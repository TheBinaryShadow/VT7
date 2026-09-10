# Building VT7

VT7 currently builds a static terminal viewport proof (0.2.0): a WPF desktop
host, native HWND surface, and the real Microsoft Terminal core and VT parser.
It displays a fixed demonstration and resizes the actual text buffer. It does
not yet run shells or SSH sessions.

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
`artifacts\viewport-proof` and `artifacts\VT7-viewport-proof-0.2.0-x64.zip`.
It tests the assembled package before archiving it and includes runtime DLLs,
symbols, notices, dependency licenses, and file checksums. Generated artifacts
are ignored by Git. The older 0.1 proof-of-life package is not overwritten.

## Verify the binary boundary

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

The recommended local test command waits for each process, checks its exit
code, and requires a fresh passing report:

```powershell
.\tools\Test-VT7.ps1 -Configuration Debug
```

It runs both headless diagnostics and the hidden native-window test. Use
`-Configuration Release` for a release build. Reports are written to
`artifacts\vt7\reports\<configuration>\diagnostics.log` and
`window-smoke-test.log`.

The WPF application can execute its native and graphics checks without opening
a window:

```powershell
.\artifacts\vt7\bin\Debug\VT7.Host.exe `
    --diagnostics `
    --diagnostics-output .\artifacts\vt7\reports\Debug\runtime-diagnostics.log
```

Exit code 0 means all required proof probes passed. The report records the
native ABI, detected Windows version, .NET runtime, graphics adapter, hardware
Direct3D 11 result, WARP result, DXGI 1.2 availability, and seven TerminalCore
regression results. A copy is also
written to `%LOCALAPPDATA%\VT7\Logs` when that directory is writable.

Normal startup opens the visual proof window:

```powershell
.\artifacts\vt7\bin\Debug\VT7.Host.exe
```

The automated window smoke test creates and disposes four WPF/native-window
pairs. Each cycle changes the host dimensions eight times, checks that the
terminal grid shrinks, forces native paints, minimizes/restores, resets the
demo, and checks that the child HWND is destroyed. It does not verify visual
appearance:

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

Copy and extract the proof zip on that machine. Run `RUN-DIAGNOSTICS.cmd` and
`RUN-VIEWPORT-TEST.cmd`, retaining `VT7-diagnostics.log` and
`VT7-viewport-test.log`. Then run `RUN-VT7.cmd` and inspect the terminal viewport:

- Confirm that colored text, bold, underline, and box drawing appear.
- Note missing or clipped accented, combining, and CJK glyphs, including the
  chosen fonts and display scaling. GDI font fallback is not a finished feature.
- Narrow and widen the window repeatedly. Content should reflow without a
  crash, persistent blank surface, or continually increasing resource use.
- Minimize, restore, switch the diagnostic/viewport tabs, and reset the demo.
- Close and reopen the program several times. Save a screenshot and both logs.

Test once with the normal graphics driver and once in the planned WARP test
environment. These graphics probes create devices; the temporary viewport
itself uses GDI, not Direct3D or WARP rendering.

Do not claim Windows 7 runtime compatibility from PE inspection or a newer
Windows test alone. Record the exact OS servicing level, graphics driver, CPU,
diagnostic log, and outcome for each test.

## Recorded Windows 7 results

Proof 0.2.0 has been tested on fully updated Windows 7 SP1 x64 setups without
ESU and with the full ESU update set. The supplied non-ESU reports show ABI 2
loading, all seven core checks passing, and four native-window lifecycles with
18 paints and 15 resizes each. Hardware D3D11 and WARP device creation succeed
at feature level 11.0. Screenshots confirm the visible static viewport.

The tester separately confirmed the ESU setup as working and tested. Separate
ESU logs and an exact per-system update inventory were not supplied for this
record. See the [validation notes](doc/vt7/validation/2026-09-10-viewport-proof.md)
for the evidence, known defect, and remaining coverage.

### Known host-styling defect in 0.2.0

The tab labels have insufficient contrast, and diagnostic values can appear
almost invisible against their dark panels. This is a WPF foreground/style
inheritance problem, not missing diagnostic data or a TerminalCore failure.
Until corrected, use the text logs for readable diagnostic values.

The hidden window tests check native painting and lifecycle behavior, not
visual contrast. They can pass while this defect is present. Style regression
coverage and a visual recheck are pending; no fix is included in 0.2.0.

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
into the bridge. A WPF `HwndHost` embeds the GDI proof surface through ABI 2.
The core is compiled without WinRT settings, ICU search/URL detection, and the
modern renderer worker. See the core boundary notes for the exact limitations.

Atlas, local PTY sessions, SSH, and the final terminal UI remain future work.
The Windows 7 host/core/viewport proof is now established on the tested
non-ESU and ESU configurations. Minimal-prerequisite clean snapshots, broader
hardware coverage, production text rendering, and long-running session
stability still require separate validation.
