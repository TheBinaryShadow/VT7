# Building VT7

VT7 currently builds a static Atlas viewport proof (0.3.5): a WPF desktop
host, native HWND surface, the real Microsoft Terminal core/VT parser, AtlasEngine
and renderer controller with a minimum Windows 7 font adapter.
It displays a fixed demonstration and resizes the actual text buffer. It does
not yet run shells or SSH sessions.

The solution also builds an independent capability probe and an Atlas backend
proof (0.1). The latter renders fixed glyphs through real Atlas backends and
has passed automated Windows 7 hardware/WARP tests plus visible Direct3D11
checks. It remains separate from the integrated host. The supplied 0.3.0 Windows 7
run accepted the bounded full-engine C1/C2 path. The integrated 0.3.4 correction
now passes the supplied actual 100%, 125% and 150% system-DPI matrix; broader
renderer acceptance remains separate.

For what to build next, use the [port-first checkpoints](doc/vt7/architecture/2026-09-12-port-first-plan.md)
and [roadmap](ROADMAP.md). The commands below reproduce existing proofs; they
do not require extending every probe before application integration. The
[0.3.0 validation record](doc/vt7/validation/2026-09-12-atlas-viewport.md) records
the initial Windows 7 C1/C2 acceptance. The current
[0.3.4 validation record](doc/vt7/validation/2026-09-12-atlas-scaling-correction.md)
separates local checks, accepted target scaling results and remaining C3 coverage.

## Scheduling and stability checks

The [0.3.5 scheduling/stability record](doc/vt7/validation/2026-09-13-atlas-stability.md)
defines the next test slice. Use `tools/Test-VT7AtlasStability.ps1` for quick
hardware/WARP checks, add `-Lifecycle` for 100/1000/500 lifetime/resize/tab counts,
or `-Soak` for that matrix plus the 30-minute active/10-minute idle run per backend.
All accept `-Configuration Debug|Release` and `-BinaryDirectory` like the other
integrated tests. Progress logs survive a runner timeout. Quick passes do not
replace the extended Windows 7 acceptance run.

The 0.3.5 package is an investigation candidate: hardware passes the 100-cycle
profile locally and on the supplied Windows 7 setup, but WARP exceeds its
resource budget on both. Package creation runs the quick regression gate, not
full stability acceptance. Keep the timed soak on hold while this is isolated.
`-Renderer atlas-d3d-hardware|atlas-d3d-warp` selects one backend for investigation.

Current source also contains opt-in `--resource-isolation` controls, documented
in the stability record. They are not present in the already-issued 0.3.5 zip
and are not acceptance profiles. No input or security feature is disabled by
the retained controls. Preserve the issued archive when building diagnostics.

The separate `VT7-resource-comparison-0.1-x64.zip` tests native Atlas WARP with
and without matched Windows power-notification subscriptions. It reuses the
issued 0.3.5 native DLL, runtimes and fonts; its `VT7.Host.exe` is a native-only
diagnostic, not the WPF application. Extract it into a fresh folder and run
`RUN-RESOURCE-COMPARISON.cmd`. Return the complete new
`Logs/resource-comparison-<run-id>` folder. Exit 0 means both measurements
completed, not that growth was accepted. Both supplied Windows 7 runs complete,
but both grow, unlike the development machine's power/plain contrast. Preserve
this result without treating the notification explanation as target-proven.
This is not a soak and needs no security exclusions or system-setting changes.
See the stability record for package identity, results and the next bounded
thread-lifetime investigation. No repeat of this unchanged package is requested.

## Pinned developer toolchain

The proof build is intentionally narrow and reproducible:

- Windows x64 development machine.
- Visual Studio 2022, version 17.14.
- MSVC v143, version 14.44.35207.
- Windows SDK 10.0.26100.0.
- .NET Framework 4.8 SDK and targeting pack.
- PowerShell 5.1 or newer to run the build scripts.

The repository rejects another MSVC or Windows SDK version for VT7 projects.
This keeps compiler and import changes visible while the Windows 7 floor is
being established. Visual Studio 2026 is not part of the supported VT7 build
path.

The checked-in [.vsconfig](.vsconfig) describes the required Visual Studio
components. It does not install the toolchain silently.

## Build

From a PowerShell prompt in the repository root:

