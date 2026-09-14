using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Threading;

namespace VT7.Host
{
    // A session transport may produce output on any thread. This queue preserves
    // byte order, applies bounded backpressure, and keeps native HWND calls on
    // the surface's dispatcher thread.
    internal sealed class SessionOutputPump : IDisposable
    {
        internal const int MaximumChunkBytes = 64 * 1024;
        internal const int MaximumQueuedChunks = 16;

        private sealed class PendingWrite
        {
            internal readonly byte[] Bytes;
            internal readonly TaskCompletionSource<bool> Completion =
                new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

            internal PendingWrite(byte[] bytes)
            {
                Bytes = bytes;
            }
        }

        private readonly object _gate = new object();
        private readonly Queue<PendingWrite> _writes = new Queue<PendingWrite>();
        private readonly SemaphoreSlim _available = new SemaphoreSlim(MaximumQueuedChunks, MaximumQueuedChunks);
        private readonly Dispatcher _dispatcher;
        private TerminalSurface? _surface;
        private TaskCompletionSource<bool>? _completion;
        private Exception? _failure;
        private bool _accepting = true;
        private bool _drainScheduled;
        private bool _disposed;

        internal SessionOutputPump(TerminalSurface surface)
        {
            _surface = surface ?? throw new ArgumentNullException(nameof(surface));
            _dispatcher = surface.Dispatcher;
            if (!_dispatcher.CheckAccess())
                throw new InvalidOperationException("A session output pump must be created on the terminal surface dispatcher.");
            surface.BeginStream();
        }

        internal async Task WriteAsync(byte[] bytes, CancellationToken cancellationToken = default)
        {
            if (bytes == null) throw new ArgumentNullException(nameof(bytes));
            if (bytes.Length == 0) return;
            if (bytes.Length > MaximumChunkBytes)
                throw new ArgumentOutOfRangeException(nameof(bytes), $"A session output chunk cannot exceed {MaximumChunkBytes} bytes.");

            await _available.WaitAsync(cancellationToken).ConfigureAwait(false);
            PendingWrite? pending = null;
            try
            {
                var copy = (byte[])bytes.Clone();
                lock (_gate)
                {
                    ThrowIfClosed();
                    pending = new PendingWrite(copy);
                    _writes.Enqueue(pending);
                    try
                    {
                        ScheduleDrainLocked();
                    }
                    catch
                    {
                        _writes.Dequeue();
                        throw;
                    }
                }
            }
            catch
            {
                _available.Release();
                throw;
            }

            await pending.Completion.Task.ConfigureAwait(false);
        }

        internal Task CompleteAsync()
        {
            lock (_gate)
            {
                if (_disposed) return Task.FromException(new ObjectDisposedException(nameof(SessionOutputPump)));
                if (_failure != null) return Task.FromException(_failure);
                if (_completion != null) return _completion.Task;
                _accepting = false;
                _completion = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
                try
                {
                    ScheduleDrainLocked();
                }
                catch (Exception ex)
                {
                    _failure = ex;
                    _completion.TrySetException(ex);
                }
                return _completion.Task;
            }
        }

        private void ScheduleDrainLocked()
        {
            if (_drainScheduled) return;
            if (_dispatcher.HasShutdownStarted || _dispatcher.HasShutdownFinished)
                throw new InvalidOperationException("The terminal surface dispatcher is shutting down.");
            _drainScheduled = true;
            try
            {
                _dispatcher.BeginInvoke(new Action(Drain), DispatcherPriority.Send);
            }
            catch
            {
                _drainScheduled = false;
                throw;
            }
        }

        private void Drain()
        {
            while (true)
            {
                PendingWrite? pending;
                TaskCompletionSource<bool>? completion = null;
                TerminalSurface? surface;
                lock (_gate)
                {
                    if (_disposed)
                    {
                        _drainScheduled = false;
                        return;
                    }
                    surface = _surface;
                    if (_writes.Count == 0)
                    {
                        _drainScheduled = false;
                        if (!_accepting) completion = _completion;
                        pending = null;
                    }
                    else
                    {
                        pending = _writes.Dequeue();
                    }
                }

                if (pending == null)
                {
                    if (completion != null)
                    {
                        try
                        {
                            surface?.EndStream();
                            completion.TrySetResult(true);
                        }
                        catch (Exception ex)
                        {
                            completion.TrySetException(ex);
                        }
                    }
                    return;
                }

                try
                {
                    surface?.WriteUtf8(pending.Bytes);
                    pending.Completion.TrySetResult(true);
                    _available.Release();
                }
                catch (Exception ex)
                {
                    pending.Completion.TrySetException(ex);
                    _available.Release();
                    Fail(ex);
                    return;
                }
            }
        }

        private void Fail(Exception error)
        {
            PendingWrite[] abandoned;
            TaskCompletionSource<bool>? completion;
            lock (_gate)
            {
                _accepting = false;
                _drainScheduled = false;
                _failure = error;
                abandoned = _writes.ToArray();
                _writes.Clear();
                completion = _completion;
            }
            foreach (var pending in abandoned)
            {
                pending.Completion.TrySetException(error);
                _available.Release();
            }
            completion?.TrySetException(error);
        }

        private void ThrowIfClosed()
        {
            if (_disposed) throw new ObjectDisposedException(nameof(SessionOutputPump));
            if (!_accepting) throw new InvalidOperationException("The session output stream is completing.");
        }

        public void Dispose()
        {
            PendingWrite[] abandoned;
            TaskCompletionSource<bool>? completion;
            lock (_gate)
            {
                if (_disposed) return;
                _disposed = true;
                _accepting = false;
                _surface = null;
                abandoned = _writes.ToArray();
                _writes.Clear();
                completion = _completion;
            }
            var error = new ObjectDisposedException(nameof(SessionOutputPump));
            foreach (var pending in abandoned)
            {
                pending.Completion.TrySetException(error);
                _available.Release();
            }
            completion?.TrySetException(error);
        }
    }
}
