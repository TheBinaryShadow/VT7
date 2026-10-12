# SSH startup phase budgets: SL01.2 validation

Date: 2026-10-11. Application 0.15.0, native ABI 11.
Status: bounded SL01.2 accepted on LEOPARD, NESSY and TURTLE.
Design: [SL01.2 specification](../architecture/2026-10-11-ssh-startup-phase-deadlines-sl01-2.md).
Accepted baseline: [SL01.1 candidate 0.4](2026-10-05-ssh-lifecycle-sl01-1.md).

## Delivered behavior

Owned 15-second phase clocks now cover automatic startup. The public server
identification and trusted host-key callbacks advance the network phases;
unknown-key/changed-key human decisions suspend those clocks while preserving
caller cancellation. The existing SSH.NET 15-second connection timeout remains.
Failures report fixed phase timeout categories, without raw server or credential
exceptions. Timeout and explicit cancellation retain the original typed shell
and return status 255. No startup clock remains armed for an active session.

Expiry cancels token-aware work and rejects late results. Synchronous resolver,
local-file and pinned-library operations remain owned and joined. Thus the phase
budget does not establish a hard 15-second return/shutdown limit. Trust-file
mutation retains its existing atomic, authorized transaction contract; expiry
does not undo an already committed addition.

Candidate 0.1 is local-only and superseded before handoff. Review found that a
trusted rekey callback during authentication/channel startup should retain the
current phase deadline, rather than be rejected for failing to advance it again.
Candidate 0.2 preserves normal trust policy for those callbacks and prevents
them from extending the phase. It is also local-only and superseded: candidate
0.3 caches the watchdog token so an in-flight callback retaining the watchdog
across Running/teardown cannot read CancellationTokenSource.Token after disposal.
The policy diagnostic checks retired-token access. These review corrections
are not evidence of a sustained-output rekey qualification.

The unissued 0.3 stage passes its startup checks, then fails the older
no-external-client fixture's missing-rejection-text assertion. The broker
had returned the correct rejection and the shim returned 255; the fixture
exited its parent Command Prompt before waiting for the shim's stderr to be
captured by WinPTY. Candidate 0.4 waits for the actual rejection marker to
commit before issuing that exit. It retains the status and message assertions,
uses a watchdog, and changes no production transport or shim for this fix.
The original failure is retained under the 0.3 local-logs/PS5 directory.

## Local evidence and limits

The --ssh-lifecycle-test runs real pinned-library silent-identification and
stalled-KEX peers with shortened phase budgets and longer library operation
limits. Expiry reports ConnectionFailure, joins startup and emits no terminal
bytes or late Running state. A typed Command Prompt silent peer also exercises
the production limits and verifies status 255 and original root PID.

An injected resolver that ignores cancellation is deliberately kept pending:
close/startup must remain incomplete until it releases, then reject its late
answer before constructing a client. Both expiry and caller cancellation pass.
A slow synchronous known-host loader similarly cannot start networking after
its result arrives late. Deadline policy covers local credential, authentication,
PTY and durable-update expiry, pause/cancellation, phase transition and stale
callback behavior. These seams are not real OS DNS or authenticated-server stalls.

The earlier SL01.1 cancellation, idempotent close, faulted outbound, pending
window/session close and typed refusal/cancellation checks remain. The local
PowerShell corpus runs Command Prompt and Windows PowerShell 5.1; development
PowerShell 7.6.5 is explicitly skipped because 7.2.24 is the qualified version.

Debug and Release builds pass. The final candidate passes the image/import
audit and all eight portable stages on PS5.1, PS2, CMD and an independently
extracted path with spaces: 32 passing stages. ZIP entry hashes match staging,
and the review copy matches the packaged archive. Compared with accepted
SL01.1, only the managed host/PDB, README, manifest/checksums and runner files
change; all other inventoried assets match byte for byte. Exact manifest source
hashes matched the working tree at issue; later acceptance documentation does
not rewrite that manifest.

Final Debug lifecycle evidence is
artifacts/vt7/sl01-2-debug/ssh-lifecycle-issue-0.4.log. It passes, including
retired-token access and production-limit typed timeout recovery. Final Release
known-host/oracle and full H01 regressions also pass under
artifacts/vt7/sl01-2-regressions-final/known-hosts-kh01-20261011-045058-ee67f0fa
and h01-20261011-045059-1e21c046. The oracle remains ssh-keygen.exe 9.5.5.2,
SHA256 2A0D971F935813E324519BCE64E7EB5AF85A5F91517C916270A4368E0786F588.

Final candidate logs are under
artifacts/vt7/packages/VT7-SSH-Lifecycle-SL01-2-0.4-x64-local-logs:

| Engine | Run directory |
| --- | --- |
| PS5.1 | PS5/ssh-lifecycle-sl01-2-20261011-064633-b509d95c |
| PS2 | PS2/ssh-lifecycle-sl01-2-20261011-064715-8edd4156 |
| CMD | CMD/ssh-lifecycle-sl01-2-20261011-064757-fed2ba81 |
| Fresh extraction, PS2 | extracted-PS2/ssh-lifecycle-sl01-2-20261011-064839-c0883d8d |

