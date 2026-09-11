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
and unresolved experiments. Source review is complete; Atlas compilation and
runtime feasibility are not yet proven. No implementation checkbox below is
closed by the existing device-creation probes.

### 2A: Isolated build and capability baseline

- [x] Review the current Atlas, renderer-controller, font, host, and build paths
  and record confirmed dependencies separately from runtime questions.
- [ ] Add an isolated VT7 renderer build using the pinned toolchain, explicit
  source/feature lists, and reproducible shader compilation. Do not import the
  complete upstream application build or silently change its baseline.
- [ ] Audit normal imports, delay-loaded/runtime dependencies, and mandatory
  COM interface requests in Debug, Release, and the assembled package.
- [ ] Add capability diagnostics for the actual graphics and font paths, with
  useful failures when prerequisites or interfaces are missing.
- [ ] Preserve the 0.2.1 package and a selectable GDI reference path. Keep its
  regression checks passing during integration.

Gate: an isolated, loadable renderer boundary with reviewed dependencies and
capability reports from Windows 7. Loading is not rendering acceptance.

### 2B: Windows 7 presentation path

- [ ] Replace mandatory newer factory/device/context/swap-chain requirements
  with interfaces and methods supported by the Windows 7 Platform Update.
- [ ] Use an opaque native HWND target, compatible bitblt swap effect, scaling,
  buffer count, and flags. Exclude the DirectComposition surface path.
- [ ] Remove mandatory frame-latency waitable objects and implement bounded,
  interruptible scheduling without busy-spinning while hidden or minimized.
- [ ] Start with a correctly redrawn full frame and conservative presentation.
  Enable dirty-rectangle/scroll optimizations only after separate validation.
- [ ] Exercise both an explicit hardware device and explicit WARP device,
  including resize, zero-sized/minimized windows, and target recreation.

Gate: actual Windows 7 frame presentation, resize, and recovery of a test target
on hardware and WARP. A cleared frame still does not prove Atlas text rendering.

### 2C: DirectWrite and glyph path

- [ ] Remove mandatory newer font-fallback and font-face interfaces; prove a
  Windows 7-compatible font mapping/shaping path before settling its design.
- [ ] Preserve cluster boundaries, fallback runs, cell allocation, baseline,
  decorations, and bold/italic variants. Test missing-family and missing-glyph
  behavior rather than treating successful Latin output as Unicode acceptance.
- [ ] Audit both Atlas backends, including Direct2D glyph rasterization used by
  BackendD3D. Replace unchecked interface assumptions with verified capabilities.
- [ ] Record which advanced font capabilities are available, gracefully absent,
  or deferred. Do not claim color-font or variable-font parity from first pixels.

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

- [ ] Select and integrate the WinPTY-based local session backend.
- [ ] Launch Command Prompt, Windows PowerShell 5.1, and PowerShell 7.2.24.
- [ ] Forward keyboard, mouse, paste, focus, and control events correctly.
- [ ] Propagate terminal resize operations to the child console.
- [ ] Handle process exit, restart, cancellation, and forced termination safely.
- [ ] Stream bytes without corrupting split UTF-8 sequences.
- [ ] Validate interactive native applications, not only shells.

Exit criterion: all required local shells can be used for sustained interactive
work, including child applications, resize stress, and clean exit.

## Milestone 4: Daily-driver interface

- [ ] Tabs.
- [ ] Horizontal and vertical split panes.
- [ ] Profile creation and editing.
- [ ] JSON settings with safe recovery from invalid configuration.
- [ ] Search, selection, copy, paste, and scrollback.
- [ ] Configurable key bindings.
- [ ] Color schemes, fonts, cursor styles, and background settings.
- [ ] Session titles, activity indication, and close confirmation.
- [ ] Keyboard-only operation, visible focus, and a practical Windows 7
  accessibility baseline.

Exit criterion: the primary workflows no longer require a developer harness or
manual configuration edits.

## Milestone 5: First-class SSH

- [ ] Select a redistributable SSH implementation with a sustainable security
  update story.
- [ ] Implement host-key verification and known-host management.
- [ ] Support password, private-key, passphrase, and agent authentication where
  the selected library permits it.
- [ ] Allocate the requested remote terminal type and dimensions.
- [ ] Send remote window-change messages on every relevant resize.
- [ ] Handle disconnection, reconnection UX, keepalives, and error reporting.
- [ ] Test `vim`, `htop`, `tmux`, `mc`, `less`, full-screen TUIs, mouse input,
  and alternate-screen restoration.

Exit criterion: SSH is a native VT7 connection type, not a fragile wrapper
around line-oriented redirected pipes.

## Milestone 6: Alpha and beta hardening

- [ ] Build a repeatable physical and virtual Windows 7 test matrix.
- [ ] Add parser, buffer, renderer, settings, PTY, and SSH regression tests.
- [ ] Create opt-in diagnostic logging with clear privacy behavior.
- [ ] Add crash reporting artifacts that users can attach manually.
- [ ] Measure startup time, memory use, idle CPU use, rendering latency, and
  sustained-output behavior.
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
  creation, and live resize updates.
- Tabs, panes, profiles, settings, search, selection, clipboard, and scrollback
  are dependable enough for daily work.
- Streaming UTF-8, wide characters, combining characters, box drawing,
  256-color, true-color, mouse input, bracketed paste, and alternate screens
  behave correctly.
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
