using System;
using System.Diagnostics;
using System.IO;
using System.Windows;

namespace VT7.Host
{
    public partial class MainWindow : Window
    {
        private string? _lastLogPath;

        public MainWindow()
        {
            InitializeComponent();
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            RunProbes();
        }

        private void RunProbes_Click(object sender, RoutedEventArgs e)
        {
            RunProbes();
        }

        private void OpenLogFolder_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(_lastLogPath))
            {
                MessageBox.Show(this, "Run the platform probes before opening the log folder.", "VT7", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var folder = Path.GetDirectoryName(_lastLogPath);
            if (string.IsNullOrWhiteSpace(folder) || !Directory.Exists(folder))
            {
                MessageBox.Show(this, "The diagnostic log folder is not available.", "VT7", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            Process.Start(new ProcessStartInfo("explorer.exe", folder)
            {
                UseShellExecute = true,
            });
        }

        private void RunProbes()
        {
            OverallStatusText.Text = "Running platform probes";
            OverallStatusDetail.Text = "Checking the native bridge, operating system, DXGI, Direct3D hardware, and WARP.";

            var snapshot = ProbeService.Capture();
            _lastLogPath = DiagnosticsLog.Write(snapshot);
            ApplySnapshot(snapshot);
        }

        private void ApplySnapshot(ProbeSnapshot snapshot)
        {
            OverallStatusText.Text = snapshot.Passed ? "Proof probe passed" : "Proof probe needs attention";
            OverallStatusDetail.Text = snapshot.Summary;
            VersionValue.Text = snapshot.BuildDisplay;
            NativeValue.Text = snapshot.NativeDisplay;
            WindowsValue.Text = snapshot.PlatformDisplay;
            RuntimeValue.Text = snapshot.RuntimeDisplay;
            AdapterValue.Text = snapshot.AdapterDisplay;
            HardwareValue.Text = snapshot.HardwareDisplay;
            WarpValue.Text = snapshot.WarpDisplay;
            DxgiValue.Text = snapshot.DxgiDisplay;
            LastRunValue.Text = snapshot.CapturedAt.ToString("yyyy-MM-dd HH:mm:ss zzz");
            LogValue.Text = _lastLogPath ?? "Log creation failed";
        }
    }
}
