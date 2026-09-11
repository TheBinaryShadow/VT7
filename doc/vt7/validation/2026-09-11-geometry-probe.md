# Milestone 2C: size/DPI geometry probe 0.6

Date: 2026-09-11. Branch: `initial-implementation-and-assessment`.
Source base: `42de4b631716e98ef5e231f170f167d671c97939` plus uncommitted 0.6 work.
Release stamp: `Sep 11 2026 13:46:06`, compiler `194435228`.
This implements the first slice of the [geometry/repaint plan](../architecture/2026-09-11-font-geometry-test-plan.md).
The supplied Windows 7 run passes the structural matrix, as recorded below.
The accepted 0.5 target result remains separate; vertical policy is still open.

## Scope and observable output

The command line stays unchanged. The original `.log.bmp` remains the fixed 0.5
reference, including its 13 fixtures, system-only natural lane, and bounded
private fallback. Twelve additional `.log.bmp.geometry-<size>-<dpi>.bmp` images
exercise 12/18/24 DIP at simulated 96/120/144/192 DPI, with 17 fixtures each.
The extra fixtures cover descenders, stacked marks, explicit grid decorations,
and italic/wide edge neighbors. No AtlasEngine, host, ABI, or session change is
part of this experiment. Fonts, licenses, and core Unicode tables are unchanged.

The normal Consolas face supplies cell metrics. Its M advance is rounded to the
nearest pixel; ascent, descent, and line gap are rounded upward separately.
Primary face identity and design-unit metrics are logged so the PowerShell
harness can independently recompute the grid. Layouts are shaped in DIP, then
em sizes, origins, advances, and offsets are converted to device pixels once.
All runs use the primary baseline. Fallback faces cannot change the grid.

U shows full fitted ink after all alternating cell backgrounds have been cleared.
V is a copied one-row viewport crop, intentionally exposing lost edge ink. A
pixel comparison checks the copy and surrounding sentinels. This exercises an
explicit diagnostic blit, not DirectWrite's clip state or Atlas's invalidation.
Underlining and strikethrough are drawn from primary font metrics as grid
decorations; this does not implement layout-decoration callback retention.

## Findings and bounded corrections

The plain-ASCII descender fixture exposed a collector assumption: omitted glyph
offset arrays were being rejected. The installed Windows SDK annotates this
field optional. The collector now owns zero offsets when the pointer is null,
with a synthetic callback regression. Source/cluster coverage remains required.
Other unsupported callback shapes still fail rather than inventing mappings.
See Microsoft's [glyph run definition](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/ns-dwrite-dwrite_glyph_run)
and the pinned SDK `dwrite.h` definition for the geometry representation.

The size/DPI matrix also exposes transformed private-glyph ink that escapes
the old advance/untransformed-ink fit estimate. Only the new matrix adds a
scratch-target raster preflight at an integer-equivalent origin. A failed fit
switches to zero-halo compression and reduces horizontal scale in bounded 10%
steps, remeasuring each attempt. At most 16 reductions are allowed; failure to
converge fails the diagnostic. Final target bounds are checked again. The fixed
0.5 reference policy is unchanged. Logged retry counts and compression factors
remain visual-quality evidence, not approval of arbitrary squeezing.

The natural horizontal halo is explicitly two device pixels in this experiment,
not a shipping constant or a value automatically multiplied by DPI. Vertical
scale stays unchanged. Ink above/below the primary row is logged as REVIEW and
left visible in U. Its crop in V does not authorize losing those marks in VT7.

## Automated acceptance and limits

The matrix requires 12 distinct cases, 204 mapped fixtures, consistent source/core
records across all cases, nonempty private glyphs, valid horizontal bounds,
explicit vertical-review accounting, both decorations, all crop checks, and
fresh correctly sized images. The independent PowerShell checker rejects a
deliberately out-of-bounds synthetic record. It recomputes cell rounding from
logged design metrics instead of trusting the reported grid.

Four repeated size/DPI changes exercise stale geometry-key rejection through
the actual render entry point. Returning to 18 DIP/96 DPI must reproduce both
initial and fresh-render RGB bytes. The unused GDI BGRX byte is excluded from
pixel comparisons. This diagnostic key is not a production snapshot/cache or
thread-lifetime implementation. Font/style generation and real HWND/display-DPI
transitions remain separate gates, as does differential incremental repaint.

## Windows 7 handoff

Extract `artifacts/VT7-renderer-probe-0.6-x64.zip` into a new writable local
folder, retain `fonts/`, and run `RUN-RENDERER-PROBE.cmd` without elevation.
Send the full log and all 13 bitmap files, preferably zipped together. If a
failure prevents later images, send the available files and full log.
No font installation, code-page change, desktop DPI change/logoff, .NET, or
Power Automate is required. Existing graphics/loader/UCRT prerequisites apply.

