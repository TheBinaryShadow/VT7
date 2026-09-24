using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Threading;

namespace VT7.Host
{
    internal sealed class KnownHostsMutationException : Exception
    {
        internal KnownHostsMutationException(string category, Exception? inner = null)
            : base("The OpenSSH known-host update failed during " + category + ".", inner) => Category = category;

        internal string Category { get; }
    }

    internal static class OpenSshKnownHostsWriter
    {
        private const int BufferBytes = 64 * 1024;
        private static readonly TimeSpan MutexTimeout = TimeSpan.FromSeconds(5);
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false, true);

        internal static KnownHostsStoreSnapshot AddPrimaryUserRecord(
            KnownHostsStoreSnapshot discoverySnapshot, string hostToken, PresentedHostKey presented)
        {
            if (discoverySnapshot == null) throw new ArgumentNullException(nameof(discoverySnapshot));
            if (hostToken == null) throw new ArgumentNullException(nameof(hostToken));
            if (presented == null) throw new ArgumentNullException(nameof(presented));
            if (hostToken.Length == 0 || hostToken.Any(character => character <= ' ' || character == '\u007f'))
                throw new KnownHostsMutationException("host-token");
            if (presented.IsCertificate) throw new KnownHostsMutationException("certificate-policy");
            if (discoverySnapshot.Sources.Count != 4 ||
                !string.Equals(discoverySnapshot.Sources[0].Definition.SourceId, "user-known-hosts", StringComparison.Ordinal))
                throw new KnownHostsMutationException("source-layout");

            var definitions = discoverySnapshot.Sources.Select(source => source.Definition).ToArray();
            var primary = definitions[0];
            using (var mutex = new Mutex(false, MutexName(primary.Path)))
            {
                var acquired = false;
                try
                {
                    try { acquired = mutex.WaitOne(MutexTimeout); }
                    catch (AbandonedMutexException) { acquired = true; }
                    if (!acquired) throw new KnownHostsMutationException("writer-lock-timeout");

                    var fresh = OpenSshKnownHostsStore.Load(definitions);
                    if (!string.Equals(fresh.Identity, discoverySnapshot.Identity, StringComparison.Ordinal))
                        throw new KnownHostsMutationException("store-generation-changed");

                    var directory = Path.GetDirectoryName(primary.Path);
                    if (string.IsNullOrEmpty(directory)) throw new KnownHostsMutationException("primary-path");
                    EnsureSafeDirectory(directory!);
                    EnsureSafeFileTarget(primary.Path);

                    var existed = File.Exists(primary.Path);
                    long expectedPrimaryLength;
                    string expectedPrimaryHash;
                    using (var stream = OpenPrimary(primary.Path, existed))
                    {
                        var content = ReadBounded(stream);
                        var current = OpenSshKnownHostsStore.CreateSourceSnapshot(primary, content,
                            File.GetLastWriteTimeUtc(primary.Path));
                        if (!PrimaryMatchesFresh(fresh.Sources[0], current, existed))
                            throw new KnownHostsMutationException("primary-generation-changed");

                        var sources = fresh.Sources.ToArray();
                        sources[0] = current;
                        var held = new KnownHostsStoreSnapshot(sources);
                        var before = KnownHostTrustResolver.Resolve(hostToken, presented, held.Documents);
                        if (before.State != KnownHostTrustState.Unknown)
                            throw new KnownHostsMutationException("trust-state-changed-" + before.State.ToString().ToLowerInvariant());

                        var addition = BuildAddition(content, hostToken, presented);
                        if (content.LongLength + addition.LongLength > OpenSshKnownHostsParser.MaximumFileBytes)
                            throw new KnownHostsMutationException("file-size-limit");
                        expectedPrimaryLength = content.LongLength + addition.LongLength;
                        expectedPrimaryHash = HashCombined(content, addition);
                        stream.Position = stream.Length;
                        stream.Write(addition, 0, addition.Length);
                        stream.Flush(true);
                    }

                    var verified = OpenSshKnownHostsStore.Load(definitions);
                    if (verified.Sources.Count != fresh.Sources.Count ||
                        !verified.Sources[0].Exists ||
                        verified.Sources[0].Length != expectedPrimaryLength ||
                        !string.Equals(verified.Sources[0].ContentHash, expectedPrimaryHash, StringComparison.Ordinal) ||
                        verified.Sources.Skip(1).Zip(fresh.Sources.Skip(1), SameSource).Any(same => !same))
                        throw new KnownHostsMutationException("read-back-generation");
                    var result = KnownHostTrustResolver.Resolve(hostToken, presented, verified.Documents);
                    if (result.State != KnownHostTrustState.Matching)
                        throw new KnownHostsMutationException("read-back-verification");
                    return verified;
                }
                catch (KnownHostsMutationException) { throw; }
                catch (Exception error) when (IsMutationFailure(error))
                {
                    throw new KnownHostsMutationException("filesystem", error);
                }
                finally
                {
                    if (acquired) mutex.ReleaseMutex();
                }
            }
        }

