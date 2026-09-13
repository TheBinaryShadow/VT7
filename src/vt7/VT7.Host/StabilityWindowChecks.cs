// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Threading;

namespace VT7.Host
{
    internal static class StabilityWindowChecks
    {
        private sealed class Resources
        {
            internal long Bytes;
            internal int Handles, Threads;
            internal uint Gdi, User;
            internal string Windows = "";
            internal string ThreadOrigins = "";
            internal static async Task<Resources> Read()
            {
                // Collect only at checkpoints, never on the ordinary rendering path.
                GC.Collect(); GC.WaitForPendingFinalizers(); GC.Collect();
                // WPF finalizers can queue native release onto the dispatcher.
                // Drain that work before comparing equivalent disposed states.
                await System.Windows.Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                await Task.Delay(250);
                using (var process = Process.GetCurrentProcess())
                {
                    process.Refresh();
                    return new Resources { Bytes = process.PrivateMemorySize64, Handles = process.HandleCount,
                        Threads = process.Threads.Count, Gdi = NativeMethods.GetGuiResources(process.Handle, 0),
                        User = NativeMethods.GetGuiResources(process.Handle, 1), Windows = NativeMethods.ReadHelperWindows(),
                        ThreadOrigins = ResourceDiagnostics.ReadThreadOrigins() };
                }
            }
            public override string ToString() => $"privateBytes={Bytes}, handles={Handles}, threads={Threads}, GDI={Gdi}, USER={User}; helper windows: {Windows}; thread origins: {ThreadOrigins}";
            internal void CheckGrowth(Resources baseline)
            {
                // Diagnostic investigation thresholds, not a production performance promise.
                Require(Bytes - baseline.Bytes <= 64L * 1024 * 1024 && Handles - baseline.Handles <= 32 &&
                    Threads - baseline.Threads <= 8 && (long)Gdi - baseline.Gdi <= 16 && (long)User - baseline.User <= 16,
                    "Resource growth exceeded the post-warm-up investigation budget.");
            }
        }

        private static void Require(bool condition, string message)
        { if (!condition) throw new InvalidOperationException(message); }

        private static async Task Settle(MainWindow window)
        {
            window.UpdateLayout();
            await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
        }

        private static async Task Until(Func<bool> predicate, string reason, int timeout = 3000)
        {
            var clock = Stopwatch.StartNew();
            while (!predicate())
            {
                if (clock.ElapsedMilliseconds > timeout) throw new TimeoutException(reason);
                await Task.Delay(1);
            }
        }

        private static async Task Park(TerminalSurface surface)
        {
            await surface.WaitForRequestedFrameAsync();
            await Until(() => surface.ReadScheduling().Waiting != 0, "Renderer did not park.");
            // Drain remembered redundant wakes and host first-frame status notifications.
            await Task.Delay(250);
            await Until(() => surface.ReadScheduling().Waiting != 0, "Renderer did not settle.");
        }

        private static async Task Exact(TerminalSurface surface)
        {
            surface.RepaintCheck(8, 0);
            surface.RepaintCheck(2, 0);
            await surface.WaitForRequestedFrameAsync();
            surface.RepaintCheck(3, 0);
        }

        private static async Task Idle(TerminalSurface surface, int milliseconds, string state, Action<string> log, bool negative = false)
        {
            await Task.Delay(250);
            var before = surface.ReadInfo();
            var schedule = surface.ReadScheduling();
            using (var process = Process.GetCurrentProcess())
            {
                var cpu = process.TotalProcessorTime;
                var clock = Stopwatch.StartNew();
                if (negative) surface.SchedulingCommand(3, 777);
                await Task.Delay(milliseconds);
                var used = (process.TotalProcessorTime - cpu).TotalMilliseconds;
                var percent = used / clock.Elapsed.TotalMilliseconds * 100;
                var after = surface.ReadInfo();
                var end = surface.ReadScheduling();
                log($"MEASURE: {state} idle {clock.ElapsedMilliseconds} ms, CPU {percent:F3}% of one logical CPU, " +
                    $"presents +{after.PaintCount - before.PaintCount}, renderer calls +{end.Frames - schedule.Frames}, waits +{end.Waits - schedule.Waits}");
                Require(after.PaintCount == before.PaintCount && end.Frames == schedule.Frames && end.Waits - schedule.Waits <= 1,
                    "Idle redraw/wake invariant failed.");
                Require(percent <= 5, "Idle process CPU exceeded 5% of one logical CPU; investigate environment and polling.");
            }
        }

