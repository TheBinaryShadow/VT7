# VT7 development handoff

Updated: 2026-09-14, after accepting SSH.NET S01 and recording the project-wide
permissive dependency policy.
This is the current resumption guide. Start with the [documentation index](README.md)
if unfamiliar with the repository. The [roadmap](../../ROADMAP.md) owns gates;
dated validation records own test claims.

## Where we are

VT7 is an independent MIT-licensed Windows 7 SP1 x64 terminal application port.
Keep new VT7-authored code MIT licensed where possible. The owner's standing
2026-09-14 decision permits compatible permissive dependencies and assets,
including Apache-2.0, ISC-style, BSD-style and broader supplier notices, when
they help deliver the port. Record exact provenance and retain every required
notice. A materially restrictive, source-sharing, network-use or proprietary
term still requires a separate compatibility review. The
[standing licensing policy](architecture/2026-09-14-third-party-licensing-policy.md)
owns this decision. `NOTICE.md` now combines legal disclosure, upstream
references and human thanks.
The current application streams a deterministic UTF-8/VT fixture through a
bounded session output queue into the TerminalCore-backed Atlas viewport inside
a .NET Framework 4.8 WPF host. It has no interactive local shell, SSH session,
production tabs/panes/profiles, selection or session-input implementation yet.
The visible viewport/Diagnostics tabs belong to the proof host, not the finished
multi-session UI. Planned PowerShell 7 coverage through 7.2.24 is not a tested
VT7 session claim.

Port first. Preserve pinned upstream behavior wherever possible and adapt the
Windows 7 boundaries. Required correctness, security, accessibility and resource
lifetime are blockers when affected; optional typography and refinements belong
in Milestone 7. The owner-approved
[WARP development deferral](architecture/2026-09-14-warp-development-deferral.md)
moves the known resource concern to REL01 release-readiness review and stops
the dedicated tracing campaign. C4/3A is active; its first shared output
boundary is implemented and S00 has rejected redirected external OpenSSH for
interactive PTY sessions.
Neither WARP attribution nor
the earlier Arabic/geometry experiment chain is the default next task.

| Item | Current state |
| --- | --- |
| Working application version | 0.3.7, native ABI 10, x64. The latest issued full viewport artifact remains 0.3.5/ABI 8; the focused 0.3.7 target candidate has a distinct identity. |
| Milestone 1 | Complete on the tested configurations, with the evidence limits in its record. |
| C1 minimum font boundary and C2 Atlas integration | Accepted on the supplied Windows 7 setup in 0.3.0. |
| C3 repaint, controlled recovery, scaling | Bounded 0.3.1/0.3.2 results and actual 0.3.4 96/120/144 DPI matrix accepted. |
| C3 scheduling/resource lifetime | Test failures preserved; further WARP tracing stopped and deferred as REL01. Quick hardware/WARP and hardware 100-cycle lifecycle pass on both setups. This concern no longer blocks feature development; final qualification is incomplete. |
| Timed soak | Not run on either setup. No immediate request; sustained-use qualification belongs with the assembled product and REL01 review, without requiring complete attribution first. |
| Latest resource target diagnostic | WPF reactivation 0.1 completes both 100-lifecycle rounds and all 16 checkpoints in 655.156 seconds, retaining three immediate budget failures. Both +180s states have 1,314 handles, 13 threads, GDI 18 and USER 10; private bytes rise by 220 KiB. |
| Remaining lifetime question | The two late integrated counts repeat, but individual handle identities/owners and a permanent bound are unproven. Final WPF handles remain 1,090 above pre-warm-up; this includes initialization and diagnostic effects. The previous native-only residual is 54 and is not directly comparable. |
| Latest local diagnostic | WPF resource reactivation 0.1 completes two 100-lifecycle batches and closed +10/+90/+180s observations after each, in one process. All 16 checkpoints validate and all eight immediate budget failures remain. The native 0.3.5 DLL is unchanged. |
| Session stream foundation | Implemented and locally validated in Debug and Release. Ordered transport-thread output reaches a per-surface decoder and TerminalCore through a bounded dispatcher queue; incomplete EOF and recovery are explicit. |
| Session ownership review | The supplied pushed-commit analysis was reconciled with the current tree. UTF-8 streaming and P01 are already complete; the remaining architecture requirement is to separate production session/TerminalCore identity from HWND/WPF presentation identity, with generation-safe callbacks and two-sided core/backend resize. |
| P01 WinPTY characterization | Complete. The official 0.4.3 native x64 artifacts are pinned. Debug, Release and all eighteen Windows 7 package 0.3 cases complete with verified evidence. WinPTY is selected for Windows 7 local legacy-console sessions behind the replaceable session boundary; raw VT, code-page, cursor-width and intermediate-state limits are explicit. |
| P01 target package | `VT7-WinPTY-P01-0.3-x64.zip`, SHA256 `6DD8560EDE4B4FEE9CCA3BC972F0437DAD216D9D0FE168E29989D96012CFDBCF`, 959,977 bytes, 15 verified files. Same-hash copy at `K:\VT7_work\VT7-WinPTY-P01-0.3-x64.zip`. Its complete target run has 109 files and 1,062,782 bytes. |
| I01 input characterization | Complete for the Windows 7 Croatian HR Latin 3A decision. Both controls receive required Croatian/AltGr text. Flags 1 and 5 both mutate `ToUnicodeEx` dead state. Native key/character, focus and resize ordering define the input adapter contract; broader layouts, printable repeat and IME remain in 3C. |
| I01 target package | `VT7-Input-I01-0.2-x64.zip`, SHA256 `45E730BDB00A27D3A42B6A61AB9A302E42CA118C18359B3364022B0CA75FF7E8`, 355,069 bytes, 13 verified files. Same-hash copy at `K:\VT7_work\VT7-Input-I01-0.2-x64.zip`. Its completed target run has 4 files and 354,713 bytes. Package 0.1 is a rejected local runner candidate and was not issued. |
| Session outbound 0.3.7 | Implemented and validated in Debug/Release and on the exact Windows 7 SP1 x64 candidate. ABI 10 encodes native-HWND committed/non-text input through TerminalInput without live-thread layout translation. One bounded generation queue orders bytes, Interrupt/Break, focus and the native authoritative resize. |
| Session outbound target package | `VT7-Session-Outbound-0.3.7-x64.zip`, SHA256 `1762520CD18A63E5A7BD30C7708658DA92B195830A3D68282A83FB21A4360CFC`, 10,560,527 bytes, 26 verified files. The accepted run has 2 files and 2,807 bytes; its host/native hashes match the package. |
| S00 OpenSSH evaluation | Complete. Preflight and controlled Debian cases accept exact Microsoft 10.0p2 x64 `ssh.exe` command bytes, strict trust, key authentication, negotiation, drain and cancellation. Forced PTY reports 0 by 0. Exact source proves its Windows geometry path requires console output and input events that VT7's redirected pipes cannot supply. External OpenSSH is accepted for non-PTY command transport and rejected for interactive VT7 SSH. |
| S00 preflight package | `VT7-OpenSSH-S00-Preflight-0.2-x64.zip`, SHA256 `1F8FE67D0E388D82248B6383035BE03E848D8FB3E71F85EE27C297ADF4149395`, 12,248 bytes, 8 verified files. It contains no OpenSSH binary. Both complete target runs are archived byte-identically as 44 files and 35,558 bytes. |
| S00 network package | Issued 0.1 is `VT7-OpenSSH-S00-Network-0.1-x64.zip`, SHA256 `8029CC9CF48F9BAEA839F16F3E104A552F848AB17A4A12636C966145B421B7FA`, 16,203 bytes, 8 verified top-level files. Its complete target run has 16 files and 149,987 bytes. The changed-host diagnostic retained a public host fingerprint and temporary profile path despite its privacy claim; raw evidence is restricted and a safe copy is archived. Corrected source advances any reissue to 0.2. |
| S01 candidate | Accepted. The isolated [SSH.NET 2026.0.0 diagnostic](validation/2026-09-14-sshnet-s01.md) passes its exact locked thirteen-package net48 closure and both Windows 7 controlled-Debian runs. Product incorporation has not started. |
| S01 target package | Accepted `VT7-SSHNET-S01-0.6-x64.zip`, SHA256 `7200827585B88E337AC3CD2074DDF34D1E6B5EF433A4FD4A305395DBF869292E`, 3,258,501 bytes, 62 verified files. Public-key-only and optional-password runs both pass; no credential fields are retained. The three sanitized manifests and verification metadata are archived under `artifacts/vt7/evidence/sshnet-s01-win7-0.6`. |
| Next bounded task | Complete the 3A session-identity/lifetime split and security contracts, carrying S01's stream-dispose-before-client-disconnect rule into the production design. No S00/S01 rerun or WARP attribution test is a prerequisite. |
| Milestone 2 | Open. Theme/high-contrast, broader device/environment and milestone-level ESU coverage also remain. |
| Development sequence | Complete the session-identity split before 3B, then integrate production local and remote transports under the accepted P01/S01 boundaries. Remaining C3/Milestone 2 qualification stays recorded without a blanket serial dependency. |

