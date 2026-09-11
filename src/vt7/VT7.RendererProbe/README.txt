VT7 renderer capability probe 0.1
================================

This is a Milestone 2 engineering probe, not an Atlas terminal build.
It does not replace or modify the accepted VT7 0.2.1 GDI proof.

Requires Windows 7 SP1 x64 with the documented VT7 graphics/loader/UCRT
prerequisites, including Platform Update KB2670838. This native probe does
not require .NET or Power Automate. Pinned Visual C++ runtime DLLs are bundled.

1. Extract every file to a writable local folder.
2. Run RUN-RENDERER-PROBE.cmd, without elevation.
3. Send VT7-renderer-probe.log, including if it reports failure.

The console is expected. The graphics windows are hidden, so no terminal
window or visible text demonstration will appear. A run normally takes seconds.
If it hangs, report that separately; the log is written when the run finishes.

PASS/FAIL lines are required baseline checks. CAPABILITY lines are observations:
newer interfaces may return 0x80004002 (E_NOINTERFACE) on Windows 7 as expected.
That is not itself a failed baseline. Review the final "Baseline passed" line.

The probe checks:
- Baseline and optional DXGI, D3D11, DirectWrite, and font-face interfaces.
- Mixed-script text-layout callbacks and in-range cluster indices.
- Separate hardware and explicit WARP devices, with no silent substitution.
- An HWND discard/stretch swap chain, Direct2D glyph rasterization, nonempty
  pixel readback, and buffer resize on both devices.

It does NOT prove:
- Atlas runtime compatibility, terminal-cell placement, or font fallback parity.
- Correct pixels on the physical display. Hidden Present is an observation.
- Device recovery, render-thread correctness, long-term stability, or all GPUs.

Font/glyph counts depend on installed fonts. Missing glyphs are reported as an
observation, not hidden or mistaken for complete Unicode support. The current
font experiment collects the system layout's runs; it is not an Atlas adapter.

Advanced CLI: VT7.RendererProbe.exe --output "path-to-report.log"
The --inject-required-failure option is for harness testing only; do not use it
for normal acceptance. Reports are overwritten on rerun, so retain earlier runs
separately if useful. No system files, services, drivers, or settings are changed.

VT7 is MIT licensed. See LICENSE.txt, NOTICE.md, and licenses/WIL.txt.
Microsoft Visual C++ runtime DLLs retain their Visual Studio redistribution
terms and are not relicensed under MIT. SHA256SUMS.txt covers package contents.
