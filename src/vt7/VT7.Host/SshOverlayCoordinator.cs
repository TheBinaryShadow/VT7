using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace VT7.Host
{
    // Owns the one local-shell-to-remote-overlay handoff boundary. The broker
    // remains session scoped and accepts sequential invocations from the same
    // WinPTY root; credentials never cross the shim pipe.
    internal sealed class SshOverlayCoordinator : IDisposable
    {
        private const long RootGeneration = 1;
        private readonly object _gate = new object();
        private readonly Func<SshInvocation, Task<SshConnectionOptions?>> _prompt;
        private readonly TaskCompletionSource<TerminalSession> _sessionReady =
            new TaskCompletionSource<TerminalSession>(TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly SemaphoreSlim _requestGate = new SemaphoreSlim(1, 1);
        private readonly SshShimBroker _broker;
        private ITerminalTransport? _overlay;
        private bool _disposed;

        private SshOverlayCoordinator(string externalPath,
            Func<SshInvocation, Task<SshConnectionOptions?>> prompt)
        {
            _prompt = prompt ?? throw new ArgumentNullException(nameof(prompt));
            _broker = new SshShimBroker(RootGeneration, externalPath, WaitForBarrierAsync,
                HandleEmbeddedAsync, ResumeRootAfterCompleteAsync, continuous: true);
        }

        internal event Action<bool, string>? OverlayStateChanged;
        internal bool IsOverlayRunning { get { lock (_gate) return _overlay != null; } }

        internal static SshOverlayCoordinator? TryCreate(TerminalProfile profile,
            Func<SshInvocation, Task<SshConnectionOptions?>> prompt)
        {
            if (profile == null) throw new ArgumentNullException(nameof(profile));
            var shim = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "shim", "ssh.exe");
            if (!File.Exists(shim)) return null;
            var external = FindExternalClient(profile, shim);
            return external == null ? null : new SshOverlayCoordinator(external, prompt);
        }

        internal TerminalProfile Configure(TerminalProfile profile)
        {
            if (profile == null) throw new ArgumentNullException(nameof(profile));
            var shimDirectory = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "shim");
            var path = profile.Environment.FirstOrDefault(pair =>
                string.Equals(pair.Key, "PATH", StringComparison.OrdinalIgnoreCase)).Value ?? string.Empty;
            return profile
                .WithEnvironmentVariable("PATH", shimDirectory + ";" + path)
                .WithEnvironmentVariable("VT7_SSH_PIPE", _broker.PipeName)
                .WithEnvironmentVariable("VT7_SSH_CAPABILITY", _broker.Capability)
                .WithEnvironmentVariable("VT7_SYSTEM_SSH", _broker.ExternalPath)
                .WithEnvironmentVariable("VT7_SYSTEM_SSH_SHA256", _broker.ExternalHash)
                .WithEnvironmentVariable("VT7_SSH_PROTOCOL", SshShimProtocol.Version.ToString())
                .WithEnvironmentVariable("VT7_SSH_MODE", "embedded-eligible");
        }

        internal void Attach(TerminalSession session, int rootProcessId)
        {
            if (session == null) throw new ArgumentNullException(nameof(session));
            if (session.RootGeneration != RootGeneration)
                throw new InvalidOperationException("The SSH overlay root generation does not match the shim broker.");
            if (!_sessionReady.TrySetResult(session))
                throw new InvalidOperationException("The SSH overlay coordinator was already attached.");
            _broker.SetRootProcess(rootProcessId);
        }

        internal async Task DisconnectAsync()
        {
            ITerminalTransport? overlay;
            lock (_gate) overlay = _overlay;
            if (overlay != null)
                await overlay.CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None).ConfigureAwait(false);
        }

        private async Task WaitForBarrierAsync(string barrier)
        {
            var session = await _sessionReady.Task.ConfigureAwait(false);
            await session.WaitForCommittedOutputAsync(RootGeneration, barrier).ConfigureAwait(false);
        }

        private async Task<int> HandleEmbeddedAsync(SshInvocation invocation)
        {
            await _requestGate.WaitAsync().ConfigureAwait(false);
            try
            {
                if (_disposed) return 255;
                var session = await _sessionReady.Task.ConfigureAwait(false);
                var options = await _prompt(invocation).ConfigureAwait(false);
                if (options == null)
                {
                    await session.AppendHostLineAsync("VT7: SSH request cancelled before connection.").ConfigureAwait(false);
                    return 255;
                }

                var overlay = new SshNetTransport(options);
                lock (_gate) _overlay = overlay;
                OverlayStateChanged?.Invoke(true, "Connecting to " + invocation.Destination + "...");
                try
                {
                    await session.StartOverlayAsync(overlay).ConfigureAwait(false);
                    OverlayStateChanged?.Invoke(true, "SSH.NET overlay connected to " + invocation.Destination + ".");
                    var result = await overlay.Completion.ConfigureAwait(false);
                    if (session.State == TerminalSessionState.RunningOverlay)
                        await session.StopOverlayAsync(result.Kind == TerminalTransportResultKind.ConnectionFailure
                            ? TerminalCloseReason.Failed : TerminalCloseReason.Normal, resumeRoot: false).ConfigureAwait(false);
                    var status = result.Kind == TerminalTransportResultKind.CleanEof ||
                        (result.Kind == TerminalTransportResultKind.ReportedExit && result.ExitCode.GetValueOrDefault() == 0)
                        ? 0 : 255;
                    await session.AppendHostLineAsync(status == 0
                        ? "VT7: SSH session ended; returning to the local shell."
                        : "VT7: SSH session failed; returning status 255 to the local shell.").ConfigureAwait(false);
                    return status;
                }
                catch (Exception error)
                {
                    var category = error is SshTransportException transportError
                        ? transportError.Category : "terminal overlay coordination";
                    if (session.State == TerminalSessionState.RunningOverlay)
                    {
                        try { await session.StopOverlayAsync(TerminalCloseReason.Failed).ConfigureAwait(false); }
                        catch { }
                    }
                    try { await session.AppendHostLineAsync("VT7: SSH connection failed during " + category +
                        "; returning status 255 to the local shell.").ConfigureAwait(false); }
                    catch { }
                    OverlayStateChanged?.Invoke(false, "SSH overlay failed during " + category + ".");
                    return 255;
                }
                finally
                {
                    lock (_gate) _overlay = null;
                    if (session.State != TerminalSessionState.StoppingOverlay)
                        OverlayStateChanged?.Invoke(false, "Returned to the local shell.");
                }
            }
            finally
            {
                _requestGate.Release();
            }
        }

        private async Task ResumeRootAfterCompleteAsync(SshInvocation invocation)
        {
            var session = await _sessionReady.Task.ConfigureAwait(false);
            if (session.State == TerminalSessionState.StoppingOverlay)
                await session.ResumeRootAsync().ConfigureAwait(false);
            OverlayStateChanged?.Invoke(false, "Returned to the local shell.");
        }

        private static string? FindExternalClient(TerminalProfile profile, string shimPath)
        {
            var candidates = new List<string>();
            AddCandidate(candidates, Environment.GetEnvironmentVariable("ProgramW6432"), "OpenSSH", "ssh.exe");
            AddCandidate(candidates, Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "OpenSSH", "ssh.exe");
            var windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            AddCandidate(candidates, windows, "System32", "OpenSSH", "ssh.exe");
            var path = profile.Environment.FirstOrDefault(pair =>
                string.Equals(pair.Key, "PATH", StringComparison.OrdinalIgnoreCase)).Value;
            foreach (var directory in (path ?? string.Empty).Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries))
            {
                try { candidates.Add(Path.GetFullPath(Path.Combine(directory.Trim().Trim('"'), "ssh.exe"))); }
                catch { }
            }
            var normalizedShim = Path.GetFullPath(shimPath);
            return candidates.FirstOrDefault(candidate => File.Exists(candidate) &&
                !string.Equals(Path.GetFullPath(candidate), normalizedShim, StringComparison.OrdinalIgnoreCase));
        }

        private static void AddCandidate(List<string> candidates, string? root, params string[] parts)
        {
            if (string.IsNullOrWhiteSpace(root)) return;
            try
            {
                var path = root!;
                foreach (var part in parts) path = Path.Combine(path, part);
                path = Path.GetFullPath(path);
                if (!candidates.Contains(path, StringComparer.OrdinalIgnoreCase)) candidates.Add(path);
            }
            catch { }
        }

        public void Dispose()
        {
            lock (_gate)
            {
                if (_disposed) return;
                _disposed = true;
            }
            _broker.Dispose();
        }
    }
}
