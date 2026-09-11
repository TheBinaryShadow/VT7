# Milestone 2A: isolated build and capability probe

## Outcome

Partial 2A progress, not completion of Milestone 2 or the 2A runtime gate.
The isolated Atlas library builds in Debug and Release, and the independent
renderer capability probe passes on the development machine. The accepted
0.2.1 GDI proof and its archive are unchanged. No upstream merge occurred.

The first Windows 7 run passed. The probe is deliberately separate
from Atlas. The subsequent backend proof now passes on Windows 7, while the
full AtlasEngine still needs font/runtime adaptation, a full link/dependency
audit, and controller integration before it can be loaded by the host.

## Build evidence

This section records the initial compile-only checkpoint. The later
[Atlas backend proof](2026-09-11-atlas-backend-proof.md) adapts presentation,
disables Debug shader hot reload, and links the backends into a separate harness.
The raw-library dependency observations below describe that earlier build,
not the current backend executable.

- Pinned VS 2022/MSVC 14.44.35207, compiler 19.44.35228, SDK 10.0.26100.0.
- `VT7.Renderer.vcxproj` compiles eleven existing Atlas translation units with
  warnings treated as errors, without editing the upstream Atlas sources.
- Four shader headers are generated from the inherited HLSL. A clean isolated
  Release rebuild produced identical SHA-256 hashes for all four headers.
- Initial C++ builds failed on SDK-gated DirectWrite, Direct2D, composition,
  and WIC declarations. A scoped header inclusion in `RendererFeatures.hpp`
  exposes those declarations and restores the Windows 7 target macros. This
  is declaration visibility only, not a runtime compatibility implementation.
- Final Debug/Release builds show no compiler warnings or errors. The raw
  Release library's symbol inventory still includes `CreateDXGIFactory2`,
  demonstrating why it must not be linked into the Windows 7 host yet.
- Nearby font loading and custom shaders are explicitly disabled in this
  compile experiment. Debug shader hot reload is still compiled into the raw
  Debug library; no raw library or shader-reload runtime is shipped.

Build/symbol reports are retained in the ignored `artifacts/vt7` tree:

- `renderer-build-debug.log`
- `renderer-build-release.log`
- `renderer-rebuild-release.log`
- `reports/Release/renderer-library-symbols.txt`

Successful static-library creation does not resolve every external symbol, test
COM availability, or establish a complete runtime dependency closure.

## Independent probe scope

`VT7.RendererProbe.exe` does not link `VT7.Renderer.lib` or `VT7.Native.dll`.
It uses the existing system graphics APIs and the pinned app-local CRT:

1. Initializes COM and queries baseline/optional DXGI and DirectWrite interfaces.
2. Uses a fixed mixed-script `IDWriteTextLayout` and a custom glyph-run callback
   to count runs/faces/glyphs, check cluster indices, and account for UTF-16 text.
   Missing glyphs are reported, not silently treated as complete Unicode support.
3. Independently creates hardware and explicit WARP D3D devices, reporting
   feature levels, adapter vendor/device IDs, and optional interface results.
4. Creates a hidden HWND discard/stretch swap chain for each device, checks
   the Direct2D device-context interface with QueryInterface, draws the layout,
   reads back the buffer, and checks for nonempty glyph pixels.
5. Observes hidden `Present` and tests buffer resize after releasing references.

This is a small capability/rasterization experiment. It does not prove Atlas
glyph mapping, terminal-cell layout, visible presentation, post-resize redraw,
fallback quality, render-worker synchronization, or recovery from device loss.
Hidden presentation is logged as an observation, not a required visual pass.
The hardware section never substitutes WARP silently.

## Development-machine results

The reports identify Windows NT 10.0.19044 x64, hardware vendor/device IDs
4098/29772, and WARP IDs 5140/140. Both configurations and the assembled Release
package report:

- 50 required checks passed, zero failures.
- Hardware and WARP feature level 11.0.
- Eight layout runs, three retained font-face identities, 60 glyphs, and zero
  missing glyphs for this installed-font environment.
- 2,182 lit pixels on each device's readback; swap-chain creation and resize pass.

These values are observations, not fixed expected Windows 7 font/pixel counts.
The baseline passes independently of optional newer interfaces. A missing
required capability fails the baseline and is retained in the report.

`Test-VT7RendererProbe.ps1` validates fresh reports, required hardware/WARP
sections, and a bounded process lifetime. Negative tests confirm that injected
required failure produces a failed report/nonzero exit, invalid arguments return
64, and an unwritable output target returns 2. This injection tests report/exit
semantics, not graphics-device recovery.

The existing GDI/core diagnostics and four-cycle window tests pass in both
configurations. PE verification passes for the probe in Debug and Release and
for every EXE/DLL in its assembled package. Optional COM queries still require
runtime evidence; import verification cannot replace that.

## Windows 7 handoff

The supplied `VT7-renderer-probe.log`, captured at 2026-09-11 03:40:12 UTC,
identifies Windows NT 6.1.7601 and the Release x64 build from 05:26:09 local
build time. It reports 49 required checks, zero failures, and a passed baseline.
Hardware and explicit WARP both rasterize and read back 2,052 lit pixels,
present to the hidden target successfully, and resize successfully at feature
level 11.0. Hardware adapter IDs are 4098/29631; WARP reports 0/0.

Factory2 in DirectWrite, Device2, Context2, and SwapChain2 return `0x80004002`;
FontFace2 returns `0x80004001`. These optional results do not fail the baseline.
The font sample reports eight runs, two faces, 60 glyphs, and one missing glyph.
There is one fewer required face check than on the development system, explaining
49 rather than 50 checks. The exact missing character is not identified by this
probe and is now an explicit Milestone 2C investigation in the roadmap.
This run validates neither Atlas nor visible presentation or post-resize redraw.

Archive: `artifacts/VT7-renderer-probe-0.1-x64.zip`.
Run `RUN-RENDERER-PROBE.cmd` after extracting all files to a writable folder.
Send `VT7-renderer-probe.log` even if it fails. No visible terminal is expected.
This native utility needs neither .NET nor Power Automate.

Missing newer COM interfaces, typically reported as `0x80004002`, are expected
observations on Windows 7. Judge the required checks and final baseline result;
do not treat optional-interface absence as a broken installation.

This capability report guided the now-tested
[Atlas backend proof](2026-09-11-atlas-backend-proof.md). The font discrepancy
remains open under 2C. Separate ESU confirmation remains part of milestone
acceptance, not a requirement to repeat every exploratory run.

The old GDI archive remains at SHA-256
`8f8724edb0d691fd5dc72392476a44d9df07d0bc6bddaf59b6353e3466299662`.
The new archive contains only the probe, runtime DLLs, symbols, instructions,
licenses/notices, and checksums. It does not contain the unported Atlas library.
