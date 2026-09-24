using Renci.SshNet;
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

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
            Require(string.Equals(assembly.GetName().Version?.ToString(), "2026.0.1.0", StringComparison.Ordinal) &&
                informational.StartsWith("2026.0.1-prerelease.6+f099365c9d", StringComparison.Ordinal),
                "SSH.NET 2026.0.1-prerelease.6 from f099365 was not loaded.");
            report.AppendLine("PASS: exact SSH.NET 2026.0.1-prerelease.6 f099365 and its twelve-file net48 runtime closure loaded.");

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
            using (var secret = Secret("test-only"))
            using (var knownHost = new SshConnectionOptions("host.invalid", 22, "user", string.Empty,
                SshAuthenticationKind.Password, null, secret))
                Require(knownHost.ExpectedHostKeyFingerprint.Length == 0,
                    "A known-host connection could not omit the fallback fingerprint.");
            report.AppendLine("PASS: structured SSH options accept an absent known-host fallback and reject malformed SHA256 fingerprints.");
            using (var secret = Secret("test-only"))
            using (var forced = new SshConnectionOptions("127.0.0.1", 22, "user", fingerprint,
                SshAuthenticationKind.Password, null, secret, SshAddressFamily.IPv4))
                Require(forced.AddressFamily == SshAddressFamily.IPv4,
                    "The typed -4 address-family constraint was not retained.");
            report.AppendLine("PASS: typed -4/-6 address-family constraints remain structured transport input.");

            var dialog = new SshConnectionDialog();
            var dialogBackground = Solid(dialog.Background, "SSH dialog background");
            var labels = Descendants(dialog.FormContent).OfType<TextBlock>().ToArray();
            Require(labels.Length >= 8, "The SSH dialog contrast check did not find every form label.");
            foreach (var label in labels)
            {
                var foreground = Solid(label.Foreground, "SSH dialog text");
                Require(ContrastRatio(foreground, dialogBackground) >= 4.5,
                    "The SSH dialog contains text below the 4.5:1 contrast requirement.");
            }
            var selectorForeground = Solid(dialog.AuthenticationSelector.Foreground, "SSH authentication selector text");
            Require(ContrastRatio(selectorForeground, dialogBackground) >= 4.5,
                "The SSH authentication selector foreground is below the 4.5:1 contrast requirement.");
            dialog.FormContent.Measure(new Size(550, 450));
            dialog.FormContent.Arrange(new Rect(0, 0, 550, 450));
            dialog.FormContent.UpdateLayout();
            dialog.AuthenticationSelector.ApplyTemplate();
            dialog.AuthenticationSelector.UpdateLayout();
            var selectorText = VisualDescendants(dialog.AuthenticationSelector).OfType<TextBlock>()
                .FirstOrDefault(item => string.Equals(item.Text, "Private key", StringComparison.Ordinal));
            if (selectorText == null)
                throw new InvalidOperationException("The SSH authentication selector did not render its selected text.");
            var selectedForeground = Solid(selectorText.Foreground, "SSH selected authentication text");
            Require(ContrastRatio(selectedForeground, dialogBackground) >= 4.5,
                "The selected SSH authentication text is below the 4.5:1 contrast requirement.");
            report.AppendLine("PASS: every SSH connection-dialog label and the selected authentication item have explicit WCAG AA contrast.");

            var trustRequest = new HostTrustPromptRequest(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
                7, 3, 1, "[unknown.example]:2222", "test-user",
                PresentedHostKey.Parse(Ed25519Blob()), true, true, "fixture-generation",
                Path.Combine(Path.GetTempPath(), ".ssh", "known_hosts"));
            var trustDialog = new HostTrustDialog(trustRequest);
            var trustBackground = Solid(trustDialog.Background, "host-trust dialog background");
            var trustLabels = Descendants(trustDialog.FormContent).OfType<TextBlock>().ToArray();
            Require(trustLabels.Length >= 7, "The host-trust dialog contrast check did not find every text element.");
            foreach (var label in trustLabels)
            {
                var foreground = Solid(label.Foreground, "host-trust dialog text");
                Require(ContrastRatio(foreground, trustBackground) >= 4.5,
                    "The host-trust dialog contains text below the 4.5:1 contrast requirement.");
            }
            var trustActions = Descendants(trustDialog.FormContent).OfType<Button>()
                .Select(button => Convert.ToString(button.Content) ?? string.Empty).ToArray();
            Require(trustActions.Any(value => value.Contains("Cancel")) &&
                trustActions.Any(value => value.Contains("once")) &&
                trustActions.Any(value => value.Contains("Trust and connect")),
                "The host-trust dialog did not expose all three first-contact actions.");
            report.AppendLine("PASS: the generation-bound host-trust dialog exposes cancel, connect-once and durable-trust actions with WCAG AA text contrast.");

            var managementDefinitions = OpenSshKnownHostsStore.CreateDefaultDefinitions(
                Path.Combine(Path.GetTempPath(), "vt7-management-fixture-user"),
                Path.Combine(Path.GetTempPath(), "vt7-management-fixture-system"));
            var stored = PresentedHostKey.Parse(Ed25519Blob());
            var storedLine = "changed.example ssh-ed25519 " + Convert.ToBase64String(stored.Blob) + "\n";
            var primarySnapshot = OpenSshKnownHostsStore.CreateSourceSnapshot(managementDefinitions[0],
                Encoding.ASCII.GetBytes(storedLine), DateTime.UtcNow);
            var managementSnapshot = new KnownHostsStoreSnapshot(new[]
            {
                primarySnapshot,
                new KnownHostsSourceSnapshot(managementDefinitions[1], false, 0, DateTime.MinValue, string.Empty, null),
                new KnownHostsSourceSnapshot(managementDefinitions[2], false, 0, DateTime.MinValue, string.Empty, null),
                new KnownHostsSourceSnapshot(managementDefinitions[3], false, 0, DateTime.MinValue, string.Empty, null),
            });
            var problem = new HostKeyProblemRequest(Guid.NewGuid(), "changed.example", stored,
                new KnownHostTrustResult(KnownHostTrustState.Changed, "different-key-for-host",
                    new[] { "user-known-hosts:1" }), managementSnapshot);
            var management = new KnownHostsManagementDialog(problem);
            var managementBackground = Solid(management.Background, "known-host management background");
            foreach (var label in Descendants(management.FormContent).OfType<TextBlock>())
                Require(ContrastRatio(Solid(label.Foreground, "known-host management text"), managementBackground) >= 4.5,
                    "Known-host management contains text below the 4.5:1 contrast requirement.");
            Require(Descendants(management.FormContent).OfType<CheckBox>().Count() == 1 &&
                Descendants(management.FormContent).OfType<Button>().Any(button =>
                    Convert.ToString(button.Content)?.Contains("Remove selected") == true),
                "Changed-key management did not expose the selected user record and deliberate removal action.");
            report.AppendLine("PASS: changed-key management presents source identity, selected user removal and WCAG AA text contrast.");

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

        private static byte[] Ed25519Blob()
        {
            var type = Encoding.ASCII.GetBytes("ssh-ed25519");
            var blob = new byte[4 + type.Length + 4 + 32];
            WriteUInt32(blob, 0, (uint)type.Length);
            Buffer.BlockCopy(type, 0, blob, 4, type.Length);
            WriteUInt32(blob, 4 + type.Length, 32);
            for (var index = 0; index < 32; ++index)
                blob[8 + type.Length + index] = (byte)(index + 1);
            return blob;
        }

        private static void WriteUInt32(byte[] destination, int offset, uint value)
        {
            destination[offset] = (byte)(value >> 24);
            destination[offset + 1] = (byte)(value >> 16);
            destination[offset + 2] = (byte)(value >> 8);
            destination[offset + 3] = (byte)value;
        }

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }

        private static System.Collections.Generic.IEnumerable<DependencyObject> Descendants(DependencyObject root)
        {
            foreach (var child in LogicalTreeHelper.GetChildren(root).OfType<DependencyObject>())
            {
                yield return child;
                foreach (var descendant in Descendants(child)) yield return descendant;
            }
        }

        private static System.Collections.Generic.IEnumerable<DependencyObject> VisualDescendants(DependencyObject root)
        {
            for (var index = 0; index < VisualTreeHelper.GetChildrenCount(root); ++index)
            {
                var child = VisualTreeHelper.GetChild(root, index);
                yield return child;
                foreach (var descendant in VisualDescendants(child)) yield return descendant;
            }
        }

        private static Color Solid(Brush brush, string name)
        {
            if (brush is SolidColorBrush solid && solid.Color.A == byte.MaxValue) return solid.Color;
            throw new InvalidOperationException(name + " is not an opaque solid color.");
        }

        private static double ContrastRatio(Color first, Color second)
        {
            var light = Math.Max(Luminance(first), Luminance(second));
            var dark = Math.Min(Luminance(first), Luminance(second));
            return (light + 0.05) / (dark + 0.05);
        }

        private static double Luminance(Color color)
        {
            return 0.2126 * Linear(color.R) + 0.7152 * Linear(color.G) + 0.0722 * Linear(color.B);
        }

        private static double Linear(byte component)
        {
            var value = component / 255.0;
            return value <= 0.04045 ? value / 12.92 : Math.Pow((value + 0.055) / 1.055, 2.4);
        }
    }
}
