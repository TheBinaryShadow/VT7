using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal sealed class SshShimBrokerResult
    {
        internal SshShimAction Action { get; set; }
        internal string Reason { get; set; } = string.Empty;
        internal uint ClientProcessId { get; set; }
        internal bool HmacValid { get; set; }
        internal bool ProcessAssociationValid { get; set; }
        internal bool ConsoleAssociationValid { get; set; }
        internal bool BarrierAcknowledged { get; set; }
        internal bool BarrierCommitted { get; set; }
        internal SshInvocation? Invocation { get; set; }
    }

    internal sealed class SshShimBroker : IDisposable
    {
        private const uint PipeAccessDuplex = 0x00000003;
        private const uint FileFlagFirstPipeInstance = 0x00080000;
        private const uint FileFlagOverlapped = 0x40000000;
        private const uint PipeRejectRemoteClients = 0x00000008;
        private const uint Th32csSnapProcess = 0x00000002;
        private const uint SddlRevision1 = 1;
        private readonly byte[] _capability = new byte[32];
        private readonly byte[] _serverNonce = new byte[16];
        private readonly long _generation;
        private readonly string _externalPath;
        private readonly string _externalHash;
        private readonly Func<string, Task> _barrierWaiter;
        private readonly Func<SshInvocation, Task<int>> _embeddedHandler;
        private readonly Func<SshInvocation, Task> _embeddedCompleted;
        private readonly bool _continuous;
        private readonly NamedPipeServerStream _server;
        private readonly CancellationTokenSource _lifetime = new CancellationTokenSource();
        private readonly TaskCompletionSource<int> _rootProcess = NewCompletion<int>();
        private readonly TaskCompletionSource<bool> _accepted = NewCompletion<bool>();
        private readonly TaskCompletionSource<SshShimBrokerResult> _firstResult = NewCompletion<SshShimBrokerResult>();
        private readonly Task _worker;
        private bool _disposed;

        internal SshShimBroker(long generation, string externalPath, Func<string, Task> barrierWaiter,
            Func<SshInvocation, Task<int>>? embeddedHandler = null,
            Func<SshInvocation, Task>? embeddedCompleted = null, bool continuous = false)
        {
            if (generation <= 0) throw new ArgumentOutOfRangeException(nameof(generation));
            _generation = generation;
            _externalPath = Path.GetFullPath(externalPath ?? throw new ArgumentNullException(nameof(externalPath)));
            if (!File.Exists(_externalPath)) throw new FileNotFoundException("The H01 external fixture is missing.", _externalPath);
            using (var stream = File.OpenRead(_externalPath))
            using (var sha = SHA256.Create())
                _externalHash = BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", string.Empty);
            _barrierWaiter = barrierWaiter ?? throw new ArgumentNullException(nameof(barrierWaiter));
            _embeddedHandler = embeddedHandler ?? (_ => Task.FromResult(0));
            _embeddedCompleted = embeddedCompleted ?? (_ => Task.CompletedTask);
            _continuous = continuous;
            using (var random = RandomNumberGenerator.Create())
            {
                random.GetBytes(_capability);
                random.GetBytes(_serverNonce);
            }
            PipeName = @"\\.\pipe\VT7.SSH." + Guid.NewGuid().ToString("N");
            _server = CreatePipe(PipeName);
            _worker = RunAsync();
        }

        internal string PipeName { get; }
        internal string Capability => Convert.ToBase64String(_capability).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        internal string ExternalPath => _externalPath;
        internal string ExternalHash => _externalHash;
        internal Task RequestAccepted => _accepted.Task;
        internal Task<SshShimBrokerResult> Completion => _firstResult.Task;

        internal void SetRootProcess(int processId)
        {
            if (processId <= 0) throw new ArgumentOutOfRangeException(nameof(processId));
            if (!_rootProcess.TrySetResult(processId)) throw new InvalidOperationException("The H01 root process was already assigned.");
        }

        private async Task RunAsync()
        {
            while (!_lifetime.IsCancellationRequested)
            {
                try
                {
                    var result = await RunRequestAsync().ConfigureAwait(false);
                    _firstResult.TrySetResult(result);
                }
                catch (Exception error)
                {
                    if (!_lifetime.IsCancellationRequested) _firstResult.TrySetException(error);
                    if (!_continuous) return;
                }
                finally
                {
                    try
                    {
                        if (_server.IsConnected) _server.Disconnect();
                    }
                    catch when (_lifetime.IsCancellationRequested) { }
                }
                if (!_continuous) return;
            }
        }

        private async Task<SshShimBrokerResult> RunRequestAsync()
        {
            var result = new SshShimBrokerResult();
            try
            {
                using (var random = RandomNumberGenerator.Create()) random.GetBytes(_serverNonce);
                var connection = _server.WaitForConnectionAsync(_lifetime.Token);
                if (_continuous) await connection.ConfigureAwait(false);
                else await WithTimeout(connection, TimeSpan.FromSeconds(10), "shim pipe connection").ConfigureAwait(false);
                if (!GetNamedPipeClientProcessId(_server.SafePipeHandle, out var clientPid))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "GetNamedPipeClientProcessId failed.");
                result.ClientProcessId = clientPid;

                var helloBody = await ReadFrameAsync().ConfigureAwait(false);
                SshShimProtocol.ParseHello(helloBody, out var claimedPid, out var claimedCreation, out var clientNonce);
                if (claimedPid != clientPid) throw new InvalidDataException("Shim PID does not match the named-pipe client.");
                await WriteFrameAsync(SshShimProtocol.Challenge(_generation, _serverNonce)).ConfigureAwait(false);

                var requestBody = await ReadFrameAsync().ConfigureAwait(false);
                var request = SshShimProtocol.ParseRequest(requestBody);
                if (request.Protocol != SshShimProtocol.Version || request.ProcessId != clientPid ||
                    request.CreationTime != claimedCreation || !request.ClientNonce.SequenceEqual(clientNonce) ||
                    !request.ServerNonce.SequenceEqual(_serverNonce) || request.Generation != _generation)
                    throw new InvalidDataException("Authenticated shim request does not match its challenge.");
                using (var hmac = new HMACSHA256(_capability))
                    result.HmacValid = FixedEquals(hmac.ComputeHash(request.CanonicalBytes), request.Mac);
                if (!result.HmacValid) throw new InvalidDataException("Shim request authentication failed.");

                var rootPid = await WithTimeout(_rootProcess.Task, TimeSpan.FromSeconds(5), "WinPTY root identity").ConfigureAwait(false);
                using (var client = Process.GetProcessById(checked((int)clientPid)))
                using (var root = Process.GetProcessById(rootPid))
                {
                    var actualCreation = GetCreationTime(client.Handle);
                    result.ProcessAssociationValid = actualCreation == request.CreationTime &&
                        GetCreationTime(root.Handle) <= actualCreation && IsDescendant(clientPid, checked((uint)rootPid));
                }
                result.ConsoleAssociationValid = request.ConsoleProcesses.Contains(clientPid) &&
                    request.ConsoleProcesses.Contains(checked((uint)rootPid));
                if (!result.ProcessAssociationValid || !result.ConsoleAssociationValid)
                    throw new InvalidDataException("Shim process association failed.");

                var consoleHandles = SshShimProtocol.HasConsoleHandles(request);
                var grammar = SshInvocationParser.TryParse(request.Arguments, request.CurrentDirectory,
                    out var invocation, out var grammarReason);
                var requestId = Guid.NewGuid();
                if (!consoleHandles || !grammar)
                {
                    result.Action = SshShimAction.System;
                    result.Reason = consoleHandles ? grammarReason : "redirected-standard-handle";
                    await WriteFrameAsync(SshShimProtocol.Response(SshShimAction.System, 0, requestId,
                        result.Reason, _externalPath, _externalHash)).ConfigureAwait(false);
                    return result;
                }

                result.Action = SshShimAction.Embedded;
                result.Reason = "eligible";
                result.Invocation = invocation;
                var barrier = $"VT7: H01 connecting to {invocation.Destination} [{requestId.ToString("N").Substring(0, 8)}]";
                await WriteFrameAsync(SshShimProtocol.Response(SshShimAction.Embedded, 0, requestId,
                    result.Reason, barrier, string.Empty)).ConfigureAwait(false);
                _accepted.TrySetResult(true);

                var barrierBody = await ReadFrameAsync().ConfigureAwait(false);
                SshShimProtocol.ParseBarrier(barrierBody, requestId, _serverNonce, out var canonical, out var mac);
                using (var hmac = new HMACSHA256(_capability))
                    result.BarrierAcknowledged = FixedEquals(hmac.ComputeHash(canonical), mac);
                if (!result.BarrierAcknowledged) throw new InvalidDataException("Barrier acknowledgement authentication failed.");
                await WithTimeout(_barrierWaiter(barrier), TimeSpan.FromSeconds(10), "committed WinPTY barrier").ConfigureAwait(false);
                result.BarrierCommitted = true;
                var exitCode = await _embeddedHandler(invocation).ConfigureAwait(false);
                if (exitCode != 0 && exitCode != 255)
                    throw new InvalidOperationException("The embedded SSH handler returned an unsupported status.");
                try
                {
                    await WriteFrameAsync(SshShimProtocol.Complete(exitCode, requestId)).ConfigureAwait(false);
                }
                finally
                {
                    // Root input must reopen even if an accepted shim disappears
                    // before it can receive the completion frame.
                    await _embeddedCompleted(invocation).ConfigureAwait(false);
                }
                return result;
            }
            catch
            {
                _accepted.TrySetException(new InvalidOperationException("The H01 request was not accepted."));
                throw;
            }
        }

        private async Task<byte[]> ReadFrameAsync()
        {
            var header = new byte[4];
            await ReadExactAsync(header).ConfigureAwait(false);
            var count = BitConverter.ToInt32(header, 0);
            if (count <= 0 || count > SshShimProtocol.MaximumFrame) throw new InvalidDataException("Invalid shim frame length.");
            var body = new byte[count];
            await ReadExactAsync(body).ConfigureAwait(false);
            return body;
        }

        private async Task ReadExactAsync(byte[] bytes)
        {
            var offset = 0;
            while (offset < bytes.Length)
            {
                var read = await WithTimeout(_server.ReadAsync(bytes, offset, bytes.Length - offset, _lifetime.Token),
                    TimeSpan.FromSeconds(5), "shim pipe read").ConfigureAwait(false);
                if (read == 0) throw new EndOfStreamException("The shim pipe closed during a frame.");
                offset += read;
            }
        }

        private async Task WriteFrameAsync(byte[] body)
        {
            if (body == null || body.Length == 0 || body.Length > SshShimProtocol.MaximumFrame)
                throw new InvalidDataException("Invalid outgoing shim frame.");
            var header = BitConverter.GetBytes(body.Length);
            await WithTimeout(_server.WriteAsync(header, 0, header.Length, _lifetime.Token), TimeSpan.FromSeconds(5), "shim pipe header write").ConfigureAwait(false);
            await WithTimeout(_server.WriteAsync(body, 0, body.Length, _lifetime.Token), TimeSpan.FromSeconds(5), "shim pipe body write").ConfigureAwait(false);
            await WithTimeout(_server.FlushAsync(_lifetime.Token), TimeSpan.FromSeconds(5), "shim pipe flush").ConfigureAwait(false);
        }

        private static NamedPipeServerStream CreatePipe(string name)
        {
            var identity = WindowsIdentity.GetCurrent().User ?? throw new InvalidOperationException("The current Windows SID is unavailable.");
            var sddl = "D:P(A;;GA;;;SY)(A;;GA;;;" + identity.Value + ")";
            if (!ConvertStringSecurityDescriptorToSecurityDescriptor(sddl, SddlRevision1, out var descriptor, out _))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Cannot create the H01 pipe security descriptor.");
            try
            {
                var attributes = new SecurityAttributes
                {
                    Length = Marshal.SizeOf(typeof(SecurityAttributes)),
                    SecurityDescriptor = descriptor,
                    InheritHandle = false,
                };
                var handle = CreateNamedPipe(name, PipeAccessDuplex | FileFlagFirstPipeInstance | FileFlagOverlapped,
                    PipeRejectRemoteClients, 1, SshShimProtocol.MaximumFrame, SshShimProtocol.MaximumFrame, 5000, ref attributes);
                if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateNamedPipe failed closed for H01.");
                return new NamedPipeServerStream(PipeDirection.InOut, true, false, handle);
            }
            finally { LocalFree(descriptor); }
        }

        private static long GetCreationTime(IntPtr process)
        {
            if (!GetProcessTimes(process, out var creation, out _, out _, out _))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetProcessTimes failed.");
            return checked((long)(((ulong)creation.High << 32) | creation.Low));
        }

        private static bool IsDescendant(uint child, uint root)
        {
            var parents = new Dictionary<uint, uint>();
            using (var snapshot = CreateToolhelp32Snapshot(Th32csSnapProcess, 0))
            {
                if (snapshot.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateToolhelp32Snapshot failed.");
                var entry = new ProcessEntry32 { Size = (uint)Marshal.SizeOf(typeof(ProcessEntry32)) };
                if (Process32First(snapshot, ref entry))
                {
                    do { parents[entry.ProcessId] = entry.ParentProcessId; entry.Size = (uint)Marshal.SizeOf(typeof(ProcessEntry32)); }
                    while (Process32Next(snapshot, ref entry));
                }
            }
            var current = child;
            for (var depth = 0; depth < 64 && current != 0; ++depth)
            {
                if (current == root) return true;
                if (!parents.TryGetValue(current, out current)) return false;
            }
            return false;
        }

        private static bool FixedEquals(byte[] left, byte[] right)
        {
            if (left == null || right == null || left.Length != right.Length) return false;
            var difference = 0;
            for (var index = 0; index < left.Length; ++index) difference |= left[index] ^ right[index];
            return difference == 0;
        }

        private static async Task<T> WithTimeout<T>(Task<T> task, TimeSpan timeout, string operation)
        {
            if (await Task.WhenAny(task, Task.Delay(timeout)).ConfigureAwait(false) != task)
                throw new TimeoutException("Timed out waiting for " + operation + ".");
            return await task.ConfigureAwait(false);
        }

        private static async Task WithTimeout(Task task, TimeSpan timeout, string operation)
        {
            if (await Task.WhenAny(task, Task.Delay(timeout)).ConfigureAwait(false) != task)
                throw new TimeoutException("Timed out waiting for " + operation + ".");
            await task.ConfigureAwait(false);
        }

        private static TaskCompletionSource<T> NewCompletion<T>() =>
            new TaskCompletionSource<T>(TaskCreationOptions.RunContinuationsAsynchronously);

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            _lifetime.Cancel();
            _server.Dispose();
            _ = _worker.ContinueWith(_ => _lifetime.Dispose(), CancellationToken.None,
                TaskContinuationOptions.ExecuteSynchronously, TaskScheduler.Default);
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct SecurityAttributes
        {
            internal int Length;
            internal IntPtr SecurityDescriptor;
            [MarshalAs(UnmanagedType.Bool)] internal bool InheritHandle;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct ProcessEntry32
        {
            internal uint Size;
            internal uint Usage;
            internal uint ProcessId;
            internal IntPtr DefaultHeapId;
            internal uint ModuleId;
            internal uint Threads;
            internal uint ParentProcessId;
            internal int BasePriority;
            internal uint Flags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] internal string ExeFile;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct FileTime { internal uint Low; internal uint High; }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafePipeHandle CreateNamedPipe(string name, uint openMode, uint pipeMode,
            uint maxInstances, uint outputBufferSize, uint inputBufferSize, uint defaultTimeout, ref SecurityAttributes security);
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetNamedPipeClientProcessId(SafePipeHandle pipe, out uint clientProcessId);
        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ConvertStringSecurityDescriptorToSecurityDescriptor(string sddl, uint revision,
            out IntPtr descriptor, out uint descriptorSize);
        [DllImport("kernel32.dll")] private static extern IntPtr LocalFree(IntPtr memory);
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetProcessTimes(IntPtr process, out FileTime creation, out FileTime exit, out FileTime kernel, out FileTime user);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern SafeFileHandle CreateToolhelp32Snapshot(uint flags, uint processId);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)] private static extern bool Process32First(SafeFileHandle snapshot, ref ProcessEntry32 entry);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)] private static extern bool Process32Next(SafeFileHandle snapshot, ref ProcessEntry32 entry);
    }
}
