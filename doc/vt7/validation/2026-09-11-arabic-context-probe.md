# Probe 0.10: Arabic context, ordering and cursive spacing

Date: 2026-09-11. Milestone 2C / F01-F02. Supplied Windows 7 structural/context
validation passes. Final Arabic typography and integration remain open.

## Scope and findings

The 0.8 mapper uses layout for face selection, then independently shapes each
face/script slice with logical-order analyzer settings. The 0.9 fitter fixes
oversized-group containment, not Arabic context or cursive spacing. Both remain
unchanged in this experiment, as do TerminalCore, AtlasEngine and the host.

This probe first tests retained native layout, then a bounded contextual repair.
Local native layout callbacks lose whole-word forms at bold/italic/family splits
in the repeated-beh fixtures. Retaining callbacks alone is therefore insufficient
for these tests. This is an observed local result, not a claim about every
DirectWrite version or font combination.

Repair shapes the full original source separately in each selected system
face/style. It extracts only the glyphs owned by that run's source interval,
retaining advances, offsets, cluster associations and COM font ownership. The
font file loader/key, face index and simulations must match. No copied callback
pointers or layout objects survive. No ZWJ or presentation-form characters are
inserted, and the input/core cells are never rewritten.

When a contextual cluster crosses a boundary, or the reference cannot provide
the same face for the complete interval, the repair leaves the original run
unchanged and logs REVIEW. The lam-alef style split exercises this limit. The
probe must not cut a shared ligature, merge away a requested style or invent
terminal cells to obtain a passing result. This is still a system-font-only,
uncached diagnostic implementation, not the production adapter.

## Five independent views

| Lane | Meaning | What it does not establish |
| --- | --- | --- |
| N | Original native DirectWrite paragraph | Cross-boundary context correctness |
| L | Unchanged logical mapper plus 0.9 fitter | Cursive joining or visual bidi |
| C | Contextual glyphs placed in logical core cells | Connected cursive spacing |
| V | Same glyphs in a diagnostic visual cell projection | Production bidi/cursor policy |
| P | Contextual glyphs with natural proportional placement | Terminal grid placement/hit testing |

N and P retain natural vertical geometry. C/V use the existing directional
diagnostic fitting helper with its fixed two-pixel natural halo, not the 0.9
fitter. Every group is fitted independently, which can visibly separate cursive
letters even when their glyph identities are contextual. P removes that grid
spacing variable to expose the context change. It places repaired runs using
their natural advances in the original layout's physical run order. It does
not reuse old layout x positions with changed advances. Neither P nor V is a
new user-facing mode or an accepted renderer design.

The family-boundary fixture labels L unavailable because the current mapper
cannot express per-range font families. Drawing a different request there
would give a misleading comparison. Core source and widths remain authoritative
in C/V; the visual projection is separately bijective and does not change them.

## Matrix and oracles

Twelve fixtures at 12/18/24 DIP and 96/120/144/192 offscreen DPI produce 144
cases and 24 Arabic comparison BMPs, two pages per configuration. The corpus
includes plain/marked Arabic, mixed Latin/digits, bold and italic boundaries,
Arial/Times New Roman boundaries, redundant same-style ranges, Consolas
fallback, lam-alef splitting, ZWJ/ZWNJ, Arabic digits and Latin combining text.

- Five repeated-beh fixtures compare all three source positions to whole-word
  shaping in the same face/style: 180 glyph-identity and face checks.
- Each fixture also shapes the letters independently. The resulting word must
  differ: 60 isolated-word negative controls. Not every individual glyph must
  change. The local Arial 7.00 GSUB tables reuse the base beh for final shaping
  and the initial-form glyph for medial shaping; nominal presentation-form
  cmap IDs are therefore not a valid universal shaping oracle. No font tables
  or font assets are copied into the project.
- 144 fresh layouts draw directly into a bitmap through a separate immediate
  renderer. Full RGB output must match replay from copied callback data after
  the original layout/collector are destroyed. Moving a retained run seven
  pixels must break that comparison in each case. Failures save both images.
- Core/shaping groups must cover every source unit, glyph and core cell exactly
  once. Logical placement retains cell positions. Visual placement changes
  only diagnostic display positions, with round-trip/coverage checks.
- `--inject-arabic-failure` substitutes isolated output for a contextual result
  and must fail the baseline. The test harness checks its error and exit status.

`tools/Test-VT7Arabic.ps1` independently validates the report's counts, identity,
source/cell/group coverage, negative-control records, repairs/reviews and all
24 bitmap headers. It does not claim to reconstruct the live DirectWrite
reference from screenshots. The direct/retained comparison tests ownership,
not whether DirectWrite itself implements every Arabic rule correctly.

## Local validation

Initial Debug execution passes 144 cases, 180 context comparisons, 60 isolated
word controls and 144 natural replay/shift controls. It records 108 repaired
runs and 24 explicit lam-alef boundary reviews. These counts are font-dependent,
not constants required from Windows 7.

