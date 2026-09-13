# Atlas scaling correction 0.3.4

> Historical validation record. Status and next steps below describe this checkpoint.
> For current work, see the [handoff](../HANDOFF.md) and
> [0.3.5 C3 stability investigation](2026-09-13-atlas-stability.md).

Date: 2026-09-12. Accepted for the tested Windows 7 SP1 x64 configuration at
actual 100%, 125% and 150% system scaling. Debug and assembled Release also pass.
This is a bounded C3 integration correction, not a new typography experiment or
completion of Milestone 2. No third-party code, font or licensing change.

## Returned 0.3.3 evidence

The three user folders, 100-percent-scaling, 125-percent-scaling and
150-percent-scaling, contain the same Release 0.3.3 native build stamped
Sep 12 2026 03:24:32, ABI 6, Windows NT 6.1.7601 SP1 x64, .NET Framework
4.8.4795.0 and AMD Radeon RX 6800 XT. Settings logs measure system DPI 96,
120 and 144 respectively, independently of the simulated renderer overrides.
No separate ESU inventory or real device-loss event is inferred.
All 387 supplied files are preserved locally under
`artifacts/vt7/evidence/atlas-scaling-win7-0.3.3/`, with the three scale folders
kept separate. These local artifacts are not added to source control.

| Suite | 100% | 125% | 150% |
|---|---:|---:|---:|
| Font/settings modes | 5/5 | 5/5 | 5/5 |
| Viewport modes | 6/6 | 1/6 | 1/6 |
| Differential repaint modes | 4/4 | 4/4 | 4/4 |
| Injected recovery scenarios | 16/16 | 7/16 | 7/16 |

All 150 settings cases, 120 invalid-input cases, 15 hidden updates and 384
repaint comparisons pass. Each scale's deliberate pixel-mismatch control fails
as expected. Shutdown during retry takes 3 ms in each supplied run.

The higher-scale viewport tests fail the first-row ink check after resize.
Nine recovery cases at each higher scale fail the raster dimension assertion
in surface_repaint.inl, before RGB comparison. This does not demonstrate glyph
corruption, but cannot be dismissed as harmless without correction and retest.
The 150% desktop screenshots also show the initial window extending off-screen.
After shrinking the window, the sample's beginning is above the visible viewport;
that observation alone does not establish buffer data loss.

## Corrections and controls

- Initial normal-window bounds are fitted and centered in the nearest monitor's
  work area using Windows 7 MonitorFromWindow/GetMonitorInfo and WPF's device
  transform. Minimum dimensions yield when the work area is smaller. This is
  startup placement, not per-monitor DPI support or ongoing forced sizing.
- Each viewport lifecycle checks the actual native outer rectangle against its
  work area. Pure geometry controls cover 96/120/144 DPI and negative monitor
  origins, explicitly simulations rather than actual system-DPI runs.
- Recovery status is one line with ellipsis and a full-text tooltip. The full
  diagnostic text remains in logs. Long messages cannot increase its height and
  silently shrink the terminal during comparison. Hidden tests check unchanged
  client/raster dimensions at 760 DIPs, then temporarily reinstate the old wrap
  policy as a positive reproduction control. Automatic status refresh is
  suppressed only while this hidden test owns the label, then restored.
- Whole-frame nonuniform pixels replace first-row ink as the known-fixture
  nonblank check. First-row ink remains available separately. A control with a
  blank first row and text below must pass; the injected entirely blank frame
  must still fail. Neither check proves glyph correctness.
- Native ABI 7 exposes whole-frame ink and captured width/height. Surface-info
  grows from 88 to 96 bytes; the managed guard rejects older native DLLs. The
  settings structure remains 40 bytes. Recovery logs before/after client,
  raster, grid, cell size, DPI and frame requests; a dimension mismatch now
  reports both sizes instead of a generic E_UNEXPECTED assertion.
- Same-device recovery retains exact RGB and core-state checks. Cross-device
  fallback still has its distinct core/nonblank contract, but now also requires
  unchanged raster dimensions. Settings checks require raster/client agreement.
