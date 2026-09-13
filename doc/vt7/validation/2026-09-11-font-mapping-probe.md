# Milestone 2C: retained font runs and core-cell experiment

> Historical validation record. Status and next steps below describe this checkpoint.
> For current work, see the [handoff](../HANDOFF.md) and
> [0.3.5 C3 stability investigation](2026-09-13-atlas-stability.md).

Date: 2026-09-11. Package: renderer/font probe 0.2. Source branch:
`initial-implementation-and-assessment`. Implemented after the approved
[research-driven plan](../architecture/2026-09-11-research-driven-plan.md).
This is partial F01/F02 evidence, not completion of 2C or AtlasEngine acceptance.

Source base: `bf196fdb22c1b347f448543ebb715d395ccf163a`, plus the uncommitted 2C
probe changes described here. Local runtime reports identify Windows NT
10.0.19044. Release build stamp: `Sep 11 2026 07:21:03`, compiler `194435228`.
The initial checks below are development-machine results. The subsequently
supplied Windows 7 result is recorded separately near the end of this document.
The advance-only mapping described here is historical 0.2 behavior, superseded
in [probe 0.3](2026-09-11-font-fitting-probe.md), not the current fitting candidate.

## Scope and design

The [probe](../../../src/vt7/VT7.RendererProbe/probe.cpp) preserves the original
0.1 sample text, Consolas format, 320x128 layout, and wrapping. It adds detailed
run diagnostics without replacing the original aggregate count or graphics tests.
This is essential for reproducing the Windows 7 one-missing-glyph observation.

[FontAnalysis](../../../src/vt7/VT7.RendererProbe/FontAnalysis.cpp) copies UTF-16
text, locale, cluster map, glyph IDs, advances, offsets, baseline, direction,
measuring mode, and em size; it retains font-face COM references. Diagnostics
include family/face/version, face index, simulations, font file path, SHA256 when
readable, and the source cluster associated with each zero glyph. A zero glyph's
cluster association is not itself a diagnosis of which font/shaping step failed.

The nine no-wrap fixtures cover Latin/combining text, CJK, supplementary text,
Arabic, Indic, an emoji ZWJ sequence, bold, italic, and a deliberately absent
family. [CoreCells](../../../src/vt7/VT7.RendererProbe/CoreCells.cpp) writes each
fixture into an actual TerminalCore buffer and extracts original text plus cell
spans, skipping wide continuation cells. Source reconstruction must match exactly.
No independent Unicode-width algorithm or installed-font advance determines cells.

After layout and collector destruction, retained runs are mapped and drawn with
the Windows 7-compatible DirectWrite bitmap target. The experimental mapper merges
shaping clusters split within a core cell, preserves multi-cell ligatures and
descending glyph-cluster indices, and rejects cross-run cell splits requiring a
more deliberate design. It asserts exact UTF-16 and glyph coverage. The cell
lane adjusts pen advances to a fixed 10-pixel grid while retaining shape offsets;
this is not the selected final fitting/overhang/bidi policy.

The BMP has an N (natural layout) and C (logical core cells) lane per fixture.
It is a software diagnostic image, not GPU Atlas output or a live terminal.
The image is top-down 1100x900 BGRA/BGRX storage with an opaque BMP interpretation.
A single cold Draw/copy duration is logged as an observation, not a benchmark.

## Local evidence

The pinned VS2022/MSVC 14.44.35207/SDK 10.0.26100.0 toolchain builds Debug and
Release. No new third-party dependency was introduced; the probe now links the
existing VT7.Core and packages its additional existing dependency notices.

| Check | Development-machine result | Limits |
| --- | --- | --- |
| Original graphics/callback checks plus new required checks | 52 required, zero failed, Debug and Release | Supplied Windows 7 result recorded below. |
| Font fixtures | Nine structurally mapped, zero unresolved, both configurations | Coverage/order/cell mapping does not establish correct visible shaping. |
| Retained ownership | Arrays/faces used after layout/collector destruction | Not asynchronous cache/lifetime stress. |
| Deterministic oracles | Ligature, split combining cluster, descending indices, invalid index, real core-cell geometry, and synthetic missing-glyph source association pass | Fixed, bounded corpus, not general conformance. |
| Negative harness | Required failure and invalid mapping return 1, bad CLI returns 64, unwritable report returns 2 | Detailed failure logs checked for freshness and expected cause. |
| Diagnostic BMP | Dimensions, top-down header, and fresh output checked; image visually inspected | Not cross-machine pixel equality or final font rasterization acceptance. |
| Existing Atlas backends | Debug/Release D3D11 and D2D, hardware/WARP: 19 frames each, exact pixel checks pass | Existing fixed-glyph harness remains separate. |
| Existing GDI/host/core | Debug/Release diagnostics and window smoke suites pass | No interactive session acceptance. |
| Release binary audit | Probe, host/native, Atlas harness and available bundled runtime imports/PE targets pass existing verifier | Import checks are not a complete behavioral/platform audit. |
| Final Debug audit | Host/native, probe and Atlas harness pass existing verifier | Same behavioral/platform limits apply. |
| Assembled 0.2 package | Release import/PE audit, complete probe harness, and all 14 manifest checksums pass | Test executed on development Windows, not the target. |

