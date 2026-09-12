# Diagnostics and Windows 7 acceptance experiments

Current execution checkpoint, September 12: the supplied
[0.3.0 Windows 7 run](../validation/2026-09-12-atlas-viewport.md) accepts the bounded
C1/C2 font/core/Atlas integration. [0.3.1](../validation/2026-09-12-atlas-repaint.md)
passes the supplied Windows 7 repaint/cursor checks. The
[0.3.2 recovery slice](../validation/2026-09-12-atlas-recovery.md) also passes supplied target testing.
The [0.3.4 scaling matrix](../validation/2026-09-12-atlas-scaling-correction.md)
now passes all positive suites at actual Windows 7 96/120/144 DPI on the tested
setup, resolving the recorded 0.3.3 failures. Scheduling/idle/resource/shutdown
checks are next; theme and broader renderer qualification remain open.
This status supersedes next-task wording in the dated
assessment/plan below, without retroactively changing its original evidence.

Research date: 2026-09-11. This is a proposed experiment backlog, not an execution report. No application builds, installations or runtime tests were performed for this research.

## Preserve the strength and limits of existing evidence

The viewport records establish a static GDI/core proof. The later renderer probe records 49 required checks without failures and one missing glyph on Windows 7. The probe does not load Atlas. Neither record establishes interactive local-shell or SSH acceptance. Keep those distinctions in future release notes and test reports. [1][2][3]

The roadmap separates the declared prerequisite floor, ESU systems, unofficial later servicing, and VM/software-rendering environments. A pass on one tier cannot substitute for another. [4]

**Recommendation:** prefer a small number of reproducible, well-instrumented experiments that resolve architectural choices before expanding into long endurance testing.

During the final source review, a new VT7.AtlasProof and Test-VT7AtlasProof.ps1 appeared. Their fixed-glyph backend/readback tests provide a starting point for G01/G02 below. They bypass AtlasEngine mapping and TerminalCore, and no execution results from that harness were assessed for this research. Reuse and extend that infrastructure rather than creating a duplicate proof. [11]

## Required evidence attached to every run

Later implementation checkpoint: the
[backend validation record](../validation/2026-09-11-atlas-backend-proof.md)
supplies Windows 7 results for that harness: four passing 19-frame automated
runs and visible Direct3D11 hardware/WARP sessions, including 8/6 R-key
recreations. This partially addresses the graphics backlog, not the complete
G01/G02, font, scheduling, or endurance criteria. The research itself did not
execute those runs; the validation record separates their scope and provenance.

Proposed run manifest:

- Repository revision and dirty patch identifier; configuration, compiler/SDK versions and complete package hashes.
- OS edition, architecture, SP/build, update tier, pending-reboot state, locale, ACP/OEMCP and keyboard layout.
- Versions/paths of loaded UCRT, VC runtime, CLR, DWrite, D2D, D3D11 and DXGI modules; .NET host and child-shell versions separately.
- GPU/driver, adapter selection, feature level, hardware/WARP choice, display/composition/remote-session state and system DPI.
- Font file/version/hash, selected face per run, corpus version, code points and expected cell widths.
- Session backend/library revision, child executable/arguments with secrets removed, dimensions and transport settings.
- Exact attempted operation, success/failure code, elapsed time and an artifact with a stable name.

Record unavailable data explicitly. Never turn an unexecuted optional test into a pass or collapse an unexpected skip into the required-check count.

## Adopted execution mapping

The [September 12 port-first decision](../architecture/2026-09-12-port-first-plan.md)
narrows current F02 work to the Windows 7 adapter and inherited shaping/cell
behavior, followed by real Atlas integration. The broad original experiment
targets below are research scope, not a demand to solve enhanced typography or
visual bidi before proceeding. Reuse existing evidence; investigate a named
blocker with a bounded test and an explicit next action. Non-blocking observations
go to Milestone 7/POL entries, distinct from these historical experiment IDs.

The [approved planning decision](../architecture/2026-09-11-research-driven-plan.md)
maps these stable experiment IDs to the [roadmap](../../../ROADMAP.md). Priorities
below indicate risk, not a requirement to run the entire backlog before 2C.

| Milestone | Required experiments and timing |
| --- | --- |
| 2C | Reuse F01 missing-glyph evidence; finish the minimum production F02 font/cell adapter with inherited policies. |
| Remaining renderer gates | G01/G02/T01, extending the recorded fixed-glyph results to the integrated controller and real text. |
| 3A, before substantial local/UI integration | P01/I01/S00 plus written session, input/IME, accessibility-range, and output-security contracts. |
| 3B/3C | U01/P02/I01/I02; initial paste and output-policy checks accompany first real sessions. |
| 4 | A01/C01/D01 and U01 selection/search range coverage. |
| 5 | S01 plus direct-SSH U01/I01/I02/C01 revalidation; S00 alone is not SSH acceptance. |
| Runtime additions and 6 | L01 dependency checks throughout, followed by clean-minimum full-package qualification and extended soak coverage. |
| 7 | Triage POL01-POL06 and new optional findings; validate selected polish and explicitly defer remaining ideas. |