- The hidden large-font fixture deliberately opts out of startup fitting to
  retain its bounded test area. It does not certify visible startup placement;
  the separate viewport lifecycle does. Test-driven later resizes remain allowed.

Code inspection identifies wrapping recovery status as a cause of viewport
geometry changes. The old-wrap control reproduces that mechanism locally and
in the returned Windows 7 runs. The corrected runs preserve client/raster sizes
and pass the formerly failing recovery cases. The old 0.3.3 logs do not contain
the old/new sizes, so they cannot retrospectively establish their exact deltas.

## Local validation and issued artifact

Development machine: Windows NT 10.0.19044 x64, .NET Framework 4.8.9339.0,
AMD Radeon RX 7900 XTX, actual system DPI 96. No OS scaling changes were made.
Debug and assembled Release each pass six viewport modes, four lifecycles per
mode, eight tab round trips per mode, the work-area/status controls and twenty
blank-first-row controls across the five Atlas modes. The old-wrap control
reproduces a client height change from 412 to 383 pixels at 760 DIPs; the same
long text leaves geometry unchanged with the corrected single-line policy.

Both configurations pass all 16 injected recovery cases, 128 differential
repaint comparisons, 32 cursor-cell checks, 50 settings cases, 40 invalid-input
rejections and five hidden font updates. Entirely blank frame, altered comparison
pixel, incorrect expected geometry and incorrect expected system DPI controls
all fail as intended. Seven core checks and the 48-mapping font suite pass.
The assembled package also passes four missing/altered-font controls and the
binary/import audits. A Release WARP native viewport capture was inspected.
These local checks do not replace actual Windows 7 high-DPI retesting.

Issued archive: `artifacts/VT7-atlas-viewport-0.3.4-x64.zip`, 10,523,404 bytes.
SHA-256: `9E112F6093FD0FBEEAA2409C655D9FEB7E22340F5823A8141FEE00C49E0A19CA`.
Native Release stamp: `Sep 12 2026 04:22:14`, ABI 7. All 32 payload hashes match
the assembled folder and archive; no extra payload files. Previous 0.3.0 through
0.3.3 archives retain their recorded SHA-256 values. No commit or push was made.

## Accepted Windows 7 retest

Reviewed user folders: `K:/VT7_work/nn/scaling-100/`, `scaling-125/` and
`scaling-150/`. All 424 files are preserved in
`artifacts/vt7/evidence/atlas-scaling-win7-0.3.4/`, keeping those folders separate.
They comprise 99 named test/diagnostic reports, 157 AppData snapshots, 156 native
test captures and 12 desktop screenshots. Raw evidence stays local and ignored
by source control; this record is the shareable acceptance summary.

All reports identify Release 0.3.4, native stamp `Sep 12 2026 04:22:14`, ABI 7
matching the host, Windows NT 6.1.7601 SP1 x64, .NET Framework 4.8.4795.0 and
AMD Radeon RX 6800 XT. Each scale's five settings logs independently measure
96, 120 or 144 system DPI. Renderer overrides remain separately labeled.

| Suite | 100% / 96 DPI | 125% / 120 DPI | 150% / 144 DPI |
|---|---:|---:|---:|
| Diagnostics | Pass | Pass | Pass |
| Font/settings modes | 5/5 | 5/5 | 5/5 |
| Viewport modes | 6/6 | 6/6 | 6/6 |
| Differential repaint modes | 4/4 | 4/4 | 4/4 |
| Injected recovery scenarios | 16/16 | 16/16 | 16/16 |

Across the three actual scales this gives 72 viewport lifecycles, 144 tab round
trips, 72 native startup work-area checks, 60 blank-first-row controls, 48
recovery cases, 150 settings cases, 120 invalid-input rejections, 15 hidden font
updates and 384 differential repaint comparisons. Core/font checks remain green.
Shutdown during retry joins in 3 ms at each scale. The reports establish their
assertions, not independent process exit-code evidence.

