using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Security;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace VT7.Host
{
    // SL01.3 uses a real, isolated protocol peer. Host trust and credentials
    // never come from arbitrary terminal text or change the user's trust files.
    internal static class SshStartupStallChecks
    {
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false, true);
        private sealed class CheckFailure : Exception
        { internal CheckFailure(string check) : base(check) { } }

        private sealed class Fixture
        {
            internal string Id = string.Empty, Host = string.Empty, Prefix = string.Empty, Key = string.Empty;
            internal int Port;
            internal static Fixture Read(string path)
            {
                Require(!string.IsNullOrWhiteSpace(path) && new FileInfo(path).Length <= 16384, "fixture bound");
                var fields = new Dictionary<string, string>(StringComparer.Ordinal);
                foreach (var line in File.ReadAllLines(path, Utf8))
                {
                    var index = line.IndexOf('=');
                    Require(index > 0 && !fields.ContainsKey(line.Substring(0, index)), "fixture framing");
                    fields.Add(line.Substring(0, index), line.Substring(index + 1));
                }
                Require(fields.Count == 7 && fields["schema"] == "vt7-sl01-3-fixture-v1" &&
                    Regex.IsMatch(fields["id"], "^[a-f0-9]{32}$") &&
                    IPAddress.TryParse(fields["principal"], out var address) &&
                    address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork &&
                    int.TryParse(fields["basePort"], out var port) && port >= 1024 && port <= 65529 &&
                    Regex.IsMatch(fields["userPrefix"], "^[A-Za-z0-9_.-]{1,32}$"), "fixture identity");
                Require(DateTimeOffset.TryParse(fields["expiresUtc"], CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out var expires) && expires > DateTimeOffset.UtcNow &&
                    expires <= DateTimeOffset.UtcNow.AddDays(8), "fixture expiry");
                var key = fields["hostKey"].Split(' ');
                Require(key.Length == 2 && key[0] == "ssh-rsa" &&
                    PresentedHostKey.Parse(Convert.FromBase64String(key[1])).KeyType == "ssh-rsa", "fixture public key");
                return new Fixture { Id = fields["id"], Host = fields["principal"], Prefix = fields["userPrefix"],
                    Port = int.Parse(fields["basePort"], CultureInfo.InvariantCulture), Key = fields["hostKey"] };
            }
        }

        private sealed class Output : ITerminalOutputSink
        {
            private readonly object _gate = new object();
            private readonly StringBuilder _text = new StringBuilder();
            internal long Bytes;
            internal string Text { get { lock (_gate) return _text.ToString(); } }
            public Task WriteAsync(TerminalOutputBlock block, CancellationToken cancellationToken)
            {
                lock (_gate)
                {
                    Require(_text.Length + block.Bytes.Length <= 65536, "fixture output bound");
                    _text.Append(Utf8.GetString(block.Bytes));
                    Bytes += block.Bytes.Length;
                }
                return Task.CompletedTask;
            }
        }

        internal static async Task Run(string path, StringBuilder report)
        {
            string? temp = null;
            var stage = "fixture input";
            try
            {
                var fixture = Fixture.Read(path);
                using var input = new StreamReader(Console.OpenStandardInput(), Utf8, false, 4096, false);
                var keyPath = ReadLine(input, 4096);
                Require(File.Exists(keyPath), "private key preflight");
                using var passphrase = new SecureString();
                for (var count = 0; ; ++count)
                {
                    var value = input.Read();
                    if (value == '\n') break;
                    Require(value >= 0 && value != '\r' && count < 4096, "credential framing");
                    passphrase.AppendChar((char)value);
                }
                passphrase.MakeReadOnly();
                var runId = Guid.NewGuid().ToString("N");
                report.AppendLine("FixtureId=" + fixture.Id);
                report.AppendLine("RunId=" + runId);
                report.AppendLine("Mode=live-startup-stalls");
                temp = Path.Combine(Path.GetTempPath(), "vt7-sl01-3-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(temp);
                var definitions = OpenSshKnownHostsStore.CreateDefaultDefinitions(temp, Path.Combine(temp, "system"));
                Directory.CreateDirectory(Path.GetDirectoryName(definitions[0].Path)!);
                File.WriteAllText(definitions[0].Path, string.Join("\n", Enumerable.Range(0, 7).Select(offset =>
                    OpenSshHostToken.Create(fixture.Host, fixture.Port + offset) + " " + fixture.Key)) + "\n", Utf8);
                var original = File.ReadAllBytes(definitions[0].Path);
                Func<KnownHostsStoreSnapshot> loader = () => OpenSshKnownHostsStore.Load(definitions);
                SshConnectionOptions Options(string name, int offset) => new SshConnectionOptions(fixture.Host,
                    fixture.Port + offset, fixture.Prefix + "_" + runId + "_" + name, string.Empty,
                    SshAuthenticationKind.PrivateKey, keyPath, passphrase);

                stage = "ready-before";
                await Healthy(fixture, Options(stage, 0), loader);
                report.AppendLine("PASS: SL01.3 ready-before authenticates, allocates a PTY and exits normally.");
                foreach (var pty in new[] { false, true })
                {
                    foreach (var behavior in new[] { "timeout", "late", "cancel", "close" })
                    {
                        stage = (pty ? "pty-" : "auth-") + behavior;
                        var offset = (pty ? 4 : 1) + (behavior == "timeout" ? 0 : behavior == "late" ? 1 : 2);
                        var watch = Stopwatch.StartNew();
                        await Stalled(Options(stage, offset), loader, pty, behavior);
                        report.AppendLine("PASS: SL01.3 " + stage + " joins startup and rejects a late Running state; elapsedMs=" + watch.ElapsedMilliseconds);
                    }
                }
                foreach (var pty in new[] { false, true })
                {
                    stage = pty ? "typed-pty-timeout" : "typed-auth-timeout";
                    await Typed(fixture, Options(stage, pty ? 4 : 1), loader, pty);
                    report.AppendLine("PASS: SL01.3 " + stage + " uses production limits, preserves the original shell PID and returns 255.");
                }
                stage = "ready-after";
                await Healthy(fixture, Options(stage, 0), loader);
                Require(original.SequenceEqual(File.ReadAllBytes(definitions[0].Path)), "isolated trust store unchanged");
                report.AppendLine("PASS: SL01.3 ready-after connects and exits normally; isolated trust records remain unchanged.");
                report.AppendLine("Cases=12");
                report.AppendLine("PASS: SL01.3 client startup-stall matrix; paired server audit and Windows 7 acceptance remain separate.");
            }
            catch (Exception error)
            {
                throw new InvalidOperationException("SL01.3 failed at " + stage + "." +
                    (error is CheckFailure ? " Check: " + error.Message + "." : "") +
                    " No credential or remote-output details retained.");
            }
            finally
            {
                // Only the newly generated diagnostic directory is removed.
                if (temp != null && Path.GetFullPath(temp).StartsWith(Path.GetFullPath(Path.GetTempPath()), StringComparison.OrdinalIgnoreCase) &&
                    Path.GetFileName(temp).StartsWith("vt7-sl01-3-", StringComparison.Ordinal)) Directory.Delete(temp, true);
            }
        }

        private static async Task Healthy(Fixture fixture, SshConnectionOptions options, Func<KnownHostsStoreSnapshot> loader)
        {
            using var transport = new SshNetTransport(options, knownHostsLoader: loader);
            using var cancel = new CancellationTokenSource(TimeSpan.FromSeconds(40));
            var output = new Output();
            await Deadline(transport.StartAsync(Context(), output, cancel.Token));
            Require(transport.State == TerminalTransportState.Running, "healthy Running");
            await WaitFor(() => output.Text.Contains("VT7-SL01-3-READY " + fixture.Id));
            await transport.WriteAsync(SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, Utf8.GetBytes("exit\n")), cancel.Token);
            await Deadline(transport.Completion);
            Require((await transport.Completion).Kind == TerminalTransportResultKind.CleanEof, "healthy EOF");
            await transport.CloseAsync(TerminalCloseReason.Normal, CancellationToken.None);
        }

        private static async Task Stalled(SshConnectionOptions options, Func<KnownHostsStoreSnapshot> loader, bool pty, string behavior)
        {
            using var caller = new CancellationTokenSource();
            using var transport = new SshNetTransport(options, knownHostsLoader: loader,
                diagnosticPhaseTimeout: behavior == "late" ? TimeSpan.FromSeconds(3) : (TimeSpan?)null);
            var output = new Output();
            var start = transport.StartAsync(Context(), output, caller.Token);
            var category = pty ? "remote PTY allocation" : "SSH authentication";
            await WaitFor(() => transport.Snapshot.Stage == category || start.IsCompleted);
            Require(!start.IsCompleted, "stall phase reached");
            Task? close = null;
            if (behavior == "cancel" || behavior == "close")
            {
                // Let the peer enter its held callback. The separate server audit
                // must confirm the callback and its full six-second hold.
                await Task.Delay(1000);
                if (behavior == "cancel") caller.Cancel();
                close = transport.CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None);
                Require(ReferenceEquals(close, transport.CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None)), "idempotent close");
                await Task.Delay(200);
                Require(!start.IsCompleted && !close.IsCompleted, "cleanup still owns blocked startup");
            }
            Exception? failure = null;
            try { await Deadline(start); }
            catch (Exception error) { failure = error; }
            Require(failure != null && output.Bytes == 0 && transport.State != TerminalTransportState.Running, "failed startup emits no remote output");
            await Deadline(transport.Completion);
            var result = await transport.Completion;
            if (behavior == "cancel" || behavior == "close")
                Require(failure is OperationCanceledException && result.Kind == TerminalTransportResultKind.Cancelled, "caller cancellation classification");
            else
                Require(failure is SshTransportException ssh && ssh.Category == category + " timeout" &&
                    result.Kind == TerminalTransportResultKind.ConnectionFailure, "phase timeout classification");
            await Deadline(close ?? transport.CloseAsync(TerminalCloseReason.Cancelled, CancellationToken.None));
            Require(start.IsCompleted && output.Bytes == 0 && transport.State != TerminalTransportState.Running, "joined late worker cannot publish Running");
        }

        private static async Task Typed(Fixture fixture, SshConnectionOptions options, Func<KnownHostsStoreSnapshot> loader, bool pty)
        {
            var profile = TerminalProfile.CreateCommandPrompt();
            using var document = new TerminalDocument(loadDemonstration: false);
            var invoked = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
            var failed = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
            using var coordinator = SshOverlayCoordinator.TryCreate(profile, invocation =>
            {
                Require(invocation.Destination == options.Host && invocation.User == options.Username && invocation.Port == options.Port,
                    "typed fixture invocation");
                invoked.TrySetResult(true);
                return Task.FromResult<SshConnectionOptions?>(options);
            }, (_, _) => throw new CheckFailure("unexpected trust prompt"),
                (_, _) => throw new CheckFailure("unexpected host management"), loader) ?? throw new CheckFailure("bundled shim missing");
            coordinator.OverlayStateChanged += (running, message) => { if (!running) failed.TrySetResult(message); };
            var root = new WinPtyTransport(coordinator.Configure(profile));
            using var session = new TerminalSession(document, root);
            await Deadline(session.StartAsync());
            coordinator.Attach(session, root.Snapshot.ProcessId);
            var originalPid = root.Snapshot.ProcessId;
            var readyMarker = "SL01_3_READY_" + Guid.NewGuid().ToString("N");
            var ready = session.WaitForCommittedOutputAsync(session.RootGeneration, readyMarker);
            Enqueue(session, "echo " + readyMarker + "\r");
            await Deadline(ready, "typed local readiness");
            Enqueue(session, "ssh -p " + options.Port + " " + options.Username + "@" + fixture.Host + "\r");
            await Deadline(invoked.Task, "typed shim invocation");
            await Deadline(failed.Task, "typed failure notification");
            Require(await failed.Task == "SSH overlay failed during " + (pty ? "remote PTY allocation" : "SSH authentication") + " timeout.",
                "typed failure category");
            await WaitFor(() => session.State == TerminalSessionState.RunningRoot && !coordinator.IsOverlayRunning && session.Outbound.Generation > 1);
            var marker = "SL01_3_RETURN_" + Guid.NewGuid().ToString("N");
            var returned = session.WaitForCommittedOutputAsync(session.RootGeneration, marker + "_255");
            Enqueue(session, "echo " + marker + "_%ERRORLEVEL%\r");
            await Deadline(returned);
            Require(root.Snapshot.ProcessId == originalPid && root.State == TerminalTransportState.Running, "same root recovery");
            await Deadline(session.CloseAsync());
        }

        private static void Enqueue(TerminalSession session, string text) => Require(session.Outbound.TryEnqueue(session.Outbound.Generation,
            SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, Utf8.GetBytes(text))) == SessionEnqueueResult.Accepted, "typed input");
        private static TerminalStartContext Context() => new TerminalStartContext(Guid.NewGuid(), 1, 80, 24);
        private static async Task Deadline(Task task, string phase = "owned startup operation")
        {
            Require(await Task.WhenAny(task, Task.Delay(40000)) == task, "diagnostic watchdog " + phase);
            await task;
        }
        private static async Task WaitFor(Func<bool> condition)
        {
            var clock = Stopwatch.StartNew();
            while (!condition()) { Require(clock.ElapsedMilliseconds < 40000, "state watchdog"); await Task.Delay(20); }
        }
        private static string ReadLine(StreamReader input, int maximum)
        {
            var text = new StringBuilder();
            while (true)
            {
                var character = input.Read();
                if (character == '\n') return text.ToString();
                Require(character >= 0 && text.Length < maximum && !char.IsControl((char)character), "credential line");
                text.Append((char)character);
            }
        }
        private static void Require(bool value, string check) { if (!value) throw new CheckFailure(check); }
    }
}
