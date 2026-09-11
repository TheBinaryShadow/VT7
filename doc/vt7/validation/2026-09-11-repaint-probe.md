# Milestone 2C: differential repaint probe 0.7

Date: 2026-09-11. Branch: `initial-implementation-and-assessment`.
Source base: `42de4b631716e98ef5e231f170f167d671c97939` plus uncommitted 0.6/0.7 work.
Release stamp: `Sep 11 2026 14:04:26`, compiler `194435228`.
Development runtime: Windows NT 10.0.19044. Supplied Windows 7 0.7 results now pass
the isolated experiment; see the target evidence below.
This implements the second slice of the [geometry/repaint plan](../architecture/2026-09-11-font-geometry-test-plan.md).

## Scene and scope

The accepted [Windows 7 0.6 result](2026-09-11-geometry-probe.md) establishes the
offscreen geometry baseline, including stacked-mark overflow across row bounds.
Probe 0.7 retains all 13 reference/geometry images and adds differential repaint
at the same 12 combinations of 12/18/24 DIP and 96/120/144/192 simulated DPI.

Each scene is five rows by 18 columns, with 12 independently shaped, LTR,
core-backed text clusters positioned at fixed coordinates. TerminalCore supplies
each cluster's source/cell span, including wide and combining cases. This is not
a live core edit stream, row-wide shaping, or a test of joins between clusters.
Grid metrics and glyph fitting reuse the 0.6 primary-face and raster-preflight
rules. The private face is forced for the designated emoji node so that the
fallback-to-normal transitions exercise the bundled face on newer systems too.

Twenty edits are applied twice per configuration: mark removal/restoration,
neighbor background changes, italic to space, narrow/wide replacement, combining
mark insertion/removal, private fallback to normal text, foreground/style
changes, and top/bottom viewport-edge marks. There are 480 positive transitions.
All changes return to the initial scene after each complete two-cycle run.

All backgrounds are drawn before glyphs. Stable node/item order defines glyph
composition, including overlapping vertical ink. The teal border is outside the
viewport. Interior ink may cross row boundaries; only the outer viewport clips
it. This is an explicit experimental composition policy, not final typography,
line-height, text-overlap, or terminal interaction acceptance.

## Independent full-frame and incremental paths

Each state retains owned glyph data and measured raster ink rectangles. A fresh
full redraw clears all viewport backgrounds and draws all intersecting glyphs.
The incremental path starts from the previous incremental image, not the oracle.
Its damage is the union of the edited node's old/new cell allocation and old/new
ink, clipped to the viewport. A background-only edit starts with the changed cell.

Only intersecting backgrounds are cleared. Every new glyph whose ink intersects
damage is redrawn, including glyphs owned by unchanged neighboring rows/cells,
in the same composition order as the full redraw. Drawing occurs on a scratch
surface seeded from the previous frame; only the damage rectangle is committed
by blit. No pixels from the full-frame oracle are used in incremental drawing.
The preflight/measurement work and scene preparation are not an optimized cache.

This is a software damage-composition experiment. It does not exercise Atlas
dirty rectangles, GPU partial presentation, DirectWrite target clipping, scroll,
reflow, a render controller, concurrency, or production snapshot generations.
The logged transition generation identifies a deterministic test step; 0.6's
separate stale-geometry-key checks remain in the same executable.

## Required comparisons and negative controls

Every positive transition requires exact RGB equality across the entire canvas
and unchanged pixels outside declared damage. Cached versus drawn ink bounds
must agree. Damage must be nonempty, remain inside the viewport, and not equal
the full viewport. Every transition must redraw fewer glyph items than are
available in the scene, ruling out a silent full-scene redraw. The final image
must exactly reproduce the initial image. The unused BGRX byte is ignored.

At each configuration two deliberately broken runs must produce differences:

- Omit old ink when removing stacked marks. The old pixels above the edited row
  are not cleared, producing stale marks.
- Omit neighboring glyphs after changing a cell background above a marked glyph.
  The changed background erases overhanging ink belonging to the next row.

There must be 24 detected negative cases in total. Their nonzero differences are
required evidence, not baseline failures. Positive mismatches fail the probe and
save full/reference, incremental, and red-pixel difference bitmaps with a failure
prefix. The log identifies the configuration, source/cell ownership, generation,
scenario, damage, selected/available glyph counts, mismatch count, and first
mismatch coordinate.

On success, each configuration saves a sample triple after the neighboring-cell
background change. At 24 DIP/192 DPI, both negative triples are saved as well:
42 new repaint images, 55 total including the prior 13. The independent
`Test-VT7Repaint.ps1` script checks all 480 step records and 24 negative records,
partial damage/draw constraints, and compares RGB pixels in all 14 saved triples.
It independently reconstructs the red difference mask and verifies negative
pixel counts against the log. Normal difference images must be black.

