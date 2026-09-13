# Integrated Atlas recovery checks 0.3.2

> Historical validation record. Status and next steps below describe this checkpoint.
> For current work, see the [handoff](../HANDOFF.md) and
> [0.3.5 C3 stability investigation](2026-09-13-atlas-stability.md).

Date: 2026-09-12. Status: Debug and assembled Release tests pass;
the supplied Windows 7 run accepts this bounded recovery slice.
This follows the accepted [0.3.1 repaint/cursor slice](2026-09-12-atlas-repaint.md).
It is a bounded C3 implementation, not completion of Milestone 2 or a session backend.

## Policy

- Default `atlas-auto` requests Direct3D11 hardware. Existing GDI and four forced
  Atlas modes retain their names and explicit device choices. No automatic GDI.
- On eligible hardware device-creation failure, auto mode tries WARP immediately.
  Eligible failures are DXGI unsupported/not-currently-available, device removed,
  reset, hung, driver-internal error and D2D target recreation. Programming errors,
  missing interfaces and out-of-memory are not treated as hardware unavailability.
- One recoverable presentation/device error recreates resources on the same
  driver. Two consecutive recoverable failures without a successful Present
  select WARP in auto mode. The selection stays sticky until surface disposal,
  including later WARP device recreations. Forced modes never switch drivers.
- The inherited controller allows six frame attempts, with five interruptible
  waits of 100/200/400/800/1600 ms. This is a retry bound, not a guarantee that
  an unresponsive driver returns from an API call within a deadline. Initial
  auto fallback can make two device-creation calls during one frame attempt.
- Exhaustion stops painting and reports the last recorded Atlas render HRESULT,
  or E_FAIL if none was recorded. This is not yet complete stage-specific
  provenance for failures elsewhere in the controller; see roadmap POL07.
  Historical transient failures are separate from the fatal surface HRESULT.
  Posted HWND messages update status on successful recovery and terminal failure;
  there is no perpetual status timer or per-frame log.
- Mutable recovery policy is render-thread-owned. Atomic counters expose
  diagnostics; Present never rewrites the concurrently owned Atlas API settings.
  Completed frames/requests advance only after successful Present. Native ABI 5
  extends surface information and adds a capture-only injection entry point.
  Actual mode identifies the last completed backend; before any completed frame,
  it explicitly reports no completed Atlas frame rather than claiming hardware.

## Controlled tests

`RecoveryWindowChecks.cs` operates the actual WPF/native HWND, core, controller,
AtlasEngine, backends and swap chain. Injected creation failures occur immediately
before the selected driver creation call. Injected removal occurs after rendering
and diagnostic readback, immediately before Present. The normal exception/retry,
resource recreation and driver-selection paths handle these errors. The OS and
driver are not modified and no real device is forcibly removed.

`tools/Test-VT7AtlasRecovery.ps1` runs 16 scenarios:

- Auto startup hardware unavailable: exactly one injected failure, two creation
  calls and a completed WARP frame.
- Auto startup both drivers unavailable: seven injected creation failures across
  six frame attempts, no completed frame/device and stable fatal state.
- Forced hardware unavailable: six failures, no WARP substitution.
- Permanent removal in auto and forced D3D WARP: exactly six failed Presents,
  no failed request counted as complete, and retry counters stop after exhaustion.
- Close during retry: wait for the fourth injected removal, then require teardown
  and child disposal within 1500 ms. The worker can observe stop during the
  following backoff; this is not a universal shutdown-latency guarantee.
- One and two removals in auto and each of four forced modes: correct driver,
  expected generation increments, completed nonblank frame and preserved sampled
  core state. Same-driver recreation must also reproduce exact RGB pixels.
  Auto two-removal recovery selects WARP, then a third injected removal verifies
  WARP stays selected. Cross-driver pixels are not required to be identical.

Tests assert production status notifications and actual WARP labeling without
manually refreshing the label. Successful scenarios retain 11 PNGs in total.
Every report identifies requested mode, scenario and injected-error nature;
normal/fatal cases include device generations, creation attempts, failure,
fallback and injection counts plus the original HRESULT.

Each process has a 45-second outer test-runner limit, with fresh-report/capture
and exit-code checks. In-process frame/fatal waits are asynchronous and bounded
to 10 seconds. Expected fatal-state scenarios still return PASS when their
assertions succeed. Existing blank-frame and repaint-mismatch negative controls
retain their expected failing reports and process exits.

## Local validation and target handoff

Development system: NT 10.0.19044 x64, .NET Framework 4.8.9339.0, AMD Radeon
RX 7900 XTX, pinned VS 2022/MSVC 14.44/Windows SDK toolchain.

- Debug and Release builds and binary/import audits pass.
- All 16 recovery scenarios pass in Debug and in the assembled Release package.
  Close during retry measured 6 ms in both recorded final runs, within the test
  bound. Auto fallback reports actual WARP and remains WARP after another removal.
