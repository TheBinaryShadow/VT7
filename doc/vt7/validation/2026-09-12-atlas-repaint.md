# Integrated Atlas repaint checks 0.3.1

Date: 2026-09-12. Status: local Debug/Release checks pass; supplied Windows 7
evidence accepts this bounded repaint/cursor slice on the tested configuration.

This is the first bounded C3 slice following the accepted
[0.3.0 C1/C2 viewport](2026-09-12-atlas-viewport.md), not completion of C3 or
Milestone 2. Font policy, upstream shaping, presentation and session scope are
unchanged. Optional typography remains deferred.

## Test design

`surface_repaint.inl` and `RepaintWindowChecks.cs` operate the actual native
HWND, TerminalCore, renderer controller and AtlasEngine. There is no separate
software rasterizer or synthetic glyph payload in this comparison.

At each of two window sizes, 16 cases comprise a baseline followed by ASCII
overwrite, bold/italic/underline and foreground/background styling, a combining
overwrite, wide-character insertion/replacement, character insertion, character
and line erasure, region scrolling, alternate-screen entry/restoration, and
block-cursor show/move/underline/hide transitions.

1. Apply VT input under the core lock. Wake the controller without issuing
   WM_PAINT or forcing full invalidation. Normal core/Atlas invalidation decides
   which cached rows must be rebuilt.
2. Wait asynchronously for the requested completed frame, then retain its owned
   CPU raster and visible source/effective-color/grid/cursor snapshot.
3. Force `InvalidateAll` through the real controller without changing the core.
   Wait for that full redraw and compare every RGB pixel, ignoring alpha.
4. Require unchanged sampled core state and a visible pixel change for each edit.
   Cursor-only changes must stay within the independently expected old/new core
   cell rectangles. Cursor blinking is disabled for deterministic tests.

The Windows 7 presentation adapter still redraws/presents a complete back buffer.
Here, incremental means ordinary terminal row/cache invalidation, not partial
swap-chain presentation or adoption of dirty-rectangle optimizations. The full
reference uses the same renderer, fonts and device, not another backend whose
antialiasing may legitimately differ. This detects invalidation disagreements,
not shared shaping defects present in both paths.

The negative control flips one RGB pixel in the retained CPU comparison image.
It must fail specifically with `Atlas differential repaint mismatch`. It tests
the comparator and failure route, not hardware corruption or device-loss recovery.
Four diagnostic PNGs per backend retain wide-text and block-cursor cases at both
sizes. Geometry is checked numerically as well as by capture inspection.

## Status-label correction

0.3.0 could show `paints 0` before asynchronous presentation and retain that
snapshot indefinitely. 0.3.1 schedules a bounded refresh after layout/reset,
waiting for a completed request, and labels the result `frames (snapshot)`.
It does not force a paint, run a perpetual timer, or write a log per frame.
Pending refreshes stop on close or superseding layout requests. The ordinary
viewport smoke test now requires the initial nonzero completed-frame label.

Native ABI 4 adds a diagnostic-only ordered repaint-check entry point. It is
rejected without Atlas and capture mode. Existing surface-info layout is unchanged;
the version guard prevents accidentally mixing this host with the accepted ABI 3 DLL.

## Local results

Development system: Windows NT 10.0.19044 x64, .NET Framework 4.8.9339.0,
AMD Radeon RX 7900 XTX. Same pinned VS 2022/MSVC 14.44/SDK toolchain as 0.3.0.

- Debug/Release builds and binary/import audits pass.
- Both Atlas backends on hardware and WARP pass: 32 exact comparisons and eight
  cursor-cell checks per mode. That is 128 comparisons and 32 cursor checks per
  build configuration, including baseline frames.
- The intentionally altered comparison image fails as expected.
- The five-mode viewport regression matrix, core/font checks, tab/lifetime tests,
  first-frame status checks and blank-frame negative pass in both configurations.
- Captures were inspected for the wide-text edit and the block cursor on its
  expected blank cell. The final package reruns tests with its app-local runtime.

