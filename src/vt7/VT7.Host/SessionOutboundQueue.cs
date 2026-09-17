using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal enum SessionOutboundKind
    {
        InputBytes,
        Interrupt,
        Break,
        Focus,
        Resize,
        Paste,
        TerminalReply,
    }

    internal enum SessionEnqueueResult
    {
        Accepted,
        Coalesced,
        StaleGeneration,
        Closed,
        Full,
    }

    internal sealed class SessionOutboundOperation
    {
        private SessionOutboundOperation(SessionOutboundKind kind, byte[] bytes, bool focused, uint columns, uint rows)
        {
            Kind = kind;
            Bytes = bytes;
            Focused = focused;
            Columns = columns;
            Rows = rows;
        }

        internal SessionOutboundKind Kind { get; }
        internal byte[] Bytes { get; }
        internal bool Focused { get; }
        internal uint Columns { get; }
        internal uint Rows { get; }
        internal long Generation { get; private set; }
        internal long Sequence { get; private set; }

        internal static SessionOutboundOperation Input(SessionOutboundKind kind, byte[] bytes)
        {
            if (kind != SessionOutboundKind.InputBytes && kind != SessionOutboundKind.Interrupt &&
                kind != SessionOutboundKind.Break && kind != SessionOutboundKind.Paste &&
                kind != SessionOutboundKind.TerminalReply)
                throw new ArgumentOutOfRangeException(nameof(kind));
            if (bytes == null) throw new ArgumentNullException(nameof(bytes));
            return new SessionOutboundOperation(kind, (byte[])bytes.Clone(), false, 0, 0);
        }

        internal static SessionOutboundOperation Focus(bool focused, byte[] bytes)
        {
            if (bytes == null) throw new ArgumentNullException(nameof(bytes));
            return new SessionOutboundOperation(SessionOutboundKind.Focus, (byte[])bytes.Clone(), focused, 0, 0);
        }

        internal static SessionOutboundOperation Resize(uint columns, uint rows)
        {
            if (columns == 0 || rows == 0) throw new ArgumentOutOfRangeException(nameof(columns));
            return new SessionOutboundOperation(SessionOutboundKind.Resize, Array.Empty<byte>(), false, columns, rows);
        }

        internal SessionOutboundOperation Stamp(long generation, long sequence)
        {
            Generation = generation;
            Sequence = sequence;
            return this;
        }
    }

    internal interface ISessionOutboundSink
    {
        Task WriteAsync(SessionOutboundOperation operation, CancellationToken cancellationToken);
        Task CompleteAsync(CancellationToken cancellationToken);
    }

    // This sink keeps the boundary live in the current backend-free host. A WinPTY
    // or SSH session will replace it without changing input ordering or generation checks.
    internal sealed class SessionOutboundAuditSink : ISessionOutboundSink
    {
        private readonly object _gate = new object();
        private readonly List<SessionOutboundOperation> _recent = new List<SessionOutboundOperation>();
        private long _operations;
        private long _bytes;

        internal long OperationCount => Interlocked.Read(ref _operations);
        internal long ByteCount => Interlocked.Read(ref _bytes);
        internal SessionOutboundOperation[] Snapshot()
        {
            lock (_gate) return _recent.ToArray();
        }

        public Task WriteAsync(SessionOutboundOperation operation, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            Interlocked.Increment(ref _operations);
            Interlocked.Add(ref _bytes, operation.Bytes.Length);
            lock (_gate)
            {
                if (_recent.Count == 512) _recent.RemoveAt(0);
                _recent.Add(operation);
            }
            return Task.CompletedTask;
        }

        public Task CompleteAsync(CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            return Task.CompletedTask;
        }
    }

    internal sealed class SessionOutboundQueue : IDisposable
    {
        private readonly object _gate = new object();
        private readonly LinkedList<SessionOutboundOperation> _pending = new LinkedList<SessionOutboundOperation>();
        private readonly SemaphoreSlim _available = new SemaphoreSlim(0);
        private readonly SemaphoreSlim _slots;
        private readonly CancellationTokenSource _cancel = new CancellationTokenSource();
        private readonly ISessionOutboundSink _sink;
        private readonly Task _worker;
        private readonly long _generation;
        private readonly TaskCompletionSource<bool> _completion =
            new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        private long _nextSequence;
        private bool _accepting = true;
        private bool _disposed;

        internal SessionOutboundQueue(long generation, ISessionOutboundSink sink, int capacity = 256)
        {
            if (generation <= 0) throw new ArgumentOutOfRangeException(nameof(generation));
            if (sink == null) throw new ArgumentNullException(nameof(sink));
            if (capacity < 1) throw new ArgumentOutOfRangeException(nameof(capacity));
            _generation = generation;
            _sink = sink;
            _slots = new SemaphoreSlim(capacity, capacity);
            _worker = Task.Run(ProcessAsync);
        }

        internal long Generation => _generation;
        internal Task Completion => _completion.Task;

        internal bool IsCurrent(long generation)
        {
            lock (_gate) return !_disposed && _accepting && generation == _generation;
        }

        internal SessionEnqueueResult TryEnqueue(long generation, SessionOutboundOperation operation)
        {
            if (operation == null) throw new ArgumentNullException(nameof(operation));
            lock (_gate)
            {
                if (_disposed || !_accepting) return SessionEnqueueResult.Closed;
                if (generation != _generation) return SessionEnqueueResult.StaleGeneration;

                var sequence = checked(++_nextSequence);
                if (operation.Kind == SessionOutboundKind.Resize && _pending.Last?.Value.Kind == SessionOutboundKind.Resize)
                {
                    _pending.Last.Value = operation.Stamp(_generation, sequence);
                    return SessionEnqueueResult.Coalesced;
                }
                if (!_slots.Wait(0)) return SessionEnqueueResult.Full;
                _pending.AddLast(operation.Stamp(_generation, sequence));
                _available.Release();
                return SessionEnqueueResult.Accepted;
            }
        }

        internal Task CompleteAsync()
        {
            lock (_gate)
            {
                if (_disposed) return _completion.Task;
                if (_accepting)
                {
                    _accepting = false;
                    _available.Release();
                }
                return _completion.Task;
            }
        }

        private async Task ProcessAsync()
        {
            try
            {
                while (true)
                {
                    await _available.WaitAsync(_cancel.Token).ConfigureAwait(false);
                    SessionOutboundOperation? operation = null;
                    lock (_gate)
                    {
                        if (_pending.First != null)
                        {
                            operation = _pending.First.Value;
                            _pending.RemoveFirst();
                            _slots.Release();
                        }
                        else if (!_accepting)
                        {
                            break;
                        }
                    }
                    if (operation != null)
                        await _sink.WriteAsync(operation, _cancel.Token).ConfigureAwait(false);
                }
                await _sink.CompleteAsync(_cancel.Token).ConfigureAwait(false);
                _completion.TrySetResult(true);
            }
            catch (OperationCanceledException) when (_cancel.IsCancellationRequested)
            {
                _completion.TrySetCanceled();
            }
            catch (Exception ex)
            {
                lock (_gate) _accepting = false;
                _completion.TrySetException(ex);
            }
        }

        public void Dispose()
        {
            lock (_gate)
            {
                if (_disposed) return;
                _disposed = true;
                _accepting = false;
                _pending.Clear();
                _cancel.Cancel();
                _available.Release();
            }
            try { _worker.GetAwaiter().GetResult(); }
            catch (OperationCanceledException) { }
            _available.Dispose();
            _slots.Dispose();
            _cancel.Dispose();
        }
    }
}
