using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

namespace VT7.Host
{
    internal enum KnownHostMarker
    {
        None,
        CertAuthority,
        Revoked,
    }

    internal enum KnownHostsLineKind
    {
        Comment,
        Record,
        Malformed,
    }

    internal enum KnownHostTrustState
    {
        Matching,
        Unknown,
        Changed,
        Revoked,
        Unreadable,
        PolicyRejected,
    }

    internal sealed class KnownHostRecord
    {
        private readonly byte[] _keyBlob;

        internal KnownHostRecord(KnownHostMarker marker, string hostField, string keyType, byte[] keyBlob)
        {
            Marker = marker;
            HostField = hostField;
            KeyType = keyType;
            _keyBlob = (byte[])keyBlob.Clone();
        }

        internal KnownHostMarker Marker { get; }
        internal string HostField { get; }
        internal string KeyType { get; }
        internal byte[] KeyBlob => (byte[])_keyBlob.Clone();
    }

    internal sealed class KnownHostsLine
    {
        private readonly byte[] _rawBytes;

        internal KnownHostsLine(int lineNumber, byte[] rawBytes, KnownHostsLineKind kind,
            KnownHostRecord? record, string? candidateHostField, bool indeterminateHost, string? errorCode)
        {
            LineNumber = lineNumber;
            _rawBytes = (byte[])rawBytes.Clone();
            Kind = kind;
            Record = record;
            CandidateHostField = candidateHostField;
            IndeterminateHost = indeterminateHost;
            ErrorCode = errorCode;
        }

        internal int LineNumber { get; }
        internal byte[] RawBytes => (byte[])_rawBytes.Clone();
        internal KnownHostsLineKind Kind { get; }
        internal KnownHostRecord? Record { get; }
        internal string? CandidateHostField { get; }
        internal bool IndeterminateHost { get; }
        internal string? ErrorCode { get; }
    }

    internal sealed class KnownHostsDocument
    {
        internal KnownHostsDocument(string sourceId, IReadOnlyList<KnownHostsLine> lines, string? fatalError)
        {
            SourceId = sourceId;
            Lines = new List<KnownHostsLine>(lines).AsReadOnly();
            FatalError = fatalError;
        }

        internal string SourceId { get; }
        internal IReadOnlyList<KnownHostsLine> Lines { get; }
        internal string? FatalError { get; }
    }

    internal sealed class KnownHostTrustResult
    {
        internal KnownHostTrustResult(KnownHostTrustState state, string reason,
            IReadOnlyList<string> locations)
        {
            State = state;
            Reason = reason;
            Locations = new List<string>(locations).AsReadOnly();
        }

        internal KnownHostTrustState State { get; }
        internal string Reason { get; }
        internal IReadOnlyList<string> Locations { get; }
    }

    internal sealed class PresentedHostKey
    {
        private readonly byte[] _blob;

        private PresentedHostKey(string keyType, byte[] blob, string fingerprint)
        {
            KeyType = keyType;
            _blob = (byte[])blob.Clone();
            Fingerprint = fingerprint;
        }

        internal string KeyType { get; }
        internal byte[] Blob => (byte[])_blob.Clone();
        internal string Fingerprint { get; }
        internal bool IsCertificate => KeyType.EndsWith("-cert-v01@openssh.com", StringComparison.Ordinal);

        internal static PresentedHostKey Parse(byte[] blob)
        {
            if (blob == null) throw new ArgumentNullException(nameof(blob));
            var copy = (byte[])blob.Clone();
            var keyType = OpenSshKeyBlob.ReadKeyType(copy);
            using var sha = SHA256.Create();
            var fingerprint = Convert.ToBase64String(sha.ComputeHash(copy)).TrimEnd('=');
            return new PresentedHostKey(keyType, copy, "SHA256:" + fingerprint);
        }
    }