The full hard resolver bound, real stalled authenticated authentication/PTY,
partial/stalled I/O, final-output drain, silent blackholes, rekey under output
and nonzero remote exit status remain open. UT01/UI01/SSHUX01 remain required.

## Candidate identity

Candidate: artifacts/VT7-SSH-Lifecycle-SL01-2-0.4-x64.zip.
SHA256: AAF77183BF54BA323EC543D9871C575C2EC932DBF3A152370200BCAAA0B1B105.
Size: 15,314,513 bytes; 90 files, with 89 inventoried checksums.
Application file version: 0.15.0.0. Native baseline: 0.12.3/ABI 11.
Baseline archive: SL01.1 candidate 0.4, SHA256
0942D0DFD3B67570FB4F78CE724A7FD4940736EEDE83819EAE47456833C1FDFC.
The native/font/shim/WinPTY/CRT/thirteen-package SSH.NET closure is unchanged.
Native SHA256: E5FFE6399442E1599C59F94FC64A7E063C9A3B78289AAECFD1E8450267B63EB5.
SSH.NET SHA256: 7CC4CDE2A70E64748F266A86C843119C045BDDA8A56A87CB065CC1282B05D64B.
Exact source hashes and unaccepted target status belong to the immutable
issue-time manifest; do not rewrite it after target testing.

## Target procedure

Extract candidate 0.4 into a fresh directory on LEOPARD, NESSY and TURTLE.
Run RUN-SSH-LIFECYCLE-SL01-2.cmd and return each COMPLETE Logs directory,
including on a clean run. Eight stages need no Debian listeners, client.fixture,
credentials or installed system OpenSSH. The runner works on PowerShell 2.0.

Then follow the included README with ordinary 10.3.3.2:22 SSH: typed/direct
paths, sequential connections, normal exit, explicit disconnect, htop/nano,
typing/resize/scrollback and window close while connecting/active. Confirm the
original local prompt and status 0 for normal exit, 255 for cancellation/failure.
Where a dedicated-host trust decision appears naturally, wait over 20 seconds,
then cancel/retry or verify/connect. Record if skipped because the key is already
known; do not remove trusted records to manufacture this test.

No KH01.5 fixture cleanup/start is required; leave its listeners down. Ordinary
sshd on port 22 remains available. No network-loss bound is claimed. LEOPARD's
PowerShell 2.0 interactive editor remains unqualified. Target acceptance requires
reviewed logs and ordinary live observations. That review is complete below.

## Accepted Windows 7 results

All eight stages pass on each returned target (24 passing stages). Each run
identifies Windows 7 SP1 x64, .NET Framework Release 528049, application 0.15.0,
native ABI 11 and 89 verified package files. Host, native, SSH.NET and manifest
hashes match the issued candidate 0.4. All seven SL01.2 deadline assertions pass
on each machine, including the production-limit typed Command Prompt timeout,
original-shell PID preservation and status 255 recovery.

| Machine | Runner PowerShell | Returned run |
| --- | --- | --- |
| LEOPARD | 2.0 | ssh-lifecycle-sl01-2-20261011-065541-8e9a20d3 |
| NESSY | 5.1.14409.1018 | ssh-lifecycle-sl01-2-20261011-065558-06e23ce0 |
| TURTLE | 5.1.14409.1005 | ssh-lifecycle-sl01-2-20261011-070436-958287e5 |

Command Prompt refusal/cancellation recovery passes on all three machines.
Windows PowerShell 5.1 and qualified PowerShell 7 recovery pass on NESSY/TURTLE.
LEOPARD correctly skips the unqualified PowerShell 2.0 interactive editor corpus
and absent PowerShell 7. Its PowerShell 2.0 runner completes all eight stages.

The owner confirms that every README live check passed without issues on all
three machines: typed/direct connection, normal exit, explicit disconnect,
reconnect, htop/nano, input/resize/scrollback and window closing. The server key
was unknown, so the over-20-second host-trust decision check was exercised,
rather than skipped. These observations accept normal operation and human
decision suspension on the ordinary Debian server at 10.3.3.2:22.

The 33 original files, including three inspected window-smoke PNGs, are retained
under artifacts/vt7/evidence/ssh-lifecycle-sl01-2-win7-0.4-review/Logs.
SHA256SUMS.txt verifies every archived copy; REVIEW.json records identities,
assertions, skips and owner observations. Text evidence contains no detected
private-key blocks, GitHub token patterns or SL01_PRIVATE_SENTINEL. Screenshots
contain the static diagnostic sample. The runner's LiveAccepted=False and the
issue-time manifest are preserved; this later record supplies live acceptance.

Host SHA256: 6ECE1C79334E842F3C555B19F477E7244887B31CAD920147C5A2E3E1BEB7FB20.
Manifest SHA256: 95C346B86DF50D73D05CB7C544A0C698AB3C8C855FD7F4B37C5F3A6C21F40DB9.

Only bounded SL01.2 is accepted. Hard OS resolver return/shutdown bounds and
real stalled authenticated authentication/PTY remain unqualified. Partial/stalled
I/O, final-output drain, silent loss/keepalive policy, rekey under output and
nonzero remote exit status remain open under the parent lifecycle gate.
