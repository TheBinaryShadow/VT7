# Building VT7

VT7 currently builds a proof-of-life desktop host and native compatibility
bridge. This is the first executable boundary of the project, not yet a
terminal emulator.

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

Build output is written under `artifacts\vt7\bin`. The packaging script creates
both `artifacts\proof-of-life` and `artifacts\VT7-proof-of-life-x64.zip`.
Generated artifacts are ignored by Git.

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
- Release verification applies the same PE and import checks to the two bundled
  Visual C++ runtime DLLs.
- The repository text follows the project punctuation rule.

Complete `dumpbin` header and import reports are saved under
`artifacts\vt7\reports`. Static import inspection is necessary, but it is not a
substitute for testing on Windows 7.

## Run the diagnostic probe

The WPF application can execute its native and graphics checks without opening
a window:

```powershell
.\artifacts\vt7\bin\Debug\VT7.Host.exe `
    --diagnostics `
    --diagnostics-output .\artifacts\vt7\reports\Debug\runtime-diagnostics.log
```

Exit code 0 means all required proof probes passed. The report records the
native ABI, detected Windows version, .NET runtime, graphics adapter, hardware
Direct3D 11 result, WARP result, and DXGI 1.2 availability. A copy is also
written to `%LOCALAPPDATA%\VT7\Logs` when that directory is writable.

Normal startup opens the visual proof window:

```powershell
.\artifacts\vt7\bin\Debug\VT7.Host.exe
```

The automated window smoke test creates the WPF top-level window, runs its
loaded handler and probes, then closes it without presenting UI:

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

Copy and extract the proof zip on that machine. Run `RUN-DIAGNOSTICS.cmd`, save
the resulting `VT7-diagnostics.log`, then run `RUN-VT7.cmd` and confirm that the
window opens. Test once with the normal graphics driver and once in the planned
WARP test environment.

Do not mark the Windows 7 startup milestone complete from PE inspection or a
newer Windows test alone. Record the exact OS servicing level, graphics driver,
CPU, diagnostic log, and outcome for each test.

## Current proof architecture

`VT7.Host` is an x64 .NET Framework 4.8 WPF executable. It loads
`VT7.Native.dll` through a small versioned C ABI. The native bridge is compiled
with the Windows 7 target macros and exposes platform and Direct3D probes.

The graphics proof deliberately uses `CreateDXGIFactory1`, `IDXGIAdapter1`, and
`D3D11CreateDevice`. DXGI 1.2 is detected through a COM interface query instead
of a static `CreateDXGIFactory2` import. That pattern lets the same binary use
the Windows 7 Platform Update capabilities without binding startup to a newer
Windows export.

TerminalCore, Atlas, local PTY sessions, SSH, and the final terminal UI have not
yet crossed this boundary. Their integration begins only after the proof runs
on the defined Windows 7 test floor.
