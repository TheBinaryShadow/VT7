# Probe 0.11: joined Arabic spans inside a terminal allocation

Planning update, 2026-09-12: shared-span fitting/centering and its interaction
questions are deferred under Milestone 7/POL01-POL02. They must be resolved before
adopting this enhanced layout, not before integrating upstream-style Atlas.
See the [port-first plan](../architecture/2026-09-12-port-first-plan.md).
The recorded results and historical follow-ups below retain their original scope.

Date: 2026-09-11. Milestone 2C / F01-F02. Supplied Windows 7 matrix passes.
Branch: `initial-implementation-and-assessment`. Built on the existing 0.10
working-tree implementation, without committing or replacing the frozen package.

## Question and boundaries

The supplied [0.10 Windows 7 result](2026-09-11-arabic-context-probe.md) verifies
context repair, but fitting each glyph group to its own cells visibly separates
Arabic letters. Can the repaired word retain its internal spacing while one
shared transform fits the complete word into the sum of its core columns?

`VT7.RendererProbe/JoinedProbe.inl` tests that question separately from the
mapper and AtlasEngine. The span is explicitly declared by each fixture. This
is not a general Unicode joining segmenter, a mixed-paragraph bidi solution or
an enabled terminal rendering mode. Ten Arabic fixture words are placed between
literal A/B neighbors. The complete source is read through real TerminalCore,
and the word's source/cell ranges must match that full row after a one-unit,
one-column offset. Shaping groups must cover the word exactly once.

The primary Consolas grid determines allocation for every fixture, including
Arial/Times New Roman and Segoe UI fallback. Font advances never invent terminal
widths. Source/cell/glyph ownership remains logical, but the Arabic word uses
the diagnostic natural visual order already exercised by 0.10. Individual glyph
positions do not claim to be aligned with their original individual core cells.

## Shared fit

The probe reuses 0.10 face/style context repair and retains glyphs, offsets,
natural advances and font faces. It reconstructs physical run order from the
unmodified layout, then places repaired runs at cumulative natural advances.
All runs are moved to the same primary baseline while preserving their relative
baseline offsets. No layout or callback lifetime is needed to draw the snapshot.

One matrix applies to every glyph, run origin and offset in the span:
horizontal scale is positive and at most one; vertical scale stays one. A
natural-width span is centered with an integer translation and is never stretched
to consume spare allocation. A wider span is compressed as a whole. Its measured
ink and natural advance determine the initial fit; actual raster containment
is rechecked, with at most 16 five-percent reductions if needed.

Measurement uses a bounded 2048 by 512 bitmap. Nonempty ink and a padded border
are required, so a clipped scratch result cannot masquerade as a successful fit.
Horizontal ink must stay strictly inside the declared combined allocation.
Ordinary vertical ink is not clipped to the row. Both scratch and final colored
comparison surfaces check changed pixels outside the horizontal allocation.
This protects the outside region, not natural neighbor overhang already inside
the word's own allocation. There is no font installation or OS-setting change.

## Comparison images and unresolved policy

Each `.joined-<size>-<dpi>.bmp` shows three lanes:

- S: 0.10-style contextual glyph groups fitted to separate visual cells.
- J: one shared-span fit inside the same combined allocation, between A/B.
- P: the repaired word at natural proportional spacing, without A/B or grid fit.

The long word intentionally exposes the centering tradeoff: natural text may
occupy only part of its terminal allocation. Correct source ownership and a
contained image do not settle visual cursor stops, selection backgrounds,
copy/hit testing, reflow, wrapping or alignment preferences.

Cross-style lam-alef keeps the existing safe policy. A contextual shaping
cluster that crosses a style boundary is not sliced. The affected original
runs and requested styles remain, and REVIEW is logged. Shared fitting cannot
make that unresolved ligature correct. Production policy may require a larger
shaping/painting unit, but this experiment neither chooses one nor drops styles.
ZWJ/ZWNJ fixtures retain the original controls and native shaping behavior;
grouping them into one allocation does not instruct disconnected letters to join.

## Tests

Ten fixtures at 12/18/24 DIP and 96/120/144/192 offscreen DPI give 120 cases and
12 new BMPs. They cover plain/marked Arabic, bold/italic/family/fallback splits,
lam-alef, join controls, an oversized deliberately nonjoining word and a longer
joined word. The original 103 images remain a separate regression reference.

Per fixture, tests require:

- Complete unchanged source/cell ownership, with the word excluding A/B cells.
- Actual positive raster ink contained horizontally in the combined allocation.
- Equality with a separately assembled 0.10 natural reference under the same
  matrix. This tests retained geometry/placement, not an independent font engine.
- A five-unit displacement of one retained run must change the raster. A CLI
  injection feeds this fault into the positive path and must fail the baseline.
- A changed revision key must be rejected before drawing.

Twelve oversized-word controls draw without fitting and must escape allocation.
The read-only `tools/Test-VT7Joined.ps1` independently validates all counts,
ownership intervals, transform/ink limits, negative records, partial damage and
bitmap headers. It does not infer correct Arabic typography from those counts.