Link implementing changes and run manifests to each applicable ID. A partial
pass names the exact subcases completed and the remaining work. G01/G02 are not
fully closed by the existing backend proof. Session isolation, bounded resources,
trust policies, and privacy-aware diagnostics are tested with their implementation,
not first introduced during final hardening. Original research did not execute
the experiments; the mapping adds no test results.

Execution follow-up: the linked 0.3.4 validation record, not the original research
table, establishes the accepted actual 96/120/144 system-DPI matrix and bounded
G01/G02-related repaint/lifecycle/recovery coverage on the supplied setup.
Remaining G01/G02 transitions and T01 scheduling/idle/resource/shutdown stress
are still open. No additional test or implementation is implied by updating this index.

## Priority experiments

All outcomes below are **acceptance targets**, not observed results.

| ID / priority | Question and procedure | Evidence that resolves it |
| --- | --- | --- |
| F01 / P0 | Reproduce the probe's missing glyph. Log source UTF-16 range, scalars, face, glyph IDs and fallback decision. | Identified character/cluster and cause: font coverage, selection, shaping, or rasterization. |
| F02 / P0 | Prototype Windows 7 layout-callback fallback into a terminal cell grid, initially independent of Atlas. | Retained run data, cluster-to-cell maps and correct Arabic/Indic/CJK/combining/supplementary samples. |
| G01 / P0 | Draw a complete frame, then change only one cell repeatedly on the chosen discard swap chain. Cover/uncover and resize. | Unchanged pixels remain correct because they are redrawn; no accidental retained-buffer assumption. |
| G02 / P0 | Exercise both Atlas backends, hardware/WARP, zero size, resize, detach, and device recreation. | Resource ownership graph and repeatable teardown; no stale render target or present after HWND destruction. |
| T01 / P0 | Stress wake/park, simultaneous invalidations, synchronized-output timeout and shutdown. | Predicate-based waits neither lose work nor spin; teardown finishes without UI/render lock inversion. |
| P01 / P0 | Feed a WinPTY child equivalent content through WriteConsoleW, A APIs, direct buffer writes and raw VT. | Side-by-side child screen, backend bytes and final core state; explicit local fidelity limits. |
| I01 / P0 before input integration | Compare inherited ToUnicodeEx helpers on Windows 7 with actual message translation for dead keys and AltGr. | Exactly one intended text result; no mutated dead-key state or unexpected control chord. |
| L01 / P0 before packaging | Launch the exact Release package on a clean minimum-prerequisite image without developer tooling. | Full dependency closure, real loads, required interface/method calls and a useful missing-prerequisite failure path. |
| P02 / P1 | Close local sessions during spawn, read, write, resize and child/grandchild exit; include a parent job. | No leaked agent/process/pipe; documented breakaway/containment behavior and no callbacks after close. |
| U01 / P1 | Feed Unicode/VT fixtures under randomized byte chunking, then resize/select/copy/search. | Identical semantic state across chunking; stable text-to-cell mapping and no corrupted UTF sequences. |
| I02 / P1 | Japanese/Chinese/Korean IMEs, focus switching, reconversion as supported, and candidate placement after resize/DPI change. | Composition and committed text are distinct; no duplicate commits; candidate UI follows the caret. |
| S00 / P0 at 3A, before implementation selection | Evaluate the known Windows 7-compatible Microsoft OpenSSH client with local-console and direct-I/O configurations. | Exact version/hash, negotiated algorithms, unmodified terminal bytes, initial/live PTY dimensions, correct prompt/diagnostic and trust handling, cancellation, and a recorded architecture choice. See the [OpenSSH reassessment](22-win32-openssh-reassessment.md). |
| S01 / P1 | Direct SSH nonblocking reads/writes, host-key changes, resize bursts, EOF/close and disconnect. | Correct retry buffers, terminal state, trust decision and exit status; no cross-session routing. |
| A01 / P1 | Inspect a native terminal surface with Windows 7 UI Automation tools and a supported screen reader. | Navigable text/ranges, selection/caret reporting and bounded notifications from native content. |
| C01 / P2 | Clipboard contention, huge/multiline paste, active mouse modes and OSC clipboard policy. | Correct ownership, bounded queues and explicit policy outcomes without freezing the UI. |
| D01 / P2 | Persist settings during a forced interruption; test Unicode/long paths and read-only portable directories. | Old or new valid configuration, recoverable failure, and no launch-dependent working-directory assumption. |

Why I01 is urgent: the inspected helper passes ToUnicodeEx bit 2, whose no-state-change semantics are documented only from Windows 10 version 1607. An import check cannot detect this flag-level incompatibility. [5][6]

## Corpus design

