# Milestone 2C: next geometry and repaint tests

Date: 2026-09-11. Status: implementation plan, no new build or runtime acceptance.
Depends on the [geometry contract](2026-09-11-text-geometry-contract.md) and the
accepted bounded [Windows 7 probe 0.5 result](../validation/2026-09-11-private-font-probe.md).

## Execution order and boundaries

1. Build probe 0.6 for primary-font grid metrics, size/DPI transforms, vertical
   ink, and fallback fitting. Test locally, then return a separate Windows 7 package.
2. Add a separately versioned differential repaint experiment after reviewing
   the geometry result. Test incremental updates against full redraw.
3. Resolve production font mapping/cache/style and ordering contracts, complete
   the newer-interface audit, then integrate into Atlas. Do not route the current
   visual-bidi diagnostic directly into production interaction code.

Keep the accepted GDI viewport and fixed-glyph Atlas harness unchanged during
the first two experiments. Do not add session plumbing, font installation,
new font assets, a Unicode-table upgrade, color emoji, or an ESU prerequisite.
MIT application code and the separate OFL font licenses remain unchanged.

## First build: geometry and fitting

Keep the existing 13-fixture 0.5 lane at 18 DIP, 10-pixel cells, and 96 DPI as a
fixed reference. The new metric-derived matrix is additional, not a silent
replacement of that reference. Do not overwrite the accepted 0.5 archive.

| Dimension | Planned cases | Required observation |
| --- | --- | --- |
| Font size and scale | 12, 18, 24 DIP at 96, 120, 144, 192 DPI | Distinguish DIP and device pixels; record rounding and effective transforms. |
| Grid and baseline | Primary Consolas metrics, then system/private fallback | Derive cell width/height and baseline from the selected primary face. Fallback never changes the grid. |
| Text and styles | Existing corpus plus descenders, stacked marks, decorations, and adjacent narrow/wide glyphs | Preserve source and cell ownership; inspect horizontal and vertical ink, not just advances. |
| Edges and neighbors | Contrasting adjacent backgrounds, first/last columns, top/bottom rows | Record visible clipping separately from lost interior ink; expose compressed or overlapping glyphs. |
| Transitions | Repeated size/DPI changes and restoration to the initial configuration | Reject stale snapshot/font metrics; restored deterministic output matches a fresh render. |

Specify and log the primary-metric rounding policy before judging output. Record
face identity, em size, device scale, cell dimensions, baseline, original/fitted
ink rectangles, compression factor, and effective clip. Do not infer a shipping
halo by multiplying the current two-pixel diagnostic constant without measuring
actual raster bounds. Label any tested allowance explicitly in device pixels.

Keep horizontal compression as a measured experiment. Compare private glyph
appearance across sizes and record how much the one-cell yin-yang is compressed.
Do not widen TerminalCore cells, replace text, discard marks, or silently shrink
all fonts to make coverage pass. Vertical metrics may expose a new policy decision;
record it before adding general vertical scaling or clipping away meaningful ink.

Acceptance for this build:

- All planned cases are accounted for, with fresh reports and images. Unsupported
  or unresolved cases are explicit failures/deferred results, never omitted passes.
- Source/core spans remain identical at every size and scale. Grid dimensions
  come from the primary face, independent of the selected fallback glyph.
- Required private glyphs remain nonempty. Interior ink stays within the declared
  policy; viewport clipping is intentional and reported. Existing natural-size
  Latin/italic checks remain valid in the frozen reference lane.
- Independent checks validate reported bounds. Deterministic transition round
  trips reject stale metrics and reproduce a fresh render on the same machine.
- Local Debug/Release suites and binary/license audits pass before handoff.
  Windows 7 results include full logs and comparison images, with visual review
  of baseline alignment, marks, adjacent text, compression, and edge behavior.

Offscreen DPI simulation does not prove actual HWND sizing or display-DPI
transitions. Record the tested Windows 7 desktop DPI separately when testing a
real window; do not require a desktop setting change or logoff for the first
offscreen package. Physical display and lifecycle acceptance remain separate.

## Second build: differential repaint

Use the accepted geometry configuration and deterministic state transitions:
italic to space, narrow to wide and back, combining-mark insertion/removal,
private fallback to ordinary text, foreground/background and style changes,
edits beside overhanging glyphs, and viewport-edge clipping. Include top/bottom
row damage and repeated alternating states. Keep actual terminal scroll/reflow
integration in its later controller tests.

For every transition, render the final state two ways: a fresh full redraw and
the proposed incremental path starting from the previous frame. Compare pixels
on the same renderer, machine, font set, scale, and antialiasing configuration.
Require exact equality for this controlled test; investigate mismatches rather
than relaxing a tolerance without a documented reason. Also require pixels
outside declared damage to remain unchanged.

Damage must include old and new ink plus affected neighbors, with backgrounds
cleared before intersecting glyphs are repainted and the viewport clip applied.
Log damaged rectangles, snapshot generations, and mismatch coordinates/counts;
save full/reference/incremental/difference images on failure. Deliberately omit
old-ink or neighbor damage in a negative test and require the comparator to catch it.
Repeat backend-specific checks when the real Atlas path is integrated; success
in this isolated experiment is not acceptance of Atlas's own invalidation code.

## Decisions still required before integration

The tests above do not settle logical-order complex-script shaping versus an
explicit visual-bidi mode, joins across font/style runs, interaction mapping,
private-face caching and lifetime under settings changes, production missing-font
behavior, or mandatory Factory2/font-face removal. Those remain 2C gates.
Ask the user before a material policy change such as broadening bundled fallback,
changing default cell proportions, or accepting intentional loss of glyph ink.

Each build must have a separate validation record, frozen package hash, and clear
local versus Windows 7 evidence. Reuse the existing toolchain and regression
suites; do not claim completion of Milestone 2 from another static bitmap alone.
