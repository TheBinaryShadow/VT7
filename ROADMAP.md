# VT7 Roadmap

This roadmap defines what VT7 is trying to achieve and how we will know when it
has arrived. It is intentionally ambitious. Windows 7 users have waited long
enough for a terminal that treats the platform as a first-class home.

VT7 is research-heavy work. Milestones are ordered by technical dependency,
not assigned calendar dates. We will publish dates only after the underlying
risks are understood well enough to make those dates meaningful.

## Guiding principles

1. Windows 7 is the target, not an accidental compatibility mode.
2. A feature is not complete until it works on real Windows 7 systems.
3. Reliability and terminal correctness come before visual novelty.
4. The user should not need to replace system DLLs or install a system-wide
   compatibility layer.
5. Compatibility code should live inside VT7 when that produces the safest and
   most predictable application.
6. Upstream code, third-party work, and individual contributors must receive
   clear attribution.
7. Claims in the README and release notes must match tested reality.
8. Core/renderer capability and end-to-end session capability are separate
   promises. A backend limitation must be measured, not hidden or silently
   adopted as a permanent product limitation.

## Research-driven execution plan

The [September 11 planning decision](doc/vt7/architecture/2026-09-11-research-driven-plan.md)
adopts the [research findings](doc/vt7/research/README.md) without changing
the platform floor, upstream baseline, or previously recorded test results.
Milestone numbering stays stable. The next implementation work is 2C, followed
by the remaining renderer integration and acceptance gates.

Before substantial local-session integration or daily-driver UI construction,
3A must resolve WinPTY fidelity, the OpenSSH integration choice, and input/session
contracts. This brings SSH feasibility forward, not full Milestone 5 delivery.
Tests, privacy-aware diagnostics, dependency audits, and output-security policies
belong with each implementing change; Milestone 6 qualifies the assembled product.

Use the experiment IDs in the [validation backlog](doc/vt7/research/20-validation-and-experiments.md)
to connect decisions, implementations, and exact Windows 7 evidence. Research
recommendations and unchecked gates are not implemented or accepted features.

## Supported system target

The planned minimum target is:

- Windows 7 SP1 x64.
- The Windows 7 Platform Update, KB2670838.
- KB2533623 or a superseding servicing rollup that provides the required loader
  behavior.
- SHA-2 support and servicing prerequisites, including KB4474419 and KB4490628
  where applicable.
- The Universal C Runtime, KB2999226.
- .NET Framework 4.8 if the WPF host remains the selected application shell.
- A working Direct3D 11 graphics driver, with WARP used as a fallback where
  practical.

The final installer or portable package should detect missing prerequisites and
explain them in plain language. It must not fail with an unexplained missing
entry point or DLL error.

### Test tiers

| Tier | Configuration | Purpose |
| --- | --- | --- |
| A | Windows 7 SP1 x64 with the documented VT7 prerequisites | Required product floor |
| B | Windows 7 SP1 x64 with the final official client ESU servicing level | Fully serviced official client test |
| C | NT 6.1 systems carrying later Windows Server 2008 R2 Premium Assurance-derived updates through January 2026 | Additional compatibility coverage, not an official Windows 7 update path |
| D | Windows 7 virtual machines using WARP | Reproducible fallback and CI-oriented testing |

A release must pass Tier A. Other tiers expand confidence but do not silently
raise the minimum requirement.

Proofs 0.2.0 and 0.2.1 have been tested on fully updated non-ESU and fully ESU-updated
Windows 7 SP1 x64 setups. The non-ESU run has supplied logs and screenshots;
the ESU run is tester-confirmed. These establish the proof on the tested
configurations, not an exhaustive prerequisite-minimum or hardware matrix.
See the [original validation record](doc/vt7/validation/2026-09-10-viewport-proof.md)
and [0.2.1 acceptance](doc/vt7/validation/2026-09-10-milestone-1-cleanup.md).

## Shell and session targets

