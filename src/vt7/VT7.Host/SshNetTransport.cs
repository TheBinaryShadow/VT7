using Renci.SshNet;
using Renci.SshNet.Common;
using System;
using System.IO;
using System.Net.Sockets;
using System.Net;
using System.Linq;
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
        private readonly SshConnectionOptions _options;
        private readonly HostTrustPromptHandler? _trustPrompt;
        private ITerminalOutputSink? _output;
        private SshClient? _client;
        private ShellStream? _stream;
        private PrivateKeyFile? _privateKey;
        private Task? _readerTask;
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
        private KnownHostsStoreSnapshot? _knownHosts;
        private string? _knownHostToken;
        private KnownHostTrustDecision? _trustDecision;
        private PresentedHostKey? _presentedHostKey;
        private KnownHostConnectionPin? _oneConnectionPin;
        private Guid _sessionId;
        private long _connectionGeneration;
        private long _promptGeneration;
        private bool _disposed;

        internal SshNetTransport(SshConnectionOptions options, HostTrustPromptHandler? trustPrompt = null)
        {
            _options = options ?? throw new ArgumentNullException(nameof(options));
            _trustPrompt = trustPrompt;
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

        public async Task StartAsync(TerminalStartContext context, ITerminalOutputSink output, CancellationToken cancellationToken)
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
            }

            try
            {
                _knownHostToken = OpenSshHostToken.Create(_options.Host, _options.Port);
                var connectionHost = await ResolveConnectionHostAsync(cancellationToken).ConfigureAwait(false);
                var prompted = false;
                while (true)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    _stage = "known-host store loading";
                    _knownHosts = OpenSshKnownHostsStore.LoadDefault();
                    ResetAttemptState();
                    ++_connectionGeneration;
                    Exception? attemptError = null;
                    try
                    {
                        _stage = "authentication setup";
                        var connection = CreateConnectionInfo(connectionHost);
                        var client = new SshClient(connection) { KeepAliveInterval = TimeSpan.FromSeconds(5) };
                        client.HostKeyReceived += OnHostKeyReceived;
                        _client = client;

                        _stage = "connection and host-key verification";
                        await client.ConnectAsync(cancellationToken).ConfigureAwait(false);
                        if (!_hostKeySeen || !_hostKeyTrusted || !client.IsConnected || !client.ConnectionInfo.IsAuthenticated)
                            throw new SshTransportException(!_hostKeyTrusted ? "host-key verification" : "authentication");
                        break;
                    }
                    catch (Exception error)
                    {
                        attemptError = error;
                    }

                    if (!prompted && CanPromptForUnknownHost())
                    {
                        var request = CreateTrustPromptRequest();
                        DisposeConnectionAttempt();
                        var response = await _trustPrompt!(request, cancellationToken).ConfigureAwait(false);
                        ValidateTrustPromptResponse(request, response, cancellationToken);
                        if (response.Action == HostTrustPromptAction.Cancel)
                            throw new SshTransportException("host-key verification cancelled", attemptError);
                        if (response.Action == HostTrustPromptAction.ConnectOnce)
                        {
                            var current = OpenSshKnownHostsStore.Load(
                                _knownHosts!.Sources.Select(source => source.Definition));
                            if (!string.Equals(current.Identity, request.StoreIdentity, StringComparison.Ordinal))
                                throw new SshTransportException("stale host-key decision");
                            _oneConnectionPin = new KnownHostConnectionPin(request.HostToken,
                                request.Presented, request.StoreIdentity);
                        }
                        else if (response.Action == HostTrustPromptAction.TrustAndConnect)
                        {
                            _stage = "known-host durable addition";
                            OpenSshKnownHostsWriter.AddPrimaryUserRecord(_knownHosts!,
                                request.HostToken, request.Presented);
                            _oneConnectionPin = null;
                        }
                        else throw new SshTransportException("host-key decision");
                        prompted = true;
                        continue;
                    }

                    throw attemptError ?? new SshTransportException("SSH connection");
                }

                var connectedClient = _client ?? throw new InvalidOperationException("The connected SSH client is unavailable.");

                _keyExchange = connectedClient.ConnectionInfo.CurrentKeyExchangeAlgorithm ?? string.Empty;
                _hostKey = connectedClient.ConnectionInfo.CurrentHostKeyAlgorithm ?? string.Empty;
                _clientCipher = connectedClient.ConnectionInfo.CurrentClientEncryption ?? string.Empty;
                _serverCipher = connectedClient.ConnectionInfo.CurrentServerEncryption ?? string.Empty;

                _stage = "remote PTY allocation";
                var pixelWidth = context.PixelWidth == 0 ? checked(context.Columns * 8u) : context.PixelWidth;
                var pixelHeight = context.PixelHeight == 0 ? checked(context.Rows * 16u) : context.PixelHeight;
                _stream = connectedClient.CreateShellStream("xterm-256color", context.Columns, context.Rows,
                    pixelWidth, pixelHeight, ShellBufferSize);
                lock (_gate) State = TerminalTransportState.Running;
                _stage = "running";
                _callerCancellation = cancellationToken.Register(() => _ = CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None));
                _readerTask = Task.Run(ReadOutputLoop);
            }
            catch (Exception error)
            {
                var category = Classify(error);
                await FinishAsync(new TerminalTransportResult(TerminalTransportResultKind.ConnectionFailure,
                    detail: category), failed: true, disconnectClient: true).ConfigureAwait(false);
                if (error is SshTransportException) throw;
                throw new SshTransportException(category, error);
            }
        }

        public async Task WriteAsync(SessionOutboundOperation operation, CancellationToken cancellationToken)
        {
            if (operation == null) throw new ArgumentNullException(nameof(operation));
            cancellationToken.ThrowIfCancellationRequested();
            await _writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
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
            finally
            {
                _writeGate.Release();
            }
        }

        public async Task CompleteAsync(CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            await _writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try { _stream?.Flush(); }
            finally { _writeGate.Release(); }
        }

        public async Task CloseAsync(TerminalCloseReason reason, CancellationToken cancellationToken)
        {
            Task? reader;
            lock (_gate)
            {
                if (!_closeReason.HasValue) _closeReason = reason;
                if (State != TerminalTransportState.Closed && State != TerminalTransportState.Failed)
                    State = TerminalTransportState.Closing;
                reader = _readerTask;
            }
            if (_completion.Task.IsCompleted)
            {
                if (reader != null) await reader.ConfigureAwait(false);
                return;
            }

            await _writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                _stream?.Dispose();
                _stream = null;
            }
            finally
            {
                _writeGate.Release();
            }

            var readerStopped = true;
            if (reader != null)
            {
                var finished = await Task.WhenAny(reader, Task.Delay(TimeSpan.FromSeconds(5), cancellationToken)).ConfigureAwait(false);
                readerStopped = finished == reader;
                if (readerStopped) await reader.ConfigureAwait(false);
            }
            var kind = !readerStopped ? TerminalTransportResultKind.ForcedTermination :
                reason == TerminalCloseReason.Cancelled ? TerminalTransportResultKind.Cancelled : TerminalTransportResultKind.CleanEof;
            await FinishAsync(new TerminalTransportResult(kind), failed: !readerStopped, disconnectClient: true).ConfigureAwait(false);
        }

        private void ResetAttemptState()
        {
            _hostKeySeen = false;
            _hostKeyTrusted = false;
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
            return new ConnectionInfo(connectionHost, _options.Port, _options.Username, method)
            {
                Timeout = TimeSpan.FromSeconds(15),
                ChannelCloseTimeout = TimeSpan.FromSeconds(5),
                Encoding = Utf8,
            };
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
            var addresses = await Task.Run(() => Dns.GetHostAddresses(host), cancellationToken).ConfigureAwait(false);
            var selected = addresses.FirstOrDefault(address => address.AddressFamily == required);
            if (selected == null) throw new SshTransportException("address-family resolution");
            return selected.ToString();
        }

        private void OnHostKeyReceived(object? sender, HostKeyEventArgs eventArgs)
        {
            _hostKeySeen = true;
            try
            {
                var snapshot = _knownHosts ?? throw new InvalidOperationException("The known-host snapshot is unavailable.");
                var token = _knownHostToken ?? throw new InvalidOperationException("The known-host token is unavailable.");
                var presented = PresentedHostKey.Parse(eventArgs.HostKey);
                _presentedHostKey = presented;
                _trustDecision = KnownHostTrustPolicy.Decide(token, presented, snapshot,
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
        }

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
                    FinishAsync(new TerminalTransportResult(TerminalTransportResultKind.CleanEof), false, true)
                        .GetAwaiter().GetResult();
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
                _stream?.Dispose();
                _stream = null;
                if (disconnectClient)
                {
                    var client = _client;
                    _client = null;
                    if (client != null)
                    {
                        client.HostKeyReceived -= OnHostKeyReceived;
                        try { if (client.IsConnected) client.Disconnect(); }
                        catch { failed = true; }
                        client.Dispose();
                    }
                }
                _privateKey?.Dispose();
                _privateKey = null;
                _options.Dispose();
                _stage = failed ? "failed" : "closed";
                lock (_gate) State = failed ? TerminalTransportState.Failed : TerminalTransportState.Closed;
                _completion.TrySetResult(result);
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
            if (error is KnownHostsMutationException mutation)
                return "known-host update " + mutation.Category;
            if (!_hostKeyTrusted && _hostKeySeen) return HostKeyFailureCategory();
            if (error is SshTransportException transport) return transport.Category;
            if (error is SshAuthenticationException) return "authentication";
            if (error is SshConnectionException) return "SSH connection";
            if (error is SocketException) return "network connection";
            if (error is OperationCanceledException || error is TimeoutException) return "cancellation or timeout";
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
            _lifetime.Dispose();
            _writeGate.Dispose();
            _finishGate.Dispose();
        }
    }
}
