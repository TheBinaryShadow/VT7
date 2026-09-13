# Milestone 1 cleanup, proof 0.2.1

> Historical validation record. Status and next steps below describe this checkpoint.
> For current work, see the [handoff](../HANDOFF.md) and
> [0.3.5 C3 stability investigation](2026-09-13-atlas-stability.md).

## Outcome

Milestone 1 is complete on the tested Windows 7 SP1 x64 configurations. The
0.2.1 non-ESU logs and screenshots confirm the cleanup; the tester also confirms
keyboard navigation, visible focus, and all tests passing on the separate
fully ESU-updated setup. This is a static viewport proof, not an interactive
terminal release or qualification of the full prerequisite/hardware matrix.

## Scope

This patch finishes the implementation follow-up to the successful Windows 7
0.2.0 static viewport proof. It changes WPF styling and test coverage, not the
TerminalCore implementation, native ABI 2 layout, toolchain, or upstream
baseline. Atlas, sessions, and upstream merges remain out of scope.

- Diagnostic styles inherit the base text style and have an explicit light
  foreground.
- Proof tab headers use paired dark backgrounds/light text, distinct selected
  styling, and a keyboard-focus outline instead of OS tab chrome with
  application-wide text colors.
- The existing smoke test now visits both tabs at large and small window sizes.
  It validates effective text colors and native child-window restoration.
- The versioned 0.2.1 package preserves the earlier proof packages.

## Regression evidence

The new live-WPF contrast check was run before applying the style correction.
It failed on `VersionValue`: foreground `#152A3A` against background `#182533`,
measuring 1.05:1 against the test's minimum 4.5:1. All seven core checks still
passed. This reproduces the reported host defect independently of the core.

After correction, Debug, Release, and assembled-package tests pass with a
minimum measured contrast of 10.81:1 across the ten diagnostic values and both
tab-header selection states.
The guard inspects effective brushes in the live visual tree, not only the
resource declarations. It requires opaque solid brushes and does not model
pixel-level font rendering, clipping, or every accessibility setting.

Four window lifecycles each include two diagnostic/viewport round trips, one
at the large size and one at the small size. Each round trip verifies that the
child HWND survives while hidden, returns visible with the same handle and grid
dimensions, and increments its paint count. Existing resize, minimize/restore,
reset, and disposal checks remain enabled. The harness reports eight completed
round trips and four completed cycles; the test script requires both counts.

Development environment: Windows NT 10.0.19044 x64, .NET Framework 4.8.9339.0,
AMD Radeon RX 7900 XTX. This is not the Windows 7 acceptance environment.
Both configurations build successfully and pass the static import verification.
The Release package includes the app-local runtime, licenses, provenance, and
symbols. Its assembled binaries pass the same diagnostics and window checks
before archiving as `artifacts/VT7-viewport-proof-0.2.1-x64.zip`.

Local reports are under `artifacts/vt7/reports/<configuration>/`:

- `diagnostics.log`
- `window-smoke-test.log`

The failing regression evidence is retained separately at
`artifacts/vt7/reports/Debug/contrast-before-fix.log`.

## Windows 7 acceptance

Initial automated desktop visual QA could not be completed: window discovery
misidentified VT7 as Power Automate and rejected the window binding. No sign-in
or installer prompts were accepted. Automated built-in checks do not depend
on Power Automate. The tester subsequently supplied Windows 7 screenshots and
manual acceptance, closing the visual-check gap for this proof.

### Supplied non-ESU evidence

The tester supplied six log files from the normally updated, non-ESU setup:

- `VT7-diagnostics.log` and `proof-20260910-211129.log`, reporting the same
  headless diagnostics run.
- `VT7-viewport-test.log` and `proof-20260910-211139.log`, reporting the same
  window smoke-test run.
- `proof-20260910-211140.log` and `proof-20260910-211148.log`, additional
  probe reports with native surface information.

All six report `Passed: True` and `Error: None`. They identify Release x64
0.2.1, native ABI 2, MSVC compiler 19.44.35228, and build timestamp
September 10, 2026, 20:56:16. The system reports Windows NT 6.1.7601 SP1 x64,
.NET Framework 4.8.4795.0, and an AMD Radeon RX 6800 XT. Hardware D3D11 and
WARP device creation pass at feature level 11.0; DXGI 1.2 is available.

All seven TerminalCore checks pass. The window test completes eight tab round
trips, preserving the child HWND/grid and verifying repaint, with a minimum
measured contrast of 10.81:1. All four lifecycles pass with a 74 x 10-cell grid,
22 paints, and 15 resizes each, including the disposal checks.

`Capture.PNG` shows the 105 x 21-cell static viewport, its demonstration, and
readable tab labels. `Capture2.PNG` shows readable diagnostic values and the
selected Diagnostics tab. The last probe report matches that visible viewport
size. These screenshots confirm the reported contrast correction, not full
font/shaping or accessibility coverage.

### Manual confirmation and ESU coverage

The tester confirms that Tab navigation, arrow-key tab switching, and the focus
outline work. Buttons show a bluish animated focus indication when tabbed to.
The tester also explicitly reran 0.2.1 on the separate fully ESU-updated setup
and reported that all tests pass and all is well. This is a fresh ESU test
confirmation, not an inference from the successful non-ESU run. Separate ESU
logs and an exact update inventory were not supplied.

The 0.2.1 runtime, style, tab-switch, and manual keyboard/focus acceptance checks
are therefore closed on the tested setups. No code change was needed after
this acceptance run, and the tested archive was not regenerated to record it.
Minimal-prerequisite snapshots, additional hardware/DPI/high-contrast coverage,
long-running stability, Atlas rendering, and interactive sessions remain future
work under the roadmap.