```powershell
.\tools\Build-VT7.ps1 -Configuration Debug
```

For the portable proof package:

```powershell
.\tools\Package-VT7Proof.ps1
```

The build script restores pinned WIL, GSL, and fmt headers from GitHub and
verifies their archive hashes. Internet access is needed on the first restore.
Dependency revisions, licensing, and proof-only source changes are documented
in [the core boundary notes](src/vt7/VT7.Core/README.md). After a verified restore,
`-NoRestore` permits an offline build using the existing extracted sources.

Build output is written under `artifacts\vt7\bin`. The packaging script creates
`artifacts\atlas-viewport-0.3.5` and `artifacts\VT7-atlas-viewport-0.3.5-x64.zip`.
Accepted 0.3.0 artifacts are preserved unchanged.
It tests the assembled package before archiving it and includes runtime DLLs,
symbols, notices, dependency licenses, and file checksums. Generated artifacts
are ignored by Git. Older proof packages, including accepted 0.2.1, are not overwritten.

## Verify the binary boundary

The solution also builds the Milestone 2 `VT7.Renderer.lib` isolated target
and independent `VT7.RendererProbe.exe`. The library now links into VT7.Native,
with the real AtlasEngine/controller/font path and a selectable GDI reference.
The older backend harness remains independently testable. See the
[renderer boundary](src/vt7/VT7.Renderer/README.md).

To test and package the independent graphics/font probe:

```powershell
.\tools\Test-VT7RendererProbe.ps1 -Configuration Debug
.\tools\Build-VT7.ps1 -Configuration Release -NoRestore
.\tools\Test-VT7RendererProbe.ps1 -Configuration Release
.\tools\Package-VT7RendererProbe.ps1 -SkipBuild
```

The current archive is `artifacts\VT7-renderer-probe-0.13-x64.zip`. Extract it on Windows 7,
run `RUN-RENDERER-PROBE.cmd`, and retain `VT7-renderer-probe.log` and the companion
`VT7-renderer-probe.log.bmp`. Version 0.5 preserves the original 0.1 sample and
includes an independent U+1F600 coverage scan, explicit candidate rendering, thirteen
real-core-cell fixtures, whole-ink fitting, and retained Arabic visual runs.
Natural-size glyphs use a bounded two-pixel ink halo at the probe's fixed 96 DPI;
oversized groups remain strictly fitted. Cell allocation never changes.
The bitmap compares natural layout with an experimental fitted visual-run path;
structural mapping success is not visual or bidi acceptance. It uses hidden
graphics windows and offscreen readback, not a visible terminal. Optional newer
interfaces may be unavailable without failing the baseline. The native probe
does not require .NET or Power Automate. Keep the complete `fonts` directory:
the build/package copies pinned Unifont and Unifont Upper 17.0.05 with their
OFL 1.1 license and provenance. These are private probe assets, not system-installed
fonts or a change to VT7's MIT code license. `tools/Verify-VT7Fonts.ps1` checks
their hashes. Missing or altered assets fail the diagnostic.

`Verify-VT7.ps1` audits the probe when present. For its assembled package, use
`-Configuration Release -RendererProbeOnly -BinaryDirectory <package-folder>`;
this checks all packaged EXE/DLL files and requires the app-local CRT files.
The [probe validation record](doc/vt7/validation/2026-09-11-renderer-probe.md)
records the successful original 0.1 local and supplied Windows 7 capability runs.
The [2C font experiment record](doc/vt7/validation/2026-09-11-font-mapping-probe.md)
tracks the supplied Windows 7 0.2 results separately. The
[0.3 follow-up](doc/vt7/validation/2026-09-11-font-fitting-probe.md) records the
supplied Windows 7 run and user confirmation that KB2729094 is installed. The
[0.4 follow-up](doc/vt7/validation/2026-09-11-natural-size-probe.md) tracks natural-size
fitting and its supplied Windows 7 result. The
[0.5 follow-up](doc/vt7/validation/2026-09-11-private-font-probe.md) adds bounded
private symbol fallback and two forced private-font fixtures. The supplied
Windows 7 run passes 51 checks and all 13 mappings, including automatic private
U+1F600 fallback. This accepts the bounded experiment, not production font quality.
No AtlasEngine is linked into the probe and no renderer worker is started;
TerminalCore is linked only to supply authoritative fixture cell spans. The
earlier renderer-probe 0.1/0.2/0.3/0.4, Atlas backend 0.1, and GDI 0.2.1 archives are retained.

