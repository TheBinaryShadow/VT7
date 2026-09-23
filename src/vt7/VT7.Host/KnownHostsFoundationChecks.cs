using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal static class KnownHostsFoundationChecks
    {
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false);

        internal static Task Run(StringBuilder report)
        {
            var firstBlob = Ed25519Blob(1);
            var secondBlob = Ed25519Blob(65);
            var rsaBlob = RsaBlob();
            var certificateBlob = Blob("ssh-ed25519-cert-v01@openssh.com", 97, 64);
            var first = PresentedHostKey.Parse(firstBlob);
            var second = PresentedHostKey.Parse(secondBlob);

            CheckHostTokens();
            report.AppendLine("PASS: OpenSSH host tokens preserve default-port identity and bracket every non-default port.");

            CheckKeyIdentity(firstBlob, first, rsaBlob);
            report.AppendLine("PASS: presented host keys use the exact RFC 4253 blob type, RSA key identity and canonical SHA256 fingerprint.");

            CheckParser(firstBlob);
            report.AppendLine("PASS: bounded known-host parsing accepts comments, markers, patterns, hashes and byte-preserved lines.");

            CheckMatchers(firstBlob);
            report.AppendLine("PASS: literal, wildcard, negated and OpenSSH |1| hashed host matching passed.");

            CheckTrustStates(first, second, certificateBlob);
            report.AppendLine("PASS: raw-key trust resolves matching, unknown, changed, revoked, unreadable and certificate-policy states.");

            CheckStoreLoadingAndPolicy(first, second);
            report.AppendLine("PASS: four-source OpenSSH loading is immutable, bounded and fail-closed for missing, changed, revoked and unreadable stores.");
            report.AppendLine("PASS: stored matches need no fingerprint, unknown hosts require a generation-bound prompt pin and explicit fingerprint mismatches remain blocked.");

            CheckDurableAddition(first, second);
            report.AppendLine("PASS: durable first-contact writes preserve existing bytes, reject stale decisions, serialize writers and verify read-back.");

            CheckPropertiesAndFuzz();
            report.AppendLine("PASS: deterministic hash properties and 1024 bounded arbitrary-byte parser cases passed.");

            var oracle = CheckOpenSshOracle(firstBlob);
            report.AppendLine("PASS: ssh-keygen differential lookup, host hashing and removal passed (" + oracle + ").");
            return Task.CompletedTask;
        }

        private static void CheckHostTokens()
        {
            Require(OpenSshHostToken.Create("Example.COM", 22) == "example.com", "Default-port hostname token changed.");
            Require(OpenSshHostToken.Create("Example.COM", 2222) == "[example.com]:2222", "Non-default hostname token changed.");
            Require(OpenSshHostToken.Create("[2001:DB8::1]", 22) == "2001:db8::1", "Default-port IPv6 token changed.");
            Require(OpenSshHostToken.Create("2001:DB8::1", 2222) == "[2001:db8::1]:2222", "Non-default IPv6 token changed.");
            ExpectFormat(() => OpenSshHostToken.Create(" example.com", 22));
            ExpectFormat(() => OpenSshHostToken.Create("exämple.com", 22));
        }

        private static void CheckKeyIdentity(byte[] blob, PresentedHostKey key, byte[] rsaBlob)
        {
            Require(key.KeyType == "ssh-ed25519", "The key blob type was not decoded.");
            Require(key.Fingerprint.StartsWith("SHA256:", StringComparison.Ordinal) && key.Fingerprint.Length == 50,
                "The SHA256 fingerprint is not canonical OpenSSH text.");
            var copy = (byte[])blob.Clone();
            copy[copy.Length - 1] ^= 0xff;
            Require(PresentedHostKey.Parse(copy).Fingerprint != key.Fingerprint, "Different key blobs produced the same test fingerprint.");
            var rsa = PresentedHostKey.Parse(rsaBlob);
            Require(rsa.KeyType == "ssh-rsa", "An RSA blob did not retain its stored public-key type.");
            var rsaDocument = Document("rsa", "rsa.example ssh-rsa " + Convert.ToBase64String(rsaBlob));
            Require(KnownHostTrustResolver.Resolve("rsa.example", rsa, new[] { rsaDocument }).State == KnownHostTrustState.Matching,
                "The exact RSA key blob did not match independently of negotiated rsa-sha2 signature names.");
            Require(ParseLine("rsa.example rsa-sha2-512 " + Convert.ToBase64String(rsaBlob)).Lines.Single().Kind == KnownHostsLineKind.Malformed,
                "A negotiated RSA signature name was accepted as the stored blob type.");
            ExpectFormat(() => PresentedHostKey.Parse(new byte[] { 0, 0, 1, 0, (byte)'x' }));
        }

        private static void CheckParser(byte[] keyBlob)
        {
            var encoded = Convert.ToBase64String(keyBlob);
            var salt = Enumerable.Range(1, 20).Select(value => (byte)value).ToArray();
            var hashed = OpenSshHostMatcher.Hash("hash.example", salt);
            var text = "# retained comment\r\n" +
                "example.com,*.example.net,!blocked.example.net ssh-ed25519 " + encoded + " retained comment\n" +
                "@revoked revoked.example ssh-ed25519 " + encoded + "\r\n" +
                "@cert-authority ca.example ssh-ed25519 " + encoded + "\n" +
                hashed + " ssh-ed25519 " + encoded;
            var bytes = Utf8.GetBytes(text);
            var document = OpenSshKnownHostsParser.Parse("fixture", bytes);
            Require(document.FatalError == null && document.Lines.Count == 5, "The parser did not retain every physical line.");
            Require(document.Lines[0].Kind == KnownHostsLineKind.Comment, "A comment became a key record.");
            Require(document.Lines[1].Record?.Marker == KnownHostMarker.None, "The ordinary marker changed.");
            Require(document.Lines[2].Record?.Marker == KnownHostMarker.Revoked, "The revoked marker changed.");
            Require(document.Lines[3].Record?.Marker == KnownHostMarker.CertAuthority, "The CA marker changed.");
            Require(document.Lines[4].Record?.HostField == hashed, "The hashed host field changed.");
            Require(bytes.SequenceEqual(document.Lines.SelectMany(line => line.RawBytes)), "Raw line bytes were not preserved.");

            var mismatch = ParseLine("example.com ssh-rsa " + encoded);
            Require(mismatch.Lines.Single().Kind == KnownHostsLineKind.Malformed &&
                mismatch.Lines.Single().ErrorCode == "key-type-mismatch", "Text/blob key-type mismatch was accepted.");
            var badHash = ParseLine("|1|bad|hash ssh-ed25519 " + encoded);
            Require(badHash.Lines.Single().IndeterminateHost, "A malformed hash did not retain indeterminate-host state.");
            var unknownMarker = ParseLine("@unknown example.com ssh-ed25519 " + encoded);
            Require(unknownMarker.Lines.Single().CandidateHostField == "example.com", "Unknown-marker host relevance was lost.");

            var oversized = new byte[OpenSshKnownHostsParser.MaximumFileBytes + 1];
            Require(OpenSshKnownHostsParser.Parse("oversized", oversized).FatalError == "file-size-limit",
                "The file-size bound was not enforced.");
        }

        private static void CheckMatchers(byte[] keyBlob)
        {
            Require(OpenSshHostMatcher.Matches("example.com", "EXAMPLE.COM"), "Literal host matching became case-sensitive.");
            Require(OpenSshHostMatcher.Matches("node.example.com", "*.example.com"), "Wildcard host matching failed.");
            Require(OpenSshHostMatcher.Matches("node.example.com", "*.example.com,!blocked.example.com"), "Positive pattern matching failed.");
            Require(!OpenSshHostMatcher.Matches("blocked.example.com", "*.example.com,!blocked.example.com"), "Negation did not override a positive pattern.");
            Require(!OpenSshHostMatcher.Matches("example.net", "*.example.com"), "An unrelated wildcard matched.");
            var salt = Enumerable.Range(0, 20).Select(value => (byte)(0xa0 + value)).ToArray();
            var hashed = OpenSshHostMatcher.Hash("[hash.example]:2222", salt);
            Require(OpenSshHostMatcher.Matches("[hash.example]:2222", hashed), "The correct OpenSSH hash did not match.");
            Require(!OpenSshHostMatcher.Matches("hash.example", hashed), "A different OpenSSH host token matched the hash.");
            ExpectFormat(() => OpenSshHostMatcher.Matches("hash.example", "|2|invalid|invalid"));
            _ = keyBlob;
        }

        private static void CheckTrustStates(PresentedHostKey first, PresentedHostKey second, byte[] certificateBlob)
        {
            var matching = Document("matching", "example.test ssh-ed25519 " + Convert.ToBase64String(first.Blob));
            var changed = Document("changed", "example.test ssh-ed25519 " + Convert.ToBase64String(second.Blob));
            var revoked = Document("revoked", "@revoked example.test ssh-ed25519 " + Convert.ToBase64String(first.Blob));
            var unrelatedMalformed = Document("unrelated", "other.test not-a-valid-key");
            var relevantMalformed = Document("relevant", "example.test not-a-valid-key");
            var indeterminate = Document("indeterminate", "|1|bad|hash ssh-ed25519 " + Convert.ToBase64String(first.Blob));
            var undecodable = OpenSshKnownHostsParser.Parse("undecodable", new byte[] { 0xff, (byte)'x', (byte)'\n' });

            Require(Resolve(first, matching).State == KnownHostTrustState.Matching, "An exact key did not match.");
            Require(Resolve(first).State == KnownHostTrustState.Unknown, "An empty store was not unknown.");
            Require(Resolve(first, changed).State == KnownHostTrustState.Changed, "A different stored key was not changed.");
            Require(Resolve(first, matching, revoked).State == KnownHostTrustState.Revoked, "Revocation did not override a match.");
            Require(Resolve(first, matching, relevantMalformed).State == KnownHostTrustState.Unreadable,
                "Relevant malformed data did not override a match.");
            Require(Resolve(first, matching, indeterminate).State == KnownHostTrustState.Unreadable,
                "An indeterminate malformed hash did not fail closed.");
            Require(Resolve(first, matching, undecodable).State == KnownHostTrustState.Unreadable,
                "A line whose host relevance cannot be decoded did not fail closed.");
            Require(Resolve(first, matching, unrelatedMalformed).State == KnownHostTrustState.Matching,
                "An unrelated malformed record blocked a valid match.");
            Require(Resolve(PresentedHostKey.Parse(certificateBlob)).State == KnownHostTrustState.PolicyRejected,
                "A certificate was allowed before KH01.4 validation exists.");
        }

        private static void CheckPropertiesAndFuzz()
        {
            var random = new Random(0x4b483031);
            for (var iteration = 0; iteration < 256; ++iteration)
            {
                var token = "node-" + iteration.ToString(System.Globalization.CultureInfo.InvariantCulture) + ".example";
                var salt = new byte[20];
                random.NextBytes(salt);
                var hash = OpenSshHostMatcher.Hash(token, salt);
                Require(OpenSshHostMatcher.Matches(token, hash), "A generated host hash did not match its token.");
                Require(!OpenSshHostMatcher.Matches(token + "-other", hash), "A generated host hash matched a different token.");
            }
            for (var iteration = 0; iteration < 1024; ++iteration)
            {
                var bytes = new byte[random.Next(0, 513)];
                random.NextBytes(bytes);
                var document = OpenSshKnownHostsParser.Parse("fuzz", bytes);
                Require(document.Lines.Count <= bytes.Length + 1, "Arbitrary input produced an impossible line count.");
            }
        }

        private static void CheckStoreLoadingAndPolicy(PresentedHostKey first, PresentedHostKey second)
        {
            var root = Path.Combine(Path.GetTempPath(), "VT7 known hosts read only " + Guid.NewGuid().ToString("N"));
            var user = Path.Combine(root, "user");
            var programData = Path.Combine(root, "program data");
            var definitions = OpenSshKnownHostsStore.CreateDefaultDefinitions(user, programData);
            try
            {
                Require(definitions.Count == 4 &&
                    definitions.Select(item => item.SourceId).SequenceEqual(new[]
                    {
                        "user-known-hosts", "user-known-hosts2", "system-known-hosts", "system-known-hosts2"
                    }), "The default known-host source order changed.");
                Require(definitions.All(item => Path.IsPathRooted(item.Path)),
                    "A default known-host source was not resolved to an absolute path.");

                Directory.CreateDirectory(Path.GetDirectoryName(definitions[0].Path));
                Directory.CreateDirectory(Path.GetDirectoryName(definitions[2].Path));
                File.WriteAllText(definitions[0].Path,
                    "primary.example ssh-ed25519 " + Convert.ToBase64String(first.Blob) + "\n" +
                    "changed.example ssh-ed25519 " + Convert.ToBase64String(second.Blob) + "\n" +
                    "@revoked revoked.example ssh-ed25519 " + Convert.ToBase64String(first.Blob) + "\n", Utf8);
                File.WriteAllText(definitions[1].Path,
                    "secondary.example ssh-ed25519 " + Convert.ToBase64String(first.Blob) + "\n", Utf8);
                File.WriteAllText(definitions[2].Path,
                    "system.example ssh-ed25519 " + Convert.ToBase64String(first.Blob) + "\n", Utf8);
                File.WriteAllText(definitions[3].Path,
                    "[system-port.example]:2222 ssh-ed25519 " + Convert.ToBase64String(first.Blob) + "\n", Utf8);

                var snapshot = OpenSshKnownHostsStore.Load(definitions);
                Require(snapshot.Sources.Count == 4 && snapshot.Sources.All(source => source.Exists &&
                    source.Document != null && source.Document.FatalError == null && source.ContentHash.Length == 64),
                    "The four default known-host sources were not loaded into a stable snapshot.");
                foreach (var token in new[] { "primary.example", "secondary.example", "system.example", "[system-port.example]:2222" })
                    Require(KnownHostTrustPolicy.Decide(token, first, snapshot, string.Empty).CanTrust,
                        "A matching default known-host source did not authorize the presented key.");

                var normalizedFirst = SshConnectionOptions.NormalizeFingerprint(first.Fingerprint);
                var normalizedSecond = SshConnectionOptions.NormalizeFingerprint(second.Fingerprint);
                var unknown = KnownHostTrustPolicy.Decide("unknown.example", first, snapshot, string.Empty);
                Require(unknown.Result.State == KnownHostTrustState.Unknown && !unknown.CanTrust,
                    "An unknown host was accepted without a fingerprint.");
                var pinned = KnownHostTrustPolicy.Decide("unknown.example", first, snapshot, normalizedFirst);
                Require(pinned.Result.State == KnownHostTrustState.Unknown && pinned.FingerprintMatched && !pinned.CanTrust,
                    "An exact unknown-host fingerprint bypassed the first-contact decision.");
                var connectionPin = new KnownHostConnectionPin("unknown.example", first, snapshot.Identity);
                var prompted = KnownHostTrustPolicy.Decide("unknown.example", first, snapshot,
                    normalizedFirst, connectionPin);
                Require(prompted.CanTrust && prompted.Authorization == "one-connection-prompt-pin",
                    "A generation-bound prompt pin did not authorize its fresh retry.");
                Require(!KnownHostTrustPolicy.Decide("other.example", first, snapshot,
                    normalizedFirst, connectionPin).CanTrust,
                    "A one-connection prompt pin authorized a different host token.");
                Require(!KnownHostTrustPolicy.Decide("unknown.example", second, snapshot,
                    normalizedSecond, connectionPin).CanTrust,
                    "A one-connection prompt pin authorized a different key blob.");
                Require(!KnownHostTrustPolicy.Decide("unknown.example", first, snapshot, normalizedSecond).CanTrust,
                    "A wrong unknown-host fingerprint was accepted.");
                Require(!KnownHostTrustPolicy.Decide("primary.example", first, snapshot, normalizedSecond).CanTrust,
                    "A supplied fingerprint mismatch was hidden by a stored match.");

                var changed = KnownHostTrustPolicy.Decide("changed.example", first, snapshot, normalizedFirst);
                Require(changed.Result.State == KnownHostTrustState.Changed && !changed.CanTrust,
                    "An explicit fingerprint overrode a changed stored key.");
                var revoked = KnownHostTrustPolicy.Decide("revoked.example", first, snapshot, normalizedFirst);
                Require(revoked.Result.State == KnownHostTrustState.Revoked && !revoked.CanTrust,
                    "An explicit fingerprint overrode a revoked stored key.");

                File.WriteAllText(definitions[0].Path,
                    "primary.example ssh-ed25519 " + Convert.ToBase64String(second.Blob) + "\n", Utf8);
                Require(KnownHostTrustPolicy.Decide("primary.example", first, snapshot, string.Empty).CanTrust,
                    "A connection snapshot changed after its source file was replaced.");

                var missingDefinitions = OpenSshKnownHostsStore.CreateDefaultDefinitions(
                    Path.Combine(root, "missing-user"), Path.Combine(root, "missing-program-data"));
                var missing = OpenSshKnownHostsStore.Load(missingDefinitions);
                Require(missing.Sources.All(source => !source.Exists && source.Document == null) &&
                    KnownHostTrustPolicy.Decide("missing.example", first, missing, string.Empty).Result.State == KnownHostTrustState.Unknown,
                    "A missing optional known-host file became an unreadable store.");

                var blockedPath = Path.Combine(root, "not-a-file");
                Directory.CreateDirectory(blockedPath);
                var blocked = OpenSshKnownHostsStore.Load(new[]
                {
                    new KnownHostsSourceDefinition("blocked-source", blockedPath)
                });
                var unreadable = KnownHostTrustPolicy.Decide("blocked.example", first, blocked, normalizedFirst);
                Require(unreadable.Result.State == KnownHostTrustState.Unreadable && !unreadable.CanTrust,
                    "An unreadable source did not block an otherwise matching fingerprint.");
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        private static void CheckDurableAddition(PresentedHostKey first, PresentedHostKey second)
        {
            var root = Path.Combine(Path.GetTempPath(), "VT7 known hosts writer " + Guid.NewGuid().ToString("N"));
            var user = Path.Combine(root, "user");
            var programData = Path.Combine(root, "program data");
            Directory.CreateDirectory(user);
            Directory.CreateDirectory(programData);
            var definitions = OpenSshKnownHostsStore.CreateDefaultDefinitions(user, programData);
            var primary = definitions[0].Path;
            try
            {
                var missing = OpenSshKnownHostsStore.Load(definitions);
                var verified = OpenSshKnownHostsWriter.AddPrimaryUserRecord(missing, "new.example", first);
                Require(KnownHostTrustResolver.Resolve("new.example", first, verified.Documents).State ==
                    KnownHostTrustState.Matching, "A new primary known_hosts file did not verify after append.");
                var expectedNew = "new.example ssh-ed25519 " + Convert.ToBase64String(first.Blob) + "\n";
                Require(File.ReadAllText(primary, Utf8) == expectedNew,
                    "A new primary known_hosts file did not contain exactly one canonical record.");
                RequireOwnerOnly(Path.GetDirectoryName(primary)!, directory: true);
                RequireOwnerOnly(primary, directory: false);

                var preserved = "# retained CRLF\r\n# retained tail";
                File.WriteAllText(primary, preserved, Utf8);
                var originalSecurity = File.GetAccessControl(primary).GetSecurityDescriptorSddlForm(
                    AccessControlSections.Access | AccessControlSections.Owner);
                var preservationSnapshot = OpenSshKnownHostsStore.Load(definitions);
                OpenSshKnownHostsWriter.AddPrimaryUserRecord(preservationSnapshot, "preserved.example", first);
                var expectedPreserved = preserved + "\r\npreserved.example ssh-ed25519 " +
                    Convert.ToBase64String(first.Blob) + "\r\n";
                Require(File.ReadAllText(primary, Utf8) == expectedPreserved,
                    "The writer changed existing bytes or failed to preserve the dominant newline.");
                Require(File.GetAccessControl(primary).GetSecurityDescriptorSddlForm(
                    AccessControlSections.Access | AccessControlSections.Owner) == originalSecurity,
                    "Appending to an existing known_hosts file changed its owner or ACL.");

                var staleSnapshot = OpenSshKnownHostsStore.Load(definitions);
                File.AppendAllText(primary, "# external change\r\n", Utf8);
                var staleBytes = File.ReadAllBytes(primary);
                ExpectMutation("store-generation-changed", () =>
                    OpenSshKnownHostsWriter.AddPrimaryUserRecord(staleSnapshot, "stale.example", first));
                Require(staleBytes.SequenceEqual(File.ReadAllBytes(primary)),
                    "A stale decision changed the known-host file.");

                File.WriteAllText(primary, "changed.example ssh-ed25519 " +
                    Convert.ToBase64String(second.Blob) + "\n", Utf8);
                var changedSnapshot = OpenSshKnownHostsStore.Load(definitions);
                var changedBytes = File.ReadAllBytes(primary);
                ExpectMutation("trust-state-changed-changed", () =>
                    OpenSshKnownHostsWriter.AddPrimaryUserRecord(changedSnapshot, "changed.example", first));
                Require(changedBytes.SequenceEqual(File.ReadAllBytes(primary)),
                    "A changed stored key was modified by first-contact trust.");

                File.WriteAllText(primary, "# concurrency fixture\n", Utf8);
                var concurrentSnapshot = OpenSshKnownHostsStore.Load(definitions);
                var outcomes = new string[2];
                Parallel.Invoke(
                    () => outcomes[0] = AddConcurrent(concurrentSnapshot, "race-one.example", first),
                    () => outcomes[1] = AddConcurrent(concurrentSnapshot, "race-two.example", first));
                Require(outcomes.Count(value => value == "success") == 1 &&
                    outcomes.Count(value => value == "store-generation-changed") == 1,
                    "Concurrent first-contact writers did not serialize with one stale loser.");
                var final = OpenSshKnownHostsStore.Load(definitions);
                var raceMatches = new[] { "race-one.example", "race-two.example" }.Count(token =>
                    KnownHostTrustResolver.Resolve(token, first, final.Documents).State == KnownHostTrustState.Matching);
                Require(raceMatches == 1, "Concurrent writers committed more than one captured generation.");
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        private static string AddConcurrent(KnownHostsStoreSnapshot snapshot, string token, PresentedHostKey key)
        {
            try
            {
                OpenSshKnownHostsWriter.AddPrimaryUserRecord(snapshot, token, key);
                return "success";
            }
            catch (KnownHostsMutationException error)
            {
                return error.Category;
            }
        }

        private static void RequireOwnerOnly(string path, bool directory)
        {
            FileSystemSecurity security = directory
                ? (FileSystemSecurity)Directory.GetAccessControl(path)
                : File.GetAccessControl(path);
            var owner = (SecurityIdentifier)security.GetOwner(typeof(SecurityIdentifier));
            var current = WindowsIdentity.GetCurrent().User ??
                throw new InvalidOperationException("The current Windows user SID is unavailable.");
            Require(owner.Equals(current) && security.AreAccessRulesProtected,
                "A newly created known-host path was not protected and owned by the current user.");
            var rules = security.GetAccessRules(true, true, typeof(SecurityIdentifier))
                .Cast<FileSystemAccessRule>().Where(rule => rule.AccessControlType == AccessControlType.Allow).ToArray();
            Require(rules.Length != 0 && rules.All(rule =>
                ((SecurityIdentifier)rule.IdentityReference).Equals(current)),
                "A newly created known-host path grants access beyond the current user.");
        }

        private static void ExpectMutation(string category, Action action)
        {
            try { action(); }
            catch (KnownHostsMutationException error)
            {
                Require(error.Category == category, "Expected mutation category " + category +
                    ", received " + error.Category + ".");
                return;
            }
            throw new InvalidOperationException("Expected known-host mutation failure: " + category + ".");
        }

        private static string CheckOpenSshOracle(byte[] keyBlob)
        {
            var executable = FindSshKeygen();
            if (executable == null) throw new InvalidOperationException("ssh-keygen.exe was not found for the KH01.1 differential oracle.");
            var root = Path.Combine(Path.GetTempPath(), "VT7 known hosts KH01 " + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            try
            {
                var encoded = Convert.ToBase64String(keyBlob);
                var plainPath = Path.Combine(root, "plain known_hosts");
                File.WriteAllText(plainPath,
                    "oracle.example ssh-ed25519 " + encoded + " fixture\n" +
                    "[oracle.example]:2222 ssh-ed25519 " + encoded + " fixture\n" +
                    "*.wild.example,!blocked.wild.example ssh-ed25519 " + encoded + " fixture\n", Utf8);

                Require(Run(executable, "-F", "oracle.example", "-f", plainPath).ExitCode == 0,
                    "ssh-keygen did not find a literal host.");
                Require(Run(executable, "-F", "[oracle.example]:2222", "-f", plainPath).ExitCode == 0,
                    "ssh-keygen did not find a non-default-port host.");
                Require(Run(executable, "-F", "node.wild.example", "-f", plainPath).ExitCode == 0,
                    "ssh-keygen did not find a wildcard host.");
                Require(Run(executable, "-F", "blocked.wild.example", "-f", plainPath).ExitCode != 0,
                    "ssh-keygen ignored a negated wildcard host.");
                var plain = OpenSshKnownHostsParser.Parse("plain", File.ReadAllBytes(plainPath));
                Require(plain.Lines.Any(line => line.Record != null &&
                    OpenSshHostMatcher.Matches("oracle.example", line.Record.HostField)),
                    "VT7 did not find the OpenSSH literal fixture.");

                var hashPath = Path.Combine(root, "hashed known_hosts");
                File.WriteAllText(hashPath, "hash-oracle.example ssh-ed25519 " + encoded + " fixture\n", Utf8);
                var hashRun = Run(executable, "-q", "-H", "-f", hashPath);
                Require(hashRun.ExitCode == 0, "ssh-keygen -H failed: " + hashRun.Error);
                var hashed = OpenSshKnownHostsParser.Parse("hashed", File.ReadAllBytes(hashPath));
                var hashedRecord = hashed.Lines.Single(line => line.Record != null).Record!;
                Require(hashedRecord.HostField.StartsWith("|1|", StringComparison.Ordinal) &&
                    OpenSshHostMatcher.Matches("hash-oracle.example", hashedRecord.HostField),
                    "VT7 did not match the OpenSSH-generated host hash.");
                Require(Run(executable, "-F", "hash-oracle.example", "-f", hashPath).ExitCode == 0,
                    "ssh-keygen did not find its hashed host.");

                var removePath = Path.Combine(root, "remove known_hosts");
                File.Copy(plainPath, removePath);
                var removeRun = Run(executable, "-q", "-R", "oracle.example", "-f", removePath);
                Require(removeRun.ExitCode == 0, "ssh-keygen -R failed: " + removeRun.Error);
                Require(Run(executable, "-F", "oracle.example", "-f", removePath).ExitCode != 0,
                    "ssh-keygen removal left the default-port host.");
                Require(Run(executable, "-F", "[oracle.example]:2222", "-f", removePath).ExitCode == 0,
                    "ssh-keygen removal damaged the non-default-port host.");
                var removed = OpenSshKnownHostsParser.Parse("removed", File.ReadAllBytes(removePath));
                Require(!removed.Lines.Any(line => line.Record != null &&
                    OpenSshHostMatcher.Matches("oracle.example", line.Record.HostField)),
                    "VT7 still found the OpenSSH-removed host.");
                Require(File.Exists(removePath + ".old"), "ssh-keygen removal did not create its recovery copy.");

                var info = FileVersionInfo.GetVersionInfo(executable);
                return Path.GetFileName(executable) + " " + (info.FileVersion ?? "unversioned");
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        private static KnownHostsDocument ParseLine(string line) =>
            OpenSshKnownHostsParser.Parse("fixture", Utf8.GetBytes(line + "\n"));

        private static KnownHostsDocument Document(string name, string line) => ParseNamed(name, line + "\n");

        private static KnownHostsDocument ParseNamed(string name, string text) =>
            OpenSshKnownHostsParser.Parse(name, Utf8.GetBytes(text));

        private static KnownHostTrustResult Resolve(PresentedHostKey key, params KnownHostsDocument[] documents) =>
            KnownHostTrustResolver.Resolve("example.test", key, documents);

        private static byte[] Ed25519Blob(int start) => Blob("ssh-ed25519", start, 32);

        private static byte[] RsaBlob()
        {
            using var stream = new MemoryStream();
            WriteString(stream, Encoding.ASCII.GetBytes("ssh-rsa"));
            WriteString(stream, new byte[] { 1, 0, 1 });
            var modulus = Enumerable.Range(1, 128).Select(value => (byte)value).ToArray();
            WriteString(stream, modulus);
            return stream.ToArray();
        }

        private static byte[] Blob(string keyType, int start, int payloadLength)
        {
            using var stream = new MemoryStream();
            WriteString(stream, Encoding.ASCII.GetBytes(keyType));
            var payload = Enumerable.Range(start, payloadLength).Select(value => (byte)value).ToArray();
            WriteString(stream, payload);
            return stream.ToArray();
        }

        private static void WriteString(Stream stream, byte[] value)
        {
            stream.WriteByte((byte)(value.Length >> 24));
            stream.WriteByte((byte)(value.Length >> 16));
            stream.WriteByte((byte)(value.Length >> 8));
            stream.WriteByte((byte)value.Length);
            stream.Write(value, 0, value.Length);
        }

        private static string? FindSshKeygen()
        {
            var candidates = new List<string>();
            AddCandidate(candidates, Environment.GetEnvironmentVariable("ProgramW6432"));
            AddCandidate(candidates, Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles));
            var windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            if (!string.IsNullOrEmpty(windows)) candidates.Add(Path.Combine(windows, "System32", "OpenSSH", "ssh-keygen.exe"));
            var path = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
            foreach (var directory in path.Split(Path.PathSeparator))
                if (!string.IsNullOrWhiteSpace(directory)) candidates.Add(Path.Combine(directory.Trim(), "ssh-keygen.exe"));
            return candidates.FirstOrDefault(File.Exists);
        }

        private static void AddCandidate(ICollection<string> candidates, string? programFiles)
        {
            if (!string.IsNullOrEmpty(programFiles)) candidates.Add(Path.Combine(programFiles!, "OpenSSH", "ssh-keygen.exe"));
        }

        private static ProcessResult Run(string executable, params string[] arguments)
        {
            var start = new ProcessStartInfo(executable)
            {
                Arguments = string.Join(" ", arguments.Select(Quote)),
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            };
            using var process = Process.Start(start) ?? throw new InvalidOperationException("Could not start ssh-keygen.");
            var output = process.StandardOutput.ReadToEnd();
            var error = process.StandardError.ReadToEnd();
            if (!process.WaitForExit(15000))
            {
                process.Kill();
                throw new TimeoutException("ssh-keygen exceeded the KH01.1 oracle deadline.");
            }
            return new ProcessResult(process.ExitCode, output, error);
        }

        private static string Quote(string value) => "\"" + value.Replace("\"", "\\\"") + "\"";

        private static void ExpectFormat(Action action)
        {
            try { action(); }
            catch (FormatException) { return; }
            throw new InvalidOperationException("Malformed OpenSSH data was accepted.");
        }

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }

        private sealed class ProcessResult
        {
            internal ProcessResult(int exitCode, string output, string error)
            {
                ExitCode = exitCode;
                Output = output;
                Error = error;
            }
            internal int ExitCode { get; }
            internal string Output { get; }
            internal string Error { get; }
        }
    }
}
