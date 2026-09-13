# Milestone 2C: horizontal fitting and neighbor protection, probe 0.9

> Historical validation record. Status and next steps below describe this checkpoint.
> For current work, see the [handoff](../HANDOFF.md) and
> [0.3.5 C3 stability investigation](2026-09-13-atlas-stability.md).

Planning update, 2026-09-12: this fitter is an optional candidate, not a required
replacement for upstream Atlas placement. Preserve its evidence under POL04 in
Milestone 7. Actual source/cell errors or lasting repaint corruption remain
renderer blockers. The [port-first plan](../architecture/2026-09-12-port-first-plan.md)
owns current sequencing; the results below retain their original scope.

Date: 2026-09-11. Branch: `initial-implementation-and-assessment`.
Source base: `3dcc155c96c9a7037bbf2137006e48b877cd1d8d` plus this uncommitted work.
Release stamp: `Sep 11 2026 16:00:47`, compiler `194435228`.
Development runtime: Windows NT 10.0.19044. The supplied Windows 7 0.9
containment/repaint run passes; final fit quality remains open. See below.

## Motivation and scope

The [supplied Windows 7 0.8 run](2026-09-11-text-adapter-probe.md) passes structural
mapping but exposes ink wider than its cells: the emoji sequence draws over its
following B, and private Unifont yin-yang exceeds one column. Correcting the
final advance, as the mapper does, does not by itself constrain glyph outlines.
The user approved tackling horizontal fitting while keeping Arabic work open.

`Win7GlyphFitter.hpp/.cpp` is a separate candidate layer compiled only into the
renderer probe. It consumes the owned logical-order mapper snapshot. It does
not change the mapper's source, cells, glyph IDs, advances, face selection,
direction flags, font metrics or private-fallback scope. It does not link into
AtlasEngine, modify the accepted GDI/Atlas proofs, or change the native ABI.

All 67 earlier reference/geometry/repaint/adapter images remain frozen lanes.
Twelve additional images compare R (raw mapper) and F (fitted), 79 total.

## Fitting contract

Each whole core/shaping group is measured using its natural advances and glyph
offsets. The fitter retains a copy of the snapshot and rendering parameters.
It uses baseline DirectWrite glyph analysis to size scratch space, then measures
the actual bitmap rasterizer. No callback pointer or temporary layout is reused.

- Natural groups use horizontal scale 1 and offset 0 when advances fit with a
  half-pixel-per-column grid-rounding tolerance and ink fits the declared halo.
- The candidate halo is `ceil(cellWidth/5)` pixels, matching the older two pixels
  at a ten-pixel cell, but scaling with the primary grid. It is not a shipping
  constant or a guarantee that ordinary overhang cannot enter adjacent cells.
- Oversized groups use the union of natural advance and whole ink bounds. Start
  with the full available horizontal allocation and no permanent inset. Center
  the transformed bounds; reduce horizontal scale by 5% per retry if the actual
  raster still escapes, with at most 16 reductions. Compressed groups have no halo.
- Nonempty ink must remain nonempty. Vertical scale stays 1; baseline/row height
  are unchanged and ordinary text is not row-clipped. This does not manufacture
  composed/color emoji or make a one-cell symbol square by widening core cells.
- Preparation and drawing use retained rendering parameters, pixel scale 1 and
  integer row origins. Actual final draw bounds are checked against the declared
  horizontal limits, not just predicted alpha bounds. Existing target transforms
  are restored after drawing. Actual ink is returned for damage accounting.

This is a candidate bitmap-raster implementation, not an Atlas shader/cache
design. Scratch dimensions are capped at 8,192 per axis and 16,777,216 pixels,
with padding and edge checks to reject a clipped measurement. Cell width is
bounded to 1,024 and draw origins to the tested API's explicit numerical bounds.
Together with the mapper's input bounds, these are engineering limits, not a
new terminal product promise. No cache/performance acceptance is implied.

## Tests and independent checks

Twelve size/DPI combinations cover 12/18/24 DIP at 96/120/144/192 simulated DPI.
Each uses 12 fixtures: emoji with A/B neighbors, forced private BMP/SMP, Latin,
italic, bold, CJK with neighbors, stacked marks, Indic with neighbors, mixed
Arabic, Arabic with a real style split, and mixed Hebrew. There are 144 fixtures.

For each glyph group, a 512x256 target contains contrasting neighbor sentinels
over its full height. Draw at an integer-equivalent origin, compare RGB changes
against the original pixels, and require zero changes outside the horizontal
allocation plus declared halo. The target is deliberately taller than one row,
so vertical overhang cannot hide an escaping horizontal pixel. Actual bounds
must equal the prepared bounds at that origin and nonempty groups must alter
pixels. Final comparison-lane drawing also checks its own actual ink bounds.

At every size/DPI the forced private BMP is deliberately drawn unfitted. The
sentinel comparator must detect its escape, 12 negative controls total. A CLI
injection (`--inject-fit-failure`) disables one fitted transform and must make
the executable baseline fail with the neighbor-protection diagnostic.

The complete Latin and italic rows must stay uncompressed and pixel-identical
to raw mapper drawing at every configuration. Source/cell arrays and glyph IDs/
advances are checked for preservation. The PowerShell validator independently
checks fixture identity, source/group coverage, allocation math, scale/halo,
reported bounds, nonempty ink, natural regressions, negative controls and images.
It does not independently rasterize DirectWrite glyphs or decide visual quality.

## Conservative partial-row repaint