### Required for version 1.0

- Command Prompt.
- Windows PowerShell 5.1.
- PowerShell 7.0 through 7.2.24, with 7.2.24 treated as the primary PowerShell 7
  acceptance target.
- General Win32 console applications through the selected local PTY backend.
- Direct SSH sessions with remote PTY allocation and resize support.

PowerShell compatibility includes PSReadLine editing, history, completion,
prediction display, Ctrl+C, Unicode input and output, native child processes,
resize behavior, and clean shutdown. Merely launching `pwsh.exe` is not enough.

Shell versions, PSReadLine versions, runtimes, and prerequisites must be recorded
separately from VT7's host requirements. Compatibility goals do not imply current
vendor support. Version 7.2.24 is the primary PowerShell 7 gate; report tested
older versions individually rather than extrapolating one result to the range.

### Capability and fidelity contracts

Maintain a feature ledger distinguishing parser recognition, core representation,
rendering, host actions, and availability through each session backend. Record
tested, unavailable, and untested behavior separately. Terminal identity, device
replies, and environment hints must match the effective session capabilities.

- Core/renderer tests use deterministic direct input to prove UTF-8 decoding,
  Unicode/cell behavior, colors, and VT modes without local-console losses.
- Direct SSH must deliver remote terminal bytes without legacy screen-buffer
  reconstruction, with a real remote PTY and live dimension updates. An external
  SSH process is acceptable; an embedded library is not a requirement.
- Local sessions must meet the shell/application acceptance corpus. WinPTY is
  the first candidate, not an assumption of transparent arbitrary VT transport.
  Its reconstructed console stream cannot be used to claim every core feature.

If a required local workflow fails, investigate an alternative or adaptation and
record an explicit scope decision before closing the gate. Do not waive the
workflow merely because the first backend cannot carry it. Publish measured
backend-specific limits without reducing the renderer or direct-SSH targets.

## Milestone 0: Project foundation

- [x] Establish the VT7 name, voice, goal, and independent-project disclaimer.
- [x] Record the Microsoft Terminal baseline and upstream policy.
- [x] Define the Windows 7 compatibility floor and test tiers.
- [x] Replace inherited Microsoft support and contribution directions.
- [x] Disable inherited release, project-board, and repository-management
  automation.
- [x] Establish a minimal local VT7 build, verification, test, and packaging
  workflow. Hosted CI remains future work.

## Milestone 1: Proof of life

The purpose of this milestone is to prove that the product shape can work before
we invest in the complete interface.

- [x] Define and document the supported developer toolchain.
- [x] Produce a standalone x64 VT7 executable.
- [x] Start on Windows 7 SP1 without unresolved post-Windows 7 imports in the
  tested configurations.
- [x] Open the WPF desktop host on the development system and Windows 7.
- [x] Implement a native HWND terminal surface and exercise it on Windows 7.
- [x] Implement a static TerminalCore-backed viewport with a temporary GDI
  renderer, passing core regression checks and visible output on Windows 7.
- [x] Package a diagnostic build for clean-machine testing.

Exit criterion: a VT7 window opens on Tier A hardware and displays a correctly
sized static terminal viewport without requiring a global compatibility layer.

Milestone 1, including the 0.2.1 cleanup, is complete on the tested Windows 7
configurations. Seven core checks and four complete window lifecycles pass in
the supplied non-ESU logs; screenshots show the static viewport, and the tester
confirms the ESU setup works as well. This is not a release qualification of
every system at the prerequisite floor.

Completed cleanup before renderer work:

- [x] Correct low-contrast tab labels and diagnostic values in the WPF host
  (0.2.1).
- [x] Add effective-color regression coverage and native viewport tab-switch
  checks, passing on the development system and Windows 7.
- [x] Rerun the 0.2.1 package and visually recheck both tabs and keyboard focus
  on Windows 7. Non-ESU logs and screenshots pass; the tester confirms Tab and
  arrow-key navigation, focus outlines, and all tests passing on the ESU setup.

