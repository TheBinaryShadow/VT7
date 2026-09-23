using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security;
using System.Security.Cryptography;
using System.Text;

namespace VT7.Host
{
    internal sealed class KnownHostsSourceDefinition
    {
        internal KnownHostsSourceDefinition(string sourceId, string path)
        {
            if (string.IsNullOrWhiteSpace(sourceId)) throw new ArgumentException("A known-host source ID is required.", nameof(sourceId));
            SourceId = sourceId;
            Path = System.IO.Path.GetFullPath(path ?? throw new ArgumentNullException(nameof(path)));
        }

        internal string SourceId { get; }
        internal string Path { get; }
    }

    internal sealed class KnownHostsSourceSnapshot
    {
        internal KnownHostsSourceSnapshot(KnownHostsSourceDefinition definition, bool exists,
            long length, DateTime lastWriteUtc, string contentHash, KnownHostsDocument? document)
        {
            Definition = definition;
            Exists = exists;
            Length = length;
            LastWriteUtc = lastWriteUtc;
            ContentHash = contentHash;
            Document = document;
        }

        internal KnownHostsSourceDefinition Definition { get; }
        internal bool Exists { get; }
        internal long Length { get; }
        internal DateTime LastWriteUtc { get; }
        internal string ContentHash { get; }
        internal KnownHostsDocument? Document { get; }
    }

    internal sealed class KnownHostsStoreSnapshot
    {
        internal KnownHostsStoreSnapshot(IEnumerable<KnownHostsSourceSnapshot> sources)
        {
            Sources = new List<KnownHostsSourceSnapshot>(sources ?? throw new ArgumentNullException(nameof(sources))).AsReadOnly();
            Documents = Sources.Where(source => source.Document != null)
                .Select(source => source.Document!).ToArray();
        }

        internal IReadOnlyList<KnownHostsSourceSnapshot> Sources { get; }
        internal IReadOnlyList<KnownHostsDocument> Documents { get; }
    }

    internal sealed class KnownHostTrustDecision
    {
        internal KnownHostTrustDecision(KnownHostTrustResult result, bool fingerprintSupplied,
            bool fingerprintMatched, bool canTrust, string authorization)
        {
            Result = result;
            FingerprintSupplied = fingerprintSupplied;
            FingerprintMatched = fingerprintMatched;
            CanTrust = canTrust;
            Authorization = authorization;
        }

        internal KnownHostTrustResult Result { get; }
        internal bool FingerprintSupplied { get; }
        internal bool FingerprintMatched { get; }
        internal bool CanTrust { get; }
        internal string Authorization { get; }
    }

    internal static class OpenSshKnownHostsStore
    {
        private const int CopyBufferBytes = 64 * 1024;

        internal static KnownHostsStoreSnapshot LoadDefault()
        {
            var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            var programData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
            return Load(CreateDefaultDefinitions(userProfile, programData));
        }

        internal static IReadOnlyList<KnownHostsSourceDefinition> CreateDefaultDefinitions(
            string userProfile, string programData)
        {
            if (string.IsNullOrWhiteSpace(userProfile))
                throw new InvalidOperationException("The Windows user profile path is unavailable.");
            if (string.IsNullOrWhiteSpace(programData))
                throw new InvalidOperationException("The Windows ProgramData path is unavailable.");
            var userSsh = System.IO.Path.Combine(System.IO.Path.GetFullPath(userProfile), ".ssh");
            var systemSsh = System.IO.Path.Combine(System.IO.Path.GetFullPath(programData), "ssh");
            return new[]
            {
                new KnownHostsSourceDefinition("user-known-hosts", System.IO.Path.Combine(userSsh, "known_hosts")),
                new KnownHostsSourceDefinition("user-known-hosts2", System.IO.Path.Combine(userSsh, "known_hosts2")),
                new KnownHostsSourceDefinition("system-known-hosts", System.IO.Path.Combine(systemSsh, "ssh_known_hosts")),
                new KnownHostsSourceDefinition("system-known-hosts2", System.IO.Path.Combine(systemSsh, "ssh_known_hosts2")),
            };
        }

        internal static KnownHostsStoreSnapshot Load(IEnumerable<KnownHostsSourceDefinition> definitions)
        {
            if (definitions == null) throw new ArgumentNullException(nameof(definitions));
            return new KnownHostsStoreSnapshot(definitions.Select(LoadSource));
        }