Reproduce with `tools/Test-VT7AtlasRepaint.ps1 -Configuration Debug` or `Release`.
Reports and PNGs are under `artifacts/vt7/reports/<configuration>/Repaint/`.
Each test process has a 60-second limit; each requested frame has a 10-second
asynchronous wait limit. The test runner requires fresh reports, expected backend,
case count, captures, exit status and the specific negative failure marker.

## Target handoff

Package: `artifacts/VT7-atlas-viewport-0.3.1-x64.zip`. The accepted 0.3.0 archive
and its evidence remain untouched. Extract into a fresh folder with all fonts/DLLs.

1. Run `RUN-DIAGNOSTICS.cmd` and `RUN-VIEWPORT-TEST.cmd` for regressions.
2. Run `RUN-REPAINT-TEST.cmd` for the new matrix. Preserve the entire `Logs`
   folder, including its deliberately failing `repaint-negative.log`.
3. Open hardware and WARP visible launchers. Check that the frame snapshot becomes
   nonzero after startup and remains readable. Return screenshots and logs.

The new tests do not need a shell/session or system changes. Batch launchers have
no hang timeout and overwrite their own output names, so retain prior evidence.
The returned Windows 7 results are recorded below.

Issued archive: 10,389,393 bytes. SHA-256:
`6101C9E65B625A550697F8E05C612195F776E50D4256166D3EF2772B7D185929`.
Native Release stamp: `Sep 12 2026 02:23:12`, ABI 4.
All 30 payload files match the manifest inside both the zip and assembled folder,
with no extra payload. Assembled-package regression/repaint suites and four
missing/altered-font controls pass. Negative font evidence is retained in
`artifacts/vt7/font-asset-negative-aa34a2292d574c83ba9336ea6b9d31cd/`.
The accepted 0.3.0 archive retains SHA-256
`BA2499B3E1C6C8C4ED666E7961A68C064298C5E06267D140C060C924A2553AF7`.

## Remaining C3 work

Following target acceptance of this slice, extend the integrated corpus
where needed for overhang/clipping and viewport edges, settings/font/system-DPI
changes, automatic hardware fallback, recoverable failures, synchronized-output
and wait/teardown races, idle CPU and resource-growth measurements. The two
window sizes here are not two DPI configurations. No universal glyph, all-cursor-
style, long-running stability or device-loss claim follows from these tests.

## Supplied Windows 7 acceptance

The returned diagnostic captured at 02:34:22 identifies native 0.3.1, ABI 4,
stamp `Sep 12 2026 02:23:12`, Windows NT 6.1.7601 SP1 x64, .NET Framework
4.8.4795.0 and AMD Radeon RX 6800 XT. All seven core and 48 font checks pass.
The five viewport modes pass 20 lifecycles, 40 tab round trips and 20 first-frame
status checks. Four Atlas repaint modes each pass 32 exact RGB comparisons and
eight cursor-cell checks, totaling 128 and 32. Both sizes contain steps 0-15
twice overall per mode, with changed pixels for every edit and unchanged sampled
core state. Target grids are 105 x 28 and 74 x 13 cells.

The supplied negative report fails at operation 3, step 1 with the expected
`Atlas differential repaint mismatch` marker. Its process exit code is not
independently recorded in the supplied logs. All 20 PNGs are present. Inspected
wide-text and block-cursor captures agree with the numerical checks. No new
desktop screenshot or independent ESU/update-inventory claim is made here.

Preserved local evidence: `artifacts/vt7/evidence/atlas-repaint-win7-0.3.1/`,
containing the diagnostic and complete returned Logs folder (10 logs, 20 PNGs).
The follow-up was the [0.3.2 controlled recovery slice](2026-09-12-atlas-recovery.md).
The later [0.3.4 corrective matrix](2026-09-12-atlas-scaling-correction.md) accepts
the same bounded repaint corpus and companion suites at actual Windows 7
96/120/144 DPI. This is still not completion of C3 or Milestone 2; bounded
scheduling/idle/resource/shutdown checks are next.
