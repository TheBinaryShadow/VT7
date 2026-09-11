# Milestone 2C: owned logical-order mapper candidate, probe 0.8

Planning update, 2026-09-12: reuse this candidate's applicable ownership/fallback
work for the minimum upstream-aligned font port. Its bounded tests are not full
Atlas acceptance. Enhanced Arabic and alternative fitting are deferred under
Milestone 7; see the [port-first plan](../architecture/2026-09-12-port-first-plan.md).
The dated evidence and original experiment boundaries below are retained.

Date: 2026-09-11. Branch: `initial-implementation-and-assessment`.
Source base: `42de4b631716e98ef5e231f170f167d671c97939` plus uncommitted 0.6-0.8 work.
The supplied Windows 7 0.8 structural run passes; see the target evidence below.
This is not an Atlas terminal build or final typography acceptance.

## Why this slice

The supplied [0.7 Windows 7 run](2026-09-11-repaint-probe.md) passes the isolated
differential repaint checks. The user then approved continuing with upstream's
fixed primary-font rows and overlapping ordinary glyph ink. The
[geometry contract v0.2](../architecture/2026-09-11-text-geometry-contract.md)
records that decision, its special clipping exceptions, and remaining gates.

The next unresolved boundary is the font mapper. Earlier experiments retain
DirectWrite's visual paragraph runs. Those are not a drop-in replacement for
Atlas's logical terminal columns. This slice implements a separate candidate
before changing AtlasEngine or the renderer controller.

## Implementation

`src/vt7/VT7.Renderer/Win7TextMapper.hpp/.cpp` owns its input source and core-cell
spans and returns owned glyph arrays, source/cell/glyph group mappings, and
retained, queried `IDWriteFontFace1` objects. It is compiled only into
`VT7.RendererProbe.exe` for now; the accepted Atlas backend library/proof and
GDI/native ABI remain unchanged.

1. Validate bounded input, complete contiguous source/cell spans, surrogate
   boundaries, and style ranges that cannot bisect a core cluster.
2. Obtain primary metrics from the explicitly selected installed regular face.
   Use upstream's default `0` advance, rounded total height, and rounded baseline.
   The interface takes DIP, then converts once to device pixels. Explicit custom
   cell-height settings are not implemented in this candidate.
3. Let baseline `IDWriteTextLayout` select system fallback faces and styles.
   Copy face-range metadata and retain COM faces. Destroy the layout/collector
   before subsequent shaping. Callback visual coordinates/order are not reused.
4. Analyze scripts with baseline `IDWriteTextAnalyzer`. Intersect script and
   face ranges in logical source order, rejecting unresolved core-cluster splits.
   Shape with `isRightToLeft=false`, as inherited Atlas does. Use no custom
   feature/axis configuration or number substitution in this initial candidate.
5. Merge shaping groups as needed to preserve full core clusters. Keep natural
   glyph size and offsets, and correct the final advance of each group to the
   core allocation, matching Atlas's complex-path advance correction. This is
   not the older diagnostic's whole-ink horizontal compression.

The mapper itself requests no Factory2, FontFallback or FontFace2+ interface.
That does not remove those requirements from the still-unported AtlasEngine.
Baseline font-face mapping through layout remains subject to target verification.

Private faces come from the existing hash-checked probe loader. The candidate
retains them without installation or new assets. System selection stays first.
Private substitution is restricted to regular, standalone symbol/pictograph
scalars occupying a complete source/core/font run, within the already approved
scalar ranges. Styled missing symbols, script/mark/ZWJ sequences, and cross-run
clusters are not silently replaced with an unstyled private face. The forced
private flag is diagnostic-only. Glyph zero remains explicit in run logs.

There is no layout cache. A snapshot carries buffer/revision/font generation,
row, columns, DPI and em-size keys. Consumers can reject stale keys, and the
caller must advance the font generation when the family/assets/settings change.
This is not concurrent invalidation, reflow, viewport scheduling, or a complete
production snapshot protocol. Map timing includes candidate construction and
is not a warmed-cache benchmark or performance acceptance.