        private static KnownHostsSourceSnapshot LoadSource(KnownHostsSourceDefinition definition)
        {
            try
            {
                FileAttributes attributes;
                try { attributes = File.GetAttributes(definition.Path); }
                catch (FileNotFoundException) { return Missing(definition); }
                catch (DirectoryNotFoundException) { return Missing(definition); }

                if ((attributes & FileAttributes.Directory) != 0)
                    return Failed(definition, "source-not-file");

                var before = new FileInfo(definition.Path);
                before.Refresh();
                if (!before.Exists) return Failed(definition, "source-changed-during-load");
                var beforeLength = before.Length;
                var beforeWrite = before.LastWriteTimeUtc;
                if (beforeLength > OpenSshKnownHostsParser.MaximumFileBytes)
                    return Failed(definition, "file-size-limit", beforeLength, beforeWrite);

                byte[] content;
                using (var input = new FileStream(definition.Path, FileMode.Open, FileAccess.Read,
                    FileShare.ReadWrite | FileShare.Delete, CopyBufferBytes, FileOptions.SequentialScan))
                using (var output = new MemoryStream(beforeLength > 0 ? checked((int)beforeLength) : 0))
                {
                    var buffer = new byte[CopyBufferBytes];
                    while (true)
                    {
                        var read = input.Read(buffer, 0, buffer.Length);
                        if (read == 0) break;
                        if (output.Length + read > OpenSshKnownHostsParser.MaximumFileBytes)
                            return Failed(definition, "file-size-limit", output.Length + read, beforeWrite);
                        output.Write(buffer, 0, read);
                    }
                    content = output.ToArray();
                }

                var after = new FileInfo(definition.Path);
                after.Refresh();
                if (!after.Exists || after.Length != beforeLength || after.LastWriteTimeUtc != beforeWrite ||
                    content.LongLength != beforeLength)
                    return Failed(definition, "source-changed-during-load", content.LongLength, beforeWrite);

                string hash;
                using (var sha = SHA256.Create())
                    hash = BitConverter.ToString(sha.ComputeHash(content)).Replace("-", string.Empty);
                var document = OpenSshKnownHostsParser.Parse(definition.SourceId, content);
                return new KnownHostsSourceSnapshot(definition, true, content.LongLength, beforeWrite, hash, document);
            }
            catch (Exception error) when (IsSourceFailure(error))
            {
                return Failed(definition, "source-read-failed");
            }
        }

        private static bool IsSourceFailure(Exception error) =>
            error is IOException || error is UnauthorizedAccessException || error is SecurityException ||
            error is NotSupportedException;

        private static KnownHostsSourceSnapshot Missing(KnownHostsSourceDefinition definition) =>
            new KnownHostsSourceSnapshot(definition, false, 0, DateTime.MinValue, string.Empty, null);

        private static KnownHostsSourceSnapshot Failed(KnownHostsSourceDefinition definition, string reason,
            long length = 0, DateTime lastWriteUtc = default) =>
            new KnownHostsSourceSnapshot(definition, true, length, lastWriteUtc, string.Empty,
                new KnownHostsDocument(definition.SourceId, Array.Empty<KnownHostsLine>(), reason));
    }

    internal static class KnownHostTrustPolicy
    {
        internal static KnownHostTrustDecision Decide(string hostToken, PresentedHostKey presented,
            KnownHostsStoreSnapshot snapshot, string expectedFingerprint)
        {
            if (snapshot == null) throw new ArgumentNullException(nameof(snapshot));
            var result = KnownHostTrustResolver.Resolve(hostToken, presented, snapshot.Documents);
            var normalized = SshConnectionOptions.NormalizeFingerprint(expectedFingerprint);
            var supplied = normalized.Length != 0;
            var actual = presented.Fingerprint.StartsWith("SHA256:", StringComparison.Ordinal)
                ? presented.Fingerprint.Substring(7) : presented.Fingerprint;
            var matched = supplied && FixedEquals(actual, normalized);

            if (result.State == KnownHostTrustState.Matching)
            {
                if (supplied && !matched)
                    return new KnownHostTrustDecision(result, true, false, false, "explicit-fingerprint-mismatch");
                return new KnownHostTrustDecision(result, supplied, matched, true, "stored-key-match");
            }
            if (result.State == KnownHostTrustState.Unknown && matched)
                return new KnownHostTrustDecision(result, true, true, true, "one-connection-fingerprint");
            return new KnownHostTrustDecision(result, supplied, matched, false,
                result.State == KnownHostTrustState.Unknown ? "unknown-fingerprint-required" : "stored-policy-block");
        }

        private static bool FixedEquals(string first, string second)
        {
            var left = Encoding.ASCII.GetBytes(first ?? string.Empty);
            var right = Encoding.ASCII.GetBytes(second ?? string.Empty);
            var difference = left.Length ^ right.Length;
            var maximum = Math.Max(left.Length, right.Length);
            for (var index = 0; index < maximum; ++index)
                difference |= (index < left.Length ? left[index] : 0) ^ (index < right.Length ? right[index] : 0);
            return difference == 0;
        }
    }
}