Compare the smallest and largest geometry images, plus the intermediate scales.
Inspect stacked marks above A and below g, descenders, decorations, first/last
cell ink, private glyph shapes, and adjacent wide characters. Preserve the full
matrix even if only some images look unusual. A passing structural baseline
with vertical REVIEW observations is not final vertical clipping/line-height
acceptance. Resolve those observations before adopting a production policy.

## Local results

The development machine reports Windows NT 10.0.19044, not Windows 7.
Debug and Release builds and full probe suites pass. The original required-check
accounting remains 52 checks with zero failures on this font inventory. The new
matrix adds 12 cases, 204 mapped fixtures, 1,164 independently checked ink records,
204 crop/sentinel checks, and successful stale-key and RGB round-trip checks.
Both configurations record 24 vertical REVIEW draws: the upper/lower stacked
marks exceed the primary row in each of the 12 cases. This is an unresolved
vertical policy observation, not a structural test failure or accepted clipping.

Two private-BMP draws require one additional raster-preflight reduction each.
Their final scale is approximately 0.380769, with contained horizontal bounds.
All remaining final horizontal bounds pass. The smallest, intermediate, and
largest comparison images were inspected: the full versus cropped stacked marks
are visible, primary baselines and alternating backgrounds remain coherent, and
the private BMP's narrow appearance remains an explicit quality compromise.

The fixed reference bitmap is byte-identical in Debug and Release and matches
the previously recorded local 0.5 bitmap hash:
`6991BFE5B7BA29C8A861BA85C9D8C72BA72C4EB03C72A86BB9909003F06F0948`.
This is a same-machine reference, not an expected cross-machine hash.

Existing missing-base/missing-Upper/wrong-hash, mapping, injected-required-failure,
invalid-CLI, and unwritable-report tests pass in both configurations. The added
optional-offset callback and independent invalid-bound oracles pass. Atlas
Direct3D11/Direct2D hardware/WARP suites pass with 19 frames per combination in
Debug and Release. Host diagnostics and smoke tests, plus both full PE/import
audits, pass. No production renderer or host behavior is claimed from this probe.

## Package verification

The assembled Release package passes the full renderer/geometry and asset-failure
suites, plus its PE/import audit. All 19 manifest entries were independently
rehashed and match. All 13 Debug and packaged Release bitmap outputs are
byte-identical on this machine. Documentation links, changed-text punctuation,
and `git diff --check` pass. No commit or push was made.

Archive: `artifacts/VT7-renderer-probe-0.6-x64.zip` (8,061,267 bytes).

SHA256: `08138326810E2C86124A8854CC38F492DD0E3FC40429B9C3243E11EBED7C23F0`.

All earlier renderer 0.1 through 0.5, Atlas 0.1, and GDI 0.2.1 archive hashes
remain unchanged.

## Supplied Windows 7 result

The user supplied `probe-0.6-logs-and-bitmaps.zip`, captured at 2026-09-11
11:50:29 UTC on Windows NT 6.1.7601 with the Release stamp above. Its log and
13 bitmaps are preserved in `artifacts/vt7/evidence/geometry-probe-win7-5f33be70/`.

- Supplied ZIP SHA256: `5F33BE709CCDC476990FC0D80BF1EBF0164E99909869368F3FAD6EC51E81ADFE`.
- Log SHA256: `C0C5F54FCE7B80AD1E16D2471E819881FBE9D6A320D9E2C6FF56ED30C1E30361`.
- Reference bitmap SHA256: `3D3F4247B5017CA60D4F048C35FD3208A2166707D19351860820CAE7E8EFDD21`.

The baseline passes 51 required checks, zero failures. The independent geometry
script passes all 12 cases, 204 fixtures, 1,164 ink records, image structures,
core-cell invariance, crop checks, and stale-key/RGB restoration records.
The reference image is byte-identical to the supplied 0.5 image, and all 78
reference CELL records are unchanged. Both private font hashes match their pins.

All 24 vertical REVIEW draws belong to stacked marks, two per configuration.
The largest observed extension is eight pixels above and twelve below the primary
row. The smallest, intermediate, and largest images were reviewed: strict V-lane
row clipping visibly removes parts of these marks. This confirms the local
observation, not acceptance of that clipping policy. Two private BMP cases,
12 DIP/192 DPI and 24 DIP/96 DPI, each need one raster-fit retry, ending at scale
0.380769 with contained horizontal bounds.

The user approved proceeding to the [differential repaint experiment](2026-09-11-repaint-probe.md).
This result accepts the bounded offscreen structural matrix on the supplied setup,
not a separate ESU matrix, physical HWND DPI behavior, or final line-height policy.