## Resume safely

1. Read this file, the [current validation record](validation/2026-09-13-atlas-stability.md),
   and the [port-first plan](architecture/2026-09-12-port-first-plan.md).
2. Inspect `git status --short`, `git branch --show-current` and `git log -1`.
   The user's development branch is `initial-implementation-and-assessment`.
   Do not switch branches, discard changes, merge upstream or commit/push merely
   as a resumption step. Preserve unrelated work.
3. The 0.2 diagnostic source base is `928c4581e3747d622ebcd43cf36206125b623102`
   with uncommitted diagnostic additions. The build manifest hashes the actual
   source/header snapshots; HEAD alone does not identify them. Record the actual
   commit and dirty state for later builds.
4. Locate or obtain the exact issued binaries if reproducing an old result.
   `artifacts/` and the tester's `K:/VT7_work/` paths are not cloned with Git.
   Use hashes below; never infer a match from the filename or version alone.
5. Review build scripts before packaging. The current package helper replaces
   its fixed 0.3.5 directory and ZIP. Do not run it over retained evidence.
   The 0.3.7 source has a focused issued target candidate, not a complete application package. A later full candidate
   needs a new artifact identity and paths that preserve old evidence.

## What 0.3.7 changed

- ABI 10 adds key, committed-character and focus encoding calls against the same
  TerminalInput state updated by output parsing. Non-text key metadata uses a
  no-layout entry point and cannot mutate Windows 7 dead-key state.
- `SessionOutboundQueue` admits at most 256 pending operations, assigns one
  generation and monotonic sequence, rejects stale/closed/full admission,
  drains accepted work on completion and coalesces only consecutive resizes.
- `NativeHwndInputAdapter` owns terminal input only at the child HWND. It emits
  OS-committed UTF-16 once, keeps Interrupt and Break distinct, suppresses paired
  ETX/Enter/Tab/Backspace characters, and reconciles tracked modifiers on focus
  loss.
- Native resize publishes the exact post-`UserResize` grid; the host coalesces
  it once. WPF dimension events never become PTY resize operations.
- `Test-VT7SessionOutbound.ps1` passes locally in Debug and Release, as do the
  existing session-stream regressions and static PE/import checks. The exact
  target package passes its hash-verifying `cmd.exe`/Windows PowerShell 5.1
  launcher from a path with spaces. Its returned Windows 7 SP1 x64 run also
  passes the bounded queue, native input/resize, TerminalCore, stream and font
  checks with exact package host/native hashes.

See the [session outbound foundation](architecture/2026-09-14-session-outbound-foundation.md).
The backend remains an audit sink. TerminalCore/session identity is not yet
separate from the HWND-backed surface, and no shell or SSH transport is wired.

## What 0.3.6 changed

- ABI 9 adds begin/write/end/status calls for a per-surface UTF-8 byte stream.
  The native decoder uses inherited `til::u8u16` state and feeds the existing
  TerminalCore parser without joining or rewriting transport chunks.
- `SessionOutputPump` copies ordered chunks from any producer thread into a
  16-slot queue with a 64 KiB chunk limit, giving 1 MiB maximum queued output
  at full chunk size. Native HWND calls remain on the surface dispatcher.
- Completion stops admission, drains accepted output and then delivers EOF.
  Incomplete UTF-8 at EOF returns `ERROR_NO_UNICODE_TRANSLATION`; writes after
  EOF fail; a new generation clears decoder/terminal state and recovers.
- Normal startup now shows a streamed Croatian HR Latin and VT fixture. Existing
  renderer regressions still use the deterministic static demo through reset.
- `Test-VT7SessionStream.ps1` compares the exact rendered raster for one chunk,
  388 one-byte writes and irregular chunks, then verifies incomplete EOF,
  recovery and HWND destruction. Debug and Release pass locally. Release static
  verification and the established Debug six-renderer viewport matrix pass.

The detailed contract, evidence and remaining limits are in the
[session stream foundation](architecture/2026-09-14-session-stream-foundation.md).
The application source does not yet instantiate the selected WinPTY backend or
implement OpenSSH or terminal replies. Input and resize now have the 0.3.7
backend-neutral queue boundary.

## P01 WinPTY diagnostic

P01 pins the official WinPTY 0.4.3 MSVC 2015 bundle, source tag commit
`3e1ab962d5262dd76159870c6dc0724927ca6a9d`. The archive SHA256 is
`35A48ECE2FF4ACDCBC8299D4920DE53EB86B1FB41E64D2FE5AE7898931BCEE89`.
The exact x64 DLL and agent hashes, license, architecture/import audit and test
design are in the [P01 validation record](validation/2026-09-14-winpty-p01.md).

