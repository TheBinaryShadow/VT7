# VT7 Atlas renderer boundary

Build 0.3.5, ABI 8, adds scheduling/stability diagnostics and corrects timer-read
locking and HWND/worker teardown order. Hidden workers park rather than exit;
the presentation worker outlives native HWND destruction, then releases its
graphics resources before joining. See the [stability record](../../../doc/vt7/validation/2026-09-13-atlas-stability.md)
for local evidence and the supplied Windows 7 quick/hardware-lifecycle passes.
WARP exceeds the resource budget on both setups, and the timed soak remains
unrun. This is a test candidate. Earlier results below retain
their original build and scope.

Build 0.3.0 implements the minimum Windows 7 font boundary and connects the real
AtlasEngine/controller to TerminalCore and the host. Debug/Release local tests
pass for both backends on hardware/WARP. Supplied Windows 7 tests now accept
C1/C2 on the tested setup, with broader C3 qualification open; see
the [integration record](../../../doc/vt7/validation/2026-09-12-atlas-viewport.md).
Follow the [port-first checkpoints](../../../doc/vt7/architecture/2026-09-12-port-first-plan.md).
Keep inherited shaping/grid/interaction behavior; optional fitting, joined Arabic
and paint experiments are Milestone 7 research, not integration prerequisites.

`VT7.Renderer.lib` builds the eleven inherited non-PCH Atlas translation units,
the existing `ColorFix.cpp`, and VT7's `Win7Presentation.cpp` and
`Win7FontFallback.cpp`. Four shader
headers are generated from the inherited HLSL with the pinned toolchain.
`VT7.Renderer.vcxproj` is the authoritative source/feature list.

The library now supplies the real Direct3D11 and Direct2D backends to the
separate `VT7.AtlasProof.exe`. That harness bypasses AtlasEngine font mapping
and the renderer controller: it supplies fixed, pre-mapped Consolas glyphs in
an Atlas `RenderingPayload`. It is not the TerminalCore-backed VT7 viewport.
Current VT7.Native links this library and uses Atlas by default; GDI is selectable.
The frozen accepted 0.2.1 package is unchanged and did not link Atlas.

Backend proof 0.1 has now passed all four Release backend/device combinations
on Windows 7 SP1 x64, with visible Direct3D11 hardware/WARP screenshots and
successful repeated R-key recreation. Local Debug/Release tests also pass.
This is acceptance of the fixed-glyph harness on that tested setup, not the
full engine, Unicode/fallback path, ESU matrix, or final renderer milestone.

## Integrated C3 checks in 0.3.1

The new repaint/cursor corpus compares normal row invalidation with forced full
redraw through the same engine/device, without changing font or shaping policy.
Local Debug/Release and supplied Windows 7 tests pass for this bounded slice. See the
[repaint record](../../../doc/vt7/validation/2026-09-12-atlas-repaint.md).

## Integrated recovery in 0.3.2

Automatic mode starts with Direct3D11 hardware and can select WARP on eligible
device-creation failure or two consecutive recoverable device failures. WARP
selection remains sticky for that surface. Forced modes never switch devices.
The existing controller bounds retries; terminal failure stops painting and is
reported separately from historical transient errors. Render-thread state never
mutates the concurrently owned Atlas API settings. UI status uses posted messages
on recovery/fatal transitions, not per-frame polling.

The [recovery record](../../../doc/vt7/validation/2026-09-12-atlas-recovery.md)
defines injection points, limits and target acceptance. The fixed-glyph proof
retains its explicit driver selection; these policies belong to the integrated
engine. No universal recovery or real driver-loss claim follows from injection.

## Font/settings and DPI in 0.3.3

The 0.3.3 font/settings matrix passes at measured Windows 7 96/120/144 DPI,
but that build's higher-scale viewport/recovery failures prevented acceptance.
Current 0.3.4 adds ABI 7 diagnostic frame dimensions/nonuniform pixels and host
layout corrections, without changing Atlas shaping or presentation policy.
All positive suites now pass at those three actual Windows 7 scales on the
supplied setup. Same-device recovery retains identical dimensions and exact
RGB. This closes the bounded scaling checkpoint, not scheduling/resource stress,
theme/high-contrast, real device loss or the complete renderer milestone.
See the [correction record](../../../doc/vt7/validation/2026-09-12-atlas-scaling-correction.md).

