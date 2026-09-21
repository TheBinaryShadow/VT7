using Renci.SshNet;
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security;
using System.Text;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal static class SshNetFoundationChecks
    {
        private static readonly string[] RuntimeFiles =
        {
            "Renci.SshNet.dll", "BouncyCastle.Cryptography.dll",
            "Microsoft.Bcl.AsyncInterfaces.dll", "Microsoft.Bcl.Cryptography.dll",
            "Microsoft.Extensions.DependencyInjection.Abstractions.dll",
            "Microsoft.Extensions.Logging.Abstractions.dll", "System.Buffers.dll",
            "System.Formats.Asn1.dll", "System.Memory.dll", "System.Numerics.Vectors.dll",
            "System.Runtime.CompilerServices.Unsafe.dll", "System.Threading.Tasks.Extensions.dll",
        };

        internal static async Task Run(StringBuilder report)
        {
            var binaryRoot = AppDomain.CurrentDomain.BaseDirectory;
            foreach (var name in RuntimeFiles)
                Require(File.Exists(Path.Combine(binaryRoot, name)), "SSH.NET runtime closure is missing " + name + ".");

            var assembly = typeof(SshClient).Assembly;
            var informational = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? string.Empty;
            Require(string.Equals(assembly.GetName().Version?.ToString(), "2026.0.0.1", StringComparison.Ordinal) &&
                informational.StartsWith("2026.0.0", StringComparison.Ordinal), "SSH.NET 2026.0.0 was not loaded.");
            report.AppendLine("PASS: exact SSH.NET 2026.0.0 and its twelve-file net48 runtime closure loaded.");

            const string fingerprint = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
            Require(SshConnectionOptions.NormalizeFingerprint(" SHA256:" + fingerprint + "= ") == fingerprint,
                "SHA256 fingerprint normalization changed.");
            var rejected = false;
            using (var secret = Secret("test-only"))
            {
                try
                {
                    using var invalid = new SshConnectionOptions("host.invalid", 22, "user", "not-a-fingerprint",
                        SshAuthenticationKind.Password, null, secret);
                }
                catch (FormatException) { rejected = true; }
            }
            Require(rejected, "An invalid host-key fingerprint was accepted.");
            report.AppendLine("PASS: structured SSH options require an explicit valid SHA256 trust fingerprint before authentication.");

            var document = new TerminalDocument(loadDemonstration: false);
            var fake = new FakeTerminalTransport("sshnet-foundation-root");
            var session = new TerminalSession(document, fake, () => new TerminalPixelSize(720, 456));
            try
            {
                await session.StartAsync();
                var start = fake.StartContext ?? throw new InvalidOperationException("The transport start context was not retained.");
                Require(start.Columns > 0 && start.Rows > 0 && start.PixelWidth == 720 && start.PixelHeight == 456,
                    "The direct transport did not receive authoritative initial cell and pixel geometry.");
                var resize = SessionOutboundOperation.Resize(100, 30, 900, 570);
                Require(session.Outbound.TryEnqueue(session.Outbound.Generation, resize) == SessionEnqueueResult.Accepted,
                    "The SSH resize operation was not admitted.");
                for (var attempt = 0; attempt < 100 && fake.Received.All(item => item.Kind != SessionOutboundKind.Resize); ++attempt)
                    await Task.Delay(10);
                var observed = fake.Received.Single(item => item.Kind == SessionOutboundKind.Resize);
                Require(observed.Columns == 100 && observed.Rows == 30 && observed.PixelWidth == 900 && observed.PixelHeight == 570,
                    "The authoritative SSH resize lost its cell or pixel geometry.");
                await session.CloseAsync();
            }
            finally
            {
                session.Dispose();
                document.Dispose();
            }
            report.AppendLine("PASS: direct-root session startup and serialized resize preserve authoritative cell and pixel dimensions.");

            using (var secret = Secret("test-only"))
            using (var options = new SshConnectionOptions("host.invalid", 22, "user",
                fingerprint, SshAuthenticationKind.Password, null, secret))
            using (var transport = new SshNetTransport(options))
            {
                Require(transport.State == TerminalTransportState.Created && transport.Snapshot.Stage == "created",
                    "The SSH.NET transport did not begin in the created state.");
            }
            report.AppendLine("PASS: SshNetTransport owns and closes its structured authentication material without starting a connection.");
        }

        private static SecureString Secret(string value)
        {
            var secret = new SecureString();
            foreach (var character in value) secret.AppendChar(character);
            secret.MakeReadOnly();
            return secret;
        }

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }
    }
}