`VT7.WinPtyFixture.exe` writes through WriteConsoleW, WriteConsoleOutputW,
WriteConsoleA, WriteFile, raw VT, rapid rewrites, alternate buffers, resize and
an exit-drain workload. It records actual console cells through a side file.
`VT7.WinPtyProbe.exe` retains WinPTY bytes and feeds each read through the ABI 9
decoder class into TerminalCore. `Test-VT7WinPty.ps1` normalizes console
lead/trail duplication for semantic comparison while preserving exact cells.

Debug and Release pass locally. All reconstructed streams are valid UTF-8 and
fully drained; dimensions and legacy attributes match in every case. The local
Windows 10 baseline records two narrow fidelity limits: unprocessed ESC cells
reconstruct as literal question marks, and a supplementary console glyph becomes
U+FFFD with a cursor-width difference. Only one of 200 fast rewrite states is
observed, but the final state matches. Both alternate/primary markers, the 100 by
30 resize and all 500 exit-drain lines survive.

The first Windows 7 attempt used package 0.1 and failed in its batch launcher
before creating `Logs`: quoted `%~dp0` ended in a backslash, causing Windows
PowerShell 5.1 to receive an illegal trailing quote in `BinaryDirectory`.
Package 0.2 changed only the launcher path form to `%~dp0.` and added a test-only
no-pause environment switch. Its Windows 7 run passed five cases, then
`SetConsoleOutputCP(932)` returned `ERROR_INVALID_PARAMETER` (87). The harness
incorrectly treated that target capability result as a fixture failure and
stopped. The 33 returned files are verified under
`artifacts/vt7/evidence/winpty-p01-win7-0.2/`.

Package 0.3 records requested/actual output code pages, `IsValidCodePage`, the
set result and exact error. An unavailable page sends no incorrectly mapped
bytes and the matrix continues. Both Debug and Release pass locally, as does an
invalid-code-page negative control. The exact shipped ZIP passes all eighteen
cases and the negative control from a path with spaces through `cmd.exe` plus
Windows PowerShell 5.1.

The complete target run is
`artifacts/vt7/evidence/winpty-p01-win7-0.3/winpty-p01-20260914-060948-29e797c8/`:
109 files and 1,062,782 bytes on Windows 7 SP1 x64 with `hr-HR` culture. All
children exit zero, all agents signal, all streams drain with valid UTF-8, and
all dimensions and legacy attributes match. Sixteen cases have ordinally equal
text. Both raw-VT cases differ because the legacy console stores ESC as NUL and
Windows 7 rejects `ENABLE_VIRTUAL_TERMINAL_PROCESSING` with error 87. CP932 is
valid but the console rejects `SetConsoleOutputCP(932)` with error 87. Five
cases have bounded cursor differences; resize, alternate-buffer and 500-line
exit-drain behavior pass.

The package's PowerShell `-cne` comparison ignored embedded NUL, so its two raw
`textEqual` fields are overly optimistic. `INDEPENDENT-ANALYSIS.json`, SHA256
`3E71AD551C519D93B461EEE4D21DEFC4768CE59021F04069391FF055F2D7156E`,
recomputes ordinal equality. Source now uses `StringComparison.Ordinal`; the
retained strings make another target run unnecessary.

P01 selects WinPTY 0.4.3 for Windows 7 local legacy-console applications behind
the replaceable session boundary. Do not describe it as lossless raw-VT
transport. Direct SSH remains a separate byte path.

## I01 input diagnostic

I01 package 0.2 combines an automatic native layout/encoder probe with a guided
.NET Framework 4.8 WPF and child-HWND focus recorder. The native side compares
Croatian HR Latin `ToUnicodeEx` flags 1 and 5 on separate threads, then exercises
the inherited `TerminalInput` encoder. The interactive side records controlled
Croatian, AltGr, dead-key, repeat, Ctrl+C, Ctrl+Break, focus and resize events
at both WPF and native boundaries. It does not launch a process backend or send
input outside its own window.

Debug and Release smoke runs pass locally. Release records 158 mappings, 30
AltGr mappings, a layout dead key and 25 encoder cases. The exact package ZIP
passes its batch entry point after extraction beneath a path with spaces under
Windows PowerShell 5.1. Package 0.1 exposed a result-hashing command-discovery
failure in that exact launcher test and is rejected; 0.2 uses an in-process
SHA-256 implementation.

The Windows 7 interactive run completes with zero validator issues, 772 event
records, 158 Croatian mappings and 30 AltGr mappings. Both controls contain the
required Croatian and AltGr text. `ToUnicodeEx` flags 1 and 5 both leave the dead
key active, so the documented Windows 10 bit-2 behavior is unavailable. Ctrl+C
and Ctrl+Break each arrive as a distinct native keydown followed by U+0003;
there are 32 focus events and three native sizes. No native printable-A repeat
was recorded, so that ordinary behavior remains in 3C rather than forcing an
unchanged compatibility rerun.

The native child HWND now owns terminal focus input. Its OS-generated committed
text path supplies printable/composed UTF-16 once; native key metadata supplies
non-text and control distinctions. The adapter correlates handled control keys
with their following character, reconciles modifiers on focus loss and sends
one coalesced native-grid resize. The exact identity, evidence and decision are in the
[I01 validation record](validation/2026-09-14-input-i01.md).

## What 0.3.5 changed

- Renderer timer deadlines are read under the core lock and the lock is released
  before waiting. The pinned synchronized-output timeout policy remains intact.
- A hidden presentation worker parks and acknowledges pause instead of exiting.
- Final close pauses rendering, completes native HWND destruction on its owner
  thread while the presentation worker still exists, then releases graphics on
  that worker, joins it and deletes the surface. Do not restore worker-exit-before-
  HWND-destruction ordering from an older research proposal.
- ABI 8 supplies scheduling counters and capture-only fixtures. The tests cover
  synchronized-output end/missing-end, parked redraw/timer wakes, hidden output,
  resize/tab churn and disposal from several states.
- This corrected the locally reproduced per-window `DwmDxBltEvent_*` retention.
  It did not solve the remaining integrated WARP resource growth.

The precise implementation, regression scope and chronology are in the
[stability record](validation/2026-09-13-atlas-stability.md). None of this changed
the [upstream baseline or merge policy](../../UPSTREAM.md).

## Findings that must not be lost

1. Integrated 0.3.5 WARP completes its operations without the recorded pixel
   mismatch or hang but fails the resource-growth verdict. Hardware passes.
   A quick pass or successful rendering cannot override that failure.
2. Development-machine isolation implicated shown-parent/message/input behavior.
   A longer 300-cycle control still grew; its name `native-child-plateau` is not
   evidence that a plateau exists. A removed process-local IME-disable experiment
   reduced USER growth but not handles. Normal IME behavior remains enabled.