## Test scope

Twelve size/DPI combinations cover 12/18/24 DIP at 96/120/144/192 simulated DPI.
Each runs 16 fixtures: Latin including combining accents and z with caron, CJK,
supplementary text, Arabic pure/mixed/marked, Indic, emoji sequence, bold/italic
split, Arabic real-style and redundant-style splits, stacked marks, two forced
private faces, mixed Hebrew, and an intentionally missing scalar.

Each case checks:

- Complete logical source, core-cell and glyph coverage, with group advances
  equal to primary-grid allocation. Natural outlines are not globally shrunk.
- Input text/cells surviving caller mutation/destruction and mapped faces/glyphs
  surviving mapper/layout destruction.
- Exact arrays/offsets and same-machine RGB equality against a fresh remap.
  Labels, the N lane, and earlier fixtures seed both canvases before drawing
  the current T lane independently. The entire canvas is compared afterward,
  including overhang. This is lifetime/determinism, not differential repaint.
- Seven stale-key variants per fixture, 1,344 total. An injected stale revision
  must fail the executable's overall baseline in the negative-test harness.
- Data-only raw-column/cluster-owner and logical-copy checks. They do not
  implement UI cursor, selection, accessibility, or proportional glyph hit tests.
- Eight input rejections: incomplete cells, cell gaps, a style splitting a core
  cluster, a split surrogate, an unpaired surrogate, invalid size, control text,
  and a missing primary family. These diagnostic failures are not the final
  shipping missing-font recovery policy.

`Test-VT7TextAdapter.ps1` independently accounts for configurations, fixture
identity, source/cell boundaries, group/glyph continuity and advances, forced
private nonmissing glyphs, RTL comparison presence, summaries and BMP headers.
It checks that declared core spans stay identical across size/DPI. Its input is
the report and bitmaps; it does not independently know installed font metrics
or decide Arabic typography from those structural checks.

## Visual comparison and open findings

The 12 new `*.adapter-<size>-<dpi>.bmp` images show N (natural visual system
layout) and T (logical terminal columns). The private glyphs are forced only in
their designated T rows. All 55 earlier reference/geometry/repaint images remain.

Local inspection at 18 DIP/96 DPI shows the intended logical-order difference
for Arabic/Hebrew; T is not a correctly reordered paragraph equivalent to N.
The real Arabic style split is visibly different, while a redundant equal-style
split must reproduce unsplit candidate glyphs/advances. These observations are
not accepted joining quality or complete complex-script support. No visual-bidi
mode has been enabled. Font/style context and consumer mapping remain gates.

Glyphs keep natural proportions. Oversized symbols can extend across their
allocated columns, unlike the older compressed lane. Horizontal fitting and
neighbor legibility remain unresolved integration work. Vertical overhang is
allowed under the selected ordinary-text policy, but box/DEC special clipping,
actual Atlas damage, rendering and physical DPI are not exercised here.

Other explicit candidate bounds: one nonempty line, at most 4,096 UTF-16 units,
48-768 DPI, 4-96 DIP, up to 32,767 columns, fixed `en-US` analysis, no custom
features/axes, no layout cache, and single-threaded ownership. The current
TerminalCore fixture helper still has its separate 200-unit diagnostic bound.
None of these bounds silently defines the final terminal's supported line size.

## Local validation and Windows 7 handoff

Both pinned Debug and Release builds pass. Both configurations report 52 required
checks, zero failures, 192 adapter fixtures, 1,020 mapped groups, 1,344 stale-key
rejections and eight invalid-input controls. Group counts may vary with target
fonts, so the independent validator derives them rather than hardcoding 1,020.
The unchanged geometry matrix reports 204 fixtures, 1,164 ink records and 24
vertical observations; repaint still reports 480 exact comparisons and 24
detected negatives. Both renderer/asset/CLI/injected-failure suites pass.

