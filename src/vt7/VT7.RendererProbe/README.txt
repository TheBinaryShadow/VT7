VT7 renderer capability and font probe 0.13
================================

This is a Milestone 2 engineering probe, not an Atlas terminal build.
It does not replace or modify the accepted VT7 0.2.1 GDI proof.

Handoff update, 2026-09-13: the integrated Atlas viewport and its minimal Windows
7 font boundary are implemented. The application is at 0.3.5/ABI 8, with WARP
lifecycle resource growth unresolved. Native comparison 0.1 also grows on Windows
7 in both power and plain modes; this probe does not investigate that workload.
Its accepted 0.13 evidence remains a regression/research checkpoint. Optional
typography and interaction experiments stay in ROADMAP.md Milestone 7.
Start at doc/vt7/README.md and doc/vt7/HANDOFF.md in the source repository for
current evidence and the next bounded diagnostic design.

Requires Windows 7 SP1 x64 with the documented VT7 graphics/loader/UCRT
prerequisites, including Platform Update KB2670838. This native probe does
not require .NET or Power Automate. Pinned Visual C++ runtime DLLs are bundled.

Reproduction reference: no repeat of this unchanged accepted probe is requested.
Use the following only for a relevant regression or requested reproduction.
The issued archive and its original README/checksum remain unchanged.

1. Extract every file to a writable local folder.
2. Run RUN-RENDERER-PROBE.cmd, without elevation.
3. Open VT7-renderer-probe.log.bmp to inspect the font comparison.
4. Inspect the 12 additional VT7-renderer-probe.log.bmp.geometry-<size>-<dpi>.bmp
   images, plus the new repaint comparisons described below. Send the log and
   all generated bitmap files (151 on success), preferably together in a ZIP,
   including if the report says failure. If no images were produced, send the log.

The console is expected. The graphics windows are hidden, so no terminal
window will appear. A bitmap comparison is saved beside the log instead.
A run normally takes seconds, but the new matrix performs substantially more work.
If it hangs, report that separately; the log is written when the run finishes.

PASS/FAIL lines are required baseline checks. CAPABILITY lines are observations:
newer interfaces may return 0x80004002 (E_NOINTERFACE) on Windows 7 as expected.
That is not itself a failed baseline. Review the final "Baseline passed" line.

The probe checks:
- Baseline and optional DXGI, D3D11, DirectWrite, and font-face interfaces.
- Mixed-script text-layout callbacks and in-range cluster indices.
- The unchanged original 0.1 sample, now with retained UTF-16/scalar ranges,
  per-run glyph IDs/advances/offsets, cluster maps, locale/bidi/baseline,
  family/face/version, font file path/hash, and exact missing-glyph clusters.
- Thirteen font/cell fixtures using actual TerminalCore rows, with copied glyph-run
  data used after destroying the layout. Private fonts are bundled in fonts/;
  no fonts are installed into Windows or added to its system font collection.
- Structural mapping oracles and rejection of invalid cluster indices.
- Independent U+1F600 coverage scan of every face in DirectWrite's system
  collection, using HasCharacter and scalar-to-glyph lookup. Candidates include
  font identity and hashes. Errors are counted, never mistaken for no coverage.
- Direct rendering of a confirmed candidate, if found, without layout fallback.
- Pinned Unifont and Unifont Upper 17.0.05, loaded from the executable's fonts/
  directory and checked by SHA256 before DirectWrite reads them. Standalone
  missing symbols/pictographs in the cell lane may use these last-resort faces.
- Private-BMP and Private-SMP explicitly force private C-lane rendering to test
  both fonts even when the system already covers those characters. The N lane
  remains system-only. The BMP symbol is narrow because its core width is one
  cell; private font advances never change the terminal's cell allocation.
- Whole-ink horizontal fitting, including outlines/offsets, and raster bounds.
- Natural-size regular/italic regression checks. Natural runs may use a bounded
  2-pixel ink overhang at this probe's fixed 96 DPI. Their cell allocation does
  not grow. Oversized groups retain strict, zero-overhang whole-ink fitting.
