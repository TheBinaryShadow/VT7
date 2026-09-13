# Milestone 2C: private fallback font probe 0.5

> Historical validation record. Status and next steps below describe this checkpoint.
> For current work, see the [handoff](../HANDOFF.md) and
> [0.3.5 C3 stability investigation](2026-09-13-atlas-stability.md).

Date: 2026-09-11. Branch: `initial-implementation-and-assessment`.
Source base: `bf196fdb22c1b347f448543ebb715d395ccf163a` plus uncommitted 2C changes.
Release stamp: `Sep 11 2026 08:55:04`, compiler `194435228`.
Development runtime: Windows NT 10.0.19044. The supplied Windows 7 SP1 x64
0.5 run passes the bounded private-font experiment; details follow below.

## Assets and licensing

The user approved bundling private fallback fonts after the supplied Windows 7
0.4 run confirmed the missing U+1F600 system coverage. Unmodified static CFF/OTF
Unifont and Unifont Upper 17.0.05 are now in `oss/unifont/`. The official upstream
archive, acquisition method, exact font/license hashes, and copyright holders
are recorded in [font provenance](../../../oss/unifont/README.md).

VT7 application code stays MIT licensed. The fonts are distributed under the
SIL Open Font License 1.1 option of their upstream dual license, not MIT.
The original OFL text and upstream COPYING statement accompany both source and
probe packages. No Unifont utility code is compiled or linked into VT7.
LICENSE is unchanged; NOTICE, the root README, and package documentation identify
the separately licensed assets. No font installation or system configuration
change is performed.

## Bounded implementation

The probe resolves the executable's own `fonts` directory, verifies pinned
SHA256 values before font parsing, then uses baseline DirectWrite file/face
creation APIs. It does not register a system font collection or require the
newer font-fallback APIs. Both faces must load and provide their known BMP/SMP
test glyphs; an absent scalar must still map to zero.

System-shaped runs remain preferred. In the experimental C lane, a missing
standalone symbol/pictograph in U+2190..U+2BFF or U+1F000..U+1FAFF can use a
private face only when the entire run is one scalar, one glyph, and one complete
core cluster. RTL, sideways runs, combining text, ZWJ sequences, and cross-run
clusters are not replaced with raw font glyphs. This is a bounded explicit cmap
fallback test, not the finished cluster-aware Atlas font adapter.

Original UTF-16 and TerminalCore cells stay authoritative. Private advances are
fitted into that allocation, never used to resize cells. The bitmap preserves
the original eleven fixtures and adds forced private BMP (U+262F) and SMP
(U+1F600) C-lane samples. Their N lanes remain system-only. The forced samples
test private loading and nonempty raster output even on a newer system that
already covers those scalars. The original 0.1 sample and independent system
coverage scan are unchanged and may still report the missing system glyph.

## Local evidence

Debug and Release builds and probe suites pass: 52 required checks, zero failures,
13 mapped fixtures, zero unresolved. Both private faces report CFF type 0 and
the expected hashes. U+262F maps to base glyph 9776; U+1F600 to Upper glyph 48676.
Both forced private glyphs produce nonempty ink. Local fit accounting is 65
natural draws and five compressed draws, all within declared horizontal bounds.
Latin and italic retain their existing natural-size regression guarantees.

Negative tests reject missing base font, missing Upper font, wrong font hash,
invalid mapping, injected required failure, invalid CLI, and unwritable report.
Each asset-failure case uses an isolated executable folder, without altering
real assets. The bad-hash case has a separate path because DirectWrite/font
caching can keep a loaded file mapped after process exit. A first test-harness
attempt to overwrite that disposable mapped copy failed; separating the cases
resolved the harness issue and all tests were rerun successfully.

The comparison bitmap was inspected locally. Private output is monochrome and
pixel-derived; the one-cell BMP symbol is compressed horizontally. This quality
tradeoff is visible, not claimed to match the normal system typeface.

## Windows 7 handoff

Extract `artifacts/VT7-renderer-probe-0.5-x64.zip` into a new writable local
folder, keeping `fonts/` intact. Run `RUN-RENDERER-PROBE.cmd` without elevation.
Return `VT7-renderer-probe.log` and `VT7-renderer-probe.log.bmp`, also on failure.
No system font installation, code-page change, .NET, or Power Automate is needed.
The existing Windows 7 SP1 x64 graphics/loader/UCRT prerequisites still apply.

