# KH01.5 live host-certificate candidate

Date: 2026-10-05. Application 0.13.1, x64, native ABI 11.

Status: **target accepted on LEOPARD, NESSY and TURTLE**, 2026-10-05, using
candidate 0.2 and the paired archived Debian 13 server/client evidence below.
KH01.1-KH01.4, the two serviced Windows 7 runtime tiers and LEOPARD's
pre-WMF Command Prompt/SSH scope retain their earlier accepted results. This
candidate targets the remaining live certificate-serving evidence gap; it does
not reopen the unchanged KH01.4 mutation/recovery matrix.

## Implementation and boundaries

`KnownHostsCertificateChecks` drives the production `SshNetTransport`, the
production typed-command coordinator, WinPTY and TerminalSession. A narrowly
scoped internal loader seam supplies isolated four-source known-host snapshots.
Ordinary sessions still load the normal OpenSSH user/system files. There is no
production command-line option to replace their trust store.

The signed certificate adapter is shared with the production `HostKeyReceived`
callback. Seven cases require that real callback and the exact policy state,
reason and authenticated certificate bytes. SSH.NET rejects expired and future
certificates during signature verification, before raising the callback. For
those two cases only, an opt-in internal diagnostic observer wraps the existing
certificate algorithm factory, returning its original algorithm unchanged. It
requires the exact fixture certificate at key exchange, no callback/trust
decision, a nested `SshConnectionException` with `KeyExchangeFailed`, failed
transport/completion and no remote output. VT7's date policy is probed separately
against that observed certificate; unauthenticated observations never establish
trust. Ordinary sessions do not enable this observer. Socket, timeout and
authentication failures cannot substitute for the required rejection.

The offline corpus now includes a public session-signature vector created with
the disposable fixture host key. Tests call the pinned algorithm's actual
`VerifySignature`, require date rejection for expired/future certificates, and
reject a corrupted session signature. This exercises signature/date gates and
the decoder/policy offline; it does not establish a live network handshake.

Private-key paths, usernames and passphrases pass from the PowerShell parent to
the WPF diagnostic host through redirected anonymous stdin. They are absent
from child arguments, environment variables, files and diagnostic reports.
Passphrases use SecureString and a cleared temporary BSTR. Reports retain
bounded case labels, policy reasons, counts and a random fixture identifier;
remote terminal output is checked in memory and excluded from reports.

The target runner deliberately uses PowerShell 2.0-compatible APIs and syntax,
including strict mode 2.0 and .NET SHA256 hashing. No installed OpenSSH is needed
on Windows. Command Prompt is always tested. Only qualified Windows PowerShell
5.1 and PowerShell 7.2.24 interactive profiles join the typed certificate matrix;
other versions/missing profiles receive explicit skips. PowerShell 2.0 can run
the test wrapper without qualifying its interactive shell/editor.

The Debian fixture creates a separate Ed25519 CA and host key, six signed
certificates and nine independent certificate-only sshd listeners on high ports.
It never changes the normal port-22 service, `/etc/ssh`, the account's
authorized_keys or the Windows user's known_hosts. A small forced command
provides deterministic readiness, `stty size` and remote EOF; these sessions
do not repeat the previously accepted bash/htop/nano checks. This is an
IPv4/Ed25519 live slice, not broader algorithm or IPv6 qualification.

The following direct cases require the callback except the two date cases:

| Case | Expected VT7 result |
| --- | --- |
| Valid authority/principal/dates | Matching, `certificate-authority-match`; authenticated PTY |
| Wrong principal | PolicyRejected, `certificate-principal-mismatch` |
| Expired | SSH.NET key-exchange rejection before callback; separate VT7 probe returns PolicyRejected, `certificate-expired-or-not-yet-valid` |
| Not yet valid | SSH.NET key-exchange rejection before callback; separate VT7 probe returns PolicyRejected, `certificate-expired-or-not-yet-valid` |
| Unknown critical option | PolicyRejected, `certificate-critical-option` |
| Untrusted CA | PolicyRejected, `certificate-authority-untrusted` |
| Revoked raw host key | Revoked, `certificate-material-revoked` |
| Revoked signing CA | Revoked, `certificate-material-revoked` |
| Revoked exact certificate | Revoked, `certificate-material-revoked` |

The valid direct session checks remote output, resize to 120 columns/40 rows,
EOF and a prompt-free reconnect. Each qualified local shell then runs typed
`ssh`, reaches the certificate-backed remote PTY, exits and proves status 0 in
its original local shell. The eight negative cases use direct transport;
typed recovery uses the valid certificate case. The shared adapter/policy is
also covered by existing SSH.NET and H01 regressions.

