# Compatibility and project principles

[Roadmap](../../../ROADMAP.md) | [Documentation](../README.md)

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
9. Reuse pinned upstream behavior first. Adapt incompatible Windows 7 boundaries
   without making enhanced typography or other optional improvements prerequisites.
10. Fix blockers in their owning milestone; record non-blocking ideas in
    Milestone 7 for bounded polish triage or explicit post-release work.

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
  VT7 0.10.1 pins SSH.NET `2026.0.1-prerelease.6` from upstream commit
  `f099365`, which resets receive-MAC state on older .NET Framework builds. The
  non-ESU `mscorlib.dll` `4.8.4110.0` configuration is an explicit Tier A test,
  not an excluded servicing level.
- A working Direct3D 11 graphics driver, with WARP used as a fallback where
  practical.

KB3191566 / Windows Management Framework 5.1 is not a product prerequisite.
VT7 should discover the installed Windows PowerShell version and offer only
profiles actually present. A Windows 7 SP1 x64, .NET Framework 4.8 machine
retaining PowerShell 2.0 is the [pre-WMF test tier](../validation/2026-09-24-pre-wmf51-windows7.md).

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

LEOPARD confirms that Tier A's Command Prompt and SSH runtime scope also works
on a pre-WMF 5.1 installation with PowerShell 2.0 and no system OpenSSH. Its
six-stage baseline and live typed/direct SSH checks pass, including resize,
disconnect, `htop` and `nano`. The PowerShell 2.0 interactive profile is not
yet qualified. Keep this product-runtime result separate from the existing
PowerShell 5.1-specific automated corpus; passing the latter is not required
to launch VT7 on a machine without WMF 5.1.

The KH01.2 package 0.2 comparison found that local VT7 operation and the complete
offline known-host corpus pass on both tiers, while SSH.NET 2026.0.0 fails during
MAC-protected connection setup on `mscorlib.dll` `4.8.4110.0`. The same machine
connects with Win32-OpenSSH. This matches upstream issue 1829. Package 0.3 adopts
the publisher-built `.6`/`f099365` correction. Its automated corpus and both
stored-key live paths pass on NESSY (`4.8.4110.0`) and TURTLE (`4.8.4795.0`),
accepting ordinary .NET Framework 4.8 as the compatibility boundary.

Proofs 0.2.0 and 0.2.1 have been tested on fully updated non-ESU and fully ESU-updated
Windows 7 SP1 x64 setups. The non-ESU run has supplied logs and screenshots;
the ESU run is confirmed in my testing. These establish the proof on the tested
configurations, not an exhaustive prerequisite-minimum or hardware matrix.
See the [original validation record](../validation/2026-09-10-viewport-proof.md)
and [0.2.1 acceptance](../validation/2026-09-10-milestone-1-cleanup.md).

## Shell and session targets

### Required for version 1.0

These are shell compatibility targets when the shell is installed, not a list
of shells that every VT7 machine must install.

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
- Local sessions must meet the shell/application acceptance corpus. P01 selects
  WinPTY 0.4.3 for Windows 7 legacy-console sessions behind a replaceable
  boundary. Its reconstructed console stream cannot be used to claim transparent
  arbitrary VT transport or every core feature.

If a required local workflow fails, investigate an alternative or adaptation and
record an explicit scope decision before closing the gate. Do not waive the
workflow merely because the first backend cannot carry it. Publish measured
backend-specific limits without reducing the renderer or direct-SSH targets.

