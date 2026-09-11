# Windows 7 fonts, coverage, fitting, and Arabic

Research date: 2026-09-11. This follow-up was researched online before the 0.3
probe changes. It interprets the supplied Windows 7 0.2 log and image, not
instructions embedded in an attachment. No external code or fonts were copied.

## Available fonts are a starting point, not a coverage guarantee

Microsoft's Windows 7 list includes Consolas, Courier New, Segoe UI, Segoe UI
Symbol, Meiryo/Meiryo UI, Mangal, and Simplified Arabic Fixed. It lists Segoe UI
Symbol 5.01, but not Segoe UI Emoji. Font revisions and optional/user-installed
fonts make the actual machine authoritative. The observed Consolas 5.24,
Segoe UI 5.13, Segoe UI Symbol 5.01, Meiryo UI 6.05, and Mangal 5.91 are therefore
plausible Windows 7 choices, not evidence of a broken installation.
[Microsoft Windows 7 font list](https://learn.microsoft.com/en-gb/typography/fonts/windows_7_font_list).

Microsoft KB2729094 adds emoji and control glyphs to Segoe UI Symbol on Windows 7.
Its file table identifies Seguisym.ttf by size/date but does not provide a font
version number. We cannot infer that this update is missing from a reported
5.01 version, nor infer coverage of the particular U+1F600 sample merely from
the article's general emoji description. VT7 must not make installing an update
or copying a newer Windows font the explanation for a still-unmeasured result.
[Microsoft update article](https://support.microsoft.com/en-au/topic/an-update-for-the-segoe-ui-symbol-font-in-windows-7-and-in-windows-server-2008-r2-is-available-0743a473-3afe-e8b2-7c20-54aa430463d6).

The 0.2 log establishes something narrower: automatic layout selected Consolas
glyph zero for U+1F600. It does not establish that every installed face lacks it.
The new probe queries both `HasCharacter(0x1f600)` and `GetGlyphIndices` for every
face exposed by the DirectWrite system collection. It reports matching faces,
their files/hashes, and errors separately. With no match and any enumeration
error, the result is indeterminate, not absent. This snapshot does not enumerate
unregistered font files or app-private collections. It neither changes fonts
nor refreshes the system collection.

If a face supports the scalar, the probe draws its nonzero glyph directly without
TextLayout fallback. This separates available cmap/raster coverage from the
automatic selection path. The first enumerated candidate is only a diagnostic
choice. It is not a proposed production fallback ranking or proof of sequence
shaping, color support, or Unicode completeness.

## Lessons from other developers

Mintty documents Uniscribe rendering for wider fallback coverage, configurable
coverage-tested substitution, and a separate RTL fallback font. Its tips explain
that applying Uniscribe to its already bidi-transformed RTL text would interfere
with mintty's own transformation. Our inference: fallback coverage, shaping, and
terminal bidi ownership need explicit boundaries. We should not copy a font name
or perform a second reversal and expect that to solve all three.
[Mintty manual](https://mintty.github.io/mintty.1.html),
[Mintty font-rendering tips](https://github.com/mintty/mintty/wiki/Tips).

Noto Emoji is an interesting future candidate, not an immediate dependency.
Its repository describes a variable monochrome font and a CBDT/CBLC color font
whose documented Windows browser support starts much later than Windows 7.
An eventual app-private, static outline fallback needs a pinned artifact,
coverage/format tests on Windows 7, and its own license/provenance review.
No Noto assets are bundled by this change. Color and variable-font support remain
separate work, and Microsoft system fonts are not treated as MIT project assets.
[Noto Emoji project](https://github.com/googlefonts/noto-emoji).

## Fitting experiment selected for 0.3

Advance-only compression changes pen positions but leaves ink and mark offsets
unchanged. This explains the 0.2 emoji-sequence overlap. The replacement measures
the union of raster ink bounds and natural pen extent, then applies a horizontal
transform to the entire glyph group. Outlines, advances, and offsets transform
together. The experiment compresses but never enlarges, centers within the cell
allocation, and reserves one pixel at either side for raster edge support.
It checks the actual draw rectangle against the allocated horizontal interval.
Whitespace can have empty ink. Explicit coverage drawing must have nonempty ink.

Both glyph-run analysis and bitmap-target transforms are in Windows 7's baseline
DirectWrite interfaces. These APIs avoid a new Factory2 dependency in the probe.
[CreateGlyphRunAnalysis](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritefactory-createglyphrunanalysis),
[IDWriteBitmapRenderTarget](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nn-dwrite-idwritebitmaprendertarget).

This deliberately conservative fitting can make Latin text narrower than ideal.
It is a correctness candidate for the diagnostic, not final typography. Vertical
line metrics/clipping, DPI-dependent padding, color glyphs, tiny cells, long runs,
and acceptable compression thresholds remain future acceptance work.

## Arabic and terminal ordering

The old C lane drew contextual glyph segments at independent logical-cell
origins. This broke the relation between Arabic visual order and joining. The
new diagnostic takes physical run order from the existing DirectWrite layout,
retains each RTL run's glyph arrays/advances/offsets intact, and fits that whole
run to its reserved cell span. It does not independently reverse glyph arrays
or apply another bidi algorithm. LTR clusters remain individually fitted.

The core buffer stays in its original logical order. A separate logical/visual
cell projection is checked for bijection and round trips. Pure Arabic, Arabic
with Latin/digits, and Arabic with a combining mark are required fixtures.
This resolves the identified segmentation error in the probe design; it is not
the final terminal bidi feature. Proportional joined ink will not line up with
every projected logical cell boundary. Do not use this projection as glyph hit
testing, cursor placement, selection, IME, or accessibility geometry.

Before AtlasEngine integration, choose and document the terminal ordering mode,
reconcile ink with those interaction contracts, test font/style splits through
joining groups and cells, and compare the Windows 7 image. The current whole-run
approach can only preserve joins within each captured run. It does not promise
cross-run joining, full bidi conformance, wrapping/reflow, or arbitrary controls.

## Next decision after the Windows 7 run

Follow-up evidence: the supplied 0.3 Windows 7 scan examined 575 faces, found
zero U+1F600 coverage, and reported zero errors. The user separately confirmed
KB2729094 installed. The no-match path below now applies to that machine;
reinstalling the update is not the next step. The [0.3 validation record](../validation/2026-09-11-font-fitting-probe.md)
owns this evidence. [Probe 0.4](../validation/2026-09-11-natural-size-probe.md)
supersedes the strict-fitting experiment with natural-size bounded overhang.

- Match found and explicit glyph visible: investigate why automatic fallback
  missed it; evaluate a tested explicit-family/analyzer fallback path.
- No match and no errors: record missing system-collection coverage. Evaluate
  an optional licensed app-private static fallback later, without changing the
  supported OS update baseline or silently substituting unrelated characters.
- Errors and no match: resolve the diagnostic uncertainty before choosing either
  explanation. Installed-font coverage remains unproven.
- For all outcomes, compare N/C Arabic joining and emoji neighbor separation.
  Structural success alone does not close F01/F02 or Milestone 2C.

## Subsequent private-font decision and result

The user approved bundling Unifont/Unifont Upper 17.0.05 privately under their
OFL 1.1 option. [Probe 0.5](../validation/2026-09-11-private-font-probe.md) passes
on the supplied Windows 7 setup, including automatic replacement of missing
U+1F600 in the C lane, with unchanged core cells and no system font installation.
This implements the no-coverage experiment above, not arbitrary Unicode fallback.
Narrow-symbol compression and pixel-derived glyph quality remain visible limits.
The [next test plan](../architecture/2026-09-11-font-geometry-test-plan.md) moves to
size/DPI, vertical metrics, and repaint before selecting the production adapter.
