using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal static class H01Checks
    {
        private sealed class CommittedOutputSink : ITerminalOutputSink, IDisposable
        {
            private readonly object _gate = new object();
            private readonly SessionOutputPump _pump;
            private readonly List<byte> _bytes = new List<byte>();
            private byte[]? _expectedBarrier;
            private TaskCompletionSource<bool>? _barrier;
            private long _sequence;

            internal CommittedOutputSink(TerminalDocument document) { _pump = new SessionOutputPump(document); }
            internal string Text { get { lock (_gate) return Encoding.UTF8.GetString(_bytes.ToArray()); } }

            public async Task WriteAsync(TerminalOutputBlock block, CancellationToken cancellationToken)
            {
                if (block.Sequence <= Interlocked.Read(ref _sequence))
                    throw new InvalidOperationException("H01 received stale WinPTY output.");
                Interlocked.Exchange(ref _sequence, block.Sequence);
                await _pump.WriteAsync(block.Bytes, checked((ulong)block.Generation), checked((ulong)block.Sequence), cancellationToken);
                lock (_gate)
                {
                    if (_bytes.Count + block.Bytes.Length > 1024 * 1024)
                        throw new InvalidOperationException("H01 output exceeded its one-MiB diagnostic bound.");
                    _bytes.AddRange(block.Bytes);
                    CheckBarrierLocked();
                }
            }

            internal Task WaitForBarrierAsync(string barrier)
            {
                lock (_gate)
                {
                    if (_barrier != null) throw new InvalidOperationException("H01 supports one pending barrier per root session.");
                    _expectedBarrier = Encoding.UTF8.GetBytes(barrier);
                    _barrier = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
                    CheckBarrierLocked();
                    return _barrier.Task;
                }
            }

            internal Task CompleteAsync() => _pump.CompleteAsync();

            private void CheckBarrierLocked()
            {
                if (_expectedBarrier == null || _barrier == null || _barrier.Task.IsCompleted) return;
                for (var offset = 0; offset + _expectedBarrier.Length <= _bytes.Count; ++offset)
                {
                    var matched = true;
                    for (var index = 0; index < _expectedBarrier.Length; ++index)
                    {
                        if (_bytes[offset + index] == _expectedBarrier[index]) continue;
                        matched = false;
                        break;
                    }
                    if (matched) { _barrier.TrySetResult(true); return; }
                }
            }

            public void Dispose() { _pump.Dispose(); }
        }

        internal static async Task Run(StringBuilder report, bool allowMissingPowerShell7)
        {
            CheckGrammarContracts();
            report.AppendLine("PASS: H01 grammar admits only interactive -4/-6/-l/-p/-i forms and sends ambiguous or unsupported syntax to exact fallback.");

            var commandPrompt = TerminalProfile.CreateCommandPrompt();
            await RunEmbedded(commandPrompt, "Command Prompt", 61, false, 6000);
            report.AppendLine("PASS: Command Prompt resolved ordinary ssh through the authenticated shim, committed the visible WinPTY barrier in order, and kept the accepted shim waiting beyond the five-second handshake timeout until embedded completion.");

            var windowsPowerShell = TerminalProfile.CreateWindowsPowerShell(cleanProfile: true);
            if (!windowsPowerShell.IsWindows7Qualified)
                throw new InvalidOperationException("The H01 PowerShell path requires Windows PowerShell 5.1; discovered " + windowsPowerShell.DisplayName + ".");
            await RunEmbedded(windowsPowerShell, "Windows PowerShell 5.1", 62, true);
            report.AppendLine("PASS: Windows PowerShell 5.1 preserved Croatian HR Latin input, command precedence and the authenticated WinPTY barrier.");

            try
            {
                var powerShell7 = TerminalProfile.CreatePowerShell7(cleanProfile: true);
                if (!powerShell7.IsWindows7Qualified)
                {
                    if (!allowMissingPowerShell7)
                        throw new InvalidOperationException("H01 requires exact PowerShell 7.2.24 on the Windows 7 target; discovered " + powerShell7.RuntimeVersion + ".");
                    report.AppendLine("SKIP: local PowerShell 7 is outside the Windows 7 H01 qualification target 7.2.24.");
                }
                else
                {
                    await RunEmbedded(powerShell7, "PowerShell 7.2.24", 63, true);
                    report.AppendLine("PASS: PowerShell 7.2.24 preserved Croatian HR Latin input, command precedence and the authenticated WinPTY barrier.");
                }
            }
            catch (FileNotFoundException) when (allowMissingPowerShell7)
            {
                report.AppendLine("SKIP: PowerShell 7 is not installed locally. The distributed Windows 7 H01 runner requires exact 7.2.24.");
            }

            await RunSystemFallback();
            report.AppendLine("PASS: unsupported syntax selected the exact absolute fallback, preserved quoted argv and exit 37, and removed capability, pipe and shim PATH state.");

            await RunAuthenticationFailure();
            report.AppendLine("PASS: a wrong session capability was denied before embedded acceptance and fell back once without a duplicate connection.");
        }

        private static async Task RunEmbedded(TerminalProfile baseProfile, string label, int exitCode,
            bool powerShell, int embeddedDelayMilliseconds = 0)
        {
            var binaryRoot = AppDomain.CurrentDomain.BaseDirectory;
            var shimDirectory = Path.Combine(binaryRoot, "shim");
            var shim = Path.Combine(shimDirectory, "ssh.exe");
            var fixture = Path.Combine(binaryRoot, "VT7.WinPtyFixture.exe");
            Require(File.Exists(shim), "H01 shim is missing: " + shim);
            Require(File.Exists(fixture), "H01 system fixture is missing: " + fixture);

            var document = new TerminalDocument(loadDemonstration: false);
            using (var sink = new CommittedOutputSink(document))
            using (var broker = new SshShimBroker(1, fixture, sink.WaitForBarrierAsync, async _ =>
            {
                if (embeddedDelayMilliseconds > 0) await Task.Delay(embeddedDelayMilliseconds);
                return 0;
            }))
            {
                var fixtureReport = Path.Combine(Path.GetTempPath(), "vt7-h01-fixture-" + Guid.NewGuid().ToString("N") + ".json");
                var profile = ConfigureProfile(baseProfile, shimDirectory, broker, fixtureReport);
                var transport = new WinPtyTransport(profile);
                try
                {
                    await transport.StartAsync(new TerminalStartContext(Guid.NewGuid(), 1, 100, 30), sink, CancellationToken.None);
                    broker.SetRootProcess(transport.Snapshot.ProcessId);

                    if (powerShell)
                    {
                        await Input(transport, "function ssh { 'VT7_H01_ALIAS' }; ssh; Remove-Item function:ssh\r");
                        await Input(transport, "Write-Output 'VT7_H01_BEFORE čćžšđ'\r");
                        await Input(transport, "& ssh -4 -l sshtest -p 22 example.com\r");
                    }
                    else
                    {
                        await Input(transport, "echo VT7_H01_BEFORE\r");
                        await Input(transport, "ssh -4 -l sshtest -p 22 example.com\r");
                    }

                    await WithTimeout(broker.RequestAccepted, TimeSpan.FromSeconds(15), label + " shim acceptance");
                    await transport.WriteAsync(SessionOutboundOperation.Resize(111, 33), CancellationToken.None);
                    var brokerResult = await WithTimeout(broker.Completion, TimeSpan.FromSeconds(15), label + " H01 barrier");
                    Require(brokerResult.Action == SshShimAction.Embedded && brokerResult.HmacValid &&
                        brokerResult.ProcessAssociationValid && brokerResult.ConsoleAssociationValid &&
                        brokerResult.BarrierAcknowledged && brokerResult.BarrierCommitted,
                        label + " did not complete the authenticated embedded barrier contract.");
                    Require(brokerResult.Invocation != null && brokerResult.Invocation.Destination == "example.com" &&
                        brokerResult.Invocation.User == "sshtest" && brokerResult.Invocation.Port == 22 && brokerResult.Invocation.ForceIpv4,
                        label + " did not preserve the typed invocation.");

                    await Input(transport, powerShell ? "Write-Output 'VT7_H01_AFTER'; exit " + exitCode + "\r" :
                        "echo VT7_H01_AFTER\r");
                    if (!powerShell) await Input(transport, "exit " + exitCode + "\r");
                    var result = await WithTimeout(transport.Completion, TimeSpan.FromSeconds(20), label + " root exit");
                    await sink.CompleteAsync();
                    Require(result.Kind == TerminalTransportResultKind.ReportedExit && result.ExitCode == exitCode,
                        label + " did not preserve the root-shell exit after the shim barrier.");
                    var snapshot = transport.Snapshot;
                    Require(snapshot.ResizeOperations == 1 && snapshot.Columns == 111 && snapshot.Rows == 33,
                        label + " did not resize while the barrier was pending.");
                    var text = sink.Text;
                    var before = text.IndexOf("VT7_H01_BEFORE", StringComparison.Ordinal);
                    var barrier = text.IndexOf("VT7: H01 connecting to example.com", StringComparison.Ordinal);
                    var after = text.IndexOf("VT7_H01_AFTER", StringComparison.Ordinal);
                    Require(before >= 0 && barrier > before && after > barrier, label + " output order did not preserve before/barrier/after.");
                    if (powerShell)
                    {
                        Require(text.Contains("VT7_H01_ALIAS"), label + " did not preserve PowerShell function precedence.");
                        Require(text.Contains("čćžšđ"), label + " did not preserve Croatian HR Latin text.");
                    }
                    var info = document.ReadInfo();
                    Require(info.Ended == 1 && info.PendingUtf8Bytes == 0, label + " document did not drain cleanly.");
                }
                finally
                {
                    if (transport.State != TerminalTransportState.Closed && transport.State != TerminalTransportState.Failed)
                        await transport.CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None);
                    transport.Dispose();
                    document.Dispose();
                    if (File.Exists(fixtureReport)) File.Delete(fixtureReport);
                }
            }
        }

        private static async Task RunSystemFallback()
        {
            var binaryRoot = AppDomain.CurrentDomain.BaseDirectory;
            var shimDirectory = Path.Combine(binaryRoot, "shim");
            var fixture = Path.Combine(binaryRoot, "VT7.WinPtyFixture.exe");
            var fixtureReport = Path.Combine(Path.GetTempPath(), "vt7-h01-fallback-" + Guid.NewGuid().ToString("N") + ".json");
            var document = new TerminalDocument(loadDemonstration: false);
            using (var sink = new CommittedOutputSink(document))
            using (var broker = new SshShimBroker(1, fixture, sink.WaitForBarrierAsync))
            {
                var profile = ConfigureProfile(TerminalProfile.CreateCommandPrompt(), shimDirectory, broker, fixtureReport);
                var transport = new WinPtyTransport(profile);
                try
                {
                    await transport.StartAsync(new TerminalStartContext(Guid.NewGuid(), 1, 90, 28), sink, CancellationToken.None);
                    broker.SetRootProcess(transport.Snapshot.ProcessId);
                    await Input(transport, "ssh -V \"space value\" plain\r");
                    var brokerResult = await WithTimeout(broker.Completion, TimeSpan.FromSeconds(15), "H01 external fallback response");
                    Require(brokerResult.Action == SshShimAction.System && brokerResult.Reason == "unsupported-option",
                        "Unsupported H01 syntax did not select system fallback.");
                    try { await WaitFor(() => File.Exists(fixtureReport), "H01 external fallback fixture"); }
                    catch (TimeoutException error)
                    {
                        throw new TimeoutException(error.Message + " WinPTY output: " + DiagnosticTail(sink.Text), error);
                    }
                    await Input(transport, "if errorlevel 37 (exit 37) else (exit 96)\r");
                    var result = await WithTimeout(transport.Completion, TimeSpan.FromSeconds(15), "H01 fallback exit");
                    await sink.CompleteAsync();
                    Require(result.Kind == TerminalTransportResultKind.ReportedExit && result.ExitCode == 37,
                        "The H01 shim did not propagate external exit 37.");
                    var json = File.ReadAllText(fixtureReport, Encoding.UTF8);
                    Require(json.Contains("\"space value\"") && json.Contains("\"plain\"") &&
                        json.Contains("\"capabilityPresent\": false") && json.Contains("\"pipePresent\": false") &&
                        json.Contains("\"shimPathPresent\": false"),
                        "The external fixture did not receive exact quoted argv and sanitized VT7 state.");
                    Require(sink.Text.Contains("VT7_H01_SYSTEM_FIXTURE"), "The external fallback did not remain visible through WinPTY.");
                }
                finally
                {
                    if (transport.State != TerminalTransportState.Closed && transport.State != TerminalTransportState.Failed)
                        await transport.CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None);
                    transport.Dispose();
                    document.Dispose();
                    if (File.Exists(fixtureReport)) File.Delete(fixtureReport);
                }
            }
        }

        private static async Task RunAuthenticationFailure()
        {
            var binaryRoot = AppDomain.CurrentDomain.BaseDirectory;
            var shimDirectory = Path.Combine(binaryRoot, "shim");
            var fixture = Path.Combine(binaryRoot, "VT7.WinPtyFixture.exe");
            var fixtureReport = Path.Combine(Path.GetTempPath(), "vt7-h01-auth-" + Guid.NewGuid().ToString("N") + ".json");
            var document = new TerminalDocument(loadDemonstration: false);
            using (var sink = new CommittedOutputSink(document))
            {
                var broker = new SshShimBroker(1, fixture, sink.WaitForBarrierAsync);
                var profile = ConfigureProfile(TerminalProfile.CreateCommandPrompt(), shimDirectory, broker, fixtureReport)
                    .WithEnvironmentVariable("VT7_SSH_CAPABILITY", Convert.ToBase64String(Enumerable.Repeat((byte)0xA5, 32).ToArray()).TrimEnd('=').Replace('+', '-').Replace('/', '_'));
                var transport = new WinPtyTransport(profile);
                try
                {
                    await transport.StartAsync(new TerminalStartContext(Guid.NewGuid(), 1, 90, 28), sink, CancellationToken.None);
                    broker.SetRootProcess(transport.Snapshot.ProcessId);
                    await Input(transport, "ssh example.com\r");
                    var rejected = false;
                    try { await WithTimeout(broker.Completion, TimeSpan.FromSeconds(10), "H01 bad-capability rejection"); }
                    catch (InvalidDataException) { rejected = true; }
                    Require(rejected, "The H01 broker did not reject a wrong session capability.");
                    broker.Dispose();
                    await WaitFor(() => File.Exists(fixtureReport), "single external fallback after authentication failure");
                    await Input(transport, "if errorlevel 37 (exit 37) else (exit 96)\r");
                    var result = await WithTimeout(transport.Completion, TimeSpan.FromSeconds(15), "H01 authentication fallback exit");
                    await sink.CompleteAsync();
                    Require(result.Kind == TerminalTransportResultKind.ReportedExit && result.ExitCode == 37,
                        "Authentication failure did not fall back exactly once before acceptance.");
                    var occurrences = Count(sink.Text, "VT7_H01_SYSTEM_FIXTURE");
                    Require(occurrences == 1, "Authentication failure launched an unexpected number of fallback clients: " + occurrences + ".");
                }
                finally
                {
                    broker.Dispose();
                    if (transport.State != TerminalTransportState.Closed && transport.State != TerminalTransportState.Failed)
                        await transport.CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None);
                    transport.Dispose();
                    document.Dispose();
                    if (File.Exists(fixtureReport)) File.Delete(fixtureReport);
                }
            }
        }

        private static TerminalProfile ConfigureProfile(TerminalProfile profile, string shimDirectory,
            SshShimBroker broker, string fixtureReport)
        {
            var path = profile.Environment.FirstOrDefault(pair => string.Equals(pair.Key, "PATH", StringComparison.OrdinalIgnoreCase)).Value ?? string.Empty;
            return profile
                .WithEnvironmentVariable("PATH", shimDirectory + ";" + path)
                .WithEnvironmentVariable("VT7_SSH_PIPE", broker.PipeName)
                .WithEnvironmentVariable("VT7_SSH_CAPABILITY", broker.Capability)
                .WithEnvironmentVariable("VT7_SYSTEM_SSH", broker.ExternalPath)
                .WithEnvironmentVariable("VT7_SYSTEM_SSH_SHA256", broker.ExternalHash)
                .WithEnvironmentVariable("VT7_SSH_PROTOCOL", "1")
                .WithEnvironmentVariable("VT7_SSH_MODE", "embedded-eligible")
                .WithEnvironmentVariable("VT7_H01_FIXTURE_REPORT", fixtureReport)
                .WithEnvironmentVariable("VT7_H01_FIXTURE_EXIT", "37")
                .WithEnvironmentVariable("VT7_H01_SHIM_DIRECTORY", shimDirectory);
        }

        private static Task Input(WinPtyTransport transport, string text) => transport.WriteAsync(
            SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, Encoding.UTF8.GetBytes(text)), CancellationToken.None);

        private static void CheckGrammarContracts()
        {
            Require(SshInvocationParser.TryParse(new[] { "ssh", "example.com" }, @"C:\work", out _, out _), "Simple destination was rejected.");
            Require(SshInvocationParser.TryParse(new[] { "ssh", "-6", "-l", "user", "-p", "2222", "-i", @"keys\id", "[::1]" }, @"C:\work", out var parsed, out _),
                "Supported option grammar was rejected.");
            Require(parsed.ForceIpv6 && parsed.User == "user" && parsed.Port == 2222 && parsed.KeyPath == @"C:\work\keys\id", "Supported grammar parsed incorrectly.");
            foreach (var rejected in new[]
            {
                new[] { "ssh", "-V" }, new[] { "ssh", "-o", "X=Y", "host" }, new[] { "ssh", "host", "command" },
                new[] { "ssh", "-p", "0", "host" }, new[] { "ssh", "-4", "-6", "host" }, new[] { "ssh", "-p", "22", "-p", "23", "host" }
            })
                Require(!SshInvocationParser.TryParse(rejected, @"C:\work", out _, out _), "Unsupported grammar was accepted: " + string.Join(" ", rejected));
        }

        private static async Task WaitFor(Func<bool> condition, string operation)
        {
            var deadline = DateTime.UtcNow.AddSeconds(10);
            while (DateTime.UtcNow < deadline)
            {
                if (condition()) return;
                await Task.Delay(20);
            }
            throw new TimeoutException("Timed out waiting for " + operation + ".");
        }

        private static int Count(string text, string value)
        {
            var count = 0;
            for (var offset = 0; (offset = text.IndexOf(value, offset, StringComparison.Ordinal)) >= 0; offset += value.Length) ++count;
            return count;
        }

        private static string DiagnosticTail(string text)
        {
            const int limit = 1024;
            var tail = text.Length <= limit ? text : text.Substring(text.Length - limit);
            return tail.Replace("\r", "\\r").Replace("\n", "\\n");
        }

        private static async Task<T> WithTimeout<T>(Task<T> task, TimeSpan timeout, string operation)
        {
            if (await Task.WhenAny(task, Task.Delay(timeout)) != task) throw new TimeoutException("Timed out waiting for " + operation + ".");
            return await task;
        }

        private static async Task WithTimeout(Task task, TimeSpan timeout, string operation)
        {
            if (await Task.WhenAny(task, Task.Delay(timeout)) != task) throw new TimeoutException("Timed out waiting for " + operation + ".");
            await task;
        }

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }
    }
}
