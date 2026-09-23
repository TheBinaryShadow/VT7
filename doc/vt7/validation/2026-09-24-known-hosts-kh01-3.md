# OpenSSH-compatible first-contact trust KH01.3

Date: 2026-09-24. Implementation state: complete and locally validated in VT7
0.11.0/native ABI 11. Windows 7 target acceptance is pending.

## Result

KH01.3 implements the unknown raw-key path defined by the
[known-host management specification](../architecture/2026-09-21-openssh-known-hosts-management-spec.md)
for both direct **Start SSH...** sessions and eligible typed `ssh` overlays.
The SSH.NET callback remains synchronous and bounded. It captures the presented
key, rejects the discovery connection before authentication, and returns the
decision to a generation-scoped WPF prompt. **Connect once** and **Trust and
connect** always use a new `SshClient` and compare newly presented key bytes.

The three actions are:

- **Cancel**: no retry and no file mutation;
- **Connect once**: an in-memory pin covers only the captured host token, exact
  key blob and unchanged four-source store generation for one fresh attempt;
- **Trust and connect**: one canonical raw-key record is appended to the primary
  user file, flushed, reloaded and verified as `Matching` before a fresh attempt.

An exact optional SHA256 fingerprint remains an out-of-band bootstrap signal,
but it no longer bypasses the first-contact decision. A mismatch, changed key,
revocation, unreadable store or certificate policy rejection cannot reach the
prompt or authentication.

## Mutation boundary

`OpenSshKnownHostsWriter` accepts only the four-source snapshot captured for the
prompt and writes only `%USERPROFILE%\.ssh\known_hosts`. It:

1. validates the normalized host token and rejects certificates;
2. takes a bounded per-user mutex derived from the canonical path;
3. reloads all four sources and rejects a stale generation;
4. rejects reparse, directory and read-only targets;
5. creates a missing `.ssh` directory and primary file with protected,
   owner-only ACLs, or preserves an existing file's ACL;
6. opens the primary file with sharing that excludes new writers, rechecks its
   exact length and SHA256, and requires the trust state to remain `Unknown`;
7. appends one bounded line while preserving every prior byte and the dominant
   newline convention, then calls durable `Flush(true)`; and
8. reloads every source, verifies the exact expected primary length/hash,
   verifies all other sources are unchanged, and requires `Matching`.

Failure never falls through to Connect once. The writer does not remove,
replace, normalize or hash records. Removal/replacement, `.old` recovery and
certificate-authority support remain KH01.4.

## Generation and lifetime ownership

Prompt requests carry request, transport, session, transport-generation,
connection-generation, prompt-generation and store-generation identities. The
transport accepts an answer only while all identities still match and its state
is `Starting`. Closing the window/session, cancellation, a later prompt or a
known-host edit invalidates the answer. The failed discovery client and its
private-key owner are disposed before WPF is entered. Every affirmative answer
therefore constructs fresh authentication objects and a fresh connection.

No endpoint, username, fingerprint, key blob, credential, known-host content or
user-specific path is added to default diagnostics.

## Implementation map

| File | KH01.3 responsibility |
| --- | --- |
| `HostTrustPrompt.cs` | Immutable generation-scoped request/response models and the keyboard-accessible three-action WPF prompt. |
| `OpenSshKnownHostsStore.cs` | Stable four-source identity and exact one-connection pin policy. |
| `OpenSshKnownHostsWriter.cs` | Mutex/exclusive append, ACL safety, durable flush and exact read-back verification. |
| `SshNetTransport.cs` | Discovery abort, prompt dispatch, fresh-client retry and fail-closed error categories. |
| `SshOverlayCoordinator.cs` | Shares the same prompt boundary with typed overlays. |
| `MainWindow.xaml.cs` | Owns WPF prompt dispatch and rejects stale or cancelled window generations. |
| `KnownHostsFoundationChecks.cs` | Disposable writer, generation, concurrency, ACL and policy regressions. |
| `SshNetFoundationChecks.cs` | Three-action prompt and WCAG AA text-contrast regression. |

No upstream implementation code was copied for KH01.3. New code is VT7-authored
under the repository MIT license. The existing pinned SSH.NET and OpenSSH oracle
provenance and notices are unchanged.

## Local verification

The following checks pass on the development host:

- Debug and Release x64 builds through the pinned VS 2022/.NET Framework 4.8
  toolchain;
- `Test-VT7SshNetFoundation.ps1 -Configuration Debug`;
- `Test-VT7KnownHosts.ps1 -Configuration Debug` against local
  `ssh-keygen.exe` 9.5.5.2;
- the complete Release `Test-VT7SshOverlay.ps1` session-stream, outbound,
  SSH.NET and H01 corpus plus `Test-VT7KnownHosts.ps1`;
- 1,024 bounded arbitrary-byte parser cases and the existing OpenSSH
  `-F/-H/-R` differential corpus;
- exact retry-pin host/key/store binding;
- new-file and existing-file append behavior, CRLF preservation, stale-store
  rejection, changed-key rejection and a two-writer race with one stale loser;
- owner-only creation ACLs and existing ACL preservation; and
- explicit 4.5:1 text contrast plus all three prompt actions.

Packaged path-with-spaces and independent archive verification will be recorded
with the candidate identity below after packaging.

## Candidate and Windows 7 procedure

The non-overwriting candidate name is `VT7-KnownHosts-KH01-0.4-x64.zip`.
`RUN-KNOWN-HOSTS-KH01-3.cmd` runs only disposable offline fixtures. The package
README then asks for controlled unknown-host checks on both NESSY
(`mscorlib.dll` 4.8.4110.0) and TURTLE (4.8.4795.0): Cancel, Connect once without
persistence, Trust and connect with one saved record, prompt-free stored-key
reconnect from typed and direct paths, Unicode/input/resize/scrollback and clean
remote exit.

This record must not call KH01.3 target accepted until that two-machine live
matrix passes. KH01.2 remains the latest accepted known-host checkpoint until
then.
