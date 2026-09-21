using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Threading;
using System.Threading;
using System.Linq;

namespace VT7.Host
{
    public partial class MainWindow : Window
    {
        private string? _lastLogPath;
        private int _statusGeneration;
        private bool _closed;
        private SessionOutboundAuditSink? _outboundAudit;
        private TerminalDocument? _document;
        private TerminalSession? _session;
        private ITerminalTransport? _rootTransport;
        private SshOverlayCoordinator? _sshOverlayCoordinator;
        private TerminalProfile? _activeProfile;
        private string? _activeSessionName;
        private bool _switchingProfile;
        internal SessionOutboundQueue? SessionOutbound => _session?.State == TerminalSessionState.RunningRoot ? _session.Outbound : null;
        internal SessionOutboundAuditSink? OutboundAudit => _outboundAudit;
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

        internal TerminalDocument DetachViewportForTest()
        {
            if (_document == null || Viewport == null) throw new InvalidOperationException("No terminal view is attached.");
            var document = _document;
            SurfaceContainer.Child = null;
            Viewport.DetachSessionInput();
            Viewport.Dispose();
            Viewport = null;
            return document;
        }

        internal TerminalSurface AttachViewportForTest(TerminalDocument document)
        {
            if (Viewport != null || _document != document) throw new InvalidOperationException("The test document is not detached from this window.");
            var surface = new TerminalSurface(document);
            Viewport = surface;
            SurfaceContainer.Child = surface;
            return surface;
        }

        protected override async void OnClosed(EventArgs e)
        {
            _closed = true;
            ++_statusGeneration;
            Viewport?.DetachSessionInput();
            _sshOverlayCoordinator?.Dispose();
            _sshOverlayCoordinator = null;
            if (_session != null)
            {
                try { await _session.CloseAsync(); }
                finally { _session.Dispose(); _session = null; }
            }
            _rootTransport = null;
            _outboundAudit = null;
            // HwndHost can reparent a detached child to retain it for reuse.
            // Explicit disposal gives the native surface a deterministic lifetime.
            Viewport?.Dispose();
            Viewport = null;
            _document?.Dispose();
            _document = null;
            base.OnClosed(e);
        }

        private async void Window_Loaded(object sender, RoutedEventArgs e)
        {
            RunProbes();
            if (LastSnapshot?.Passed == true)
            {
                _document = new TerminalDocument(loadDemonstration: !App.LaunchLocalSession);
                Viewport = new TerminalSurface(_document);
                Viewport.RecoveryStatusChanged += () => { if (!_closed) RefreshSurfaceStatus(); };
                SurfaceContainer.Child = Viewport;
                if (!App.SessionStreamTest)
                {
                    try
                    {
                        if (App.LaunchLocalSession)
                        {
                            var profiles = TerminalProfileCatalog.Discover();
                            ProfileSelector.ItemsSource = profiles;
                            var requested = profiles.FirstOrDefault(profile =>
                                string.Equals(profile.Id, App.RequestedProfileId, StringComparison.OrdinalIgnoreCase));
                            if (requested == null)
                                throw new InvalidOperationException($"The requested profile '{App.RequestedProfileId}' is not installed.");
                            ProfileSelector.SelectedItem = requested;
                            await StartProfileAsync(requested);
                        }
                        else
                        {
                            ProfileControls.Visibility = Visibility.Collapsed;
                            _outboundAudit = new SessionOutboundAuditSink();
                            _rootTransport = new FakeTerminalTransport("diagnostic-root", _outboundAudit);
                            _session = new TerminalSession(_document, _rootTransport);
                            await _session.StartAsync();
                            AttachSession(_session);
                        }
                    }
                    catch (Exception ex)
                    {
                        _session?.Dispose();
                        _session = null;
                        _rootTransport = null;
                        _activeProfile = null;
                        SurfaceStatus.Text = "Terminal profile could not start: " + ex.Message;
                    }
                }
                Viewport.SizeChanged += (_, __) => QueueSurfaceStatusRefresh();
                QueueSurfaceStatusRefresh();
            }
            else SurfaceStatus.Text = "Startup checks failed. See Diagnostics and the log.";
        }