See the [cleanup validation notes](doc/vt7/validation/2026-09-10-milestone-1-cleanup.md)
for the regression reproduced before the fix, test scope, and final acceptance.

Device-creation probes do not validate Atlas, and the temporary GDI viewport
does not close any Milestone 2 rendering goals. Minimal-prerequisite snapshots,
additional hardware, and sustained stability remain part of release hardening.

## Milestone 2: Windows 7 renderer

Port the real Atlas rendering path without losing the tested TerminalCore/host
boundary. This is not just a swap-chain change: the renderer controller,
DirectWrite font mapping, native lifetime rules, and test harness also need work.

The [code assessment and acceptance plan](doc/vt7/architecture/2026-09-11-renderer-assessment.md)
records the reviewed source, documented platform limits, proposed decisions,
and unresolved experiments. The isolated Atlas library now compiles in Debug
and Release; the full engine's font port and integration remain unproven. The independent
[capability probe](doc/vt7/validation/2026-09-11-renderer-probe.md) passes locally
and on the tested Windows 7 SP1 x64 machine (49 required checks, zero failures).
It does not load Atlas, and cannot
close Atlas rendering or integration gates.

The next [backend experiment](doc/vt7/validation/2026-09-11-atlas-backend-proof.md)
now links and runs the real Atlas Direct3D11 and Direct2D backends with a shared
Windows 7 presentation adapter. Debug/Release hardware/WARP pixel tests pass
locally, and all four Release backend/device combinations pass on the tested
Windows 7 machine (19 frames each). Supplied screenshots show visible Direct3D11
output on hardware and WARP. Follow-up logs confirm eight hardware and six
WARP R-key recreations, each followed by successful presentation and clean exit.
This proves the fixed-glyph backend harness, not AtlasEngine font fallback or
TerminalCore integration. Separate ESU acceptance of this Atlas package is not
yet recorded; Milestone 1's ESU results do not substitute for it.

### 2A: Isolated build and capability baseline

- [x] Review the current Atlas, renderer-controller, font, host, and build paths
  and record confirmed dependencies separately from runtime questions.
- [x] Add an isolated VT7 renderer build using the pinned toolchain, explicit
  source/feature lists, and reproducible shader compilation. Do not import the
  complete upstream application build or silently change its baseline.
- [x] Audit the linked backend harness in Debug/Release and its assembled
  package, and validate that boundary on the tested Windows 7 machine.
- [ ] Extend the audit to the full engine's imports, runtime dependencies, and
  COM interface requests in Debug, Release, and the assembled package.
- [ ] Audit behavior as well as imports: flags, enum/metric values, interface
  methods, and resource ownership must work on the declared Windows 7 floor.
  Resolve the caret-blink metric assumption before cursor acceptance.
- [x] Add capability diagnostics for the actual graphics and font paths, with
  distinct required failures and optional-interface observations. The standalone
  probe passes on the development system and the tested Windows 7 setup.
- [x] Preserve the accepted 0.2.1 archive and keep GDI/core regressions passing
  through the isolated Atlas backend work.
- [ ] Add a selectable GDI reference path during Atlas/host integration and
  keep its regression checks passing.

Gate: an isolated, loadable renderer boundary with reviewed dependencies and
capability reports from Windows 7. Loading is not rendering acceptance.
This gate remains open: the full engine still needs font/runtime adaptation,
and a linked backend harness is not a load test of that full engine. The GDI proof and
accepted archive are preserved; selectable Atlas/GDI integration is still ahead.

### 2B: Windows 7 presentation path

Implementation checkpoint: `Win7Presentation` is shared by the AtlasEngine
presentation branch and the backend harness. It selects older device/context/
swap-chain interfaces, an opaque HWND discard/stretch target, and full redraw.
The harness tests exact pixels across four resize stages and device recreation;
its visible mode parks in the message loop without a periodic render timer.
The fixed-glyph presentation checkpoint now passes on the tested Windows 7
machine. Full controller scheduling and wider lifecycle acceptance remain open.

