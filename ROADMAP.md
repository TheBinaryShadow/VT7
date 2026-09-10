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

Proof 0.2.0 has been tested on fully updated non-ESU and fully ESU-updated
Windows 7 SP1 x64 setups. The non-ESU run has supplied logs and screenshots;
the ESU run is tester-confirmed. These establish the proof on the tested
configurations, not an exhaustive prerequisite-minimum or hardware matrix.
See the [validation record](doc/vt7/validation/2026-09-10-viewport-proof.md).

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

The Milestone 1 technical proof has been reached on the tested Windows 7
configurations. Seven core checks and four complete window lifecycles pass in
the supplied non-ESU logs; screenshots show the static viewport, and the tester
confirms the ESU setup works as well. This is not a release qualification of
every system at the prerequisite floor.

Follow-up before renderer work:

- [ ] Correct low-contrast tab labels and diagnostic values in the WPF host.
- [ ] Add style regression coverage and recheck both tabs visually on Windows 7.

Device-creation probes do not validate Atlas, and the temporary GDI viewport
does not close any Milestone 2 rendering goals. Minimal-prerequisite snapshots,
additional hardware, and sustained stability remain part of release hardening.

## Milestone 2: Windows 7 renderer

- [ ] Restore a Windows 7-compatible Atlas device and swap-chain path.
- [ ] Use the DirectX interfaces supplied by the Windows 7 Platform Update.
- [ ] Remove the frame-latency waitable-object dependency.
- [ ] Restore a safe fallback for presentation timing.
- [ ] Use Windows 7-compatible scaling, buffer flags, and resize behavior.
- [ ] Support Direct3D 11 hardware rendering.
- [ ] Support WARP fallback where practical.
- [ ] Verify font fallback, DPI changes, high contrast, and window resizing.

Exit criterion: the renderer survives repeated resize, maximize, restore,
minimize, DPI, and alternate-screen transitions without corruption or device
loss loops.

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