- Pure/mixed/marked Arabic with original shaped RTL runs kept together, plus
  a bijective logical/visual cell projection. This is not glyph hit testing.
- Separate hardware and explicit WARP devices, with no silent substitution.
- An HWND discard/stretch swap chain, Direct2D glyph rasterization, nonempty
  pixel readback, and buffer resize on both devices.

It does NOT prove:
- AtlasEngine runtime compatibility, final glyph placement, or fallback parity.
- Correct pixels on the physical display. Hidden Present is an observation.
- Device recovery, render-thread correctness, long-term stability, or all GPUs.

Font/glyph counts depend on installed fonts. Missing glyphs are reported as an
observation, not hidden or mistaken for complete Unicode support. The current
font experiment uses system layout runs; it is not the final Atlas adapter.

In the bitmap, N is natural DirectWrite layout; C uses a 10-pixel cell allocation
and DirectWrite's visual run order. Original TerminalCore text/cells are unchanged.
LTR clusters are fitted separately; RTL runs stay joined and are fitted as units.
Horizontal compression is allowed, expansion is not.
Natural-size glyphs are preferred when advances fit and ink stays within the
declared 2-pixel overhang; only oversized groups are compressed. This replaces
0.3's strict per-cell squeezing. The log distinguishes cell and damage bounds.
Neither this cell projection
nor proportional RTL ink is a production cursor/selection contract. It is
not a claim of complete bidi or terminal shaping. Compare both rows and report
boxes, clipped/overlapping text, unexpected ordering, and missing characters.

The unchanged original sample and system coverage scan can still report missing
U+1F600: neither uses private fonts. On the tested Windows 7 machine, compare
the Supplementary N lane (system tofu) with its C lane (private fallback glyph).
The bottom explicit-system-candidate check can still be skipped legitimately.
Look for PRIVATE_FALLBACK records and the two forced private C-lane samples.

Fallback scope is deliberately limited to standalone symbol/pictograph scalars
in U+2190..U+2BFF and U+1F000..U+1FAFF, each occupying a complete core cluster/run.
RTL scripts, combining text, ZWJ sequences, and cross-run clusters are not
substituted with raw Unifont glyphs. No composed/color emoji guarantee is made.

All thirteen structural mapping fixtures and drawn horizontal bounds are required.
A mapping failure is reported as MAPPING_UNRESOLVED and fails this new baseline.
Zero unresolved mappings still
does not mean the pixels or shaping policy are accepted. Glyph zero records
identify an associated source cluster, not automatically the underlying cause.

The log includes installed font paths and hashes, not font files. Review paths
before sharing. Only fixed test text is captured, never terminal sessions.

Advanced CLI: VT7.RendererProbe.exe --output "path-to-report.log"
The --inject-required-failure and --inject-font-failure options are for harness testing only; do not use them
for normal acceptance. Reports are overwritten on rerun, so retain earlier runs
separately if useful. No system files, services, drivers, or settings are changed.

VT7 application code is MIT licensed. The bundled fonts use SIL OFL 1.1, not MIT.
See fonts/OFL-1.1.txt, fonts/COPYING, and fonts/README.md for their original
licensing and pinned provenance. Keep the complete fonts/ folder with the EXE.
Missing or wrong-hash fonts fail this diagnostic instead of silently substituting.
See LICENSE.txt, NOTICE.md, and licenses/ for the inherited
core and pinned WIL/GSL/fmt/Chromium provenance.
Microsoft Visual C++ runtime DLLs retain their Visual Studio redistribution
terms and are not relicensed under MIT. SHA256SUMS.txt covers package contents.

New in 0.6: geometry matrix
---------------------------
The original 0.5 comparison bitmap remains the frozen reference. Twelve separate
images cover 12/18/24 DIP text at simulated 96/120/144/192 DPI. There are 17
fixtures per image, 204 total, including the existing corpus, descenders,
stacked marks, explicit grid decorations, and italic/wide edge neighbors.

U is unclipped fitted ink over alternating cell backgrounds. V is a diagnostic
copy cropped to a one-row viewport. It intentionally shows what a strict clip
would lose, not a decision to discard those marks in the product. This crop is
implemented by a verified blit, not Atlas or DirectWrite target clipping.
Fixture names mentioning "forced C" refer to the original comparison naming;
both U and V show the forced private face in those two geometry fixtures.