Local report paths under `artifacts/vt7/reports/<configuration>/`:

- `renderer-probe.log` and `renderer-probe.log.bmp`.
- `renderer-probe-mapping-failure.log` and `renderer-probe-injected-failure.log`.
- Existing `diagnostics.log`, `window-smoke-test.log`, and `Atlas/` reports.

## Findings that remain open

- The development machine resolves the original sample without a missing glyph.
  The supplied Windows 7 result now identifies U+1F600 as the missing cluster,
  but independent installed-font coverage still needs the 0.3 scan.
- The Arabic C lane visibly differs from the natural layout's ordering/joining.
  Preserving logical cells while keeping shaped contextual forms needs an explicit
  terminal ordering policy and adapter decision. Nine structural passes do not
  waive this discrepancy or establish full bidi behavior.
- The emoji-sequence rendering and grid overhang/fitting need visual evaluation
  on both machines; successful callback collection is not complete sequence support.
- Complex font-run splits inside a core cell are reported as MAPPING_UNRESOLVED.
  The first three basic fixtures are required; later fixtures are exploratory
  and unresolved cases are counted explicitly. Drawing/API failures still fail
  the baseline, rather than being treated as expected mapping limitations.
- Full font inventory, font-change/cache invalidation, fallback scale/baseline,
  decorations, style splits inside clusters, reflow, DPI, performance comparison,
  and real AtlasEngine/controller integration are not proven by this package.

Do not instantiate the unported AtlasEngine on Windows 7 yet. No selected
production adapter or change to its mandatory fallback calls is part of this slice.

## Windows 7 handoff

1. Extract `artifacts/VT7-renderer-probe-0.2-x64.zip` to a writable local folder.
2. Run `RUN-RENDERER-PROBE.cmd` without elevation. No .NET, Power Automate,
   global font installation, or system changes are needed for this native probe.
3. Open `VT7-renderer-probe.log.bmp` and compare N/C lanes. Send the image and
   complete `VT7-renderer-probe.log`, even if the baseline fails. If image creation
   fails, send the available log and describe what happened.
4. Use the normally updated Windows 7 machine first. Keep ESU acceptance and
   clean-minimum-image qualification separate from that iteration run.

Reports contain fixed sample text and installed font paths/hashes, not font files
or session content. Review paths before sharing. Reruns overwrite that folder's
log/image; retain earlier runs in separate folders if needed.

The earlier renderer-probe 0.1, Atlas backend 0.1, and GDI viewport 0.2.1 archives
remain unchanged. Packaging 0.2 uses a different directory and archive name.

## Supplied Windows 7 evidence

The user supplied the 0.2 log and bitmap from `K:\VT7_work`. The preserved local
copies are under `artifacts/vt7/evidence/font-probe-win7-20260911-053320/`.
The log reports Windows NT 6.1.7601, the same Release build stamp, and UTC
2026-09-11 05:33:20. It passes 51 required checks, zero failures, nine mapped
fixtures, zero unresolved. The required count differs from local 52 because
the original sample uses two faces instead of three, with per-face checks.

- Original run 7 maps UTF-16 [60,62), U+1F600, to Consolas 5.24 glyph zero.
  This is a fallback/coverage observation before rasterization, not evidence
  that the machine lacks every possible supporting face.
- CJK uses Meiryo UI 6.05; Arabic uses Segoe UI 5.13; Indic uses Mangal 5.91.
- The emoji sequence uses Segoe UI Symbol 5.01, with separate nonzero woman
  and laptop glyphs totaling 36 natural pixels in a two-cell, 20-pixel span.
  Advance-only compression visibly overlaps the glyph ink and neighbor.
- Arabic structural mapping passes while its C lane visibly breaks the natural
  run's order/joining. Neither nine passes nor zero missing sequence glyphs
  establishes acceptable complex-script or composed-emoji behavior.

Log SHA256: `EA7B2FB8EB04440B0675696A8F824357F97E7768FC51FE2EA5BA25DFE94EDDB1`.

Bitmap SHA256: `001808EF9B4F7C38B5B03E0CBC45A37479E862061847B7F43191D0AFFEA929D1`.

This is a supplied target run, not a separate ESU or clean-minimum-image claim.
It motivates the [researched 0.3 changes](../research/2026-09-11-font-coverage-and-fitting.md).

## Package identity

Archive: `artifacts/VT7-renderer-probe-0.2-x64.zip`.

SHA256: `30DAD5D88BE06F9F2C9F989308CF6F95FC1A887F609628FB80E1391D69C83F11`.

Preserved archive SHA256 values:

- Renderer probe 0.1: `C5708911D94F6C6D3C5126B93AF4D70250A22CC658069A6061853CC2845069EF`.
- Atlas backend 0.1: `27CA1C434899BA0D81406342B5F28A92E3AB027DD6F15339907EB23CDB99081B`.
- GDI viewport 0.2.1: `8F8724EDB0D691FD5DC72392476A44D9DF07D0BC6BDDAF59B6353E3466299662`.