A separate server audit proves that each rejected connection received **zero
SSH user-authentication requests**, while every accepted connection authenticated
by public key. It rejects missing connections, extra connections and mismatched
accepted counts. Only its aggregate summary is returned; raw DEBUG3 server logs
remain on Debian. Pair that summary with the client FixtureId and package hash.

## Candidate identity

### Candidate 0.1 target results and correction

All three supplied Windows 7 machines pass the offline corpus. Their live runs
share fixture `f061663f41a244a1a783e48e0b7da086` and pass the valid direct PTY
(including resize/EOF) and wrong-principal rejection. Each then fails at
`direct expired` because candidate 0.1 incorrectly demanded a trust callback
for every case. The pinned upstream implementation verifies certificate dates
before `CanTrustHostKey` raises `HostKeyReceived`. The result identifies a
harness assumption; it does not establish the remaining live cases.

| Machine | Offline run | Live run, failed at expired callback |
| --- | --- | --- |
| LEOPARD | `20261005-042432-feb6240f` | `20261005-043121-129bc906` |
| NESSY | `20261005-042450-1942e97e` | `20261005-043017-66755dc4` |
| TURTLE | `20261005-043222-ab39c0d8` | `20261005-043227-19138cd2` |

The six complete client runs and hash inventory are retained under ignored
`artifacts/vt7/evidence/known-hosts-kh01-5-win7-0.1-rejected/`. Candidate 0.1's
immutable ZIP identity below is retained as failed historical evidence.
The permanent controlled server is now Debian 13 at `10.3.3.2`; actual valid
certificate sessions establish that its fixture started. At the candidate 0.1
review, paired audits and the full corrected Windows matrix were pending;
the later candidate 0.2 review below establishes acceptance.

Application 0.13.1/candidate 0.2 corrects the evidence contract described above
and adds the offline signature/date gate regression. Production verification,
the server scripts and the live fixture schema remain unchanged. The existing
server fixture/public `client.fixture` can be reused while certificates are
valid, after resetting and restarting the fixture before each machine/retry.

### Historical candidate 0.1

Candidate: `VT7-KnownHosts-KH01-5-0.1-x64.zip`, application 0.13.0.

| Field | Verified identity |
| --- | --- |
| Review archive | `artifacts/VT7-KnownHosts-KH01-5-0.1-x64.zip` |
| SHA256 | `B3C08CE4F9D05AF1A9180B5D959E86C0F8BC0C1C3393DDD5E190CC042BECE0E0` |
| Bytes | 15,293,994 |
| Distributed files | 92, independently verified against the staged archive |
| Source base | `10bac6980`, plus recorded uncommitted input hashes |
| Target accepted | False |

It reuses the accepted `VT7-Legacy-Win7-0.2-x64.zip` closure, SHA256
`5DB55BB730A242958FDB32EF0DC6F47702BFF43883142435B2E78C27CE9E1450`.
Native ABI 11 rendering, WinPTY, shim and runtime/supplier/font assets are
unchanged. The native diagnostic build string still identifies 0.12.3; the
runner separately verifies host file version 0.13.0.0 and records host/native/
SSH.NET hashes. SSH.NET remains publisher-built `2026.0.1-prerelease.6`, upstream
`f099365c9d4cf2ade92b92c203bbb2b345d2cd74`, with the accepted non-ESU MAC fix.

The manifest records HEAD plus dirty working-source state and exact changed
build/harness input hashes. No commit/push is implied by candidate generation.
SHA256SUMS verifies the distributed inventory before the runner starts. Source
and package disclosures acknowledge OpenSSH's certificate tooling and the
integrated SSH.NET closure. No new runtime dependency, upstream code port or
license category is introduced; VT7-authored harness code remains MIT.

### Corrected candidate 0.2

Application 0.13.1. The target runner requires host file version 0.13.1.0.
The unchanged accepted native/dependency baseline and disclosures above apply.

| Field | Verified identity |
| --- | --- |
| Review archive | `artifacts/VT7-KnownHosts-KH01-5-0.2-x64.zip` |
| SHA256 | `90F1699C5DAA5388988DCD0241A28E075D4B688E252926948B203A0D26EE7DD6` |
| Bytes | 15,295,831 |
| Distributed files | 92, independently verified against the staged archive |
| Source base | `10bac6980`, plus recorded uncommitted input hashes |
| Target accepted | False |

