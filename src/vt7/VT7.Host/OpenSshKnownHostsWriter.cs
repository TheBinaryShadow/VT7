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

        internal static KnownHostsStoreSnapshot RemovePrimaryUserRecords(
            KnownHostsStoreSnapshot reviewedSnapshot, string hostToken, IReadOnlyList<int> selectedLines)
        {
            if (reviewedSnapshot == null) throw new ArgumentNullException(nameof(reviewedSnapshot));
            if (hostToken == null) throw new ArgumentNullException(nameof(hostToken));
            if (selectedLines == null) throw new ArgumentNullException(nameof(selectedLines));
            if (reviewedSnapshot.Sources.Count != 4 ||
                !string.Equals(reviewedSnapshot.Sources[0].Definition.SourceId, "user-known-hosts", StringComparison.Ordinal))
                throw new KnownHostsMutationException("source-layout");
            if (selectedLines.Count == 0 || selectedLines.Count > OpenSshKnownHostsParser.MaximumRecords ||
                selectedLines.Any(number => number <= 0) || selectedLines.Distinct().Count() != selectedLines.Count)
                throw new KnownHostsMutationException("removal-selection");

            var definitions = reviewedSnapshot.Sources.Select(source => source.Definition).ToArray();
            var primary = definitions[0];
            var selected = new HashSet<int>(selectedLines);
            var reviewed = reviewedSnapshot.Sources[0].Document;
            if (!reviewedSnapshot.Sources[0].Exists || reviewed?.FatalError != null || reviewed == null)
                throw new KnownHostsMutationException("primary-unavailable");
            ValidateRemovalSelection(reviewed, hostToken, selected);

            using (var mutex = new Mutex(false, MutexName(primary.Path)))
            {
                var acquired = false;
                try
                {
                    try { acquired = mutex.WaitOne(MutexTimeout); }
                    catch (AbandonedMutexException) { acquired = true; }
                    if (!acquired) throw new KnownHostsMutationException("writer-lock-timeout");

                    var fresh = OpenSshKnownHostsStore.Load(definitions);
                    if (!string.Equals(fresh.Identity, reviewedSnapshot.Identity, StringComparison.Ordinal))
                        throw new KnownHostsMutationException("store-generation-changed");
                    var directory = Path.GetDirectoryName(primary.Path);
                    if (string.IsNullOrEmpty(directory) || !Directory.Exists(directory))
                        throw new KnownHostsMutationException("primary-path");
                    EnsureSafeDirectory(directory!);
                    EnsureSafeFileTarget(primary.Path);
                    if (!File.Exists(primary.Path)) throw new KnownHostsMutationException("primary-unavailable");
                    var backup = primary.Path + ".old";
                    EnsureSafeBackupTarget(backup);

                    byte[] original;
                    FileSecurity security;
                    using (var source = new FileStream(primary.Path, FileMode.Open, FileAccess.Read,
                        FileShare.Read | FileShare.Delete, BufferBytes, FileOptions.SequentialScan))
                    {
                        original = ReadBounded(source);
                        security = File.GetAccessControl(primary.Path);
                        var current = OpenSshKnownHostsStore.CreateSourceSnapshot(primary, original,
                            File.GetLastWriteTimeUtc(primary.Path));
                        if (!PrimaryMatchesFresh(fresh.Sources[0], current, true))
                            throw new KnownHostsMutationException("primary-generation-changed");
                    var document = OpenSshKnownHostsParser.Parse(primary.SourceId, original);
                    if (document.FatalError != null) throw new KnownHostsMutationException("primary-unreadable");
                    ValidateRemovalSelection(document, hostToken, selected);
                    var retained = document.Lines.Where(line => !selected.Contains(line.LineNumber))
                        .SelectMany(line => line.RawBytes).ToArray();
                    var originalHash = HashBytes(original);
                    var expectedHash = HashBytes(retained);
                    var expectedSecurity = security.GetSecurityDescriptorSddlForm(
                        AccessControlSections.Owner | AccessControlSections.Group | AccessControlSections.Access);
                    var temporary = Path.Combine(directory!, "known_hosts.vt7-" + Guid.NewGuid().ToString("N") + ".tmp");
                    var replaced = false;
                    try
                    {
                        using (var target = new FileStream(temporary, FileMode.CreateNew,
                            FileSystemRights.ReadData | FileSystemRights.WriteData | FileSystemRights.AppendData |
                            FileSystemRights.ReadAttributes | FileSystemRights.WriteAttributes |
                            FileSystemRights.ReadPermissions | FileSystemRights.ChangePermissions,
                            FileShare.None, BufferBytes, FileOptions.SequentialScan, security))
                        {
                            target.Write(retained, 0, retained.Length);
                            target.Flush(true);
                        }
                        // File.SetAccessControl does not persist an unmodified
                        // FileSecurity returned by GetAccessControl. Copy the
                        // reviewed descriptor into a fresh, modified object and
                        // verify it before replacing any trusted file. Windows 7
                        // does not always leave the replacement with the same
                        // owner/group/DACL if this step is skipped.
                        var replacementSecurity = new FileSecurity();
                        replacementSecurity.SetSecurityDescriptorSddlForm(expectedSecurity,
                            AccessControlSections.Owner | AccessControlSections.Group | AccessControlSections.Access);
                        File.SetAccessControl(temporary, replacementSecurity);
                        var temporaryMismatch = SecurityMismatch(security, File.GetAccessControl(temporary));
                        if (temporaryMismatch != null)
                            throw new KnownHostsMutationException("temporary-security-" + temporaryMismatch);

                        // The final source check catches edits while the retained file is being
                        // built. File.Replace commits the new file and the .old backup together.
                        var finalSource = OpenSshKnownHostsStore.Load(definitions);
                        if (!string.Equals(finalSource.Identity, reviewedSnapshot.Identity, StringComparison.Ordinal) ||
                            !string.Equals(finalSource.Sources[0].ContentHash, originalHash, StringComparison.Ordinal))
                            throw new KnownHostsMutationException("store-generation-changed");
                        EnsureSafeBackupTarget(backup);
                        File.Replace(temporary, primary.Path, backup, false);
                        replaced = true;
                    }
                    finally
                    {
                        if (!replaced && File.Exists(temporary))
                        {
                            // A created temporary file is never a trust source. Leave it for
                            // inspection if another process changed it before cleanup.
                            try
                            {
                                if (string.Equals(HashFile(temporary), expectedHash, StringComparison.Ordinal))
                                    File.Delete(temporary);
                            }
                            catch (IOException) { }
                            catch (UnauthorizedAccessException) { }
                        }
                    }

                    var verified = OpenSshKnownHostsStore.Load(definitions);
                    if (!verified.Sources[0].Exists || verified.Sources[0].Length != retained.LongLength ||
                        !string.Equals(verified.Sources[0].ContentHash, expectedHash, StringComparison.Ordinal) ||
                        verified.Sources.Skip(1).Zip(fresh.Sources.Skip(1), SameSource).Any(same => !same) ||
                        !string.Equals(HashFile(backup), originalHash, StringComparison.Ordinal))
                        throw new KnownHostsMutationException("read-back-generation");
                    var readBackMismatch = SecurityMismatch(security, File.GetAccessControl(primary.Path));
                    if (readBackMismatch != null)
                        throw new KnownHostsMutationException("read-back-security-" + readBackMismatch);
                    return verified;
                    }
                }
                catch (KnownHostsMutationException) { throw; }
                catch (Exception error) when (IsMutationFailure(error))
                {
                    throw new KnownHostsMutationException("filesystem", error);
                }
                finally { if (acquired) mutex.ReleaseMutex(); }
            }
        }

        private static void ValidateRemovalSelection(KnownHostsDocument document, string hostToken,
            HashSet<int> selected)
        {
            var found = 0;
            foreach (var line in document.Lines)
            {
                if (!selected.Contains(line.LineNumber)) continue;
                var record = line.Record;
                if (line.Kind != KnownHostsLineKind.Record || record == null ||
                    record.Marker != KnownHostMarker.None || !OpenSshHostMatcher.Matches(hostToken, record.HostField))
                    throw new KnownHostsMutationException("removal-selection");
                ++found;
            }
            if (found != selected.Count) throw new KnownHostsMutationException("removal-selection");
        }

        private static string? SecurityMismatch(FileSecurity expected, FileSecurity actual)
        {
            // The auto-inheritance control bits can differ when Windows writes
            // a copied descriptor, even if owner, group and every DACL entry
            // are identical. Compare the security properties we must preserve
            // instead of the complete SDDL serialization of those properties.
            var original = new RawSecurityDescriptor(expected.GetSecurityDescriptorBinaryForm(), 0);
            var replacement = new RawSecurityDescriptor(actual.GetSecurityDescriptorBinaryForm(), 0);
            if (!Equals(original.Owner, replacement.Owner)) return "owner";
            if (!Equals(original.Group, replacement.Group)) return "group";
            const ControlFlags relevant = ControlFlags.DiscretionaryAclPresent |
                ControlFlags.DiscretionaryAclProtected;
            if ((original.ControlFlags & relevant) != (replacement.ControlFlags & relevant))
                return "access-flags";
            var originalAcl = original.DiscretionaryAcl;
            var replacementAcl = replacement.DiscretionaryAcl;
            if (originalAcl == null || replacementAcl == null)
                return originalAcl == replacementAcl ? null : "access-entries";
            if (originalAcl.Count != replacementAcl.Count) return "access-entries";
            for (var index = 0; index < originalAcl.Count; ++index)
            {
                var left = new byte[originalAcl[index].BinaryLength];
                var right = new byte[replacementAcl[index].BinaryLength];
                originalAcl[index].GetBinaryForm(left, 0);
                replacementAcl[index].GetBinaryForm(right, 0);
                if (!left.SequenceEqual(right)) return "access-entries";
            }
            return null;
        }

        private static void EnsureSafeBackupTarget(string path)
        {
            FileAttributes attributes;
            try { attributes = File.GetAttributes(path); }
            catch (FileNotFoundException) { return; }
            catch (DirectoryNotFoundException) { return; }
            if ((attributes & (FileAttributes.Directory | FileAttributes.ReparsePoint | FileAttributes.ReadOnly)) != 0)
                throw new KnownHostsMutationException("unsafe-backup-file");
        }

        private static string HashFile(string path)
        {
            using var input = new FileStream(path, FileMode.Open, FileAccess.Read,
                FileShare.Read, BufferBytes, FileOptions.SequentialScan);
            using var sha = SHA256.Create();
            return BitConverter.ToString(sha.ComputeHash(input)).Replace("-", string.Empty);
        }

        private static string HashBytes(byte[] bytes)
        {
            using var sha = SHA256.Create();
            return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-", string.Empty);
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