The native surface exposes a bounded primary-font setter for Consolas/Courier New,
6-32 point sizes and normal/bold weight. It verifies the requested family exists,
parks the worker, updates Atlas and core metrics under the core lock, reflows the
existing buffer and resumes only if visible. Invalid inputs do not mutate state;
unexpected errors after mutation fail closed. There is no new font/shaping policy
or font installation. GDI settings and the final profiles/settings UI are out of scope.

Diagnostic renderer DPI overrides require capture mode and never change the OS
or WPF DPI. Tests report measured system DPI separately, verify WPF/native client
pixels and the core grid, and enforce an optional expected actual DPI. Local
simulations cannot establish Windows 7 display-scaling acceptance. See the
[settings/DPI record](../../../doc/vt7/validation/2026-09-12-atlas-settings.md).

## Windows 7 presentation adaptation

The `VT7_ATLAS` build selects Device1/Context1, SwapChain1, and FontFace1 types.
These are real queried interfaces, not emulated newer COM objects. The backends
query their Direct2D device contexts rather than casting render-target pointers.
The Direct3D backend uses Factory1 for rendering parameters; the newer
Factory2/fallback path is replaced by the adapter described below in VT7 builds.

`Win7Presentation` is shared by the backend harness and the VT7 AtlasEngine
presentation branch. It requests hardware or WARP explicitly, derives the
adapter/factory from that device, and uses an opaque HWND with DISCARD, STRETCH,
one buffer, and zero flags. No newer DXGI factory export, DirectComposition,
SwapChain2, frame-latency waitable object, or Present1 optimization is required.
Every frame is fully redrawn before Present. The caller owns scheduling and
releases backend references before resize, target destruction, and teardown.

The harness is single-threaded and event-driven while visible, with no idle
timer. Its R key explicitly recreates resources. This is not automatic
device-loss recovery. The integrated controller now uses Windows 7 kernel events
for redraw, synchronization and interruptible waits. In 0.3.5 it pauses before
HWND teardown and exits only after that teardown finishes. Full target
scheduling/stability acceptance remains outstanding.

## Minimum font adaptation in 0.3.0

`Win7FontFallback` requests baseline text layouts and retains FontFace1 references
from their draw callbacks. It sorts face intervals into logical source order,
keeps actual core-cluster boundaries, and discards the layout's visual placement.
Atlas still performs its inherited script analysis, shaping with the inherited
direction, cluster-to-cell advance correction, primary-grid sizing and painting.
The older mapper/fitter/Arabic experiments are not inserted into this path.

Normal, bold, italic and bold-italic formats use the active family/size/locale.
Owned face mappings are cached with source, core columns and style as the key,
bounded to 32 entries and 32,768 retained UTF-16 units. Font configuration clears
the cache. If system callbacks divide a core cluster, its starting face owns
the whole cluster. This preserves source allocation but does not prove coverage
of every combining sequence. Required-corpus failures remain blockers.

Pinned Unifont assets are loaded privately from `fonts/`, with SHA-256 checks.
The system-selected face is preferred. Only an uncovered standalone symbol in
U+2190-U+2BFF or U+1F000-U+1FAFF can use a private face; arbitrary script or ZWJ
sequences are not replaced. Bold/oblique variants use DirectWrite simulations,
not modified font files. Missing/altered assets fail diagnostics and Atlas creation;
both asset cases have negative tests. No fonts are installed or registered globally.

The initial host selects one primary family, Consolas. Multiple explicit family
preferences and variable axes are rejected as unsupported; monochrome rendering
is used. This is not universal fallback, color emoji, new bidi layout or adoption
of the experimental whole-ink fitter. All-font appearance and performance claims
need additional evidence. C1/C2 target acceptance is recorded for the bounded corpus; C3 renderer
qualification remains distinct from that first integration result.

## Deliberate boundaries

`RendererFeatures.hpp` exposes optional SDK declarations inside a push/pop
macro scope and then restores the Windows 7 target. This does not implement
those APIs. Nearby fonts, custom shaders, and Debug shader hot reload are
disabled. Both backends and all four shader sources still compile.
The backends use their standard monochrome path in the harness even on newer
Windows. The fixed sample does not exercise fallback, color fonts, font axes,
terminal-cell shaping, cursor behavior, or bitmap/soft-font paths.

