# OpenSSH-compatible known-host management KH01.4

Date: 2026-09-24. Implementation state: VT7 0.12.3/native ABI 11 inherited-ACL
test correction candidate. Package 0.5 is rejected on NESSY and TURTLE. Package 0.6
passes the automated corpus on both, but live removal stops safely before
mutation at `temporary-security` and its key-row contrast is poor. KH01.3 package 0.4 remains the accepted
first-contact baseline.

## Behavior and security boundary

Both the typed `ssh` overlay and direct **Start SSH...** profile use the same
SSH.NET transport policy. A changed ordinary host key is rejected in the
synchronous host-key callback before authentication. The connection owner then
opens a review with the new key type/fingerprint, host token, relevant source
locations and matching ordinary entries from the primary user file. The owner
must select records and separately confirm removal. VT7 cannot use this view
to remove `@revoked`, `@cert-authority`, system or secondary-user entries. A
successful removal ends the attempt; a new connection and host-key decision
are required. No key is silently replaced or trusted.

Removal takes the reviewed four-source snapshot, acquires VT7's per-file
writer mutex, validates selected line identities, checks all source generations
and opens the primary file with competing writes excluded. Retained physical
lines are copied byte for byte to a unique same-directory temporary file.
VT7 flushes it, copies the original file security descriptor into a fresh
`FileSecurity` object, applies it and verifies owner, group, inheritance
protection and exact DACL entries on the
temporary file, rechecks the source generation and uses `File.Replace` to
install the replacement and
produce `known_hosts.old`. It reloads the store and verifies the retained
content hash, exact backup hash and owner/group/DACL. Changed files, unsafe
paths, stale reviews, malformed sources and invalid selections stop the
mutation. OpenSSH and VT7 do not share a global transaction, so an outside
process that renames files concurrently remains a bounded race; the final
recheck and post-verification detect drift, and the `.old` file is the recovery
copy. The automated corpus covers concurrent VT7 requests and stale reviews.

A presented host certificate is never treated as an ordinary raw host key.
SSH.NET verifies the key-exchange and certificate signatures before the
host-key callback. VT7 then requires an applicable exact `@cert-authority`
public-key blob, host certificate type, valid time interval, nonempty matching
host principals, no critical options and no applicable `@revoked` entry for
the exact certificate, certified key or CA. Principal wildcard matching is
case-sensitive as in OpenSSH; empty principal lists are rejected. A raw
`known_hosts` entry cannot authorize a certificate, and an explicit fingerprint
cannot override certificate policy. The full certificate blob comes from a
guarded internal property of the pinned SSH.NET prerelease.6 assembly; if that
API boundary changes, VT7 rejects certificate trust rather than dropping the
exact-certificate revocation check.

## Local evidence

- Debug and Release builds, `Test-VT7KnownHosts.ps1`,
  `Test-VT7SshNetFoundation.ps1` and the Release typed-overlay regression pass
  on the development host.
- The disposable corpus gives the original a protected ACL distinct from the
  directory-inherited temporary-file ACL, then checks selected removal,
  retained bytes/newlines, exact ACL preservation, exact `.old` backup, stale
  review, backup replacement,
  revocation exclusion, unsafe targets and two competing VT7 removals.
- Certificate policy fixtures cover exact CA, wildcard and case-sensitive
  principals, empty/wrong principal, wrong certificate type, expiry, critical
  options, raw-key non-authorization, exact revocation of each material type
  and non-default-port host tokens.
- The local OpenSSH `ssh-keygen.exe` 9.5.5.2 oracle signs a disposable Ed25519
  host certificate. The pinned SSH.NET assembly parses its complete signed
  bytes, CA and principals; VT7 accepts the exact CA and rejects exact
  certificate revocation. Target package tests additionally require the
  Windows 7 OpenSSH 10.0p2 oracle.
- The offline dialog corpus checks the changed-key text and action contrast.