## Local verification

- Debug and Release builds pass with the pinned Visual Studio/.NET toolchain.
- Debug/Release signed-certificate self-tests pass all nine cases, including
  exact byte read-back, all three revocation forms, the pinned signature/date
  gate, corrupted-signature and unrelated-failure controls.
- Packaged SSH.NET foundation, no-external typed-shim and H01 shell/barrier/
  fallback regressions pass on the development host. Its installed PowerShell
  7 version is outside the 7.2.24 scope and is explicitly skipped.
- The final packaged full known-host parser/loader/first-contact/writer/removal/
  certificate/differential suite also passes on the development host.
- Anonymous UTF-8 stdin and fail-closed controls pass: a valid disposable key
  against a closed loopback port cannot produce a passing live matrix; the
  sentinel username/key path/passphrase is absent from its failure report.
- Server audit tests pass for valid counts and reject authentication exposure,
  missing connections and contaminated logs; summaries exclude raw endpoints,
  usernames and keys. These tests use synthetic server logs.
- Bash syntax validation passes. Actual Debian sshd configuration validation,
  fixture startup and live key exchange are **not** established locally.
- Full portable image/import/runtime closure verification passes. ZIP entries
  match staged hashes. Packaged self-tests pass under actual PowerShell 5.1 and
  2.0/CLR 2, through CMD, and after independent extraction into a path with spaces.

These local results do not establish Windows 7 live certificate acceptance.

## Owner-controlled target procedure

Use the complete [packaged instructions](../../../src/vt7/packaging/KH01-5-README.txt).
The extracted package contains the same README.txt, Windows launchers and
`server/VT7-KH01-5-server.sh` plus its audit helper.

1. On NESSY, TURTLE and LEOPARD, extract into a fresh folder and first run
   `RUN-KNOWN-HOSTS-KH01-5.cmd --self-test`.
2. For the existing `/var/tmp/vt7-kh01-5-b` fixture, skip prepare/transfer:
   reset/start before the retry and reuse the current public `client.fixture`.
   The server scripts are unchanged and certificates remain valid for seven
   days. For a new fixture, copy the two server files to Debian. With the dedicated
   key-authenticated test account already configured, run, for example:

   ```bash
   cd ~/vt7-kh01-5-server
   sudo bash VT7-KH01-5-server.sh prepare /var/tmp/vt7-kh01-5-b 10.3.3.2 sshtest 22350
   sudo bash VT7-KH01-5-server.sh start /var/tmp/vt7-kh01-5-b
   ```

   Choose an unused nine-port range. Restrict any required firewall allowance
   to the test machines. The fixture requires OpenSSH, bash, sh, stty, python3
   and the normal `/run/sshd` privilege-separation directory. Its certificates
   last seven days; check both server/client clocks.
3. Copy only the public `client.fixture` through your trusted admin path to a
   location outside the Windows package. Do not copy the private keys directory.
4. Start the Windows CMD launcher without flags. Enter that fixture path and
   the dedicated username/private-key path/passphrase. Run **one** matrix per
   fresh server log set. No other client should connect to fixture ports.
5. Read `AcceptedConnections` in the client log and run the server audit with
   that number, for example:

   ```bash
   sudo bash VT7-KH01-5-server.sh audit /var/tmp/vt7-kh01-5-b 3
   ```

   The number is 3 for Command Prompt only, 4 or 5 with qualified additional
   shells. Save `/var/tmp/vt7-kh01-5-b/server-audit.txt` before the next audit.
   To export the root-owned summary into your ordinary account for transfer,
   use `sudo cat /var/tmp/vt7-kh01-5-b/server-audit.txt > ~/server-audit-LEOPARD.txt`
   (substitute the machine name). This exports only the safe aggregate summary.
6. Return the complete Windows Logs directory and matching server-audit.txt
   for each machine, **including successful runs**. Label each machine. If a
   run fails, return what exists rather than retrying against contaminated logs.
   Do not send private keys, credentials, raw server logs, actual known_hosts
   or the public fixture/key data.
7. Before another machine/retry, use `reset` then `start`. Reset archives the
   old raw logs. Stop the fixture when finished:

   ```bash
   sudo bash VT7-KH01-5-server.sh reset /var/tmp/vt7-kh01-5-b
   sudo bash VT7-KH01-5-server.sh start /var/tmp/vt7-kh01-5-b
   # After the final run:
   sudo bash VT7-KH01-5-server.sh stop /var/tmp/vt7-kh01-5-b
   ```

