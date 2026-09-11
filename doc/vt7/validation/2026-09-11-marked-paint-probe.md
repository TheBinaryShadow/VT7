# Probe 0.13: marked Arabic paint and source selection

Planning update, 2026-09-12: preserve this successful bounded experiment and its
visible highlight discrepancy under Milestone 7/POL02-POL03. The proposed enhanced
interaction follow-up is deferred, not the next implementation task. Baseline
Atlas keeps inherited grid behavior; ordinary selection/copy correctness is still
required. See the [port-first plan](../architecture/2026-09-12-port-first-plan.md).
No results, source, frozen packages or acceptance claims change with this note.

Date: 2026-09-11. Milestone 2C / F01-F02. Supplied Windows 7 matrix passes.
Branch: `initial-implementation-and-assessment`.

## Accepted direction and scope

The user reviewed [0.12](2026-09-11-cross-style-ligature-probe.md) and agreed to
carry forward same-outline painting, not adopt the different-outline spatial
hybrid as a default. Its older comparison remains frozen evidence. No font or
weight override is silently selected for a boundary-spanning ligature.

`VT7.RendererProbe/PaintProbe.inl` extends the paint experiment, still outside
the mapper and Atlas. Six fixtures cover marked lam-alef, beh letters before
and after lam-alef, marked salaam, stacked shadda/fatha with joining context,
a longer beh word with spare allocation, and marked fallback text requested
through Consolas. The complete fixture is shaped once without paint effects
or outline-style splits, then retained and fitted using the unchanged 0.11 path.
No source substitutions, per-letter glyph cuts or new font assets are introduced.

This is a uniformly RTL, fixture-declared word experiment, not a general bidi
paragraph or Unicode segmenter. All retained runs must be RTL. The word uses
the combined real TerminalCore allocation and primary Consolas metrics. The
retained outline, offsets, advances, baseline and shared fit are reused for
every paint state, with vertical scale one. Natural-width centering remains
a candidate; no production width or alignment policy changes.

## Source, cells and paint regions

Real core clusters determine source intervals. Their logical columns are
projected into reversed visual columns for this diagnostic word. These regions
partition the entire allocation exactly once, but are not anatomical ownership
boundaries within a ligature or combining glyph. A mark may visually cross a
region and receive different colors on its two sides. Retaining the entire
outline prevents geometry loss; it does not settle semantic paint ownership.

The source query is always UTF-16 `[1,2)`. It is expanded to its owning core
cluster. Hard-coded fixture oracles require a base plus all its marks when
the query lands on a mark, including the stacked sequence. Every UTF-16 source
unit round-trips to its owning interval, and an out-of-range query is rejected.
The copied substring must equal the expected original logical substring.
No system clipboard is accessed. A core cluster is not necessarily an entire
font ligature: selecting lam can copy lam without also copying alef.

The three lanes are:

- U: whole outline in uniform white, with cell background guides.
- C: cyan/yellow alternating by logical core cluster, painted in projected
  cell regions without reshaping the text.
- S: the same colored outline with the snapped core-cluster region highlighted
  and painted white. Selection is a spatial-policy comparison, not acceptance
  of interactive selection, font-provided caret stops or terminal bidi.

Each color pass draws the entire retained shape against the destination
background in staging memory, then copies only its disjoint full-height strips.
There is no ordinary row-height clip, vertical shrink or GDI clipping assumption.
The copied strips remain inside the word allocation. Protection outside it does
not protect neighbor ink that already overhangs inside the word allocation.

## Test matrix

Six fixtures at 12/18/24 DIP and 96/120/144/192 offscreen DPI give 72 cases.
Twelve `.paint-<size>-<dpi>.bmp` pages bring the successful output to 151 BMPs.
The earlier 139 images retain their original code paths and comparison lanes.

- Source/core partitions, expected mark/base selection and logical substring
  checks in every case; invalid queries and stale snapshots must be rejected.
- 432 RGB comparisons: U/C/S on both uniform and alternating backgrounds.
  The oracle renders three complete single-color references, independently
  chooses pixels using the original core columns and checks the full canvas.
  This tests compositing, not an independent font engine.
- 144 exact uniform recombinations and 144 controls requiring colored output
  to differ from a one-color shortcut. Paint regions with no ink are allowed,
  for example where centered short text leaves spare allocated columns.
- 72 stale revision rejections before any pixels change. Retained geometry
  remains immutable throughout paint-state transitions; no cache is implemented.
- 288 partial color/selection repaints, cycling U-C-S-C-U. Each incremental
  surface starts from its own previous frame, clears conservative row/ink
  damage, repaints and commits only that rectangle. Full-canvas RGB must equal
  a fresh draw, pixels outside damage stay unchanged, and the cycle returns
  exactly to its original frame. This does not cover changed text/metrics,
  scrolling, reflow, concurrent caches or Atlas/GPU presentation.
- All final comparison lanes preserve pixels outside the horizontal allocation
  with literal A/B neighbors present.
- `--inject-paint-failure` swaps cyan/yellow in the actual positive draw path
  and must fail `Paint raster reference differs`. Older injected faults keep
  their previous matrix scope rather than rerunning the unrelated new matrix.

`tools/Test-VT7Paint.ps1` independently validates case accounting, source and
visual partitions, selection oracles, reported checks and fresh bitmap headers.
Its structural pass is not Arabic typography or interactive acceptance.

## Local validation and frozen package