- Six-mode viewport regression passes: 24 lifecycles, 48 tab round trips and
  24 first-frame status checks per configuration, plus the blank-frame negative.
- Four forced Atlas modes pass 128 exact repaint comparisons and 32 cursor-cell
  checks per configuration, plus the expected pixel-mismatch negative.
- Seven core checks and 48 font mappings pass. The assembled package also passes
  four missing/altered-font controls, with source assets unchanged. Evidence is
  retained in `artifacts/vt7/font-asset-negative-e192f430e87447ac9a7b617f2a5fb02d/`.
- Recovery captures were inspected for successful startup fallback and recovered
  core content. These are back-buffer images, not desktop screenshots.

Issued archive: `VT7-atlas-viewport-0.3.2-x64.zip`, 10,408,967 bytes. SHA-256:
`CC7BCDA2CB5FF3D181C4D8DE0F7F07B9291FC901FD4CD2563B33B1834FF8C613`.
Native Release stamp: `Sep 12 2026 02:58:01`, ABI 5. Accepted 0.3.0 and 0.3.1
archives retain their previously recorded hashes and are untouched. The supplied
0.3.1 target logs/captures were preserved before preparing this package.
All 31 payload files match the manifest in both archive and assembled folder,
with no extra files. Release recovery evidence contains 16 reports and 11 PNGs.

Use `artifacts/VT7-atlas-viewport-0.3.2-x64.zip`, extracted into a fresh folder.
Keep accepted archives and earlier evidence. Run:

1. `RUN-DIAGNOSTICS.cmd`.
2. `RUN-VIEWPORT-TEST.cmd` (six modes, now including auto).
3. `RUN-REPAINT-TEST.cmd` (four forced Atlas modes and mismatch negative).
4. `RUN-RECOVERY-TEST.cmd` (all 16 scenarios should PASS).
5. Visible `RUN-VT7.cmd` and `RUN-ATLAS-WARP.cmd` checks as before.

Return `VT7-diagnostics.log`, the complete Logs folder and visible screenshots.
Batch launchers overwrite their own filenames and do not enforce an outer hang
timeout. Preserve partial output and report a hang rather than treating it as a
pass. Report exact Windows servicing tier, driver and display scaling. No separate
ESU or real driver-loss result is inferred from earlier tests or these injections.

## Remaining C3 scope

Following target acceptance, move to settings/font/system-DPI changes and bounded
wait/synchronized-output, idle CPU, resource growth and shutdown stress. Existing
resize/tab/minimize checks are not a substitute for those gates. Real driver-loss,
remote-session and suspend/resume qualification remain separate. Broader error
code/injection-site coverage can be added for a named blocker, not as an open-ended
experiment. Optional typography and cosmetic improvements remain Milestone 7 work.
No new third-party code, font assets or license changes are included.

## Supplied Windows 7 acceptance

The diagnostic captured at 03:04:33 identifies the issued 0.3.2 Release stamp,
ABI 5, Windows NT 6.1.7601 SP1 x64, .NET Framework 4.8.4795.0 and AMD Radeon
RX 6800 XT. All seven core checks and 48 font mappings pass.

All 16 recovery reports pass with expected backend, generation, fallback and
injection counts. Initial hardware unavailability selects WARP. Repeated removal
selects WARP and a third injected removal confirms that selection remains sticky.
Forced modes do not substitute drivers. Exhausted retries stop without counting
failed frames as completed. Closing during retry took 3 ms in this run.

The six viewport modes pass 24 lifecycles, 48 tab round trips and 24 initial
status checks. Four repaint modes pass 128 exact RGB comparisons and 32 cursor
checks; ordered steps, changed pixels and preserved sampled core state were
verified. The deliberate mismatch fails at operation 3, step 1 as expected.
The supplied logs do not independently record process exit codes.

All 32 diagnostic PNGs decode. Normal.PNG and WARP.PNG show the correct visible
hardware/WARP labels, 105 x 21 cells at 9 x 19 pixels and nonzero frame snapshots.
The 42 additional AppData reports contain no unexpected failures; one records
the same intentional repaint mismatch. Exact driver/update inventory and a
separate ESU run are not established by these files. Injected errors are still
not real device-loss evidence, and this does not close all of C3/Milestone 2.

Evidence is preserved in `artifacts/vt7/evidence/atlas-recovery-win7-0.3.2/`.
The follow-up was the [0.3.3 settings/DPI slice](2026-09-12-atlas-settings.md),
whose higher-scale integration failures required correction. The subsequent
[0.3.4 matrix](2026-09-12-atlas-scaling-correction.md) now passes all 16 injected
recovery cases and companion suites at actual Windows 7 96/120/144 DPI.
The subsequent [0.3.5 stability investigation](2026-09-13-atlas-stability.md)
records scheduling/idle/resource/shutdown stress and its open acceptance issues.
These later records do not retroactively broaden the original 0.3.2 evidence or
certify real driver loss.