Local images show why context alone cannot close F01/F02: logical order and
independent group fitting still produce separated Arabic text. Whole-word
context repair must not be advertised as finished Arabic support. Follow-up
work must settle cursive-group spacing, ligatures crossing styles and the
terminal interaction contract before cache work or Atlas adoption.

The final Debug and packaged Release suites pass, including deliberate context
loss, missing/altered private font assets, existing geometry/adapter/fitting/
repaint checks, invalid CLI arguments and report failures. Both baseline runs
report 52 required checks, zero failures on Windows NT 10.0.19044. All 1,320
logged C/V group projections validate. Four separately corrupted report copies
(context marker, source interval, summary and missing P reference) are rejected
by the independent Arabic validator.

All 79 frozen 0.9 images are byte-identical in 0.10, confirmed by a fresh run
of the preserved 0.9 executable. All 103 packaged Release BMPs match Debug
byte-for-byte. Visual inspection at 18 DIP/96 DPI and 24 DIP/192 DPI includes
N/P style and font boundaries: the repaired proportional P lane makes the
context improvement visible, while C/V still expose cell-spacing limitations.
This does not replace Windows 7 execution or expert Arabic typography review.

Debug/Release import audits and host diagnostics/window-smoke tests pass.
Atlas D3D11 and D2D, each on hardware and WARP, pass 19 frames per combination
in both configurations. These unchanged Atlas tests do not integrate the new
Arabic path. All 19 package manifest entries were independently rehashed.

Release stamp: `Sep 11 2026 22:08:46`, compiler `194435228`.
Archive: `artifacts/VT7-renderer-probe-0.10-x64.zip`, 8,375,931 bytes.
SHA256: `174BCB715810946A829DCD03252CD0A53C9EB73681B4AE587CC5CFDDF39176E2`.
No commit or push was made.

## Supplied Windows 7 result

Archive `0.10-logs-and-bmp.zip`: 3,990,767 bytes, SHA256
`C2C4D9C8D67802E497BBBABF666A6CEE7F76A2DD962A357489CAEC62BA5DDEC6`.
Its 104 flat entries contain one log and 103 BMPs, 591,248,919 bytes uncompressed.
Evidence is preserved under ignored `artifacts/vt7/evidence/arabic-probe-win7-c2c4d9c8`.
Log SHA256: `6B433AE062363C241F445EDE6403671EC8CC42B84EF96E222889DCC79BAD17E8`.

The log reports Windows NT 6.1.7601, Release x64 built Sep 11 2026 22:08:46,
compiler 194435228, captured 2026-09-11 20:13:46 UTC. All 51 required checks and
all five independent validators pass. Arabic accounting: 144 fixtures, 180
whole-word context checks, 60 isolated-word controls, 144 exact natural replays
and shifted-output controls, 1,320 C/V projections, 96 repairs, 24 reviews.

The 96 versus 108 local repair count is entirely in the Consolas fallback-bold
fixture: two rather than three runs change per configuration, with every
whole-word comparison still passing. The supplied faces include Arial/Times
New Roman 5.22, Segoe UI 5.13 and Consolas 5.24. All 79 earlier images are
byte-identical to the supplied 0.9 Windows 7 evidence.

Inspection at 18 DIP/96 DPI and 24 DIP/192 DPI shows improved connections in P
across the tested style/family boundaries. C/V still separate letters. All
24 reviews are the deliberately unresolved lam-alef style split. This accepts
the bounded context experiment, not final Arabic rendering or a separate ESU run.
The next experiment is [shared-span fitting](2026-09-11-joined-span-probe.md).

## Windows 7 handoff

Extract `artifacts/VT7-renderer-probe-0.10-x64.zip` fresh, retain `fonts/`, then
run `RUN-RENDERER-PROBE.cmd` without elevation. Return the log and all 103 BMPs
(79 earlier plus 24 Arabic images), including any failure images. Inspect N/P
at style/font boundaries and compare C/V/P for plain/marked text and digits.
Report any unexpected disappearance, clipping or failure separately from the
known grid-spacing and lam-alef REVIEW limitations. No fonts are installed.
No assets, licenses, OS prerequisites, DPI settings or code pages are changed.

## Research checked for this slice

- Microsoft [Arabic OpenType development](https://learn.microsoft.com/en-us/typography/script-development/arabic):
  contextual glyph substitution and positioning are distinct shaping stages.
- Microsoft [GetGlyphs](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextanalyzer-getglyphs)
  and [GetGlyphPlacements](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextanalyzer-getglyphplacements):
  shaping is font/script dependent and its source-to-glyph relationship need
  not be one-to-one. These baseline APIs do not expose a separate surrounding
  context parameter for independently shaped slices.
- Microsoft [GetFontFromFontFace](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritefontcollection-getfontfromfontface):
  baseline collection lookup supplies the selected system font's properties.

The whole-source repair and its safety limits are VT7 experiments, not behavior
guaranteed by those documents. There is no new dependency or borrowed source.