The [geometry/repaint plan](doc/vt7/architecture/2026-09-11-font-geometry-test-plan.md)
now has its first implementation in [probe 0.6](doc/vt7/validation/2026-09-11-geometry-probe.md).
The unchanged command also writes twelve `.log.bmp.geometry-<size>-<dpi>.bmp`
images, alongside the frozen 0.5 reference image. These 13 images remain part of
the current package's output. `Test-VT7Geometry.ps1` independently checks the matrix as
part of `Test-VT7RendererProbe.ps1`. Offscreen DPI is simulated; no display-setting
change is requested. Vertical REVIEW observations do not imply final typography
acceptance. The supplied Windows 7 0.6 run passes the matrix checks with the same
24 stacked-mark observations; its reference image matches the target 0.5 image.
Both accepted archives are retained.

[Probe 0.7](doc/vt7/validation/2026-09-11-repaint-probe.md) adds the differential
repaint experiment: 480 edits across the same 12 configurations, independent
full-frame comparisons, and deliberately broken old-ink/neighbor cases.
`Test-VT7Repaint.ps1` runs as part of the renderer suite. There are 42 additional
repaint images, for 55 bitmap outputs total on success. Return the log and all
bitmaps together, preferably zipped. Red pixels in explicitly named negative
difference images are expected; normal sample difference images must be black.
This remains an isolated software damage experiment, not Atlas integration.

The supplied 0.7 Windows 7 result passes. The approved vertical policy follows
upstream: fixed primary-font rows with ordinary glyph overhang and special
clipping exceptions. [Probe 0.8](doc/vt7/validation/2026-09-11-text-adapter-probe.md)
adds 12 `.adapter-<size>-<dpi>.bmp` comparisons, bringing the total to 67 bitmaps.
Its reusable mapper candidate selects faces with baseline DirectWrite layout,
then shapes original core order using the analyzer. N is visual paragraph layout;
T is logical terminal order with upstream-default metrics/advance correction.
Arabic/Hebrew N and T intentionally differ; joining and horizontal overhang
quality still need review. This is not the integrated Atlas font path.
`Test-VT7TextAdapter.ps1` independently checks 192 mappings and reported coverage
as part of the renderer suite. The suite also injects a stale-snapshot failure.

The supplied 0.8 Windows 7 structural run passes, while documenting horizontal
overflow and unresolved Arabic typography. [Probe 0.9](doc/vt7/validation/2026-09-11-horizontal-fitting-probe.md)
adds 12 `.horizontal-<size>-<dpi>.bmp` images, R (raw) versus F (fitted), for
79 outputs total. It preserves the earlier 67 images. Whole-group raster fitting,
neighbor sentinels, natural Latin/italic pixel identity, deliberate overflow
controls, and 72 conservative partial-row repaints are checked by the probe.
`Test-VT7Horizontal.ps1` independently validates the logged matrix and bitmap
structure. The suite injects an unfitted overflow that must fail the baseline.
The supplied Windows 7 0.9 containment run passes. Narrow-symbol quality and
Atlas integration remain open; no new system setting or update is required.

[Probe 0.10](doc/vt7/validation/2026-09-11-arabic-context-probe.md) adds 24
`.arabic-<size>-<dpi>-<page>.bmp` images, for 103 bitmaps on success. Its five
lanes separate native layout, legacy mapper, repaired logical/visual grid
projections, and repaired proportional text. Arabic context repair is a bounded
probe, not an enabled terminal bidi mode. Unsafe lam-alef splits are explicit
REVIEW observations. Run `Test-VT7Arabic.ps1 -ReportPath <log>` to validate the
matrix; the renderer suite also injects lost context and requires failure.
The supplied Windows 7 0.10 run passes its structural/context checks, with
96 repaired runs and 24 explicit lam-alef boundary reviews. The fixed-grid
cursive spacing decision remains open.

