using Renci.SshNet;
using Renci.SshNet.Common;
using System;
using System.IO;
using System.Net.Sockets;
using System.Net;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal sealed class SshNetTransportSnapshot
    {
        internal SshNetTransportSnapshot(long outputBytes, long outputBlocks, long inputBytes,
            long inputOperations, long resizeOperations, uint columns, uint rows, string stage,
            string keyExchange, string hostKey, string clientCipher, string serverCipher)
        {
            OutputBytes = outputBytes;
            OutputBlocks = outputBlocks;
            InputBytes = inputBytes;
            InputOperations = inputOperations;
            ResizeOperations = resizeOperations;
            Columns = columns;
            Rows = rows;
            Stage = stage;
            KeyExchange = keyExchange;
            HostKey = hostKey;
            ClientCipher = clientCipher;
            ServerCipher = serverCipher;
        }

        internal long OutputBytes { get; }
        internal long OutputBlocks { get; }
        internal long InputBytes { get; }
        internal long InputOperations { get; }
        internal long ResizeOperations { get; }
        internal uint Columns { get; }
        internal uint Rows { get; }
        internal string Stage { get; }
        internal string KeyExchange { get; }
        internal string HostKey { get; }
        internal string ClientCipher { get; }
        internal string ServerCipher { get; }
    }

    internal sealed class SshTransportException : Exception
    {
        internal SshTransportException(string category, Exception? inner = null)
            : base("SSH connection failed during " + category + ".", inner) => Category = category;

        internal string Category { get; }
    }

    internal sealed class SshNetTransport : ITerminalTransport
    {
        private const int MaximumOutputChunk = 64 * 1024;
        private const int ShellBufferSize = 1024 * 1024;
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false);

        private readonly object _gate = new object();
        private readonly SemaphoreSlim _writeGate = new SemaphoreSlim(1, 1);
        private readonly SemaphoreSlim _finishGate = new SemaphoreSlim(1, 1);
        private readonly CancellationTokenSource _lifetime = new CancellationTokenSource();
        private readonly TaskCompletionSource<TerminalTransportResult> _completion =
            new TaskCompletionSource<TerminalTransportResult>(TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly TaskCompletionSource<bool> _shellClosed =
            new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly SshConnectionOptions _options;
        private readonly HostTrustPromptHandler? _trustPrompt;
        private readonly HostKeyProblemHandler? _hostKeyProblem;
        private readonly Func<KnownHostsStoreSnapshot> _knownHostsLoader;
        private readonly bool _observeCertificateKeyExchange;
        private ITerminalOutputSink? _output;
        private SshClient? _client;
        private ShellStream? _stream;
        private PrivateKeyFile? _privateKey;
        private Task? _readerTask;
        private Task? _startTask;
        private Task? _closeTask;
        private Exception? _streamError;
        private readonly TimeSpan _connectionTimeout;
        private readonly TimeSpan _phaseTimeout;
        private readonly Func<string, CancellationToken, Task<IPAddress[]>> _resolveAddresses;
        private SshStartupDeadline? _startupDeadline;
        private CancellationTokenRegistration _callerCancellation;
        private TerminalCloseReason? _closeReason;
        private long _nextOutputSequence;
        private long _outputBytes;
        private long _outputBlocks;
        private long _inputBytes;
        private long _inputOperations;
        private long _resizeOperations;
        private uint _columns;
        private uint _rows;
        private string _stage = "created";
        private string _keyExchange = string.Empty;
        private string _hostKey = string.Empty;
        private string _clientCipher = string.Empty;
        private string _serverCipher = string.Empty;
        private bool _hostKeySeen;
        private bool _hostKeyTrusted;
        internal bool CertificatePresented { get; private set; }
        // Diagnostic observation only: these bytes precede signature validation
        // and must never be treated as an authenticated trust callback.
        internal HostKeyEventArgs? KeyExchangeCertificate { get; private set; }
        internal KnownHostTrustDecision? TrustDecision => _trustDecision;
        private KnownHostsStoreSnapshot? _knownHosts;
        private string? _knownHostToken;
        private KnownHostTrustDecision? _trustDecision;
        private PresentedHostKey? _presentedHostKey;
        private KnownHostConnectionPin? _oneConnectionPin;
        private Guid _sessionId;
        private long _connectionGeneration;
        private long _promptGeneration;
        private bool _disposed;

        internal SshNetTransport(SshConnectionOptions options, HostTrustPromptHandler? trustPrompt = null,
            HostKeyProblemHandler? hostKeyProblem = null, Func<KnownHostsStoreSnapshot>? knownHostsLoader = null,
            bool observeCertificateKeyExchange = false, TimeSpan? diagnosticConnectionTimeout = null,
            TimeSpan? diagnosticPhaseTimeout = null,
            Func<string, CancellationToken, Task<IPAddress[]>>? diagnosticResolver = null)
        {
            _options = options ?? throw new ArgumentNullException(nameof(options));
            _trustPrompt = trustPrompt;
            _hostKeyProblem = hostKeyProblem;
            // Only internal diagnostics supply an isolated store. Ordinary sessions
            // always use the default OpenSSH locations; no production CLI override.
            _knownHostsLoader = knownHostsLoader ?? OpenSshKnownHostsStore.LoadDefault;
            _observeCertificateKeyExchange = observeCertificateKeyExchange;
            _connectionTimeout = diagnosticConnectionTimeout ?? TimeSpan.FromSeconds(15);
            if (_connectionTimeout <= TimeSpan.Zero || _connectionTimeout > TimeSpan.FromSeconds(15))
                throw new ArgumentOutOfRangeException(nameof(diagnosticConnectionTimeout));
            _phaseTimeout = diagnosticPhaseTimeout ?? TimeSpan.FromSeconds(15);
            if (_phaseTimeout <= TimeSpan.Zero || _phaseTimeout > TimeSpan.FromSeconds(15))
                throw new ArgumentOutOfRangeException(nameof(diagnosticPhaseTimeout));
            // Windows 7's resolver has no supported cancellation API here. Join
            // the request and reject its late result rather than abandoning it.
            _resolveAddresses = diagnosticResolver ?? ((host, token) =>
                Task.Run(() => Dns.GetHostAddresses(host), token));
        }

        public Guid TransportId { get; } = Guid.NewGuid();
        public long Generation { get; private set; }
        public TerminalTransportState State { get; private set; } = TerminalTransportState.Created;
        public Task<TerminalTransportResult> Completion => _completion.Task;
        internal SshNetTransportSnapshot Snapshot => new SshNetTransportSnapshot(
            Interlocked.Read(ref _outputBytes), Interlocked.Read(ref _outputBlocks),
            Interlocked.Read(ref _inputBytes), Interlocked.Read(ref _inputOperations),
            Interlocked.Read(ref _resizeOperations), _columns, _rows, _stage,
            _keyExchange, _hostKey, _clientCipher, _serverCipher);

        public Task StartAsync(TerminalStartContext context, ITerminalOutputSink output, CancellationToken cancellationToken)
        {
            if (context == null) throw new ArgumentNullException(nameof(context));
            if (output == null) throw new ArgumentNullException(nameof(output));
            cancellationToken.ThrowIfCancellationRequested();
            lock (_gate)
            {
                if (_disposed) throw new ObjectDisposedException(nameof(SshNetTransport));
                if (State != TerminalTransportState.Created) throw new InvalidOperationException("Transport already started.");
                State = TerminalTransportState.Starting;
                Generation = context.Generation;
                _sessionId = context.SessionId;
                _columns = context.Columns;
                _rows = context.Rows;
                _output = output;
                // Register before network/authentication/PTY startup. Close joins
                // this worker before releasing any owned resources.
                _callerCancellation = cancellationToken.Register(() =>
                    _ = CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None));
                _startTask = Task.Run(() => StartCoreAsync(context, cancellationToken));
                return _startTask;
            }
        }

        private async Task StartCoreAsync(TerminalStartContext context, CancellationToken callerToken)
        {
            using var linked = CancellationTokenSource.CreateLinkedTokenSource(callerToken, _lifetime.Token);
            var cancellationToken = linked.Token;
            var startup = new SshStartupDeadline(_phaseTimeout, cancellationToken);
            _startupDeadline = startup;
            try
            {
                cancellationToken.ThrowIfCancellationRequested();
                _knownHostToken = OpenSshHostToken.Create(_options.Host, _options.Port);
                EnterStartupPhase(SshStartupPhase.Resolution);
                var connectionHost = await ResolveConnectionHostAsync(startup.Token).ConfigureAwait(false);
                startup.Check();
                var prompted = false;
                while (true)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    EnterStartupPhase(SshStartupPhase.KnownHosts);
                    _knownHosts = _knownHostsLoader();
                    startup.Check();
                    ResetAttemptState();
                    ++_connectionGeneration;
                    Exception? attemptError = null;
                    try
                    {
                        EnterStartupPhase(SshStartupPhase.Credentials);
                        var connection = CreateConnectionInfo(connectionHost);
                        startup.Check();
                        var client = new SshClient(connection) { KeepAliveInterval = TimeSpan.FromSeconds(5) };
                        client.HostKeyReceived += OnHostKeyReceived;
                        client.ServerIdentificationReceived += OnServerIdentification;
                        client.ErrorOccurred += OnStreamError;
                        _client = client;

                        EnterStartupPhase(SshStartupPhase.Identification);
                        await client.ConnectAsync(startup.Token).ConfigureAwait(false);
                        startup.Check();
                        cancellationToken.ThrowIfCancellationRequested();
                        if (!_hostKeySeen || !_hostKeyTrusted || !client.IsConnected || !client.ConnectionInfo.IsAuthenticated)
                            throw new SshTransportException(!_hostKeyTrusted ? "host-key verification" : "authentication");
                        break;
                    }
                    catch (Exception error)
                    {
                        attemptError = error;
                    }
                    cancellationToken.ThrowIfCancellationRequested();
                    startup.Check();

                    if (!prompted && CanPromptForUnknownHost())
                    {
                        var request = CreateTrustPromptRequest();
                        startup.Pause();
                        _stage = "host-key trust decision";
                        DisposeConnectionAttempt();
                        var response = await _trustPrompt!(request, cancellationToken).ConfigureAwait(false);
                        ValidateTrustPromptResponse(request, response, cancellationToken);
                        if (response.Action == HostTrustPromptAction.Cancel)
                            throw new SshTransportException("host-key verification cancelled", attemptError);
                        if (response.Action == HostTrustPromptAction.ConnectOnce)
                        {
                            EnterStartupPhase(SshStartupPhase.KnownHosts);
                            var current = OpenSshKnownHostsStore.Load(
                                _knownHosts!.Sources.Select(source => source.Definition));
                            startup.Check();
                            if (!string.Equals(current.Identity, request.StoreIdentity, StringComparison.Ordinal))
                                throw new SshTransportException("stale host-key decision");
                            _oneConnectionPin = new KnownHostConnectionPin(request.HostToken,
                                request.Presented, request.StoreIdentity);
                        }
                        else if (response.Action == HostTrustPromptAction.TrustAndConnect)
                        {
                            EnterStartupPhase(SshStartupPhase.TrustUpdate);
                            OpenSshKnownHostsWriter.AddPrimaryUserRecord(_knownHosts!,
                                request.HostToken, request.Presented);
                            startup.Check();
                            _oneConnectionPin = null;
                        }
                        else throw new SshTransportException("host-key decision");
                        prompted = true;
                        continue;
                    }

                    if (_hostKeyProblem != null && _trustDecision?.Result.State == KnownHostTrustState.Changed &&
                        _presentedHostKey != null && _knownHosts != null && _knownHostToken != null)
                    {
                        var problem = new HostKeyProblemRequest(Guid.NewGuid(), _knownHostToken,
                            _presentedHostKey, _trustDecision.Result, _knownHosts);
                        startup.Pause();
                        _stage = "host-key change review";
                        DisposeConnectionAttempt();
                        await _hostKeyProblem(problem, cancellationToken).ConfigureAwait(false);
                        throw new SshTransportException("changed host key; reconnect after review", attemptError);
                    }

                    throw attemptError ?? new SshTransportException("SSH connection");
                }

                var connectedClient = _client ?? throw new InvalidOperationException("The connected SSH client is unavailable.");

                _keyExchange = connectedClient.ConnectionInfo.CurrentKeyExchangeAlgorithm ?? string.Empty;
                _hostKey = connectedClient.ConnectionInfo.CurrentHostKeyAlgorithm ?? string.Empty;
                _clientCipher = connectedClient.ConnectionInfo.CurrentClientEncryption ?? string.Empty;
                _serverCipher = connectedClient.ConnectionInfo.CurrentServerEncryption ?? string.Empty;

                EnterStartupPhase(SshStartupPhase.Pty);
                var pixelWidth = context.PixelWidth == 0 ? checked(context.Columns * 8u) : context.PixelWidth;
                var pixelHeight = context.PixelHeight == 0 ? checked(context.Rows * 16u) : context.PixelHeight;
                _stream = connectedClient.CreateShellStream("xterm-256color", context.Columns, context.Rows,
                    pixelWidth, pixelHeight, ShellBufferSize);
                startup.Check();
                _stream.ErrorOccurred += OnStreamError;
                _stream.Closed += OnShellClosed;
                lock (_gate)
                {
                    // Stop the startup clock atomically with its final check;
                    // an expired PTY result cannot become a live session.
                    startup.Pause();
                    cancellationToken.ThrowIfCancellationRequested();
                    if (_closeReason.HasValue) throw new OperationCanceledException(cancellationToken);
                    State = TerminalTransportState.Running;
                }
                _stage = "running";
                _readerTask = Task.Run(ReadOutputLoop);
            }
            catch (Exception error)
            {
                var category = Classify(error);
                var cancelled = cancellationToken.IsCancellationRequested;
                await FinishAsync(new TerminalTransportResult(cancelled ? TerminalTransportResultKind.Cancelled :
                    TerminalTransportResultKind.ConnectionFailure, detail: category),
                    failed: !cancelled, disconnectClient: true).ConfigureAwait(false);
                if (cancelled) throw new OperationCanceledException(cancellationToken);
                if (error is SshTransportException transport && transport.Category == category) throw;
                throw new SshTransportException(category, error);
            }
            finally
            {
                _startupDeadline = null;
                await startup.StopAsync().ConfigureAwait(false);
            }
        }

        private void EnterStartupPhase(SshStartupPhase phase)
        {
            _startupDeadline!.Enter(phase);
            _stage = SshStartupDeadline.Name(phase);
        }

        private void OnServerIdentification(object? sender, SshIdentificationEventArgs args)
        {
            var startup = _startupDeadline;
            if (startup != null && startup.TryAdvance(SshStartupPhase.Identification, SshStartupPhase.KeyExchange))
                _stage = SshStartupDeadline.Name(SshStartupPhase.KeyExchange);
        }

        public async Task WriteAsync(SessionOutboundOperation operation, CancellationToken cancellationToken)
        {
            if (operation == null) throw new ArgumentNullException(nameof(operation));
            cancellationToken.ThrowIfCancellationRequested();
            using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, _lifetime.Token);
            await _writeGate.WaitAsync(linked.Token).ConfigureAwait(false);
            try
            {
                await Task.Run(() => WriteCore(operation), linked.Token).ConfigureAwait(false);
            }
            catch (Exception error) when (!(error is OperationCanceledException) && !_closeReason.HasValue)
            {
                await FinishAsync(new TerminalTransportResult(TerminalTransportResultKind.ConnectionFailure,
                    detail: Classify(error)), true, true).ConfigureAwait(false);
                throw new SshTransportException(Classify(error), error);
            }
            finally { _writeGate.Release(); }
        }

        private void WriteCore(SessionOutboundOperation operation)
        {
                if (State != TerminalTransportState.Running) throw new InvalidOperationException("SSH.NET transport is not running.");
                var stream = _stream ?? throw new InvalidOperationException("The SSH shell stream is unavailable.");
                if (operation.Kind == SessionOutboundKind.Resize)
                {
                    var width = operation.PixelWidth == 0 ? checked(operation.Columns * 8u) : operation.PixelWidth;
                    var height = operation.PixelHeight == 0 ? checked(operation.Rows * 16u) : operation.PixelHeight;
                    stream.ChangeWindowSize(operation.Columns, operation.Rows, width, height);
                    _columns = operation.Columns;
                    _rows = operation.Rows;
                    Interlocked.Increment(ref _resizeOperations);
                    return;
                }
                if (operation.Bytes.Length == 0) return;
                stream.Write(operation.Bytes, 0, operation.Bytes.Length);
                stream.Flush();
                Interlocked.Add(ref _inputBytes, operation.Bytes.Length);
                Interlocked.Increment(ref _inputOperations);
        }

        public async Task CompleteAsync(CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (State != TerminalTransportState.Running) return;
            await _writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try { await Task.Run(() => _stream?.Flush(), cancellationToken).ConfigureAwait(false); }
            finally { _writeGate.Release(); }
        }

        public Task CloseAsync(TerminalCloseReason reason, CancellationToken cancellationToken)
        {
            // A cancelled wait must not cancel ownership cleanup. All callers
            // join one close operation, including caller-token cancellation.
            lock (_gate)
            {
                if (_closeTask != null) return _closeTask;
                // Completion can be published just before a startup/reader
                // continuation finishes. Close still joins those workers and
                // the writer before Dispose can release their coordination.
                _closeReason = reason;
                if (!_completion.Task.IsCompleted) State = TerminalTransportState.Closing;
                _closeTask = Task.Run(() => CloseCoreAsync(reason));
                return _closeTask;
            }
        }

        private async Task CloseCoreAsync(TerminalCloseReason reason)
        {
            _lifetime.Cancel();
            Task? startup;
            Task? reader;
            lock (_gate)
            {
                startup = _startTask;
            }
            if (startup != null)
            {
                try { await startup.ConfigureAwait(false); }
                catch { /* StartCore owns failure completion and cleanup. */ }
            }
            lock (_gate)
            {
                reader = _readerTask;
            }
            if (_completion.Task.IsCompleted)
            {
                if (reader != null) await reader.ConfigureAwait(false);
                await _writeGate.WaitAsync().ConfigureAwait(false);
                _writeGate.Release();
                return;
            }

            await _writeGate.WaitAsync().ConfigureAwait(false);
            var shutdownFailed = false;
            try
            {
                if (_stream != null)
                {
                    _stream.ErrorOccurred -= OnStreamError;
                    _stream.Closed -= OnShellClosed;
                    _stream.Dispose();
                }
                _stream = null;
            }
            catch { shutdownFailed = true; }
            finally
            {
                _writeGate.Release();
            }

            var readerStopped = true;
            if (reader != null)
            {
                var finished = await Task.WhenAny(reader, Task.Delay(TimeSpan.FromSeconds(5))).ConfigureAwait(false);
                readerStopped = finished == reader;
                if (readerStopped) await reader.ConfigureAwait(false);
            }
            var kind = !readerStopped || shutdownFailed ? TerminalTransportResultKind.ForcedTermination :
                reason == TerminalCloseReason.Cancelled ? TerminalTransportResultKind.Cancelled : TerminalTransportResultKind.CleanEof;
            await FinishAsync(new TerminalTransportResult(kind), failed: !readerStopped || shutdownFailed, disconnectClient: true).ConfigureAwait(false);
        }

        private void ResetAttemptState()
        {
            _hostKeySeen = false;
            _hostKeyTrusted = false;
            _streamError = null;
            CertificatePresented = false;
            KeyExchangeCertificate = null;
            _trustDecision = null;
            _presentedHostKey = null;
        }

        private bool CanPromptForUnknownHost()
        {
            var decision = _trustDecision;
            return _trustPrompt != null && _presentedHostKey != null && decision != null &&
                decision.Result.State == KnownHostTrustState.Unknown &&
                (!decision.FingerprintSupplied || decision.FingerprintMatched);
        }

        private HostTrustPromptRequest CreateTrustPromptRequest()
        {
            var snapshot = _knownHosts ?? throw new InvalidOperationException("The known-host snapshot is unavailable.");
            var token = _knownHostToken ?? throw new InvalidOperationException("The known-host token is unavailable.");
            var presented = _presentedHostKey ?? throw new InvalidOperationException("The presented host key is unavailable.");
            var decision = _trustDecision ?? throw new InvalidOperationException("The host-trust decision is unavailable.");
            if (snapshot.Sources.Count == 0) throw new InvalidOperationException("The primary known-host source is unavailable.");
            var promptGeneration = ++_promptGeneration;
            return new HostTrustPromptRequest(Guid.NewGuid(), TransportId, _sessionId, Generation,
                _connectionGeneration, promptGeneration, token, _options.Username, presented,
                decision.FingerprintSupplied, decision.FingerprintMatched, snapshot.Identity,
                snapshot.Sources[0].Definition.Path);
        }

        private void ValidateTrustPromptResponse(HostTrustPromptRequest request,
            HostTrustPromptResponse response, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            lock (_gate)
            {
                if (_disposed || State != TerminalTransportState.Starting ||
                    request.TransportId != TransportId || request.SessionId != _sessionId ||
                    request.TransportGeneration != Generation ||
                    request.ConnectionGeneration != _connectionGeneration ||
                    request.PromptGeneration != _promptGeneration ||
                    response == null || response.RequestId != request.RequestId)
                    throw new SshTransportException("stale host-key decision");
            }
        }

        private void DisposeConnectionAttempt()
        {
            var client = _client;
            _client = null;
            if (client != null)
            {
                client.HostKeyReceived -= OnHostKeyReceived;
                client.ServerIdentificationReceived -= OnServerIdentification;
                client.ErrorOccurred -= OnStreamError;
                try { if (client.IsConnected) client.Disconnect(); }
                catch { }
                client.Dispose();
            }
            _privateKey?.Dispose();
            _privateKey = null;
        }

        private ConnectionInfo CreateConnectionInfo(string connectionHost)
        {
            AuthenticationMethod method;
            using (var secret = _options.CopySecret())
            {
                var value = SecretToString(secret);
                try
                {
                    if (_options.Authentication == SshAuthenticationKind.PrivateKey)
                    {
                        _privateKey = value.Length == 0
                            ? new PrivateKeyFile(_options.PrivateKeyPath!)
                            : new PrivateKeyFile(_options.PrivateKeyPath!, value);
                        method = new PrivateKeyAuthenticationMethod(_options.Username, _privateKey);
                    }
                    else
                    {
                        method = new PasswordAuthenticationMethod(_options.Username, value);
                    }
                }
                finally
                {
                    value = string.Empty;
                }
            }
            var connection = new ConnectionInfo(connectionHost, _options.Port, _options.Username, method)
            {
                Timeout = _connectionTimeout,
                ChannelCloseTimeout = TimeSpan.FromSeconds(5),
                Encoding = Utf8,
            };
            if (_observeCertificateKeyExchange)
            {
                foreach (var name in connection.HostKeyAlgorithms.Keys.Where(key =>
                    key.EndsWith("-cert-v01@openssh.com", StringComparison.Ordinal)).ToArray())
                {
                    var factory = connection.HostKeyAlgorithms[name];
                    connection.HostKeyAlgorithms[name] = bytes =>
                    {
                        var algorithm = factory(bytes);
                        KeyExchangeCertificate = new HostKeyEventArgs(algorithm);
                        // Return the original pinned algorithm. Verification and
                        // callback ordering remain completely unchanged.
                        return algorithm;
                    };
                }
            }
            return connection;
        }

        private async Task<string> ResolveConnectionHostAsync(CancellationToken cancellationToken)
        {
            if (_options.AddressFamily == SshAddressFamily.Any) return _options.Host;
            var host = _options.Host;
            if (host.Length > 2 && host[0] == '[' && host[host.Length - 1] == ']')
                host = host.Substring(1, host.Length - 2);
            var required = _options.AddressFamily == SshAddressFamily.IPv4
                ? AddressFamily.InterNetwork : AddressFamily.InterNetworkV6;
            if (IPAddress.TryParse(host, out var literal))
            {
                if (literal.AddressFamily != required)
                    throw new SshTransportException("address-family resolution");
                return literal.ToString();
            }
            var addresses = await _resolveAddresses(host, cancellationToken).ConfigureAwait(false);
            _startupDeadline!.Check();
            var selected = addresses.FirstOrDefault(address => address.AddressFamily == required);
            if (selected == null) throw new SshTransportException("address-family resolution");
            return selected.ToString();
        }

        private void OnHostKeyReceived(object? sender, HostKeyEventArgs eventArgs)
        {
            _hostKeySeen = true;
            CertificatePresented = eventArgs.Certificate != null;
            try
            {
                var snapshot = _knownHosts ?? throw new InvalidOperationException("The known-host snapshot is unavailable.");
                var token = _knownHostToken ?? throw new InvalidOperationException("The known-host token is unavailable.");
                var presented = PresentedHostKey.Parse(eventArgs.HostKey);
                _presentedHostKey = presented;
                _trustDecision = DecideHostKey(eventArgs, token, snapshot,
                    _options.ExpectedHostKeyFingerprint, _oneConnectionPin);
                _hostKeyTrusted = _trustDecision.CanTrust;
            }
            catch (Exception error) when (error is FormatException || error is ArgumentException ||
                error is InvalidOperationException || error is CryptographicException)
            {
                _trustDecision = new KnownHostTrustDecision(
                    new KnownHostTrustResult(KnownHostTrustState.PolicyRejected,
                        "presented-host-key-invalid", Array.Empty<string>()),
                    _options.ExpectedHostKeyFingerprint.Length != 0, false, false,
                    "presented-key-policy-block");
                _hostKeyTrusted = false;
            }
            eventArgs.CanTrust = _hostKeyTrusted;
            var startup = _startupDeadline;
            if (_hostKeyTrusted && startup != null && State == TerminalTransportState.Starting)
            {
                if (startup.TryAdvance(SshStartupPhase.KeyExchange, SshStartupPhase.Authentication))
                    _stage = SshStartupDeadline.Name(SshStartupPhase.Authentication);
                if (startup.ExpiredCategory != null || startup.Token.IsCancellationRequested)
                    eventArgs.CanTrust = false;
                // A trusted rekey during authentication/channel startup still
                // uses normal policy; it must not reset the current deadline.
            }
        }

        internal static KnownHostTrustDecision DecideHostKey(HostKeyEventArgs eventArgs, string token,
            KnownHostsStoreSnapshot snapshot, string fingerprint, KnownHostConnectionPin? pin = null)
        {
            KnownHostCertificateFacts? certificate = null;
            if (eventArgs.Certificate != null)
            {
                var source = eventArgs.Certificate;
                certificate = new KnownHostCertificateFacts(source.Name, ReadCertificateBytes(source),
                    source.CertificateAuthorityKey,
                    source.Type == Renci.SshNet.Security.Certificate.CertificateType.Host,
                    source.ValidPrincipals, source.CriticalOptions.Count != 0,
                    source.ValidAfterUnixSeconds, source.ValidBeforeUnixSeconds);
            }
            return KnownHostTrustPolicy.Decide(token, PresentedHostKey.Parse(eventArgs.HostKey), snapshot,
                fingerprint, pin, certificate);
        }

        internal static byte[] ReadCertificateBytes(Renci.SshNet.Security.Certificate certificate)
        {
            // The pinned prerelease exposes the complete authenticated certificate
            // internally. Exact certificate revocation requires those bytes; fail
            // closed if a later SSH.NET build changes this boundary.
            var property = typeof(Renci.SshNet.Security.Certificate).GetProperty("Bytes",
                BindingFlags.Instance | BindingFlags.NonPublic);
            try
            {
                if (property?.PropertyType != typeof(byte[]) || property.GetValue(certificate) is not byte[] bytes)
                    throw new FormatException("certificate-bytes-unavailable");
                return (byte[])bytes.Clone();
            }
            catch (TargetInvocationException error)
            {
                throw new FormatException("certificate-bytes-unavailable", error);
            }
        }

        private void OnStreamError(object? sender, ExceptionEventArgs args) =>
            Interlocked.CompareExchange(ref _streamError, args.Exception, null);

        private void OnShellClosed(object? sender, EventArgs args) => _shellClosed.TrySetResult(true);

        private void ReadOutputLoop()
        {
            try
            {
                var stream = _stream ?? throw new InvalidOperationException("The SSH shell stream is unavailable.");
                var buffer = new byte[MaximumOutputChunk];
                while (true)
                {
                    var read = stream.Read(buffer, 0, buffer.Length);
                    if (read == 0) break;
                    var bytes = new byte[read];
                    Buffer.BlockCopy(buffer, 0, bytes, 0, read);
                    var sequence = Interlocked.Increment(ref _nextOutputSequence);
                    var sink = _output ?? throw new InvalidOperationException("The SSH output sink is unavailable.");
                    sink.WriteAsync(new TerminalOutputBlock(Generation, sequence, bytes), _lifetime.Token)
                        .GetAwaiter().GetResult();
                    Interlocked.Add(ref _outputBytes, read);
                    Interlocked.Increment(ref _outputBlocks);
                }

                if (!_closeReason.HasValue)
                {
                    // The pinned library dispatches Closed asynchronously after
                    // a real channel-close message, while Read may already return
                    // zero. Allow that notification to settle before treating a
                    // later connection disconnect as a failed remote shell exit.
                    Task.WhenAny(_shellClosed.Task, Task.Delay(TimeSpan.FromSeconds(5), _lifetime.Token))
                        .GetAwaiter().GetResult();
                    if (_closeReason.HasValue) return;
                    var error = _streamError;
                    var failed = !_shellClosed.Task.IsCompleted;
                    FinishAsync(new TerminalTransportResult(failed ? TerminalTransportResultKind.ConnectionFailure :
                        TerminalTransportResultKind.CleanEof,
                        detail: failed ? error != null ? Classify(error) : "SSH connection lost" : null), failed, true)
                        .GetAwaiter().GetResult();
                }
            }
            catch (Exception error)
            {
                if (!_closeReason.HasValue)
                    FinishAsync(new TerminalTransportResult(TerminalTransportResultKind.ConnectionFailure,
                        detail: Classify(error)), true, true).GetAwaiter().GetResult();
            }
        }

        private async Task FinishAsync(TerminalTransportResult result, bool failed, bool disconnectClient)
        {
            await _finishGate.WaitAsync().ConfigureAwait(false);
            try
            {
                if (_completion.Task.IsCompleted) return;
                lock (_gate)
                {
                    if (State == TerminalTransportState.Running) State = TerminalTransportState.Closing;
                }
                _callerCancellation.Dispose();
                _lifetime.Cancel();
                _output = null;
                var stream = _stream;
                _stream = null;
                try
                {
                    if (stream != null)
                    {
                        stream.ErrorOccurred -= OnStreamError;
                        stream.Closed -= OnShellClosed;
                        stream.Dispose();
                    }
                }
                catch { failed = true; }
                if (disconnectClient)
                {
                    var client = _client;
                    _client = null;
                    if (client != null)
                    {
                        client.HostKeyReceived -= OnHostKeyReceived;
                        client.ServerIdentificationReceived -= OnServerIdentification;
                        client.ErrorOccurred -= OnStreamError;
                        try { if (client.IsConnected) client.Disconnect(); }
                        catch { failed = true; }
                        try { client.Dispose(); }
                        catch { failed = true; }
                    }
                }
                try { _privateKey?.Dispose(); }
                catch { failed = true; }
                _privateKey = null;
                _options.Dispose();
                _stage = failed ? "failed" : "closed";
                lock (_gate) State = failed ? TerminalTransportState.Failed : TerminalTransportState.Closed;
                _completion.TrySetResult(failed && result.Kind == TerminalTransportResultKind.CleanEof
                    ? new TerminalTransportResult(TerminalTransportResultKind.ConnectionFailure, detail: "SSH cleanup") : result);
            }
            finally
            {
                _finishGate.Release();
            }
        }

        private string Classify(Exception error)
        {
            while (error is AggregateException aggregate && aggregate.InnerExceptions.Count == 1)
                error = aggregate.InnerExceptions[0];
            var startup = _startupDeadline;
            if (startup?.ExpiredCategory is string expired) return expired;
            if (error is KnownHostsMutationException mutation)
                return "known-host update " + mutation.Category;
            if (!_hostKeyTrusted && _hostKeySeen) return HostKeyFailureCategory();
            if (error is SshTransportException transport) return transport.Category;
            if (error is SshAuthenticationException) return "authentication";
            if (error is SshOperationTimeoutException || error is TimeoutException)
                return startup != null ? startup.CurrentCategory + " timeout" : "SSH operation timeout";
            if (error is SshConnectionException) return "SSH connection";
            if (error is SocketException socket) return "network connection " + socket.SocketErrorCode;
            if (error is OperationCanceledException) return "SSH operation cancelled";
            if (error is FileNotFoundException || error is IOException) return "local key or stream I/O";
            if (error is FormatException || error is ArgumentException || error is CryptographicException) return "authentication setup";
            return _stage;
        }

        private string HostKeyFailureCategory()
        {
            var decision = _trustDecision;
            if (decision == null) return "host-key verification";
            if (decision.Authorization == "explicit-fingerprint-mismatch") return "host-key fingerprint mismatch";
            switch (decision.Result.State)
            {
                case KnownHostTrustState.Unknown: return "unknown host-key verification";
                case KnownHostTrustState.Changed: return "changed host key";
                case KnownHostTrustState.Revoked: return "revoked host key";
                case KnownHostTrustState.Unreadable: return "known-host store";
                case KnownHostTrustState.PolicyRejected: return "host-key policy";
                default: return "host-key verification";
            }
        }

        private static string SecretToString(SecureString secret)
        {
            if (secret.Length == 0) return string.Empty;
            var pointer = Marshal.SecureStringToBSTR(secret);
            try { return Marshal.PtrToStringBSTR(pointer); }
            finally { Marshal.ZeroFreeBSTR(pointer); }
        }

        public void Dispose()
        {
            lock (_gate)
            {
                if (_disposed) return;
                _disposed = true;
            }
            try { CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None).GetAwaiter().GetResult(); }
            catch
            {
                _stream?.Dispose();
                _client?.Dispose();
                _privateKey?.Dispose();
                _options.Dispose();
            }
            var reader = _readerTask;
            if (reader != null && !reader.IsCompleted)
                _ = reader.ContinueWith(_ => DisposeCoordination(), CancellationToken.None,
                    TaskContinuationOptions.ExecuteSynchronously, TaskScheduler.Default);
            else DisposeCoordination();
        }

        private void DisposeCoordination()
        {
            _lifetime.Dispose();
            _writeGate.Dispose();
            _finishGate.Dispose();
        }
    }
}