3. The ESET inspection-module-excluded development control still failed. The
   user removed that narrow exclusion. This does not rule out every security
   component, but gives no reason to request broader exclusions. Windhawk
   exclusion also did not remove the earlier reproduction.
4. Process-only CDB tracing on Windows 10 attributed the 12 new current
   `IoCompletion` handles in the complete baseline-to-25-cycle interval: 11 to
   Windows power-message delivery, one to a WPF message-posting path. Final trace
   history overflowed. Do not claim complete final lifetime histories or equate
   notification registration tokens with those internal completion handles.
5. A native-only paired control on Windows 10 grew with matched power
   subscriptions but stayed flat without them. WPF was unnecessary there.
6. Windows 7 did not reproduce that separation. Both native modes grew with
   zero GDI growth, and USER totals tracked additional queue-bearing threads.
   Explicit power subscription is unnecessary for this target reproduction.
   Windows 10 handle types/stacks are not automatically Windows 7 attribution.
7. The later Windows 7 recreate/reuse comparison 0.2 completes both modes.
   From baseline to iteration 100, recreate gains 15 handles/14 USER and reuse
   gains eight/eight; live sampled thread counts stay 38. All 14/eight additional
   positive queue observations belong to existing baseline identities in the
   `ntdll.dll+F8DE0` group. Reuse retains all 38 baseline identities through the
   last live checkpoint. This removes repeated surface creation as a necessary
   condition, without proving harmlessness or which module owns the resources.
8. Trace 0.3 now supplies direct call-path evidence. Eleven new unnamed Event
   opens between baseline and iteration 25 map one-to-one to WARP setup calls
   on eleven existing TID-plus-creation identities becoming queue-positive.
   Exact symbols resolve the callback chain to NTDLL TppWorkerThread /
   TppWorkpExecuteCallback, WARP ThreadPool::WorkCallBack / Task::ExecuteTask /
   Task_Present, then USER32 GetThreadDesktop. Those Event values and identities
   remain listed after final surface close plus ten seconds. Later handle diffs
   contain no newly outstanding opens. This attributes the bounded call path,
   not a long-term bound or the integrated C3 result.
9. [Offline WARP pool inspection](diagnostics/2026-09-13-warp-pool-lifetime.md)
   finds initialized resource slots, one reusable work object, callback drain,
   work close and wrapper free in the device path. Mode 3 uses the default pool;
   mode 2 creates a private pool with minimum/maximum one worker. This does not
   prove the captured target executed either branch or its cleanup calls.
10. In trace 0.3, the 32 target TpWorkerFactory entries all report Pool `0x266460`, not 32
    distinct pools. Their minimum/maximum are 0/512 and idle timeout is 67
    seconds. All 34 baseline Windows workers survive final+10s, while WARP is
    absent from the final loaded list. The observation is too short to test
    retirement after that interval; the timeout is not a release deadline.
11. The later [Windows 7 retirement result](diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result)
    records mode 3 and completed work/wrapper cleanup. In this process, all 34
    baseline pool-worker identities remain at final+10s but are absent at +90s
    and +180s; the factory reports zero workers. USER returns to its pre-warmup
    value of 4, with GDI 9. All 15 Event values added between baseline and
    iteration 25 have matching worker-exit CLOSE records and are absent by
    +90s; this holds for all 34 captured WARP/GetThreadDesktop Events. Process
    handles remain 107, or 54 above
    pre-warmup, so this is bounded retirement evidence, not integrated C3 acceptance.