[Probe 0.11](doc/vt7/validation/2026-09-11-joined-span-probe.md) adds 12
`.joined-<size>-<dpi>.bmp` images, for 115 bitmaps on success. It compares
per-group fitting with a single transform across a fixture-declared Arabic
span inside its combined core allocation. `Test-VT7Joined.ps1 -ReportPath <log>`
checks the matrix, ownership, containment, negative controls and 72 partial
repaint records. The renderer suite injects broken relative run placement.
The supplied Windows 7 0.11 matrix passes, with all 103 earlier target BMPs unchanged.

[Probe 0.12](doc/vt7/validation/2026-09-11-cross-style-ligature-probe.md) adds 24
`.ligature-<size>-<dpi>-<page>.bmp` images. Return the log and all 139 BMPs in a
ZIP. N/L/A/X/C compare native split styles, whole-source shapes in each selected
face, a REVIEW-only spatial hybrid and same-outline two-color painting.
`Test-VT7Ligature.ps1 -ReportPath <log>` validates the matrix independently.
The suite also injects lost paint styling. Its per-process timeout is now 120
seconds for the expanded matrix. The supplied Windows 7 0.12 matrix passes.

[Probe 0.13](doc/vt7/validation/2026-09-11-marked-paint-probe.md) adds twelve
`.paint-<size>-<dpi>.bmp` pages for 151 BMPs total. Return all images and the log.
U/C/S compare uniform text, per-core-cluster colors and a snapped selection on
marked/joined words. `Test-VT7Paint.ps1` checks the matrix and source mapping.
The suite also swaps paint colors as a required negative. Cursor/hit testing
is not implemented. The supplied Windows 7 0.13 run passes all eight validators:
51 required checks, zero failures, 432 paint raster comparisons and 288 partial
paint repaints. All 139 earlier target BMPs remain byte-identical. Source
selection preserves bases with marks, but the long-word highlight still exposes
the mismatch between allocated cells and centered glyph positions. Interaction
mapping is deferred under Milestone 7/POL02, not an accepted production behavior
or the next build task. The [port-first plan](doc/vt7/architecture/2026-09-12-port-first-plan.md)
prioritizes minimal font adaptation and an integrated Atlas viewport. The probe
commands and frozen packages remain reproducible regression/research tools;
their optional typography policies need not be implemented to finish the port.

Run the static Windows 7 compatibility gate after a build:

```powershell
.\tools\Verify-VT7.ps1 -Configuration Debug
```

The gate currently checks:

- Both VT7 images are x64 PE files.
- Their operating-system and subsystem versions do not exceed 6.1.
- Their static imports do not include the known post-Windows 7 APIs prohibited
  by the proof architecture.
- Release verification applies the same PE and import checks to the three bundled
  Visual C++ runtime DLLs.
- The repository text follows the project punctuation rule.

Complete `dumpbin` header and import reports are saved under
`artifacts\vt7\reports`. Static import inspection is necessary, but it is not a
substitute for testing on Windows 7.

## Run the automated checks

### Atlas backend experiment

The solution also builds `VT7.AtlasProof.exe`, which links the real Atlas
backends and shared Windows 7 presentation code. It deliberately bypasses the
AtlasEngine font mapper and the TerminalCore/controller path.
It does not replace the accepted GDI host.

```powershell
.\tools\Test-VT7AtlasProof.ps1 -Configuration Debug
.\tools\Test-VT7AtlasProof.ps1 -Configuration Release
.\tools\Package-VT7AtlasProof.ps1
```

The test runner executes both backends on forced hardware and forced WARP,
with 19 frames per combination, pre-Present pixel readback, resize/redraw,
color changes, explicit device recreation, and negative CLI/failure checks.
It writes reports and diagnostic PNGs under
`artifacts\vt7\reports\<configuration>\Atlas`. Each process has a 60-second limit.
PNGs show the back buffer, not the visible desktop.

The archive is `artifacts\VT7-atlas-backend-proof-0.1-x64.zip`. Extract it on
Windows 7 and run `RUN-ATLAS-TESTS.cmd`, then the hardware and WARP launchers
for visible testing. The batch launcher does not impose a hang timeout.
`Verify-VT7.ps1 -AtlasProofOnly -BinaryDirectory <package directory>` audits
every assembled EXE/DLL. No .NET or Power Automate is needed for this harness.
See the [backend validation record](doc/vt7/validation/2026-09-11-atlas-backend-proof.md)
for limitations and current evidence.