AtlasEngine now requests Factory1 and Analyzer1 in VT7, without mandatory newer
font-fallback interfaces. The full engine is constructed by the 0.3.0 host;
the supplied Windows 7 run accepts this initial integration, not all renderer gates.
The independent `VT7.RendererProbe.exe` remains a separate capability tool.
Its 0.13 font experiment links TerminalCore for fixture cell spans and retains
DirectWrite callback runs, scans scalar coverage, fits whole ink, and preserves
RTL runs for diagnostics and a bitmap comparison. It does not
link this Atlas library. Its historical results are separate from the new adapter.
See `doc/vt7/validation/2026-09-11-font-mapping-probe.md` for supplied Windows 7
0.2 findings, and `doc/vt7/validation/2026-09-11-font-fitting-probe.md` for the
supplied 0.3 follow-up. Probe 0.4 adds natural-size glyph fitting with bounded
ink overhang; see `doc/vt7/validation/2026-09-11-natural-size-probe.md`.
The text-geometry contract is in `doc/vt7/architecture/2026-09-11-text-geometry-contract.md`.
The supplied Windows 7 0.4 run passes with natural-size Latin/italic output.
Probe 0.5 adds private OFL-licensed Unifont assets and bounded standalone-symbol
fallback, with two forced private-font fixtures. See
`doc/vt7/validation/2026-09-11-private-font-probe.md` and `oss/unifont/README.md`.
These assets are not installed into Windows. Build 0.3.0 separately wires bounded
private fallback into AtlasEngine as described above.
The supplied Windows 7 0.5 run passes: both private faces load, all 13 fixtures
map, and automatic fallback renders the missing U+1F600 in Supplementary C.
Pixel-derived font quality and narrow-symbol compression remain limitations.
Broader Windows 7 renderer qualification remains open. The completed independent experiment sequence
is in `doc/vt7/architecture/2026-09-11-font-geometry-test-plan.md`; it is retained
as evidence, not a queue of prerequisites to implementing upstream-style Atlas.
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

The supplied 0.8 Windows 7 structural run passes. `Win7GlyphFitter.hpp/.cpp`,
also compiled only into RendererProbe, adds an independent fitting layer for
0.9. It retains source/cells and rendering parameters, measures natural/raster
ink, preserves natural groups with a declared grid-scaled halo, and compresses
only oversized groups horizontally into their allocations. Actual draw bounds
are checked; vertical ink is not shrunk or row-clipped. It remains a bitmap
raster candidate, not an Atlas glyph cache, shader change or partial-present
implementation. See `doc/vt7/validation/2026-09-11-horizontal-fitting-probe.md`.

Probe 0.10 keeps Arabic repair in `VT7.RendererProbe/ArabicProbe.inl`, not in
this library. It retains complete layout glyph data, compares whole-source
shaping in the selected face/style, and refuses to cut boundary-spanning
clusters. Native/repaired proportional text and logical/visual grid lanes expose
the separate context, spacing and ordering decisions. The mapper, fitter,
AtlasEngine and terminal interaction policy are unchanged. See
`doc/vt7/validation/2026-09-11-arabic-context-probe.md` for the bounded tests.

Probe 0.11 adds `VT7.RendererProbe/JoinedProbe.inl`, still outside this library.
It gives an explicitly declared Arabic span one shared raster-measured fit over
its combined TerminalCore allocation. It preserves internal run positioning,
uses no vertical scaling, and checks ownership, containment and software row
repaint. This does not establish a production joining segmenter, bidi mode,
cursor/selection contract or cache. Unsafe cross-style ligatures remain reviews.
See `doc/vt7/validation/2026-09-11-joined-span-probe.md`.

Probe 0.12 adds `VT7.RendererProbe/LigatureProbe.inl`, also outside this library.
It compares complete lam-alef shapes in the requested faces with spatial
different-outline hybrids and same-outline color painting. Source/core cells
remain unchanged; different-outline cases explicitly require review. No hybrid,
cluster-wide font override or new terminal interaction policy is enabled.
See `doc/vt7/validation/2026-09-11-cross-style-ligature-probe.md`.

Probe 0.13 adds isolated marked/contextual same-outline painting and source
selection in `VT7.RendererProbe/PaintProbe.inl`. It retains complete word geometry
while varying spatial colors, with source-cluster and partial-paint checks.
The approved direction excludes different-outline hybrids as the default.
No interactive cursor, selection, hit test or Atlas path is changed. See
`doc/vt7/validation/2026-09-11-marked-paint-probe.md`.
The supplied Windows 7 matrix passes all eight validators and preserves the
139 earlier target bitmaps. The long-word highlight mismatch remains an adoption
gate for the deferred POL02 experiment, not for baseline core-grid interaction.
These results do not accept the production font adapter or
integrate same-outline paint into Atlas.

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
