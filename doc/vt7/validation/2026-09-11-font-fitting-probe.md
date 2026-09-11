# Milestone 2C: font coverage and whole-ink fitting probe 0.3

Date: 2026-09-11. Branch: `initial-implementation-and-assessment`.
Source base: `bf196fdb22c1b347f448543ebb715d395ccf163a`, plus the uncommitted
2C probe changes. This follows the user's approval of all three follow-up points
and the requested [online research](../research/2026-09-11-font-coverage-and-fitting.md).

## Changes from 0.2

- Independent U+1F600 scalar coverage scan across DirectWrite's system collection.
  Every face is checked using HasCharacter and GetGlyphIndices. Supporting faces
  have identity/file/hash diagnostics; errors are counted. No match with errors
  is INDETERMINATE. A confirmed candidate is drawn directly with nonempty ink,
  bypassing automatic TextLayout fallback. No match alone is not a failed probe.
- Whole-ink horizontal fitting replaces advance-only compression. Measured ink
  and pen extent determine a transform applied to outlines, advances, and offsets
  together. Compression is allowed; expansion is not. Actual drawn rectangles
  must stay inside their allocated cell interval. Whitespace may have empty ink.
- DirectWrite's physical run order is used once. RTL shaped runs are kept intact
  to preserve contextual joining; LTR clusters are fitted separately. The core's
  original logical cells/text are unchanged. Logical/visual cell projection is
  bijective and round-trip checked, but is not a proportional glyph hit-test map.
- All eleven fixtures are now required, including pure/mixed/marked Arabic.
  A mapping failure fails the baseline instead of being an exploratory pass.
  Added coverage-status, fitting, and visual-order oracles complement the existing
  cluster/ownership/core checks and deliberately invalid mapping test.
- The diagnostic bitmap is top-down 1100x1200, with N/C comparison lanes and an
  explicit U+1F600 candidate at the bottom, or a clear no-candidate label.

The original 0.1 sample, hidden hardware/WARP capability tests, source ownership,
and explicit missing-glyph reporting are preserved. This executable still does
not link or instantiate AtlasEngine. No production host/core/Atlas implementation
was changed in this follow-up, and no font or external dependency was added.

## Local evidence

Development runtime: Windows NT 10.0.19044. Pinned VS2022/MSVC 14.44.35207 and
SDK 10.0.26100.0. Release build stamp: `Sep 11 2026 07:53:31`, compiler `194435228`.

Debug and Release probe suites pass 52 required checks, zero failures, eleven
mapped fixtures, zero unresolved. Both scan 1,003 font faces, find eight supporting
faces, and report zero coverage errors. Explicit candidate rendering succeeds.
These counts describe this development machine only, not Windows 7.

The tests assert fresh output, exact fixture accounting, coverage status and
candidate consistency, bitmap header/dimensions, and diagnostic markers. Native
oracles check absent/error/found coverage status, fitting overhang/compression/no
expansion, pure/mixed RTL visual ordering, and logical/visual round trips. Every
fitted draw checks its actual horizontal ink bounds. Existing mapping injection
returns 1; required-failure injection returns 1; invalid CLI returns 64; a report
path naming a directory returns 2. These are bounded tests, not a font fuzzer.

The local image was inspected: Arabic contextual shapes/joining remain coherent
with the natural lane, including mixed text/digits and a combining mark. Fitted
emoji stays within its span. The conservative one-pixel edge allowance visibly
narrows some glyphs. This is accepted for this diagnostic comparison, not final
typographic quality. A nonzero sequence glyph does not establish color emoji or
complete ZWJ sequence support on another OS.

Local reports are under `artifacts/vt7/reports/Debug/` and `Release/`:
`renderer-probe.log`, its `.bmp` companion, and the two negative-test logs.
Existing Atlas and GDI/host regression results are recorded below.
No local result is promoted to Windows 7 acceptance.

## Windows 7 handoff and remaining gates

Extract `artifacts/VT7-renderer-probe-0.3-x64.zip` into a new writable local folder
and run `RUN-RENDERER-PROBE.cmd` without elevation. Do not overwrite the previous
package/evidence. Send `VT7-renderer-probe.log` and `VT7-renderer-probe.log.bmp`,
even if the report fails. If there is no bitmap, send the log and observed error.
Use the normally updated Windows 7 SP1 x64 test machine first.

