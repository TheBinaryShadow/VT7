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
        internal TerminalStartContext(Guid sessionId, long generation, uint columns, uint rows)
        {
            SessionId = sessionId;
            Generation = generation;
            Columns = columns;
            Rows = rows;
        }
        internal Guid SessionId { get; }
        internal long Generation { get; }
        internal uint Columns { get; }
        internal uint Rows { get; }
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

    internal interface ITerminalTransport : ISessionOutboundSink
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

        private readonly object _gate = new object();
        private readonly CancellationTokenSource _lifetime = new CancellationTokenSource();
        private readonly Dictionary<long, long> _producerSequences = new Dictionary<long, long>();
        private readonly HashSet<long> _producerGenerations = new HashSet<long>();
        private readonly Dictionary<long, ITerminalTransport> _producerTransports = new Dictionary<long, ITerminalTransport>();
        private readonly ITerminalTransport _root;
        private readonly SessionOutputPump _output;
        private ITerminalTransport? _overlay;
        private SessionOutboundQueue? _outbound;
        private long _activeGeneration;
        private bool _disposed;

        internal TerminalSession(TerminalDocument document, ITerminalTransport root)
        {
            Document = document ?? throw new ArgumentNullException(nameof(document));
            _root = root ?? throw new ArgumentNullException(nameof(root));
            SessionId = Guid.NewGuid();
            _output = new SessionOutputPump(document);
        }

        internal Guid SessionId { get; }
        internal TerminalDocument Document { get; }
        internal TerminalSessionState State { get; private set; } = TerminalSessionState.Created;
        internal SessionOutboundQueue Outbound => _outbound ?? throw new InvalidOperationException("The session has not started.");
        internal event Action<SessionOutboundQueue>? ActiveOutboundChanged;

        internal async Task StartAsync()
        {
            RequireState(TerminalSessionState.Created);
            State = TerminalSessionState.StartingRoot;
            try
            {
                var generation = NextGeneration();
                lock (_gate)
                {
                    _producerGenerations.Add(generation);
                    _producerTransports.Add(generation, _root);
                }
                var info = Document.ReadInfo();
                await _root.StartAsync(new TerminalStartContext(SessionId, generation, info.Columns, info.Rows),
                    new OutputSink(this), _lifetime.Token);
                _outbound = new SessionOutboundQueue(generation, _root);
                State = TerminalSessionState.RunningRoot;
            }
            catch
            {
                State = TerminalSessionState.Failed;
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
                var info = Document.ReadInfo();
                await overlay.StartAsync(new TerminalStartContext(SessionId, generation, info.Columns, info.Rows),
                    new OutputSink(this), _lifetime.Token);
                _overlay = overlay;
                _outbound = new SessionOutboundQueue(generation, overlay);
                State = TerminalSessionState.RunningOverlay;
                ActiveOutboundChanged?.Invoke(_outbound);
            }
            catch
            {
                State = TerminalSessionState.Failed;
                throw;
            }
        }

        internal async Task StopOverlayAsync(TerminalCloseReason reason = TerminalCloseReason.Normal)
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
            var generation = NextGeneration();
            _outbound = new SessionOutboundQueue(generation, _root);
            State = TerminalSessionState.RunningRoot;
            ActiveOutboundChanged?.Invoke(_outbound);
        }

        internal async Task CloseAsync(TerminalCloseReason reason = TerminalCloseReason.Normal)
        {
            if (State == TerminalSessionState.Closed) return;
            if (State == TerminalSessionState.Created)
            {
                State = TerminalSessionState.Closed;
                _output.Dispose();
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
            await _root.Completion;
            await _output.CompleteAsync();
            _output.Dispose();
            State = TerminalSessionState.Closed;
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

        private long NextGeneration() => Interlocked.Increment(ref _activeGeneration);
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
            _outbound?.Dispose();
            _output.Dispose();
            _lifetime.Dispose();
        }
    }

    // Deterministic in-memory transport used by 3A tests and by the backend-free
    // development host until WinPtyTransport replaces it in 3B.
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
    }
}