For each size/DPI, a six-edit sequence changes text, marks, span width, bold,
font family and lam-alef boundaries, then restores the initial word. A fresh full
redraw is compared to an independent previous-frame incremental surface. Damage
unions old/new row allocations and ink, including conservative neighbor margins.
The incremental path seeds scratch from its own previous frame, clears damage,
redraws the row and commits only that rectangle. All 72 full-canvas RGB comparisons
and outside-damage checks must match; the final image must equal the initial
image. Failures save full/incremental BMPs. This is conservative software row
damage, not minimal per-glyph invalidation, GPU partial presentation or scrolling.

## Local evidence

Initial Debug execution passes all 120 reference/spacing/stale checks and 72
partial repaints, with 23 compressed spans, 24 explicit boundary reviews and
12 detected unfitted-overflow controls. The development OS is Windows NT
10.0.19044; these counts may differ with the target fonts.

Visual inspection at 18 DIP/96 DPI and 24 DIP/192 DPI shows the joined J lane
preserving connected words while S separates groups. Marked text and the tested
style/family combinations remain visible. The wide nonjoining word compresses,
and the long joined word leaves spare space within its allocation. The lam-alef
style split remains unresolved. At this initial local stage, Windows 7 execution
and visual review were still required; the supplied result is recorded below.

Final Debug and packaged Release renderer suites pass. Both report 52 required
checks, zero failures, 120 shared-transform references/spacing controls/stale
rejections, 23 compressed spans, 24 reviews, 12 detected unfitted overflows and
72 exact partial repaints. The injected displacement fails with
`Joined shared-transform reference differs`, as required. Missing/altered asset,
CLI/report and all earlier negative tests also pass.

The independent joined validator rejects six corrupted report copies covering
source ownership, vertical scaling, stale acceptance, hidden boundary reviews,
repaint mismatches and a missing final colored-surface guard. All 103 frozen
0.10 BMPs remain byte-identical, confirmed by a fresh run of its preserved
executable. All 115 packaged Release BMPs match Debug byte-for-byte.

Both configurations pass PE/import audits, host diagnostics/window-smoke tests,
and the unchanged Atlas D3D11/D2D hardware/WARP tests, with 19 frames per
combination. Those Atlas tests do not integrate the new joined-span path.
All 19 package manifest entries were independently rehashed. Local Markdown
links, changed-text punctuation and `git diff --check` pass.

Release stamp: `Sep 11 2026 22:31:08`, compiler `194435228`.
Archive: `artifacts/VT7-renderer-probe-0.11-x64.zip`, 11,005,903 bytes.
SHA256: `8988DDE2BCCFC982142DAA6165C3329A1FF83B771286438718C99D600B52E016`.
The 0.10 archive retains SHA256
`174BCB715810946A829DCD03252CD0A53C9EB73681B4AE587CC5CFDDF39176E2`.
No commit or push was made.

## Windows 7 handoff

The supplied `0.11-logs-and-bmp.zip` was assessed before starting 0.12. It
contains one log and all 115 BMPs, with no extra failure images. Archive SHA256:
`0255C8D452CFEF07835DF79EC89E1356262A3592AAD3032A2089E82ACB0F2CE4`.
The log SHA256 is
`FAFCBCC74FA105E682DE10D6EE9A191B4D72A2EFEFCC1E1DB8BA598DC4CB5CA4`.
Evidence is retained under `artifacts/vt7/evidence/joined-probe-win7-0255c8d4`.

The Release stamp matches the package above. Capture: 2026-09-11 20:51:32 UTC,
NT 6.1.7601, 51 required checks and zero failures. All six independent validators
pass. Joined results: 120 fixtures, 23 compressed spans, 24 explicit reviews,
120 raster references/spacing controls/stale rejections, 12 overflow controls,
72 exact partial repaints and no failures. All 103 earlier target BMPs match
the supplied 0.10 archive byte-for-byte. No separate ESU run is inferred.

Visual review confirms the tested J connections, visible marks and contained
wide spans; long-word centering leaves spare allocation. Cross-style lam-alef
remains unresolved. This accepts the bounded experiment, not production Arabic
typography or interaction. The subsequent comparison was
[0.12 cross-style lam-alef](2026-09-11-cross-style-ligature-probe.md).

Original handoff instructions:

Extract `artifacts/VT7-renderer-probe-0.11-x64.zip` into a fresh writable folder,
keep `fonts/`, and run `RUN-RENDERER-PROBE.cmd` without elevation. Return the log
and all 115 BMPs (103 earlier plus 12 joined-span comparisons), including failure
images if present. Inspect S versus J, the A/B neighbors, marks, font/style
boundaries, compressed wide text and the centered long word.

No new dependency, font asset, license, supported OS baseline, code-page setting,
or terminal UI change is introduced. MIT code and the existing OFL fonts remain
unchanged in licensing. Atlas integration, production segmentation, cache cost,
interactive bidi/cursor/selection and cross-style ligature policy remain open.
