# Atlas backend proof 0.1

## Outcome and scope

Partial Milestone 2A/2B progress. The real Atlas Direct3D11 and Direct2D
backends link into a standalone native harness and pass local Debug/Release
hardware/WARP rendering tests. The issued Release package now also passes all
four automated modes on Windows 7 SP1 x64, with visible Direct3D11 hardware/WARP
screenshots and successful R-key recreation. The fixed-glyph backend checkpoint
is accepted on this tested setup. Full 2A/2B and Milestone 2 remain open for the
font/controller, scheduling, and broader acceptance work described below.

This differs from the capability probe: the pixel pipeline is now Atlas code,
including BackendD3D's glyph atlas, shaders, and instanced drawing. The harness
feeds a fixed pre-mapped Consolas sample directly into `RenderingPayload`.
It does not construct AtlasEngine, run its fallback/shaping path, or integrate
TerminalCore, the renderer controller, or the WPF host.

The missing glyph from the earlier Windows 7 capability report remains an
explicit 2C roadmap item. It is not investigated or hidden by this ASCII sample.

## Implementation

- Added shared `Win7Presentation` routines, called by the harness and the
  `VT7_ATLAS` branch of AtlasEngine's presentation code.
- Requests hardware/WARP explicitly, obtains the actual device's adapter and
  factory, and queries Device1/Context1. WARP is not selected by assuming that
  adapter enumeration exposes a software adapter on Windows 7.
- Uses SwapChain1, opaque HWND, DISCARD/STRETCH, one buffer, no flags, and full
  redraw before `Present(1, 0)`. No composition path, newer factory export,
  waitable presentation object, or Present1 dirty/scroll optimization.
- Rejects zero dimensions and alpha requests before swap-chain creation.
  Resize releases backend buffer references and clears/flushes device state.
- Both Atlas backends now QueryInterface for Direct2D device contexts rather
  than assuming that an `ID2D1RenderTarget` pointer implements that interface.
- The VT7 payload/cache use FontFace1; BackendD3D uses a separate Factory1
  reference for rendering parameters. Its unused `#if 0` glyph-analysis
  experiment still contains newer APIs and is not compiled.
- Compiles existing ColorFix code to satisfy the backend cursor-color link
  dependency. No whole TerminalCore or upstream application link was added.
- Disables Debug shader hot reload as well as custom shaders and nearby fonts.
  The inherited four HLSL sources remain build-time shader inputs.

