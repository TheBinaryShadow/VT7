# Milestone 2C: natural-size fitting probe 0.4

Date: 2026-09-11. Branch: `initial-implementation-and-assessment`.
Source base: `bf196fdb22c1b347f448543ebb715d395ccf163a` plus uncommitted 2C changes.
Release stamp: `Sep 11 2026 08:24:33`, compiler `194435228`.
The development runtime reports Windows NT 10.0.19044, not Windows 7.

## Why this iteration

The [supplied Windows 7 0.3 result](2026-09-11-font-fitting-probe.md) passes all
checks but squeezes normal Consolas and italic glyphs. The user also confirmed
KB2729094 installed, so missing U+1F600 coverage is not diagnosed as a missing
update. No font installation or update change is part of this follow-up.

## New fitting policy

At the fixed 96 DPI diagnostic geometry, natural advances that fit their cell
allocation retain scale 1, provided raster ink fits a two-pixel halo on either
side. The baseline offset is integral to preserve raster phase. Logical cells
do not grow, and hit testing must never use the halo to derive terminal columns.
Groups exceeding either the advance or ink bound use the existing whole-ink
compression with no enlargement and strict zero-overhang cell containment.

This is an explicit change from 0.3's strict per-cell acceptance rule, not an
unreported relaxation. Every draw logs its scale, policy, halo, cell interval,
and actual drawn interval. The native check and PowerShell harness independently
validate those bounds. The first Latin and italic fixtures must contain natural
draws and zero compressed draws. This is a quality gate for the tested Consolas
corpus, not a promise that every font revision or arbitrary string will pass.

The eleven fixtures, original mixed-script sample, coverage scan, preserved RTL
run experiment, and bitmap dimensions remain unchanged. No production Atlas,
TerminalCore, native ABI, or host code is modified by this iteration.

## Local evidence

Debug and Release builds and probe suites pass: 52 required checks, zero failures,
eleven mapped fixtures, zero unresolved. The local reports record 64 natural-size
draws and four compressed draws, including the optional explicit coverage glyph.
All 13 Latin-combining draws and all 12 italic draws retain scale 1. Bold uses
eight natural draws and zero compressed draws on this machine. These counts
depend on the installed fonts and are not Windows 7 results.

New oracles cover regular/italic bounded overhang, excessive overhang, oversized
groups, empty ink, and invalid negative advances. Existing cluster/cell/bidi
oracles and mapping/required-failure/invalid-CLI/unwritable-report negative tests
still pass. The harness checks every reported fit against its declared halo and
requires natural draws to have scale 1. The local comparison image was inspected:
Latin and italic proportions are visibly improved, Arabic still follows its
natural reference, and oversized glyph groups remain bounded.

Reports: `artifacts/vt7/reports/Debug/renderer-probe.log` and the corresponding
Release log, each with a `.bmp` companion.

## Contract and limits

The new [text geometry contract v0.1](../architecture/2026-09-11-text-geometry-contract.md)
defines source/core/glyph/pixel ownership, snapshot generations, interaction
coordinate rules, and separate ink damage. It records the inherited Atlas LTR
analysis settings, and keeps diagnostic visual bidi out of the default production
path. Logical-order complex-script shaping versus a deliberate visual-bidi mode
still needs implementation evidence before final integration.

The two-pixel halo is a fixed-probe parameter, not a production DPI policy.
Partial redraw, neighboring backgrounds, stale ink, viewport clipping, vertical
metrics, DPI/size variation, and font/style splits need further tests. The static
image cannot prove those behaviors or cursor/selection/IME/accessibility correctness.
Missing system font coverage remains a separate optional-dependency decision.

## Windows 7 handoff

Extract `artifacts/VT7-renderer-probe-0.4-x64.zip` to a new writable local folder.
Run `RUN-RENDERER-PROBE.cmd` without elevation, and return the full
`VT7-renderer-probe.log` and `VT7-renderer-probe.log.bmp`, even on failure.
Compare Latin, bold, and especially italic N/C proportions with 0.3. Also check
that emoji neighbors and Arabic remain coherent. No new font, update, .NET,
Power Automate, or system configuration change is requested. Existing platform
prerequisites still apply. The subsequently supplied target result is recorded below.

Earlier 0.1/0.2/0.3 renderer, 0.1 Atlas, and 0.2.1 GDI archives remain preserved.

## Final regression and package checks

Debug and Release Atlas suites pass all four combinations (Direct3D11/Direct2D,
hardware/WARP), with 19 frames each and exact pixel checks. Host diagnostics and
window smoke tests pass in both configurations. The Debug full binary audit and
Release probe/assembled-package import/PE audits pass. The assembled package
passes its complete probe suite; all 14 manifest entries were rehashed and match.
Changed-file punctuation and `git diff --check` pass. No commit or push was made.

The Debug and packaged Release bitmaps are byte-identical on this machine:
SHA256 `018837D361DA89A0D9C9F793FB18FE70124A27F20D26DB0C824C1A71CCC03231`.
This does not require cross-machine pixel equality.

Archive: `artifacts/VT7-renderer-probe-0.4-x64.zip`.

SHA256: `7DF4DF1E2BCCFBBA55BC0B0E6320DCD1EC118F830DB5E414BDB9415F7DFEAA71`.

All earlier archive hashes match their recorded identities.

## Supplied Windows 7 result

The user supplied the 0.4 report and bitmap captured at 2026-09-11 06:31:43 UTC
on Windows NT 6.1.7601. Evidence is preserved under
`artifacts/vt7/evidence/font-probe-win7-20260911-063143/`.

- Log SHA256: `6F763125F5FA8228B8FBC610275C74486BBAF084C1EA6E4C81953E63A8FF62FB`.
- Bitmap SHA256: `417C557A289BC41ADE9814214F63E016F370C5B7DAE8C48712CE292BAE3D0BAB`.
- 51 required checks, zero failures, eleven mapped fixtures, zero unresolved.
- 65 natural draws and two compressed draws. All 13 Latin, 12 italic, and
  eight bold draws retain scale 1. Nine draws use the permitted natural halo;
  none of the 67 draws exceed their declared bounds.
- Pure, mixed, and marked Arabic follow the natural reference in the supplied
  static comparison. The woman/laptop sequence remains separate glyphs, not a
  composed emoji. This is not final terminal bidi or interaction acceptance.
- U+1F600 remains absent from 575 scanned system faces, with zero scan errors.
  KB2729094 was already user-confirmed installed; no update reinstall is proposed.

This closes the pending target execution/comparison for 0.4, not the production
fitting, partial redraw, DPI, or font fallback gates. The subsequent approved
[0.5 private-font experiment](2026-09-11-private-font-probe.md) addresses the
missing standalone glyph without changing the original system-only diagnostics.