Primary Consolas supplies the grid at every size: M advance rounded to the nearest
device pixel, ascent/descent/line gap rounded upward separately. Fallback never
changes those dimensions. Layout DIP values are converted to pixels once, with
a common primary baseline. All reported geometry is in device pixels afterward.
The two-pixel natural horizontal halo remains an explicit experiment; it is not
multiplied by DPI or accepted as a production constant. Oversized glyphs use a
bounded raster-preflight loop before drawing. Retry counts and scales are logged.

Look closely at stacked marks above A and below g, descenders, decorations,
private glyph proportions, and first/last-cell ink. GEOMETRY_INK vertical=REVIEW
records ink outside the primary row height. These observations inform the chosen
overlap policy; they do not count as structural failures or disappear
behind "Baseline passed". No general vertical shrinking is applied.

The matrix also verifies source/core spans, required private ink, crop pixels,
outside-crop sentinels, stale geometry-key rejection, and restored RGB pixels
against initial and fresh renders. This is not a production cache/lifetime test.
Offscreen DPI simulation does not test display settings, actual HWND resizing,
per-monitor transitions, or Atlas incremental redraw. Do not change Windows DPI
or log off to run this package.

New in 0.7: differential repaint
--------------------------------
Twelve size/DPI combinations each run 20 deterministic edits twice, 480
transitions total, on a five-row, 18-column diagnostic grid. Cases include
italic-to-space, narrow/wide replacement, combining marks, private fallback,
foreground/background/style changes, neighboring-row ink, and viewport edges.
This is a fixed scene of independently shaped core-backed clusters, not a live
TerminalCore edit/reflow session or a test of joining across separate clusters.

Each new state is freshly rendered as an oracle. The incremental path starts
from the previous frame, clears only damaged backgrounds, rerasterizes glyphs
whose ink intersects the damage, then commits only that rectangle. The damage
includes old/new allocation and ink, clipped only at the outer viewport. It is
not expanded to the full viewport and it never copies pixels from the oracle.
Scratch drawing plus bounded blit tests a software damage compositor, not
DirectWrite clip state or Atlas's own incremental presentation path.

Every transition requires exact RGB equality with the oracle and unchanged
pixels outside damage. Two complete edit cycles must restore the initial image.
All configurations must also detect deliberately omitted old-ink damage and
deliberately skipped neighboring glyphs. REPAINT_NEGATIVE records with nonzero
mismatch counts are EXPECTED and required. Positive REPAINT_STEP records must
have mismatch=0 and outside=0. Read the final REPAINT_SUMMARY and baseline status.

For each size/DPI, *.repaint-<size>-<dpi>.sample.full.bmp and
*.sample.incremental.bmp must look identical; *.sample.difference.bmp is black.
At 24 DIP/192 DPI, two extra negative-old and negative-neighbor triples show
deliberately broken results with red mismatch pixels. Red in those NEGATIVE
images is expected. Unexpected failures save additional *.failure-* triples.
The 42 repaint bitmaps supplement the existing 13 reference/geometry images.

The teal border is outside the terminal viewport and must remain untouched.
Stacked marks may cross interior row boundaries in this experiment; top/bottom
viewport ink is clipped deliberately. Overlapping text, narrow private symbols,
and physical DPI behavior are not declared production-ready by pixel equality.
The selected policy now follows upstream: fixed primary-font rows with ordinary
text overhang. Earlier probe metric rounding and images remain frozen evidence.

New in 0.8: logical-order mapper candidate
-----------------------------------------
Twelve additional *.adapter-<size>-<dpi>.bmp images compare:
- N: ordinary visual DirectWrite paragraph layout, system fonts only.
- T: the reusable Win7TextMapper candidate, original terminal column order.

T does NOT reverse or visually reorder terminal cells for Arabic/Hebrew. The
analyzer uses the same direction flags as upstream Atlas. N and T are therefore
expected to differ on those rows. Compare shapes, marks, style boundaries and
neighbors; do not interpret a successful mapping as complete script support.
Arabic joining across real style/font changes remains an explicit review item.
The equal-style split must reproduce the unsplit Arabic mapping.