        private async void StartProfile_Click(object sender, RoutedEventArgs e)
        {
            if (ProfileSelector.SelectedItem is TerminalProfile profile)
                await StartProfileAsync(profile);
        }

        private async void StartSsh_Click(object sender, RoutedEventArgs e)
        {
            if (_switchingProfile || _closed) return;
            var dialog = new SshConnectionDialog { Owner = this };
            if (dialog.ShowDialog() != true || dialog.Result == null) return;
            await StartTransportAsync(new SshNetTransport(dialog.Result), "SSH.NET direct profile", null, null);
        }

        private async void DisconnectSsh_Click(object sender, RoutedEventArgs e)
        {
            if (_sshOverlayCoordinator == null || !_sshOverlayCoordinator.IsOverlayRunning) return;
            DisconnectSshButton.IsEnabled = false;
            SurfaceStatus.Text = "Disconnecting the SSH.NET overlay...";
            try { await _sshOverlayCoordinator.DisconnectAsync(); }
            catch (Exception ex) when (!_closed) { SurfaceStatus.Text = "SSH disconnect failed: " + ex.Message; }
        }

        private async System.Threading.Tasks.Task StartProfileAsync(TerminalProfile profile)
        {
            if (_switchingProfile || _closed || _document == null || Viewport == null) return;
            var coordinator = SshOverlayCoordinator.TryCreate(profile, PromptForTypedSshAsync);
            var configured = coordinator?.Configure(profile) ?? profile;
            await StartTransportAsync(new WinPtyTransport(configured), profile.DisplayName, profile, coordinator);
        }

        private async System.Threading.Tasks.Task StartTransportAsync(ITerminalTransport transport, string sessionName,
            TerminalProfile? localProfile, SshOverlayCoordinator? pendingCoordinator)
        {
            if (_switchingProfile || _closed || _document == null || Viewport == null)
            {
                transport.Dispose();
                pendingCoordinator?.Dispose();
                return;
            }
            _switchingProfile = true;
            StartProfileButton.IsEnabled = false;
            StartSshButton.IsEnabled = false;
            DisconnectSshButton.IsEnabled = false;
            TerminalSession? pendingSession = null;
            try
            {
                Viewport.DetachSessionInput();
                var previous = _session;
                var previousCoordinator = _sshOverlayCoordinator;
                _session = null;
                _sshOverlayCoordinator = null;
                _rootTransport = null;
                _activeProfile = null;
                _activeSessionName = null;
                previousCoordinator?.Dispose();
                if (previous != null)
                {
                    try { await previous.CloseAsync(TerminalCloseReason.Replaced); }
                    finally { previous.Dispose(); }
                }

                SurfaceStatus.Text = "Starting " + sessionName + "...";
                pendingSession = new TerminalSession(_document, transport, () =>
                {
                    if (Viewport == null) return default;
                    var info = Viewport.ReadInfo();
                    return new TerminalPixelSize(checked(info.Columns * info.CellWidth), checked(info.Rows * info.CellHeight));
                });
                await pendingSession.StartAsync();
                if (pendingCoordinator != null)
                {
                    if (!(transport is WinPtyTransport winPty))
                        throw new InvalidOperationException("An SSH overlay coordinator requires a WinPTY root.");
                    pendingCoordinator.Attach(pendingSession, winPty.Snapshot.ProcessId);
                    pendingCoordinator.OverlayStateChanged += OnOverlayStateChanged;
                }
                _rootTransport = transport;
                _session = pendingSession;
                _sshOverlayCoordinator = pendingCoordinator;
                _activeProfile = localProfile;
                _activeSessionName = sessionName;
                AttachSession(pendingSession);
                Title = "VT7 - " + sessionName;
                SurfaceStatus.Text = sessionName + " is running.";
                QueueTerminalFocus(pendingSession);
                QueueSurfaceStatusRefresh();
            }
            catch (Exception ex)
            {
                if (_session == pendingSession)
                {
                    Viewport?.DetachSessionInput();
                    _session = null;
                    _rootTransport = null;
                    _sshOverlayCoordinator = null;
                    _activeProfile = null;
                    _activeSessionName = null;
                }
                if (pendingSession != null) pendingSession.Dispose();
                else transport.Dispose();
                pendingCoordinator?.Dispose();
                if (!_closed) SurfaceStatus.Text = sessionName + " could not start: " + ex.Message;
            }
            finally
            {
                _switchingProfile = false;
                if (!_closed)
                {
                    StartProfileButton.IsEnabled = true;
                    StartSshButton.IsEnabled = true;
                    DisconnectSshButton.IsEnabled = _sshOverlayCoordinator?.IsOverlayRunning == true;
                }
            }
        }

