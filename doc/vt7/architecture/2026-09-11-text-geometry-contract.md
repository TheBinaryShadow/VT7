# Text geometry contract v0.1

Date: 2026-09-11. Status: implementation contract for the next adapter work,
not a claim that interactive consumers or the adapter are implemented.
This follows the approved [research-driven plan](2026-09-11-research-driven-plan.md).

## Authority and coordinate spaces

TerminalCore owns text, cells, cursor state, viewport dimensions, and reflow.
The renderer must not infer terminal columns from glyph count, font advances,
ink bounds, or the host OS's Unicode version. The inherited width detector's
generated data identifies Unicode 16.0.0 in `src/types/CodepointWidthDetector.cpp`.
Actual row data is authoritative, including any configured width behavior.

Every rendered snapshot must identify its buffer/viewport revision, row origin,
font/settings generation, cell metrics, and DPI transform. Half-open ranges are
used throughout. Stale layouts must not be reused after reflow, font changes,
viewport movement, or replacement of the owning core. Capture under the core's
lock, copy text/attributes/maps, retain COM faces, then render without holding
the core lock. A retained face does not make pointers into callback arrays safe.

| Space | Representation | Ownership rule |
| --- | --- | --- |
| Source | UTF-16 range within an identified row snapshot | Preserve original code units, never replace source with glyph IDs or visual text. |
| Core cluster | Source range plus leading-cell and continuation-cell span | Combining sequences and surrogate pairs cannot be sliced by fallback or style boundaries. |
| Shaping cluster | Source range plus glyph range(s), face, direction, advances and offsets | May merge core clusters, for example a ligature; font boundaries can require additional analysis. |
| Logical grid | Row and half-open column interval | Comes from the core, not shaping. Missing glyphs retain the original cell width. |
| Pixel allocation | Logical cell rectangle transformed by viewport origin, metrics and DPI | Used for backgrounds, terminal cursor cells, selection cells, and session dimensions. |
| Ink/damage | Actual raster extent plus declared bounded allowance | Can exceed a cell rectangle, but cannot change source ownership or mouse columns. |

The present CoreCells helper reads `GlyphAt` and `DbcsAttrAt`, includes two-cell
leading spans, and excludes trailing continuation cells from duplicate text.
Its 200-unit single-row limit is a probe bound, not a production buffer design.
The next adapter must validate full source and glyph coverage with checked
arithmetic and reject unresolved cross-face/style splits through a core cluster.
Never silently drop marks or count a missing glyph as an absent source character.

## Grid interaction rules

In core-order mode, derive a mouse column from the inverse viewport/DPI transform
and floor(localX / cellWidth), not from ink. Reject outside-viewport points unless
the caller explicitly requests drag clamping. A continuation-cell hit retains
the raw terminal column for mouse reporting and identifies the owning cluster
for text selection. These are different outputs; do not silently rewrite one
into the other. Zero/negative dimensions and stale revisions must be rejected.

Selections/search/copy operate on original buffer text and core ranges. Text
range boundaries cannot divide a surrogate pair, combining cluster, or wide
continuation span. A rectangular selection needs its own explicit boundary
policy, not a renderer-created alternate source string. Ligature ink can span
several independently selectable core cells. Cursor/background drawing uses
core rectangles even when glyph ink overlaps them.

IME placement uses the active core cursor rectangle transformed into screen
coordinates by the HWND owner. Accessible text ranges use the same source/core
mapping; accessible bounds use current viewport geometry and clip to visibility.
The host must not maintain independent estimates for those positions. Session
resize derives integral columns/rows from the same metrics, never fallback fonts.
Implementations and interactive acceptance of these consumers remain later work.

## Natural ink, compression, and repaint

The 0.4 experiment separates advance fit from raster overhang. At its fixed
18 DIP font, 10 pixel cell width, and 96 DPI, preserve scale 1 when the natural
advance fits the allocated span and ink fits a two-pixel horizontal halo.
Use an integer baseline offset. Oversized groups use the 0.3 whole-ink transform,
no enlargement, and zero allowed ink spill beyond their cell span.
The two-pixel value is a probe parameter, not a DPI-independent shipping constant.

The production renderer must clear backgrounds before drawing ink, and account
for the union of old and new ink extents when invalidating/repainting. Repaint
intersecting neighboring glyphs as needed, clipped to the terminal viewport.
Otherwise legal italic overhang will be erased by the next cell's background
or leave stale pixels when text changes. A static full-bitmap test does not
establish partial-update correctness. Pixel bounds must be measured after the
actual transform; an alpha-bound prediction alone is insufficient acceptance.

## Direction and shaping ownership

The inspected inherited Atlas code sets the paragraph reading direction to LTR
in `DWriteTextAnalysis.cpp` and passes isRightToLeft=0 in `AtlasEngine.cpp` calls
to GetGlyphs and GetGlyphPlacements. Its existing path is therefore not evidence
that a paragraph-style bidi terminal is already implemented.

The initial production integration must preserve core column order unless a
separately selected visual-bidi mode has a complete interaction contract and
acceptance tests. The current probe's visual-run lane is a shaping experiment,
not the default terminal mode. Its per-cell bijection proves structural coverage,
but is not glyph hit testing for proportional joined Arabic. Do not feed that
lane directly into production cursor/selection logic or apply bidi twice.

Whether the initial complex-script adapter should use logical-order analyzer
shaping or a deliberate visual-bidi mode remains an explicit integration gate.
The required experiment is to compare those paths without changing core text,
including cursor placement, selection, mixed numbers, marks, font/style splits,
wrapping, and reflow. Preserving joins within one captured RTL run does not prove
joins across runs. This contract fixes authority and safety rules; it does not
pretend that the open Arabic pixel-to-interaction mapping has been solved.

## Before Atlas integration can be accepted

- Preserve the accepted 0.4/0.5 Windows 7 fixed-geometry comparison as a regression
  reference. Expand it through the [geometry/repaint plan](2026-09-11-font-geometry-test-plan.md).
- Add snapshot generation/lifetime tests and source/core/glyph/pixel range tests,
  including partial redraw with overhang, stale caches, and viewport clipping.
- Compare the logical-order complex-script path with the current visual probe,
  and settle the intended mode before routing interactive consumers through it.
- Exercise different cell sizes/DPI, style/face splits, and vertical metrics.
- Complete the Factory2/font-face capability audit and adapter cost/cache checks.

These gates do not install fonts or change the supported Windows update baseline.
U+1F600 missing-system-collection coverage is separately recorded, with KB2729094
user-confirmed installed. The user subsequently approved private OFL-licensed
Unifont assets; the supplied 0.5 run verifies bounded symbol fallback without
system font installation. This does not change the core geometry contract or
settle the final adapter, asset-failure, style, and font-quality policies.