The OpenSSH principal rule is checked against upstream
[`sshkey_cert_check_authority` and `sshkey_cert_check_host`](https://github.com/openssh/openssh-portable/blob/master/sshkey.c)
and the [single-pattern matcher](https://github.com/openssh/openssh-portable/blob/master/match.c).
The Windows same-volume replacement and backup boundary follows
[Microsoft `File.Replace`](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.replace?view=netframework-4.8.1).
No OpenSSH implementation code was copied; KH01.4 code is VT7-authored under
the repository MIT license. Existing SSH.NET and other supplier notices remain
in the distribution.

## Rejected Windows 7 package 0.5

The archived NESSY and TURTLE reports both fail at `read-back-security` after
the disposable removal. All preceding parser, certificate policy, source
loading and durable-addition checks pass. NESSY uses .NET Framework
`4.8.4110.0`; TURTLE uses `4.8.4795.0`; both use the same package host/native
hashes and OpenSSH 10.0p2 oracle. Package 0.5 had passed local and independent
ZIP checks, but the Windows 7 result rejects it. Four privacy-checked files
plus hashes are retained under
`artifacts/vt7/evidence/known-hosts-kh01-4-win7-0.5-rejected`.

The cause is a .NET Framework API contract: `File.SetAccessControl` does not
persist an unchanged `FileSecurity` object retrieved from another file. The
temporary replacement therefore kept its creation-time security. The code
now creates a fresh descriptor via `SetSecurityDescriptorSddlForm`, applies
it to the temporary file and checks the exact owner/group/DACL *before*
`File.Replace`. The strengthened disposable fixture exercises a protected
ACL that cannot accidentally match the inherited temporary ACL.
[Microsoft documents this copy requirement](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.setaccesscontrol?view=netframework-4.8.1).

## Corrected package and remaining acceptance

Corrected candidate identity: `VT7-KnownHosts-KH01-0.6-x64.zip`, application 0.12.1,
native ABI 11, publisher-built SSH.NET `2026.0.1-prerelease.6`/`f099365`.
The non-overwriting packager and independent verifier are
`tools/Package-VT7KnownHostsManagementAcl.ps1` and
`tools/Verify-VT7KnownHostsManagementAclPackage.ps1`. The issued archive is
SHA256 `DF56400ACB1B0266CD8BB5E99757BB8F08411B058799B1E028BDF5B3D8B218EF`,
15,247,563 bytes and 94 verified files. Its manifest names clean source commit
`3dfd3664a32672d60e28734623c71af0de8a73e7`. Release build, focused
known-host and SSH.NET checks, typed overlay, path-with-spaces staging and the
independent extracted launcher pass locally. NESSY (`4.8.4110.0`) and TURTLE
(`4.8.4795.0`) also pass the automated KH01.4 launcher. Four privacy-checked
files and their hashes are archived under
`artifacts/vt7/evidence/known-hosts-kh01-4-win7-0.6-automated`.
Owner-confirmed live removal fails at
`temporary-security` without changing the real file or creating `.old`.
The real-file descriptor has not been collected, so the precise difference
is unproven. The current exact SDDL-string comparison can reject differences
in auto-inheritance control bits even when owner, group and ACL entries agree.
Review copy:
`artifacts/VT7-KnownHosts-KH01-0.6-x64.zip`.

Version 0.12.2/package 0.7 compares those security components structurally,
retains a fail-closed check before replacement, and reports the mismatched
component if one remains. The corpus now exercises both protected and
inherited file ACLs. An explicit dark key-row `TextBlock` corrects the white
dialog's faint text. The issued package is
`VT7-KnownHosts-KH01-0.7-x64.zip`, SHA256
`402F077ACF230943554C50D964EE9100A02569B4359C1F17C8F254A1B0AF5FC5`,
15,264,946 bytes, 94 verified files. Its manifest names clean source commit
`cf27e25a5e9f793611f4b64449cb0c139f84e51f`. Debug and Release focused
known-host and SSH.NET checks, Release typed overlay, staged path-with-spaces
and independent extracted launcher checks pass locally. Review copy:
`artifacts/VT7-KnownHosts-KH01-0.7-x64.zip`. Its NESSY automated run fails
after removal at the inherited-ACL fixture's *old exact SDDL assertion*, even
though the production writer's structural owner/group/DACL check succeeded.
The complete privacy-checked log and hash are preserved under
`artifacts/vt7/evidence/known-hosts-kh01-4-win7-0.7-rejected`. Package 0.7
is rejected before live testing.

Version 0.12.3/package 0.8 makes that inherited-ACL assertion use the same
structural comparison as production and reports which component differs if
it fails. The actual owner-file live removal is still unverified on Windows 7.
Package 0.8 is issued as `VT7-KnownHosts-KH01-0.8-x64.zip`, SHA256
`16509A782C8EE629E74F8CE4D4FE11E265C93763BB2E75036AC3C5FEE6920AEE`,
15,283,778 bytes and 94 verified files. Its manifest names clean source
commit `e37371c064f466102f9d2450af78a09278d1f720`. Release known-host,
SSH.NET and typed-overlay checks, staged path-with-spaces and independent
extracted launcher checks pass locally. Review copy:
`artifacts/VT7-KnownHosts-KH01-0.8-x64.zip`. Windows 7 automation and live
acceptance remain pending.

Run the package 0.8 automated launcher on both NESSY (`mscorlib.dll`
`4.8.4110.0`) and TURTLE (`4.8.4795.0`). Then follow its controlled live
changed-key, removal, backup, fresh-reconnect and direct/typed path procedure.
Return a complete `Logs` directory only for failed automated runs. Do not
archive real trust file contents, host-key blobs, fingerprints or credentials.
The controlled live certificate-serving matrix remains a separate KH01.5
gate; offline signed-certificate parsing alone is not network acceptance.