The T lane uses upstream's primary '0' advance, rounded total line height and
rounded baseline, unlike the frozen 0.6/0.7 metric lane. Glyph proportions stay
natural; terminal groups receive upstream-like final-advance correction, not
the earlier probe's horizontal ink compression. Oversized glyphs may overlap
neighbors. This is a measured candidate, not final horizontal-fit acceptance.
Ordinary vertical overhang is allowed without dynamically enlarging rows.
Box/DEC special clipping is not exercised by this bitmap mapper.

The mapper uses baseline DirectWrite layout only to select faces, then destroys
the layout and shapes owned source with IDWriteTextAnalyzer. Mapped faces must
provide real FontFace1. No Factory2, FontFallback, or FontFace2+ is requested by
this candidate. The probe does not construct AtlasEngine; the integrated
viewport uses its separate Win7FontFallback boundary for the baseline platform.

All 192 fixtures check source/core/glyph coverage, cell advances, retained-data
lifetime, fresh-remap pixels and seven stale-key variants. Eight invalid-input
controls must be rejected. The log reports missing glyph counts explicitly.
T's forced private BMP/SMP samples use the same pinned assets. Automatic private
fallback remains bounded to regular standalone symbol runs; styled, multi-scalar
and cross-run cases are not silently substituted. Missing-primary and bad assets
fail this diagnostic; shipping fallback/recovery policy is still separate.

The candidate has no layout cache or concurrent renderer, supports a bounded
single-row input and fixed en-US analysis locale, and does not implement cursor,
selection, IME, accessibility or visual-bidi interaction. The grid hit/copy
checks are data-contract tests, not UI acceptance. Time samples include mapper
construction and are diagnostic observations, not a performance benchmark.

All 55 previous bitmaps are retained, plus 12 adapter comparisons, 67 total.
Send the log and all bitmaps in a ZIP. No Windows settings changes are needed.
The --inject-adapter-failure switch is only for the local negative-test harness.

New in 0.9: horizontal fitting and neighboring pixels
-----------------------------------------------------
Twelve new *.horizontal-<size>-<dpi>.bmp images compare R (raw mapper) with
F (fitted). The older 67 images, including the raw 0.8 adapter lane, remain.
Version 0.9 produced 79 bitmaps. Version 0.10 retains them and adds 24 Arabic images.

The fitting layer measures whole source/core/shaping groups using natural
advances and actual raster ink. Text, glyph IDs, cell ownership and row metrics
are unchanged. Natural groups retain scale 1 and offset 0. Their allowance is
ceil(cellWidth/5) pixels, two pixels at a ten-pixel cell. A half-pixel-per-column
advance tolerance accounts for primary-grid rounding. This allowance scales
with grid size and is an explicit candidate, not a final universal setting.

Oversized groups use only horizontal compression, starting with the full
available width and reducing it if actual raster bounds still spill. There is
no permanent inset, vertical shrink or ordinary row clipping. Nonempty ink must
remain visible. Compressed groups may not spill into neighboring columns.
Natural groups may retain legal overhang within their declared allowance; this
does not promise that all neighboring-cell pixels are protected from italics.

The test checks each group's pixel changes over full-height contrasting neighbor
sentinels, confirms measured/drawn bounds, and intentionally draws an oversized
private glyph without fitting. That negative control must escape. Latin and
italic raw/fitted pixels must match exactly. Seventy-two conservative partial-row
repaints must equal fresh full redraw and leave pixels outside damage unchanged.
These reuse a scratch surface and bounded blit, not Atlas partial presentation.

Inspect the emoji fixture's following B, narrow private yin-yang, private smiley,
italic edges, CJK/Indic neighbors and stacked accents. The uncomposed emoji
sequence is not promised to become a single composed/color emoji. The narrow
private symbol can still look compressed even with correct containment.
Arabic and Hebrew keep logical terminal order. Their typography/context is a
separate open issue and is not fixed by horizontal fitting.