Representative automatic present-once recovery geometry is unchanged:

| System DPI | Client and raster before/after | Grid | Primary cell |
|---|---|---|---|
| 96 | 950 x 405 pixels | 105 x 21 | 9 x 19 pixels |
| 120 | 1190 x 480 pixels | 108 x 20 | 11 x 23 pixels |
| 144 | 1427 x 403 pixels | 109 x 14 | 13 x 28 pixels |

Every present-once/twice run preserves its client/raster/grid/cell geometry.
Same-device comparisons retain exact RGB; cross-device fallback retains its
distinct core/nonblank contract. At 760 DIPs, the deliberately restored wrapping
policy changes client height 405 to 378, 480 to 378 and 403 to 310 pixels at
96/120/144 DPI. The corrected single-line policy preserves the dimensions.
Viewport tests also pass when first-row ink is zero but lower-row text is visible.

Each scale's `repaint-negative.log` fails at operation 3, step 1 as intended.
The three matching AppData repaint snapshots are expected. Three other AppData
snapshots report intentionally fatal surfaces, not failed test verdicts:

- 125% `proof-20260912-043809.log`: automatic permanent Present failure,
  six failures, one fallback, HRESULT 0x887A0005.
- 125% `proof-20260912-043813.log`: forced-WARP permanent Present failure,
  six failures, no fallback, HRESULT 0x887A0005.
- 150% `proof-20260912-044229.log`: forced-hardware startup failure,
  no completed frame/device, six failures, HRESULT 0x887A0004.

Their timestamps and counters match the passing canonical recovery reports,
which assert bounded fatal state and stopped retries. There are no unexplained
failures. Entirely blank-frame and wrong-geometry/DPI controls remain local
runner evidence; the packaged launchers do not run those negative cases.

All 12 supplied desktop screenshots were reviewed. Hardware and WARP show the
correct build/backend/DPI. At 150%, the initial title bar and bottom buttons fit
on-screen. Diagnostics remain readable within a scrollable panel. The shorter
14-row viewport shows the lower part of the sample; earlier lines being above
the view is expected scrolling, not evidence of lost glyphs. Screenshots do not
independently certify tooltip interaction or all keyboard behavior.

This closes the bounded corrective system-DPI checkpoint on this setup. It does
not close Milestone 2, establish a separate ESU matrix, identify an exact driver
or servicing inventory, or qualify real driver loss, other GPUs/monitors,
per-monitor DPI, Aero/basic/high contrast, remote/suspend transitions or soak.

## Reproducing the accepted matrix

Use a fresh 0.3.4 extraction and preserve 0.3.3 results. At each actual Windows
scale, 100%, 125% and 150%, run diagnostics, viewport, repaint, recovery and
settings launchers. Select the matching scale in RUN-SETTINGS-TEST.cmd. Save
work before any Windows-required sign-out, and launch a new application after
the scale change. VT7 never changes the OS scale.

Return all logs and captures, including failures. All positive suites must pass;
only repaint-negative.log is expected to fail among the named test reports.
AppData may additionally capture intentionally fatal surfaces as described above. Capture
normal and WARP windows immediately after launch, before manual resizing, and
their Diagnostics tabs. Verify the title bar and bottom buttons fit the screen,
long status remains readable through its tooltip/log, and resize/tab/focus still
work. Missing sample rows in a short viewport are not themselves missing glyphs.

At this checkpoint, the next implementation was bounded synchronized-output
timeout/wait-notify, idle CPU, resource-growth and shutdown stress validation.
The subsequent [0.3.5 stability investigation](2026-09-13-atlas-stability.md)
records that implementation and its open acceptance issues; the
[handoff](../HANDOFF.md) owns current priorities. Theme/high-contrast and broader
renderer qualification remained open at this checkpoint; nonblocking typography
stays in Milestone 7. The issued 0.3.4 archive and assembled package are not
rewritten for documentation updates,
preserving their recorded hashes.