Recommended text cases: ASCII; Croatian diacritics; decomposed accents; leading combining marks; Arabic joining; at least one Indic conjunct; CJK wide characters; ambiguous-width symbols; supplementary-plane letters/symbols; text/emoji variation selectors; regional indicators; emoji modifier/ZWJ sequences; tabs, CR/LF/backspace; embedded NUL at bounded internal APIs; isolated UTF-16 surrogates and malformed/incomplete UTF-8.

For each case store original bytes or UTF-16 units, intended decoder policy, scalar/cluster boundaries, terminal cells, and expected selection/copy text. Distinguish “preserved text with missing glyph” from “text corrupted.” Do not demand a specific font image on machines with different font versions.

Recommended interactive programs should exercise a line editor, full-screen screen-buffer/VT application, high-volume output, password prompt, child process tree, and resize-sensitive layout. Pin versions. Existing Microsoft Terminal tests can guide fixtures, but a modern Windows result does not establish the Windows 7 adapter's behavior.

## Capability diagnostics versus appearance

Proposed graphics/font diagnostic stages:

1. Export found and module loaded.
2. Factory/device created, with exact flags and fallback reason.
3. Required interface acquired.
4. Required method succeeds with VT7's real descriptor.
5. Correct CPU-visible/readback result.
6. Correct visible terminal frame and interaction.

The Platform Update intentionally exposes only part of the newer graphics interfaces' behavior. Log these stages separately. [7] The current hidden probe primarily informs earlier stages; it cannot replace step 6. [3]

## Crash and hang evidence

Windows Error Reporting LocalDumps is available from Vista SP1, is not enabled by default, and supports per-application configuration; changing those settings needs administrative privileges. Microsoft documents dump location/type/count controls. This is an optional tester setup, not a change executed by this research. [8]

MiniDumpWriteDump is another option. Microsoft recommends an external process where possible because invoking it from an unstable process risks loader deadlock. DbgHelp calls must be serialized. [9]

**Recommendation:** prefer a separate diagnostic helper or documented WER setup over complex crash-handler work inside VT7. Dumps may contain terminal scrollback, credentials and decrypted session data: let the tester inspect and explicitly choose what to share. For hangs capture thread stacks and ownership/wait state before terminating the process.

A diagnostic event should name the session/surface generation, thread, operation, HRESULT/Win32 error, bytes queued and shutdown stage. Redact credentials and avoid logging ordinary terminal content by default. A failure code without the attempted operation is often insufficient to identify a downlevel API problem.

## Performance and endurance after correctness

QueryPerformanceCounter is the appropriate Windows high-resolution interval source; use paired counter/frequency values and compare durations rather than treating it as wall-clock time. [10]

Proposed measurements: input-to-core and input-to-present latency; output throughput at several chunk sizes; idle CPU; active/occluded/minimized CPU; WARP cost; glyph-cache growth; queue depth; handle/private-memory growth over repeated tab open/close; recovery time after a stalled child or network peer.

Measure timestamps at actual boundaries. A “frame rate” metric alone can conceal input queuing or skipped content. Establish thresholds from target hardware after the semantic experiments pass, rather than inventing performance guarantees now.

## Completion criteria for a research-driven implementation

For each chosen design, link the implementing change to the experiment ID and attach the exact run manifest. Record rejected alternatives and unresolved limitations briefly. Update claimed capabilities only when an end-to-end test demonstrates them on the appropriate Windows 7 tier.

The subsystem notes contain additional targeted tests; this file prioritizes the experiments most likely to prevent costly architectural rework.

## Sources

- [1] [Viewport proof evidence](../validation/2026-09-10-viewport-proof.md).
- [2] [Cleanup acceptance evidence](../validation/2026-09-10-milestone-1-cleanup.md).
- [3] [Independent renderer-probe evidence](../validation/2026-09-11-renderer-probe.md).
- [4] [Roadmap and supported test tiers](../../../ROADMAP.md).
- [5] [Terminal keyboard helper](../../../src/cascadia/TerminalCore/Terminal.cpp) and [TerminalInput helper](../../../src/terminal/input/terminalInput.cpp).
- [6] Microsoft, [ToUnicodeEx](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-tounicodeex).
- [7] Microsoft, [Platform Update for Windows 7](https://learn.microsoft.com/en-us/windows/win32/direct3darticles/platform-update-for-windows-7).
- [8] Microsoft, [Collecting User-Mode Dumps](https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps).
- [9] Microsoft, [MiniDumpWriteDump](https://learn.microsoft.com/en-us/windows/win32/api/minidumpapiset/nf-minidumpapiset-minidumpwritedump).
- [10] Microsoft, [Acquiring high-resolution time stamps](https://learn.microsoft.com/en-us/windows/win32/sysinfo/acquiring-high-resolution-time-stamps).
- [11] [New AtlasProof implementation](../../../src/vt7/VT7.AtlasProof/main.cpp) and [backend test harness](../../../tools/Test-VT7AtlasProof.ps1), final source review approximately 04:11 UTC on 2026-09-11.
