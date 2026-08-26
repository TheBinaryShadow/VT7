using System;
using System.Windows;
using System.Windows.Threading;

namespace VT7.Host
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            if (Array.Exists(e.Args, argument =>
                string.Equals(argument, "--diagnostics", StringComparison.OrdinalIgnoreCase)))
            {
                ShutdownMode = ShutdownMode.OnExplicitShutdown;
                var snapshot = ProbeService.Capture();
                DiagnosticsLog.Write(snapshot);

                var outputArgument = Array.FindIndex(e.Args, argument =>
                    string.Equals(argument, "--diagnostics-output", StringComparison.OrdinalIgnoreCase));
                if (outputArgument >= 0 && outputArgument + 1 < e.Args.Length)
                {
                    DiagnosticsLog.WriteTo(snapshot, e.Args[outputArgument + 1]);
                }

                Shutdown(snapshot.Passed ? 0 : 1);
                return;
            }

            if (Array.Exists(e.Args, argument =>
                string.Equals(argument, "--window-smoke-test", StringComparison.OrdinalIgnoreCase)))
            {
                ShutdownMode = ShutdownMode.OnExplicitShutdown;
                var smokeWindow = new MainWindow
                {
                    Opacity = 0,
                    ShowActivated = false,
                    ShowInTaskbar = false,
                };
                smokeWindow.Show();
                smokeWindow.Dispatcher.BeginInvoke(
                    DispatcherPriority.ApplicationIdle,
                    new Action(() =>
                    {
                        smokeWindow.Close();
                        Shutdown(0);
                    }));
                return;
            }

            new MainWindow().Show();
        }
    }
}
