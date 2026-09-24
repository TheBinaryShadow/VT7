# OpenSSH-compatible known-host management specification

Decision date: 2026-09-21. Status: implementation specification approved;
KH01.1 is accepted on Windows 7 against the exact 10.0p2 oracle. KH01.2 is
accepted on NESSY and TURTLE. KH01.3 is implemented, package-verified and
target accepted on both machines in VT7 0.11.0. KH01.4 is implemented locally
in VT7 0.12.0. Package 0.5 passed local verification but failed ACL read-back
on both Windows 7 machines. VT7 0.12.1/package 0.6 passes automated checks
on both but live removal stops safely at `temporary-security`. VT7 0.12.2
compares owner, group and ACL components structurally; package 0.7 exposed an
obsolete exact-SDDL assertion in the inherited-ACL test on NESSY. VT7 0.12.3/
package 0.8 corrects that assertion and awaits target validation.

This specification defines VT7's first durable SSH host-trust subsystem. It
replaces the generic trust-store wording in the broader
[terminal document and SSH handoff specification](2026-09-14-terminal-document-and-ssh-handoff-spec.md)
with an OpenSSH-compatible design. The existing, accepted fingerprint-only
path remains the security baseline until every acceptance gate in this document
passes.

## Decision summary

VT7 will use the user's existing OpenSSH known-host files rather than create a
private VT7 trust database. The first implementation reads the normal user and
system files, writes only the primary user file, preserves material it does not
modify, and produces entries that `ssh.exe` and `ssh-keygen.exe` understand.

Compatibility is defined against the OpenSSH 10.0p2 generation carried by the
Microsoft Win32-OpenSSH 10.0.0.0p2 Preview package already characterized on the
Windows 7 test machine. OpenSSH's manuals and source are the behavioral oracle.
The file format is an OpenSSH convention rather than an IETF SSH wire-protocol
standard, so naming the exact implementation baseline matters.

VT7-authored parser, matcher, policy and Windows persistence code will be MIT
licensed. OpenSSH source may be studied and tested against. A direct or close
translation of an OpenSSH routine is allowed only when it materially reduces
security or compatibility risk; that file must retain the applicable upstream
copyright and license text and be recorded in `NOTICE.md`. No OpenSSH binary or
source is required at VT7 runtime.

Host trust remains a pre-authentication decision. A stored mismatch, revocation,
unreadable relevant record or unsupported relevant policy fails closed. An
unknown host may be trusted once or saved only through structured VT7 UI. VT7
never asks a shell to interpret localized SSH output and never accepts a host
key from terminal text.

## Goals

The implementation must:

1. interoperate with `%USERPROFILE%\.ssh\known_hosts` written by compatible
   OpenSSH clients;
2. understand literal, patterned, negated and hashed host fields, non-default
   ports, ordinary host keys, `@revoked`, and `@cert-authority`;
3. compare the exact SSH public-key blob rather than a display string or the
   negotiated signature algorithm name;
4. decide trust before SSH.NET sends any authentication request;
5. provide explicit matching, unknown, changed, revoked, unreadable and
   policy-rejected outcomes;
6. preserve the accepted out-of-band SHA256 fingerprint path as a secure
   fallback and bootstrap option;
7. share files without discarding comments, unknown entries, line endings or
   concurrent changes;
8. make saved entries readable by OpenSSH and make OpenSSH entries readable by
   VT7 within the scope declared here;
9. keep passwords, passphrases, private keys, endpoints, usernames, host keys
   and fingerprints out of default diagnostics; and
10. run on Windows 7 SP1 x64 and .NET Framework 4.8 without a service, agent,
    administrator privilege or post-Windows 7 filesystem primitive.

## Non-goals of the first implementation

This work does not implement all of `ssh_config`, replace `ssh-keygen`, or make
SSH.NET an OpenSSH client internally. The following remain separate work:

- `HostKeyAlias`, custom `UserKnownHostsFile`, `GlobalKnownHostsFile`,
  `KnownHostsCommand`, `CheckHostIP yes`, DNS SSHFP and hostname
  canonicalization;
- automatic `UpdateHostKeys` learning after authentication;
- importing trust from PuTTY, registry stores or browser certificate stores;
- key generation, user-certificate management or an SSH agent;
- editing arbitrary third-party known-host files selected by the user;
- silently repairing malformed files; and
- accepting a changed or revoked key through a one-click connection prompt.

