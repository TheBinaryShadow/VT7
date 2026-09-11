# Isolated Atlas renderer target

`VT7.Renderer.lib` builds the eleven inherited non-PCH Atlas translation units,
the existing `ColorFix.cpp`, and VT7's `Win7Presentation.cpp`. Four shader
headers are generated from the inherited HLSL with the pinned toolchain.
`VT7.Renderer.vcxproj` is the authoritative source/feature list.

The library now supplies the real Direct3D11 and Direct2D backends to the
separate `VT7.AtlasProof.exe`. That harness bypasses AtlasEngine font mapping
and the renderer controller: it supplies fixed, pre-mapped Consolas glyphs in
an Atlas `RenderingPayload`. It is not the TerminalCore-backed VT7 viewport.
Neither VT7.Native nor the accepted GDI proof links this library.

Backend proof 0.1 has now passed all four Release backend/device combinations
on Windows 7 SP1 x64, with visible Direct3D11 hardware/WARP screenshots and
successful repeated R-key recreation. Local Debug/Release tests also pass.
This is acceptance of the fixed-glyph harness on that tested setup, not the
full engine, Unicode/fallback path, ESU matrix, or final renderer milestone.

## Windows 7 presentation adaptation

The `VT7_ATLAS` build selects Device1/Context1, SwapChain1, and FontFace1 types.
These are real queried interfaces, not emulated newer COM objects. The backends
query their Direct2D device contexts rather than casting render-target pointers.
The Direct3D backend uses Factory1 for rendering parameters; the newer
Factory2/fallback path remains separate and unported in AtlasEngine.

`Win7Presentation` is shared by the backend harness and the VT7 AtlasEngine
presentation branch. It requests hardware or WARP explicitly, derives the
adapter/factory from that device, and uses an opaque HWND with DISCARD, STRETCH,
one buffer, and zero flags. No newer DXGI factory export, DirectComposition,
SwapChain2, frame-latency waitable object, or Present1 optimization is required.
Every frame is fully redrawn before Present. The caller owns scheduling and
releases backend references before resize, target destruction, and teardown.

The harness is single-threaded and event-driven while visible, with no idle
timer. Its R key explicitly recreates resources. This is not automatic
device-loss recovery or the future controller's interruptible render scheduler.
Full engine/controller threading and lifetime acceptance remain outstanding.

## Deliberate boundaries

`RendererFeatures.hpp` exposes optional SDK declarations inside a push/pop
macro scope and then restores the Windows 7 target. This does not implement
those APIs. Nearby fonts, custom shaders, and Debug shader hot reload are
disabled. Both backends and all four shader sources still compile.
The backends use their standard monochrome path in the harness even on newer
Windows. The fixed sample does not exercise fallback, color fonts, font axes,
terminal-cell shaping, cursor behavior, or bitmap/soft-font paths.

AtlasEngine still requests newer DirectWrite font factory/fallback interfaces
in its constructor and font routines. It must not be constructed on Windows 7
until Milestone 2C adapts those paths. A successfully linked backend harness
does not establish a complete loadable AtlasEngine or renderer-controller port.
The independent `VT7.RendererProbe.exe` remains a separate capability tool.
Its 0.8 font experiment links TerminalCore for fixture cell spans and retains
DirectWrite callback runs, scans scalar coverage, fits whole ink, and preserves
RTL runs for diagnostics and a bitmap comparison. It does not
link this Atlas library or change the full engine's unsupported font boundary.
See `doc/vt7/validation/2026-09-11-font-mapping-probe.md` for supplied Windows 7
0.2 findings, and `doc/vt7/validation/2026-09-11-font-fitting-probe.md` for the
supplied 0.3 follow-up. Probe 0.4 adds natural-size glyph fitting with bounded
ink overhang; see `doc/vt7/validation/2026-09-11-natural-size-probe.md`.
The text-geometry contract is in `doc/vt7/architecture/2026-09-11-text-geometry-contract.md`.
The supplied Windows 7 0.4 run passes with natural-size Latin/italic output.
Probe 0.5 adds private OFL-licensed Unifont assets and bounded standalone-symbol
fallback, with two forced private-font fixtures. See
`doc/vt7/validation/2026-09-11-private-font-probe.md` and `oss/unifont/README.md`.
These assets are not installed into Windows or wired into AtlasEngine.
The supplied Windows 7 0.5 run passes: both private faces load, all 13 fixtures
map, and automatic fallback renders the missing U+1F600 in Supplementary C.
Pixel-derived font quality and narrow-symbol compression remain limitations.
Atlas font/interaction integration remains open. The next independent test scope
is in `doc/vt7/architecture/2026-09-11-font-geometry-test-plan.md`, starting with
size/DPI and vertical metrics, followed by differential repaint validation.
Probe 0.6 now implements the first offscreen matrix, preserving the 0.5 reference;
see `doc/vt7/validation/2026-09-11-geometry-probe.md`. The crop-copy and geometry-key
tests are not Atlas clipping/invalidation or production snapshot acceptance.
The supplied 0.6 Windows 7 matrix passes with the recorded stacked-mark overflow.
Probe 0.7 adds software differential repaint over fixed core-backed clusters,
with independent full-frame and negative comparisons. See
`doc/vt7/validation/2026-09-11-repaint-probe.md`; Atlas invalidation remains unchanged.
The supplied 0.7 Windows 7 run passes. The geometry contract now selects
upstream's fixed-grid/ordinary-text overlap policy with its clipping exceptions.

`Win7TextMapper.hpp/.cpp` is a reusable candidate currently compiled only by
RendererProbe 0.8, not by this Atlas library. It uses baseline layout callbacks
for face selection, retains FontFace1, then shapes in logical source order using
IDWriteTextAnalyzer. It owns source/cell/glyph data, uses upstream-default metrics
and complex-path advance correction, and rejects invalid spans/stale keys.
There is no cache, visual bidi mode, general private styled fallback, horizontal
ink fitting, or production controller integration. The 0.8 comparison separates
these unresolved behaviors from the accepted older diagnostic lanes. See
`doc/vt7/validation/2026-09-11-text-adapter-probe.md` for scope and evidence.

## Provenance and evidence

Atlas, ColorFix, and shader source remain Microsoft Terminal code under MIT,
with VT7 modifications in the files identified above. No external backport
code was introduced. The pinned WIL, GSL, fmt, inherited Chromium numerics,
and stb code retain their existing notices. The package carries the project
LICENSE/NOTICE and additional dependency license files.

In the source repository, see:

- `doc/vt7/architecture/2026-09-11-renderer-assessment.md`
- `doc/vt7/validation/2026-09-11-renderer-probe.md`
- `doc/vt7/validation/2026-09-11-atlas-backend-proof.md`

Shader outputs: `artifacts/vt7/obj/VT7.Renderer/<configuration>/shaders`.
Backend test reports/images: `artifacts/vt7/reports/<configuration>/Atlas`.
