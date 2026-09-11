# Probe 0.12: cross-style lam-alef policy comparison

Planning update, 2026-09-12: this comparison is retained under Milestone 7/POL03.
Same-outline paint remains a research candidate and different-outline hybrids
remain unaccepted, not baseline port requirements. The
[port-first plan](../architecture/2026-09-12-port-first-plan.md) supersedes
historical next-task wording below without changing results or package evidence.

Date: 2026-09-11. Milestone 2C / F01-F02. Supplied Windows 7 matrix passes.
Branch: `initial-implementation-and-assessment`. No production policy change.

## Why a separate experiment

The supplied [0.11 Windows 7 results](2026-09-11-joined-span-probe.md) pass
shared-span fitting, but cross-style lam-alef remains unresolved. A shaping
cluster can span both source characters while the requested weight, slant or
family changes between them. Slicing its glyph array does not recover a
character-owned outline.

Microsoft documents a glyph run as having one face, and a physical face as
having a particular weight, slant and stretch. Its rendering API separately
accepts a text color. This supports investigating outline changes separately
from paint-only changes, but does not specify VT7's terminal policy. Sources:
[Glyphs and Glyph Runs](https://learn.microsoft.com/en-us/windows/win32/directwrite/glyphs-and-glyph-runs)
and [Text Rendering with Direct2D and DirectWrite](https://learn.microsoft.com/en-us/windows/win32/direct2d/direct2d-and-directwrite).

`VT7.RendererProbe/LigatureProbe.inl` compares possible consequences. It does
not modify ArabicRepair, JoinedProbe, Mapper, Atlas, source text or terminal
interaction. The earlier 115 images remain regression references.

## Fixture and geometry boundary

Eight two-scalar fixtures cover paint-only, alef bold, lam bold, alef italic,
Arial/Times New Roman, Consolas fallback bold, and bold alef with hamza or madda.
These are explicit standalone pairs, not a general joining segmenter. Combining
marks, preceding joining letters, arbitrary style ranges and mixed paragraphs
are not included in this new matrix.

The original styled DirectWrite layout selects the physical faces. The entire
unchanged pair is then shaped independently in each selected face, retaining
glyphs, advances, offsets and face ownership after layout destruction. Physical
face equality is checked through file-loader identity/reference keys, face index
and simulations. No Arabic presentation-form characters, font table patches or
forced zero-width joiners are used.

Explicit-font pairs must expose a shared shaping cluster. Fallback cluster
behavior is recorded, not presumed: locally both fallback variants expose two
clusters. Those remain whole-source shape comparisons, not shared-cluster
successes. The two uniform references are not substitutes for the mixed-style
request. In particular, neither is an approved first-character-wins policy.

Real TerminalCore must return four one-column source cells for A + pair + B.
Consolas provides the primary grid and baseline. Both whole-source variants use
one common horizontal scale at most one, with individual centering translations;
vertical scale remains one. Natural ink/advances determine fit, followed by
bounded raster containment checks. The two complete outlines need not agree
where a paint boundary crosses them.

## Five comparison lanes

- N: original mixed-style layout, fitted as a whole to the two-column allocation.
- L: the whole pair shaped in the physical face/style selected for lam.
- A: the whole pair shaped in the physical face/style selected for alef.
- X: spatial hybrid, left region from A and right region from L. REVIEW for
  different faces. This is not a claim of authentic per-character font styling.
- C: the L geometry painted yellow on the left and cyan on the right. Both
  regions use the exact same retained outline and transform. This isolates
  paint-only behavior; it deliberately does not honor the different outline
  request in the non-paint-only fixtures.

The seam is the boundary between the two allocated columns, with the diagnostic
RTL lam region on the right. It is not an anatomical division of the letters,
a ligature caret supplied by the font, or a selected terminal bidi policy.
Each complete raster is drawn against the current destination background on a
staging target. Disjoint full-height strips are then copied into the output.
There is no ordinary row-height clip or assumption that the DirectWrite bitmap
renderer honors a GDI clipping region. Outside-allocation protection does not
protect neighboring overhang already intruding inside the pair's allocation.

## Tests and acceptance boundaries

The 12 size/DPI configurations remain 12/18/24 DIP at 96/120/144/192 offscreen DPI.
Two pages per configuration add 24 images, for 139 total BMPs on success.

- 96 fixture ownership/physical-face checks, with shared clusters counted from
  actual font results rather than hard-coded glyph numbers.
- 384 full-canvas RGB comparisons against independent per-pixel selection of
  the two complete reference rasters, on uniform and alternating backgrounds.
- Both spatial regions must contain visible pixels. All changed pixels must
  remain inside the two-column allocation. All five final panel lanes repeat
  the outside-allocation guard with A/B neighbors present.
- Same-face white recombination must equal each intact reference exactly.
- 192 paint-only controls reject substituting either whole one-color raster.
- 96 stale revision checks reject before any pixels change.
- `--inject-ligature-failure` actually replaces the alef paint color with the
  lam color in the positive draw path and must fail the baseline comparison.

`tools/Test-VT7Ligature.ps1` independently checks matrix accounting, source
scalars, cluster/face observations, fit bounds, explicit policy reviews and
fresh bitmap dimensions/headers. It validates evidence structure, not Arabic
typography. The raster oracle tests compositing, not an independent font engine.
New hybrid partial-edit/reflow/scroll/cursor tests are not implemented. Older
repaint suites still run, but do not certify the new hybrid path or Atlas.

## Initial local observations

The initial Debug matrix passes: 96 fixtures, 168 shared-cluster variants,
384 raster references, 192 dropped-color controls, 96 stale checks and 84
explicit different-outline reviews. The 24 remaining whole-source variants
are the fallback cases without a shared cluster. All 115 earlier BMPs match
the previous local 0.11 Release results byte-for-byte.

Visual inspection at 24 DIP/192 DPI shows intact L/A lam-alef forms and a
continuous two-color C outline. The italic and family X hybrids expose seams
or outline discontinuities. A contained composite is not a typographically
correct cross-style ligature. Do not adopt this hybrid as production behavior
on the strength of passing structural tests.

Recommended decision sequence: obtain the target Windows 7 comparison, then
separate the promising same-outline paint path from the unresolved different-
outline policy. Choosing a cluster-wide font, preserving the native split, or
adopting another shaping approach requires an explicit documented tradeoff.
Cursor/selection mapping and surrounding joining context remain open.

## Windows 7 handoff

The supplied `0.12-logs-and-bmp.zip` contains one log and all 139 BMPs.
Archive SHA256: `ED7AF32A453AF148F36AEDC5D533577B291537CF6756432AA32837921C513001`.
Log SHA256: `47D4BB5B0636D3B6F53FA91C8F1279591FE8179E19ABDA2AF220C16C43AC1111`.
Evidence: `artifacts/vt7/evidence/ligature-probe-win7-ed7af32a`.
Capture: 2026-09-11 21:22:31 UTC, NT 6.1.7601, matching Release stamp below.
All seven validators pass; 51 required checks, zero failures. All 115 previous
target BMPs are byte-identical. The new matrix passes 384 raster references,
192 paint controls and 96 stale checks, with 84 explicit outline reviews.

This target reports 192 shared-cluster variants, versus 168 locally. All 24
fallback variants now expose a shared cluster; this is a font-stack observation,
not a general Windows 7 guarantee. Visual inspection at 18/96 and 24/192 shows
intact same-outline colors and mixed-outline seam concerns, especially italic
and family changes. No independent ESU run is inferred from this archive.

After reviewing the images, the user approved carrying forward same-outline
painting while rejecting the mixed-outline hybrid as the recommended default.
This does not authorize a cluster-wide font override. The subsequent isolated step was
[0.13 marked paint/source selection](2026-09-11-marked-paint-probe.md).

Original local package evidence and handoff:

Debug and packaged Release pass the complete renderer suite, including actual dropped-
color injection, all earlier negative/CLI/report controls and missing/altered
font checks. Both Debug and Release baselines report 52 required checks and zero
failures on development NT 10.0.19044. All 139 packaged Release BMPs are byte-
identical to Debug. The independent validator also rejects seven corrupted
reports covering source scalars, vertical scale, stale acceptance, hidden
reviews, absent paint controls, missing panel guards and lost shared clusters.

Both configurations pass PE/import audits and unchanged host diagnostics/window
smoke tests. All four Atlas backend combinations (D3D11/D2D, hardware/WARP) pass
19-frame checks in both configurations. Those tests do not integrate lam-alef.
All 19 package manifest entries were independently rehashed.
The 105 checked local documentation links, project punctuation gate and
`git diff --check` also pass. No commit or push was made.

Release stamp: `Sep 11 2026 23:14:24`, compiler `194435228`.
Archive: `artifacts/VT7-renderer-probe-0.12-x64.zip`, 10,916,138 bytes.
SHA256: `99AE0C22492D1D82695A2600EE9EED75228A36610304CA377B0DAA254BC6037F`.
The frozen 0.11 package remains unchanged. This is local evidence, not a supplied
Windows 7 result for 0.12.

Extract `artifacts/VT7-renderer-probe-0.12-x64.zip` into a fresh writable folder,
keep the supplied `fonts/` directory, and run `RUN-RENDERER-PROBE.cmd` normally.
Return the log and all 139 BMPs. Compare N/L/A/X/C in
`.ligature-<size>-<dpi>-<page>.bmp`, particularly bold, italic, family and fallback.
The expected REVIEW records are policy observations, not baseline failures.

No new font, dependency, system setting or license change. Application code
remains MIT; bundled OFL assets are unchanged. No commit or push is requested.