- [x] Replace mandatory newer graphics factory/device/context/swap-chain requirements
  with interfaces and methods supported by the Windows 7 Platform Update.
- [x] Use an opaque native HWND target, compatible bitblt swap effect, scaling,
  buffer count, and flags. Exclude the DirectComposition surface path.
- [ ] Remove mandatory frame-latency waitable objects and implement bounded,
  interruptible scheduling without busy-spinning while hidden or minimized.
- [x] Start with a correctly redrawn full frame and conservative presentation.
  Enable dirty-rectangle/scroll optimizations only after separate validation.
- [x] Exercise both an explicit hardware device and explicit WARP device in
  the backend harness, including resize, rejected zero-sized buffers,
  minimize/restore, and explicit target recreation.

Gate: actual Windows 7 frame presentation, resize, and recovery of a test target
on hardware and WARP. A cleared frame still does not prove Atlas text rendering.
The fixed-glyph backend proof now supplies that initial presentation evidence.
2B remains open for bounded interruptible controller scheduling; explicit
recreation does not establish automatic recovery from real device loss (2E).

### 2C: DirectWrite and glyph path

- [ ] Investigate the capability-probe font discrepancy: the Windows 7 run on
  2026-09-11 reported 8 runs, 2 faces, 60 glyphs, and 1 missing glyph, versus
  3 faces and no missing glyphs on the development system. Add character/cluster
  and selected-font diagnostics, identify the exact missing character, and
  distinguish installed-font coverage from mapping defects. Do not assume it
  is the supplementary sample character or treat this as Unicode acceptance.
- [ ] Remove mandatory newer font-fallback and font-face interfaces; prove a
  Windows 7-compatible font mapping/shaping path before settling its design.
- [ ] Evaluate retained `IDWriteTextLayout::Draw` callback runs first, comparing
  explicit family mapping/analyzer shaping if needed. Record correctness, font
  identity/lifetime, caching, and cost before selecting the adapter (F01/F02).
- [ ] Define the authoritative core-cell model and mappings among UTF-16,
  clusters, glyphs, cells, and pixels. Cursor, selection, hit testing, IME,
  accessibility, and session dimensions must share these contracts; their full
  interactive implementations remain in later milestones.
- [ ] Preserve cluster boundaries, fallback runs, cell allocation, baseline,
  decorations, and bold/italic variants. Test missing-family and missing-glyph
  behavior rather than treating successful Latin output as Unicode acceptance.
- [ ] Audit both Atlas backends, including Direct2D glyph rasterization used by
  BackendD3D. Replace unchecked interface assumptions with verified capabilities.
- [ ] Record which advanced font capabilities are available, gracefully absent,
  or deferred. Do not claim color-font or variable-font parity from first pixels.
- [ ] Record the inherited Unicode width/cluster and bidi-ordering policies.
  Preserve original text even when a glyph is missing. Use versioned font/corpus
  evidence; prefer tested static faces for any initial bundled-font evaluation.
  Color emoji, variable-font axes, and full bidi terminal behavior require
  separate scope decisions, not an implied promise inside Unicode support.

Gate: reproducible mixed-script glyph output with correct terminal-cell
placement on Windows 7; unresolved fallback cases remain explicitly recorded.

### 2D: TerminalCore-to-Atlas integration

- [ ] Integrate the real renderer controller and IRenderData path with Atlas.
  Keep the core/test fixtures consistent with the selected renderer type.
- [ ] Replace address-based waits in redraw/timers and synchronized output with
  Windows 7-safe synchronization, preserving deadlines and avoiding lost wakes.
- [ ] Define device/thread ownership, core locking, tab hide/show, and teardown.
  Stop rendering before releasing the HWND, core, engine, or device resources.
- [ ] Propagate actual font metrics, viewport size, invalidation, and settings
  through the native boundary; version any ABI changes in both native and host.
