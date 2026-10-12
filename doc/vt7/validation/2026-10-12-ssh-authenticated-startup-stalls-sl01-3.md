# SSH protocol startup stalls: SL01.3 validation

Date: 2026-10-12. Application 0.16.0, native ABI 11.
Status: implemented; paired Windows 7 acceptance pending.
Design: [SL01.3 specification](../architecture/2026-10-12-ssh-authenticated-startup-stalls-sl01-3.md).
Baseline: accepted [SL01.2 candidate 0.4](2026-10-11-ssh-startup-phase-deadlines-sl01-2.md).

## Delivered behavior

The new --ssh-startup-stall-test diagnostic drives the existing production
transport against real authentication and authenticated PTY stalls. Twelve
cases exercise production deadlines, late success with shorter diagnostic
phase clocks, cancellation, explicit close, healthy-before/after connections
and typed Command Prompt category/status-255/original-PID recovery.

No production transport, dependency, trust, shim, native or font implementation
is changed by SL01.3. The additional diagnostic mode and application identity
make the candidate distinguishable. Paramiko is a server-only fault-fixture
dependency; Windows retains ordinary .NET Framework 4.8 and PS2 runner support.

## Local qualification

Debug and Release builds pass with the pinned Visual Studio/net48 toolchain.
The Debug client report in artifacts/vt7/sl01-3-local-Debug-a98cb35e passes all
twelve cases. Matching server audit replay passes after fixing the report
parser to accept the diagnostic's first-field `Surface: FixtureId=` prefix.
The original audit failure is retained; this was a helper framing mismatch,
not a client/server lifecycle failure. The client report was not modified.

The earlier Debug run in artifacts/vt7/sl01-3-local-Debug-51941e87 passes the
direct cases but its typed test lacks an initial committed local-shell readiness
barrier and times out. The final harness adds that barrier and a structured
coordinator failure notification. It does not weaken the phase, status or PID
assertions or change the production shim/transport. The failed report remains.

Observed production authentication timeout settles near 15 seconds. The PTY
timeout cleanup settles near 18 seconds with this peer; late-result and
cancel/close cases join the six-second reply. These observations do not
establish a hard overall startup/shutdown bound or immediate cancellation.

The local-only candidate 0.1 passes all twelve real cases and the matching
server audit under artifacts/vt7/sl01-3-local-Release-378469d3. This includes
actual encrypted SSH negotiation with Paramiko 3.5.1 on loopback, authenticated
PTY callbacks, natural holds, closed workers and healthy-before/after completion.
It is local WOLF evidence, not a Debian/Windows 7 target result.

Candidate 0.1 passes all 32 portable regression stages (retained prototype evidence):

| Engine | Run under artifacts/vt7/packages/VT7-SSH-Lifecycle-SL01-3-0.1-x64-local-logs |
| --- | --- |
| PS5.1 | PS5/ssh-lifecycle-sl01-3-20261012-064815-cd248d4b |
| PS2 | PS2/ssh-lifecycle-sl01-3-20261012-064857-4a4f14d6 |
| CMD | CMD/ssh-lifecycle-sl01-3-20261012-064938-23faf4e1 |
| Fresh extraction, PS2 | extracted-PS2/ssh-lifecycle-sl01-3-20261012-065020-2fd10398 |

Known-host/oracle and H01 regressions pass under artifacts/vt7/sl01-3-regressions,
in known-hosts-kh01-20261012-045247-87f158e2 and h01-20261012-045246-7052e628.
The oracle remains ssh-keygen.exe 9.5.5.2, SHA256
2A0D971F935813E324519BCE64E7EB5AF85A5F91517C916270A4368E0786F588.

One positive and seven negative paired-audit checks pass. Missing client PASS
assertions, wrong fixture identity, absent server close, early server stop,
shortened hold, missing authenticated PTY events and unjoined server workers are rejected. The local
audit harness is artifacts/vt7/sl01-3-audit-negative.py.

Candidate 0.1 is superseded before handoff. Final review found that the fixture
joined its protocol thread for 20 seconds but recorded `closed` without checking
whether the thread had actually stopped. Candidate 0.2 records/rejects unsettled
protocol or fixture workers. It changes the server helper, README and provenance;
the compiled host and client runner remain byte-identical to candidate 0.1.
Final candidate 0.2's twelve-case staged Release matrix and stronger paired
server audit pass under artifacts/vt7/sl01-3-local-Release-final-a7aa6663.