The issued 0.1 package passed all four automated combinations on Windows 7
SP1 x64. Visible hardware/WARP Direct3D11 sessions and repeated R-key
recreation also passed. Keep that archive unchanged as the tested checkpoint;
documentation-only updates do not require repackaging it. Rerunning a launcher
overwrites its own log/images, so preserve evidence before repeating tests.

### Integrated Atlas/GDI host and core checks

0.3.0 has supplied Windows 7 C1/C2 acceptance; 0.3.1 repaint/cursor checks also
pass on the supplied target setup. Use the following in Debug or Release:

```powershell
.\tools\Test-VT7AtlasRepaint.ps1 -Configuration Debug
```

This runs 32 exact comparisons and eight cursor-cell checks per Atlas mode,
across two window sizes, plus an expected-failure pixel-mismatch control.
Reports/captures: `artifacts/vt7/reports/<configuration>/Repaint/`.
See the [test design and limits](doc/vt7/validation/2026-09-12-atlas-repaint.md).

0.3.2 adds `tools/Test-VT7AtlasRecovery.ps1 -Configuration Debug` (or Release):
16 controlled startup, removal, exhausted-retry and close-during-backoff scenarios.
Reports/captures live under `artifacts/vt7/reports/<configuration>/Recovery/`.
Each process has a 45-second outer limit; the in-process asynchronous wait is
10 seconds. These are injected failures, not real driver-loss evidence. See the
[policy and remaining gates](doc/vt7/validation/2026-09-12-atlas-recovery.md).

0.3.2 now has supplied Windows 7 acceptance of that bounded recovery matrix.
0.3.3 adds `tools/Test-VT7AtlasSettings.ps1 -Configuration Debug` (or Release).
Current 0.3.4 retains that matrix and adds startup work-area, status-layout and
blank-first-row controls to the viewport tests. Same-device recovery still
requires exact RGB; before/after geometry is logged. The 0.3.3 higher-DPI failures
are retained historically; 0.3.4 passes every positive suite at all three measured
Windows 7 scales on the supplied setup. To reproduce, run all five packaged
test launchers at each actual 100/125/150 percent scale. See the
[corrective build record](doc/vt7/validation/2026-09-12-atlas-scaling-correction.md).
Five Atlas modes each run 10 font/settings cases and eight invalid-input checks,
plus hidden updates. Two separate local negative controls verify geometry and
expected system-DPI rejection. Reports/20 captures are under
`artifacts/vt7/reports/<configuration>/Settings/`. Use `-ExpectedSystemDpi 96`,
`120` or `144` to assert the actual environment, not change it. Renderer DPI
overrides are simulations. See the [settings record](doc/vt7/validation/2026-09-12-atlas-settings.md).

The recommended local test command waits for each process, checks its exit
code, and requires a fresh passing report:

```powershell
.\tools\Test-VT7.ps1 -Configuration Debug
```

It runs headless diagnostics, six hidden viewport modes and a blank-frame
negative control. Use
`-Configuration Release` for a release build. Reports are written to
`artifacts\vt7\reports\<configuration>\diagnostics-gdi.log` and
`window-smoke-test-<renderer>.log`, with a PNG for each Atlas mode.
Use `-Renderers gdi` or `-Renderers atlas-d3d-warp` for a focused recheck.
`tools/Test-VT7FontAssets.ps1 -Configuration Release` checks missing/altered
private assets in disposable copies, without changing the source fonts.

The WPF application can execute its native and graphics checks without opening
a window:

```powershell
.\artifacts\vt7\bin\Debug\VT7.Host.exe `
    --diagnostics `
    --diagnostics-output .\artifacts\vt7\reports\Debug\runtime-diagnostics.log
```

Exit code 0 means all required proof probes passed. The report records the
native ABI, detected Windows version, .NET runtime, graphics adapter, hardware
Direct3D 11 result, WARP result, DXGI 1.2 availability, seven TerminalCore
regression results and the new 48-case font-boundary check. A copy is also
written to `%LOCALAPPDATA%\VT7\Logs` when that directory is writable.

Normal startup opens the visual proof window:

```powershell
.\artifacts\vt7\bin\Debug\VT7.Host.exe
```