Six state changes per size/DPI alternate emoji, spaces, supplementary fallback
and stacked marks, then restore the initial state: 72 transitions. Damage is
the union of old/new whole-row allocations and measured ink, including overhang.
It remains smaller than the 512x256 canvas. This intentionally redraws the
complete short fixture row, not a minimal selection of dirty glyphs.

A fresh full redraw is the reference. The incremental path starts from its own
previous frame, seeds a scratch surface, clears damage and redraws the new row,
then commits only damage by blit. It never copies pixels from the reference.
Full-canvas RGB must match exactly; outside-damage pixels must remain unchanged;
the last state must match the initial image. On mismatch, separate full and
incremental failure bitmaps are saved. Successful extra repaint images are not
saved; the report contains all 72 records. The earlier 0.7 independent saved
triples and minimal-glyph experiment still run unchanged.

This tests software row damage, not Atlas invalidation, GPU partial present,
concurrency, actual scrolling/reflow, device loss or a session backend.

## Local evidence

Pinned Debug and Release builds and renderer suites pass, including the new
independent validator and overflow-injection baseline failure. Both report:

- 52 required baseline checks, zero failures on the local font inventory.
- 144 horizontal fixtures, 984 groups, 107 compressed groups.
- 12 detected unfitted-overflow controls, zero positive sentinel escapes.
- 72 exact partial-row comparisons and outside-damage checks.
- Natural Latin/italic pixels unchanged at all 12 size/DPI combinations.
- The existing 204 geometry fixtures, 192 adapter fixtures, 1,344 stale-key
  checks, 480 repaint comparisons and 24 older negative controls still pass.

Counts of groups/fits depend on font mapping. The independent script derives
them from the report instead of requiring the development machine's 984/107.
Both Atlas backends on hardware/WARP pass 19 frames per combination in Debug and
Release. Both host diagnostics/window-smoke suites and PE/import audits pass.
A fresh run of the frozen 0.8 executable confirms that all 67 earlier bitmaps
remain byte-identical to their 0.9 outputs on this development machine.

Local images at 18 DIP/96 DPI and 24 DIP/192 DPI show the emoji fixture's B clear
of the oversized group and retained stacked marks. The private yin-yang remains
visibly compressed into one column, a quality limitation requiring review.
Arabic/Hebrew still use logical terminal order; fitting can change horizontal
appearance but does not settle joining/context or interactive bidi behavior.
This is not final typography acceptance.

## Windows 7 handoff

Extract `artifacts/VT7-renderer-probe-0.9-x64.zip` into a fresh writable folder,
keep `fonts/`, and run `RUN-RENDERER-PROBE.cmd` without elevation. Return the log
and all 79 bitmaps in a ZIP, including any failure images if generated. Look at
the new `.horizontal-<size>-<dpi>.bmp` R/F comparisons, especially the following
B, private narrow symbol, italic edges and stacked marks. The raw lane retains
its known overflow intentionally for comparison.

No fonts are installed and no assets, licenses, OS prerequisites, DPI/code-page
settings or host UI are changed. The same MIT code and OFL font licensing applies.
The supplied 0.9 Windows 7 execution now passes the containment checks below.
Atlas integration, Arabic context/style handling, cache/lifetime costs and final
fit quality remain open.

## Supplied Windows 7 result

Archive `probe-0.9-bitmaps-and-log.zip`: 2,869,267 bytes, SHA256
`C0A7BFF178FD98CEFCA6806403199062992C7C76F171FB04B7CAB955349008F8`.
The 80 flat entries contain one log and 79 BMPs, 374,959,248 bytes uncompressed.
Evidence is preserved under ignored
`artifacts/vt7/evidence/horizontal-probe-win7-c0a7bff1`.
Log SHA256: `D99028E868CDD86886E01F7CB30227D28C0CECF51FBA24196E7EDA388B1DFDAD`.

The log reports Windows NT 6.1.7601, Release x64 built Sep 11 2026 16:00:47,
compiler 194435228, captured 2026-09-11 14:10:09 UTC. All 51 required checks pass.
The geometry, repaint, adapter and horizontal independent validators pass:

- 144 horizontal fixtures, 984 groups, 94 compressed groups.
- 12 detected raw-overflow controls and 72 exact partial-row repaints.
- Zero positive protection escapes or reported failures.
- Natural Latin/italic pixels identical across all 12 configurations.
- All 67 earlier BMPs byte-identical to the supplied 0.8 target evidence.

Inspection at 18 DIP/96 DPI and 24 DIP/192 DPI confirms the emoji sequence no
longer covers the following B, and vertical marks remain. The one-cell yin-yang
is noticeably squeezed. Woman/laptop remain separate monochrome glyphs, not a
composed emoji. Accept containment as a bounded result, not final typography.
This archive does not independently establish a second ESU-machine run.

## Frozen package verification

The assembled Release package passes the complete renderer/geometry/repaint/
adapter/horizontal/asset-failure suite and its packaged PE/import audit. All
19 manifest entries were independently rehashed. All 79 packaged Release bitmap
outputs match Debug byte-for-byte. The accepted 0.7 and 0.8 archives retain their
recorded hashes. Changed-text punctuation, 91 local Markdown links and
`git diff --check` pass. No commit or push was made.

Archive: `artifacts/VT7-renderer-probe-0.9-x64.zip` (8,357,184 bytes).

SHA256: `DA4F45E21210899242CA8337915A686BA37E442F6F23A77AD769665A90EB38DA`.