- [ ] Render the existing TerminalCore sample through Atlas and package the
  first Windows 7 text-rendering proof with unambiguous backend diagnostics.

Gate: the existing sample visibly rendered by Atlas on Windows 7, with its
backend and completed-frame evidence recorded. This is the first user-testable
Atlas viewport, not completion of Milestone 2.

### 2E: Fallback, lifecycle, and deterministic regression checks

- [ ] Add forced hardware/WARP modes and test automatic hardware-failure
  fallback. A GDI fallback must be reported and cannot pass an Atlas test.
- [ ] Replace GDI-only paint-count assumptions with bounded frame-completion
  checks; retain tab contrast, child-window lifetime, and core regression tests.
- [ ] Exercise resize/reflow, alternate-screen and cursor transitions, tab
  switching, expose/occlusion, minimize/maximize/restore, and repeated disposal
  using deterministic VT input without needing a session backend.
- [ ] Inject recoverable device/presentation failures and verify bounded retry,
  resource recreation, clean shutdown, and understandable terminal failure.
- [ ] Test wait/notify races, synchronized-output timeout, and teardown while
  rendering is idle, active, hidden, or recovering.

Gate: automated lifecycle/recovery suites pass with the requested backend;
fault injection is recorded separately from real driver/device-loss evidence.

### 2F: Visual and stability acceptance

- [ ] Verify hardware Atlas and forced-WARP text rendering on Windows 7, with
  logs and screenshots. Use the non-ESU setup for iteration and confirm the ESU
  setup at milestone acceptance, not by assuming equivalent behavior.
- [ ] Verify font fallback, accents/combining marks, wide and supplementary
  characters, ligatures, box drawing, colors, decorations, and cursor alignment.
- [ ] Test Windows 7 system-DPI configurations at 100%, 125%, and 150%, including
  WPF/native sizing and clipping. Treat newer per-monitor DPI separately.
- [ ] Verify Aero/basic and high-contrast behavior, keyboard focus, and readable
  host diagnostics without silently overriding explicit terminal colors.
- [ ] Run the quantified stress/idle checks in the acceptance plan, collect
  resource and frame-time measurements, and investigate continuing growth or
  unexplained rendering while idle. Record remaining coverage gaps honestly.
- [ ] Pass Debug/Release verification and tests, audit the complete portable
  package, and record the exact build, backend, environment, and results.

Exit criterion: real Atlas text rendering works on the tested Windows 7 hardware
and WARP paths and passes the lifecycle, font, DPI, theme, and stability checks
above without persistent corruption, hangs, or device-loss loops. First pixels,
a successful factory query, or a newer-Windows run alone cannot close this
milestone. Minimum-prerequisite/extended hardware release qualification remains
part of Milestone 6 and must not be claimed from the two existing test setups.

Out of scope: local shells, SSH, daily-driver UI expansion, upstream merging,
system DLL replacement, and modern composition effects. Early restrictions
must be documented, not silently turned into permanent product limitations.

## Milestone 3: Local interactive sessions

### 3A: Session feasibility and contracts

Run bounded experiments before committing to transport and input designs. These
do not require daily-driver tabs or a finished SSH interface.

- [ ] Characterize a pinned WinPTY native library/agent build (P01). Compare
  child console state, reconstructed bytes, and final core state for W/A console
  APIs, direct buffer writes, raw VT, code pages, colors, Unicode, alternate
  buffers, and resize. Select the local backend from that evidence.
- [ ] Evaluate a pinned Microsoft Win32-OpenSSH client first (S00), recording
  exact binaries/runtime hashes, Windows 7 configuration, and negotiated
  algorithms. Compare a known-good local-console run with direct byte I/O.
- [ ] Prove unmodified remote VT/UTF-8 bytes, initial/live PTY dimensions, prompt
  and diagnostic routing, trust decisions, and cancellation. `ssh -tt` and a
  successful login alone do not close S00. Never substitute commands typed into
  shell input for SSH window-change messages.