        private static FileStream OpenPrimary(string path, bool existed)
        {
            if (existed)
            {
                var attributes = File.GetAttributes(path);
                if ((attributes & (FileAttributes.Directory | FileAttributes.ReparsePoint | FileAttributes.ReadOnly)) != 0)
                    throw new KnownHostsMutationException("unsafe-primary-file");
                return new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.Read,
                    BufferBytes, FileOptions.SequentialScan);
            }

            var security = OwnerFileSecurity();
            return new FileStream(path, FileMode.CreateNew,
                FileSystemRights.ReadData | FileSystemRights.WriteData | FileSystemRights.AppendData |
                FileSystemRights.ReadAttributes | FileSystemRights.WriteAttributes | FileSystemRights.ReadPermissions,
                FileShare.Read, BufferBytes, FileOptions.SequentialScan, security);
        }

        private static byte[] ReadBounded(FileStream stream)
        {
            if (stream.Length > OpenSshKnownHostsParser.MaximumFileBytes)
                throw new KnownHostsMutationException("file-size-limit");
            stream.Position = 0;
            using var output = new MemoryStream(stream.Length > 0 ? checked((int)stream.Length) : 0);
            var buffer = new byte[BufferBytes];
            while (true)
            {
                var read = stream.Read(buffer, 0, buffer.Length);
                if (read == 0) break;
                if (output.Length + read > OpenSshKnownHostsParser.MaximumFileBytes)
                    throw new KnownHostsMutationException("file-size-limit");
                output.Write(buffer, 0, read);
            }
            return output.ToArray();
        }

        private static byte[] BuildAddition(byte[] content, string hostToken, PresentedHostKey presented)
        {
            var newline = DominantNewline(content);
            var prefix = Array.Empty<byte>();
            if (content.Length > 0 && content[content.Length - 1] != (byte)'\n')
                prefix = content[content.Length - 1] == (byte)'\r' && newline.Length == 2
                    ? new[] { (byte)'\n' } : newline;
            var record = Utf8.GetBytes(hostToken + " " + presented.KeyType + " " +
                Convert.ToBase64String(presented.Blob));
            var result = new byte[prefix.Length + record.Length + newline.Length];
            Buffer.BlockCopy(prefix, 0, result, 0, prefix.Length);
            Buffer.BlockCopy(record, 0, result, prefix.Length, record.Length);
            Buffer.BlockCopy(newline, 0, result, prefix.Length + record.Length, newline.Length);
            return result;
        }

        private static byte[] DominantNewline(byte[] content)
        {
            var crlf = 0;
            var lf = 0;
            for (var index = 0; index < content.Length; ++index)
            {
                if (content[index] != (byte)'\n') continue;
                if (index > 0 && content[index - 1] == (byte)'\r') ++crlf;
                else ++lf;
            }
            return crlf > lf ? new[] { (byte)'\r', (byte)'\n' } : new[] { (byte)'\n' };
        }

        private static string HashCombined(byte[] content, byte[] addition)
        {
            var combined = new byte[checked(content.Length + addition.Length)];
            Buffer.BlockCopy(content, 0, combined, 0, content.Length);
            Buffer.BlockCopy(addition, 0, combined, content.Length, addition.Length);
            using var sha = SHA256.Create();
            return BitConverter.ToString(sha.ComputeHash(combined)).Replace("-", string.Empty);
        }

        private static bool SameSource(KnownHostsSourceSnapshot first, KnownHostsSourceSnapshot second) =>
            string.Equals(first.Definition.SourceId, second.Definition.SourceId, StringComparison.Ordinal) &&
            string.Equals(first.Definition.Path, second.Definition.Path, StringComparison.OrdinalIgnoreCase) &&
            first.Exists == second.Exists && first.Length == second.Length &&
            first.LastWriteUtc == second.LastWriteUtc &&
            string.Equals(first.ContentHash, second.ContentHash, StringComparison.Ordinal) &&
            string.Equals(first.Document?.FatalError, second.Document?.FatalError, StringComparison.Ordinal);

        private static bool PrimaryMatchesFresh(KnownHostsSourceSnapshot expected,
            KnownHostsSourceSnapshot current, bool existed)
        {
            // Opening a missing primary file creates an empty file while the
            // writer holds the lock. That creation is the expected transition;
            // every pre-existing file must still match the discovery snapshot.
            if (!expected.Exists) return !existed && current.Length == 0;
            if (!existed) return false;
            return expected.Length == current.Length &&
                string.Equals(expected.ContentHash, current.ContentHash, StringComparison.Ordinal);
        }

        private static void EnsureSafeDirectory(string path)
        {
            if (Directory.Exists(path))
            {
                if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
                    throw new KnownHostsMutationException("reparse-directory");
                return;
            }
            if (File.Exists(path)) throw new KnownHostsMutationException("directory-path-is-file");
            var parent = Path.GetDirectoryName(path);
            if (string.IsNullOrEmpty(parent) || !Directory.Exists(parent))
                throw new KnownHostsMutationException("profile-directory-missing");
            Directory.CreateDirectory(path, OwnerDirectorySecurity());
        }

        private static void EnsureSafeFileTarget(string path)
        {
            if (!File.Exists(path)) return;
            var attributes = File.GetAttributes(path);
            if ((attributes & (FileAttributes.Directory | FileAttributes.ReparsePoint | FileAttributes.ReadOnly)) != 0)
                throw new KnownHostsMutationException("unsafe-primary-file");
        }

        private static DirectorySecurity OwnerDirectorySecurity()
        {
            var owner = CurrentOwner();
            var security = new DirectorySecurity();
            security.SetAccessRuleProtection(true, false);
            security.SetOwner(owner);
            security.AddAccessRule(new FileSystemAccessRule(owner, FileSystemRights.FullControl,
                InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                PropagationFlags.None, AccessControlType.Allow));
            return security;
        }

        private static FileSecurity OwnerFileSecurity()
        {
            var owner = CurrentOwner();
            var security = new FileSecurity();
            security.SetAccessRuleProtection(true, false);
            security.SetOwner(owner);
            security.AddAccessRule(new FileSystemAccessRule(owner, FileSystemRights.FullControl,
                AccessControlType.Allow));
            return security;
        }

        private static SecurityIdentifier CurrentOwner() =>
            WindowsIdentity.GetCurrent().User ?? throw new KnownHostsMutationException("current-user-identity");

        private static string MutexName(string path)
        {
            byte[] digest;
            using (var sha = SHA256.Create())
                digest = sha.ComputeHash(Encoding.UTF8.GetBytes(Path.GetFullPath(path).ToUpperInvariant()));
            return "Local\\VT7-KnownHosts-" + BitConverter.ToString(digest).Replace("-", string.Empty);
        }

        private static bool IsMutationFailure(Exception error) =>
            error is IOException || error is UnauthorizedAccessException || error is SecurityException ||
            error is NotSupportedException || error is CryptographicException;
    }
}
