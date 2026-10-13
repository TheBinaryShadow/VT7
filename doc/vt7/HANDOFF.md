# Development handoff

Updated: 2026-10-13. Current source: **0.16.0 / native ABI 11**.

**The next step is paired SL01.3 testing on LEOPARD, NESSY, and TURTLE.**
The candidate is issued and locally checked. I have not yet recorded its
Windows 7 acceptance. This documentation cleanup changes no application code
or issued test package.

## Current candidate

| Item | Value |
| --- | --- |
| Package | `VT7-SSH-Lifecycle-SL01-3-0.2-x64.zip` |
| Local archive | [artifacts/VT7-SSH-Lifecycle-SL01-3-0.2-x64.zip](../../artifacts/VT7-SSH-Lifecycle-SL01-3-0.2-x64.zip) |
| ZIP SHA256 | `F4FC4EE844667C22F82A3A6EBE7A9D9BC136A2BC1BF149B225CFA0B9B40E174B` |
| Contents | 15,329,030 bytes; 91 files; 90 checksums |
| Application / native baseline | 0.16.0 / 0.12.3, ABI 11 |
| Local result | Twelve real SSH fault cases with paired audits, plus 32 portable regression stages, pass |
| Target result | Pending on all three Windows 7 machines |

The [SL01.3 record](validation/2026-10-12-ssh-authenticated-startup-stalls-sl01-3.md)
contains the host and manifest hashes, source provenance, local failures and
corrections, and full acceptance boundary. Candidate 0.1 was a local prototype
and was superseded before handoff.

## Next test

Use the issued package's README. The [README source](../../src/vt7/packaging/SL01-3-README.txt)
is convenient for reading the procedure; the package inventory identifies the
exact issued copy.

1. Extract into a fresh folder on each machine and run
   `RUN-SSH-LIFECYCLE-SL01-3.cmd --self-test`.
2. Prepare the separate Debian fault peer with the dedicated client **public**
   key. It uses `python3-paramiko` on the server and ports 22400-22406 at
   `10.3.3.2`. Copy only the public `client.fixture` back through a trusted path.
3. Run the Windows launcher without options. Supply the matching private-key
   path and passphrase through its prompts. Run one client matrix per server
   `serve` invocation.
4. After the client finishes, wait five seconds, stop the server with Ctrl+C,
   and pair its JSONL with that client's log using the included audit command.
   Restart `serve` before the next machine.
5. Keep the complete client Logs, matching server JSONL, and audit output for
   every run, including passes and failures. Leave the fault listeners down
   when testing is complete. The old KH01.5 listeners also stay down; ordinary
   SSH on port 22 remains available.

## Accepted baseline and remaining work

| Area | Recorded status |
| --- | --- |
| Local sessions | CMD and the qualified Windows PowerShell 5.1 / PowerShell 7.2.24 corpus pass. The viewport keyboard correction is accepted. |
| Legacy runtime | LEOPARD passes the PS2-compatible runner, CMD, typed/direct SSH, exit, typing, resize, disconnect, `htop`, and `nano` without WMF 5.1 or system OpenSSH. Its full interactive PS2 editor corpus remains unqualified. |
| Known hosts | KH01.1-KH01.5 accepted in their recorded scopes, including paired certificate evidence. |
| SSH lifecycle | SL01.1 and bounded SL01.2 accepted on all three machines. SL01.2 has 24 passing target stages and my live checks, including the unknown-key decision wait. |
| SSH limits | Hard real DNS completion/shutdown bounds, partial/stalled I/O, final drain, silent-loss policy, rekey, and nonzero remote exit status remain open. Cancellation still joins synchronous work. |
| Text and UI | UT01, UI01, and SSHUX01 are required before polish. The present dialogs and viewport/Diagnostics tabs are development UI. |
| WARP | REL01 permits continued development; it does not turn the original budget failures into passes. |

My earlier disconnect testing used **Disconnect SSH**, not a network outage.
It does not establish silent-network-loss or automatic reconnection behavior.
The missing SSH prompt glyph is U+12032, with UTF-8 bytes `f0 92 80 b2`. I also
reproduced it in an older package. It is a required UT01 fixture, separate from
the accepted SSH lifecycle results.

## Test machines and dependencies

| Machine | Relevant configuration |
| --- | --- |
| LEOPARD | Windows 7 SP1 x64, .NET 4.8, original PowerShell 2.0; no WMF 5.1 or system OpenSSH |
| NESSY | Non-ESU Windows 7 SP1 x64, .NET 4.8, Windows PowerShell 5.1; qualified PowerShell 7.2.24 |
| TURTLE | Newer-serviced Windows 7 SP1 x64, .NET 4.8, Windows PowerShell 5.1; qualified PowerShell 7.2.24 |
| WOLF | Development machine; local results do not establish Windows 7 acceptance |
| SSH server | Debian 13, `10.3.3.2:22`; isolated fault listeners only while their test is running |

The retained dependency set includes WinPTY 0.4.3 and publisher-built SSH.NET
`2026.0.1-prerelease.6`, commit `f099365c9d4cf2ade92b92c203bbb2b345d2cd74`.
That SSH.NET fix is necessary for the tested non-ESU .NET servicing level.
SL01.3 retains the accepted native, font, shim, and dependency bytes.

## Code and document map

| Work | Starting point |
| --- | --- |
| Current fault harness | [SshStartupStallChecks.cs](../../src/vt7/VT7.Host/SshStartupStallChecks.cs), [server fixture](../../src/vt7/packaging/server/VT7-SL01-3-server.py) |
| SSH transport and deadlines | [SshNetTransport.cs](../../src/vt7/VT7.Host/SshNetTransport.cs), [SshStartupDeadline.cs](../../src/vt7/VT7.Host/SshStartupDeadline.cs) |
| Session and typed handoff | [TerminalSession.cs](../../src/vt7/VT7.Host/TerminalSession.cs), [SshOverlayCoordinator.cs](../../src/vt7/VT7.Host/SshOverlayCoordinator.cs), [handoff specification](architecture/2026-09-14-terminal-document-and-ssh-handoff-spec.md) |
| Build and packaging | [BUILDING.md](../../BUILDING.md) |
| Requirements and next workstreams | [Roadmap](../../ROADMAP.md), [architecture index](architecture/README.md) |
| Prior test results | [Validation index](validation/README.md) |
| Older resumption details | [Dated handoff reference](history/2026-10-12-development-handoff.md) |

## Keeping this handoff useful

I keep the active task, issued candidate, unresolved limits, and next decision
here. Exact test results belong in their dated validation record; milestone
requirements belong in the roadmap's linked plans. Do not append the full
development history to this page again.

Preserve issued ZIPs, manifests, logs, and failed results. A documentation or
source change after issue does not update a frozen package's hashes. Record
later acceptance in the validation record instead of changing issue-time flags.
The ignored `artifacts/` directory is local evidence, not content available to
a fresh clone. See the [writing guide](WRITING.md) for the documentation style.