The descriptor follows the documented
[Windows 7 Platform Update limits](https://learn.microsoft.com/en-us/windows/win32/direct3darticles/platform-update-for-windows-7),
and the earlier capability probe established this combination on the tested
Windows 7 hardware and WARP paths. That earlier evidence is not acceptance of
the new Atlas implementation; the later backend runs below provide that evidence.

## Dependency boundary

Debug and Release `Verify-VT7` passes include the linked Atlas proof executable.
The assembled Release package is audited and tested using its app-local CRT.
The gate checks x64, PE target versions, known prohibited imports, and project
punctuation. Full dumpbin reports are retained alongside the test logs.
This deny-list gate is not an exhaustive proof of every API's availability.

Debug/Release linker maps confirm BackendD3D, BackendD2D, Win7Presentation,
ColorFix, and stb_rect_pack are linked, while AtlasEngine, VT7.Core, and
VT7.Native are absent. The final imports contain no runtime shader compiler,
composition entry point, CreateDXGIFactory2, DXGIGetDebugInterface1, or address
wait/wake imports. Maps are under `artifacts/vt7/bin/<configuration>`.

The linked backend path requires Direct3D11, DXGI adapter/factory/surface and
SwapChain1, Direct2D device contexts, DirectWrite Factory1/FontFace1/rendering
parameters, and the original WIC factory for optional PNG capture. Later
Direct2D context/device queries are optional. The harness leaves the newer
DirectWrite color factory null, with color glyphs disabled even on newer OSes.
It resolves RtlGetVersion for accurate reporting. Atlas's MacType check only
inspects an already-loaded module and its version; no shim is installed/loaded.
Custom-shader/compiler/file-watcher paths are compiled out.

AtlasEngine still requires DirectWrite Factory2/system fallback in its
constructor and font routines. Those objects are not linked into the backend
harness, and the whole renderer controller remains outside this boundary.
Do not link/construct that engine in the Windows 7 host yet. A full engine
runtime/import/COM audit remains a 2A/2C integration requirement.

## Automated evidence

Development OS: Windows NT 10.0.19044 x64. Pinned MSVC compiler 19.44.35228,
toolset 14.44.35207, SDK 10.0.26100.0. Both configurations pass for:

| Atlas backend | Device request | Frames per test |
| --- | --- | --- |
| Direct3D11 | Hardware | 19 |
| Direct3D11 | WARP | 19 |
| Direct2D | Hardware | 19 |
| Direct2D | WARP | 19 |

Each run checks the actual swap-chain descriptor and uses pre-Present readback,
because DISCARD does not preserve valid back-buffer contents after Present.
At 800x352, 537x247, 320x176, and 800x352 again, it verifies:

- Header glyph pixels and the bottom-right background are present.
- A complete repeated redraw is pixel-identical.
- Changing foreground color changes the frame.
- Restoring it restores the exact previous pixels.

It then recreates the backend/device/target, compares against the previous
frame, rejects a zero-size resize, and checks that the existing target remains
usable. This is explicit recreation, not automatic device-loss recovery.
The static backends do not request continuous redraw. Negative tests cover
invalid arguments, unwritable output, and injected render failure producing
a failed report/nonzero exit without a success marker. The injection tests
failure reporting, not graphics-driver reset or recovery.

The existing GDI/core diagnostics and window tests also pass in Debug/Release.
Back-buffer PNGs were visually inspected locally for readable cyan/white text.
They do not establish that a visible desktop window presented correctly.

Reports: `artifacts/vt7/reports/<configuration>/Atlas`.
Build logs: `artifacts/vt7/atlas-build-debug.log` and `atlas-build-release.log`.

## Windows 7 results, 2026-09-11

The supplied logs identify Windows NT 6.1.7601, Release x64, compiler
19.44.35228, and build time `Sep 11 2026 06:26:45`. The issued archive is
`VT7-atlas-backend-proof-0.1-x64.zip`, SHA-256
`27ca1c434899ba0d81406342b5f28a92e3ab027dd6f15339907eb23cdb99081b`.
The log build identity matches the issued build; the tester did not supply
a separate hash of the extracted executable or archive.

All four automated reports end with `Automated backend checks passed: True`
and `Failed: False; frames=19`, for 76 automated frames in total. They pass
the descriptor, glyph/background pixel, repeat redraw, color-change, resize,
explicit device/target recreation, zero-size rejection, and surviving-target
checks. Hardware adapter IDs are 4098/29631; WARP reports 0/0. Both report
feature level 11.0. WARP is selected explicitly, not inferred from those IDs.

| Evidence | Hardware Direct3D11 | WARP Direct3D11 |
| --- | --- | --- |
| Initial visible session | 848 frames, no reported rendering failure | 432 frames, no reported rendering failure |
| Screenshots | Readable cyan/white fixed sample | Readable cyan/white fixed sample |
| Follow-up R-key session | 8 recreations, 10 frames | 6 recreations, 8 frames |
| After each R-key recreation | Successful next Present | Successful next Present |
| Minimize/restore and close | Recorded minimization, subsequent frames, clean exit | Recorded minimization, subsequent frames, clean exit |

Every observed Present in these sessions reports success. Both follow-up
sessions end with `Failed: False`. The R-key coverage gap from the initial
visible run is closed. This tests explicit recreation, not a real driver reset
or automatic recovery. Screenshots show no obvious corruption at the captured
sizes; they do not prove every intermediate frame during resizing was correct.
Cover/uncover is not independently identified by the current logs.

The visible launcher reuses its output filename. The follow-up files replaced
the initial 848/432-frame reports. Those initial totals were read and recorded
during the first review; the checksums below identify the currently supplied
files, not both generations of visible logs. Preserve copies before future reruns.

Current supplied log SHA-256 identities, read from `K:/VT7_work/Logs`:

```text
ef823d727f2b0930bc6a6d4334f25eeca2808684dd985b20b2ba4fde5d183230  Direct3D11-hardware.log
15812d721e6f9b83ae1d68af79bae61b422668b99613367170c2358d520ae3f2  Direct3D11-WARP.log
ec6fd22c37420fa39e5ce48690dd00f3daafaa5a8a271190ce707e9058f43b1d  Direct2D-hardware.log
ee5e88c3d16cd156dfe468095078676783e6029ad0f982ba5670f7a528907ba0  Direct2D-WARP.log
92d7b91bd98905a28bcd1b1c6b45fb7127115e4f93202cf0639bf1edca9a8b12  visible-Direct3D11-hardware.log
e514681d46c602ee15f59a63705c1600d43ac23f7115978234320a0d6130cdff  visible-Direct3D11-WARP.log
```

Screenshots supplied: `K:/VT7_work/Capture.PNG` (Direct3D11 hardware) and
`Capture2.PNG` (Direct3D11 WARP). No visible Direct2D session logs/screenshots
were supplied; its two automated runs pass. No new separate ESU, minimum-image,
additional GPU/driver, DPI/theme, or VM qualification is claimed for this build.
The logs do not inventory exact OS updates, driver/DLL/font versions, or DPI.

## Scheduling and remaining work

The harness has one owner thread for COM, graphics, window messages, and
teardown. It redraws on WM_PAINT, invalidates on resize, and does not use a
periodic render timer. Minimized/invisible/zero-client targets are not drawn
by its visible path. Escape/close unwinds the message loop, then destroys the
backend, swap chain, and HWND in that order. R explicitly recreates resources.

Initial Direct3D11 minimize/restore and explicit recreation now pass on the
tested Windows 7 setup. Wider expose/occlusion, Direct2D visible behavior,
DPI/themes, injected driver failure recovery, and quantified stress/idle
measurements still need testing. The future
renderer controller's render thread, bounded interruptible waits, and wake/
shutdown races are not implemented by this single-threaded harness. The
AtlasEngine branch skips hidden/minimized presentation, but this is not a
complete controller scheduling solution.

The fixed font metrics and ASCII glyph indices deliberately avoid a false
claim of shaping, fallback, terminal-cell, Unicode, or cursor acceptance.
Font mapping/shaping comes next under 2C before full controller integration.

## Reproducing the Windows 7 checkpoint

Package: `artifacts/VT7-atlas-backend-proof-0.1-x64.zip`.
Extract all files to a writable folder and run `RUN-ATLAS-TESTS.cmd`, then
`RUN-ATLAS-HARDWARE.cmd` and `RUN-ATLAS-WARP.cmd`. Test resize, cover/uncover,
minimize/restore, and R-key recreation. Send Logs plus visible screenshots.
Optional Direct2D launchers allow equivalent visible checks of that backend.

Use the normal non-ESU setup for iteration; obtain separate ESU confirmation
at milestone acceptance. Preserve failing/partial logs and describe
any hang. The batch scripts have no watchdog; the development PowerShell test
runner enforces a 60-second limit per spawned process. Neither utility needs
.NET, Power Automate, elevation, or system changes.

The old GDI archive remains separate and unchanged. This archive contains the
linked proof executable, three CRT DLLs, symbols, launchers, instructions, and
existing license/notices. It does not include a standalone renderer DLL or
claim to ship the unported AtlasEngine. No commit, push, or upstream merge is
part of this step. This documentation-only acceptance update does not rebuild
or replace the tested archive.
