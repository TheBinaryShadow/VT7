VT7 renderer capability and font probe 0.5
================================

This is a Milestone 2 engineering probe, not an Atlas terminal build.
It does not replace or modify the accepted VT7 0.2.1 GDI proof.

Requires Windows 7 SP1 x64 with the documented VT7 graphics/loader/UCRT
prerequisites, including Platform Update KB2670838. This native probe does
not require .NET or Power Automate. Pinned Visual C++ runtime DLLs are bundled.

1. Extract every file to a writable local folder.
2. Run RUN-RENDERER-PROBE.cmd, without elevation.
3. Open VT7-renderer-probe.log.bmp to inspect the font comparison.
4. Send both VT7-renderer-probe.log and VT7-renderer-probe.log.bmp,
   including if the report says failure. If no image was produced, send the log.

The console is expected. The graphics windows are hidden, so no terminal
window will appear. A bitmap comparison is saved beside the log instead.
A run normally takes seconds.
If it hangs, report that separately; the log is written when the run finishes.

PASS/FAIL lines are required baseline checks. CAPABILITY lines are observations:
newer interfaces may return 0x80004002 (E_NOINTERFACE) on Windows 7 as expected.
That is not itself a failed baseline. Review the final "Baseline passed" line.

The probe checks:
- Baseline and optional DXGI, D3D11, DirectWrite, and font-face interfaces.
- Mixed-script text-layout callbacks and in-range cluster indices.
- The unchanged original 0.1 sample, now with retained UTF-16/scalar ranges,
  per-run glyph IDs/advances/offsets, cluster maps, locale/bidi/baseline,
  family/face/version, font file path/hash, and exact missing-glyph clusters.
- Thirteen font/cell fixtures using actual TerminalCore rows, with copied glyph-run
  data used after destroying the layout. Private fonts are bundled in fonts/;
  no fonts are installed into Windows or added to its system font collection.
- Structural mapping oracles and rejection of invalid cluster indices.
- Independent U+1F600 coverage scan of every face in DirectWrite's system
  collection, using HasCharacter and scalar-to-glyph lookup. Candidates include
  font identity and hashes. Errors are counted, never mistaken for no coverage.
- Direct rendering of a confirmed candidate, if found, without layout fallback.
- Pinned Unifont and Unifont Upper 17.0.05, loaded from the executable's fonts/
  directory and checked by SHA256 before DirectWrite reads them. Standalone
  missing symbols/pictographs in the cell lane may use these last-resort faces.
- Private-BMP and Private-SMP explicitly force private C-lane rendering to test
  both fonts even when the system already covers those characters. The N lane
  remains system-only. The BMP symbol is narrow because its core width is one
  cell; private font advances never change the terminal's cell allocation.
- Whole-ink horizontal fitting, including outlines/offsets, and raster bounds.
- Natural-size regular/italic regression checks. Natural runs may use a bounded
  2-pixel ink overhang at this probe's fixed 96 DPI. Their cell allocation does
  not grow. Oversized groups retain strict, zero-overhang whole-ink fitting.
- Pure/mixed/marked Arabic with original shaped RTL runs kept together, plus
  a bijective logical/visual cell projection. This is not glyph hit testing.
- Separate hardware and explicit WARP devices, with no silent substitution.
- An HWND discard/stretch swap chain, Direct2D glyph rasterization, nonempty
  pixel readback, and buffer resize on both devices.

It does NOT prove:
- AtlasEngine runtime compatibility, final glyph placement, or fallback parity.
- Correct pixels on the physical display. Hidden Present is an observation.
- Device recovery, render-thread correctness, long-term stability, or all GPUs.

Font/glyph counts depend on installed fonts. Missing glyphs are reported as an
observation, not hidden or mistaken for complete Unicode support. The current
font experiment uses system layout runs; it is not the final Atlas adapter.

In the bitmap, N is natural DirectWrite layout; C uses a 10-pixel cell allocation
and DirectWrite's visual run order. Original TerminalCore text/cells are unchanged.
LTR clusters are fitted separately; RTL runs stay joined and are fitted as units.
Horizontal compression is allowed, expansion is not.
Natural-size glyphs are preferred when advances fit and ink stays within the
declared 2-pixel overhang; only oversized groups are compressed. This replaces
0.3's strict per-cell squeezing. The log distinguishes cell and damage bounds.
Neither this cell projection
nor proportional RTL ink is a production cursor/selection contract. It is
not a claim of complete bidi or terminal shaping. Compare both rows and report
boxes, clipped/overlapping text, unexpected ordering, and missing characters.

The unchanged original sample and system coverage scan can still report missing
U+1F600: neither uses private fonts. On the tested Windows 7 machine, compare
the Supplementary N lane (system tofu) with its C lane (private fallback glyph).
The bottom explicit-system-candidate check can still be skipped legitimately.
Look for PRIVATE_FALLBACK records and the two forced private C-lane samples.

Fallback scope is deliberately limited to standalone symbol/pictograph scalars
in U+2190..U+2BFF and U+1F000..U+1FAFF, each occupying a complete core cluster/run.
RTL scripts, combining text, ZWJ sequences, and cross-run clusters are not
substituted with raw Unifont glyphs. No composed/color emoji guarantee is made.

All thirteen structural mapping fixtures and drawn horizontal bounds are required.
A mapping failure is reported as MAPPING_UNRESOLVED and fails this new baseline.
Zero unresolved mappings still
does not mean the pixels or shaping policy are accepted. Glyph zero records
identify an associated source cluster, not automatically the underlying cause.

The log includes installed font paths and hashes, not font files. Review paths
before sharing. Only fixed test text is captured, never terminal sessions.

Advanced CLI: VT7.RendererProbe.exe --output "path-to-report.log"
The --inject-required-failure and --inject-font-failure options are for harness testing only; do not use them
for normal acceptance. Reports are overwritten on rerun, so retain earlier runs
separately if useful. No system files, services, drivers, or settings are changed.

VT7 application code is MIT licensed. The bundled fonts use SIL OFL 1.1, not MIT.
See fonts/OFL-1.1.txt, fonts/COPYING, and fonts/README.md for their original
licensing and pinned provenance. Keep the complete fonts/ folder with the EXE.
Missing or wrong-hash fonts fail this diagnostic instead of silently substituting.
See LICENSE.txt, NOTICE.md, and licenses/ for the inherited
core and pinned WIL/GSL/fmt/Chromium provenance.
Microsoft Visual C++ runtime DLLs retain their Visual Studio redistribution
terms and are not relicensed under MIT. SHA256SUMS.txt covers package contents.
