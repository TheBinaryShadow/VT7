# Integrated Atlas font/settings and DPI checks 0.3.3

Date: 2026-09-12. Status: Debug, assembled Release and the supplied Windows 7
font/settings matrix pass at measured 96/120/144 DPI. The full 0.3.3 scaling gate
is NOT accepted: viewport and recovery suites fail at both higher scales.
The subsequent [0.3.4 corrective matrix](2026-09-12-atlas-scaling-correction.md)
passes all positive suites at those actual scales. Its bounded scaling checkpoint
is accepted on the supplied Windows 7 setup; 0.3.3's historical failures remain.
This follows accepted [0.3.2 controlled recovery](2026-09-12-atlas-recovery.md).
This records a bounded C3 slice, not a completed renderer milestone or settings UI.

## Implementation boundary

Native ABI 6 adds a 40-byte settings-info structure and a font setter. Surface-info
layout stays unchanged. The proof setter accepts one family, Consolas or Courier
New, integer sizes 6-32 points, and normal/bold weight. Actual family availability
is queried before mutation and the resolved primary name is checked afterward.
This deliberately bounded engineering boundary is not an arbitrary-font/profile
contract. The GDI reference does not implement this setter.

Invalid values are rejected before touching state. Identical settings are a no-op.
The worker is joined outside the core lock before changing Atlas font resources,
cell metrics or capture-dependent values. Under the core lock, the existing
Atlas UpdateDpi/UpdateFont path updates core FontInfo and cell size. UserResize
then reflows the existing buffer without resetting the sample. The renderer is
woken and resumed only if the surface is visible. Unexpected errors after mutation
fail closed and report a fatal status, rather than painting inconsistent metrics.
Transactional recovery from arbitrary allocation/font failures remains outside
this bounded setter. No new shaping, glyph-fitting or fallback policy is adopted.

The system-aware manifest is unchanged. Real system DPI comes from the window DC;
WPF's device transform independently checks that scale. Renderer DPI overrides
96/120/144 are accepted only in capture mode. They never alter Windows settings,
the WPF device transform or the recorded system DPI. Zero override restores use
of actual system DPI. Per-monitor DPI and live system-font installation changes
are not claimed. The visible status now includes system DPI.

The new test exposed a frame-wait race: a wait could return for an older request
while a newer WM_PAINT request remained pending. WaitForRequestedFrameAsync now
requires completion of the latest request observed in its snapshot as well as
the original request. Settings tests settle pending layout/paint messages before
capturing. Existing regression suites protect this shared wait path.

## Test design

Five modes: auto, Direct3D11 hardware/WARP and Direct2D hardware/WARP. Each gets
one real WPF/native window and the normal renderer controller. A fixed fixture
contains a 120-character line to exercise reflow, combining/CJK text, fallback
symbols and styled text. It intentionally has no authored spaces; its source
oracle compares ordered nonblank clusters and effective colors while ignoring
padding. This is not proof of all whitespace, scrollback, selection or cursor
semantics. Existing core/repaint suites retain their separate coverage.

Ten cases cover baseline, size changes, weight changes, Courier New selection,
simulated renderer DPI 96/120/144, and restoration of real-system-DPI Consolas.
For every case:

- Require the requested settings and nonblank completed output. Each nonbaseline
  case must change pixels. Device generation/fallback selection must not change.
- Preserve the fixture's source/color signature through reflow.
- Compare native child client pixels to WPF dimensions transformed to device
  pixels, within 1.1 pixels for layout rounding. Compare the core grid to integer
  client-pixel/cell-size division, including its existing minimum/maximum bounds.
- Reapplying identical settings must not increment generation or request repaint.
- Capture the completed settings frame, force the existing full-redraw path and
  compare every RGB pixel and the sampled core state using the repaint comparator.
  This detects cache/invalidation disagreements, not shared shaping defects.

Restoring baseline must reproduce the original grid, metrics and raster hash.
Eight invalid values must return E_INVALIDARG without changing generation,
requested frame or fatal state. Changing font while hidden must leave the worker
parked; showing it must render with preserved fixture content. A normal tab round
trip then verifies the child HWND, grid and readable diagnostic controls.

Four PNGs per mode retain baseline, Courier New, simulated 144 DPI and restored
baseline, totaling 20 captures. Test logs identify actual system DPI separately
from the renderer override. The existing frame wait has a 10-second asynchronous
bound and the PowerShell runner has a 60-second per-process bound, with fresh
report/capture, expected count, exit-code and failure checks.