The automated window smoke test creates and disposes four WPF/native-window
pairs. Each cycle changes the host dimensions eight times, checks that the
terminal grid shrinks, forces native paints, minimizes/restores, resets the
demo, and checks that the child HWND is destroyed. At both large and small
sizes, it switches to Diagnostics and back, checks ten diagnostic values and
both selected/unselected tab-header colors, then verifies the same child HWND
and grid return visibly and repaint. There are eight tab round trips in total.

Atlas tests wait for a completed requested frame, inspect pre-Present header ink,
compare repeated reset hashes and verify no frame growth while the tab is hidden.
They save a full-sample back-buffer PNG with blinking disabled for determinism.
The injected blank frame must fail the header-ink check. These are integration
oracles, not a full text-correctness, differential repaint or idle-CPU suite.

The contrast gate requires at least 4.5:1 using the effective foreground and
background brushes in the live WPF visual tree. This is not a screenshot check
or a claim of full accessibility compliance. Font rasterization, clipping,
keyboard focus behavior, and high-contrast configurations need visual testing:

```powershell
.\artifacts\vt7\bin\Debug\VT7.Host.exe --window-smoke-test
```

## Windows 7 proof procedure

The development machine can prove the build and binary boundary, but only a
Tier A Windows 7 system can establish compatibility. Use a clean snapshot with:

- Windows 7 SP1 x64.
- Platform Update KB2670838.
- .NET Framework 4.8.
- The remaining prerequisites listed in [ROADMAP.md](ROADMAP.md).

Copy and extract the entire 0.3.5 zip, including `fonts/`, on that machine.
Run `RUN-DIAGNOSTICS.cmd` and `RUN-VIEWPORT-TEST.cmd`, retaining
`VT7-diagnostics.log` and the complete `Logs` folder. The latter runs GDI and
all four forced Atlas backend/device modes plus automatic mode, with separate logs and Atlas PNG captures.
Run `RUN-REPAINT-TEST.cmd` and retain all logs/captures, including the expected
failure `repaint-negative.log`. Verify the visible `frames (snapshot)` label
becomes nonzero after startup; it is not a live counter.
Run `RUN-RECOVERY-TEST.cmd`. All 16 scenarios should PASS, including assertions
about intentionally exhausted retries. Keep every recovery log and PNG.
Run `RUN-SETTINGS-TEST.cmd` and choose the current actual Windows scaling.
To reproduce the accepted matrix, repeat all five suites at actual Windows 7
100/125/150 percent scaling, restarting
the Windows session/application after the OS change as required. Save work before
signing out. The launcher does not change the OS. It preserves different DPI runs
in separately named reports, but overwrites another run at the same DPI.
Capture normal/WARP viewport and Diagnostics screenshots at each scale and inspect
clipping, legibility and focus. Capture the initial window before manual resizing
to verify work-area fit. Preserve each scale's results separately. Expected fatal
AppData snapshots are not failed recovery verdicts; correlate them with the named
test reports as described in the correction record.
Then run `RUN-VT7.cmd` (automatic Atlas Direct3D11) and inspect the viewport:

- Confirm that colored text, bold, underline, and box drawing appear.
- Note missing or clipped accented, combining, and CJK glyphs, including the
  chosen fonts and display scaling. Also inspect the two fallback symbols.
  Logical-cell Arabic is inherited behavior, not the earlier joined-word experiment.
- Narrow and widen the window repeatedly. Content should reflow without a
  crash, persistent blank surface, or continually increasing resource use.
- Minimize, restore, switch the diagnostic/viewport tabs, and reset the demo.
- Confirm that both headers and diagnostic values are readable. Use Tab and
  arrow keys to switch tabs and check the visible focus indicator.
- Close and reopen the program several times. Save screenshots and all logs.

Repeat visible checks with `RUN-ATLAS-WARP.cmd`. `RUN-GDI-REFERENCE.cmd` selects
the old reference. For visible Direct2D checks use `VT7.Host.exe --renderer
atlas-d2d-hardware` or `--renderer atlas-d2d-warp`. Automatic mode (`atlas-auto`)
can switch hardware to WARP and reports the actual backend; forced modes never
switch. Archive logs before rerunning, since launchers overwrite
their own output names. Report hangs with partial logs, never as a pass.

Do not claim Windows 7 runtime compatibility from PE inspection or a newer
Windows test alone. Record the exact OS servicing level, graphics driver, CPU,
diagnostic log, and outcome for each test.

