# DirectWrite fallback, shaping and Atlas adaptation

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P0; this is a design blocker for the real renderer.

Later implementation: [0.3.0](../validation/2026-09-12-atlas-viewport.md)
integrates the minimum face-selection adapter and removes mandatory newer
font-fallback interfaces from the VT7 path, with bounded supplied Windows 7
C1/C2 acceptance. U+1F600 and the tested machine's missing system coverage are
identified in the [research index](README.md#planning-adoption). The original
missing-glyph experiment and adapter alternatives below are historical inputs,
not the current C3 task or a requirement to replace the integrated adapter.

## Supported boundary

IDWriteFactory1 is documented for Windows 7 with the Platform Update. IDWriteFontFallback, including the public system-fallback mapper obtained from Factory2, has a Windows 8.1 minimum. [1][2]

Observed in repository: AtlasEngine startup requests Factory2 and system fallback. The working tree has begun adapting shared/backend types to Factory1 and FontFace1, but this does not remove the engine's mandatory fallback dependency. [3]

**Conclusion:** lowering interface typedefs alone is insufficient. The port needs a different supported way of selecting fonts and producing shaped runs.

## Viable experiment: IDWriteTextLayout callbacks

IDWriteTextLayout::Draw and IDWriteTextRenderer::DrawGlyphRun are available on Windows 7. Draw invokes the supplied renderer for glyph runs and other layout content; DrawGlyphRun supplies a font face, run data and an associated text description. [4][5]

The higher-level DirectWrite text layout system includes script analysis, font fallback, shaping and layout. This makes it a plausible way to access OS-resolved fallback without the newer public MapCharacters API. [6]

**Proposed adapter, not yet proven:**

1. Build a UTF-16 row/range description from the core with a map from text offsets to logical terminal cells.
2. Set the intended base family, weight, style, size, locale and horizontal layout policy.
3. Disable layout wrapping for the experiment so DirectWrite does not independently create terminal lines.
4. Collect each callback's text range, cluster map, font face, glyph IDs, advances, offsets, bidi level and baseline.
5. Copy callback-owned arrays before returning and retain needed COM references.
6. Convert the runs to Atlas's row/glyph representation without splitting a cluster or deriving columns from natural advances.
7. Reconcile fallback scale/baseline and cell allocation, then compare with the GDI reference and source text.

Copying callback data and retaining faces are proposed ownership requirements for an asynchronous renderer; the callback interface itself is not an owned cache.

## Alternative: explicit font selection plus analyzer

IDWriteTextAnalyzer::GetGlyphs accepts a specified font face, script analysis, direction, locale and typographic features. Its cluster map describes character-to-glyph relationships. The documented initial allocation estimate can be too small; insufficient buffers require retry, and actualGlyphCount is meaningful only on success. [7]

**Inference:** an explicit fallback-family list with analyzer shaping is controllable, but VT7 then owns fallback policy, script/language coverage and run segmentation. Scanning individual UTF-16 units or selecting a font independently for every scalar is not an adequate replacement for shaping a contextual cluster.

Evaluate both approaches using the same corpus. Compare layout cost, cache behavior, missing-glyph reporting, script correctness, fallback metrics and ability to respect terminal-cell boundaries. Do not select solely on Latin throughput.

## Current missing-glyph discrepancy

The recorded Windows 7 probe has eight runs, two faces, 60 glyphs and one missing glyph; the developer machine has three faces and no missing glyphs. The probe does not identify the offending character. [8]

**Next experiment:** emit a record per glyph run containing:

- Full input code points and escaped UTF-16 units.
- Text position/length and cluster map.
- Font family, face name, file path/version/hash, face index and simulations.
- Glyph IDs, especially zero IDs, and affected source ranges.
- Locale, bidi level, measuring mode, size, baseline, advances and offsets.
- Font-interface QueryInterface HRESULTs.

A zero glyph ID is a diagnostic lead. It must be correlated with text and pixels; aggregate glyph/run counts are not a Unicode coverage specification.

## Atlas-specific hazards to audit

Observed in repository: both Atlas backends use DirectWrite/Direct2D-related glyph paths. BackendD3D is not independent of Direct2D just because its final renderer uses D3D. Its glyph cache also has assumptions about font-face identity returned by the mapper. [9]

Recommended checks:

| Risk | Required proof |
| --- | --- |
| Face-pointer identity differs between layout calls | Cache keys remain correct and bounded; COM lifetime is retained |
| Fallback glyph has a larger ascent/descent | No clipped accents or baseline jumps |
| Italic/ligature overhang crosses cells | Invalidation includes affected pixels without changing logical width |
| Style split bisects a cluster | Defined shaping and color policy |
| New font installed or selected | Font/layout/glyph caches invalidate together |
| Supplementary character | No UTF-16-half font lookup or copied half-surrogate |
| Bidi run | Glyph order and offsets map to the intended terminal policy |
| Missing family | Predictable fallback and a useful diagnostic |

Font mapping, shaping, rasterization, cell layout and presentation must each pass independently. A successful layout call with nonempty pixels proves only a small part of that chain.

## Sources

- [1] Microsoft, [IDWriteFactory1](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_1/nn-dwrite_1-idwritefactory1).
- [2] Microsoft, [IDWriteFontFallback](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_2/nn-dwrite_2-idwritefontfallback).
- [3] [AtlasEngine.cpp](../../../src/renderer/atlas/AtlasEngine.cpp), [common.h](../../../src/renderer/atlas/common.h).
- [4] Microsoft, [IDWriteTextLayout::Draw](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextlayout-draw).
- [5] Microsoft, [IDWriteTextRenderer::DrawGlyphRun](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextrenderer-drawglyphrun).
- [6] Microsoft, [Introducing DirectWrite](https://learn.microsoft.com/en-us/windows/win32/directwrite/introducing-directwrite).
- [7] Microsoft, [IDWriteTextAnalyzer::GetGlyphs](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextanalyzer-getglyphs).
- [8] [Renderer probe evidence](../validation/2026-09-11-renderer-probe.md).
- [9] [BackendD3D.cpp](../../../src/renderer/atlas/BackendD3D.cpp), [BackendD3D.h](../../../src/renderer/atlas/BackendD3D.h), [BackendD2D.cpp](../../../src/renderer/atlas/BackendD2D.cpp).