    internal sealed class KnownHostCertificateFacts
    {
        private readonly byte[] _certificateBlob;
        private readonly byte[] _authorityBlob;

        internal KnownHostCertificateFacts(string certificateType, byte[] certificateBlob,
            byte[] authorityBlob, bool isHost, IEnumerable<string> principals,
            bool hasCriticalOptions, ulong validAfter, ulong validBefore)
        {
            CertificateType = certificateType ?? throw new ArgumentNullException(nameof(certificateType));
            _certificateBlob = (byte[])(certificateBlob ?? throw new ArgumentNullException(nameof(certificateBlob))).Clone();
            _authorityBlob = (byte[])(authorityBlob ?? throw new ArgumentNullException(nameof(authorityBlob))).Clone();
            IsHost = isHost;
            Principals = (principals ?? throw new ArgumentNullException(nameof(principals))).ToArray();
            HasCriticalOptions = hasCriticalOptions;
            ValidAfter = validAfter;
            ValidBefore = validBefore;
        }

        internal string CertificateType { get; }
        internal byte[] CertificateBlob => (byte[])_certificateBlob.Clone();
        internal byte[] AuthorityBlob => (byte[])_authorityBlob.Clone();
        internal bool IsHost { get; }
        internal IReadOnlyList<string> Principals { get; }
        internal bool HasCriticalOptions { get; }
        internal ulong ValidAfter { get; }
        internal ulong ValidBefore { get; }
    }

    internal static class OpenSshKeyBlob
    {
        internal const int MaximumDecodedBytes = 64 * 1024;

        internal static string ReadKeyType(byte[] blob)
        {
            if (blob.Length < 5 || blob.Length > MaximumDecodedBytes)
                throw new FormatException("host-key-blob-length");
            var length = ReadUInt32(blob, 0);
            if (length == 0 || length > 256 || length > (uint)(blob.Length - 4))
                throw new FormatException("host-key-type-length");
            var keyTypeLength = checked((int)length);
            for (var index = 4; index < 4 + keyTypeLength; ++index)
            {
                var value = blob[index];
                if (value < 0x21 || value > 0x7e)
                    throw new FormatException("host-key-type-character");
            }
            return Encoding.ASCII.GetString(blob, 4, keyTypeLength);
        }

        private static uint ReadUInt32(byte[] bytes, int offset) =>
            ((uint)bytes[offset] << 24) | ((uint)bytes[offset + 1] << 16) |
            ((uint)bytes[offset + 2] << 8) | bytes[offset + 3];
    }

    internal static class OpenSshHostToken
    {
        internal static string Create(string host, int port)
        {
            if (host == null) throw new ArgumentNullException(nameof(host));
            if (port < 1 || port > 65535) throw new ArgumentOutOfRangeException(nameof(port));
            if (host.Length == 0 || host.Length > 255 || !string.Equals(host, host.Trim(), StringComparison.Ordinal))
                throw new FormatException("host-token-length-or-spacing");
            if (host.Length >= 2 && host[0] == '[' && host[host.Length - 1] == ']')
                host = host.Substring(1, host.Length - 2);
            if (host.Length == 0) throw new FormatException("host-token-empty");
            var builder = new StringBuilder(host.Length);
            foreach (var character in host)
            {
                if (character > 0x7f || char.IsControl(character) || char.IsWhiteSpace(character) || character == ',')
                    throw new FormatException("host-token-character");
                builder.Append(character >= 'A' && character <= 'Z' ? (char)(character + 32) : character);
            }
            var normalized = builder.ToString();
            return port == 22 ? normalized : "[" + normalized + "]:" + port.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }
    }