- [ ] Record the SSH architecture choice: unmodified external OpenSSH, a narrowly
  scoped maintained helper adaptation, or an embedded library if its structured
  control is a better fit. No dependency is selected solely by this roadmap.
  Document licensing, update responsibility, and reasons for rejecting alternatives.
- [ ] Test the inherited `ToUnicodeEx` helpers on Windows 7 (I01), especially
  dead keys and AltGr. Do not assume newer non-mutating flag semantics or merely
  clear the flag without checking keyboard-state effects.
- [ ] Define one session owner, per-session decoder/parser/input state, ordered
  writes including terminal replies, bounded queues/backpressure, coalesced
  resize generations, EOF/drain/exit distinctions, cancellation, and teardown.
  Hidden panes keep consuming output without presenting unnecessary frames.
- [ ] Separate committed text from non-text key metadata. Choose the IME input
  owner and composition/candidate geometry contract; define accessible text/range
  mapping before the UI depends on it. Implementations follow in 3C and 4.
- [ ] Define host-action policies before feeding real session output: bounded
  titles/OSC/DCS, explicit clipboard permissions, user-activated validated links,
  and untrusted working-directory metadata. Scope callbacks/replies to the
  originating session and reject stale work after close. Diagnostic replay must
  not perform desktop actions by default.

Gate: evidence-backed backend choices and written session/input/security contracts
exist before 3B or Milestone 4 construction. Record failed experiments and resolve
required capability gaps instead of marking them passed. S00 is architectural
feasibility, not full SSH acceptance or a promise to ship the evaluated release.

### 3B: Local backend integration

- [ ] Integrate the selected native local backend behind a replaceable boundary,
  preserving its lifecycle and ownership contracts without requiring Cygwin UI.
- [ ] Launch Command Prompt, Windows PowerShell 5.1, and PowerShell 7.2.24 with
  explicit executable, arguments, environment, working directory, and versions.
- [ ] Validate PSReadLine editing, history, completion, supported prediction,
  multiline prompts, and native children, using clean and ordinary profiles.
  Do not silently alter execution policy, user profiles, or global code pages.
- [ ] Propagate the authoritative grid to the child console during resize;
  compare results across code pages, long prompts, wide/combining text, and
  full-screen applications.
- [ ] Stream output through a persistent decoder and core (U01). Test every
  boundary of short UTF-8/VT fixtures, malformed/incomplete input, EOF, restart,
  and replies. The existing UTF-16 core tests do not prove byte-stream decoding.

Gate: required shells and representative native applications work end to end
with documented fidelity, not merely a visible prompt.

### 3C: Input and lifecycle acceptance

- [ ] Forward text, non-text keys, mouse, paste, focus, and control events once
  and in order through the session, not global keyboard injection. Test terminal
  modes, selection override, large/canceled paste, and Ctrl+C/Ctrl+Break.
- [ ] Implement and test the chosen IME path (I02): preedit stays local, committed
  text is sent once, candidate UI follows the caret, and tab/focus/resize/close
  transitions leave no stale composition. Record Windows 7 IME versions.
- [ ] Test US, Croatian, German, and a non-Latin keyboard layout, including
  AltGr, dead keys, repeats, modifier loss, and WPF/native focus routing (I01).
- [ ] Exercise spawn/read/write/resize cancellation, agent or child failure,
  final-output drain, restart, and forced termination (P02). Include child trees
  and inherited jobs; document Windows 7 containment/breakaway limits explicitly.
- [ ] Prove bounded shutdown and queue growth, no cross-session input/replies,
  no callbacks after destruction, and a responsive dispatcher under output.
- [ ] Add privacy-aware diagnostics and deterministic session/host-action
  regressions with the implementation. Do not log ordinary terminal content or
  credentials by default.

