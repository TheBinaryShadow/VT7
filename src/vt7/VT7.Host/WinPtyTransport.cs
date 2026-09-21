using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal sealed class WinPtyTransportSnapshot
    {
        internal WinPtyTransportSnapshot(long outputBytes, long outputBlocks, long inputBytes,
            long inputOperations, long resizeOperations, uint columns, uint rows, int processId)
        {
            OutputBytes = outputBytes;
            OutputBlocks = outputBlocks;
            InputBytes = inputBytes;
            InputOperations = inputOperations;
            ResizeOperations = resizeOperations;
            Columns = columns;
            Rows = rows;
            ProcessId = processId;
        }
        internal long OutputBytes { get; }
        internal long OutputBlocks { get; }
        internal long InputBytes { get; }
        internal long InputOperations { get; }
        internal long ResizeOperations { get; }
        internal uint Columns { get; }
        internal uint Rows { get; }
        internal int ProcessId { get; }
    }

    internal sealed class WinPtyTransport : ITerminalTransport
    {
        private const uint GenericRead = 0x80000000;
        private const uint GenericWrite = 0x40000000;
        private const uint OpenExisting = 3;
        private const uint FileFlagOverlapped = 0x40000000;
        private const uint WaitObject0 = 0;
        private const uint WaitTimeout = 258;
        private const uint Infinite = 0xffffffff;
        private const ulong SpawnAutoShutdown = 1;
        private const ulong SpawnExitAfterShutdown = 2;
        private const int ErrorBrokenPipe = 109;
        private const int ErrorOperationAborted = 995;

        private readonly object _gate = new object();
        private readonly SemaphoreSlim _writeGate = new SemaphoreSlim(1, 1);
        private readonly CancellationTokenSource _lifetime = new CancellationTokenSource();
        private readonly TaskCompletionSource<TerminalTransportResult> _completion =
            new TaskCompletionSource<TerminalTransportResult>(TaskCreationOptions.RunContinuationsAsynchronously);
        private ITerminalOutputSink? _output;
        private IntPtr _pty;
        private SafeFileHandle? _inputHandle;
        private SafeFileHandle? _outputHandle;
        private SafeFileHandle? _childHandle;
        private FileStream? _inputStream;
        private FileStream? _outputStream;
        private Task? _readTask;
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
        private int _processId;
        private bool _disposed;

        internal WinPtyTransport(TerminalProfile profile)
        {
            Profile = profile ?? throw new ArgumentNullException(nameof(profile));
        }

        internal TerminalProfile Profile { get; }
        public Guid TransportId { get; } = Guid.NewGuid();
        public long Generation { get; private set; }
        public TerminalTransportState State { get; private set; } = TerminalTransportState.Created;
        public Task<TerminalTransportResult> Completion => _completion.Task;

        internal WinPtyTransportSnapshot Snapshot => new WinPtyTransportSnapshot(
            Interlocked.Read(ref _outputBytes), Interlocked.Read(ref _outputBlocks),
            Interlocked.Read(ref _inputBytes), Interlocked.Read(ref _inputOperations),
            Interlocked.Read(ref _resizeOperations), _columns, _rows, Volatile.Read(ref _processId));

        public Task StartAsync(TerminalStartContext context, ITerminalOutputSink output, CancellationToken cancellationToken)
        {
            if (context == null) throw new ArgumentNullException(nameof(context));
            if (output == null) throw new ArgumentNullException(nameof(output));
            cancellationToken.ThrowIfCancellationRequested();
            lock (_gate)
            {
                if (_disposed) throw new ObjectDisposedException(nameof(WinPtyTransport));
                if (State != TerminalTransportState.Created) throw new InvalidOperationException("Transport already started.");
                State = TerminalTransportState.Starting;
                Generation = context.Generation;
                _columns = context.Columns;
                _rows = context.Rows;
                _output = output;
            }

            try
            {
                StartNative(context.Columns, context.Rows);
                lock (_gate) State = TerminalTransportState.Running;
                _callerCancellation = cancellationToken.Register(() => _ = CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None));
                _readTask = ReadOutputAsync();
                return Task.CompletedTask;
            }
            catch (Exception ex)
            {
                ReleaseNative();
                lock (_gate) State = TerminalTransportState.Failed;
                _completion.TrySetResult(new TerminalTransportResult(TerminalTransportResultKind.ConnectionFailure, detail: ex.Message));
                throw;
            }
        }

        public async Task WriteAsync(SessionOutboundOperation operation, CancellationToken cancellationToken)
        {
            if (operation == null) throw new ArgumentNullException(nameof(operation));
            cancellationToken.ThrowIfCancellationRequested();
            await _writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                if (State != TerminalTransportState.Running) throw new InvalidOperationException("WinPTY transport is not running.");
                if (operation.Kind == SessionOutboundKind.Resize)
                {
                    IntPtr pty;
                    lock (_gate) pty = _pty;
                    if (pty == IntPtr.Zero) throw new InvalidOperationException("WinPTY is no longer available.");
                    IntPtr error;
                    if (!WinPtyNative.winpty_set_size(pty, checked((int)operation.Columns), checked((int)operation.Rows), out error))
                        throw WinPtyNative.CreateException("winpty_set_size", error);
                    WinPtyNative.FreeError(error);
                    _columns = operation.Columns;
                    _rows = operation.Rows;
                    Interlocked.Increment(ref _resizeOperations);
                    return;
                }
                if (operation.Bytes.Length == 0) return;
                var stream = _inputStream ?? throw new InvalidOperationException("The WinPTY input pipe is closed.");
                await stream.WriteAsync(operation.Bytes, 0, operation.Bytes.Length, cancellationToken).ConfigureAwait(false);
                await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
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
            try
            {
                if (_inputStream != null) await _inputStream.FlushAsync(cancellationToken).ConfigureAwait(false);
            }
            finally
            {
                _writeGate.Release();
            }
        }

        public async Task CloseAsync(TerminalCloseReason reason, CancellationToken cancellationToken)
        {
            Task? reader;
            lock (_gate)
            {
                if (State == TerminalTransportState.Closed || State == TerminalTransportState.Failed)
                {
                    reader = _readTask;
                }
                else
                {
                    _closeReason = reason;
                    State = TerminalTransportState.Closing;
                    reader = _readTask;
                }
            }
            if (_completion.Task.IsCompleted)
            {
                if (reader != null) await reader.ConfigureAwait(false);
                return;
            }

            await _writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                _inputStream?.Dispose();
                _inputStream = null;
                _inputHandle = null;
            }
            finally
            {
                _writeGate.Release();
            }

            var child = _childHandle;
            var natural = child != null && !child.IsInvalid && WinPtyNative.WaitForSingleObject(child.DangerousGetHandle(), 750) == WaitObject0;
            if (!natural)
            {
                await _writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
                try
                {
                    IntPtr pty;
                    lock (_gate) { pty = _pty; _pty = IntPtr.Zero; }
                    if (pty != IntPtr.Zero) WinPtyNative.winpty_free(pty);
                }
                finally
                {
                    _writeGate.Release();
                }
            }
            if (reader != null)
            {
                var finished = await Task.WhenAny(reader, Task.Delay(5000, cancellationToken)).ConfigureAwait(false);
                if (finished != reader) throw new TimeoutException("WinPTY output did not finish within five seconds of close.");
                await reader.ConfigureAwait(false);
            }
            else
            {
                CompleteFromClose(natural);
            }
        }

        private void StartNative(uint columns, uint rows)
        {
            IntPtr error;
            var config = WinPtyNative.winpty_config_new(0, out error);
            if (config == IntPtr.Zero) throw WinPtyNative.CreateException("winpty_config_new", error);
            WinPtyNative.FreeError(error);
            try
            {
                WinPtyNative.winpty_config_set_initial_size(config, checked((int)columns), checked((int)rows));
                WinPtyNative.winpty_config_set_mouse_mode(config, 0);
                WinPtyNative.winpty_config_set_agent_timeout(config, 10000);
                _pty = WinPtyNative.winpty_open(config, out error);
                if (_pty == IntPtr.Zero) throw WinPtyNative.CreateException("winpty_open", error);
                WinPtyNative.FreeError(error);
            }
            finally
            {
                WinPtyNative.winpty_config_free(config);
            }

            _outputHandle = OpenPipe(WinPtyNative.winpty_conout_name(_pty), GenericRead);
            _inputHandle = OpenPipe(WinPtyNative.winpty_conin_name(_pty), GenericWrite);
            _outputStream = new FileStream(_outputHandle, FileAccess.Read, 4096, true);
            _inputStream = new FileStream(_inputHandle, FileAccess.Write, 4096, true);

            var environment = AllocateEnvironment(Profile.Environment);
            IntPtr spawn = IntPtr.Zero;
            try
            {
                spawn = WinPtyNative.winpty_spawn_config_new(SpawnAutoShutdown | SpawnExitAfterShutdown,
                    Profile.Executable, Profile.CommandLine, Profile.WorkingDirectory, environment, out error);
                if (spawn == IntPtr.Zero) throw WinPtyNative.CreateException("winpty_spawn_config_new", error);
                WinPtyNative.FreeError(error);
                IntPtr child;
                IntPtr thread;
                uint createProcessError;
                if (!WinPtyNative.winpty_spawn(_pty, spawn, out child, out thread, out createProcessError, out error))
                {
                    throw WinPtyNative.CreateException("winpty_spawn", error, createProcessError);
                }
                WinPtyNative.FreeError(error);
                _childHandle = new SafeFileHandle(child, true);
                using (var threadHandle = new SafeFileHandle(thread, true)) { }
                _processId = checked((int)WinPtyNative.GetProcessId(child));
            }
            finally
            {
                if (spawn != IntPtr.Zero) WinPtyNative.winpty_spawn_config_free(spawn);
                Marshal.FreeHGlobal(environment);
            }
        }

        private async Task ReadOutputAsync()
        {
            try
            {
                var stream = _outputStream ?? throw new InvalidOperationException("The WinPTY output pipe is closed.");
                var buffer = new byte[4096];
                while (true)
                {
                    int read;
                    try
                    {
                        read = await stream.ReadAsync(buffer, 0, buffer.Length, _lifetime.Token).ConfigureAwait(false);
                    }
                    catch (IOException ex) when (IsPipeClosure(ex))
                    {
                        break;
                    }
                    catch (OperationCanceledException) when (_lifetime.IsCancellationRequested)
                    {
                        break;
                    }
                    if (read == 0) break;
                    var bytes = new byte[read];
                    Buffer.BlockCopy(buffer, 0, bytes, 0, read);
                    var sequence = Interlocked.Increment(ref _nextOutputSequence);
                    var sink = _output ?? throw new InvalidOperationException("The WinPTY output sink is unavailable.");
                    await sink.WriteAsync(new TerminalOutputBlock(Generation, sequence, bytes), _lifetime.Token).ConfigureAwait(false);
                    Interlocked.Add(ref _outputBytes, read);
                    Interlocked.Increment(ref _outputBlocks);
                }

                var closeReason = _closeReason;
                if (closeReason.HasValue)
                {
                    var childExited = _childHandle != null && !_childHandle.IsInvalid &&
                        WinPtyNative.WaitForSingleObject(_childHandle.DangerousGetHandle(), 2000) == WaitObject0;
                    CompleteFromClose(childExited);
                }
                else
                {
                    var child = _childHandle ?? throw new InvalidOperationException("The WinPTY child handle is unavailable.");
                    if (WinPtyNative.WaitForSingleObject(child.DangerousGetHandle(), 2000) != WaitObject0)
                        throw new TimeoutException("The WinPTY child did not signal after output EOF.");
                    if (!WinPtyNative.GetExitCodeProcess(child.DangerousGetHandle(), out var exitCode))
                        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "GetExitCodeProcess failed.");
                    Complete(new TerminalTransportResult(TerminalTransportResultKind.ReportedExit, unchecked((int)exitCode)), false);
                }
            }
            catch (Exception ex)
            {
                if (_closeReason.HasValue)
                    CompleteFromClose(false);
                else
                    Complete(new TerminalTransportResult(TerminalTransportResultKind.ConnectionFailure, detail: ex.Message), true);
            }
        }

        private void CompleteFromClose(bool childExited)
        {
            var reason = _closeReason ?? TerminalCloseReason.Normal;
            var kind = reason == TerminalCloseReason.Cancelled ? TerminalTransportResultKind.Cancelled :
                childExited ? TerminalTransportResultKind.CleanEof : TerminalTransportResultKind.ForcedTermination;
            int? exitCode = null;
            var child = _childHandle;
            if (childExited && child != null && !child.IsInvalid && WinPtyNative.GetExitCodeProcess(child.DangerousGetHandle(), out var code))
                exitCode = unchecked((int)code);
            Complete(new TerminalTransportResult(kind, exitCode), false);
        }

        private void Complete(TerminalTransportResult result, bool failed)
        {
            lock (_gate)
            {
                if (State == TerminalTransportState.Running) State = TerminalTransportState.Closing;
            }
            ReleaseNative();
            lock (_gate) State = failed ? TerminalTransportState.Failed : TerminalTransportState.Closed;
            _completion.TrySetResult(result);
        }

        private void ReleaseNative()
        {
            _writeGate.Wait();
            try
            {
                _callerCancellation.Dispose();
                _lifetime.Cancel();
                _inputStream?.Dispose();
                _inputStream = null;
                _inputHandle = null;
                _outputStream?.Dispose();
                _outputStream = null;
                _outputHandle = null;
                IntPtr pty;
                lock (_gate) { pty = _pty; _pty = IntPtr.Zero; }
                if (pty != IntPtr.Zero) WinPtyNative.winpty_free(pty);
                _childHandle?.Dispose();
                _childHandle = null;
                _output = null;
            }
            finally
            {
                _writeGate.Release();
            }
        }

        private static SafeFileHandle OpenPipe(IntPtr name, uint access)
        {
            var value = Marshal.PtrToStringUni(name) ?? throw new InvalidOperationException("WinPTY returned an empty pipe name.");
            var handle = WinPtyNative.CreateFile(value, access, 0, IntPtr.Zero, OpenExisting, FileFlagOverlapped, IntPtr.Zero);
            if (handle.IsInvalid)
            {
                var error = Marshal.GetLastWin32Error();
                handle.Dispose();
                throw new System.ComponentModel.Win32Exception(error, "Opening WinPTY pipe failed.");
            }
            return handle;
        }

        private static IntPtr AllocateEnvironment(IReadOnlyList<KeyValuePair<string, string>> values)
        {
            var builder = new StringBuilder();
            foreach (var pair in values) builder.Append(pair.Key).Append('=').Append(pair.Value).Append('\0');
            builder.Append('\0');
            var bytes = Encoding.Unicode.GetBytes(builder.ToString());
            var memory = Marshal.AllocHGlobal(bytes.Length);
            Marshal.Copy(bytes, 0, memory, bytes.Length);
            return memory;
        }

        private static bool IsPipeClosure(IOException exception)
        {
            var error = exception.HResult & 0xffff;
            return error == ErrorBrokenPipe || error == ErrorOperationAborted;
        }

        public void Dispose()
        {
            lock (_gate)
            {
                if (_disposed) return;
                _disposed = true;
            }
            try { CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None).GetAwaiter().GetResult(); }
            catch { ReleaseNative(); }
            _lifetime.Dispose();
            _writeGate.Dispose();
        }
    }

    internal static class WinPtyNative
    {
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr winpty_config_new(ulong flags, out IntPtr error);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void winpty_config_free(IntPtr config);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void winpty_config_set_initial_size(IntPtr config, int columns, int rows);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void winpty_config_set_mouse_mode(IntPtr config, int mode);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void winpty_config_set_agent_timeout(IntPtr config, uint milliseconds);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr winpty_open(IntPtr config, out IntPtr error);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr winpty_conin_name(IntPtr pty);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr winpty_conout_name(IntPtr pty);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        internal static extern IntPtr winpty_spawn_config_new(ulong flags, string application, string commandLine,
            string currentDirectory, IntPtr environment, out IntPtr error);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void winpty_spawn_config_free(IntPtr config);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool winpty_spawn(IntPtr pty, IntPtr config, out IntPtr process, out IntPtr thread,
            out uint createProcessError, out IntPtr error);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool winpty_set_size(IntPtr pty, int columns, int rows, out IntPtr error);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void winpty_free(IntPtr pty);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr winpty_error_msg(IntPtr error);
        [DllImport("winpty.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern void winpty_error_free(IntPtr error);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        internal static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr security,
            uint creation, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);
        [DllImport("kernel32.dll")]
        internal static extern uint GetProcessId(IntPtr process);

        internal static Exception CreateException(string operation, IntPtr error, uint createProcessError = 0)
        {
            string? message;
            try { message = error == IntPtr.Zero ? "unknown WinPTY error" : Marshal.PtrToStringUni(winpty_error_msg(error)); }
            finally { FreeError(error); }
            var detail = createProcessError == 0 ? string.Empty : $" CreateProcess={createProcessError}.";
            return new InvalidOperationException($"{operation} failed: {message ?? "unknown WinPTY error"}.{detail}");
        }

        internal static void FreeError(IntPtr error)
        {
            if (error != IntPtr.Zero) winpty_error_free(error);
        }
    }
}