Both configurations also pass the unchanged Atlas hardware/WARP Direct3D11 and
Direct2D suites, 19 frames per combination, and host diagnostics/window smoke
tests. Both PE/import audits pass. Release build stamp: `Sep 11 2026 14:36:56`,
compiler `194435228`, on development runtime Windows NT 10.0.19044.

The assembled Release package also passes the full renderer/geometry/repaint/
adapter/asset-failure suite and its packaged PE/import audit. All 19 manifest
entries were independently rehashed. All 67 Debug and packaged Release bitmaps
are byte-identical on this machine. A separate execution of the frozen 0.7 EXE
confirms all 55 earlier bitmaps are byte-identical to their current 0.8 outputs.
The accepted 0.5, 0.6 and 0.7 archive hashes remain unchanged.

Extract `artifacts/VT7-renderer-probe-0.8-x64.zip` into a fresh writable folder,
retain `fonts/`, run `RUN-RENDERER-PROBE.cmd` without elevation, and return the
log plus all 67 bitmaps in a ZIP. No font installation, code-page/DPI change,
.NET, Power Automate, or new Windows update is required. Send available files
even on failure. Expect N/T RTL differences and explicit missing-glyph records;
report unexpected boxes, lost marks, overlap, and style-boundary artifacts.

Integration must not skip the
cache/context/style and horizontal-quality gates just because this mapper runs.

## Frozen package

Archive: `artifacts/VT7-renderer-probe-0.8-x64.zip` (8,329,135 bytes).

SHA256: `DB4263A4127A7D534F1DA3DA8AE2BBB78AD76FCCC1133C1C11471BBD3AF04F9E`.

The final manifest recheck covers all 19 entries. Changed-text punctuation,
90 local Markdown links, and `git diff --check` pass. No commit or push was made.

## Supplied Windows 7 evidence

Returned archive: `probe-0.8-bitmaps-and-log.zip`, SHA256
`60F9A8BE0EEDEBF114E68EB3CAEA51D84FFF28F8160C59EB4592F53895638D30`.
Log SHA256: `6FE97BAE020A493A5C24D4DB282DFFC0E1DA3ABFBE05F1780997F9271A8282A4`.
It records Windows NT 6.1.7601, the Release stamp above, compiler 194435228,
and capture UTC 2026-09-11 12:48:22. The log and 67 bitmaps are retained unchanged
in `artifacts/vt7/evidence/adapter-probe-win7-60f9a8be/`; derived PNG previews are
separate files. No separate ESU or minimum-prerequisite run is inferred.

- 51 required checks pass, zero failures. All three independent validators pass.
- 192 adapter cases, 1,020 glyph groups, 1,344 stale-key rejections and eight
  invalid-input controls pass. Baseline layout/analyzer and real FontFace1 work
  for the tested mappings without constructing AtlasEngine.
- Geometry retains 204 fixtures, 1,164 ink records and 24 vertical observations.
  Repaint retains 480 exact comparisons and 24 detected negative controls.
- All 55 earlier bitmaps are byte-identical to the supplied Windows 7 0.7 files.
- Automatic private U+1F600 fallback works in the Supplementary T lane, and both
  forced private samples are nonempty. System-only N can legitimately show tofu.

Visual inspection of the 18 DIP/96 DPI and 24 DIP/192 DPI comparisons confirms
remaining horizontal overflow: the uncomposed emoji sequence draws into B, and
the private yin-yang exceeds its one-cell allocation. At 18 DIP/96 DPI, the
sequence's ink extends to x=316 while B's cell starts at x=300. The private BMP
ink spans x=269..290 for an allocation x=270..280. These are not typography passes.
Arabic logical ordering differs from paragraph layout as planned, but joining
and spacing still require work. Stacked marks remain visible across row edges.

The user approved tackling horizontal fitting/protection next. The separate
[0.9 fitting candidate](2026-09-11-horizontal-fitting-probe.md) keeps the accepted
0.8 raw lane intact; it does not close the Arabic or Atlas integration gates.