    internal static class OpenSshHostMatcher
    {
        internal static bool Matches(string hostToken, string hostField)
        {
            if (hostToken == null) throw new ArgumentNullException(nameof(hostToken));
            if (hostField == null) throw new ArgumentNullException(nameof(hostField));
            if (hostField.StartsWith("|", StringComparison.Ordinal))
                return MatchesHashed(hostToken, hostField);

            var positive = false;
            foreach (var item in hostField.Split(','))
            {
                if (item.Length == 0) throw new FormatException("host-pattern-empty");
                var negative = item[0] == '!';
                var pattern = negative ? item.Substring(1) : item;
                if (pattern.Length == 0) throw new FormatException("host-pattern-empty");
                if (!GlobMatches(hostToken, pattern)) continue;
                if (negative) return false;
                positive = true;
            }
            return positive;
        }

        internal static string Hash(string hostToken, byte[] salt)
        {
            if (salt == null || salt.Length != 20) throw new ArgumentException("OpenSSH host hashes require a 20-byte salt.", nameof(salt));
            byte[] digest;
            using (var hmac = new HMACSHA1((byte[])salt.Clone()))
                digest = hmac.ComputeHash(Encoding.UTF8.GetBytes(hostToken));
            return "|1|" + Convert.ToBase64String(salt) + "|" + Convert.ToBase64String(digest);
        }

        internal static bool IsValidHostField(string field, out bool indeterminate)
        {
            indeterminate = false;
            if (string.IsNullOrEmpty(field) || field.Length > OpenSshKnownHostsParser.MaximumHostFieldBytes)
                return false;
            if (field[0] == '|')
            {
                indeterminate = true;
                try
                {
                    ParseHash(field, out _, out _);
                    indeterminate = false;
                    return true;
                }
                catch (FormatException) { return false; }
            }
            var items = field.Split(',');
            if (items.Length > OpenSshKnownHostsParser.MaximumPatternsPerLine) return false;
            foreach (var item in items)
            {
                var pattern = item.Length > 0 && item[0] == '!' ? item.Substring(1) : item;
                if (pattern.Length == 0) return false;
            }
            return true;
        }

        private static bool MatchesHashed(string hostToken, string hostField)
        {
            ParseHash(hostField, out var salt, out var expected);
            byte[] actual;
            using (var hmac = new HMACSHA1(salt))
                actual = hmac.ComputeHash(Encoding.UTF8.GetBytes(hostToken));
            return FixedEquals(actual, expected);
        }

        private static void ParseHash(string field, out byte[] salt, out byte[] digest)
        {
            var parts = field.Split('|');
            if (parts.Length != 4 || parts[0].Length != 0 || parts[1] != "1")
                throw new FormatException("host-hash-format");
            try
            {
                salt = Convert.FromBase64String(parts[2]);
                digest = Convert.FromBase64String(parts[3]);
            }
            catch (FormatException)
            {
                throw new FormatException("host-hash-base64");
            }
            if (salt.Length != 20 || digest.Length != 20)
                throw new FormatException("host-hash-length");
        }

        private static bool FixedEquals(byte[] first, byte[] second)
        {
            var difference = first.Length ^ second.Length;
            var maximum = Math.Max(first.Length, second.Length);
            for (var index = 0; index < maximum; ++index)
            {
                var left = index < first.Length ? first[index] : 0;
                var right = index < second.Length ? second[index] : 0;
                difference |= left ^ right;
            }
            return difference == 0;
        }

        private static bool GlobMatches(string value, string pattern)
        {
            var valueIndex = 0;
            var patternIndex = 0;
            var star = -1;
            var retry = 0;
            while (valueIndex < value.Length)
            {
                if (patternIndex < pattern.Length && (pattern[patternIndex] == '?' ||
                    Fold(pattern[patternIndex]) == Fold(value[valueIndex])))
                {
                    ++patternIndex;
                    ++valueIndex;
                }
                else if (patternIndex < pattern.Length && pattern[patternIndex] == '*')
                {
                    star = patternIndex++;
                    retry = valueIndex;
                }
                else if (star >= 0)
                {
                    patternIndex = star + 1;
                    valueIndex = ++retry;
                }
                else return false;
            }
            while (patternIndex < pattern.Length && pattern[patternIndex] == '*') ++patternIndex;
            return patternIndex == pattern.Length;
        }