No font assets, licenses, system settings or prerequisites changed. The new
fitter is still a bounded, uncached bitmap candidate outside AtlasEngine.
The --inject-fit-failure option is only for the local negative-test harness.

New in 0.10: Arabic context, ordering and spacing
-----------------------------------------------
Twenty-four *.arabic-<size>-<dpi>-<page>.bmp images cover twelve fixtures at
12/18/24 DIP and 96/120/144/192 offscreen DPI, with two pages per combination.
Keep every earlier bitmap too: 103 BMPs plus the log on success.

N: native DirectWrite paragraph layout, including any boundary limitations.
L: unchanged 0.8 mapper plus 0.9 fitting in logical terminal order.
C: contextual glyphs projected into logical core cells.
V: the same contextual glyphs projected into diagnostic visual-order cells.
P: repaired glyphs at natural proportional spacing, without cell-grid fitting.

C/V reuse the earlier directional diagnostic fitter with its two-pixel natural
halo. They are not the 0.9 fitter or a proposed final cursive-spacing policy.
P makes context changes visible without the spacing imposed by a terminal grid.
Neither V nor P is an enabled terminal rendering mode. Source text and core
cell widths remain untouched; cursor/selection/reflow behavior is not tested.

Fixtures include plain and marked Arabic, mixed Latin/digits, bold/italic and
Arial/Times New Roman boundaries, redundant same-style ranges, Consolas fallback,
lam-alef style splitting, ZWJ/ZWNJ controls, Arabic digits and a Latin control.
The old mapper has no per-range family input, so L is explicitly unavailable
for the forced family-boundary fixture instead of drawing a different request.

Whole-source context is shaped separately in each selected face/style. The
candidate retains only glyphs owned by the requested interval, with exact face
identity checks. A cluster shared across the boundary is left unchanged and
logged as ARABIC_REPAIR ... REVIEW. This is expected for the lam-alef split,
not permission to claim it fixed. No presentation-form characters are inserted.

Checks: 180 whole-word context comparisons, 60 deliberately isolated-word
controls, 144 exact immediate-versus-retained natural raster comparisons,
144 shifted-output controls, and complete logical/visual source/cell ownership.
Glyph IDs and repair counts depend on the actual fonts. Some fonts reuse a
glyph across positions, so the isolated word must differ, not every character.
--inject-arabic-failure deliberately loses context and must fail the baseline.

Look particularly at N versus P at style/family boundaries, and C versus V
versus P for plain/marked Arabic. Correct contextual forms do not guarantee
connected cursive text when groups are independently placed on fixed cells.
The supplied Windows 7 0.10 run passes its structural/context tests. Final
typography, ligature/style policy, caching and Atlas integration remain open.
No assets, licenses or system settings changed.

New in 0.11: joined spans inside a fixed terminal allocation
----------------------------------------------------------
Twelve *.joined-<size>-<dpi>.bmp images add 120 cases. There are now 115 BMPs
on success, plus the log. The earlier 103 images retain their original lanes.

S: contextual glyph groups fitted separately to visual-order cells.
J: the entire fixture-declared Arabic span shares one horizontal transform.
P: the same repaired word at natural proportional spacing, without neighbors.

The surrounding A/B remain in their original core columns. The word receives
the sum of its real TerminalCore cell widths, using the primary Consolas grid.
J preserves all relative run origins, natural advances, offsets and vertical
scale. It centers natural-width text without stretching it; oversized spans
are compressed horizontally as a unit, with actual raster containment checks.
Blank space within a generous allocation is intentional in this experiment.

Ten fixtures cover plain/marked Arabic, bold/italic/family/fallback boundaries,
lam-alef style splitting, joining controls, a wide nonjoining stress case and
a longer joined word. The spans are explicit fixture inputs, not a production
Unicode segmentation or mixed-paragraph bidi implementation. Source ownership
does not imply that every glyph visually aligns with its individual core cell.

Cross-style lam-alef retains the 0.10 policy: leave unsafe boundary runs as they
were and report REVIEW. Do not cut a shared ligature, drop a style, or rewrite
source. Natural Arabic ordering inside J is diagnostic; no terminal mode changes.