Exit criterion: all required local shells can be used for sustained interactive
work, including child applications, composed input, resize stress, and clean
exit. The 3A SSH decision is recorded; production SSH delivery remains Milestone 5.
Repeat backend-sensitive input and IME tests over direct SSH there.

## Milestone 4: Daily-driver interface

- [ ] Tabs and horizontal/vertical split panes, keeping session lifetime separate
  from transient WPF layout and respecting native HWND airspace. Search chrome
  and splitters must not rely on ordinary WPF overlays over the terminal.
- [ ] Profile creation/editing with explicit backend and executable selection,
  capabilities, and runtime requirements.
- [ ] Versioned UTF-8 JSON settings with validation, last-known-good recovery,
  recoverable replacement, concurrent-save handling, and explicit portable-mode
  behavior on Unicode/read-only paths (D01).
- [ ] Search, selection, copy, paste, and scrollback using the shared cell/text
  model. Decide literal/regex, case-folding, normalization, soft-wrap, and offset
  semantics before restoring search. Audit any selected dependency such as ICU;
  preserve original text and do not hold the core lock during long searches.
- [ ] Test cluster-safe selection/copy, reflow, clipboard contention, multiline
  and bounded/cancelable paste, and the separate OSC clipboard policy (C01).
- [ ] Configurable key bindings.
- [ ] Color schemes, fonts, cursor styles, and background settings.
- [ ] Session titles, activity indication, and close confirmation.
- [ ] Keyboard-only operation, visible focus, and a practical Windows 7
  accessibility baseline: native terminal text/ranges, selection and bounds,
  bounded notifications, and safe provider lifetime (A01). Accessible host
  controls alone do not satisfy terminal accessibility.
- [ ] Validate a Windows 7-compatible screen reader, live high-contrast/settings
  changes, no-blink caret preference, system-DPI geometry, and input focus during
  dialogs, pane switching, and active composition.

Exit criterion: the primary workflows no longer require a developer harness or
manual configuration edits.

## Milestone 5: First-class SSH

Deliver the architecture selected by 3A/S00. An external process with lossless
terminal I/O and a proven control path is a first-class implementation option.

- [ ] Integrate the selected implementation and pin its complete redistributable
  dependency set. Recheck security advisories, Windows 7 execution, licensing,
  release/support status, and the maintenance/update process before shipping.
- [ ] Implement host-key verification and recoverable known-host management.
  Separate unknown, changed, matching, and unreadable trust records; never
  silently accept a mismatch or continue authentication past a failed decision.
- [ ] Support password, private-key, passphrase, and agent authentication where
  the selected implementation permits it. Keep prompts/diagnostics distinct
  from remote terminal data; do not infer structured trust decisions from
  arbitrary localized terminal text. Protect secrets and exclude them from logs.
- [ ] Allocate the requested remote terminal type and dimensions.
- [ ] Send remote window-change messages for relevant grid changes, coalescing
  bursts but delivering the latest size. Verify remote dimensions, not only
  successful local writes.
- [ ] Handle stage-specific deadlines/cancellation, stalled peers, partial I/O,
  rekey under output, keepalives, EOF/close/exit status, and reconnection UX (S01).
  Never replay already-submitted input automatically on reconnection.
- [ ] Test `vim`, `htop`, `tmux`, `mc`, `less`, full-screen TUIs, mouse input,
  bracketed paste, Unicode, 256-color/true-color output, alternate-screen
  restoration, and the shared keyboard/IME/clipboard paths on Windows 7.

Exit criterion: SSH is a first-class VT7 connection type with lossless remote
terminal bytes, secure trust/authentication handling, initial/live PTY sizing,
and bounded lifecycle behavior. Neither a line-oriented redirected command nor
`ssh.exe` through legacy console reconstruction substitutes for this gate.

## Milestone 6: Alpha and beta hardening