## Recorded Windows 7 results

The current 0.3.4 corrective matrix is accepted on the supplied Windows 7 SP1 x64
setup, .NET Framework 4.8.4795.0, AMD Radeon RX 6800 XT, at actual 96/120/144 DPI.
At each scale, diagnostics, 6 viewport modes, 4 repaint modes, 16 injected
recovery cases and 5 settings modes pass. Recovery dimensions remain stable;
native work-area checks and normal/WARP launch screenshots confirm initial fit.
See the [complete acceptance record](doc/vt7/validation/2026-09-12-atlas-scaling-correction.md)
for archive identity, counts and expected negative/fatal snapshots. This closes
the bounded scaling checkpoint, not theme, stress, separate ESU or broader
device/driver qualification. The earlier records below retain their original scope.

Proof 0.2.0 has been tested on fully updated Windows 7 SP1 x64 setups without
ESU and with the full ESU update set. The supplied non-ESU reports show ABI 2
loading, all seven core checks passing, and four native-window lifecycles with
18 paints and 15 resizes each. Hardware D3D11 and WARP device creation succeed
at feature level 11.0. Screenshots confirm the visible static viewport.

The tester separately confirmed the ESU setup as working and tested. Separate
ESU logs and an exact per-system update inventory were not supplied for this
record. See the [validation notes](doc/vt7/validation/2026-09-10-viewport-proof.md)
for the evidence, known defect, and remaining coverage.

### Host-styling correction in 0.2.1

In 0.2.0, tab labels had insufficient contrast and diagnostic values could
appear almost invisible against their dark panels. This was a WPF foreground/
style inheritance problem, not missing data or a TerminalCore failure.

Version 0.2.1 explicitly pairs tab text/background colors, adds a keyboard-focus
outline, and makes the diagnostic style inherit the base text style with an
explicit light foreground. The new test reproduced the original 1.05:1
diagnostic contrast failure before the fix; the corrected controls pass with a
minimum measured ratio of 10.81:1 on the development machine.

The new hidden tests also exercise tab switching and viewport restoration.
The supplied 0.2.1 Windows 7 non-ESU logs pass all seven core checks, eight tab
round trips at a minimum 10.81:1 contrast, and four window lifecycles, each with
22 paints and 15 resizes. Screenshots show readable headers and values. The
tester confirms Tab/arrow-key navigation and visible focus, and separately
confirms that all tests pass on the ESU setup. This closes Milestone 1 cleanup
acceptance on those configurations, not the full release matrix. See the
[cleanup validation notes](doc/vt7/validation/2026-09-10-milestone-1-cleanup.md).

## Current proof architecture

`VT7.Host` is an x64 .NET Framework 4.8 WPF executable. It loads
`VT7.Native.dll` through a small versioned C ABI. The native bridge is compiled
with the Windows 7 target macros and exposes platform and Direct3D probes.

The graphics proof deliberately uses `CreateDXGIFactory1`, `IDXGIAdapter1`, and
`D3D11CreateDevice`. DXGI 1.2 is detected through a COM interface query instead
of a static `CreateDXGIFactory2` import. That pattern lets the same binary use
the Windows 7 Platform Update capabilities without binding startup to a newer
Windows export.

`VT7.Core.lib` now links the inherited parser and terminal state implementation
into the bridge. A WPF `HwndHost` embeds the selectable Atlas/GDI surface through
ABI 8 (0.3.4 used ABI 7, 0.3.3 used ABI 6, 0.3.2 used ABI 5, 0.3.1 used ABI 4).
The renderer uses Windows 7 events. It parks while hidden and stays alive until
native HWND destruction completes, then releases graphics and joins before the
surface is deleted. The core is compiled without WinRT settings or ICU search/URL
detection. See the core boundary notes for the exact limitations.

AtlasEngine font mapping and controller/core integration now pass locally and
on the supplied Windows 7 setup. C3 renderer qualification, local PTY sessions,
SSH and the final UI remain ahead.
The separate Atlas backend proof is established on the tested Windows 7 setup.
The Windows 7 host/core/viewport proof is now established on the tested
non-ESU and ESU configurations. Minimal-prerequisite clean snapshots, broader
hardware coverage, production text rendering, and long-running session
stability still require separate validation.
