# OpenSSH-compatible first-contact trust KH01.3

Date: 2026-09-24. Implementation state: target accepted in VT7 0.11.0/native
ABI 11 on both Windows 7 runtime tiers.

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

The staged PowerShell 5.1 CMD launchers pass from a path containing spaces. The
independent verifier reopens the archive, rejects unsafe or duplicate paths,
recomputes all 94 entry hashes, checks the write-enabled manifest and PE/runtime
closure, extracts into a fresh directory and reruns the packaged KH01.3 launcher.

## Accepted package and Windows 7 result

The accepted non-overwriting package is `VT7-KnownHosts-KH01-0.4-x64.zip`:

- source commit: `750bbca99` (`sourceGitDirty: false` in the manifest);
- SHA256: `531B4A1D43894408F7AA38AC6E0BC22C6EBA1394519C3A70C1C9A83AA64B2C83`;
- size: 15,262,430 bytes;
- files: 94 verified archive entries; and
- review copy: `artifacts/VT7-KnownHosts-KH01-0.4-x64.zip`.

Both target machines pass the exact packaged automated runner. Each report
identifies Windows NT 6.1.7601 SP1 x64, Croatian regional settings,
PowerShell 5.1.14409.1005, the same VT7 host/native hashes and the required
Win32-OpenSSH 10.0p2 `ssh-keygen.exe` oracle. NESSY exercises the ordinary
non-ESU .NET Framework `mscorlib.dll` 4.8.4110.0 tier with VMware SVGA 3D;
TURTLE exercises 4.8.4795.0 with an AMD Radeon RX 6800 XT. Both reports record
VT7 0.11.0 Release, ABI 11, all 1,024 parser cases, the `ssh-keygen` differential
oracle and the durable KH01.3 writer corpus as passed with no error.

The owner then completed the package README's controlled live matrix on both
machines: Cancel, Connect once without persistence, Trust and connect with one
saved record, prompt-free stored-key reconnect through typed and direct paths,
Unicode/input/resize/scrollback and clean remote exit all pass. The automated
logs establish the offline contracts; the owner report establishes the live
network/UI behavior. No credential is retained in either evidence set.

The four returned files and `ARCHIVE-VERIFICATION.json` are preserved under
`artifacts/vt7/evidence/known-hosts-kh01-3-win7-0.4`. The verification record
binds them to the accepted package identity and records these SHA256 values:

| Machine | File | SHA256 |
| --- | --- | --- |
| NESSY | `known-hosts.log` | `CF4C87FB1C077422C44483B13459E507F0E358DEB84E405438B1E0AA3CDDE7B5` |
| NESSY | `RUN-ENVIRONMENT.txt` | `8D2093CD253791E68184783487569A931603EAA2178CBC03A651FB678F289B9F` |
| TURTLE | `known-hosts.log` | `98F5EB6A98F4E80A0DA47D8A9ECDA313847380A775A7A350F935CB5150A52F2B` |
| TURTLE | `RUN-ENVIRONMENT.txt` | `7B924270EBD3B00A29DB00038C0D200BAFB9582429AAD549FD80E507261B2008` |

KH01.3 is target accepted. KH01.4 is the next bounded slice: deliberate
user-record removal/replacement with recovery, followed by the declared
certificate and marker policy. Complete known-host management remains open
until KH01.4 and the final KH01.5 matrix close.
