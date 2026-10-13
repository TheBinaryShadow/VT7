using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Security;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace VT7.Host
{
    // SL01.1: real pinned-library loopback connections, never an external SSH
    // service. The peers deliberately stop before host keys or authentication.
    internal static class SshLifecycleChecks
    {
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false);

        private sealed class Output : ITerminalOutputSink
        {
            internal long Bytes;
            public Task WriteAsync(TerminalOutputBlock block, CancellationToken cancellationToken)
            {
                Interlocked.Add(ref Bytes, block.Bytes.Length);
                return Task.CompletedTask;
            }
        }

        private sealed class Peer : IDisposable
        {
            private readonly TcpListener _listener = new TcpListener(IPAddress.Loopback, 0);
            private readonly CancellationTokenSource _stop = new CancellationTokenSource();
            private readonly TaskCompletionSource<bool> _release = NewCompletion();
            internal readonly TaskCompletionSource<bool> Accepted = NewCompletion();
            internal readonly TaskCompletionSource<bool> KeyExchange = NewCompletion();
            private readonly Task _worker;
            private TcpClient? _client;
            internal int Port { get; }

            internal Peer(string? banner = null, bool observeKeyExchange = false)
            {
                _listener.Start();
                Port = ((IPEndPoint)_listener.LocalEndpoint).Port;
                _worker = Run(banner, observeKeyExchange);
            }

            private async Task Run(string? banner, bool observeKeyExchange)
            {
                try
                {
                    _client = await _listener.AcceptTcpClientAsync().ConfigureAwait(false);
                    var stream = _client.GetStream();
                    if (banner != null)
                    {
                        var bytes = Utf8.GetBytes(banner + "\r\n");
                        await stream.WriteAsync(bytes, 0, bytes.Length).ConfigureAwait(false);
                    }
                    Accepted.TrySetResult(true);
                    if (observeKeyExchange)
                    {
                        var received = new List<byte>();
                        var buffer = new byte[1024];
                        while (received.Count < 8192)
                        {
                            var count = await stream.ReadAsync(buffer, 0, buffer.Length, _stop.Token).ConfigureAwait(false);
                            if (count == 0) throw new IOException("Loopback peer ended before KEXINIT.");
                            for (var index = 0; index < count; ++index) received.Add(buffer[index]);
                            var lineEnd = received.IndexOf(10);
                            // SSH packet: four-byte length, padding length, message type.
                            if (lineEnd >= 0 && received.Count > lineEnd + 6 && received[lineEnd + 6] == 20)
                            {
                                KeyExchange.TrySetResult(true);
                                break;
                            }
                        }
                    }
                    await _release.Task.ConfigureAwait(false);
                }
                catch (Exception error)
                {
                    if (!_stop.IsCancellationRequested)
                    {
                        Accepted.TrySetException(error);
                        KeyExchange.TrySetException(error);
                    }
                }
                finally { _client?.Dispose(); }
            }

            public void Dispose()
            {
                _stop.Cancel();
                _listener.Stop();
                _client?.Dispose();
                _release.TrySetResult(true);
                _worker.GetAwaiter().GetResult();
                _stop.Dispose();
            }
        }

        internal static async Task Run(StringBuilder report)
        {
            await PhasePolicy(report);
            await PhaseDeadline(report, keyExchange: false);
            await PhaseDeadline(report, keyExchange: true);
            await LateResolver(report, cancel: false);
            await LateResolver(report, cancel: true);
            await LateLocalSetup(report);
            await StartupDeadline(report);
            await CancelStartup(report, caller: true, keyExchange: false);
            await CancelStartup(report, caller: false, keyExchange: false);
            await CancelStartup(report, caller: true, keyExchange: true);
            await InvalidProtocol(report);
            await CloseStartingOverlay(report);
            await FaultedQueueRecovery(report);
            await CloseStartingWindow(report);
            var profiles = new List<TerminalProfile> { TerminalProfile.CreateCommandPrompt() };
            var windowsPowerShell = TerminalProfile.CreateWindowsPowerShell(cleanProfile: true);
            if (windowsPowerShell.IsWindows7Qualified) profiles.Add(windowsPowerShell);
            else report.AppendLine("SKIP: Windows PowerShell interactive version is outside the qualified 5.1 scope.");
            try
            {
                var powerShell = TerminalProfile.CreatePowerShell7(cleanProfile: true);
                if (powerShell.IsWindows7Qualified) profiles.Add(powerShell);
                else report.AppendLine("SKIP: PowerShell interactive version is outside the qualified 7.2.24 scope.");
            }
            catch (FileNotFoundException) { report.AppendLine("SKIP: PowerShell 7 is not installed."); }
            foreach (var profile in profiles)
            {
                report.AppendLine("CHECK: SL01.1 typed " + profile.Id + " refused connection.");
                await TypedRecovery(profile, cancel: false);
                report.AppendLine("CHECK: SL01.1 typed " + profile.Id + " cancellation during startup.");
                await TypedRecovery(profile, cancel: true);
                report.AppendLine("PASS: SL01.1 typed " + profile.Id + " refused connection and connecting-disconnect recover the same local shell with status 255.");
                if (profile.Kind == TerminalProfileKind.CommandPrompt)
                {
                    await TypedRecovery(profile, cancel: false, timeout: true);
                    report.AppendLine("PASS: SL01.2 typed command-prompt startup timeout preserves the original shell PID and returns status 255 using production limits.");
                }
            }
            report.AppendLine("PASS: SL01.1 uses loopback peers only; no host-key trust, authentication or external server fixture required.");
        }

        private static async Task PhasePolicy(StringBuilder report)
        {
            var budget = TimeSpan.FromMilliseconds(150);
            var phases = new[] { SshStartupPhase.KnownHosts, SshStartupPhase.Credentials,
                SshStartupPhase.Authentication, SshStartupPhase.Pty, SshStartupPhase.TrustUpdate };
            foreach (var phase in phases)
            {
                var clock = new SshStartupDeadline(budget, CancellationToken.None);
                try
                {
                    clock.Enter(phase);
                    await WaitFor(() => clock.Token.IsCancellationRequested);
                    Require(clock.ExpiredCategory == SshStartupDeadline.Name(phase) + " timeout" &&
                        !clock.TryEnter(SshStartupPhase.Identification), "expired phase cannot advance");
                    var rejected = false;
                    try { clock.Check(); }
                    catch (SshTransportException error) { rejected = error.Category == clock.ExpiredCategory; }
                    Require(rejected, "late synchronous phase result is rejected");
                }
                finally { await clock.StopAsync(); }
            }
            using var caller = new CancellationTokenSource();
            var paused = new SshStartupDeadline(budget, caller.Token);
            try
            {
                paused.Enter(SshStartupPhase.Identification);
                paused.Pause();
                await Task.Delay(400);
                Require(!paused.Token.IsCancellationRequested && paused.ExpiredCategory == null,
                    "human decision has no network deadline");
                paused.Enter(SshStartupPhase.Authentication);
                Require(!paused.TryAdvance(SshStartupPhase.Identification, SshStartupPhase.KeyExchange) &&
                    !paused.TryAdvance(SshStartupPhase.KeyExchange, SshStartupPhase.Authentication) &&
                    paused.CurrentCategory == SshStartupDeadline.Name(SshStartupPhase.Authentication),
                    "stale callbacks cannot reset a later phase");
                paused.Pause();
                caller.Cancel();
                var cancelled = false;
                try { paused.Check(); }
                catch (OperationCanceledException) { cancelled = true; }
                Require(cancelled, "caller cancellation remains active during a human decision");
            }
            finally { await paused.StopAsync(); }
            Require(paused.Token.IsCancellationRequested &&
                !paused.TryAdvance(SshStartupPhase.KeyExchange, SshStartupPhase.Authentication),
                "in-flight callback can read a retired token without reviving the watchdog");
            var transitions = new SshStartupDeadline(TimeSpan.FromMilliseconds(700), CancellationToken.None);
            try
            {
                transitions.Enter(SshStartupPhase.Identification);
                await Task.Delay(250);
                Require(transitions.TryAdvance(SshStartupPhase.Identification, SshStartupPhase.KeyExchange),
                    "identification advances the phase");
                await Task.Delay(500);
                transitions.Check();
                Require(transitions.ExpiredCategory == null,
                    "earlier phase deadline cannot expire the current phase");
                transitions.Pause();
            }
            finally { await transitions.StopAsync(); }
            report.AppendLine("PASS: SL01.2 deadline policy rejects late local/authentication/PTY results, preserves paused human decisions and ignores stale phase callbacks; this is policy coverage, not a stalled authenticated server test.");
        }

        private static async Task PhaseDeadline(StringBuilder report, bool keyExchange)
        {
            using var peer = new Peer(keyExchange ? "SSH-2.0-VT7-SL01" : null, keyExchange);
            using var transport = new SshNetTransport(Options(peer.Port),
                knownHostsLoader: () => new KnownHostsStoreSnapshot(Array.Empty<KnownHostsSourceSnapshot>()),
                diagnosticConnectionTimeout: TimeSpan.FromSeconds(2),
                diagnosticPhaseTimeout: TimeSpan.FromMilliseconds(400));
            var output = new Output();
            var startup = transport.StartAsync(Context(), output, CancellationToken.None);
            await Deadline(keyExchange ? peer.KeyExchange.Task : peer.Accepted.Task);
            SshTransportException? error = null;
            try { await Deadline(startup); }
            catch (SshTransportException failure) { error = failure; }
            var phase = keyExchange ? SshStartupPhase.KeyExchange : SshStartupPhase.Identification;
            Require(error?.Category == SshStartupDeadline.Name(phase) + " timeout" &&
                transport.State == TerminalTransportState.Failed && output.Bytes == 0 &&
                (await transport.Completion).Kind == TerminalTransportResultKind.ConnectionFailure,
                "phase expiry is failure, not caller cancellation or clean EOF");
            await Deadline(transport.CloseAsync(TerminalCloseReason.Failed, CancellationToken.None));
            report.AppendLine("PASS: SL01.2 pinned-library " + (keyExchange ? "key-exchange" : "identification") +
                " deadline joins startup and reports the expired phase without a late running state.");
        }

        private static async Task LateResolver(StringBuilder report, bool cancel)
        {
            var entered = NewCompletion();
            var release = new TaskCompletionSource<IPAddress[]>(TaskCreationOptions.RunContinuationsAsynchronously);
            CancellationToken resolverToken = default;
            using var secret = new SecureString();
            secret.AppendChar('x');
            using var caller = new CancellationTokenSource();
            using var transport = new SshNetTransport(new SshConnectionOptions("sl01.invalid", 22,
                "sl01-fixture", string.Empty, SshAuthenticationKind.Password, null, secret, SshAddressFamily.IPv4),
                diagnosticPhaseTimeout: TimeSpan.FromMilliseconds(200), diagnosticResolver: (_, token) =>
                { resolverToken = token; entered.TrySetResult(true); return release.Task; });
            var output = new Output();
            var startup = transport.StartAsync(Context(), output, caller.Token);
            Task? close = null;
            try
            {
                await Deadline(entered.Task);
                if (cancel) { caller.Cancel(); close = transport.CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None); }
                await WaitFor(() => resolverToken.IsCancellationRequested);
                Require(!startup.IsCompleted && (close == null || !close.IsCompleted), "pending resolver remains owned");
            }
            finally { release.TrySetResult(new[] { IPAddress.Loopback }); }
            if (cancel)
            {
                await Deadline(close!);
                await ExpectCancelled(startup);
                Require(transport.State == TerminalTransportState.Closed &&
                    (await transport.Completion).Kind == TerminalTransportResultKind.Cancelled,
                    "resolver cancellation preserves close classification");
            }
            else
            {
                SshTransportException? error = null;
                try { await Deadline(startup); }
                catch (SshTransportException failure) { error = failure; }
                Require(error?.Category == "address-family resolution timeout" &&
                    transport.State == TerminalTransportState.Failed &&
                    (await transport.Completion).Kind == TerminalTransportResultKind.ConnectionFailure,
                    "late resolver cannot begin a connection");
            }
            Require(output.Bytes == 0, "late resolver output isolation");
            report.AppendLine("PASS: SL01.2 late resolver " + (cancel ? "cancellation" : "deadline") +
                " joins the pending request and rejects its result before creating an SSH client; OS resolver completion latency is not bounded by this test.");
        }

        private static async Task LateLocalSetup(StringBuilder report)
        {
            using var peer = new Peer();
            using var transport = new SshNetTransport(Options(peer.Port), knownHostsLoader: () =>
            {
                Thread.Sleep(500);
                return new KnownHostsStoreSnapshot(Array.Empty<KnownHostsSourceSnapshot>());
            }, diagnosticPhaseTimeout: TimeSpan.FromMilliseconds(200));
            var output = new Output();
            SshTransportException? error = null;
            try { await Deadline(transport.StartAsync(Context(), output, CancellationToken.None)); }
            catch (SshTransportException failure) { error = failure; }
            Require(error?.Category == "known-host store loading timeout" && !peer.Accepted.Task.IsCompleted &&
                transport.State == TerminalTransportState.Failed && output.Bytes == 0,
                "late synchronous local setup cannot create a connection");
            report.AppendLine("PASS: SL01.2 late synchronous known-host loading is joined and rejected before networking; local filesystem latency is not forcibly interrupted.");
        }

        private static SshConnectionOptions Options(int port)
        {
            using var secret = new SecureString();
            foreach (var character in "SL01_PRIVATE_SENTINEL") secret.AppendChar(character);
            secret.MakeReadOnly();
            return new SshConnectionOptions("127.0.0.1", port, "sl01-fixture", string.Empty,
                SshAuthenticationKind.Password, null, secret, SshAddressFamily.IPv4);
        }

        private static SshNetTransport Transport(int port, double seconds = 2) =>
            new SshNetTransport(Options(port), diagnosticConnectionTimeout: TimeSpan.FromSeconds(seconds));

        private static async Task StartupDeadline(StringBuilder report)
        {
            using var peer = new Peer();
            using var transport = Transport(peer.Port, 0.5);
            var output = new Output();
            var watch = Stopwatch.StartNew();
            SshTransportException? error = null;
            try { await Deadline(transport.StartAsync(Context(), output, CancellationToken.None)); }
            catch (SshTransportException failure) { error = failure; }
            Require(peer.Accepted.Task.Status == TaskStatus.RanToCompletion && error?.Category == "DNS, TCP or SSH identification timeout" &&
                transport.State == TerminalTransportState.Failed && output.Bytes == 0 &&
                (await transport.Completion).Kind == TerminalTransportResultKind.ConnectionFailure && watch.ElapsedMilliseconds < 6000,
                "stalled identification deadline and safe timeout category");
            Require(!error!.Message.Contains("SL01_PRIVATE_SENTINEL"), "timeout disclosure");
            report.AppendLine("PASS: SL01.1 accepted TCP peer with no SSH banner reaches the configured deadline and fails without terminal output.");
        }

        private static async Task CancelStartup(StringBuilder report, bool caller, bool keyExchange)
        {
            using var peer = new Peer(keyExchange ? "SSH-2.0-VT7-SL01" : null, keyExchange);
            using var cancellation = new CancellationTokenSource();
            using var transport = Transport(peer.Port);
            var output = new Output();
            var startup = transport.StartAsync(Context(), output, cancellation.Token);
            await Deadline(keyExchange ? peer.KeyExchange.Task : peer.Accepted.Task);
            if (caller) cancellation.Cancel();
            var firstClose = transport.CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None);
            var secondClose = transport.CloseAsync(TerminalCloseReason.Normal, CancellationToken.None);
            Require(ReferenceEquals(firstClose, secondClose), "shared close operation");
            await Deadline(firstClose);
            await ExpectCancelled(startup);
            Require(transport.State == TerminalTransportState.Closed && output.Bytes == 0 &&
                (await transport.Completion).Kind == TerminalTransportResultKind.Cancelled,
                "cancelled startup cannot publish a running transport or failure EOF");
            report.AppendLine("PASS: SL01.1 " + (keyExchange ? "stalled KEX" : caller ? "caller cancellation" : "explicit close during startup") +
                " joins startup and idempotent close without a late running state.");
        }

        private static async Task InvalidProtocol(StringBuilder report)
        {
            using var peer = new Peer("SSH-1.0-VT7-SL01");
            using var transport = Transport(peer.Port);
            var output = new Output();
            var failed = false;
            try { await Deadline(transport.StartAsync(Context(), output, CancellationToken.None)); }
            catch (SshTransportException error) { failed = error.Category == "SSH connection"; }
            Require(failed && output.Bytes == 0 &&
                (await transport.Completion).Kind == TerminalTransportResultKind.ConnectionFailure,
                "protocol disconnect cannot be a clean EOF");
            report.AppendLine("PASS: SL01.1 unsupported server protocol fails with a bounded category and never reports a clean session end.");
        }

        private static async Task CloseStartingOverlay(StringBuilder report)
        {
            using var peer = new Peer();
            using var document = new TerminalDocument(loadDemonstration: false);
            using var root = new FakeTerminalTransport("SL01 local root");
            using var session = new TerminalSession(document, root);
            await session.StartAsync();
            using var overlay = Transport(peer.Port);
            var startup = session.StartOverlayAsync(overlay);
            await Deadline(peer.Accepted.Task);
            await Deadline(session.CloseAsync(TerminalCloseReason.Cancelled));
            await ExpectCancelled(startup);
            Require(session.State == TerminalSessionState.Closed && root.State == TerminalTransportState.Closed &&
                overlay.State == TerminalTransportState.Closed, "closing session cannot revive its local root");
            report.AppendLine("PASS: SL01.1 session close owns a connecting overlay and cannot restore a closed root.");
        }

        private sealed class FailingTransport : ITerminalTransport
        {
            private readonly TaskCompletionSource<TerminalTransportResult> _completion =
                new TaskCompletionSource<TerminalTransportResult>(TaskCreationOptions.RunContinuationsAsynchronously);
            public Guid TransportId { get; } = Guid.NewGuid();
            public long Generation { get; private set; }
            public TerminalTransportState State { get; private set; }
            public Task<TerminalTransportResult> Completion => _completion.Task;
            public Task StartAsync(TerminalStartContext context, ITerminalOutputSink sink, CancellationToken token)
            { Generation = context.Generation; State = TerminalTransportState.Running; return Task.CompletedTask; }
            public Task WriteAsync(SessionOutboundOperation operation, CancellationToken token)
            {
                State = TerminalTransportState.Failed;
                _completion.TrySetResult(new TerminalTransportResult(TerminalTransportResultKind.ConnectionFailure));
                throw new IOException("Synthetic closed output channel.");
            }
            public Task CompleteAsync(CancellationToken token) => Task.CompletedTask;
            public Task CloseAsync(TerminalCloseReason reason, CancellationToken token) => Task.CompletedTask;
            public void Dispose() { }
        }

        private static async Task FaultedQueueRecovery(StringBuilder report)
        {
            using var document = new TerminalDocument(loadDemonstration: false);
            using var root = new FakeTerminalTransport("SL01 local root");
            using var session = new TerminalSession(document, root);
            await session.StartAsync();
            using var overlay = new FailingTransport();
            await session.StartOverlayAsync(overlay);
            var queue = session.Outbound;
            Enqueue(session, "discarded");
            try { await Deadline(queue.Completion); }
            catch (IOException) { }
            Require(queue.Completion.IsFaulted, "faulted outbound control");
            await Deadline(session.StopOverlayAsync(TerminalCloseReason.Failed));
            Require(session.State == TerminalSessionState.RunningRoot && !queue.IsCurrent(queue.Generation) &&
                root.Received.Length == 0,
                "queue failure cannot prevent root recovery or replay old input");
            await session.CloseAsync();
            report.AppendLine("PASS: SL01.1 failed outbound queue is retired, old input is not replayed, and the original root recovers.");
        }

        private static async Task CloseStartingWindow(StringBuilder report)
        {
            using var peer = new Peer();
            using var transport = Transport(peer.Port);
            var window = new MainWindow { Opacity = 0, ShowActivated = false, ShowInTaskbar = false };
            var closed = NewCompletion();
            window.Closed += (_, _) => closed.TrySetResult(true);
            try
            {
                window.Show();
                await window.Dispatcher.InvokeAsync(() => { }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
                Require(window.Viewport != null, "window lifecycle fixture viewport");
                var startup = window.StartTransportForLifecycleTestAsync(transport);
                await Deadline(peer.Accepted.Task);
                window.Close();
                await Deadline(closed.Task);
                await Deadline(startup);
                Require(transport.State == TerminalTransportState.Closed && window.Viewport == null,
                    "closing window joins its pending SSH session before releasing presentation");
            }
            finally { if (!closed.Task.IsCompleted) window.Close(); }
            report.AppendLine("PASS: SL01.1 closing a window during SSH startup joins cancellation before destroying its viewport.");
        }

        private static async Task TypedRecovery(TerminalProfile profile, bool cancel, bool timeout = false)
        {
            using var peer = cancel || timeout ? new Peer() : null;
            var port = peer?.Port ?? ClosedPort();
            using var document = new TerminalDocument(loadDemonstration: false);
            using var coordinator = SshOverlayCoordinator.TryCreate(profile,
                _ => Task.FromResult<SshConnectionOptions?>(Options(port)),
                (_, _) => throw new InvalidOperationException("Unexpected loopback trust prompt."),
                (_, _) => throw new InvalidOperationException("Unexpected loopback management prompt."))
                ?? throw new InvalidOperationException("Bundled shim is missing.");
            var root = new WinPtyTransport(coordinator.Configure(profile));
            using var session = new TerminalSession(document, root);
            await session.StartAsync();
            coordinator.Attach(session, root.Snapshot.ProcessId);
            var rootProcess = root.Snapshot.ProcessId;
            var readyMarker = "SL01_READY_" + Guid.NewGuid().ToString("N");
            var ready = session.WaitForCommittedOutputAsync(session.RootGeneration, readyMarker);
            Enqueue(session, profile.Kind == TerminalProfileKind.CommandPrompt ? "echo " + readyMarker + "\r" :
                "Write-Output '" + readyMarker + "'\r");
            await Deadline(ready, "local shell readiness");
            Enqueue(session, "ssh -p " + port + " sl01-fixture@127.0.0.1\r");
            if (peer != null)
            {
                await Deadline(peer.Accepted.Task, "typed loopback accept");
                if (cancel) await Deadline(coordinator.DisconnectAsync(), "typed startup disconnect", 35000);
            }
            var marker = "SL01_RETURN_" + Guid.NewGuid().ToString("N");
            await WaitFor(() => session.State == TerminalSessionState.RunningRoot && !coordinator.IsOverlayRunning &&
                session.Outbound.Generation > 1, timeout ? 35000 : 12000);
            var committed = session.WaitForCommittedOutputAsync(session.RootGeneration, marker + "_255");
            Enqueue(session, profile.Kind == TerminalProfileKind.CommandPrompt ? "echo " + marker + "_%ERRORLEVEL%\r" :
                "Write-Output ('" + marker + "_' + $LASTEXITCODE)\r");
            await Deadline(committed, "typed local status 255");
            Require(root.Snapshot.ProcessId == rootProcess && root.State == TerminalTransportState.Running,
                "typed failure restarted or lost the original root");
            await session.CloseAsync();
        }

        private static int ClosedPort()
        {
            var listener = new TcpListener(IPAddress.Loopback, 0);
            listener.Start();
            var port = ((IPEndPoint)listener.LocalEndpoint).Port;
            listener.Stop();
            return port;
        }

        private static TerminalStartContext Context() => new TerminalStartContext(Guid.NewGuid(), 1, 80, 24);
        private static TaskCompletionSource<bool> NewCompletion() =>
            new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        private static void Enqueue(TerminalSession session, string text) =>
            Require(session.Outbound.TryEnqueue(session.Outbound.Generation,
                SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, Utf8.GetBytes(text))) == SessionEnqueueResult.Accepted,
                "lifecycle outbound enqueue");
        private static async Task ExpectCancelled(Task task)
        {
            var cancelled = false;
            try { await Deadline(task); }
            catch (OperationCanceledException) { cancelled = true; }
            Require(cancelled, "startup cancellation must be observable");
        }
        private static async Task Deadline(Task task, string phase = "owned lifecycle operation", int milliseconds = 12000)
        {
            if (await Task.WhenAny(task, Task.Delay(milliseconds)) != task)
                throw new TimeoutException("SL01.1 diagnostic watchdog expired at " + phase + ".");
            await task;
        }
        private static async Task WaitFor(Func<bool> condition, int milliseconds = 12000)
        {
            var watch = Stopwatch.StartNew();
            while (!condition())
            {
                if (watch.ElapsedMilliseconds > milliseconds) throw new TimeoutException("SL01 lifecycle state transition timed out.");
                await Task.Delay(20);
            }
        }
        private static void Require(bool condition, string check)
        { if (!condition) throw new InvalidOperationException("SL01.1 check failed: " + check + "."); }
    }
}