Tests check 120 shared-transform raster references, 120 displaced-run controls,
120 stale-snapshot rejections, full source/core ownership, and pixel protection
outside the allocation on both scratch and colored comparison surfaces. Twelve
unfitted wide-span controls must spill. Seventy-two partial row repaints must
match fresh full redraws, preserve outside-damage pixels and restore the initial
frame after text/mark/style/family/width changes. These are software tests, not
Atlas/GPU invalidation, scrolling, selection or concurrent-cache acceptance.

Compare S with J, especially Plain, Marks, style/family boundaries and Long-joined.
Watch the A/B neighbors and the compressed Wide-nonjoining sample. Lam-alef is
still explicitly unresolved. Return every bitmap and the log, including failure
images. --inject-joined-failure is a deliberate local-harness spacing failure.
The supplied Windows 7 0.11 matrix passes. No new dependencies or font installation.

New in 0.12: cross-style lam-alef policy comparison
-------------------------------------------------
Return the log and all 139 BMPs. Twenty-four new *.ligature-<size>-<dpi>-<page>.bmp
images compare eight standalone pairs at the same twelve sizes/offscreen DPIs.
The earlier 115 images are preserved. The supplied Windows 7 0.12 matrix passes.

N: original mixed-style layout, fitted as one pair.
L: whole pair in the physical face/style selected for lam.
A: whole pair in the physical face/style selected for alef.
X: left spatial region from A, right from L. Different-outline cases are REVIEW.
C: one unchanged L outline, yellow left region and cyan right region.

L/A are references, not permission to discard one character's style. X is a
diagnostic hybrid, not authentic per-character outline ownership. The seam is
the middle of the combined two-column allocation, not a font-provided caret.
C isolates paint-only changes; it does not honor mixed outline styles.

Compare bold, reversed bold, italic, family, fallback, hamza and madda cases.
Inspect X for kinks or mismatched strokes. A contained image is not necessarily
correct typography. Fallback faces may not report a shared lam-alef cluster;
the log records this instead of assuming every selected face behaves like Arial.

Checks cover 96 fixtures, exact selected faces, original source/core allocation,
whole-source shaping, 384 pixel references on uniform/alternating backgrounds,
192 dropped-color controls, 96 stale rejections and all five panel lane guards.
--inject-ligature-failure deliberately drops a paint color and must fail.
No new hybrid incremental-edit or cursor/selection tests are claimed.
No font installation, source substitution, dependency or licensing change.

New in 0.13: marks, joining context and same-outline paint
--------------------------------------------------------
Return the log and all 151 BMPs. Twelve new *.paint-<size>-<dpi>.bmp pages
extend the same-outline color approach; all 139 earlier images remain.
The different-outline X hybrid is not adopted as a default.

U: the complete retained outline in uniform white.
C: alternating cyan/yellow by logical core cluster, in diagnostic RTL cell regions.
S: source query [1,2) expanded to its core cluster, highlighted and painted white.

Six fixtures cover marked lam-alef, surrounding beh letters, a marked word,
stacked marks, a longer joined word and Consolas fallback. The whole word is
shaped before paint decisions. Marks remain in the copied base cluster, but a
visual mark can cross a spatial paint boundary. Please report confusing color
or selection behavior even if the checks pass. Blank allocated space is possible.

Checks include 432 pixel references, 144 exact uniform recombinations, 144
dropped-color controls, source/cell partitions and logical substring oracles,
72 stale rejections and 288 exact partial color/selection repaints. Injecting
--inject-paint-failure swaps colors and must fail. No clipboard is accessed.
This is not interactive cursor/selection, mixed bidi, reflow or Atlas acceptance.
The supplied Windows 7 0.13 run passes all eight validators: 51 required checks,
zero failures, and all 139 earlier target BMPs unchanged. Marks and connections
remain visible in the inspected samples. The long-word selection stripe still
does not neatly identify the intended letter within centered glyph geometry.
Visible-position/source/core interaction mapping is deferred under Milestone 7,
POL02, not the next test or completed caret/selection support. Baseline grid-based
interaction remains required. No assets or system settings change.

This source README includes the later Windows 7 assessment. The frozen 0.13
archive retains its original handoff README and published checksum.
