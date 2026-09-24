# OpenSSH-compatible known-host management KH01.4

Date: 2026-09-24. Implementation state: local VT7 0.12.0/native ABI 11
candidate. Windows 7 NESSY/TURTLE acceptance is pending. KH01.3 package 0.4
remains the accepted first-contact baseline.

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
VT7 flushes it, applies the original file security descriptor, rechecks the
source generation and uses `File.Replace` to install the replacement and
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
- The disposable corpus checks selected removal, retained bytes/newlines, ACL
  preservation, exact `.old` backup, stale review, backup replacement,
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

## Package and remaining acceptance

Candidate identity: `VT7-KnownHosts-KH01-0.5-x64.zip`, application 0.12.0,
native ABI 11, publisher-built SSH.NET `2026.0.1-prerelease.6`/`f099365`.
The non-overwriting packager and independent verifier are
`tools/Package-VT7KnownHostsManagement.ps1` and
`tools/Verify-VT7KnownHostsManagementPackage.ps1`. It passes local staged
path-with-spaces checks and independent extracted ZIP verification. The archive
is 15,255,144 bytes and contains 94 verified files. SHA256:
`13175567C37E0566C8601E790A1451902796D4AB3AD5309E2303A0DB5137E814`.
The manifest identifies clean source commit `8bb8834bc3226f71074ed2b9719386f302e5ebb3`.
Review copy: `artifacts/VT7-KnownHosts-KH01-0.5-x64.zip`.

Run the packaged automated launcher on both NESSY (`mscorlib.dll`
`4.8.4110.0`) and TURTLE (`4.8.4795.0`). Then follow its controlled live
changed-key, removal, backup, fresh-reconnect and direct/typed path procedure.
Return a complete `Logs` directory only for failed automated runs. Do not
archive real trust file contents, host-key blobs, fingerprints or credentials.
The controlled live certificate-serving matrix remains a separate KH01.5
gate; offline signed-certificate parsing alone is not network acceptance.