        internal static async Task Run(string[] args, StringBuilder report)
        {
            var outputIndex = Array.IndexOf(args, "--diagnostics-output");
            var progressPath = outputIndex >= 0 && outputIndex + 1 < args.Length ? Path.GetFullPath(args[outputIndex + 1]) + ".progress.log" : null;
            if (progressPath != null) Directory.CreateDirectory(Path.GetDirectoryName(progressPath)!);
            using (var progress = progressPath == null ? null : new StreamWriter(progressPath, false, new UTF8Encoding(false)) { AutoFlush = true })
            {
                void Log(string text) { report.AppendLine(text); progress?.WriteLine(DateTime.UtcNow.ToString("O") + " " + text); }
                if (App.ResourceIsolation != null) { await RunIsolation(Log); return; }
                Log($"Stability profile: {(App.StabilitySoak ? "extended" : App.StabilityLifecycle ? "lifecycle" : "quick")}; renderer {App.RendererMode}; capture/readback enabled, cursor blink disabled.");
                Log("Budgets: idle zero presents/renderer calls, <=1 redundant wait, <=5% one logical CPU; close <=2000 ms; " +
                    "post-warm-up growth <=64 MiB private, 32 handles, 8 threads, 16 GDI and 16 USER objects. GPU allocation accounting unavailable.");
                var count = App.StabilitySoak || App.StabilityLifecycle ? 100 : 8;
                Resources? baseline = null;
                var latency = new List<double>();
                long worstClose = 0;
                var resourceFailures = 0;
                for (int cycle = -2; cycle < count; ++cycle)
                {
                    var window = new MainWindow { Opacity = 0, ShowActivated = false, ShowInTaskbar = false, IsHitTestVisible = false };
                    IntPtr handle = IntPtr.Zero;
                    try
                    {
                        window.Show(); await Settle(window);
                        var surface = window.Viewport ?? throw new InvalidOperationException("No stability viewport.");
                        handle = surface.Handle;
                        surface.SchedulingCommand(0);
                        await surface.PaintAndWaitAsync();
                        if (cycle == 0)
                        {
                            Log($"Measured system DPI {surface.ReadSettings().SystemDpi}; warm-up completed.");
                            await Park(surface);
                            await Idle(surface, 2000, "visible", Log, App.InjectStabilityFailure);
                            var fired = surface.ReadScheduling().TimerFires;
                            surface.SchedulingCommand(6, 40);
                            await Until(() => surface.ReadScheduling().TimerFires == fired + 1, "One-shot timer did not wake the parked renderer.");
                            for (var timerStep = 0; timerStep < 64; ++timerStep)
                            {
                                surface.SchedulingCommand(6, 1000);
                                surface.SchedulingCommand(7);
                            }
                            await Park(surface);
                            await Task.Delay(1100);
                            Require(surface.ReadScheduling().TimerFires == fired + 1, "Canceled timer fired.");
                            Log("PASS: parked one-shot timer wake and 64 timer arm/cancel pairs, no canceled callbacks.");
                            var before = surface.ReadScheduling();
                            var beforeFrame = surface.ReadInfo().PaintCount;
                            var clock = Stopwatch.StartNew();
                            surface.SchedulingCommand(1, 1);
                            await Until(() => surface.ReadScheduling().Synchronizing != 0, "Sync begin never entered renderer wait.");
                            Require(surface.ReadInfo().PaintCount == beforeFrame && surface.ReadScheduling().SyncMode == 1,
                                "Synchronized frame was presented before end.");
                            surface.SchedulingCommand(2);
                            await surface.WaitForRequestedFrameAsync();
                            Require(surface.ReadScheduling().SyncTimeouts == before.SyncTimeouts && surface.ReadScheduling().SyncMode == 0,
                                "Explicit sync end did not release the wait before timeout.");
                            surface.SchedulingCommand(4, 1); await Exact(surface);
                            Log($"PASS: explicit synchronized-output end, {clock.ElapsedMilliseconds} ms including validation; exact redraw matches.");
                            await Park(surface);
                            before = surface.ReadScheduling(); clock.Restart();
                            surface.SchedulingCommand(5, 2);
                            await surface.WaitForRequestedFrameAsync();
                            var elapsed = clock.ElapsedMilliseconds;
                            var after = surface.ReadScheduling();
                            Require(after.SyncWaits == before.SyncWaits + 1 && after.SyncTimeouts == before.SyncTimeouts + 1 &&
                                after.SyncMode == 0 && elapsed >= 80 && elapsed < 3000, "Missing-end timeout was not bounded or did not reset mode.");
                            surface.SchedulingCommand(4, 2); await Exact(surface);
                            Log($"PASS: split DECSET 2026 missing-end timeout, {elapsed} ms; mode reset and exact redraw matches.");
                            for (uint wake = 0; wake < 64; ++wake)
                            {
                                await Until(() => surface.ReadScheduling().Waiting != 0, "Wake test did not park.");
                                surface.SchedulingCommand(3, wake);
                                await surface.WaitForRequestedFrameAsync();
                                surface.SchedulingCommand(4, wake);
                            }
                            await Exact(surface);
                            Log("PASS: 64 parked wake generations, two joined producers with 64 notifications each; final source and exact redraw verified.");
                            window.ProofTabs.SelectedIndex = 1; await Settle(window);
                            Require(!NativeMethods.IsWindowVisible(handle), "Tab did not hide native HWND.");
                            surface.SchedulingCommand(3, 123);
                            await Idle(surface, 2000, "hidden with pending output", Log);
                            window.ProofTabs.SelectedIndex = 0; await Settle(window);
                            await surface.PaintAndWaitAsync(); surface.SchedulingCommand(4, 123); await Exact(surface);
                            Require(surface.ReadScheduling().ThreadStarts == 1, "Tab return restarted the presentation worker.");
                            Log("PASS: hidden output consumed without frames, restored source and exact pixels.");
                        }
                        for (var step = 0; step < 10; ++step)
                        {
                            window.Width = 760 + (step % 5) * 45;
                            window.Height = 640 + (step % 3) * 30;
                            await Settle(window);
                            surface.SchedulingCommand(3, (uint)(step + 100));
                            var clock = Stopwatch.StartNew();
                            await surface.PaintAndWaitAsync();
                            if (cycle >= 0) latency.Add(clock.Elapsed.TotalMilliseconds);
                            surface.SchedulingCommand(4, (uint)(step + 100));
                            if (step % 2 == 0) await ProofWindowChecks.CheckTabRoundTrip(window, surface);
                        }
                        await Exact(surface);
                        Require(surface.ReadScheduling().ThreadStarts == 1, "Lifecycle tab transitions restarted the presentation worker.");
                        // Rotate close from parked, active, hidden and sync-waiting states.
                        switch ((cycle + 4) % 4)
                        {
                            case 0: await Park(surface); break;
                            case 1: surface.SchedulingCommand(3, 900); break;
                            case 2: window.ProofTabs.SelectedIndex = 1; await Settle(window); surface.SchedulingCommand(3, 901); break;
                            case 3:
                                surface.SchedulingCommand(1, 902);
                                await Until(() => surface.ReadScheduling().Synchronizing != 0, "Close test never entered sync wait.");
                                break;
                        }
                    }
                    finally
                    {
                        var close = Stopwatch.StartNew(); window.Close();
                        worstClose = Math.Max(worstClose, close.ElapsedMilliseconds);
                        Require(close.ElapsedMilliseconds <= 2000, "Shutdown exceeded two seconds.");
                    }
                    await System.Windows.Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                    Require(!NativeMethods.IsWindow(handle), "Stability HWND survived disposal.");
                    if (cycle == -1) { baseline = await Resources.Read(); Log("RESOURCE warm-up: " + baseline); }
                    if (cycle >= 0 && ((cycle + 1) % Math.Max(1, count / 4) == 0))
                    {
                        var resources = await Resources.Read(); Log($"RESOURCE cycle {cycle + 1}: {resources}");
                        // Retain all four checkpoints to distinguish continuing growth
                        // from one-time initialization. A crossed budget still fails.
                        try { resources.CheckGrowth(baseline!); }
                        catch (InvalidOperationException ex) { ++resourceFailures; Log("BUDGET: " + ex.Message); }
                        Require(resources.Bytes - baseline!.Bytes < 512L * 1024 * 1024 && resources.Handles - baseline.Handles < 2048,
                            "Resource safety ceiling exceeded; stopping bounded lifecycle collection.");
                    }
                }
                latency.Sort();
                Log($"PASS: {count} create/destroy cycles, {count * 10} resize operations, {count * 5} tab round trips; worst close {worstClose} ms.");
                Log($"MEASURE: request-to-observed-completion with readback/polling, median {latency[latency.Count / 2]:F2} ms, " +
                    $"p95 {latency[(int)(latency.Count * .95)]:F2} ms, maximum {latency.Last():F2} ms; not input latency or GPU frame time.");
                Require(resourceFailures == 0, $"Resource budget exceeded at {resourceFailures} lifecycle checkpoints; full series retained for investigation.");
                if (App.StabilitySoak) await Soak(Log);
                else Log("NOT RUN: 30-minute active/10-minute idle soak. Lifecycle counts above identify this profile's coverage.");
                Log("PASS: stability profile completed");
            }
        }

