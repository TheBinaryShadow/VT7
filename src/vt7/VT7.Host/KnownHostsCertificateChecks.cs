using Renci.SshNet;
using Renci.SshNet.Common;
using Renci.SshNet.Messages.Transport;
using System;
using System.Collections.Generic;
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
    // KH01.5 uses the production transport/coordinator with a private diagnostic
    // trust store. Neither credentials nor remote output are included in reports.
    internal static class KnownHostsCertificateChecks
    {
        internal static readonly string[] Cases = { "valid", "wrong-principal", "expired", "not-yet-valid",
            "critical-option", "untrusted-ca", "revoked-key", "revoked-ca", "revoked-certificate" };
        private static readonly string[] Reasons = { "certificate-authority-match", "certificate-principal-mismatch",
            "certificate-expired-or-not-yet-valid", "certificate-expired-or-not-yet-valid",
            "certificate-critical-option", "certificate-authority-untrusted", "certificate-material-revoked",
            "certificate-material-revoked", "certificate-material-revoked" };
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false, true);

        private sealed class CheckFailure : Exception
        {
            internal CheckFailure(string message) : base(message) { }
        }

        private sealed class Fixture
        {
            internal string Id = string.Empty;
            internal string Principal = string.Empty;
            internal int BasePort;
            internal string Authority = string.Empty;
            internal string HostKey = string.Empty;
            internal byte[]? SelfTestData;
            internal byte[]? SelfTestSignature;
            internal readonly Dictionary<string, byte[]> Certificates = new Dictionary<string, byte[]>();

            internal static Fixture Read(string path)
            {
                if (string.IsNullOrWhiteSpace(path) || new FileInfo(path).Length > 128 * 1024)
                    throw new InvalidOperationException("KH01.5 fixture is missing or oversized.");
                var values = new Dictionary<string, string>(StringComparer.Ordinal);
                foreach (var line in File.ReadAllLines(path, Utf8))
                {
                    if (line.Length == 0 || line.StartsWith("#", StringComparison.Ordinal)) continue;
                    var separator = line.IndexOf('=');
                    if (separator <= 0 || values.ContainsKey(line.Substring(0, separator)))
                        throw new InvalidOperationException("KH01.5 fixture has an invalid or duplicate field.");
                    values.Add(line.Substring(0, separator), line.Substring(separator + 1));
                }
                if ((values.Count != 12 && !(values.Count == 14 && values.ContainsKey("selfTestData") &&
                    values.ContainsKey("selfTestSignature"))) || values["schema"] != "vt7-kh01-5-fixture-v1" ||
                    !Regex.IsMatch(values["id"], "^[a-f0-9]{32}$") ||
                    !IPAddress.TryParse(values["principal"], out var address) ||
                    address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork ||
                    !int.TryParse(values["basePort"], out var port) || port < 1024 || port > 65527)
                    throw new InvalidOperationException("KH01.5 fixture identity or port range is invalid.");
                var fixture = new Fixture { Id = values["id"], Principal = address.ToString(), BasePort = port,
                    Authority = Key(values["ca"], "ssh-ed25519"), HostKey = Key(values["hostKey"], "ssh-ed25519") };
                foreach (var name in Cases.Take(6))
                {
                    var key = Key(values["cert." + name], "ssh-ed25519-cert-v01@openssh.com");
                    fixture.Certificates.Add(name, Convert.FromBase64String(key.Split(' ')[1]));
                }
                if (values.ContainsKey("selfTestData"))
                {
                    fixture.SelfTestData = Convert.FromBase64String(values["selfTestData"]);
                    fixture.SelfTestSignature = Convert.FromBase64String(values["selfTestSignature"]);
                }
                return fixture;
            }

            private static string Key(string text, string expectedType)
            {
                var fields = text.Split(' ');
                if (fields.Length != 2 || fields[0] != expectedType || fields[1].Length > 16384)
                    throw new InvalidOperationException("KH01.5 fixture contains an invalid public key.");
                var key = PresentedHostKey.Parse(Convert.FromBase64String(fields[1]));
                if (key.KeyType != expectedType)
                    throw new InvalidOperationException("KH01.5 fixture key type differs from its blob.");
                return text;
            }

            internal byte[] CertificateFor(int index) => Certificates[Cases[index < 6 ? index : 0]];
            internal string StoreText(int index)
            {
                var token = OpenSshHostToken.Create(Principal, BasePort + index);
                var text = "@cert-authority " + token + " " + Authority + "\n";
                if (index >= 6)
                {
                    var material = index == 6 ? HostKey : index == 7 ? Authority :
                        "ssh-ed25519-cert-v01@openssh.com " + Convert.ToBase64String(CertificateFor(index));
                    text += "@revoked " + token + " " + material + "\n";
                }
                return text;
            }
        }

        private sealed class Output : ITerminalOutputSink
        {
            private readonly object _gate = new object();
            private readonly List<byte> _bytes = new List<byte>();
            private long _sequence;
            internal string Text { get { lock (_gate) return Encoding.UTF8.GetString(_bytes.ToArray()); } }
            public Task WriteAsync(TerminalOutputBlock block, CancellationToken cancellationToken)
            {
                lock (_gate)
                {
                    Require(block.Sequence > _sequence && _bytes.Count + block.Bytes.Length <= 1024 * 1024,
                        "output order or bound");
                    _sequence = block.Sequence;
                    _bytes.AddRange(block.Bytes);
                }
                return Task.CompletedTask;
            }
        }

        internal static Task SelfTest(string path, StringBuilder report)
        {
            var fixture = Fixture.Read(path);
            var temp = Path.Combine(Path.GetTempPath(), "vt7-kh01-5-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(temp);
            try
            {
                var definitions = OpenSshKnownHostsStore.CreateDefaultDefinitions(temp, Path.Combine(temp, "system"));
                Directory.CreateDirectory(Path.GetDirectoryName(definitions[0].Path)!);
                for (var index = 0; index < Cases.Length; ++index)
                {
                    File.WriteAllText(definitions[0].Path, fixture.StoreText(index), Utf8);
                    var snapshot = OpenSshKnownHostsStore.Load(definitions);
                    var info = new ConnectionInfo(fixture.Principal, "diagnostic", new PasswordAuthenticationMethod("diagnostic", "unused"));
                    var algorithm = info.HostKeyAlgorithms["ssh-ed25519-cert-v01@openssh.com"](fixture.CertificateFor(index));
                    Require(fixture.SelfTestData != null && fixture.SelfTestSignature != null,
                        "public signature test vectors");
                    Require(algorithm.VerifySignature(fixture.SelfTestData!, fixture.SelfTestSignature!) ==
                        (index != 2 && index != 3), "pinned certificate signature and validity gate " + Cases[index]);
                    var args = new HostKeyEventArgs(algorithm);
                    Require(args.Certificate != null, "SSH.NET certificate decoding");
                    Require(SshNetTransport.ReadCertificateBytes(args.Certificate!).SequenceEqual(fixture.CertificateFor(index)),
                        "exact authenticated certificate bytes");
                    var decision = SshNetTransport.DecideHostKey(args,
                        OpenSshHostToken.Create(fixture.Principal, fixture.BasePort + index), snapshot, string.Empty);
                    CheckDecision(index, decision);
                    report.AppendLine("PASS: certificate adapter " + Cases[index] + " -> " + decision.Result.Reason);
                }
                var validAlgorithm = new ConnectionInfo(fixture.Principal, "diagnostic",
                    new PasswordAuthenticationMethod("diagnostic", "unused"))
                    .HostKeyAlgorithms["ssh-ed25519-cert-v01@openssh.com"](fixture.CertificateFor(0));
                var invalidSignature = (byte[])fixture.SelfTestSignature!.Clone();
                invalidSignature[invalidSignature.Length - 1] ^= 1;
                Require(!validAlgorithm.VerifySignature(fixture.SelfTestData!, invalidSignature), "invalid session signature gate");
                Require(IsKeyExchangeRejection(new SshTransportException("key exchange",
                    new SshConnectionException("synthetic rejection", DisconnectReason.KeyExchangeFailed))) &&
                    !IsKeyExchangeRejection(new SshTransportException("disconnect",
                    new SshConnectionException("synthetic disconnect", DisconnectReason.ConnectionLost))) &&
                    !IsKeyExchangeRejection(new SshTransportException("timeout", new TimeoutException())) &&
                    !IsKeyExchangeRejection(new SshTransportException("network connection",
                        new System.Net.Sockets.SocketException())) &&
                    !IsKeyExchangeRejection(new SshTransportException("authentication",
                        new SshAuthenticationException("synthetic authentication failure"))),
                    "unrelated failures cannot count as a certificate date rejection");
                report.AppendLine("PASS: pinned certificate signature/date gate and invalid-signature/unrelated-failure controls.");
                report.AppendLine("PASS: KH01.5 self-test uses signed public fixtures, exact SSH.NET certificate facts and isolated four-source stores; no network connection.");
            }
            finally { Directory.Delete(temp, true); }
            return Task.CompletedTask;
        }

        internal static async Task RunLive(string path, StringBuilder report)
        {
            var stage = "fixture preflight";
            string? temp = null;
            try
            {
                var fixture = Fixture.Read(path);
                stage = "credential input";
                // Read from the redirected anonymous stdin pipe, never argv/env/files.
                using var input = new StreamReader(Console.OpenStandardInput(), Utf8, false, 1024);
                var host = ReadLine(input, 255);
                var user = ReadLine(input, 64);
                var keyPath = ReadLine(input, 4096);
                using var secret = new SecureString();
                for (var count = 0; ; ++count)
                {
                    var character = input.Read();
                    if (character == '\n') break;
                    Require(character >= 0 && count < 4096 && character != '\r', "credential pipe framing");
                    secret.AppendChar((char)character);
                }
                secret.MakeReadOnly();
                Require(host == fixture.Principal && Regex.IsMatch(user, "^[A-Za-z0-9_.-]{1,64}$") && File.Exists(keyPath),
                    "host or credential preflight");
                temp = Path.Combine(Path.GetTempPath(), "vt7-kh01-5-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(temp);
                var definitions = OpenSshKnownHostsStore.CreateDefaultDefinitions(temp, Path.Combine(temp, "system"));
                var storePath = definitions[0].Path;
                Directory.CreateDirectory(Path.GetDirectoryName(storePath)!);
                Func<KnownHostsStoreSnapshot> loader = () => OpenSshKnownHostsStore.Load(definitions);
                SshConnectionOptions Options(int port) => new SshConnectionOptions(host, port, user, string.Empty,
                    SshAuthenticationKind.PrivateKey, keyPath, secret);
                report.AppendLine("FixtureId=" + fixture.Id);
                report.AppendLine("Mode=live-certificates");
                var accepted = 0;
                for (var index = 0; index < Cases.Length; ++index)
                {
                    stage = "direct " + Cases[index];
                    File.WriteAllText(storePath, fixture.StoreText(index), Utf8);
                    var original = File.ReadAllBytes(storePath);
                    using var outputCancellation = new CancellationTokenSource(TimeSpan.FromSeconds(25));
                    using var transport = new SshNetTransport(Options(fixture.BasePort + index), knownHostsLoader: loader,
                        observeCertificateKeyExchange: true);
                    var output = new Output();
                    SshTransportException? failure = null;
                    try { await transport.StartAsync(new TerminalStartContext(Guid.NewGuid(), 1, 80, 24), output, outputCancellation.Token); }
                    catch (SshTransportException error) { failure = error; }
                    var observed = transport.KeyExchangeCertificate;
                    Require(observed?.Certificate != null &&
                        SshNetTransport.ReadCertificateBytes(observed.Certificate).SequenceEqual(fixture.CertificateFor(index)),
                        "exact live key-exchange certificate");
                    if (index == 2 || index == 3)
                    {
                        // The pinned library rejects dates in VerifySignature,
                        // before CanTrustHostKey/HostKeyReceived is called.
                        Require(!transport.CertificatePresented && transport.TrustDecision == null &&
                            failure != null && IsKeyExchangeRejection(failure), "SSH.NET pre-callback date rejection");
                        var policyProbe = SshNetTransport.DecideHostKey(observed!,
                            OpenSshHostToken.Create(fixture.Principal, fixture.BasePort + index), loader(), string.Empty);
                        CheckDecision(index, policyProbe);
                    }
                    else
                    {
                        Require(transport.CertificatePresented && transport.TrustDecision != null, "live certificate callback");
                        CheckDecision(index, transport.TrustDecision!);
                    }
                    if (index == 0)
                    {
                        Require(failure == null && transport.State == TerminalTransportState.Running, "valid certificate connection");
                        await WaitFor(() => output.Text.Contains("VT7-KH01-5-READY " + fixture.Id), "remote ready");
                        await transport.WriteAsync(SessionOutboundOperation.Resize(120, 40), outputCancellation.Token);
                        await transport.WriteAsync(SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, Utf8.GetBytes("size\n")), outputCancellation.Token);
                        await WaitFor(() => output.Text.Contains("VT7-KH01-5-SIZE 40 120"), "remote PTY resize");
                        await transport.WriteAsync(SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, Utf8.GetBytes("exit\n")), outputCancellation.Token);
                        var completion = await Deadline(transport.Completion, "remote exit");
                        Require(completion.Kind == TerminalTransportResultKind.CleanEof, "remote EOF");
                        ++accepted;
                    }
                    else
                    {
                        Require(failure != null && transport.State == TerminalTransportState.Failed && output.Text.Length == 0,
                            "rejected certificate reached remote PTY");
                        Require((await transport.Completion).Kind == TerminalTransportResultKind.ConnectionFailure, "rejection completion");
                    }
                    Require(original.SequenceEqual(File.ReadAllBytes(storePath)), "diagnostic store changed during connection");
                    report.AppendLine("PASS: live direct " + Cases[index] + " -> " + Reasons[index] +
                        (index == 2 || index == 3 ? " (SSH.NET key-exchange rejection; no trust callback)" : string.Empty));
                }

                File.WriteAllText(storePath, fixture.StoreText(0), Utf8);
                stage = "valid reconnect";
                using (var retry = new SshNetTransport(Options(fixture.BasePort), knownHostsLoader: loader))
                {
                    var output = new Output();
                    using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(25));
                    await retry.StartAsync(new TerminalStartContext(Guid.NewGuid(), 1, 80, 24), output, cancellation.Token);
                    Require(retry.CertificatePresented && retry.TrustDecision != null, "reconnect certificate callback");
                    CheckDecision(0, retry.TrustDecision!);
                    await WaitFor(() => output.Text.Contains("VT7-KH01-5-READY " + fixture.Id), "reconnect ready");
                    await retry.WriteAsync(SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, Utf8.GetBytes("exit\n")), cancellation.Token);
                    Require((await Deadline(retry.Completion, "reconnect EOF")).Kind == TerminalTransportResultKind.CleanEof, "reconnect EOF");
                    ++accepted;
                }
                report.AppendLine("PASS: live valid certificate reconnect requires no host-trust prompt.");

                var profiles = new List<TerminalProfile> { TerminalProfile.CreateCommandPrompt() };
                var windowsPowerShell = TerminalProfile.CreateWindowsPowerShell(cleanProfile: true);
                if (windowsPowerShell.IsWindows7Qualified) profiles.Add(windowsPowerShell);
                else report.AppendLine("SKIP: Windows PowerShell interactive version is outside the qualified 5.1 scope.");
                try
                {
                    var powerShell = TerminalProfile.CreatePowerShell7(cleanProfile: true);
                    if (powerShell.IsWindows7Qualified) profiles.Add(powerShell);
                    else report.AppendLine("SKIP: PowerShell interactive version is outside the qualified 7.2.24 scope.");
                }
                catch (FileNotFoundException) { report.AppendLine("SKIP: PowerShell 7 is not installed."); }
                foreach (var profile in profiles)
                {
                    stage = "typed " + profile.Id;
                    await RunTyped(profile, fixture, user, () => Options(fixture.BasePort), loader);
                    ++accepted;
                    report.AppendLine("PASS: live typed certificate SSH " + profile.Id + " reaches the remote PTY and returns status 0 to its original local shell.");
                }
                report.AppendLine("AcceptedConnections=" + accepted);
                report.AppendLine("RejectedConnections=8");
                report.AppendLine("PASS: KH01.5 client certificate matrix passed; server authentication audit and Windows 7 target acceptance remain separate.");
            }
            catch (Exception error)
            {
                // Do not forward exception text containing endpoints/key paths/credentials.
                var check = error is CheckFailure ? " Check: " + error.Message : string.Empty;
                throw new InvalidOperationException("KH01.5 failed at " + stage + "." + check +
                    " No credential or remote-output details retained.");
            }
            finally { if (temp != null) Directory.Delete(temp, true); }
        }

        private static async Task RunTyped(TerminalProfile profile, Fixture fixture, string user,
            Func<SshConnectionOptions> options, Func<KnownHostsStoreSnapshot> loader)
        {
            using var document = new TerminalDocument(loadDemonstration: false);
            using var coordinator = SshOverlayCoordinator.TryCreate(profile, invocation =>
            {
                Require(invocation.Destination == fixture.Principal && invocation.User == user && invocation.Port == fixture.BasePort,
                    "typed invocation differs from fixture");
                return Task.FromResult<SshConnectionOptions?>(options());
            }, (_, _) => throw new InvalidOperationException("Unexpected certificate trust prompt."),
                (_, _) => throw new InvalidOperationException("Unexpected certificate management prompt."), loader)
                ?? throw new InvalidOperationException("The bundled SSH shim is missing.");
            var root = new WinPtyTransport(coordinator.Configure(profile));
            using var session = new TerminalSession(document, root);
            await session.StartAsync();
            coordinator.Attach(session, root.Snapshot.ProcessId);
            Enqueue(session, "ssh -p " + fixture.BasePort + " " + user + "@" + fixture.Principal + "\r");
            await WaitFor(() => session.State == TerminalSessionState.RunningOverlay, "typed certificate handoff");
            await Deadline(session.WaitForCommittedOutputAsync(session.Outbound.Generation,
                "VT7-KH01-5-READY " + fixture.Id), "typed remote ready");
            Enqueue(session, "exit\r");
            await WaitFor(() => session.State == TerminalSessionState.RunningRoot && !coordinator.IsOverlayRunning,
                "typed local-shell return");
            var marker = "VT7_KH01_5_RETURN_" + Guid.NewGuid().ToString("N");
            var completion = session.WaitForCommittedOutputAsync(session.RootGeneration, marker + "_0");
            Enqueue(session, profile.Kind == TerminalProfileKind.CommandPrompt ? "echo " + marker + "_%ERRORLEVEL%\r" :
                "Write-Output ('" + marker + "_' + $LASTEXITCODE)\r");
            await Deadline(completion, "typed return status");
            await session.CloseAsync();
        }

        private static void Enqueue(TerminalSession session, string text)
        {
            var queue = session.Outbound;
            Require(queue.TryEnqueue(queue.Generation,
                SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, Utf8.GetBytes(text))) == SessionEnqueueResult.Accepted,
                "typed input queue");
        }

        private static void CheckDecision(int index, KnownHostTrustDecision decision)
        {
            var state = index == 0 ? KnownHostTrustState.Matching : index >= 6 ? KnownHostTrustState.Revoked : KnownHostTrustState.PolicyRejected;
            Require(decision.Result.State == state && decision.Result.Reason == Reasons[index] && decision.CanTrust == (index == 0),
                "certificate policy " + Cases[index]);
        }

        private static bool IsKeyExchangeRejection(Exception error)
        {
            for (Exception? current = error; current != null; current = current.InnerException)
            {
                if (current is SshConnectionException connection && connection.DisconnectReason == DisconnectReason.KeyExchangeFailed)
                    return true;
            }
            return false;
        }

        private static string ReadLine(StreamReader input, int maximum)
        {
            var text = new StringBuilder();
            for (var count = 0; ; ++count)
            {
                var character = input.Read();
                if (character == '\n') return text.ToString();
                Require(character >= 0 && count < maximum && !char.IsControl((char)character), "credential pipe framing");
                text.Append((char)character);
            }
        }

        private static void Require(bool condition, string stage)
        {
            if (!condition) throw new CheckFailure("KH01.5 check failed: " + stage + ".");
        }
        private static async Task WaitFor(Func<bool> condition, string stage)
        {
            var deadline = DateTime.UtcNow.AddSeconds(25);
            while (!condition())
            {
                if (DateTime.UtcNow >= deadline) throw new CheckFailure("KH01.5 timeout: " + stage + ".");
                await Task.Delay(25);
            }
        }
        private static async Task<T> Deadline<T>(Task<T> task, string stage)
        {
            if (await Task.WhenAny(task, Task.Delay(25000)) != task)
                throw new CheckFailure("KH01.5 timeout: " + stage + ".");
            return await task;
        }
        private static async Task Deadline(Task task, string stage)
        {
            if (await Task.WhenAny(task, Task.Delay(25000)) != task)
                throw new CheckFailure("KH01.5 timeout: " + stage + ".");
            await task;
        }
    }
}