The real PS2 live runner with a generated encrypted fixture key passes all nine
stages and the paired twelve-case audit under artifacts/vt7/sl01-3-local-PS2-e34f855d,
Logs/ssh-lifecycle-sl01-3-20261012-065626-4617d4ac. No synthetic passphrase appears
in its report. An artifact-only wrapper supplies generated Read-Host inputs;
the shipped runner uses its normal prompts and credential pipe. Earlier wrapper
failures in sl01-3-local-PS2-52ddf17f and sl01-3-local-PS2-912f85a9 are retained:
the local wrapper first tried redirected input and then used script-scoped
variables across a called-script boundary. These failures did not alter the
shipped runner or client. The final wrapper uses explicit synthetic inputs.

## Candidate identity and provenance

Archive: artifacts/VT7-SSH-Lifecycle-SL01-3-0.2-x64.zip.
SHA256: F4FC4EE844667C22F82A3A6EBE7A9D9BC136A2BC1BF149B225CFA0B9B40E174B.
Size: 15,329,030 bytes; 91 files, with 90 inventoried checksums.
Managed file version: 0.16.0.0. Native baseline: 0.12.3/native ABI 11.
Host SHA256: F161F31F9E130C957FCC861600D686EA902F2201AE44A3B003623294A34BB556.
Manifest SHA256: 13ECDE3EFA0FE3E8ED723EFDC92796CB7E271A2ECBA069314B19E954D74E7300.

The ZIP entry hashes match staging and the review copy matches the packaged
archive. All 83 retained baseline assets are byte-identical, including native,
fonts, shim, WinPTY/CRT and the thirteen-package pinned SSH.NET closure. Four
retained entries change: host, host PDB, README and manifest. Earlier runner
files are replaced in the new stage; the new server helper is added. The old
issued archives and original failures remain intact.

All 21 issue-time source inputs match the final working implementation. Six
critical production/session/coordinator/legacy diagnostic source hashes also
match accepted SL01.2's manifest. Package review is retained in
artifacts/vt7/sl01-3-package-review-0.2.json. The immutable candidate manifest records
sl01_3TargetAccepted=false; do not rewrite it after target qualification.

## Final candidate 0.2 qualification

All 32 final portable stages pass. Logs are under
artifacts/vt7/packages/VT7-SSH-Lifecycle-SL01-3-0.2-x64-local-logs:

| Engine | Run |
| --- | --- |
| PS5 | PS5/ssh-lifecycle-sl01-3-20261012-070015-87c8efd2 |
| PS2 | PS2/ssh-lifecycle-sl01-3-20261012-070056-9982ac81 |
| CMD | CMD/ssh-lifecycle-sl01-3-20261012-070137-ebb8e363 |
| extracted-PS2 | extracted-PS2/ssh-lifecycle-sl01-3-20261012-070220-64a1bd70 |

## Target procedure and boundary

Use candidate 0.2's README. Run RUN-SSH-LIFECYCLE-SL01-3.cmd --self-test first.
Prepare the separate Debian fault peer using the dedicated client PUBLIC key,
start its foreground listeners at 10.3.3.2:22400-22406, and transfer its PUBLIC
client.fixture to Windows by a trusted path. Then run the launcher without an
option; give the matching private key path and passphrase through its stdin
prompt. No server password or real test-user OS shell is involved.

Run one client matrix per serve invocation. After completion, wait five seconds
before Ctrl+C. Restart serve for each machine; prepare a separate fixture only
for a different client public key or an expired fixture. Pair each client
ssh-startup-stall-test.log with the corresponding server JSONL through the
included audit command. Return complete client Logs, server JSONL and audit
stdout even on success. Leave these fault listeners and KH01.5 listeners down
after testing; ordinary sshd on port 22 remains available.

Acceptance requires paired twelve-case results on LEOPARD, NESSY and TURTLE.
PowerShell 2.0's full interactive editor corpus remains unqualified. Hard real
DNS return bounds, partial/stalled I/O, final drain, silent-loss policy, rekey
and nonzero remote exit status remain open. UT01/UI01/SSHUX01 remain required.
