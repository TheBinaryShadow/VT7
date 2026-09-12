using System;
using System.Text;
using System.Windows;
using System.Windows.Threading;

namespace VT7.Host
{
    public partial class App : Application
    {
        internal static uint RendererMode { get; private set; } = 5;
        internal static bool SettingsTest { get; private set; }
        internal static bool InjectSettingsFailure { get; private set; }
        internal static uint ExpectedSystemDpi { get; private set; }
        internal static string? RecoveryScenario { get; private set; }
        internal static bool CaptureFrames { get; private set; }
        internal static bool RepaintTest { get; private set; }
        internal static bool InjectRepaintFailure { get; private set; }
        internal static uint SurfaceOptions { get; private set; }
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            var rendererIndex = Array.IndexOf(e.Args, "--renderer");
            if (rendererIndex >= 0)
            {
                var modes = new[] { "gdi", "atlas-d3d-hardware", "atlas-d3d-warp", "atlas-d2d-hardware", "atlas-d2d-warp", "atlas-auto" };
                var mode = rendererIndex + 1 < e.Args.Length ? Array.IndexOf(modes, e.Args[rendererIndex + 1]) : -1;
                if (mode < 0) { Shutdown(2); return; }
                RendererMode = (uint)mode;
            }
            var diagnostics = HasArgument(e.Args, "--diagnostics");
            var smokeTest = HasArgument(e.Args, "--window-smoke-test");
            var recoveryIndex = Array.IndexOf(e.Args, "--recovery-test");
            if (recoveryIndex >= 0)
            {
                var scenarios = new[] { "startup-hardware", "startup-both", "present-once", "present-twice", "present-permanent", "close-retry" };
                RecoveryScenario = recoveryIndex + 1 < e.Args.Length ? e.Args[recoveryIndex + 1] : "";
                if (Array.IndexOf(scenarios, RecoveryScenario) < 0 || RendererMode == 0 || smokeTest || diagnostics)
                { Shutdown(2); return; }
            }
            RepaintTest = HasArgument(e.Args, "--repaint-test");
            InjectRepaintFailure = HasArgument(e.Args, "--inject-repaint-failure");
            SettingsTest = HasArgument(e.Args, "--settings-test");
            InjectSettingsFailure = HasArgument(e.Args, "--inject-settings-failure");
            var dpiIndex = Array.IndexOf(e.Args, "--expected-system-dpi");
            if (dpiIndex >= 0)
            {
                if (!SettingsTest || dpiIndex + 1 >= e.Args.Length || !uint.TryParse(e.Args[dpiIndex + 1], out var dpi) ||
                    (dpi != 96 && dpi != 120 && dpi != 144)) { Shutdown(2); return; }
                ExpectedSystemDpi = dpi;
            }
            if ((SettingsTest && (RendererMode == 0 || smokeTest || diagnostics || RepaintTest || RecoveryScenario != null)) ||
                (InjectSettingsFailure && !SettingsTest)) { Shutdown(2); return; }
            if ((RepaintTest && (RendererMode == 0 || smokeTest || diagnostics || RecoveryScenario != null)) ||
                (InjectRepaintFailure && !RepaintTest)) { Shutdown(2); return; }
            CaptureFrames = smokeTest || RepaintTest || RecoveryScenario != null || SettingsTest;
            var injectBlank = HasArgument(e.Args, "--inject-blank-frame");
            if (injectBlank && (!smokeTest || RendererMode == 0)) { Shutdown(2); return; }
            SurfaceOptions = RendererMode | (CaptureFrames ? 0x100u : 0u) | (injectBlank ? 0x200u : 0u);
            if (RecoveryScenario == "startup-hardware") SurfaceOptions |= 0x400u;
            if (RecoveryScenario == "startup-both") SurfaceOptions |= 0x800u;
            if (diagnostics || smokeTest || RepaintTest || RecoveryScenario != null || SettingsTest)
            {
                ShutdownMode = ShutdownMode.OnExplicitShutdown;
                RunChecks(e.Args, smokeTest);
                return;
            }
            new MainWindow().Show();
        }

        private static bool HasArgument(string[] args, string value) =>
            Array.Exists(args, argument => string.Equals(argument, value, StringComparison.OrdinalIgnoreCase));