Initial local Debug evidence: 72 fixtures, 432 source-unit round trips,
432 raster references, 144 exact uniform recombinations, 144 dropped-color
controls, 72 stale checks and 288 exact partial repaints pass. The actual
swapped-color injection fails as required. All 139 earlier local BMPs remain
byte-identical to the preserved 0.12 Release results.

Visual inspection at 24 DIP/192 DPI shows retained marks and joining geometry
across the three paint states. The long-word sample exposes the alignment
tradeoff: a highlighted allocated column need not neatly match the intended
letter inside centered proportional geometry. This is evidence for the next
interaction-policy experiment, not a reason to call selection complete.

Debug and packaged Release pass the complete renderer suite, including the new paint
injection, all earlier negative/CLI/report controls and missing/altered font
tests. Both baselines report 52 required checks and zero failures on local
NT 10.0.19044. All 151 packaged Release images match Debug byte-for-byte.
The read-only paint validator rejects seven corrupted reports: source holes,
split-mark selection, vertical scaling, stale acceptance, absent color controls,
lost repaint-cycle identity and hidden spatial-policy review.

Both configurations pass import/PE audits, unchanged host diagnostics/window
smoke checks, and all four Atlas combinations (D3D11/D2D, hardware/WARP), each
with 19-frame checks. Those checks do not integrate the new painting path.
All 19 package manifest entries were independently rehashed. The 109 checked
local documentation links, punctuation checks and `git diff --check` pass.

Release stamp: `Sep 11 2026 23:38:42`, compiler `194435228`.
Archive: `artifacts/VT7-renderer-probe-0.13-x64.zip`, 11,440,239 bytes.
SHA256: `C73263D43E9866F51F513F19FA832D1E06D6B61EA89178DC96F311196AB3E421`.
The 0.12 package retains SHA256
`99AE0C22492D1D82695A2600EE9EED75228A36610304CA377B0DAA254BC6037F`.
These are local results, separate from the supplied Windows 7 evidence below.
No commit or push was made.

## Supplied Windows 7 evidence

The supplied `0.13-logs-and-bmp.zip` contains one log and all 151 expected BMPs,
with no extra failure images: 152 entries, 6,046,135 compressed bytes and
946,491,074 uncompressed bytes. Archive SHA256:
`814E9DEA7E565BC5BDBEAB54CAB52466EA9BABC27BE09E2A4851A238B4BD809E`.
Log SHA256:
`C0898EC13EC42788F665348E70CD67CEDFEC5C14A03D729A6CF1D7067E33C22A`.
Evidence is retained under `artifacts/vt7/evidence/paint-probe-win7-814e9dea`.

The log identifies NT 6.1.7601, Release x64, the matching package build stamp
`Sep 11 2026 23:38:42`, and compiler `194435228`. Capture time is
2026-09-11 21:50:17 UTC. It reports 51 required checks, zero failures and a
passed baseline. All eight read-only validators pass against the supplied log
and images; this assessment did not substitute a run on the development OS.

The new paint matrix passes all 72 fixtures, 432 source-unit round trips,
432 raster references, 144 uniform recombinations, 144 dropped-color controls,
72 stale checks and 288 exact partial repaints. Expected source-selection
oracles keep base characters with their combining marks, including the stacked
sequence. All 139 earlier target BMPs match the supplied 0.12 results
byte-for-byte. The previous ligature matrix still reports 192 shared-cluster
variants and 84 explicit outline-policy reviews; those are not new failures.

Inspection of representative 18 DIP/96 DPI and 24 DIP/192 DPI pages shows
retained marks and joining geometry across U/C/S, including fallback and
surrounding joining letters. The long-word image reproduces the known visual
selection mismatch: a core-column stripe can miss the intended letter inside
centered proportional geometry. Paint boundaries can also cross marks or
shared ligatures. These remain explicit quality/interaction review points.

This validates the bounded paint and source-ownership experiment on the
supplied Windows 7 setup, not complete Arabic typography, cursor navigation,
interactive selection, mixed bidi, actual display-DPI transitions or Atlas
integration. No separate ESU run is inferred from this archive.

## Reproduction and deferred interaction follow-up

Extract `artifacts/VT7-renderer-probe-0.13-x64.zip` into a fresh writable folder,
keep `fonts/` intact, and run `RUN-RENDERER-PROBE.cmd` normally. Return the log
and all 151 BMPs, including partial output if a check fails.

Inspect marks and connections across U/C/S, the highlighted base-plus-mark
region, long-word spare space and fallback. Report confusing mark colors or
selection boundaries even if every mechanical check passes. Cursor navigation,
hit testing, mixed-direction text and production selection policy are still
open. Different-outline hybrids remain excluded from the recommended default.
If selected during Milestone 7 triage or later, the POL02 interaction experiment should:

- Map visible glyph/cluster positions back to source intervals and authoritative
  core cells without changing terminal widths or source text.
- Compare caret and selection placement against the existing cell-strip
  reference, keeping base/mark source ownership intact and shared-ligature
  boundaries explicit.
- Test clicks in spare allocated space, both edges of a span, and selections
  crossing combining marks or ligatures. Report ambiguity instead of inventing
  character-owned outline boundaries.

These are deferred experiments, not baseline integration gates, implemented behavior or an
approved change to terminal bidi, centering, caret stops or selection policy.
The frozen 0.13 archive and its packaged handoff README remain unchanged;
this source-tree record contains the subsequent target assessment.

No new dependencies, licenses, system settings, font installations or terminal
UI changes. MIT application code and existing OFL assets remain unchanged.