Two separate local negatives must fail: a 20-pixel error deliberately added to
the expected WPF width, and a requested system DPI different from the measured
environment. They verify the geometry oracle and prevent a simulated scale from
being labeled a real system-DPI pass. They do not alter Windows or native rendering.

## Local validation

Development environment: Windows NT 10.0.19044 x64, .NET Framework 4.8.9339.0,
AMD Radeon RX 7900 XTX, actual system DPI 96, pinned VS 2022/MSVC 14.44 toolchain.
Debug settings runs pass all five modes and both negatives, including repeated
runs after the frame-wait correction. The assembled Release package passes the
same matrix: 50 settings cases/exact comparisons, 40 invalid-input rejections,
five hidden updates and both geometry/DPI negatives per configuration.
The existing six-mode viewport, four-mode repaint, 16-case recovery, seven core
and 48-mapping font suites pass in Debug and packaged Release. Binary/import
audits and the assembled package's four missing/altered-font controls pass.
Negative font evidence is retained in
`artifacts/vt7/font-asset-negative-536485e9e24d4249a6c1c7c8aa22929a/`.
Courier New and simulated 144-DPI captures were visually inspected; no new
typographic policy was introduced. This establishes only local real 96-DPI host geometry
and simulated renderer-DPI transitions, not actual Windows 7 125/150 percent runs.

Reproduce with `tools/Test-VT7AtlasSettings.ps1 -Configuration Debug` or Release.
Optional `-ExpectedSystemDpi 96`, 120 or 144 asserts the real environment. Reports
and PNGs are under `artifacts/vt7/reports/<configuration>/Settings/`.

Issued archive: `VT7-atlas-viewport-0.3.3-x64.zip`, 10,436,788 bytes. SHA-256:
`32DAC43B8ABAC2389600C8F96418C9E9313571CBB9FD6A51B47DC5A37D5332F0`.
Native Release stamp: `Sep 12 2026 03:24:32`, ABI 6. All 32 payload files match
the manifest in both archive and assembled folder, with no extras. Accepted
0.3.0/0.3.1/0.3.2 archives retain their recorded hashes; no prior package was replaced.

## Original Windows 7 handoff (superseded)

The procedure below describes the issued 0.3.3 build. Its returned font/settings
tests passed at all three actual scales, while higher-scale viewport/recovery
tests failed. Use the [accepted 0.3.4 matrix and reproduction procedure](2026-09-12-atlas-scaling-correction.md)
for current reference; do not repeat 0.3.3 as the current acceptance candidate.

Extract `artifacts/VT7-atlas-viewport-0.3.3-x64.zip` into a fresh directory, keeping
all DLLs/fonts. Accepted 0.3.2 and older artifacts/evidence remain untouched.

1. At the current scaling, rerun diagnostics, viewport, repaint and recovery
   launchers. Preserve the expected repaint mismatch report.
2. Run `RUN-SETTINGS-TEST.cmd`. Choose the scaling actually selected in Windows:
   100 percent (96 DPI), 125 percent (120), or 150 percent (144). All five modes
   should pass. The host rejects a mismatched selection.
3. Run normal and WARP visible launchers. Capture both the viewport and Diagnostics;
   inspect clipping, font baseline/box alignment, text readability, tabs and focus.
4. Repeat the settings suite and visible checks at the other actual Windows 7
   scales. Save work before changing scaling/signing out, and start a fresh Windows
   session/application after the change as required. No tool changes the OS for you.

The launcher names reports `settings-dpi<actual>-<mode>.log`, with four PNGs each,
so different actual scales do not overwrite each other. Another run at the same
scale does overwrite its files. Save screenshots separately per scale and return
the complete Logs folder, diagnostic report, display scale and driver/update tier.
Current-scale results can be reviewed before the other scales are available.
Batch launchers have no outer hang timeout; report hangs with partial output.

Following 0.3.4's accepted target DPI matrix, the next work is bounded synchronized-output,
wait/notify, idle CPU, resource-growth and shutdown stress. Theme/high-contrast,
broader device-loss and other C3 qualification remain open. Non-blocking typography
and visual improvements remain Milestone 7 work. MIT code and existing separate
font/runtime licenses are unchanged; no new assets or third-party code are added.