        private static char Fold(char value) => value >= 'A' && value <= 'Z' ? (char)(value + 32) : value;
    }

    internal static class OpenSshKnownHostsParser
    {
        internal const int MaximumFileBytes = 16 * 1024 * 1024;
        internal const int MaximumLineBytes = 64 * 1024;
        internal const int MaximumRecords = 16 * 1024;
        internal const int MaximumPatternsPerLine = 256;
        internal const int MaximumHostFieldBytes = 8 * 1024;

        internal static KnownHostsDocument Parse(string sourceId, byte[] content)
        {
            if (sourceId == null) throw new ArgumentNullException(nameof(sourceId));
            if (content == null) throw new ArgumentNullException(nameof(content));
            if (content.Length > MaximumFileBytes)
                return new KnownHostsDocument(sourceId, Array.Empty<KnownHostsLine>(), "file-size-limit");

            var lines = new List<KnownHostsLine>();
            var recordCount = 0;
            var offset = 0;
            var lineNumber = 1;
            while (offset < content.Length)
            {
                var end = Array.IndexOf(content, (byte)'\n', offset);
                var after = end < 0 ? content.Length : end + 1;
                var rawLength = after - offset;
                var semanticLength = (end < 0 ? content.Length : end) - offset;
                if (semanticLength > 0 && content[offset + semanticLength - 1] == '\r') --semanticLength;
                var raw = new byte[rawLength];
                Buffer.BlockCopy(content, offset, raw, 0, rawLength);
                if (semanticLength > MaximumLineBytes)
                    return new KnownHostsDocument(sourceId, lines, "line-size-limit:" + lineNumber);
                var semantic = new byte[semanticLength];
                Buffer.BlockCopy(content, offset, semantic, 0, semanticLength);
                var parsed = ParseLine(lineNumber, raw, semantic);
                lines.Add(parsed);
                if (parsed.Kind == KnownHostsLineKind.Record && ++recordCount > MaximumRecords)
                    return new KnownHostsDocument(sourceId, lines, "record-count-limit");
                offset = after;
                ++lineNumber;
            }
            return new KnownHostsDocument(sourceId, lines, null);
        }

        private static KnownHostsLine ParseLine(int lineNumber, byte[] raw, byte[] semantic)
        {
            var index = 0;
            SkipSpacing(semantic, ref index);
            if (index == semantic.Length || semantic[index] == '#')
                return new KnownHostsLine(lineNumber, raw, KnownHostsLineKind.Comment, null, null, false, null);

            string? hostField = null;
            var indeterminate = false;
            try
            {
                var first = ReadToken(semantic, ref index);
                var marker = KnownHostMarker.None;
                if (first.Length > 0 && first[0] == '@')
                {
                    marker = first == "@cert-authority" ? KnownHostMarker.CertAuthority :
                        first == "@revoked" ? KnownHostMarker.Revoked : throw new FormatException("marker");
                    hostField = ReadToken(semantic, ref index);
                }
                else hostField = first;

                if (!OpenSshHostMatcher.IsValidHostField(hostField, out indeterminate))
                    throw new FormatException("host-field");
                var keyType = ReadToken(semantic, ref index);
                var encodedKey = ReadToken(semantic, ref index);
                byte[] keyBlob;
                try { keyBlob = DecodeBase64(encodedKey); }
                catch (FormatException) { throw new FormatException("key-base64"); }
                var blobType = OpenSshKeyBlob.ReadKeyType(keyBlob);
                if (!string.Equals(keyType, blobType, StringComparison.Ordinal))
                    throw new FormatException("key-type-mismatch");
                var record = new KnownHostRecord(marker, hostField, keyType, keyBlob);
                return new KnownHostsLine(lineNumber, raw, KnownHostsLineKind.Record, record, hostField, false, null);
            }
            catch (FormatException error)
            {
                if (hostField == null)
                {
                    hostField = TryCandidateHostField(semantic, out indeterminate);
                    if (hostField == null) indeterminate = true;
                }
                return new KnownHostsLine(lineNumber, raw, KnownHostsLineKind.Malformed, null,
                    hostField, indeterminate, error.Message);
            }
        }

