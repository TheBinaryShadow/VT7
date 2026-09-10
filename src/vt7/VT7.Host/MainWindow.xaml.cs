using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Threading;

namespace VT7.Host
{
    public partial class MainWindow : Window
    {
        private string? _lastLogPath;
        internal TerminalSurface? Viewport { get; private set; }
        internal ProbeSnapshot? LastSnapshot { get; private set; }

        public MainWindow()
        {
            InitializeComponent();
        }

        protected override void OnClosed(EventArgs e)
        {
            // HwndHost can reparent a detached child to retain it for reuse.
            // Explicit disposal gives the native surface a deterministic lifetime.
            Viewport?.Dispose();
            Viewport = null;
            base.OnClosed(e);
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            RunProbes();
            if (LastSnapshot?.Passed == true)
            {
                Viewport = new TerminalSurface();
                SurfaceContainer.Child = Viewport;
                Viewport.SizeChanged += (_, __) => Dispatcher.BeginInvoke(
                    DispatcherPriority.ApplicationIdle, new Action(RefreshSurfaceStatus));
                Dispatcher.BeginInvoke(DispatcherPriority.ApplicationIdle, new Action(RefreshSurfaceStatus));
            }
            else SurfaceStatus.Text = "Startup checks failed. See Diagnostics and the log.";
        }

        private void ResetSample_Click(object sender, RoutedEventArgs e)
        {
            Viewport?.ResetDemo();
            RefreshSurfaceStatus();
        }

        internal void RefreshSurfaceStatus()
        {
            if (Viewport == null || Viewport.Handle == IntPtr.Zero) return;
            var info = Viewport.ReadInfo();
            SurfaceStatus.Text = $"TerminalCore | GDI | {info.Columns} x {info.Rows} cells | " +
                $"{info.CellWidth} x {info.CellHeight} px | paints {info.PaintCount}, resizes {info.ResizeCount}";
            if (info.LastHResult < 0)
                SurfaceStatus.Text += $" | FAILED 0x{unchecked((uint)info.LastHResult):X8}";
            if (LastSnapshot != null)
            {
                LastSnapshot.SurfaceDisplay = SurfaceStatus.Text;
                LastSnapshot.Passed &= info.LastHResult >= 0;
                if (info.LastHResult < 0)
                {
                    LastSnapshot.Summary = "The native terminal surface reported an error. See the diagnostic log.";
                    OverallStatusText.Text = "Viewport needs attention";
                    OverallStatusDetail.Text = LastSnapshot.Summary;
                }
                _lastLogPath = DiagnosticsLog.Write(LastSnapshot);
                LogValue.Text = _lastLogPath ?? "Log creation failed";
            }
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
            LastSnapshot = snapshot;
            _lastLogPath = DiagnosticsLog.Write(snapshot);
            ApplySnapshot(snapshot);
            RefreshSurfaceStatus();
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
