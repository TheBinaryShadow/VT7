# Font assets, private collections, emoji and text rasterization

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P0 for repeatable renderer tests.

Later selection: the accepted [0.3.0 viewport](../validation/2026-09-12-atlas-viewport.md)
uses the approved pinned private Unifont/Unifont Upper assets and Atlas primary
metrics. The candidate font/fitting discussions below retain their original
research scope; they do not select more assets or replace the accepted baseline.

## Separate font coverage from rendering capability

An installed font can lack a scalar, a useful shaped sequence, a requested style, or a color representation. Conversely, an OS can lack the API needed to use a feature present in the font. A family name alone is therefore insufficient test metadata.

Recommended font inventory: family/subfamily names, file path and hash, font version, face index, outline format, static/variable status, simulations, selected weight/style/stretch, and fallback order. Record the actual selected face for each failing cluster.

DirectWrite's system collection is not the only supported source on Windows 7. Custom collections can expose bundled or embedded fonts through collection/file loaders and enumerators. Loader registration retains references; unregistration must be explicit rather than attempted from the loader destructor. Collection keys must remain valid for the loader's registered lifetime. [1]

**Recommendation:** private DirectWrite collections are a viable portable-font design. Keep the factory, loader, key storage, collection, faces and glyph caches in an explicit lifetime graph. Decide how system fallback and bundled families interact; a collection containing only one Latin font does not establish multilingual fallback.

Observed source hazard: FontCache.h contains a comment claiming IDWriteFontCollection1 supports Windows 7, whereas Microsoft documents Windows 10. The use is inside the nearby-font-loading branch and also depends on a newer factory, so this does not prove that the current proof executes an unsupported call. It does mean the comment must not guide a future bundled-font implementation. [9][10]

## GDI private fonts are a different mechanism

AddFontResourceExW with FR_PRIVATE makes a font process-private; a matching private name takes precedence over a public font for that process. FR_NOT_ENUM also prevents the caller from enumerating it. RemoveFontResourceEx releases a resource when no longer needed. [2]

**Inference:** do not assume a GDI private-font operation automatically implements the intended DirectWrite custom collection. Test each renderer's selected face independently. Changing global font installation to make a probe pass hides a deployment dependency.

## Static and variable fonts

DirectWrite's variable-font support is documented as a later Windows 10 feature, so arbitrary axis selection is not a Windows 7 baseline. [3] Cascadia provides static TTF/OTF alternatives; its own documentation notes that static TTF hinting quality differs from the variable build. [4]

**Recommendation:** if bundling Cascadia or another family, select exact static files for initial Windows 7 acceptance. Test regular/bold/italic selection rather than allowing synthesized styles to pass unnoticed. Do not label a font unsupported merely because a variable build behaves poorly; first compare a static instance.

Font redistribution needs the actual font license and notices. VT7's source license does not grant redistribution rights for fonts installed with Windows. Retain the selected font's license alongside the package; this is a packaging task, not permission to copy arbitrary system font files. [4]

## Emoji is several independent features

Windows color-glyph support for COLR/CPAL begins in Windows 8.1; later bitmap/SVG color formats require newer Windows versions. Ordinary monochrome glyph rendering remains distinct from color-run rendering. [5]

Unicode Emoji defines presentation selectors, modifier sequences, regional-indicator sequences and ZWJ sequences. These are sequences of text, not a guarantee of a single available glyph in every font/OS combination. [6]

**Expected Windows 7 baseline:** permit monochrome rendering where a suitable font and shaping path provide it; show a predictable missing-glyph result otherwise. Installing a newer emoji font does not by itself provide newer DirectWrite color APIs. An application-local color-font rasterizer would be a separate dependency and engineering project.

Do not turn unsupported sequence shaping into a decoding error. Preserve the original text in the buffer and clipboard even if the visual result is several glyphs or a replacement box.

## Rasterization and metrics

DirectWrite offers a Windows 7 bitmap-render-target path through IDWriteGdiInterop::CreateBitmapRenderTarget. This provides a useful software reference for a shaped glyph run independently of DXGI presentation. [7]

Proposed comparison matrix:

| Dimension | Cases |
| --- | --- |
| Rendering | ClearType, grayscale and aliased where supported |
| Background | Opaque dark/light; reverse video; selection |
| Style | True face vs synthesized bold/italic; underline/strike |
| Geometry | 100/125/150% system DPI; fractional em size; integer cell grid |
| Coverage | CJK, accents, Arabic/Indic, symbols, supplementary text |
| Terminal art | Box drawing, block elements, Powerline/private-use symbols |
| Font changes | Missing family, install/remove, face/version replacement |

**Recommendation:** do not compare raw image hashes across different drivers/font versions as the sole correctness criterion. Use semantic layout assertions plus controlled visual references. Check baseline, ascent/descent clipping, overhang, box-joining gaps and cursor alignment. Grayscale is the initial candidate for any path that cannot preserve ClearType's background assumptions.

The proof currently uses GDI Consolas metrics, while future Atlas will supply its own font/grid metrics. A font-size change must update the core grid and backend dimensions through one agreed path, not leave WPF, core and renderer using different cell sizes. [8]

## Sources

- [1] Microsoft, [Custom Font Collections for Windows 7/8](https://learn.microsoft.com/en-us/windows/win32/directwrite/custom-font-collections).
- [2] Microsoft, [AddFontResourceExW](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-addfontresourceexw).
- [3] Microsoft, [OpenType Variable Fonts](https://learn.microsoft.com/en-us/windows/win32/directwrite/opentype-variable-fonts).
- [4] Microsoft Cascadia, [font formats and license links](https://github.com/microsoft/cascadia-code).
- [5] Microsoft, [Color font support](https://learn.microsoft.com/en-us/windows/win32/directwrite/color-fonts).
- [6] Unicode Consortium, [UTS #51: Unicode Emoji](https://www.unicode.org/reports/tr51/).
- [7] Microsoft, [CreateBitmapRenderTarget](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritegdiinterop-createbitmaprendertarget).
- [8] [Proof viewport and metrics](../../../src/vt7/VT7.Native/surface.cpp).
- [9] [Inherited FontCache.h](../../../src/renderer/base/FontCache.h).
- [10] Microsoft, [IDWriteFontCollection1 requirements](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_3/nn-dwrite_3-idwritefontcollection1).