12. The [Windows 7 WPF reactivation result](diagnostics/2026-09-14-resource-reactivation.md#supplied-windows-7-result)
    completes both rounds with three immediate failures preserved. Its +180s
    handle/thread/GDI/USER counts match exactly, with +220 KiB private bytes.
    Nine of the 13 late thread identities are common and four differ. None of
    the 40/42 queue-positive `ntdll.dll+F8DE0` identities at the ends of the two
    batches appears at its corresponding +180s sample. Missing identities are
    not exit events; equal handle totals do not prove the same handles remain.

Earlier comparison 0.1 Windows 7 deltas from post-warm-up through the ten-second final
closed-surface sample (one persistent native parent still exists):

| Mode | Handles | USER | Private bytes | Total sampled threads |
| --- | ---: | ---: | ---: | ---: |
| Power, 102 matched registration/unregistration pairs | +12 | +10 | +2,658,304 | 37 to 42 |
| Plain, zero registrations or deliveries | +16 | +14 | +1,515,520 | 36 to 44 |

At every target sample, USER equals four plus the queue-bearing
`ntdll.dll+f8de0` count. This is an unsymbolicated grouped start address, not
ownership proof. The final +2 handles in each mode coincide with two more
non-queue threads. Samples are sequential, not atomic. Brief flat intervals do
not prove a fixed pool or a long-term bound. Both modes exit 0 for completed
measurements, not resource acceptance. The complete target transcript is in the
[diagnostic appendix](diagnostics/2026-09-13-resource-investigation.md).

## Next bounded task

The owner has decided to continue development and return to the WARP concern
only when evidence or release review requires it. Follow the
[September 14 decision](architecture/2026-09-14-warp-development-deferral.md)
and [REL01](../../ROADMAP.md#deferred-reliability-review). Do not resume the
dedicated tracing campaign or request another diagnostic/soak as a prerequisite.

The exact 0.3.7 Windows 7 run is accepted and archived. The
[S00 evaluation](validation/2026-09-14-openssh-s00.md) is complete on Windows 7
in two complete, repeatable runs. It freezes the exact official Microsoft
10.0p2 x64 client and shows that redirected input produces a PTY-allocation
diagnostic on stderr. No unchanged preflight rerun is requested. The
controlled-server package 0.1 completes on the owner's Debian 12 server and
dedicated `sshtest` account. Strict trust, key-only authentication, exact
non-PTY bytes, negotiation, final drain and active cancellation pass. Forced PTY
allocation reports 0 columns by 0 rows. Exact 10.0p2 source shows that its
Windows size query reads the stdout console buffer and its resize notification
comes from console input events. VT7's redirected pipes provide neither path,
so another resize run would not add evidence. S00 rejects this interactive
architecture while retaining the client as a command-only option.

SSH.NET 2026.0.0 is the accepted S01 transport candidate because it exposes
explicit PTY resize and structured trust/authentication. The owner accepted its audited
permissive Apache-2.0, ISC-style and supplier terms as a standing project-wide
policy. Corrected package 0.6 passes public-key-only and optional-password runs
on Windows 7 against controlled Debian, so S01 accepts SSH.NET as the embedded
interactive candidate. Complete the session ownership and security contracts
next, carrying the stream-first shutdown rule into production. Apply the
[session ownership and external source review](architecture/2026-09-14-session-ownership-and-source-review.md):
do not let a real transport grow into the current HWND-owned `Surface`, and keep
TerminalCore/session identity separate from presentation identity before 3B.
Reuse the
existing renderer and accepted evidence; preserve native HWND destruction before
presentation-worker cleanup/join. Full local sessions and the daily-driver UI
follow the 3A choices and contracts, not another renderer research campaign.

The two S00 preflight runs are preserved byte-identically under
`artifacts/vt7/evidence/openssh-s00-win7-preflight-0.2/`. They contain 44 raw
files and 35,558 bytes. The archive verification and independent analysis record
the per-file comparisons, exact package identity, official archive-entry match,
algorithm/default distinction, raw channel behavior and 807/808 ms cancellation.

The controlled-server run is archived under
`artifacts/vt7/evidence/openssh-s00-network-win7-0.1/`. Its private raw copy is
byte-identical but contains a public host fingerprint and temporary Windows
profile path, so it is not publication-safe. The sanitized copy and independent
analysis retain every behavioral result without those identifiers. Package 0.1
has SHA256 `8029CC9CF48F9BAEA839F16F3E104A552F848AB17A4A12636C966145B421B7FA`;
the original manifest has SHA256
`A3F4EE75A4379ACEA05498D41F1CB743B2F4EE99069A33CA78629C0CFA17C1DE`.

The [completed Windows 7 reactivation run](diagnostics/2026-09-14-resource-reactivation.md#supplied-windows-7-result)
has 16 valid samples, 200 measured lifecycles, 2,000 resizes and 1,000 tab trips
in 655.156 seconds. Worst close is 8 ms; all 202 companion WPF reports pass.
Both +180s states have 1,314 handles, 13 threads, GDI 18 and USER 10. Private
bytes differ by 220 KiB. Three original immediate checks still fail. Nine late
thread identities are common and four differ; handle identities are unproven.

All 207 files (883,594 bytes) are verified and archived under
`artifacts/vt7/evidence/resource-reactivation-win7-0.1/resource-reactivation-20260914-032308-629f4198/`.
The report SHA256 is
`168C44C2C17BFAA9B1360669D76136BD742DF8926F3ED7247E3D3507BB923C35`.
The diagnostic record links inventory/supplement, validator, independent analysis
and package provenance. The separate Windows 10 result retains eight immediate
failures and late deltas of +2 handles, +1 thread, +1 USER and +3,846,144 bytes.

Keep the original budgets, warm-up, baseline, reports and failed exits. This is
development-risk acceptance, not a declaration of a fix or C3/Milestone 2
completion. REL01 uses ordinary product qualification at release review and
reopens earlier for continuing accumulation, exhaustion, crashes/hangs, shutdown
failure or a concrete relevant lifetime defect. Another trace is conditional,
not inevitable; identifying every internal Windows handle is not a prerequisite
to acceptance. No new application code or diagnostic is issued by this decision.

## Retained diagnostic context

The following history and dated next-step reasoning preserve how the evidence
was obtained. The approved REL01 decision above supersedes any instruction here
to continue tracing or complete attribution before developing sessions.

The [resource lifetime comparison 0.2](diagnostics/2026-09-13-resource-lifetime.md#supplied-windows-7-comparison)
has answered its narrow question: growth also occurs with one reused surface.
Do not request another unchanged comparison or extend it into a timed soak.

By iteration 25, the target `ntdll.dll+F8DE0` group has 34 positive queue
observations in recreate and 33 in reuse, from the same 34 baseline identities
in each run. These observations remain through final destruction plus ten
seconds. The prior failed GUI queries are unavailable evidence, not proof of
earlier queue absence. The two sampled identities with Native and D3D10Warp
start addresses disappear after final close; the other 36 identities survive.
Reuse handles increase 138 to 140 during the final delay with the same sampled
identities and queue observations. This residual is not attributed by the logs.

The reused-surface trace has identified the Windows 7 call path and retained
handle type for the eleven-handle growth interval. Offline inspection now
connects WARP device construction, task submission and work cleanup. The later
retirement capture now observes actual mode/cleanup and worker disappearance
beyond the reported 67-second idle timeout. The
[pool-lifetime record](diagnostics/2026-09-13-warp-pool-lifetime.md) preserves the
reasoning for that diagnostic. A correction or general bound still requires
connecting this native evidence to the integrated application.
The [focused resource trace 0.3](diagnostics/2026-09-13-resource-trace.md) now
supplies the process-scoped collection. It preserves the exact 0.2 executable
and issued native 0.3.5 DLL, includes both matching private PDBs, and traces
25 reuse iterations with six existing checkpoints. A module containing a
thread's start address is not its allocation owner. The internal USER32 setup
hook has no guaranteed queue-allocation coverage; match its events to the same
run's identities before drawing conclusions. Handle-history diffs concern NT
handles, not USER objects, and debugger timing/counters are not normal stability
measurements. The supplied target capture completes; the issued validator's
nested Token Type bug is corrected and the unchanged logs pass offline.
No new package, unchanged target rerun or full application build is needed
to validate the preserved 0.3 capture.

The user installed SDK 8.1 Debugging Tools. Target CDB/DbgHelp 6.3.9600.17298
and DbgEng/Ext/Exts 6.3.9600.17336 pass preflight; no reinstall is requested.
Trace 0.1 then stopped at first-chance invalid handle (`0xC0000008`) and an
interactive prompt before the application banner, native DLL load or any sample.
The previous USER32 setup stack is not the missing exception stack.

Trace 0.2 records the exception's own context and passes first chance with `gn`.
It aborts on unhandled second chance or the sixteenth such exception. A queued
stdin fallback captures any unexpected debugger prompt and ends the diagnostic
promptly. Its supplied target run records the same exception at second chance
11 ms after dispatch, before the application banner, native DLL or any sample.
Raw frames are in NTDLL startup, but nearest-export labels do not identify the
exact invalid operation or cause. No WARP work occurred in this capture.

Trace 0.3 preserves that exception policy. Its separate startup child uses
neither the USER32 setup hook nor handle tracing and quits at pre-warmup sample
entry, after CRT/COM, native load and parent-window creation. Only if that passes
does the full trace start. The full trace keeps the early setup hook, but activates
!htrace inside the first sample-entry breakpoint, before inventory/sampling and
first surface creation. Thus early startup NT opening histories are excluded;
all WARP surface work and the baseline-to-25 interval remain in scope. If this
full trace fails before pre-warmup, handle tracing is still off in that process.
Both stages preserve !lmi ntdll CodeView identifiers for later symbol retrieval.
The startup control has a 60-second limit and the full trace a 600-second limit.
This is diagnostic isolation, not proof that !htrace caused the startup failure.

The supplied 0.3 startup control and full trace both complete without an invalid
handle. All 36 setup records are preserved: main loader 1, native presentation
worker 1, WARP/GetThreadDesktop workers 34. Between baseline and sample 4,
eleven Event opens match eleven setup events and first positive queue samples
on existing identities. All 34 baseline TppWorkerThread identities become
queue-positive; a 35th new identity remains queue-unavailable with no setup
event. Do not interpret an unavailable query as proof that it has no queue.

The validator now checks one top-level Type per handle and reconciles each
type total. All 137 fixtures pass against both Win7 and Win10 captures under
PowerShell 2.0 and 5.1. The original target summary still records launcher exit 1;
the corrected offline result is separate. Keep the issued 0.3 ZIP intact.

Exact Microsoft NTDLL and WARP symbols are retained with download provenance
and independent GUID/age checks. WARP Task_Present, not its misleading nearest
export label, invokes GetThreadDesktop. That API's returned desktop handle
requires no CloseDesktop call; the observed Events are internal effects, not
application-owned desktop handles to close. Do not force worker termination or
change internal-threading flags as a substitute for understanding the boundary.
The completed Init/CleanUp, caller and submission inspection finds no obvious
missing work close on that path. Default-pool work closure leaves Windows in
control of its workers. In trace 0.3, factory parameters supported default-pool
use as an inference; the later retirement capture supplies actual mode 3 and
matching wrapper/work cleanup observations.

Retirement 0.1 keeps the two-warm-up/25-measured reused-surface workload and the
exact native 0.3.5 DLL. Its new sampler exports `VT7RetirementSample` and adds
10/90/180-second post-close checkpoints. Private WARP hooks require matching PE,
CodeView and instruction identities; an unsupported profile collects ordinary
resource evidence without using those offsets. At final close the collector
disables setup, ownership and module-load event hooks, leaving checkpoint/exit
breakpoints while the normal message pump runs. Unexpected stops or idle
exceptions make collection incomplete. The final full handle history retains
OPEN/CLOSE records and rejects a dump that reaches the history capacity.

The final Windows 10 collection passes under actual PowerShell 2 with eight
checkpoints, zero invalid handles and 4,308 full-history records. Its WARP profile
is correctly unsupported, so this is collector qualification rather than a
Windows 7 cleanup or retirement result. The 181 synthetic validator fixtures
plus its three actual stage logs pass offline under PowerShell 2 and 5.1.
The target-only hook and failure controls are documented separately in the
[retirement record](diagnostics/2026-09-13-resource-retirement.md).

The supplied Windows 7 retirement run then passes all three stages with a
supported profile and zero invalid handles. All 34 baseline pool workers are
absent by the 90-second sample, USER falls 38 to 4 and handles fall 141 to 107,
with both unchanged at 180 seconds. The same 32 factory handle values remain,
now reporting zero workers. The remaining 54 process handles above pre-warmup
and the integrated WPF failure still need a bounded follow-up. No timed soak
was run and this native retirement result does not accept C3.

Keep exception review separate from collection completion. The local
6.3.9600.16384 debugger qualifies the policy with separate handled, unhandled
and repeated-exception fixtures. Do not copy the current 10.0.26100 debugger to Windows 7; its engine
imports GetSystemTimePreciseAsFileTime. The VS 2022 17.14 build environment
belongs on the modern development host, not Windows 7. No global debugger,
kernel debugging, registry setting or security exclusion is used.

Keep normal rendering, input, accessibility and security behavior. No worker
suppression, extra warm-up or budget relaxation is justified. Use ownership
evidence to select a fix or support a bounded lifetime model, then rerun the
unchanged integrated profiles on both machines. The short flat interval in
this diagnostic does not close C3 or establish a long-term bound.

User test context: Croatian HR Latin is the primary input layout. The user
reports Windows PowerShell 5.1 and PowerShell 7.2.24 installed side-by-side on
the Windows 7 target. The trace launcher uses powershell.exe, hence 5.1 there;
this is an installed-tool inventory, not a VT7 session-backend qualification.
The user also reports Visual Studio 2022 Enterprise 17.6 with needed features
installed on the target. This does not replace the pinned modern-host build tools.
Immediately available hardware includes GTX 580, i7-9700, i7-6700, Athlon II and FX-8350.
The user can assemble broader hardware combinations later, after the application
is fully working with its features; this bounded comparison uses the existing
Windows 7 setup rather than requesting a hardware matrix now.

## Code map for that task

| Area | Files and role |
| --- | --- |
| Build/version | [VT7.sln](../../VT7.sln), [Directory.Build.props](../../src/vt7/Directory.Build.props), [Build-VT7.ps1](../../tools/Build-VT7.ps1). |
| CLI and diagnostic dispatch | [App.xaml.cs](../../src/vt7/VT7.Host/App.xaml.cs). |
| Managed lifecycle workload | [StabilityWindowChecks.cs](../../src/vt7/VT7.Host/StabilityWindowChecks.cs). |
| Integrated reactivation diagnostic | [Protocol and qualification](diagnostics/2026-09-14-resource-reactivation.md), [two-round controller](../../src/vt7/VT7.ResourceReactivation/ReactivationChecks.cs), [thread identities](../../src/vt7/VT7.ResourceReactivation/ReactivationThreads.cs), [validator](../../src/vt7/VT7.ResourceReactivation/Validate-ResourceReactivation.ps1), [launcher](../../src/vt7/VT7.ResourceReactivation/Run-ResourceReactivation.ps1). Separate managed project, shared actual host workload, unchanged native payload. |
| Process/thread samples | [ResourceDiagnostics.cs](../../src/vt7/VT7.Host/ResourceDiagnostics.cs). |
| WPF/native lifetime | [TerminalSurface.cs](../../src/vt7/VT7.Host/TerminalSurface.cs), [surface.cpp](../../src/vt7/VT7.Native/surface.cpp). |
| C ABI agreement | [vt7_native.h](../../src/vt7/VT7.Native/include/vt7_native.h), [exports.def](../../src/vt7/VT7.Native/exports.def), [NativeMethods.cs](../../src/vt7/VT7.Host/NativeMethods.cs). |
| Session byte path | [native decoder](../../src/vt7/VT7.Native/utf8_terminal_stream.hpp), [bounded managed pump](../../src/vt7/VT7.Host/SessionOutputPump.cs), [visible fixture](../../src/vt7/VT7.Host/SessionStreamFixture.cs), [focused integration check](../../src/vt7/VT7.Host/SessionStreamWindowChecks.cs), [runner](../../tools/Test-VT7SessionStream.ps1). |
| Renderer worker/timers | [renderer.cpp](../../src/renderer/base/renderer.cpp), [renderer.hpp](../../src/renderer/base/renderer.hpp), VT7 compatibility branches. |
| Atlas/presentation | [AtlasEngine.cpp](../../src/renderer/atlas/AtlasEngine.cpp), [Win7Presentation.cpp](../../src/vt7/VT7.Renderer/Win7Presentation.cpp). |
| Font boundary, not current task | [Renderer README](../../src/vt7/VT7.Renderer/README.md), Win7TextMapper and private font fallback. Experimental fitters are not automatic production policy. |
| Assertions/runner | [Test-VT7AtlasStability.ps1](../../tools/Test-VT7AtlasStability.ps1), [packaging launchers](../../src/vt7/packaging/README.txt). |
| Native-only control | [Preserved source and recipe](diagnostics/2026-09-13-resource-investigation.md); not part of VT7.sln or the WPF Host source. |
| Recreate/reuse control | [Protocol and source map](diagnostics/2026-09-13-resource-lifetime.md); versioned standalone source, isolated build/package/test helpers. |
| Focused reuse trace | [Protocol and tool provenance](diagnostics/2026-09-13-resource-trace.md), `src/vt7/VT7.ResourceTrace/`, `tools/Package-VT7ResourceTrace.ps1`, `tools/Test-VT7ResourceTrace.ps1`. No application rebuild. |
| Worker retirement diagnostic | [Protocol, package and qualification](diagnostics/2026-09-13-resource-retirement.md), [sampler](../../src/vt7/VT7.ResourceRetirement/main.cpp), [collector](../../src/vt7/VT7.ResourceRetirement/retirement.cdb), [validator](../../src/vt7/VT7.ResourceRetirement/Validate-ResourceRetirement.ps1), [build helper](../../tools/Build-VT7ResourceRetirement.ps1), [package helper](../../tools/Package-VT7ResourceRetirement.ps1). New diagnostic only; native application payload unchanged. |

Current source-only managed isolation cases are `wpf`, `native-child`,
`hwndhost`, `native-child-software`, `native-parent`, `native-child-layered`
and `native-child-plateau` (300 cycles). They are not present in the issued
0.3.5 ZIP. No IME-disable case remains. Their retained source has local Debug
checks, not fresh Release/Windows 7 qualification.

## Build and test resumption

Use [BUILDING.md](../../BUILDING.md) for the complete prerequisites and commands.
The pinned developer tools are Visual Studio 2022/MSVC 14.44.35207, Windows SDK
10.0.26100.0 and .NET Framework 4.8 targeting files. Build on the development
machine, then validate the resulting artifact on Windows 7. This is a command
reference: select checks relevant to the next change, not an automatic request
to repeat every accepted suite. This diagnostic task did not rerun these
integrated application suites:

```powershell
.\tools\Build-VT7.ps1 -Configuration Debug
.\tools\Verify-VT7.ps1 -Configuration Debug
.\tools\Test-VT7.ps1 -Configuration Debug
.\tools\Test-VT7AtlasRepaint.ps1 -Configuration Debug
.\tools\Test-VT7AtlasRecovery.ps1 -Configuration Debug
.\tools\Test-VT7AtlasSettings.ps1 -Configuration Debug
.\tools\Test-VT7FontAssets.ps1 -Configuration Debug
.\tools\Test-VT7AtlasStability.ps1 -Configuration Debug
```

Build/restore can download pinned dependencies. Tests launch local processes and
overwrite their named report paths, so preserve earlier reports first. For the
known full lifecycle reproduction, use `-Lifecycle -Renderer atlas-d3d-warp`
on `Test-VT7AtlasStability.ps1`; its current failure is not a new regression by
itself. Do not add `-Soak` now. Read each negative-control verdict, not just a
generic search for `FAIL` across all reports. The viewport blank, repaint,
settings/font and idle negative tests intentionally reject their injected faults.

Unchanged post-warm-up investigation limits are +64 MiB private memory,
+32 handles, +8 threads, +16 GDI and +16 USER, sampled repeatedly. These are
test gates, not a claim that every smaller increase is harmless. Quick mode
has 8 measured lifecycles; full has 100/1,000/500 lifecycles/resizes/tab trips.
The extended active/idle profile is separate and has no results yet.

## Artifacts and evidence availability

The latest completed target capture uses `VT7-resource-retirement-0.1-x64.zip`. Its exact
size, hashes, provenance and local qualification are recorded in the
[retirement diagnostic record](diagnostics/2026-09-13-resource-retirement.md).
It preserves the earlier artifacts listed below. Its Windows 7 result is now
recorded; no unchanged rerun is requested.

| Artifact | Identity and scope |
| --- | --- |
| `VT7-atlas-viewport-0.3.4-x64.zip` | 10,523,404 bytes; accepted bounded scaling matrix, not complete renderer acceptance. |
| `VT7-atlas-viewport-0.3.5-x64.zip` | 10,541,563 bytes; Release ABI 8 investigation candidate, known WARP failure. |
| `VT7-resource-comparison-0.1-x64.zip` | 2,938,282 bytes; native-only Host plus exact issued 0.3.5 native/runtime/font/legal payload, not the WPF application. |
| `VT7-resource-lifetime-0.2-x64.zip` | 3,799,264 bytes; recreate/reuse measurements complete locally and on Windows 7. Both target modes grow; resource acceptance remains open. |
| `VT7-resource-trace-0.1-x64.zip` | 8,297,623 bytes; locally complete. Target preflight passes, but trace times out at an invalid-handle prompt before application work. Preserved, superseded by corrected trace 0.2. |
| `VT7-resource-trace-0.2-x64.zip` | 8,055,884 bytes; final packaged run passes locally under PowerShell 5.1. Target captures unhandled second-chance invalid handle during startup, before native DLL load or WARP work. Preserved. |
| `VT7-resource-trace-0.3-x64.zip` | 8,060,952 bytes; separate startup control and delayed handle tracing. Local and target captures complete. Issued target validator miscounts nested Token metadata; corrected offline validation accepts the preserved capture. ZIP unchanged. |

SHA256, in that order:

```text
9E112F6093FD0FBEEAA2409C655D9FEB7E22340F5823A8141FEE00C49E0A19CA
57B2EE43BB9A1AC6AB227B7C7BE4E3FCB88C765753FDEDD988E14EF375604C86
16A058CE3AA41D9D6829F1ACC357CE0CD4CC9128DE04F12D2F8914B16198118D
8F2F1014A96B1781486574E4FF92AD8B43823CB96EC90BA1A2E71B656C03F388
AAFA42259DDF706400F77DDC75BAF7F41BB9876960C2B740DF7484175A830033
0442029DC3BC4D4CFF89CE11089B16855E47C500146E962D8C55A751685E6D5D
E0DCA8AD0532E401903D46DE6E352303C56D9392DF0B613C40FC2AFDAB461059
```

The three earlier archives were rechecked unchanged during the 0.2 diagnostic
task; the new archive's entries were verified against its manifest. They are local
engineering artifacts under `artifacts/`, not public releases or Git-tracked
files. Issued source/provenance text inside a ZIP is a dated snapshot and is not
rewritten when the working documentation advances.

- Integrated target evidence: `artifacts/vt7/evidence/atlas-stability-win7-0.3.5/`.
- Native recreate/reuse target evidence:
  `artifacts/vt7/evidence/resource-lifetime-win7-0.2/resource-lifetime-20260913-144532-55a231c4/`.
- Supplied trace 0.1 timeout:
  `artifacts/vt7/evidence/resource-trace-win7-0.1/resource-trace-20260913-151714-26f04e23/`.
- Trace 0.1 local qualification:
  `artifacts/resource-trace-0.1/Logs/resource-trace-20260913-151421-516ac5a5/`.
  All 54 payload entries in the trace ZIP verified. The trace record includes
  60 validator fixtures, launcher failure controls and timeout cleanup evidence.
- Corrected trace 0.2 local qualification:
  `artifacts/resource-trace-0.2/Logs/resource-trace-20260913-155408-deb5c62b/`.
  All 57 archive entries and fresh extraction verified; handled, unhandled,
  repetition-limit and unexpected-prompt controls pass. The trace record
  preserves the separate exception fixture and 85 text-validation cases.
- Supplied trace 0.2 startup exception:
  `artifacts/vt7/evidence/resource-trace-win7-0.2/resource-trace-20260913-160144-8a929ea8/`.
  Preflight passes; first-chance context, normal dispatch and second-chance
  context are captured. The launcher correctly rejects collection despite
  CDB itself exiting zero after the explicit abort.
- Trace 0.3 final packaged qualification:
  `artifacts/resource-trace-0.3/Logs/resource-trace-20260913-161208-c026e689/`.
  Preflight, separate startup control, full trace and launcher pass. The trace
  reaches all six checkpoints with two setup events and zero invalid handles.
  All 59 checksum-listed payload files verify in the ZIP and fresh extraction.
  All 126 text-validation fixtures pass on PowerShell 2.0 and 5.1 against the
  final packaged logs, with transcripts retained in the archive audit directory.
  Preflight-only and startup-abort stage controls pass; the latter prevents
  the full trace from starting. Exact hashes and regression evidence are in
  the trace record. All earlier pinned archive identities remain unchanged.
- Supplied trace 0.3 and offline correction:
  `artifacts/vt7/evidence/resource-trace-win7-0.3/resource-trace-20260913-161711-9df20496/`;
  `artifacts/vt7/diagnostics/resource-trace-0.3-offline-revalidation-1789309290771-d8abc328/`.
  Corrected validator and fixture source snapshots, exact commands and all four
  137-case transcripts are retained. No runtime workload was launched to
  revalidate these logs. Derived identity/handle tables and exact symbols are
  linked from the trace record.
- Retirement 0.1 final local collector and offline validation:
  `artifacts/vt7/diagnostics/retirement-final-collector-qa-20260913-145800598-c35e2414/Logs/resource-retirement-20260913-165800-9ec8f673/`;
  `artifacts/vt7/diagnostics/retirement-validator-actual-20260913-170226/`.
  Three debugger stages complete on Windows 10 under PowerShell 2. The final
  history has 4,308 records; 184 offline checks pass on PowerShell 2 and 5.1.
  `TARGET_EVIDENCE=UNSUPPORTED` distinguishes this local qualification from
  the separate supplied Windows 7 result.
- Supplied retirement 0.1 target evidence is archived at
  [`artifacts/vt7/evidence/resource-retirement-win7-0.1/resource-retirement-20260913-170928-9ad405a7/`](../../artifacts/vt7/evidence/resource-retirement-win7-0.1/resource-retirement-20260913-170928-9ad405a7/).
  The user explicitly authorized copying the original K: run. All 17 files
  (7,310,791 bytes) match source sizes and SHA256 hashes, rechecked after copying;
  the original logs are unchanged. The separate
  [verification record](../../artifacts/vt7/evidence/resource-retirement-win7-0.1/ARCHIVE-VERIFICATION-20260913-152421-53a65b82.json)
  lists every archived file. This ignored artifact directory must be transferred
  separately for a fresh checkout.
  The [target result](diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result)
  records hashes, numerical findings and evidence limits.
- Earlier native power/plain evidence:
  `artifacts/vt7/evidence/resource-comparison-win7-0.1/resource-comparison-18452-32699/`.
- Supplied I01 Windows 7 evidence:
  `artifacts/vt7/evidence/input-i01-win7-0.2/input-i01-20260914-052832-f87c2fc7/`.
  The four original files total 354,713 bytes and are copied unchanged.
  `ARCHIVE-VERIFICATION.json` records every source size/hash and
  `INDEPENDENT-ANALYSIS.json` records the accepted input/resize decision.
- Supplied session-outbound 0.3.7 Windows 7 evidence:
  `artifacts/vt7/evidence/session-outbound-win7-0.3.7/session-outbound-20260914-063714-74969eea/`.
  The two original files total 2,807 bytes and are copied unchanged.
  `ARCHIVE-VERIFICATION.json` records both source size/hash pairs and
  `INDEPENDENT-ANALYSIS.json` records the exact package identity and accepted
  queue/input/resize decision.
- Local managed/native controls and CDB traces: `artifacts/vt7/diagnostics/`.
- Local integrated reports: `artifacts/vt7/reports/Debug/` and `Release/`.
- Versioned findings, hashes and limitations:
  [stability record](validation/2026-09-13-atlas-stability.md).
- Versioned native source/header/launcher, trace setup and latest target logs:
  [diagnostic appendix](diagnostics/2026-09-13-resource-investigation.md).

Full older raw traces, screenshots, binaries and PDBs still require a separate
artifact transfer. Do not say they are available from Git. The preserved source
allows a new diagnostic build, but compiler timestamps and environment mean it
is not the byte-identical issued executable. Assign it a new identity and qualify
its actual bytes. If source or a required artifact is missing, state that gap
instead of reconstructing a historical pass from memory.

Specific historical limits also remain: initial visible Atlas-backend logs
(848 hardware frames and 432 WARP frames) were overwritten by later same-name
R-key runs; only their documented totals survive unless a separate backup exists.
Some early probes identify a source base plus uncommitted changes, not a complete
rebuild manifest. Early ESU success was tester-confirmed without separate supplied
ESU logs or full update inventories. Do not retrofit stronger provenance into
those records.

## Before handing off again

Update this file, the applicable validation record and roadmap status together.
Record exactly what changed, source and artifact identity, configuration and
environment, passed/failed/incomplete/not-run cases, preserved evidence paths,
what remains unproven and one concrete next task. Keep the MIT and dependency
notices intact. Do not add an em dash. Do not commit generated artifacts or
private logs indiscriminately. Read [CONTRIBUTING.md](../../CONTRIBUTING.md) for
the full maintenance and provenance rules.

Earlier documentation audit checks: local Markdown paths/anchors, archived diagnostic
source and transcript consistency after line-ending normalization, no added em
dashes, diff whitespace and the comment-only renderer project XML change.
That documentation audit performed no application build or runtime test.
The later 0.2 diagnostic build and local checks are recorded separately in its
linked protocol. No security-setting change, upstream merge, commit or push is
part of the diagnostic task.