        private static string? TryCandidateHostField(byte[] line, out bool indeterminate)
        {
            indeterminate = false;
            try
            {
                var index = 0;
                SkipSpacing(line, ref index);
                var first = ReadToken(line, ref index);
                var candidate = first.Length > 0 && first[0] == '@' ? ReadToken(line, ref index) : first;
                if (candidate.StartsWith("|", StringComparison.Ordinal)) indeterminate = true;
                return candidate;
            }
            catch (FormatException) { return null; }
        }

        private static byte[] DecodeBase64(string value)
        {
            if (value.Length == 0 || value.Length > ((OpenSshKeyBlob.MaximumDecodedBytes + 2) / 3) * 4)
                throw new FormatException();
            foreach (var character in value)
            {
                if (!((character >= 'A' && character <= 'Z') || (character >= 'a' && character <= 'z') ||
                    (character >= '0' && character <= '9') || character == '+' || character == '/' || character == '='))
                    throw new FormatException();
            }
            var remainder = value.Length % 4;
            if (remainder == 1) throw new FormatException();
            var padded = remainder == 0 ? value : value + new string('=', 4 - remainder);
            var bytes = Convert.FromBase64String(padded);
            if (bytes.Length == 0 || bytes.Length > OpenSshKeyBlob.MaximumDecodedBytes) throw new FormatException();
            return bytes;
        }

        private static string ReadToken(byte[] line, ref int index)
        {
            SkipSpacing(line, ref index);
            if (index >= line.Length) throw new FormatException("truncated");
            var start = index;
            while (index < line.Length && line[index] != ' ' && line[index] != '\t')
            {
                if (line[index] < 0x21 || line[index] > 0x7e) throw new FormatException("token-character");
                ++index;
            }
            if (index == start) throw new FormatException("truncated");
            return Encoding.ASCII.GetString(line, start, index - start);
        }

        private static void SkipSpacing(byte[] line, ref int index)
        {
            while (index < line.Length && (line[index] == ' ' || line[index] == '\t')) ++index;
        }
    }

    internal static class KnownHostTrustResolver
    {
        internal static KnownHostTrustResult Resolve(string hostToken, PresentedHostKey presented,
            IEnumerable<KnownHostsDocument> documents)
        {
            if (hostToken == null) throw new ArgumentNullException(nameof(hostToken));
            if (presented == null) throw new ArgumentNullException(nameof(presented));
            if (documents == null) throw new ArgumentNullException(nameof(documents));

            var revoked = new List<string>();
            var unreadable = new List<string>();
            var exact = new List<string>();
            var changed = new List<string>();
            var certificatePolicy = new List<string>();

            foreach (var document in documents)
            {
                if (document.FatalError != null)
                    unreadable.Add(document.SourceId + ":" + document.FatalError);
                foreach (var line in document.Lines)
                {
                    var location = document.SourceId + ":" + line.LineNumber;
                    if (line.Kind == KnownHostsLineKind.Malformed)
                    {
                        if (line.IndeterminateHost || CandidateMatches(hostToken, line.CandidateHostField))
                            unreadable.Add(location);
                        continue;
                    }
                    var record = line.Record;
                    if (record == null || !OpenSshHostMatcher.Matches(hostToken, record.HostField)) continue;
                    var same = FixedEquals(record.KeyBlob, presented.Blob);
                    if (record.Marker == KnownHostMarker.Revoked)
                    {
                        if (same) revoked.Add(location);
                    }
                    else if (record.Marker == KnownHostMarker.CertAuthority)
                    {
                        if (presented.IsCertificate) certificatePolicy.Add(location);
                    }
                    else if (same) exact.Add(location);
                    else changed.Add(location);
                }
            }

            if (revoked.Count > 0) return Result(KnownHostTrustState.Revoked, "matching-revoked-key", revoked);
            if (unreadable.Count > 0) return Result(KnownHostTrustState.Unreadable, "relevant-store-data-unreadable", unreadable);
            if (presented.IsCertificate)
                return Result(KnownHostTrustState.PolicyRejected, "certificate-verification-unavailable", certificatePolicy);
            if (exact.Count > 0) return Result(KnownHostTrustState.Matching, "exact-key-blob", exact);
            if (changed.Count > 0) return Result(KnownHostTrustState.Changed, "different-key-for-host", changed);
            return Result(KnownHostTrustState.Unknown, "no-applicable-key", Array.Empty<string>());
        }

