# Milestones 0 and 1: foundation and proof of life

[Roadmap](../../../ROADMAP.md) | [Documentation](../README.md)

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
I invest in the complete interface.

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
the supplied non-ESU logs; screenshots show the static viewport, and I confirm the ESU setup works as well. This is not a release qualification of
every system at the prerequisite floor.

Completed cleanup before renderer work:

- [x] Correct low-contrast tab labels and diagnostic values in the WPF host
  (0.2.1).
- [x] Add effective-color regression coverage and native viewport tab-switch
  checks, passing on the development system and Windows 7.
- [x] Rerun the 0.2.1 package and visually recheck both tabs and keyboard focus
  on Windows 7. Non-ESU logs and screenshots pass; I confirm Tab and
  arrow-key navigation, focus outlines, and all tests passing on the ESU setup.

See the [cleanup validation notes](../validation/2026-09-10-milestone-1-cleanup.md)
for the regression reproduced before the fix, test scope, and final acceptance.

Device-creation probes do not validate Atlas, and the temporary GDI viewport
does not close any Milestone 2 rendering goals. Minimal-prerequisite snapshots,
additional hardware, and sustained stability remain part of release hardening.

