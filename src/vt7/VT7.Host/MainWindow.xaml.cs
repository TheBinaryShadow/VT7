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
        private int _statusGeneration;
        private bool _closed;
        internal TerminalSurface? Viewport { get; private set; }
        internal ProbeSnapshot? LastSnapshot { get; private set; }
        // Only the hidden font fixture opts out, to retain space for its largest test font.
        internal bool FitStartupToWorkArea { get; set; } = true;
        internal bool TestingStatusLayout { get; set; }

        protected override void OnSourceInitialized(EventArgs e)
        {
            base.OnSourceInitialized(e);
            if (App.StabilityTest) NativeMethods.MakeTestWindowNonInteractive(new System.Windows.Interop.WindowInteropHelper(this).Handle);
            if (FitStartupToWorkArea) StartupPlacement.Apply(this);
        }

        public MainWindow()
        {
            InitializeComponent();
        }

        protected override void OnClosed(EventArgs e)
        {
            _closed = true;
            ++_statusGeneration;
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
                Viewport.RecoveryStatusChanged += () => { if (!_closed) RefreshSurfaceStatus(); };
                SurfaceContainer.Child = Viewport;
                Viewport.SizeChanged += (_, __) => QueueSurfaceStatusRefresh();
                QueueSurfaceStatusRefresh();
            }
            else SurfaceStatus.Text = "Startup checks failed. See Diagnostics and the log.";
        }

        private void ResetSample_Click(object sender, RoutedEventArgs e)
        {
            Viewport?.ResetDemo();
            QueueSurfaceStatusRefresh();
        }

        private async void QueueSurfaceStatusRefresh()
        {
            var generation = ++_statusGeneration;
            try
            {
                // Bounded one-shot refresh after layout/render completion. No repaint
                // requests, perpetual polling, or per-frame log writes are introduced.
                for (var attempt = 0; attempt < 200; ++attempt)
                {
                    await System.Threading.Tasks.Task.Delay(50);
                    if (_closed || generation != _statusGeneration || Viewport == null) return;
                    var info = Viewport.ReadInfo();
                    if (info.LastHResult < 0 || (info.PaintCount > 0 && info.CompletedRequest >= info.RequestedFrame))
                    {
                        RefreshSurfaceStatus();
                        return;
                    }
                }
                if (!_closed && generation == _statusGeneration) RefreshSurfaceStatus();
            }
            catch (Exception ex)
            {
                if (!_closed) SurfaceStatus.Text = "Status refresh failed: " + ex.Message;
            }
        }

        internal void RefreshSurfaceStatus()
        {
            if (TestingStatusLayout) return; // Hidden layout control owns the label temporarily.
            if (Viewport == null || Viewport.Handle == IntPtr.Zero) return;
            var info = Viewport.ReadInfo();
            var font = Viewport.ReadSettings();
            var backend = new[] { "GDI reference", "Atlas D3D11 hardware", "Atlas D3D11 WARP", "Atlas D2D hardware", "Atlas D2D WARP", "Atlas automatic", "Atlas awaiting first frame" };
            SurfaceStatus.Text = $"TerminalCore | {backend[info.RendererMode]} | {info.Columns} x {info.Rows} cells | " +
                $"{info.CellWidth} x {info.CellHeight} px | frames (snapshot) {info.PaintCount}, resizes {info.ResizeCount}";
            SurfaceStatus.Text += $" | system DPI {font.SystemDpi}";
            if (info.LastHResult < 0)
                SurfaceStatus.Text += $" | FAILED 0x{unchecked((uint)info.LastHResult):X8}";
            if (info.RecoveryFailures > 0)
                SurfaceStatus.Text += $" | device {info.DeviceGeneration}, failures {info.RecoveryFailures}, WARP fallbacks {info.FallbackCount}, last 0x{unchecked((uint)info.LastRenderFailure):X8}";
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
