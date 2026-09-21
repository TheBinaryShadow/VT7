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
