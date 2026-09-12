// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
using System;
using System.Diagnostics;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Threading;

namespace VT7.Host
{
    internal static class RecoveryWindowChecks
    {
        private static void Require(bool value, string message)
        {
            if (!value) throw new InvalidOperationException(message);
        }

        internal static async Task Run(string[] args, StringBuilder report)
        {
            var scenario = App.RecoveryScenario!;
            report.AppendLine($"Controlled recovery: {scenario}, requested renderer {App.RendererMode}; INJECTED errors, not real driver loss");
            var window = new MainWindow { Opacity = 0, ShowActivated = false, ShowInTaskbar = false };
            IntPtr handle = IntPtr.Zero;
            var closed = false;
            try
            {
                window.Show();
                await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                var viewport = window.Viewport ?? throw new InvalidOperationException("No recovery viewport.");
                handle = viewport.Handle;
                var startup = scenario.StartsWith("startup-", StringComparison.Ordinal);
                var fatal = scenario == "startup-both" || (scenario == "startup-hardware" && (App.RendererMode == 1 || App.RendererMode == 3)) || scenario == "present-permanent";
                NativeMethods.SurfaceInfo before = default;
                if (!startup)
                {
                    await viewport.PaintAndWaitAsync();
                    report.AppendLine(await ProofWindowChecks.CheckStatusLayout(window, viewport));
                    viewport.RepaintCheck(0, 0);
                    await viewport.WaitForRequestedFrameAsync();
                    viewport.RepaintCheck(1, 0);
                    viewport.RepaintCheck(2, 0);
                    await viewport.WaitForRequestedFrameAsync();
                    before = viewport.ReadInfo();
                    report.AppendLine(Geometry("before injection", viewport));
                    viewport.InjectFailure(scenario == "present-once" ? 1u : scenario == "present-twice" ? 2u : 3u);
                }
                var timer = Stopwatch.StartNew();
                if (scenario == "close-retry")
                {
                    // Catch the worker during its long retry backoff, not just initial paint.
                    while (viewport.ReadInfo().InjectedFailures < 4)
                    {
                        Require(timer.ElapsedMilliseconds < 10000, "Did not reach the fourth injected failure.");
                        await Task.Delay(10);
                    }
                    timer.Restart();
                    window.Close(); closed = true;
                    Require(timer.ElapsedMilliseconds < 1500, "Teardown did not interrupt retry backoff promptly.");
                    report.AppendLine($"PASS: close during retry, joined in {timer.ElapsedMilliseconds} ms");
                }
                else
                {
                    if (fatal)
                    {
                        while (viewport.ReadInfo().LastHResult >= 0)
                        {
                            Require(timer.ElapsedMilliseconds < 10000, "Permanent failure did not become fatal within the retry bound.");
                            await Task.Delay(15);
                        }
                    }
                    else await viewport.WaitForRequestedFrameAsync();
                    var after = viewport.ReadInfo();
                    report.AppendLine(Geometry("after recovery/fatal", viewport));
                    Require(after.RequestedRendererMode == App.RendererMode, "Requested renderer changed.");
                    Require(after.InjectedFailures > 0, "The fault seam was not exercised.");
                    Require(after.LastRenderFailure < 0, "Original failure HRESULT was lost.");
                    if (fatal)
                    {
                        var expected = scenario == "startup-both" && App.RendererMode == 5 ? 7u : 6u;
                        Require(after.InjectedFailures == expected, "Unexpected retry count.");
                        Require(after.CompletedRequest < after.RequestedFrame, "A failed request was marked complete.");
                        if (startup) Require(after.PaintCount == 0 && after.DeviceGeneration == 0 && after.RendererMode == 6, "Failed startup claimed a completed frame/device.");
                        else Require(after.PaintCount == before.PaintCount, "A failed Present was counted as completed.");
                        var attempts = after.DeviceAttempts;
                        var failures = after.InjectedFailures;
                        await Task.Delay(300);
                        after = viewport.ReadInfo();
                        Require(after.DeviceAttempts == attempts && after.InjectedFailures == failures, "Renderer kept retrying after fatal state.");
                        report.AppendLine("PASS: bounded fatal state; failed requests not completed; retries stopped");
                    }
                    else
                    {
                        Require(after.LastHResult >= 0 && after.FrameInkPixels >= 10, "Recovered surface is poisoned or blank.");
                        if (scenario == "startup-hardware")
                            Require(after.RendererMode == 2 && after.FallbackCount == 1 && after.DeviceAttempts == 2 && after.InjectedFailures == 1, "Initial hardware failure did not select WARP exactly once.");
                        else
                        {
                            var count = scenario == "present-once" ? 1u : 2u;
                            Require(after.InjectedFailures == count && after.DeviceGeneration == before.DeviceGeneration + count, "Wrong recreation count.");
                            var fallback = App.RendererMode == 5 && count == 2;
                            Require(after.RendererMode == (fallback ? 2u : before.RendererMode), "Unexpected recovery backend.");
                            Require(after.FallbackCount == (fallback ? 1u : 0u), "Forced mode fell back or auto mode failed to fall back.");
                            Require(after.RasterWidth == before.RasterWidth && after.RasterHeight == before.RasterHeight,
                                "Recovery changed raster dimensions. See before/after geometry.");
                            report.AppendLine(viewport.RepaintCheck(fallback ? 5u : 3u, 0));
                            if (fallback)
                            {
                                viewport.InjectFailure(1);
                                await viewport.WaitForRequestedFrameAsync();
                                var sticky = viewport.ReadInfo();
                                Require(sticky.RendererMode == 2 && sticky.FallbackCount == 1 &&
                                    sticky.DeviceGeneration == after.DeviceGeneration + 1 && sticky.InjectedFailures == 3,
                                    "WARP selection did not remain sticky through another device recreation.");
                                after = sticky;
                                report.AppendLine("PASS: WARP remains sticky through another injected removal and recreation");
                            }
                        }
                        var output = Array.IndexOf(args, "--diagnostics-output");
                        if (output >= 0 && output + 1 < args.Length) viewport.SaveCapture(args[output + 1] + ".png");
                        report.AppendLine("PASS: recovered frame, correct backend and nonblank glyphs");
                    }
                    Require(App.RendererMode == 5 || after.FallbackCount == 0, "Forced renderer silently fell back.");
                    // Check the production event-driven status, without refreshing it here.
                    await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                    Require(window.SurfaceStatus.Text.Contains(fatal ? "FAILED" : "WARP fallbacks"), "Recovery/fatal status notification was not delivered.");
                    if (!fatal && after.RendererMode == 2)
                        Require(window.SurfaceStatus.Text.Contains("Atlas D3D11 WARP"), "Status did not identify the actual WARP renderer.");
                    report.AppendLine($"PASS: status notification; actual {after.RendererMode}, generations {after.DeviceGeneration}, attempts {after.DeviceAttempts}, failures {after.RecoveryFailures}, fallbacks {after.FallbackCount}, injected {after.InjectedFailures}, last 0x{unchecked((uint)after.LastRenderFailure):X8}");
                }
            }
            finally { if (!closed) window.Close(); }
            await System.Windows.Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
            Require(!NativeMethods.IsWindow(handle), "Recovery HWND survived disposal.");
            report.AppendLine("PASS: controlled recovery HWND disposed");
        }

        private static string Geometry(string phase, TerminalSurface viewport)
        {
            var info = viewport.ReadInfo();
            var settings = viewport.ReadSettings();
            return $"Recovery geometry {phase}: system DPI {settings.SystemDpi}, client {settings.ClientWidth}x{settings.ClientHeight}, raster {info.RasterWidth}x{info.RasterHeight}, grid {info.Columns}x{info.Rows}, cell {info.CellWidth}x{info.CellHeight}, requested {info.RequestedFrame}, completed {info.CompletedRequest}";
        }
    }
}