- [ ] Qualify the complete product across a repeatable physical/virtual Windows 7
  matrix. Verify a clean minimum Tier A image without developer tools (L01),
  plus separately recorded ESU, WARP, and additional hardware coverage. Recheck
  prerequisite/dependency closure whenever a new runtime is introduced, not
  only at final packaging; shell requirements remain separate from host needs.
- [ ] Consolidate and extend the parser, buffer, renderer, input, settings, PTY,
  SSH, accessibility, and output-policy regression suites developed in each
  milestone. This is not their first implementation stage.
- [ ] Verify opt-in diagnostic privacy, redaction, exact run/package manifests,
  and bounded resource behavior across the assembled product.
- [ ] Add crash reporting artifacts that users can attach manually.
- [ ] Measure startup, memory, active/hidden/minimized CPU, input-to-present
  latency, queue/cache growth, and sustained output against budgets established
  on target hardware. Extend earlier per-milestone measurements.
- [ ] Test long-running sessions and repeated tab and pane creation.
- [ ] Produce signed or checksum-verifiable portable release artifacts.
- [ ] Document installation, prerequisites, recovery, and uninstallation.

## Version 1.0 acceptance bar

VT7 1.0 is complete only when all of the following are true:

- It installs or runs portably on a clean Tier A system with understandable
  prerequisite handling.
- It does not require modified system files, a system-wide compatibility layer,
  MSIX, the Microsoft Store, or ConPTY.
- Command Prompt, Windows PowerShell 5.1, and PowerShell 7.2.24 pass the local
  session acceptance suite.
- Direct SSH supports secure host-key verification, authentication, remote PTY
  creation, live resize updates, and unmodified remote terminal byte delivery.
- Tabs, panes, profiles, settings, search, selection, clipboard, and scrollback
  are dependable enough for daily work.
- Core/renderer acceptance proves streaming UTF-8, wide/combining text, box
  drawing, indexed/true color, and VT state with deterministic fixtures and
  versioned font evidence. Missing glyphs must not corrupt original text.
- Direct SSH independently passes end-to-end Unicode, 256-color/true-color,
  mouse, bracketed-paste, alternate-screen, and resize tests on compatible
  remote applications.
- Local-console acceptance independently passes the required shell/native-app
  corpus, input/IME, colors and text preserved by the selected console path,
  interrupts, resize, and clean shutdown. The capability ledger publishes
  measured transport limits; unresolved required workflow failures block
  acceptance until fixed or explicitly reconsidered, not silently waived.
- Selection, copy, search, IME geometry, and native accessible text agree with
  the core's cells and original text. Output-triggered host actions obey tested
  trust policies and cannot cross session boundaries.
- The renderer works with a supported Direct3D 11 driver and has a documented
  fallback path.
- Full-screen applications survive repeated resize, maximize, restore, and
  alternate-screen exit without lasting display corruption.
- Failures produce actionable diagnostics instead of silent exits.
- Licensing and provenance are complete for every shipped component.

## Deliberate non-goals for version 1.0

- Exact feature or UI parity with current Windows Terminal.
- MSIX, Microsoft Store, WinGet, or Windows shell registration that depends on
  post-Windows 7 deployment services.
- ConPTY implementation for the operating system.
- Replacement of the built-in Windows console host.
- Mica, acrylic, modern DirectComposition effects, or Windows 11 integration.
- x86, ARM, or ARM64 builds.
- Guaranteed support for PowerShell 7.3 or newer.
- Making Windows 7 a supported or secure operating system again.

## Beyond version 1.0

Possible later work includes serial connections, additional SSH features,
session restoration, quake mode, shell integration, richer accessibility,
plugin interfaces, and other architectures. These should not distract from
shipping a trustworthy Windows 7 terminal first.

Color emoji rendering, variable-font axis control, full bidirectional terminal
behavior, and richer local-console transport are separate evaluation tracks.
None is automatically included in the Unicode claim or permanently ruled out
by an initial proof restriction. Record a scope/design decision before promising
them for a release; preserve the baseline accessibility and local workflows above.