        private async void RunChecks(string[] args, bool smokeTest)
        {
            var snapshot = ProbeService.Capture();
            var report = new StringBuilder();
            try
            {
                if (SettingsTest)
                {
                    if (!snapshot.Passed) throw new InvalidOperationException("Core or platform checks failed before settings testing.");
                    await SettingsWindowChecks.Run(args, report);
                    snapshot.SurfaceDisplay = report.ToString();
                    snapshot.Summary = "Atlas font/settings and measured host-DPI checks passed. Renderer DPI overrides are simulations.";
                }
                if (RecoveryScenario != null)
                {
                    if (!snapshot.Passed) throw new InvalidOperationException("Core or platform checks failed before recovery testing.");
                    await RecoveryWindowChecks.Run(args, report);
                    snapshot.SurfaceDisplay = report.ToString();
                    snapshot.Summary = "Controlled Atlas recovery checks passed. Injected errors are not real driver-loss evidence.";
                }
                if (RepaintTest)
                {
                    if (!snapshot.Passed) throw new InvalidOperationException("Core or platform checks failed before repaint testing.");
                    await RepaintWindowChecks.Run(args, report);
                    snapshot.SurfaceDisplay = report.ToString();
                    snapshot.Summary = "Integrated Atlas repaint and cursor-cell checks passed.";
                }
                if (smokeTest)
                {
                    if (!snapshot.Passed) throw new InvalidOperationException("Core or platform checks failed before window testing.");
                    for (var cycle = 0; cycle < 4; ++cycle)
                    {
                        var window = new MainWindow { Opacity = 0, ShowActivated = false, ShowInTaskbar = false };
                        IntPtr nativeWindow = IntPtr.Zero;
                        try
                        {
                            window.Show();
                            await Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                            var viewport = window.Viewport ?? throw new InvalidOperationException("The native viewport was not created.");
                            nativeWindow = viewport.Handle;
                            await viewport.PaintAndWaitAsync();
                            report.AppendLine(StartupPlacement.Check(window));
                            await ProofWindowChecks.CheckFirstFrameStatus(window);
                            report.AppendLine("PASS: first-frame status refreshed with a completed-frame snapshot");
                            report.AppendLine(await ProofWindowChecks.CheckStatusLayout(window, viewport));
                            if (RendererMode != 0) report.AppendLine(await ProofWindowChecks.CheckBlankFirstRow(viewport));
                            uint initialColumns = 0;
                            for (var step = 0; step < 8; ++step)
                            {
                                window.Width = step % 2 == 0 ? 1040 : 760;
                                window.Height = step % 2 == 0 ? 800 : 600;
                                window.UpdateLayout();
                                await Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                                await viewport.PaintAndWaitAsync();
                                var info = viewport.ReadInfo();
                                if (info.LastHResult < 0 || info.PaintCount == 0 || info.Columns == 0 || info.Rows == 0)
                                    throw new InvalidOperationException("Surface paint or dimensions failed.");
                                if (step == 0) initialColumns = info.Columns;
                                if (step % 2 == 1 && info.Columns >= initialColumns)
                                    throw new InvalidOperationException("Resizing the WPF host did not shrink the terminal grid.");
                                if (step == 0 || step == 7)
                                    report.AppendLine(await ProofWindowChecks.CheckTabRoundTrip(window, viewport));
                            }
                            window.WindowState = WindowState.Minimized;
                            await Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                            window.WindowState = WindowState.Normal;
                            window.UpdateLayout();
                            await Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                            viewport.ResetDemo();
                            await viewport.PaintAndWaitAsync();
                            var finalInfo = viewport.ReadInfo();
                            viewport.ResetDemo();
                            await viewport.PaintAndWaitAsync();
                            if (RendererMode != 0 && finalInfo.RasterHash != viewport.ReadInfo().RasterHash)
                                throw new InvalidOperationException("Repeated reset did not restore the same Atlas pixels.");
                            if (RendererMode != 0 && cycle == 0)
                            {
                                window.Width = 1040;
                                window.Height = 940;
                                window.UpdateLayout();
                                await Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                                viewport.ResetDemo();
                                await viewport.PaintAndWaitAsync();
                                var outputIndex = Array.IndexOf(args, "--diagnostics-output");
                                if (outputIndex >= 0 && outputIndex + 1 < args.Length)
                                    viewport.SaveCapture(args[outputIndex + 1] + ".png");
                                finalInfo = viewport.ReadInfo();
                            }
                            if (finalInfo.LastHResult < 0 || finalInfo.ResizeCount < 7)
                                throw new InvalidOperationException("Resize, minimize/restore, or reset failed.");
                            report.AppendLine($"PASS: HWND cycle {cycle + 1}, {finalInfo.Columns} x {finalInfo.Rows} cells, " +
                                $"{finalInfo.PaintCount} paints, {finalInfo.ResizeCount} resizes, renderer {finalInfo.RendererMode}, header ink {finalInfo.HeaderInkPixels}, reset hash {finalInfo.RasterHash:X16}");
                        }
                        finally
                        {
                            window.Close();
                        }
                        await Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                        if (NativeMethods.IsWindow(nativeWindow))
                            throw new InvalidOperationException("The terminal child window survived host disposal.");
                    }
                    snapshot.SurfaceDisplay = report.ToString();
                    snapshot.Summary = "Platform, TerminalCore, tab contrast/switching, child HWND paints, resize, and disposal checks passed.";
                }
            }
            catch (Exception ex)
            {
                snapshot.Passed = false;
                snapshot.Error = ex.ToString();
                snapshot.SurfaceDisplay = report + "FAIL: " + ex.Message;
                snapshot.Summary = "VT7 validation failed. See the diagnostic report.";
            }

            var exitCode = snapshot.Passed ? 0 : 1;
            try
            {
                var index = Array.FindIndex(args, argument =>
                    string.Equals(argument, "--diagnostics-output", StringComparison.OrdinalIgnoreCase));
                if (index >= 0)
                {
                    if (index + 1 >= args.Length || args[index + 1].StartsWith("--", StringComparison.Ordinal))
                        throw new ArgumentException("--diagnostics-output requires a file path.");
                    DiagnosticsLog.WriteTo(snapshot, args[index + 1]);
                }
            }
            catch (Exception ex)
            {
                snapshot.Passed = false;
                snapshot.Error = "Cannot write requested report: " + ex;
                exitCode = 2;
            }
            DiagnosticsLog.Write(snapshot);
            Shutdown(exitCode);
        }
    }
}