Stop targets only the fixture's verified sshd PIDs; it preserves all files.
An expired fixture is replaced by preparing a fresh directory name, without
altering the original evidence or the regular SSH service.

## Acceptance and following work

### Candidate 0.2 target evidence review, 2026-10-05

The owner supplied eight client run directories and three named server audit
exports. Originals and a hash inventory are retained under ignored
`artifacts/vt7/evidence/known-hosts-kh01-5-win7-0.2-review/`. All runs identify
application 0.13.1, host SHA256
`36C8FF30823393D0F0C3B0DC859B6E1A06CCACF456D8937DB4C07009CEAA90EB`,
the unchanged native/SSH.NET hashes and .NET Release 528049. All three self-tests
pass. Successful live runs use fixture `f061663f41a244a1a783e48e0b7da086`.

| Machine | Self-test | Successful complete live run | Client accepted count | Supplied server audit |
| --- | --- | --- | --- | --- |
| LEOPARD | `044959-1062ba3c` | `045033-7fb6b6c6` | 3 | Expected 3, actual connections/accepted 3; Passed=True |
| TURTLE | `045427-42057f70` | `045434-ffdc3cfe` | 5 | Expected 3, actual connections/accepted 5; Passed=False because the expected-count argument is wrong |
| NESSY | `044557-3be0c49d` | `045612-45395de4` | 5 | Expected 3, actual connections/accepted 5; Passed=False because the expected-count argument is wrong |

Each successful client run passes all nine direct certificate cases, including
the corrected expired/future checks, valid PTY resize/EOF, valid reconnect and
typed SSH return status. LEOPARD qualifies Command Prompt only and explicitly
skips Windows PowerShell 2.0 and missing PowerShell 7. NESSY and TURTLE each
qualify Command Prompt, Windows PowerShell and PowerShell 7, hence five accepted
connections (two direct plus three typed). Every supplied server audit shows
exactly one connection, zero user-authentication requests and zero accepts for
each of the eight rejected cases. The positive server counts also agree with
their respective client counts. No rejected-certificate authentication exposure
is present in this evidence; the two audit failure flags must remain preserved
as originally supplied rather than silently rewritten.

NESSY's first live attempt (`044653-75e9162e`) fails at `direct valid`, check
`exact live key-exchange certificate`, before any direct case is reported passed.
This means the expected certificate was absent or differed; the report does not
distinguish those outcomes or retain the underlying transport exception class.
It does not establish an expired-certificate regression or prove a network,
credential, server-startup or client fault. The later complete pass uses identical
binary hashes and fixture identity. The owner confirms reset/start before the
first attempt and between every machine; reused logs are therefore not an
explanation for this initial failure. Its cause remains unresolved, with no
automatic retry or relaxed validation introduced. If it recurs, preserve that
run and its server logs before reset for targeted investigation.

LEOPARD also has an earlier wrapper-only failure (`045005-247d794b`) at
`fixture and credential input`, without a host diagnostic report. Its subsequent
complete paired live run passes; the early input failure is retained separately.

LEOPARD's complete paired KH01.5 slice is verified. NESSY and TURTLE's complete
client matrices and server counts are verified, but their supplied audit exports
still report failure because they were invoked with 3 instead of 5. Re-audit
the corresponding preserved server log sets with **5**, not the example count
3. For the latest NESSY run, if it is still the current fixture log set:

```bash
sudo bash VT7-KH01-5-server.sh audit /var/tmp/vt7-kh01-5-b 5
sudo cat /var/tmp/vt7-kh01-5-b/server-audit.txt > ~/server-audit-NESSY.txt
```

Do not audit NESSY's current log set and label it TURTLE. TURTLE's corrected
export must use its own preserved log set. No client rebuild is needed, and a
new client matrix is unnecessary merely to correct an audit argument if its
matching server logs remain available. At this initial review, full KH01.5/the
broad known-host gate remained open pending corrected audit exports. The
subsequent mounted-server replay below supersedes that pending status while
preserving the supplied failure exports.

### Mounted archived-server audit replay and acceptance

The owner supplied the fixture mounted at `E:/var/tmp/vt7-kh01-5-b` and granted
read access. Fixture identity matches the clients. The three separate complete
log sets are identified by archive boundaries, client execution order and their
exact positive/negative counts. Before replay, only each selected log set and
the fixture identity were copied into separate local evidence roots. The mounted
fixture was not written, its keys/configurations were not copied, and the
unchanged distributed audit helper was run against those local copies with the
accepted count from the corresponding client report.