        internal static KnownHostTrustResult ResolveCertificate(string hostToken, PresentedHostKey certifiedKey,
            KnownHostCertificateFacts certificate, IEnumerable<KnownHostsDocument> documents)
        {
            if (hostToken == null) throw new ArgumentNullException(nameof(hostToken));
            if (certifiedKey == null) throw new ArgumentNullException(nameof(certifiedKey));
            if (certificate == null) throw new ArgumentNullException(nameof(certificate));
            if (documents == null) throw new ArgumentNullException(nameof(documents));
            var revoked = new List<string>();
            var unreadable = new List<string>();
            var authorities = new List<string>();
            var certBlob = certificate.CertificateBlob;
            var caBlob = certificate.AuthorityBlob;
            foreach (var document in documents)
            {
                if (document.FatalError != null) unreadable.Add(document.SourceId + ":" + document.FatalError);
                foreach (var line in document.Lines)
                {
                    var location = document.SourceId + ":" + line.LineNumber;
                    if (line.Kind == KnownHostsLineKind.Malformed)
                    {
                        if (line.IndeterminateHost || CandidateMatches(hostToken, line.CandidateHostField))
                            unreadable.Add(location);
                        continue;
                    }
                    var record = line.Record;
                    if (record == null || !OpenSshHostMatcher.Matches(hostToken, record.HostField)) continue;
                    var blob = record.KeyBlob;
                    if (record.Marker == KnownHostMarker.Revoked &&
                        (FixedEquals(blob, certBlob) || FixedEquals(blob, certifiedKey.Blob) ||
                         FixedEquals(blob, caBlob)))
                        revoked.Add(location);
                    if (record.Marker == KnownHostMarker.CertAuthority && FixedEquals(blob, caBlob))
                        authorities.Add(location);
                }
            }
            if (revoked.Count > 0) return Result(KnownHostTrustState.Revoked, "certificate-material-revoked", revoked);
            if (unreadable.Count > 0) return Result(KnownHostTrustState.Unreadable,
                "relevant-store-data-unreadable", unreadable);
            if (!certificate.IsHost || certifiedKey.IsCertificate ||
                certificate.CertificateType != OpenSshKeyBlob.ReadKeyType(certBlob) ||
                OpenSshKeyBlob.ReadKeyType(caBlob).EndsWith("-cert-v01@openssh.com", StringComparison.Ordinal) ||
                !CertificateTypeMatchesKey(certificate.CertificateType, certifiedKey.KeyType))
                return Result(KnownHostTrustState.PolicyRejected, "certificate-material-invalid", authorities);
            var now = (ulong)DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            if (certificate.ValidAfter > now || now >= certificate.ValidBefore)
                return Result(KnownHostTrustState.PolicyRejected, "certificate-expired-or-not-yet-valid", authorities);
            if (certificate.HasCriticalOptions)
                return Result(KnownHostTrustState.PolicyRejected, "certificate-critical-option", authorities);
            var principalHost = CertificatePrincipalHost(hostToken);
            if (certificate.Principals.Count == 0 || certificate.Principals.Count > 256 ||
                !certificate.Principals.Any(principal => CertificatePrincipalMatches(principalHost, principal)))
                return Result(KnownHostTrustState.PolicyRejected, "certificate-principal-mismatch", authorities);
            if (authorities.Count == 0)
                return Result(KnownHostTrustState.PolicyRejected, "certificate-authority-untrusted", Array.Empty<string>());
            return Result(KnownHostTrustState.Matching, "certificate-authority-match", authorities);
        }