Check both forced private C-lane symbols. On the previously tested Windows 7
font inventory, Supplementary N should retain the missing system glyph while
Supplementary C should show private U+1F600, with a `missing-system-glyph`
PRIVATE_FALLBACK record. Verify adjacent characters, Latin/italic proportions,
and Arabic against 0.4. The final system-only candidate may remain absent; that
is expected and does not invalidate private fallback.

The supplied target execution is recorded below. There is no claim of color emoji,
ZWJ composition, universal Unicode coverage, new complex-script shaping, or
complete production fallback. Unifont's Unicode 17 repertoire does not update
TerminalCore's Unicode 16 width tables. Full font mapping/cache/style policy,
vertical/DPI behavior, partial redraw, and Atlas integration remain open.

## Final regression and package checks

Debug and Release Atlas tests pass all four Direct3D11/Direct2D hardware/WARP
combinations, with 19 frames and exact pixel checks per combination. Host
diagnostics and window smoke tests pass in both configurations. Both full binary
audits and the assembled Release probe's PE/import audit pass. The complete
probe suite also passes from the assembled package, including private asset
negative tests. All 19 package manifest entries were independently rehashed and
match. The final Release bitmap was inspected after packaging.

Archive: `artifacts/VT7-renderer-probe-0.5-x64.zip`.

SHA256: `F7106B1EED215F76F9ED54CA8361BB346ACDA6CF0691DFADB17409F091FFFA60`.

All earlier renderer 0.1/0.2/0.3/0.4, Atlas 0.1, and GDI 0.2.1 archive hashes
still match their recorded identities. No commit or push was made. Local and
supplied target results are recorded separately, not treated as interchangeable.

## Supplied Windows 7 result and acceptance

The user supplied the 0.5 log and bitmap captured at 2026-09-11 07:00:24 UTC
on Windows NT 6.1.7601, with the Release stamp listed above. Evidence is preserved
under `artifacts/vt7/evidence/font-probe-win7-20260911-070024/`:

- Log SHA256: `9F009A1523ABC8595598872069183E3221CB6DD16587A35BE22FE1EBC94351F1`.
- Bitmap SHA256: `3D3F4247B5017CA60D4F048C35FD3208A2166707D19351860820CAE7E8EFDD21`.
- Bitmap dimensions: 1100 x 1400. `preview.png` is a viewing conversion, not the
  original bitmap used for the recorded hash.

The baseline passes 51 required checks with zero failures. All 13 fixtures map,
with zero unresolved mappings. Both private CFF faces load from the package's
`fonts` directory with the pinned hashes. U+262F uses Unifont glyph 9776;
U+1F600 uses Unifont Upper glyph 48676. Both forced private C lanes have visible
glyphs. Crucially, the ordinary Supplementary fixture reports
`PRIVATE_FALLBACK: missing-system-glyph` for U+1F600, demonstrating the automatic
missing-glyph path, not just forced test substitution.

The system collection still has 575 scanned faces, zero supporting U+1F600,
and zero scan errors. The Supplementary N lane and original system-only sample
therefore retain glyph zero, while Supplementary C renders the private face.
The final explicit system-candidate draw is correctly skipped. Comparing required
PASS records with the development log identifies the count difference separately:
the development sample has an additional `Font face 2 / Face1` check. The original
sample checks each distinct selected face, so its installed-font-dependent face
count yields 51 required checks here versus 52 locally. It is not a dropped
private-font check or an unexplained failure.

An independent review of the report verifies all 69 FIT records against their
declared horizontal bounds: 66 natural, three compressed, zero violations.
Eleven draws use permitted natural overhang. All 76 original CELL records match
the supplied 0.4 log in order, with two additional private-fixture records.
Latin-combining (13 draws), bold (eight), and italic (12) remain uncompressed.
The 0.5 bitmap shows no obvious new regression in those samples or the retained
pure/mixed/marked Arabic comparison. This is bounded visual review, not full
script or interactive conformance.

The pixel-derived private smiley is visible; the one-cell yin-yang is noticeably
squeezed. The woman/laptop sequence remains separate glyphs rather than a composed
emoji. These are explicit quality limitations, not hidden by the passing baseline.
The user accepted proceeding after this review. This evidence accepts the exact
private faces and bounded fallback on this Windows 7 setup. It does not establish
a separate ESU/non-ESU 0.5 matrix or acceptance of all Milestone 2C gates.

Next: the [geometry and repaint test plan](../architecture/2026-09-11-font-geometry-test-plan.md).
Keep the tested 0.5 archive immutable; a documentation update does not rebuild it.