No Power Automate, .NET, new font installation, registry changes, or new update
installation is required by this follow-up. Existing VT7 platform prerequisites
still apply. Reports include installed font paths and hashes, not font files or
session text. Collection enumeration can take longer with many installed fonts.

Check the original missing glyph, the coverage result and explicit-candidate
image, Arabic N/C joining and order, and emoji separation from adjacent A/B.
No confirmed candidate with zero errors establishes lack of U+1F600 coverage in
that system collection, not in every file on disk. A found candidate points us
back to automatic fallback selection. Errors retain an indeterminate result.

The supplied Windows 7 0.3 execution is recorded below. Full Atlas adapter
selection, fallback preference/cache invalidation, vertical clipping/baselines,
DPI and size variation, style/font splits through clusters/joining groups,
cursor/selection/IME/accessibility geometry, and full bidi policy remain open.
In particular, the diagnostic cell projection must not become production glyph
hit testing. See the research record for the next decision after the target run.

## Final package and regressions

Debug and Release Atlas regressions pass all four combinations: Direct3D11 and
Direct2D, each on hardware and WARP, 19 frames each with exact pixel checks.
Both host diagnostics and window smoke suites pass in both configurations.
The full development builds passed the existing import/PE/punctuation audit;
the final Release probe/package passed again after the coverage-error correction.
The correction retains a confirmed coverage candidate even if later optional
font identity collection fails, instead of losing the ability to draw it.

The assembled Release package passes its complete probe suite and import/PE audit.
All 14 manifest entries were independently rehashed successfully. Debug and
packaged Release diagnostic BMPs are byte-identical locally, SHA256
`D3BB0AE931CA1E26387B2984BC9D2128581A7611D7B8113386688C96F0F609AC`.
This is within-machine consistency, not a cross-OS pixel requirement.

Archive: `artifacts/VT7-renderer-probe-0.3-x64.zip`.

SHA256: `3854E5D45CEFD0971D9E4022CA46C114673EC8B3E86C27F7E1CB159DE2FC164D`.

The existing 0.2 font probe, 0.1 capability probe, 0.1 Atlas proof, and 0.2.1 GDI
proof archives are preserved, rather than overwritten by the 0.3 packaging path.
Their hashes still match the identities in the 0.2 validation record.

## Supplied Windows 7 result and update confirmation

Target log: Windows NT 6.1.7601, probe 0.3, Release stamp `Sep 11 2026 07:53:31`,
captured UTC 2026-09-11 06:07:55. Preserved copies are under
`artifacts/vt7/evidence/font-probe-win7-20260911-060755/`.

- 51 required checks, zero failures; eleven fixtures mapped, zero unresolved.
  The local count is 52 because the original sample has an additional font face
  and therefore an additional per-face required check.
- 575 faces scanned, zero supporting U+1F600, zero errors: NONE_IN_COLLECTION.
  Explicit-candidate drawing is correctly skipped. This establishes missing
  scalar coverage in this machine's DirectWrite system collection, not every
  font file on disk or all Windows 7 installations.
- The user separately verified that KB2729094 is already installed. This is
  user-confirmed update state, not an installed-update inventory collected by
  the probe. Do not diagnose a missing update or ask for its reinstallation.
- Independent log checks found 67 fitted draws, zero horizontal cell overflow,
  and all 76 core-cell records identical to the development-machine records.
- The image preserves Arabic joining/order against its natural reference in
  the three samples. The woman/laptop sequence remains two symbols, compressed
  to 50% horizontal scale, but no longer escapes its cells or overlaps adjacent
  A/B. This is not composed-emoji support.
- Ordinary Latin and italic text is still too compressed. For example, A uses
  scale 0.666667 and italic f uses 0.571429. Strict containment is proven for this
  corpus; final typographic quality is not accepted. Probe 0.4 addresses this
  by separating cell ownership from bounded natural ink overhang.

Log SHA256: `E7E69A744D558677D25C423B8921C1C25D449CE7F8BA1DED88322B29732F6D9B`.

Bitmap SHA256: `02DD9B3B39D1CA31CEBB049CA59E04C7E9D4FB263BA9414AEFF9AC63EF077BF2`.

No separate ESU run, full bidi conformance, or AtlasEngine acceptance is claimed.