        private static bool CertificateTypeMatchesKey(string certificateType, string keyType)
        {
            const string suffix = "-cert-v01@openssh.com";
            if (!certificateType.EndsWith(suffix, StringComparison.Ordinal)) return false;
            var baseType = certificateType.Substring(0, certificateType.Length - suffix.Length);
            if (baseType == "rsa-sha2-256" || baseType == "rsa-sha2-512") baseType = "ssh-rsa";
            return string.Equals(baseType, keyType, StringComparison.Ordinal);
        }

        private static string CertificatePrincipalHost(string hostToken)
        {
            if (hostToken.Length > 2 && hostToken[0] == '[')
            {
                var close = hostToken.LastIndexOf("]:" , StringComparison.Ordinal);
                if (close > 0) return hostToken.Substring(1, close - 1);
            }
            return hostToken;
        }

        private static bool CertificatePrincipalMatches(string host, string pattern)
        {
            // OpenSSH checks certificate principals with match_pattern, which is
            // case-sensitive and treats each principal as one wildcard pattern.
            // The known_hosts hostname matcher has different case/list rules.
            if (string.IsNullOrEmpty(pattern) || pattern.Length > 1024 ||
                pattern.Any(character => character < 0x21 || character > 0x7e)) return false;
            var hostIndex = 0;
            var patternIndex = 0;
            var star = -1;
            var retry = 0;
            while (hostIndex < host.Length)
            {
                if (patternIndex < pattern.Length &&
                    (pattern[patternIndex] == '?' || pattern[patternIndex] == host[hostIndex]))
                {
                    ++patternIndex;
                    ++hostIndex;
                }
                else if (patternIndex < pattern.Length && pattern[patternIndex] == '*')
                {
                    star = patternIndex++;
                    retry = hostIndex;
                }
                else if (star >= 0)
                {
                    patternIndex = star + 1;
                    hostIndex = ++retry;
                }
                else return false;
            }
            while (patternIndex < pattern.Length && pattern[patternIndex] == '*') ++patternIndex;
            return patternIndex == pattern.Length;
        }

        private static bool CandidateMatches(string hostToken, string? candidate)
        {
            if (string.IsNullOrEmpty(candidate)) return false;
            try { return OpenSshHostMatcher.Matches(hostToken, candidate!); }
            catch (FormatException)
            {
                if (candidate![0] == '|') return true;
                foreach (var item in candidate.Split(','))
                {
                    if (item.Length == 0) continue;
                    try { if (OpenSshHostMatcher.Matches(hostToken, item)) return true; }
                    catch (FormatException) { }
                }
                return false;
            }
        }

        private static KnownHostTrustResult Result(KnownHostTrustState state, string reason, IEnumerable<string> locations) =>
            new KnownHostTrustResult(state, reason, locations.Distinct(StringComparer.Ordinal).ToArray());

        private static bool FixedEquals(byte[] first, byte[] second)
        {
            var difference = first.Length ^ second.Length;
            var maximum = Math.Max(first.Length, second.Length);
            for (var index = 0; index < maximum; ++index)
                difference |= (index < first.Length ? first[index] : 0) ^ (index < second.Length ? second[index] : 0);
            return difference == 0;
        }
    }
}