        private async System.Threading.Tasks.Task<SshConnectionOptions?> PromptForTypedSshAsync(SshInvocation invocation)
        {
            if (_closed) return null;
            return await Dispatcher.InvokeAsync(() =>
            {
                if (_closed) return null;
                var dialog = new SshConnectionDialog(invocation) { Owner = this };
                return dialog.ShowDialog() == true ? dialog.Result : null;
            }).Task;
        }

        private void OnOverlayStateChanged(bool active, string status)
        {
            _ = Dispatcher.BeginInvoke(new System.Action(() =>
            {
                if (_closed) return;
                DisconnectSshButton.IsEnabled = active;
                SurfaceStatus.Text = status;
                if (_session != null) QueueTerminalFocus(_session);
            }));
        }

        private void AttachSession(TerminalSession session)
        {
            if (Viewport == null) throw new InvalidOperationException("The terminal viewport is unavailable.");
            session.ActiveOutboundChanged += queue =>
            {
                _ = Dispatcher.BeginInvoke(new System.Action(() =>
                {
                    if (_closed || Viewport == null || _session != session) return;
                    Viewport.DetachSessionInput();
                    Viewport.AttachSessionInput(queue, queue.Generation, message => SurfaceStatus.Text = "Input stopped: " + message);
                    QueueTerminalFocus(session);
                }), DispatcherPriority.Input);
            };
            var outbound = session.Outbound;
            Viewport.AttachSessionInput(outbound, outbound.Generation, message =>
            {
                if (!_closed && _session == session) SurfaceStatus.Text = "Input stopped: " + message;
            });
            _ = ObserveSessionCompletionAsync(session);
        }

        private void QueueTerminalFocus(TerminalSession session)
        {
            _ = Dispatcher.BeginInvoke(new System.Action(() =>
            {
                if (!_closed && _session == session) Viewport?.FocusTerminal();
            }), DispatcherPriority.Input);
        }

        private void ResetSample_Click(object sender, RoutedEventArgs e)
        {
            if (_session != null)
            {
                SurfaceStatus.Text = "Reset is unavailable while a terminal session is running.";
                return;
            }
            Viewport?.ResetDemo();
            QueueSurfaceStatusRefresh();
        }

        private async System.Threading.Tasks.Task ObserveSessionCompletionAsync(TerminalSession session)
        {
            try
            {
                var result = await session.Completion;
                if (_closed || _session != session) return;
                Viewport?.DetachSessionInput();
                var exit = result.ExitCode.HasValue ? $", exit {result.ExitCode.Value}" : string.Empty;
                var name = _activeSessionName ?? _activeProfile?.DisplayName ?? "Terminal";
                SurfaceStatus.Text = $"{name} session ended: {result.Kind}{exit}. Scrollback remains available; Start profile or Start SSH opens a new session.";
            }
            catch (Exception ex) when (!_closed)
            {
                SurfaceStatus.Text = "Terminal session failed: " + ex.Message;
            }
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
            if (_session != null && (_session.State == TerminalSessionState.RunningRoot || _session.State == TerminalSessionState.RunningOverlay))
                SurfaceStatus.Text += $" | input generation {_session.Outbound.Generation}, {_session.State}";
            if (_activeProfile != null) SurfaceStatus.Text += " | " + _activeProfile.DisplayName;
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