Unsupported configuration semantics continue through the existing exact
external-OpenSSH fallback when the typed-command grammar selects that path.
The embedded path must state its narrower behavior rather than imply that it
processed the user's complete OpenSSH configuration.

## Normative baseline and references

The compatibility baseline is:

- [Microsoft Win32-OpenSSH 10.0.0.0p2 Preview](https://github.com/PowerShell/Win32-OpenSSH/releases/tag/10.0.0.0p2-Preview),
  release commit `2cc4c13`, which carries upstream OpenSSH 10.0p2 changes;
- the matching [PowerShell/openssh-portable v10.0.0.0 source](https://github.com/PowerShell/openssh-portable/tree/v10.0.0.0),
  especially [`hostfile.c`](https://github.com/PowerShell/openssh-portable/blob/v10.0.0.0/hostfile.c),
  [`match.c`](https://github.com/PowerShell/openssh-portable/blob/v10.0.0.0/match.c),
  [`sshconnect.c`](https://github.com/PowerShell/openssh-portable/blob/v10.0.0.0/sshconnect.c),
  and [`ssh_config.5`](https://github.com/PowerShell/openssh-portable/blob/v10.0.0.0/ssh_config.5);
- the OpenSSH [known-hosts file format](https://man.openbsd.org/sshd#SSH_KNOWN_HOSTS_FILE_FORMAT)
  and [`ssh-keygen(1)` host-file operations](https://man.openbsd.org/ssh-keygen);
- SSH.NET 2026.0.0
  [`HostKeyEventArgs`](https://sshnet.github.io/SSH.NET/api/Renci.SshNet.Common.HostKeyEventArgs.html),
  [`SshKeyData`](https://sshnet.github.io/SSH.NET/api/Renci.SshNet.Security.SshKeyData.html)
  and [`Certificate`](https://sshnet.github.io/SSH.NET/api/Renci.SshNet.Security.Certificate.html)
  contracts; and
- RFC 4253 key-blob framing and the OpenSSH certificate format where wire data
  must be decoded.

If prose in this document is ambiguous, a differential test against the exact
10.0p2 `ssh-keygen.exe` and tagged source decides file-format behavior. A newer
OpenSSH release does not silently move the baseline. Updating the baseline
requires a recorded compatibility and security review.

## Compatibility boundary

"OpenSSH-compatible" has a precise meaning for this milestone:

- VT7 accepts the declared known-host line grammar and host matching behavior.
- VT7 uses OpenSSH's host token for the explicitly requested hostname and port.
- VT7 reaches the same trust result for the same presented key and applicable
  records, subject to the documented fail-closed Windows safety rules below.
- Entries VT7 adds can be found and removed by the baseline `ssh-keygen.exe`.
- VT7 does not need `ssh.exe` or `ssh-keygen.exe` at runtime.

VT7 intentionally strengthens two failure cases. If an existing configured
file cannot be read, or a malformed record might apply to the requested host,
VT7 blocks the connection instead of treating the host as new. This prevents a
permissions or parsing failure from becoming a trust reset. These are explicit
security-policy differences, not accidental incompatibilities.

## File discovery and ownership

The initial source set, in evaluation order, is:

1. `%USERPROFILE%\.ssh\known_hosts`;
2. `%USERPROFILE%\.ssh\known_hosts2`;
3. `%ProgramData%\ssh\ssh_known_hosts`; and
4. `%ProgramData%\ssh\ssh_known_hosts2`.

The two `known_hosts2` paths are read for compatibility but are never selected
for a new write. The two ProgramData paths are administrator-owned and read
only. A new permanent decision is written only to
`%USERPROFILE%\.ssh\known_hosts`.

All readable sources are additive. File order is retained for evidence and UI,
but a later ordinary match cannot override a revocation or a relevant read
failure from another source. A missing optional file contributes no records and
is not an error. An existing inaccessible file is `Unreadable`.

Paths are expanded once from the connection owner's Windows user profile, then
converted to absolute paths. Environment expansion, current-directory lookup
and shell tilde expansion are forbidden after that point. The resolved source
set belongs to the connection generation so a late callback cannot switch
users or paths.

VT7 will not automatically mutate a known-host file or `.ssh` directory that is
a reparse point in the first implementation. It may read a canonicalized target
when policy permits, but a requested save or removal must stop with a clear
management error and leave the connection untrusted. This avoids silently
writing outside the user profile on Windows 7. A later explicit linked-store
policy can relax this after targeted tests.

## Byte-preserving file model

The loader retains both a parsed view and the exact original bytes. Each source
records:

- absolute path, existence, length, last-write time and a SHA256 content hash;
- file identity where Windows exposes it reliably;
- newline convention and whether the final line has a terminator;
- every original line as a byte range;
- parsed fields, marker, source path and one-based line number; and
- a bounded parse result with any reason a line could not be interpreted.

Unmodified lines are emitted byte for byte during a rewrite. Comments, spacing,
unknown non-applicable key types, and mixed CRLF/LF line endings are not
normalized. A newly added entry is ASCII with the source's dominant newline,
or CRLF for a new or newline-free file. If the existing final line has no
terminator, VT7 writes one before the new record.

The parser has explicit resource limits. The proposed initial limits are 16 MiB
per file, 64 KiB per physical line, 16,384 records, 256 host patterns per line,
8 KiB per host field, and 64 KiB after base64 key decoding. Exceeding a limit in
an existing source is `Unreadable`, never `Unknown`. The exact limits become
public constants and regression fixtures before integration.

## Known-host line grammar

After optional leading spaces or tabs, an empty line or a line beginning with
`#` is a comment. A key line contains:

```text
[marker] hostnames keytype base64-key [comment]
```

Fields are separated by one or more spaces or tabs. The supported markers are:

- no marker: an ordinary host key;
- `@cert-authority`: a CA key allowed to certify a matching host; and
- `@revoked`: key material that must never be accepted for a matching host.

Only one marker is legal. Marker matching is exact. An unknown or malformed
marker on a potentially applicable line is policy-rejected.

`hostnames` is a comma-separated list. Plain patterns support OpenSSH `*` and
`?` wildcards and `!` negation. A matching negative pattern defeats positive
patterns on that line. Pattern matching is performed with OpenSSH-compatible
ASCII case behavior and no DNS lookup.

A field beginning `|1|` is the OpenSSH hashed-host form:

```text
|1|base64-20-byte-salt|base64-HMAC-SHA1(salt, host-token)
```

VT7 computes the HMAC over the exact normalized host token described below and
compares the decoded result in fixed time. Version `1`, a 20-byte salt and a
20-byte digest are required. Hashed host fields do not carry wildcard lists or
negation. An invalid hash in a loaded source is preserved; because its target
cannot be determined safely, it blocks automatic trust until repaired.

The base64 key field decodes to the RFC 4253 serialized public-key blob. VT7
parses the leading SSH string containing the key type with bounded reads and
requires it to agree with the textual `keytype` under OpenSSH's key-type rules.
Trailing comments are opaque and preserved.

A UTF-8 byte-order mark is not silently removed because the baseline OpenSSH
grammar does not define it. Non-ASCII comment bytes are preserved. Host, marker,
key-type and base64 tokens must remain valid under their field grammar.

## Host identity and lookup token

The trust lookup starts from the endpoint the user explicitly requested, before
name resolution. VT7 does not trust a reverse DNS name and does not add resolved
IP addresses in this slice, matching the baseline `CheckHostIP no` default.

Normalization is deterministic:

1. trim no semantic characters; the command/dialog parser already rejects
   surrounding whitespace and control characters;
2. remove syntactic brackets from an IPv6 input before forming the token;
3. apply ASCII lowercase to a DNS hostname; preserve the textual IP value;
4. use the lowercase hostname or IP alone for port 22; and
5. use `[hostname]:port` for every non-default port, including IPv4, DNS and
   IPv6 hosts.

No search suffix, IDNA conversion, CNAME following, reverse lookup or current
machine locale participates. This token is used for literal matching, wildcard
matching, hashed matching, display of the trust target, and new records.
KH01.1 policy-rejects non-ASCII host input rather than guessing an IDNA mapping;
any later IDNA support requires an explicit compatibility decision and fixtures.

The username is not part of host identity. The same host and port must reach the
same trust decision for every account and authentication method.

## Key identity and algorithm handling

The authoritative identity is the exact serialized public-key blob. SHA256
fingerprints are display and out-of-band verification values derived from that
blob; they are not the stored primary key.

SSH.NET exposes both `HostKeyEventArgs.HostKey` and `HostKeyName`. VT7 uses the
former. In particular, an RSA key may be negotiated with `rsa-sha2-256` or
`rsa-sha2-512` while the public-key blob begins with `ssh-rsa`. Comparing only
`HostKeyName` would falsely reject or misclassify the same RSA key. VT7 parses
the blob's internal key type, validates the stored text type, then compares the
complete blob in fixed time.

Fingerprints use SHA256 over the exact blob and OpenSSH presentation:
`SHA256:` followed by unpadded base64. Internal normalization accepts the
existing dialog's optional prefix, surrounding whitespace and padding only at
the input boundary. UI always displays the canonical prefixed form.

Multiple ordinary keys and algorithms may be valid for one host token. Saving
a newly presented key does not delete another valid key. Replacement is a
separate, deliberate management operation.

## Trust evaluation

The resolver returns an immutable result containing state, canonical host token,
presented key type and fingerprint, relevant source locations, and safe reason
codes. The states are:

| State | Meaning | Connection action |
| --- | --- | --- |
| `Matching` | An applicable ordinary key exactly matches, or a valid host certificate chains to an applicable CA. | Trust and proceed to authentication. |
| `Unknown` | No applicable ordinary key or CA establishes trust and no conflicting record exists. | Abort this attempt and request a structured user decision. |
| `Changed` | Applicable ordinary host keys exist for this identity, but none matches the presented key. | Hard block; require deliberate management. |
| `Revoked` | An applicable `@revoked` entry matches the presented key, its certified key, or its signing CA as OpenSSH requires. | Hard block with no connect override. |
| `Unreadable` | An expected source exists but cannot be read, exceeds limits, changes during evaluation, or contains an applicable/indeterminate malformed record. | Hard block; repair the store or use an explicitly isolated fallback workflow. |
| `PolicyRejected` | A relevant certificate, marker, key type, critical option, path or file condition is recognized but unsupported or prohibited. | Hard block; no downgrade to `Unknown`. |

Precedence is `Revoked`, `Unreadable`/`PolicyRejected`, `Matching`, `Changed`,
then `Unknown`. This means an exact match in one file does not hide a revocation
or unsafe relevant source in another.

For ordinary keys, the OpenSSH model is preserved: an exact applicable key is
`Matching`; otherwise the presence of applicable ordinary host keys makes the
result `Changed`; otherwise it is `Unknown`. Marker class and certificate
semantics are evaluated separately, then combined by the precedence above.

The result is never inferred from fingerprint text previously rendered to the
terminal. It is computed from the current SSH.NET callback bytes and a store
snapshot tied to this connection attempt.

## Host certificates

`@cert-authority` is part of the compatibility contract, not an ordinary key
alias. When SSH.NET reports a certificate, VT7 must require all of the following:

1. SSH.NET has validated the key-exchange signature, certificate signature and
   validity interval;
2. the certificate is a host certificate;
3. its signing CA public-key blob exactly matches an applicable
   `@cert-authority` record;
4. the host token satisfies the certificate principals under OpenSSH rules;
5. the certificate contains no unsupported critical option;
6. the certificate, certified host key and signing CA are not revoked by an
   applicable `@revoked` record; and
7. every relevant field can be parsed within the declared bounds.

OpenSSH rejects an empty principal list. Host principals use case-sensitive
single-pattern wildcard matching, unlike known_hosts host-field matching.
VT7 verifies those rules against OpenSSH source and signed disposable fixtures;
the controlled-server matrix remains an acceptance gate. Unknown critical
options always fail closed.

If SSH.NET cannot expose enough authenticated certificate material to enforce
these checks, certificate trust remains `PolicyRejected` and the release gate
stays open. VT7 must not fall back to accepting the certificate's embedded raw
host key as if no certificate were presented.

## Existing fingerprint fallback

The accepted direct-profile flow currently requires a separately obtained
SHA256 fingerprint. It remains available during and after this work.

An explicit fingerprint can establish an unknown host for one connection when
it exactly matches the current callback key. It may also authorize adding that
same key if the user selects the save action. It cannot override `Changed`,
`Revoked`, `Unreadable` or `PolicyRejected`, and it cannot turn a certificate
policy failure into raw-key trust.

This rule preserves a secure recovery route without making a stored mismatch
look like first contact. A deliberate changed-key workflow must identify and
remove or replace the old record before another connection attempt.

## SSH.NET integration and connection state machine

`HostKeyReceived` is synchronous and runs on SSH.NET's connection worker. The
callback performs bounded, in-memory evaluation only. It does not show UI, read
or write files, enter WPF, or hold a session/transport lock.

Before `SshClient.Connect`, the connection owner:

1. resolves source paths and loads an immutable store snapshot;
2. validates any explicit fingerprint and authentication inputs;
3. creates a new connection and prompt generation; and
4. subscribes the host-key callback with that snapshot and generation.

The callback copies the bounded presented key and certificate facts, resolves
trust and sets `CanTrust` true only for `Matching` or an exact authorized
one-connection pin. All other results set it false. SSH.NET then aborts during
key exchange, before authentication.

For `Unknown`, the owner receives the captured result after the failed attempt
and posts a generation-scoped WPF request. The user may cancel, connect once, or
trust and connect. Either affirmative choice creates a fresh `SshClient` and a
fresh connection attempt:

- Connect once installs an in-memory pin for the exact captured host token and
  key blob.
- Trust and connect safely writes the record, reloads the store, and expects an
  ordinary `Matching` result.

The second connection compares the server's newly presented bytes again. A key
substitution between the prompt and retry therefore fails. No credentials are
sent in the discovery attempt. Secret objects may already exist in the
authentication owner, but are neither logged nor offered until trust succeeds.

A prompt answer is accepted only if session, overlay, connection and prompt
generations still match. Closing the window/session, changing the active root,
starting another connection, or editing the relevant store invalidates the old
answer.

## User experience

A matching key produces no trust prompt. The status surface may state that the
known-host check passed without revealing endpoint or fingerprint in default
logs.

An unknown-host prompt shows:

- the exact host token and port being trusted;
- key type and canonical SHA256 fingerprint;
- whether an out-of-band fingerprint was supplied and matched;
- the destination user only in the transient UI, not diagnostics; and
- actions **Cancel**, **Connect once**, and **Trust and connect**.

The prompt explains that first-contact verification should compare the
fingerprint with a separate trusted source. **Trust and connect** names the user
file it will update. A save failure leaves the host untrusted and does not fall
through to Connect once.

A changed-key screen shows the presented key type/fingerprint and the source
paths and line numbers of conflicting entries. It clearly states that the
connection was stopped before authentication. Its actions are **Cancel** and
**Manage known hosts**. There is no ordinary **Continue** button.

The management view may remove selected user-owned records after confirmation,
then requires a new connection and trust decision. It cannot edit ProgramData
records without leaving VT7 and administrator action. Replacement is modeled
as remove, reconnect, verify, then add; VT7 never overwrites a key solely
because a new server presented one.

Revoked, unreadable and policy-rejected screens identify the safe reason and
source location without displaying raw key material. Revoked keys have no
override. The UI must remain keyboard accessible and respect Windows 7 high
contrast before this feature is accepted.

## Persistence, concurrency and recovery

Every mutation begins from a freshly loaded snapshot. VT7 serializes its own
writers with a per-user named mutex whose name is derived from the canonical
primary path without exposing that path in logs. The mutex has a bounded wait
and abandoned-owner handling.

### Addition

For a new trust record VT7:

1. acquires the writer mutex;
2. opens or creates the primary file with sharing that excludes other writers;
3. re-reads and re-evaluates the target against the presented key;
4. stops if the state is no longer `Unknown` or the file is unsafe;
5. appends one complete OpenSSH line through the held handle;
6. flushes file data before reporting success; and
7. reloads the file and requires `Matching`.

The write is one bounded record. If the process dies before the line is complete,
the next load reports the relevant truncated line as unreadable instead of
accepting it. VT7 never reports success until read-back verification passes.

New entries are unhashed in the first slice unless a project setting explicitly
enables OpenSSH host hashing and its differential tests pass. When hashing is
enabled, VT7 generates a fresh cryptographically random 20-byte salt per record
and writes the exact `|1|` HMAC-SHA1 form. SHA1 here is the fixed OpenSSH privacy
format, not a host-key signature or trust hash.

### Removal and replacement

Removing selected user records is a byte-preserving rewrite:

1. acquire the writer mutex and exclusive source access;
2. compare identity, length and SHA256 with the reviewed snapshot;
3. reparse and verify the selected path/line/key identities;
4. write retained raw lines to a unique temporary file in the same directory;
5. flush the temporary file and preserve the original file's security metadata;
6. create or replace `known_hosts.old` as the recoverable prior copy;
7. atomically replace the original with the temporary file using a Windows 7
   supported same-volume operation; and
8. reload and verify both the intended removal and all retained records.

Any identity or content change causes a bounded reload/review retry, never a
blind overwrite. Failure leaves the original file authoritative. Temporary and
backup cleanup is conservative: an unexplained artifact is reported for repair,
not silently promoted to trusted content.

VT7 never weakens directory or file ACLs. A new `.ssh` directory and file use
owner-only access where Windows 7 APIs can establish it safely; packaging tests
must prove the actual ACL. Existing owner/admin/system permissions are retained.
Read-only files, locked files, ACL-copy failures, cross-volume paths and reparse
targets stop the mutation.

OpenSSH and VT7 cannot share a cross-process transaction protocol. The design
therefore combines exclusive mutation handles, content rechecks, same-directory
replacement and post-write verification. Tests must force external edits at
each boundary and prove VT7 either includes the edit or fails without losing it.

## Diagnostics and privacy

Default diagnostics may record:

- generated session/connection IDs;
- trust state and safe reason code;
- source category (`user-primary`, `user-legacy`, `system-primary`,
  `system-legacy`) and line count;
- parser/mutation stage, duration and normalized exception category;
- whether a record was literal, patterned or hashed; and
- whether the key was raw or certificate-backed and its algorithm family.

Default diagnostics must not record:

- hostname, address, port, username or full command line;
- raw or base64 host key, certificate, salt or hash;
- fingerprint;
- private-key path or contents;
- password/passphrase or prompt text; or
- raw known-host lines, comments or filesystem paths containing the user name.

An explicit support export may include separately consented redacted metadata.
Automated test fixtures use reserved example names and generated keys.

## Licensing and source-reuse rule

The preferred implementation is clean VT7 C# written from public format
documentation and verified against observable OpenSSH behavior. That source is
MIT licensed with the rest of VT7.

OpenSSH's aggregate `LICENCE` states that its components are BSD-style or more
permissive; individual files carry specific notices. If a routine is directly
ported, its new source file must:

1. identify the exact upstream repository, tag, path and commit;
2. retain the applicable file-level copyright, conditions and disclaimer;
3. describe the mechanical and semantic modifications;
4. add the notice to `NOTICE.md` and the packaged license inventory; and
5. receive a focused compatibility review under the standing
   [third-party licensing policy](2026-09-14-third-party-licensing-policy.md).

The HMAC-SHA1 hash calculation and wildcard matching are small enough to
implement independently and differential-test first. Direct reuse is reserved
for a demonstrated ambiguity or mismatch that cannot be corrected reliably
from the documented behavior. Calling `ssh-keygen.exe` at runtime is rejected:
it is not guaranteed to exist, complicates cancellation and quoting, leaks
endpoints into a child command line, and does not solve the synchronous SSH.NET
trust callback.

## Proposed code boundaries

Names may change during implementation, but ownership may not blur:

- `KnownHostsPathResolver`: creates the immutable ordered source set.
- `KnownHostsFileReader`: bounded byte-preserving load and source metadata.
- `KnownHostsParser`: pure line grammar and bounded key-blob decoding.
- `OpenSshHostToken`: endpoint normalization and non-default-port form.
- `OpenSshHostMatcher`: literal, pattern-list, negation and `|1|` matching.
- `KnownHostTrustResolver`: pure multi-source state and precedence.
- `PresentedHostKey`: immutable SSH.NET callback facts and canonical fingerprint.
- `KnownHostsWriter`: addition, removal, backup, ACL and recovery policy.
- `HostTrustCoordinator`: connection-attempt generations and retry state machine.
- `HostTrustDialog` and `KnownHostsManagementDialog`: WPF decisions only.

`SshNetTransport` remains the owner of SSH.NET callbacks and transport lifetime.
It receives a prepared trust attempt rather than reading files or invoking UI.
`SshConnectionOptions` carries authentication and endpoint choices but no longer
requires a fingerprint when durable trust resolves. `SshOverlayCoordinator`
continues to own typed overlay/root suspension ordering and delegates trust UI
through the existing WPF boundary.

Pure parser, matcher and resolver code should live outside visual classes and
accept byte arrays/immutable models, making fuzzing and exact fixtures possible.

## Implementation slices

### KH01.1: parser and differential oracle

Implementation status: complete and target accepted in package 0.1 against the
exact Windows 7 10.0p2 oracle. See the
[KH01.1 validation record](../validation/2026-09-22-known-hosts-kh01.md).

- Implement bounded raw-line parsing, host token creation, patterns, negation,
  hash version 1, key-blob validation and trust precedence.
- Add a generated fixture corpus and compare lookup, hashing and removal cases
  with the exact 10.0p2 `ssh-keygen.exe` on the development and target machines.
- Make no production connection-path change.

### KH01.2: read-only production trust

Implementation status: complete and target accepted in VT7 0.10.1/package 0.3.
Local Debug, Release, typed-overlay, packaged-path and independent ZIP checks
pass, as do the automated and live direct/typed SSH paths on NESSY and TURTLE.
See the [KH01.2 validation record](../validation/2026-09-22-known-hosts-kh01-2.md).

- Load the four default sources before connection.
- Integrate raw-key and revocation evaluation into `HostKeyReceived`.
- Keep the mandatory fingerprint for unknown hosts.
- Prove matching skips re-entry, while changed/unreadable/revoked states block
  before authentication in direct and typed-overlay paths.

### KH01.3: first-contact and durable addition

Implementation status: complete and target accepted in VT7 0.11.0/package 0.4
on both Windows 7 runtime tiers. See the
[KH01.3 validation record](../validation/2026-09-24-known-hosts-kh01-3.md).

- Add generation-safe unknown-host UI, Connect once and Trust and connect.
- Abort discovery and create a fresh connection for every affirmative decision.
- Add safe primary-user-file writes and read-back verification.
- Retain the explicit fingerprint bootstrap route.

### KH01.4: management and certificates

Implementation status: VT7 0.12.0/package 0.5 rejected on NESSY and TURTLE
after local checks passed. VT7 0.12.1 corrects the `FileSecurity` copy and
verifies the temporary file's ACL before replacement. See the
[KH01.4 validation record](../validation/2026-09-24-known-hosts-kh01-4.md).
Windows 7 target acceptance remains open.

- Add deliberate user-record removal with `.old` recovery and concurrency tests.
- Complete `@cert-authority`, principal, critical-option and revocation behavior.
- Do not mark known-host management complete until certificate and marker cases
  reach the declared oracle behavior or are visibly policy-rejected.

### KH01.5: target acceptance

- Package, independently verify and run the complete Windows 7 matrix.
- Archive only the required privacy-safe evidence and exact package identity.
- Update the roadmap checkbox only after every acceptance criterion below passes.

## Verification plan

### Parser and matcher corpus

Fixtures cover:

- blank/comment lines, leading whitespace, CRLF, LF, mixed endings and no final
  newline;
- literal DNS names, IPv4, IPv6, default and non-default ports;
- comma lists, `*`, `?`, negation and ASCII case behavior;
- correct and incorrect `|1|` hashes, salts, padding and digest lengths;
- multiple keys and algorithms for one host;
- RSA negotiated-name versus `ssh-rsa` blob identity;
- malformed/truncated fields, base64, key blobs, markers and oversized input;
- `@revoked`, `@cert-authority`, ordinary keys and certificate records; and
- unrelated malformed lines versus relevant or indeterminate malformed lines.

Every test states whether it checks exact OpenSSH behavior or VT7's documented
fail-closed extension.

### Differential OpenSSH tests

Against the pinned target tools:

- compare VT7 lookup with `ssh-keygen -F` for literal, patterned, hashed and
  non-default-port identities;
- compare generated hash records with `ssh-keygen -H` behavior and confirm each
  tool finds the other's entry;
- compare selected removal with `ssh-keygen -R`, including the `.old` recovery
  expectation;
- feed the same generated key corpus to both implementations; and
- preserve the tool version, executable hash and fixture seed in the result.

The test tool may invoke `ssh-keygen`; production code may not.

### Property, fuzz and mutation tests

- Random non-target lines survive a no-op or unrelated removal byte for byte.
- Parser work and allocation remain bounded for arbitrary bytes and long lines.
- Hash matches are deterministic and comparisons do not early-exit on secret
  digest bytes.
- File change, lock, process crash, short write, disk-full simulation, stale
  generation, ACL failure, read-only state and reparse paths fail safely.
- Two VT7 writers and a simulated external OpenSSH writer cannot silently lose
  an accepted external edit.
- A post-prompt server key swap fails the fresh connection attempt.

### Controlled-server integration

The Debian 12 server and isolated test account exercise:

1. unknown key, Cancel, and proof that authentication did not occur;
2. Connect once followed by a second connection that is unknown again;
3. Trust and connect, then reconnect with no trust prompt;
4. public-key and password authentication after trust;
5. direct **Start SSH...** and typed `ssh` from Command Prompt, Windows
   PowerShell 5.1 and PowerShell 7.2.24;
6. changed server key hard block and source-line management;
7. revoked host key and revoked CA hard block;
8. plain, wildcard and hashed records;
9. port 22 and a non-default port;
10. a valid host certificate, wrong principal, expired/not-yet-valid certificate,
    unknown critical option and untrusted CA;
11. sequential overlays, explicit disconnect, root prompt recovery and shutdown;
    and
12. privacy inspection of all retained logs.

Authentication logs on the controlled server must establish that rejected
trust attempts never reached authentication.

## Windows 7 acceptance matrix

The target package must pass:

- Debug and Release local parser/resolver suites;
- packaged dependency, image/import, notice and ZIP verification;
- PowerShell 5.1 batch launch from a path containing spaces;
- read and write of a fresh user store;
- coexistence with a store written by installed OpenSSH 10.0p2;
- shared matching, hashing and removal fixtures with exact target tool hashes;
- read-only and locked user file behavior;
- global match, global mismatch/revocation and refusal to edit global records;
- ACL and `.old` recovery checks;
- all controlled-server cases above; and
- keyboard-only/high-contrast trust and management dialogs.

The current Croatian HR Latin input method remains part of the ordinary typed
overlay run. No unchanged WARP diagnostic is required for this feature unless
the implementation changes renderer lifetime or triggers a REL01 reopening
condition.

## Acceptance criteria

Known-host management is complete only when:

1. the parser/matcher corpus and exact 10.0p2 differential suite pass;
2. the user and system default files are read with the declared precedence;
3. an existing match connects without fingerprint re-entry;
4. unknown trust supports Cancel, Connect once and durable save through a fresh
   connection attempt;
5. changed, revoked, unreadable and policy-rejected states stop before
   authentication and cannot be bypassed by the ordinary prompt;
6. the explicit out-of-band fingerprint path remains usable for an unknown host;
7. additions and removals preserve unrelated bytes and survive concurrency,
   failure and recovery tests without silent data loss;
8. raw RSA key identity and host-certificate behavior pass their dedicated
   cases;
9. direct and typed-overlay paths pass on Windows 7 with clean root recovery;
10. dialogs pass keyboard and contrast checks;
11. logs pass the privacy review; and
12. source provenance, any reused OpenSSH notices and packaged disclosures are
    complete.

Passing only plain-key happy paths is not enough to mark the roadmap item done.
Slices may ship in engineering packages while the checkbox remains open.

## Rejected alternatives

### Private VT7 trust database

This would duplicate user decisions, surprise users who already maintain
OpenSSH trust, and require import/export and conflict policy. It is rejected.

### Runtime `ssh-keygen` subprocess

This adds an optional executable dependency and child-process security surface,
cannot answer the synchronous callback itself, and exposes endpoint material in
process arguments. It remains a test oracle only.

### Prompt inside `HostKeyReceived`

The callback is synchronous on a connection worker. Blocking it on WPF creates
deadlock, cancellation and stale-answer hazards. Unknown discovery aborts, UI
runs outside the callback, and an affirmative decision starts a fresh attempt.

### Trust by negotiated algorithm and fingerprint string alone

Negotiated RSA signature names differ from the stored key-blob type, and text
normalization is not the file's key identity. Exact serialized key bytes are
authoritative.

### Accept changed key after a warning

A changed record can indicate interception or an uncoordinated server rebuild.
Ordinary connection UI cannot override it. Removal/replacement is a deliberate
management operation followed by a new connection.

### Rewrite and normalize the whole file

OpenSSH files are shared user data. Reformatting comments, whitespace, unknown
entries or line endings creates needless damage and merge conflicts. VT7
preserves untouched bytes.

## Documentation and completion record

Implementation changes must update this specification when behavior changes,
the [roadmap](../../../ROADMAP.md), [development handoff](../HANDOFF.md),
[documentation index](../README.md), the SSH.NET direct and overlay validation
records, `NOTICE.md` if any upstream code is ported, and a dated KH01 validation
record containing exact package and target evidence.

This document authorizes engineering work within its boundaries. KH01.1 through
KH01.3 are target accepted. KH01.4 is implemented and locally package-verified,
with live acceptance still open. Complete known-host management is not claimed until
KH01.4 and KH01.5 close their remaining behavior and matrix.
