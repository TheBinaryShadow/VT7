using System;
using System.IO;
using System.Security;
using System.Text.RegularExpressions;

namespace VT7.Host
{
    internal enum SshAuthenticationKind
    {
        PrivateKey,
        Password,
    }

    internal enum SshAddressFamily
    {
        Any,
        IPv4,
        IPv6,
    }

    internal sealed class SshConnectionOptions : IDisposable
    {
        private SecureString? _secret;

        internal SshConnectionOptions(string host, int port, string username,
            string expectedHostKeyFingerprint, SshAuthenticationKind authentication,
            string? privateKeyPath, SecureString? secret, SshAddressFamily addressFamily = SshAddressFamily.Any)
        {
            Host = (host ?? string.Empty).Trim();
            Port = port;
            Username = (username ?? string.Empty).Trim();
            ExpectedHostKeyFingerprint = NormalizeFingerprint(expectedHostKeyFingerprint);
            Authentication = authentication;
            PrivateKeyPath = string.IsNullOrWhiteSpace(privateKeyPath) ? null : Path.GetFullPath(privateKeyPath!.Trim());
            AddressFamily = addressFamily;
            var ownedSecret = secret?.Copy() ?? new SecureString();
            ownedSecret.MakeReadOnly();
            _secret = ownedSecret;
            Validate();
        }

        internal string Host { get; }
        internal int Port { get; }
        internal string Username { get; }
        internal string ExpectedHostKeyFingerprint { get; }
        internal SshAuthenticationKind Authentication { get; }
        internal string? PrivateKeyPath { get; }
        internal SshAddressFamily AddressFamily { get; }

        internal SecureString CopySecret()
        {
            var secret = _secret ?? throw new ObjectDisposedException(nameof(SshConnectionOptions));
            return secret.Copy();
        }

        private void Validate()
        {
            if (Host.Length == 0 || Host.Length > 255 || HasControl(Host))
                throw new ArgumentException("SSH host must be a non-empty hostname or address.");
            if (Port < 1 || Port > 65535) throw new ArgumentOutOfRangeException(nameof(Port));
            if (Username.Length == 0 || Username.Length > 255 || HasControl(Username))
                throw new ArgumentException("SSH username must be non-empty.");
            if (ExpectedHostKeyFingerprint.Length != 0 &&
                !Regex.IsMatch(ExpectedHostKeyFingerprint, "^[A-Za-z0-9+/]{43}$", RegexOptions.CultureInvariant))
                throw new FormatException("Trusted host-key fingerprint must be empty or a SHA256 fingerprint.");
            if (Authentication == SshAuthenticationKind.PrivateKey)
            {
                if (PrivateKeyPath == null || !File.Exists(PrivateKeyPath))
                    throw new FileNotFoundException("The selected SSH private key was not found.");
            }
            else if (Authentication == SshAuthenticationKind.Password)
            {
                if (_secret == null || _secret.Length == 0)
                    throw new ArgumentException("A password is required for password authentication.");
            }
            else
            {
                throw new ArgumentOutOfRangeException(nameof(Authentication));
            }
            if (AddressFamily != SshAddressFamily.Any && AddressFamily != SshAddressFamily.IPv4 && AddressFamily != SshAddressFamily.IPv6)
                throw new ArgumentOutOfRangeException(nameof(AddressFamily));
        }

        internal static string NormalizeFingerprint(string value)
        {
            var normalized = (value ?? string.Empty).Trim();
            if (normalized.StartsWith("SHA256:", StringComparison.OrdinalIgnoreCase))
                normalized = normalized.Substring(7);
            return normalized.Trim().TrimEnd('=');
        }

        private static bool HasControl(string value)
        {
            foreach (var character in value) if (char.IsControl(character)) return true;
            return false;
        }

        public void Dispose()
        {
            _secret?.Dispose();
            _secret = null;
        }
    }
}
