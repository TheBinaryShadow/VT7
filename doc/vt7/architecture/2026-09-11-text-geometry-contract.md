# Text geometry contract v0.2

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

## Primary metrics and vertical ink policy

Following the upstream review and user approval, VT7's initial production target
is a fixed primary-font grid with overlapping ordinary-text ink. Row height does
not grow when a fallback face or stacked mark is encountered. Use upstream's
default metrics: primary `0` advance (0.5 em if unavailable), ascent + descent +
line gap, rounded total cell dimensions, and its centered, rounded baseline.
Font size/DPI are converted once. Future explicit cell-height settings must
preserve upstream's metric-resolution semantics, not modify rows per character.

Ordinary glyph ink can cross interior row boundaries without changing cell
ownership, cursor position, or copy order. Clip to the viewport and preserve
upstream's exceptions, including cell-bound box glyphs and DEC double-height
line halves. This is not a blanket removal of all glyph clipping. No general
vertical shrink or strict ordinary-text row clip is selected.

Sources: [upstream metrics](https://github.com/microsoft/terminal/blob/main/src/renderer/atlas/AtlasEngine.api.cpp),
[upstream text drawing and dirty bounds](https://github.com/microsoft/terminal/blob/main/src/renderer/atlas/BackendD3D.cpp),
and [Microsoft's Atlas overlap explanation](https://devblogs.microsoft.com/commandline/windows-terminal-preview-1-18-release/).
The reviewed current upstream source informs the policy, not an upstream merge
or a change to VT7's pinned source baseline.

The accepted 0.6/0.7 diagnostic lane keeps its original `M`-advance/separate-ceil
metrics. Probe 0.8 adds a distinct upstream-default metric lane; it must not
silently relabel those older images as upstream-metric evidence. Actual Atlas
integration, damage, clipping exceptions, and legibility remain acceptance gates.

## Natural ink, compression, and repaint

The 0.4 experiment separates advance fit from raster overhang. At its fixed
18 DIP font, 10 pixel cell width, and 96 DPI, preserve scale 1 when the natural
advance fits the allocated span and ink fits a two-pixel horizontal halo.
Use an integer baseline offset. Oversized groups use the 0.3 whole-ink transform,
no enlargement, and zero allowed ink spill beyond their cell span.
The two-pixel value is a probe parameter, not a DPI-independent shipping constant.

The 0.9 candidate adds a separate `FittedRow`, retaining the mapper snapshot and
rendering parameters alongside per-group transforms and measured ink. It uses
natural glyph advances within each whole source/core/shaping group, not an
already corrected pen advance to infer outline width. Source text, cell widths,
glyph identities and mapper arrays are not rewritten by fitting.

Its candidate natural allowance is `ceil(cellWidth / 5)` pixels. A half-pixel
per-column advance tolerance accounts for primary-grid rounding. Eligible natural
groups retain scale 1 and offset 0. Oversized groups use the whole available
allocation, reducing only horizontal scale until the actual raster fits without
spill. No fixed horizontal inset, vertical shrink, or ordinary row clip is added.
Measurements and draws must use matching rendering parameters and integer pixel
origins; actual draw bounds are checked too. Nonempty ink must not vanish.

This protects outside the declared natural allowance, not every pixel in an
adjacent cell: ordinary italic overhang remains legal. Compressed groups have
zero allowance. Private narrow-symbol aspect/legibility and script quality
remain visual gates. The grid-scaled allowance is an explicit experiment, not
a universal production constant or a replacement for Atlas-specific tests.

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

The initial candidate now uses logical-order analyzer shaping, matching upstream's
direction flags. A visual-bidi mode is not enabled. The required experiment
compares those paths without changing core text,
including cursor placement, selection, mixed numbers, marks, font/style splits,
wrapping, and reflow. Preserving joins within one captured RTL run does not prove
joins across runs. This contract fixes authority and safety rules; it does not
pretend that the open Arabic pixel-to-interaction mapping has been solved.

The [0.8 mapper candidate](../validation/2026-09-11-text-adapter-probe.md) implements
owned source/cell/glyph data and retained FontFace1 objects outside the probe
helper. It remains linked only into the independent probe. Its fixed `en-US`
locale, bounded input, lack of cache, styled-private fallback exclusions,
cross-face/style context, and horizontal ink policy need further work before
production integration. Snapshot-key rejection is not a concurrent cache test.

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
