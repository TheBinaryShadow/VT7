# Windows 7 viewport proof results, 2026-09-10

## Result and scope

VT7 proof 0.2.0 runs its real TerminalCore-backed native viewport on Windows 7
SP1 x64. The tester confirmed two separate, fully updated setups as working
and tested: one without ESU, and one with the full ESU update set.

The supplied logs and screenshots are from the non-ESU setup. The ESU result is
recorded from the tester's explicit confirmation, not inferred from the
non-ESU result or from an assumption that security updates cannot affect
compatibility. Separate ESU logs were not supplied with this evidence set.

The Milestone 1 technical proof has been reached on these tested
configurations. This is a static viewport proof, not an alpha terminal release
or a claim that every Windows 7 hardware/prerequisite combination is validated.

## Evidence received

- `VT7-diagnostics.log`: headless platform, graphics, and core regression report.
- `VT7-viewport-test.log`: aggregate native-window lifecycle report.
- `proof-20260910-121633.log`: duplicate of `VT7-diagnostics.log`.
- `proof-20260910-121650.log`: duplicate of `VT7-viewport-test.log`.
- `proof-20260910-121651.log` and `proof-20260910-121652.log`: per-window probe
  snapshots during the automated test, showing a 74 x 11-cell viewport.
- `proof-20260910-121659.log`: visual-host probe snapshot showing a
  105 x 22-cell viewport.
- `Capture.PNG`: the visible static terminal demonstration.
- `Capture2.PNG`: the diagnostic tab, including its contrast defect.

All seven log files report `Passed: True` and `Error: None`. The duplicate
reports and snapshots must not be counted as seven independent test runs.
Capture timestamps span approximately 26 seconds, not an extended stability
test. This document summarizes the evidence without committing private local
paths, original logs, or screenshots containing desktop details.

## Non-ESU configuration observed

| Item | Result |
| --- | --- |
| VT7 build | 0.2.0, Release x64, build timestamp Sep 10 2026 12:01:16 |
| Native boundary | ABI 2, matching the managed host |
| Compiler | MSVC 19.44.35228 |
| Operating system | Windows NT 6.1.7601, SP1, 64-bit workstation |
| Update tier | Fully updated without ESU, identified by the tester |
| Managed runtime | .NET Framework 4.8.4795.0 |
| Graphics adapter | AMD Radeon RX 6800 XT, approximately 16 GiB dedicated memory |
| Hardware D3D11 | Device creation passed, feature level 11.0 |
| WARP D3D11 | Device creation passed, feature level 11.0 |
| DXGI 1.2 | Available through `IDXGIFactory2` |
| Visual viewport | 105 x 22 cells, 9 x 19 pixels per cell |

The update tier is tester-provided metadata; the probe does not enumerate
installed updates. Exact KB inventories, graphics driver versions, CPU,
display scaling, and a compatibility-modification inventory were not supplied.
Hardware and runtime details above must not be attributed to the separate ESU
setup without its own record.

## Automated results

All seven focused core checks pass against the inherited implementation:

1. VT cursor movement and erase.
2. True-color and indexed SGR attributes.
3. Wide and combining Unicode cell allocation.
4. Alternate-screen restoration of the main buffer.
5. Resize and reflow preserving text.
6. VT sequences split across writes.
7. Windows 7 SRW-backed core lock contention.

The aggregate viewport report records four successful WPF/native-window
lifecycles. Each finishes at 74 x 11 cells with 18 paints and 15 resizes. The
harness exercises repeated size changes, minimize/restore, sample reset, and
native child-window destruction. Passing these checks does not establish leak
freedom under sustained use or validate the appearance of the hidden windows.

## Visual result and open defect

The first screenshot confirms that the static viewport visibly draws sample
text, the standard/bright palette, a 256-color ramp, true-color text, bold,
underline, reverse video, accented/Greek/combining/CJK samples, and box drawing.
This is useful visual evidence, not comprehensive Unicode or shaping coverage.

Both screenshots expose a WPF styling defect: pale tab labels lack contrast on
light tab backgrounds, and diagnostic values are nearly invisible on their
dark panels. The current `ValueText` style does not set a foreground or inherit
the implicit text style, so those values inherit the tab's dark foreground.
The implicit light text style also conflicts with the light tab headers.

This defect affects the host UI, not the stored diagnostic values or the core
regression results. Use the text logs for readable diagnostics. The defect is
still present in 0.2.0; a styling correction, regression coverage, and Windows 7
visual recheck are the next small follow-up.

## What remains unproven

- A clean snapshot containing only the exact minimum prerequisites, rather than
  a fully serviced test installation.
- Additional hardware, driver, VM, DPI, and high-contrast configurations.
- Full font fallback, complex shaping, emoji, and production text quality.
- Atlas, Direct3D presentation, and renderer-level WARP fallback. The viewport
  uses GDI; the successful Direct3D results are device-creation probes only.
- Local PTY sessions, PowerShell acceptance, SSH, and the daily-driver UI.
- Long-running performance, memory/resource stability, and input stress.

The non-ESU and ESU outcomes remain distinct test results. Neither expands the
project's operating-system prerequisites or turns the proof into a security
or support guarantee for Windows 7.