## Local evidence

Debug and Release builds and full renderer suites pass: 52 required baseline
checks, zero failures on this development font inventory. Both configurations
report 480 matching positive transitions, zero outside-damage changes, 480
partial glyph redraws, and 24 detected negative cases. Each saved positive triple
matches exactly. At the largest configuration, each negative case exposes 63
mismatched pixels in the stacked marks above the affected row. The representative
scene and both negative difference images were inspected locally.

The original 13-fixture reference remains byte-identical to the accepted local
0.5/0.6 reference, SHA256
`6991BFE5B7BA29C8A861BA85C9D8C72BA72C4EB03C72A86BB9909003F06F0948`.
The geometry matrix still passes 204 fixtures and 1,164 ink checks, with the same
24 explicit vertical REVIEW observations. Missing/altered font, mapping, CLI,
required-failure, and report-path negative tests still pass.

Atlas Direct3D11/Direct2D hardware/WARP tests pass with 19 frames per combination
in Debug and Release. Host diagnostics/smoke tests and both PE/import audits pass.
No production Atlas, host, ABI, font assets/licenses, or OS baseline changes are
part of this work. Package and target evidence are recorded separately below.

## Windows 7 handoff

Extract `artifacts/VT7-renderer-probe-0.7-x64.zip` into a new writable folder,
retain `fonts/`, and run `RUN-RENDERER-PROBE.cmd` without elevation. Return the log
and all generated bitmaps, preferably together in a ZIP. Success produces 55
bitmaps; on failure send all files available, including any failure triples.

Normal sample full/incremental images should look identical and their difference
images should be black. Red pixels in explicitly named negative difference
images are expected. Check neighboring-row marks, the changed red background,
private glyphs, and the untouched teal border. Do not change fonts, code pages,
desktop DPI, or system updates for this test. No .NET or Power Automate is needed;
the existing graphics/loader/UCRT prerequisites still apply.

Successful target comparison would validate this isolated repaint algorithm on
that setup. It would not resolve legibility where ink overlaps adjacent text or
complete Milestone 2C. Final vertical/line-height policy, production mapping/cache
and ordering decisions, and equivalent tests in Atlas remain integration gates.

## Package verification

The assembled Release package passes the complete renderer, geometry, repaint,
and asset-failure suites plus its PE/import audit. All 19 manifest entries were
independently rehashed and match. All 55 Debug and packaged Release bitmaps are
byte-identical on this machine. Documentation links, changed-text punctuation,
and `git diff --check` pass. No commit or push was made.

Archive: `artifacts/VT7-renderer-probe-0.7-x64.zip` (8,297,678 bytes).

SHA256: `A8E8F397D46582472D32FB60052063B93E67032433826FF53C4FD8903CD58D30`.

The accepted 0.5 and 0.6 archive hashes remain unchanged.

## Supplied Windows 7 acceptance

The returned `probe-0.7-bitmaps-and-log.zip` has SHA256
`25080A9CA64AFE4732D411FCDA5FC508CCFB8EB99DB02B5C1CCD3D2931E9BF68`.
Its log has SHA256
`55FF278D8CAB12D828F3624302688F443F0DD49270752C0E8A76F8B42E421ECB`.
The log records Windows NT 6.1.7601, the Release stamp above, compiler 194435228,
and capture UTC 2026-09-11 12:09:15. This is evidence for that supplied run,
not separate ESU, minimum-prerequisite, or additional hardware acceptance.

- 51 required checks pass with zero failures on the target font inventory.
- All 12 repaint configurations and 480 transitions match fresh full redraw,
  with zero outside-damage changes, 480 partial glyph redraws, and restoration
  to the initial scene.
- All 24 deliberate failures are detected. Each largest-configuration negative
  exposes 64 changed pixels, first at (142,82). This differs from the local
  63-pixel result and is not a cross-machine pixel-equality claim.
- The independent geometry and repaint validators pass, including independent
  RGB/difference-mask checks for all 14 saved repaint triples.
- All 13 reference/geometry bitmaps remain byte-identical to the supplied 0.6
  files. The 204 geometry fixtures and 1,164 ink records retain 24 vertical
  observations. Representative normal and broken images were inspected.

The log and images are retained in the ignored local evidence directory
`artifacts/vt7/evidence/repaint-probe-win7-25080a9c/`. No supplied files were edited.
This accepts the isolated software repaint experiment, not Atlas invalidation.

After reviewing upstream, the user approved continuing with its fixed-grid,
overlapping ordinary-text policy. See the updated
[geometry contract](../architecture/2026-09-11-text-geometry-contract.md).
Overlapping-text legibility, special-glyph clipping, and integration still need
their own tests. The old probes' metric rounding remains frozen evidence.
