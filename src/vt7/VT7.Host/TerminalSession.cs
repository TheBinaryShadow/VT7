using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal enum TerminalTransportState { Created, Starting, Running, Closing, Closed, Failed }
    internal enum TerminalSessionState { Created, StartingRoot, RunningRoot, StartingOverlay, RunningOverlay, StoppingOverlay, Closing, Closed, Failed }
    internal enum TerminalCloseReason { Normal, Replaced, Cancelled, Failed }
    internal enum TerminalTransportResultKind { CleanEof, ReportedExit, ConnectionFailure, Cancelled, ForcedTermination }

    internal sealed class TerminalTransportResult
    {
        internal TerminalTransportResult(TerminalTransportResultKind kind, int? exitCode = null, string? detail = null)
        {
            Kind = kind;
            ExitCode = exitCode;
            Detail = detail;
        }
        internal TerminalTransportResultKind Kind { get; }
        internal int? ExitCode { get; }
        internal string? Detail { get; }
    }

    internal sealed class TerminalStartContext
    {
        internal TerminalStartContext(Guid sessionId, long generation, uint columns, uint rows,
            uint pixelWidth = 0, uint pixelHeight = 0)
        {
            SessionId = sessionId;
            Generation = generation;
            Columns = columns;
            Rows = rows;
            PixelWidth = pixelWidth;
            PixelHeight = pixelHeight;
        }
        internal Guid SessionId { get; }
        internal long Generation { get; }
        internal uint Columns { get; }
        internal uint Rows { get; }
        internal uint PixelWidth { get; }
        internal uint PixelHeight { get; }
    }

    internal readonly struct TerminalPixelSize
    {
        internal TerminalPixelSize(uint width, uint height) { Width = width; Height = height; }
        internal uint Width { get; }
        internal uint Height { get; }
    }

    internal sealed class TerminalOutputBlock
    {
        internal TerminalOutputBlock(long generation, long sequence, byte[] bytes)
        {
            if (generation <= 0) throw new ArgumentOutOfRangeException(nameof(generation));
            if (sequence <= 0) throw new ArgumentOutOfRangeException(nameof(sequence));
            Generation = generation;
            Sequence = sequence;
            Bytes = (byte[])(bytes ?? throw new ArgumentNullException(nameof(bytes))).Clone();
        }
        internal long Generation { get; }
        internal long Sequence { get; }
        internal byte[] Bytes { get; }
    }

    internal interface ITerminalOutputSink
    {
        Task WriteAsync(TerminalOutputBlock block, CancellationToken cancellationToken);
    }

    internal interface ITerminalTransport : ISessionOutboundSink, IDisposable
    {
        Guid TransportId { get; }
        long Generation { get; }
        TerminalTransportState State { get; }
        Task<TerminalTransportResult> Completion { get; }
        Task StartAsync(TerminalStartContext context, ITerminalOutputSink output, CancellationToken cancellationToken);
        Task CloseAsync(TerminalCloseReason reason, CancellationToken cancellationToken);
    }

    internal sealed class TerminalSession : IDisposable
    {
        private sealed class OutputSink : ITerminalOutputSink
        {
            private readonly TerminalSession _owner;
            internal OutputSink(TerminalSession owner) { _owner = owner; }
            public Task WriteAsync(TerminalOutputBlock block, CancellationToken cancellationToken) =>
                _owner.AcceptOutputAsync(block, cancellationToken);
        }

        private sealed class OverlayOutboundSink : ISessionOutboundSink
        {
            private readonly ITerminalTransport _root;
            private readonly ITerminalTransport _overlay;
            internal OverlayOutboundSink(ITerminalTransport root, ITerminalTransport overlay)
            {
                _root = root;
                _overlay = overlay;
            }
            public async Task WriteAsync(SessionOutboundOperation operation, CancellationToken cancellationToken)
            {
                if (operation.Kind == SessionOutboundKind.Resize)
                    await _root.WriteAsync(operation, cancellationToken);
                await _overlay.WriteAsync(operation, cancellationToken);
            }
            public Task CompleteAsync(CancellationToken cancellationToken) =>
                _overlay.CompleteAsync(cancellationToken);
        }

        private readonly object _gate = new object();
        private readonly CancellationTokenSource _lifetime = new CancellationTokenSource();
        private readonly Dictionary<long, long> _producerSequences = new Dictionary<long, long>();
        private readonly HashSet<long> _producerGenerations = new HashSet<long>();
        private readonly Dictionary<long, ITerminalTransport> _producerTransports = new Dictionary<long, ITerminalTransport>();
        private readonly Dictionary<long, List<byte>> _committedTails = new Dictionary<long, List<byte>>();
        private readonly Dictionary<long, CommittedOutputWaiter> _committedWaiters = new Dictionary<long, CommittedOutputWaiter>();
        private readonly ITerminalTransport _root;
        private readonly Func<TerminalPixelSize>? _pixelSize;
        private readonly SessionOutputPump _output;
        private ITerminalTransport? _overlay;
        private SessionOutboundQueue? _outbound;
        private long _activeGeneration;
        private Task? _closeTask;
        private Task? _rootMonitor;
        private readonly TaskCompletionSource<TerminalTransportResult> _completion =
            new TaskCompletionSource<TerminalTransportResult>(TaskCreationOptions.RunContinuationsAsynchronously);
        private bool _disposed;

        private sealed class CommittedOutputWaiter
        {
            internal CommittedOutputWaiter(byte[] marker)
            {
                Marker = marker;
                Completion = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
            }
            internal byte[] Marker { get; }
            internal TaskCompletionSource<bool> Completion { get; }
        }

        internal TerminalSession(TerminalDocument document, ITerminalTransport root,
            Func<TerminalPixelSize>? pixelSize = null)
        {
            Document = document ?? throw new ArgumentNullException(nameof(document));
            _root = root ?? throw new ArgumentNullException(nameof(root));
            _pixelSize = pixelSize;
            SessionId = Guid.NewGuid();
            _output = new SessionOutputPump(document);
        }

        internal Guid SessionId { get; }
        internal TerminalDocument Document { get; }
        internal TerminalSessionState State { get; private set; } = TerminalSessionState.Created;
        internal SessionOutboundQueue Outbound => _outbound ?? throw new InvalidOperationException("The session has not started.");
        internal Task<TerminalTransportResult> Completion => _completion.Task;
        internal long RootGeneration { get; private set; }
        internal event Action<SessionOutboundQueue>? ActiveOutboundChanged;

        internal async Task StartAsync()
        {
            RequireState(TerminalSessionState.Created);
            State = TerminalSessionState.StartingRoot;
            try
            {
                var generation = NextGeneration();
                RootGeneration = generation;
                lock (_gate)
                {
                    _producerGenerations.Add(generation);
                    _producerTransports.Add(generation, _root);
                }
                var context = await CreateStartContextAsync(generation);
                await _root.StartAsync(context,
                    new OutputSink(this), _lifetime.Token);
                _outbound = new SessionOutboundQueue(generation, _root);
                State = TerminalSessionState.RunningRoot;
                _rootMonitor = MonitorRootAsync();
            }
            catch (Exception ex)
            {
                State = TerminalSessionState.Failed;
                _completion.TrySetResult(new TerminalTransportResult(TerminalTransportResultKind.ConnectionFailure, detail: ex.Message));
                throw;
            }
        }

        internal async Task StartOverlayAsync(ITerminalTransport overlay)
        {
            if (overlay == null) throw new ArgumentNullException(nameof(overlay));
            RequireState(TerminalSessionState.RunningRoot);
            State = TerminalSessionState.StartingOverlay;
            var prior = _outbound!;
            _outbound = null;
            await prior.CompleteAsync();
            prior.Dispose();
            try
            {
                var generation = NextGeneration();
                lock (_gate)
                {
                    _producerGenerations.Add(generation);
                    _producerTransports.Add(generation, overlay);
                }
                var context = await CreateStartContextAsync(generation);
                await overlay.StartAsync(context,
                    new OutputSink(this), _lifetime.Token);
                _overlay = overlay;
                _outbound = new SessionOutboundQueue(generation, new OverlayOutboundSink(_root, overlay));
                State = TerminalSessionState.RunningOverlay;
                ActiveOutboundChanged?.Invoke(_outbound);
            }
            catch
            {
                lock (_gate)
                {
                    if (_overlay == overlay) _overlay = null;
                    _producerGenerations.Remove(overlay.Generation);
                    _producerTransports.Remove(overlay.Generation);
                }
                overlay.Dispose();
                var generation = NextGeneration();
                _outbound = new SessionOutboundQueue(generation, _root);
                State = TerminalSessionState.RunningRoot;
                ActiveOutboundChanged?.Invoke(_outbound);
                throw;
            }
        }

        internal async Task StopOverlayAsync(TerminalCloseReason reason = TerminalCloseReason.Normal, bool resumeRoot = true)
        {
            RequireState(TerminalSessionState.RunningOverlay);
            State = TerminalSessionState.StoppingOverlay;
            var outbound = _outbound!;
            _outbound = null;
            await outbound.CompleteAsync();
            outbound.Dispose();
            var overlay = _overlay!;
            await overlay.CloseAsync(reason, _lifetime.Token);
            await overlay.Completion;
            _overlay = null;
            if (!resumeRoot) return;
            ResumeRoot();
        }

        internal Task ResumeRootAsync()
        {
            RequireState(TerminalSessionState.StoppingOverlay);
            ResumeRoot();
            return Task.CompletedTask;
        }

        private void ResumeRoot()
        {
            var generation = NextGeneration();
            _outbound = new SessionOutboundQueue(generation, _root);
            State = TerminalSessionState.RunningRoot;
            ActiveOutboundChanged?.Invoke(_outbound);
        }

        internal Task WaitForCommittedOutputAsync(long generation, string marker)
        {
            if (generation <= 0) throw new ArgumentOutOfRangeException(nameof(generation));
            if (string.IsNullOrEmpty(marker)) throw new ArgumentException("A committed-output marker is required.", nameof(marker));
            var bytes = Encoding.UTF8.GetBytes(marker);
            lock (_gate)
            {
                if (_disposed || State == TerminalSessionState.Closing || State == TerminalSessionState.Closed || State == TerminalSessionState.Failed)
                    throw new InvalidOperationException("The terminal session cannot accept a committed-output waiter.");
                if (_committedWaiters.ContainsKey(generation))
                    throw new InvalidOperationException("A committed-output waiter already exists for this generation.");
                if (_committedTails.TryGetValue(generation, out var tail) && Contains(tail, bytes))
                    return Task.CompletedTask;
                var waiter = new CommittedOutputWaiter(bytes);
                _committedWaiters.Add(generation, waiter);
                return waiter.Completion.Task;
            }
        }

        internal async Task AppendHostLineAsync(string text, CancellationToken cancellationToken = default)
        {
            if (text == null) throw new ArgumentNullException(nameof(text));
            cancellationToken.ThrowIfCancellationRequested();
            var generation = NextGeneration();
            lock (_gate)
            {
                if (_disposed || State == TerminalSessionState.Closing || State == TerminalSessionState.Closed || State == TerminalSessionState.Failed)
                    throw new InvalidOperationException("The terminal session no longer accepts host output.");
                _producerGenerations.Add(generation);
                _producerTransports.Add(generation, _root);
            }
            await _output.WriteAsync(Encoding.UTF8.GetBytes(text + "\r\n"), checked((ulong)generation), 1, cancellationToken);
        }

        internal Task CloseAsync(TerminalCloseReason reason = TerminalCloseReason.Normal)
        {
            lock (_gate)
            {
                if (_closeTask != null) return _closeTask;
                _closeTask = CloseCoreAsync(reason);
                return _closeTask;
            }
        }

        private async Task CloseCoreAsync(TerminalCloseReason reason)
        {
            if (State == TerminalSessionState.Closed) return;
            if (State == TerminalSessionState.Created)
            {
                State = TerminalSessionState.Closed;
                _output.Dispose();
                _completion.TrySetResult(new TerminalTransportResult(TerminalTransportResultKind.Cancelled));
                return;
            }
            State = TerminalSessionState.Closing;
            var outbound = _outbound;
            _outbound = null;
            if (outbound != null)
            {
                await outbound.CompleteAsync();
                outbound.Dispose();
            }
            if (_overlay != null)
            {
                await _overlay.CloseAsync(reason, CancellationToken.None);
                await _overlay.Completion;
                _overlay = null;
            }
            await _root.CloseAsync(reason, CancellationToken.None);
            var result = await _root.Completion;
            await _output.CompleteAsync();
            _output.Dispose();
            State = result.Kind == TerminalTransportResultKind.ConnectionFailure ? TerminalSessionState.Failed : TerminalSessionState.Closed;
            _completion.TrySetResult(result);
        }

        private async Task MonitorRootAsync()
        {
            try
            {
                var result = await _root.Completion.ConfigureAwait(false);
                var reason = result.Kind == TerminalTransportResultKind.ConnectionFailure
                    ? TerminalCloseReason.Failed : TerminalCloseReason.Normal;
                await CloseAsync(reason).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                State = TerminalSessionState.Failed;
                _completion.TrySetResult(new TerminalTransportResult(TerminalTransportResultKind.ConnectionFailure, detail: ex.Message));
            }
        }

        private async Task AcceptOutputAsync(TerminalOutputBlock block, CancellationToken cancellationToken)
        {
            if (block == null) throw new ArgumentNullException(nameof(block));
            cancellationToken.ThrowIfCancellationRequested();
            lock (_gate)
            {
                if (_disposed || State == TerminalSessionState.Created || State == TerminalSessionState.Failed ||
                    State == TerminalSessionState.Closing || State == TerminalSessionState.Closed)
                    throw new InvalidOperationException("The terminal session no longer accepts output.");
                if (!_producerGenerations.Contains(block.Generation))
                    throw new InvalidOperationException("A transport output generation was not registered with this session.");
                _producerSequences.TryGetValue(block.Generation, out var previous);
                if (block.Sequence <= previous) throw new InvalidOperationException("A transport output sequence was stale or duplicated.");
                _producerSequences[block.Generation] = block.Sequence;
            }
            await _output.WriteAsync(block.Bytes, checked((ulong)block.Generation), checked((ulong)block.Sequence), cancellationToken);
            RecordCommittedOutput(block.Generation, block.Bytes);
            var replies = Document.Dispatcher.CheckAccess()
                ? Document.DrainReplies()
                : await Document.Dispatcher.InvokeAsync(Document.DrainReplies).Task;
            foreach (var reply in replies)
            {
                ITerminalTransport origin;
                lock (_gate)
                {
                    if (!_producerTransports.TryGetValue(checked((long)reply.OriginGeneration), out origin))
                        throw new InvalidOperationException("A terminal reply had no originating transport generation.");
                }
                var operation = SessionOutboundOperation.Input(SessionOutboundKind.TerminalReply, reply.Bytes)
                    .Stamp(checked((long)reply.OriginGeneration), checked((long)reply.Sequence));
                await origin.WriteAsync(operation, cancellationToken);
            }
        }

        private void RecordCommittedOutput(long generation, byte[] bytes)
        {
            const int maximumTail = 8192;
            lock (_gate)
            {
                if (!_committedTails.TryGetValue(generation, out var tail))
                {
                    tail = new List<byte>(Math.Min(maximumTail, bytes.Length));
                    _committedTails.Add(generation, tail);
                }
                tail.AddRange(bytes);
                if (tail.Count > maximumTail) tail.RemoveRange(0, tail.Count - maximumTail);
                if (_committedWaiters.TryGetValue(generation, out var waiter) && Contains(tail, waiter.Marker))
                {
                    _committedWaiters.Remove(generation);
                    waiter.Completion.TrySetResult(true);
                }
            }
        }

        private static bool Contains(List<byte> haystack, byte[] needle)
        {
            if (needle.Length == 0 || needle.Length > haystack.Count) return false;
            for (var start = 0; start <= haystack.Count - needle.Length; ++start)
            {
                var match = true;
                for (var index = 0; index < needle.Length; ++index)
                    if (haystack[start + index] != needle[index]) { match = false; break; }
                if (match) return true;
            }
            return false;
        }

        private long NextGeneration() => Interlocked.Increment(ref _activeGeneration);

        private Task<TerminalStartContext> CreateStartContextAsync(long generation)
        {
            if (Document.Dispatcher.CheckAccess())
                return Task.FromResult(CreateStartContext(generation));
            return Document.Dispatcher.InvokeAsync(() => CreateStartContext(generation)).Task;
        }

        private TerminalStartContext CreateStartContext(long generation)
        {
            var info = Document.ReadInfo();
            var pixels = _pixelSize?.Invoke() ?? default;
            return new TerminalStartContext(SessionId, generation, info.Columns, info.Rows,
                pixels.Width, pixels.Height);
        }

        private void RequireState(TerminalSessionState expected)
        {
            if (State != expected) throw new InvalidOperationException($"Session state {State}; expected {expected}.");
        }

        public void Dispose()
        {
            lock (_gate)
            {
                if (_disposed) return;
                _disposed = true;
            }
            _lifetime.Cancel();
            lock (_gate)
            {
                foreach (var waiter in _committedWaiters.Values)
                    waiter.Completion.TrySetCanceled();
                _committedWaiters.Clear();
            }
            _outbound?.Dispose();
            _output.Dispose();
            _overlay?.Dispose();
            _root.Dispose();
            _lifetime.Dispose();
        }
    }

    // Deterministic in-memory transport retained by 3A and hidden host tests.
    internal sealed class FakeTerminalTransport : ITerminalTransport
    {
        private readonly object _gate = new object();
        private readonly List<SessionOutboundOperation> _received = new List<SessionOutboundOperation>();
        private readonly TaskCompletionSource<TerminalTransportResult> _completion =
            new TaskCompletionSource<TerminalTransportResult>(TaskCreationOptions.RunContinuationsAsynchronously);
        private ITerminalOutputSink? _output;
        private long _nextOutputSequence;
        private readonly SessionOutboundAuditSink? _audit;

        internal FakeTerminalTransport(string name, SessionOutboundAuditSink? audit = null)
        {
            Name = name;
            _audit = audit;
        }
        internal string Name { get; }
        internal TerminalStartContext? StartContext { get; private set; }
        internal SessionOutboundOperation[] Received { get { lock (_gate) return _received.ToArray(); } }
        public Guid TransportId { get; } = Guid.NewGuid();
        public long Generation { get; private set; }
        public TerminalTransportState State { get; private set; } = TerminalTransportState.Created;
        public Task<TerminalTransportResult> Completion => _completion.Task;

        public Task StartAsync(TerminalStartContext context, ITerminalOutputSink output, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (State != TerminalTransportState.Created) throw new InvalidOperationException("Transport already started.");
            State = TerminalTransportState.Starting;
            Generation = context.Generation;
            StartContext = context;
            _output = output ?? throw new ArgumentNullException(nameof(output));
            State = TerminalTransportState.Running;
            return Task.CompletedTask;
        }

        internal Task EmitAsync(string text, CancellationToken cancellationToken = default) =>
            EmitAsync(Encoding.UTF8.GetBytes(text), cancellationToken);

        internal Task EmitAsync(byte[] bytes, CancellationToken cancellationToken = default)
        {
            ITerminalOutputSink output;
            long sequence;
            lock (_gate)
            {
                if (State != TerminalTransportState.Running || _output == null)
                    throw new InvalidOperationException("Transport is not running.");
                output = _output;
                sequence = ++_nextOutputSequence;
            }
            return output.WriteAsync(new TerminalOutputBlock(Generation, sequence, bytes), cancellationToken);
        }

        public async Task WriteAsync(SessionOutboundOperation operation, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            lock (_gate)
            {
                if (State != TerminalTransportState.Running) throw new InvalidOperationException("Transport is not running.");
                _received.Add(operation);
            }
            if (_audit != null) await _audit.WriteAsync(operation, cancellationToken);
        }

        public Task CompleteAsync(CancellationToken cancellationToken) =>
            _audit?.CompleteAsync(cancellationToken) ?? Task.CompletedTask;

        public Task CloseAsync(TerminalCloseReason reason, CancellationToken cancellationToken)
        {
            lock (_gate)
            {
                if (State == TerminalTransportState.Closed) return Task.CompletedTask;
                State = TerminalTransportState.Closing;
                _output = null;
                State = TerminalTransportState.Closed;
                _completion.TrySetResult(new TerminalTransportResult(
                    reason == TerminalCloseReason.Normal ? TerminalTransportResultKind.CleanEof : TerminalTransportResultKind.Cancelled));
            }
            return Task.CompletedTask;
        }

        public void Dispose()
        {
            if (State != TerminalTransportState.Closed) CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None).GetAwaiter().GetResult();
        }
    }
}