        private static async Task RunIsolation(Action<string> log)
        {
            var cycles = App.ResourceIsolation == "native-child-plateau" ? 300 : 100;
            var nativeParent = App.ResourceIsolation == "native-parent";
            var directChild = nativeParent || App.ResourceIsolation!.StartsWith("native-child", StringComparison.Ordinal);
            log($"Resource isolation: {App.ResourceIsolation}; renderer {App.RendererMode}; 2 warm-up plus {cycles} measured cycles. Not scheduling acceptance.");
            Resources? baseline = null;
            var failures = 0;
            for (int cycle = -2; cycle < cycles; ++cycle)
            {
                var panel = new System.Windows.Controls.Border();
                var window = new System.Windows.Window { Width = 900, Height = 700, Content = panel,
                    Opacity = 0, ShowActivated = false, ShowInTaskbar = false, IsHitTestVisible = false };
                if (App.ResourceIsolation == "native-child-layered")
                { window.WindowStyle = System.Windows.WindowStyle.None; window.AllowsTransparency = true; }
                window.SourceInitialized += (_, __) => NativeMethods.MakeTestWindowNonInteractive(new System.Windows.Interop.WindowInteropHelper(window).Handle);
                TerminalSurface? host = null;
                IntPtr handle = IntPtr.Zero;
                IntPtr parent = IntPtr.Zero;
                try
                {
                    if (App.ResourceIsolation == "hwndhost") { host = new TerminalSurface(); panel.Child = host; }
                    else panel.Child = new System.Windows.Controls.TextBlock { Text = "VT7 resource control", FontFamily = new System.Windows.Media.FontFamily("Segoe UI") };
                    if (nativeParent)
                    {
                        parent = NativeMethods.CreateWindowEx(0x080800A0, "STATIC", "VT7 native parent control", 0x82000000,
                            0, 0, 1000, 800, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
                        Require(parent != IntPtr.Zero, "Cannot create native isolation parent.");
                        Require(NativeMethods.SetLayeredWindowAttributes(parent, 0, 0, 2), "Cannot make native isolation parent transparent.");
                        NativeMethods.ShowWindow(parent, 4);
                    }
                    else { window.Show(); window.UpdateLayout(); parent = new System.Windows.Interop.WindowInteropHelper(window).Handle; }
                    if (cycle == -2) log("PARENT: " + NativeMethods.ReadWindowStyles(parent));
                    await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                    if (directChild)
                        System.Runtime.InteropServices.Marshal.ThrowExceptionForHR(NativeMethods.VT7_CreateSurface(
                            parent, App.SurfaceOptions, out handle));
                    else if (host != null) handle = host.Handle;
                    async Task Frame(uint step)
                    {
                        if (handle == IntPtr.Zero) return;
                        System.Runtime.InteropServices.Marshal.ThrowExceptionForHR(NativeMethods.VT7_SchedulingCommand(handle, 3, step));
                        Require(NativeMethods.RedrawWindow(handle, IntPtr.Zero, IntPtr.Zero, 0x101), "Isolation redraw failed.");
                        await Until(() => {
                            var info = new NativeMethods.SurfaceInfo { StructSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf(typeof(NativeMethods.SurfaceInfo)) };
                            System.Runtime.InteropServices.Marshal.ThrowExceptionForHR(NativeMethods.VT7_GetSurfaceInfo(handle, ref info));
                            System.Runtime.InteropServices.Marshal.ThrowExceptionForHR(info.LastHResult);
                            return info.PaintCount > 0 && info.CompletedRequest >= info.RequestedFrame;
                        }, "Isolation frame did not complete.");
                        System.Runtime.InteropServices.Marshal.ThrowExceptionForHR(NativeMethods.VT7_SchedulingCommand(handle, 4, step));
                    }
                    for (uint step = 0; step < 10; ++step)
                    {
                        window.Width = 760 + step % 5 * 45; window.Height = 640 + step % 3 * 30;
                        window.UpdateLayout(); await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                        if (directChild)
                            Require(NativeMethods.MoveWindow(handle, 0, 0, (int)window.Width - 40, (int)window.Height - 60, true), "Isolation resize failed.");
                        await Frame(step);
                        if (handle != IntPtr.Zero && step % 2 == 0)
                        {
                            NativeMethods.ShowWindow(handle, 0); await Task.Delay(20);
                            NativeMethods.ShowWindow(handle, 4); await Frame(step);
                        }
                    }
                }
                finally
                {
                    try
                    {
                        if (host != null) host.Dispose();
                        else if (handle != IntPtr.Zero) System.Runtime.InteropServices.Marshal.ThrowExceptionForHR(NativeMethods.VT7_DestroySurface(handle));
                    }
                    finally
                    {
                        try
                        {
                            if (nativeParent && parent != IntPtr.Zero)
                                Require(NativeMethods.DestroyWindow(parent), "Native isolation parent could not be destroyed.");
                        }
                        finally { window.Close(); }
                    }
                }
                Require(handle == IntPtr.Zero || !NativeMethods.IsWindow(handle), "Isolation surface survived close.");
                if (cycle == -1) { baseline = await Resources.Read(); log("RESOURCE warm-up: " + baseline); }
                if (cycle >= 0 && (cycle + 1) % 25 == 0)
                {
                    var state = await Resources.Read(); log($"RESOURCE cycle {cycle + 1}: {state}");
                    try { state.CheckGrowth(baseline!); }
                    catch (InvalidOperationException ex) { ++failures; log("BUDGET: " + ex.Message); }
                    Require(state.Bytes - baseline!.Bytes < 512L * 1024 * 1024 && state.Handles - baseline.Handles < 2048, "Isolation safety ceiling exceeded.");
                }
            }
            await Task.Delay(10000);
            log("RESOURCE after 10 seconds closed: " + await Resources.Read());
            log($"PASS: {cycles} resource-isolation cycles completed. No timed soak performed.");
            Require(failures == 0, $"Resource budget exceeded at {failures} isolation checkpoints.");
        }

        private static async Task Soak(Action<string> log)
        {
            var window = new MainWindow { Opacity = 0, ShowActivated = false, ShowInTaskbar = false, IsHitTestVisible = false };
            try
            {
                window.Show(); await Settle(window);
                var surface = window.Viewport!;
                surface.SchedulingCommand(0); await surface.PaintAndWaitAsync();
                // Warm the fixed corpus, sizes and diagnostic allocations before sampling.
                for (uint i = 0; i < 100; ++i) { surface.SchedulingCommand(3, i); await surface.WaitForRequestedFrameAsync(); }
                var baseline = await Resources.Read(); log("RESOURCE soak warm-up: " + baseline);
                var clock = Stopwatch.StartNew(); long nextSample = 60000; uint step = 0;
                while (clock.Elapsed.TotalMinutes < 30)
                {
                    surface.SchedulingCommand(3, step++ % 100000);
                    window.Width = 760 + (step % 5) * 40; window.Height = 640 + (step % 3) * 30;
                    await Settle(window); await surface.PaintAndWaitAsync();
                    surface.SchedulingCommand(4, (step - 1) % 100000);
                    if (clock.ElapsedMilliseconds >= nextSample)
                    {
                        await Exact(surface);
                        var resources = await Resources.Read(); log($"RESOURCE active {clock.ElapsedMilliseconds} ms: {resources}");
                        resources.CheckGrowth(baseline); nextSample += 60000;
                    }
                    await Task.Delay(100);
                }
                await Exact(surface); await Park(surface);
                log($"PASS: active soak {clock.ElapsedMilliseconds} ms, {step} content/resize generations.");
                for (int minute = 0; minute < 10; ++minute) await Idle(surface, 60000, $"visible soak minute {minute + 1}", log);
                window.ProofTabs.SelectedIndex = 1; await Settle(window);
                await Idle(surface, 10000, "hidden soak", log);
                var final = await Resources.Read(); log("RESOURCE soak final: " + final); final.CheckGrowth(baseline);
                log("PASS: extended active/idle soak completed; opacity-zero test host, not physical occlusion qualification.");
            }
            finally { window.Close(); }
        }
    }
}