| Machine | Source archived server logs (UTC name) | Client successful run | Audit expected | Replayed audit |
| --- | --- | --- | --- | --- |
| LEOPARD | `logs-20261005T025336Z-8cad58f2` | `045033-7fb6b6c6` | 3 | Passed=True |
| TURTLE | `logs-20261005T025546Z-c423aadc` | `045434-ffdc3cfe` | 5 | Passed=True |
| NESSY | `logs-20261005T025737Z-b20a2334` | `045612-45395de4` | 5 | Passed=True |

Each replay verifies exactly the expected valid connections/accepts and all
eight rejected cases with exactly one connection, zero user-authentication
requests and zero accepted authentications. Every client verifies the matching
fixture certificates, direct resize/EOF/reconnect and typed status-zero return
for its qualified profiles. This closes the paired evidence gate without a new
client run or rebuild. The original count-3 audit exports remain unchanged.
The newer mounted `server-audit.txt` expects five but reports zero for every
case because the current `logs` directory is empty after reset; it does not
describe the successful archived NESSY run.

Replay inputs, source inventory, generated aggregate audits and hashes are
retained under ignored
`artifacts/vt7/evidence/known-hosts-kh01-5-win7-0.2-server-replay/`. Raw server
logs are kept only in that local ignored evidence area, not in source or the
distributed package. Its per-machine aggregate `server-audit.txt` files contain
no raw endpoints, usernames or keys.

The archive covering NESSY's first failure,
`logs-20261005T024900Z-641c6b9b`, contains zero entries, including with hidden
entries enumerated. The start command requires nine server log files and
`Server listening on` readiness records before reporting success. An empty
archive is consistent with fixture listeners being unavailable during that
attempt, but does not prove why they were unavailable or exclude omissions in
the supplied mount/copy. Respect the owner's confirmation that reset/start was
performed; do not claim a specific skipped command or an application fix.
The other empty archives `025344Z-b96fe2f9` and `025551Z-991e6567` and the current
empty `logs` are preserved in the inventory. The older `024057Z-d24865b5` set
contains three mixed candidate-0.1 attempts and is excluded from acceptance.
NESSY's initial failure remains recorded as an operational incident with an
unproved exact cause. No automatic retry or reduced validation is introduced.

**KH01.5 and the bounded recoverable known-host management roadmap gate are
accepted** for the declared Windows 7 tiers and IPv4/Ed25519 certificate slice.
Candidate 0.2's immutable manifest records `kh01_5TargetAccepted=false` at issue
time; this dated post-issue evidence review establishes acceptance without
rewriting the archive. Broader algorithm/IPv6/environment tests and Milestone 5
lifecycle/TUI hardening retain their separate scope. The next work is the
remaining Milestone 5 lifecycle/TUI hardening, followed by the approved pre-1.0
UI/SSH interaction work in roadmap order.

UI01 and SSHUX01 remain approved pre-1.0 work: real title-area session tabs,
conditional stable shell names and terminal-only SSH interaction. The diagnostic
fixture's automated input does not implement that final user experience.

## Primary references

- [Pinned SSH.NET CertificateHostAlgorithm](https://github.com/sshnet/SSH.NET/blob/f099365c9d4cf2ade92b92c203bbb2b345d2cd74/src/Renci.SshNet/Security/CertificateHostAlgorithm.cs)
  and [KeyExchange](https://github.com/sshnet/SSH.NET/blob/f099365c9d4cf2ade92b92c203bbb2b345d2cd74/src/Renci.SshNet/Security/KeyExchange.cs):
  certificate date/signature verification precedes the trust callback;
  verification failure reports `KeyExchangeFailed`.

- [OpenSSH sshd_config](https://man.openbsd.org/sshd_config): independent server
  configuration, HostKey/HostCertificate, certificate-only HostKeyAlgorithms,
  public-key authentication and ForceCommand.
- [OpenSSH ssh-keygen](https://man.openbsd.org/ssh-keygen): CA-signed host
  certificates, principal/date/critical-option fixtures and public-key output.
- [Pinned SSH.NET HostKeyEventArgs](https://github.com/sshnet/SSH.NET/blob/f099365c9d4cf2ade92b92c203bbb2b345d2cd74/src/Renci.SshNet/Common/HostKeyEventArgs.cs):
  raw underlying key bytes and the separately exposed decoded certificate.
- [Known-host management specification](../architecture/2026-09-21-openssh-known-hosts-management-spec.md)
  and [accepted KH01.4 record](2026-09-24-known-hosts-kh01-4.md).
