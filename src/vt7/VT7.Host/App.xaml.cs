using System;
using System.Text;
using System.Windows;
using System.Windows.Threading;

namespace VT7.Host
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            var diagnostics = HasArgument(e.Args, "--diagnostics");
            var smokeTest = HasArgument(e.Args, "--window-smoke-test");
            if (diagnostics || smokeTest)
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
                            uint initialColumns = 0;
                            for (var step = 0; step < 8; ++step)
                            {
                                window.Width = step % 2 == 0 ? 1040 : 760;
                                window.Height = step % 2 == 0 ? 800 : 600;
                                window.UpdateLayout();
                                await Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                                viewport.PaintNow();
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
                            viewport.PaintNow();
                            var finalInfo = viewport.ReadInfo();
                            if (finalInfo.LastHResult < 0 || finalInfo.ResizeCount < 7)
                                throw new InvalidOperationException("Resize, minimize/restore, or reset failed.");
                            report.AppendLine($"PASS: HWND cycle {cycle + 1}, {finalInfo.Columns} x {finalInfo.Rows} cells, " +
                                $"{finalInfo.PaintCount} paints, {finalInfo.ResizeCount} resizes");
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
