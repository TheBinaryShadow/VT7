# Atlas scheduling and stability 0.3.5

Status: implemented investigation candidate, not stability-accepted. Local
hardware passes 100 lifecycles, but WARP fails the resource-growth budget.
Supplied Windows 7 quick checks and the hardware lifecycle profile pass; WARP
also fails the resource budget on Windows 7. No soak was run. The
[0.3.4 scaling result](2026-09-12-atlas-scaling-correction.md)
remains accepted and its issued artifact is preserved. This is a bounded C3
slice, not Milestone 2 completion or interactive-session support.

## Implementation

- Read renderer timer deadlines under the same core lock used for timer changes
  and ticks. Release it before the event wait. Preserve remembered auto-reset
  redraw wakes and the upstream 100 ms synchronized-output timeout.
- Pause/acknowledge the worker on hide rather than terminating it. Final close
  pauses rendering, completes `DestroyWindow` on the HWND owner, then runs
  graphics cleanup on the presentation worker and joins it before deleting the
  surface. Assert that tab returns keep one worker start per surface.
- ABI 8 adds scheduling counters and capture-only fixture commands. Commands
  belong to the HWND owner thread; two diagnostic notification producers are
  joined before return. No asynchronous callback may retain a destroyed surface.
- Exercise explicit sync end, split DECSET 2026 with missing-end timeout, core
  marker integrity and exact same-device full-redraw comparison.
- Exercise parked redraw and one-shot timer wakes, timer arm/cancel pairs,
  hidden pending output, and disposal from parked, active, hidden and sync-waiting
  states. Existing controlled-recovery tests cover close during retry separately.

## Profiles and budgets

`tools/Test-VT7AtlasStability.ps1` runs forced D3D11 hardware and WARP sequentially.
It rejects wrong exit codes, missing/stale reports, missing evidence markers and
reported failures. Quick mode also injects an unwanted redraw during idle and
requires that the idle invariant fails. D2D modes retain their existing tests;
this scheduling/stress matrix does not qualify D2D stability separately.

| Profile | Coverage per backend |
| --- | --- |
| Quick, default | Two warm-up windows, then 8 lifecycles, 80 resize operations, 40 tab round trips, sync/timer/wake and 2-second visible/hidden idle checks. |
| `-Lifecycle` | Same scheduling checks plus 100 lifecycles, 1,000 resize operations and 500 tab round trips; no timed soak. |
| `-Soak` | Full lifecycle profile, then at least 30 minutes changing content/size, 10 minutes unchanged visible idle and 10 seconds hidden idle. |

Recorded diagnostic investigation budgets, not production performance promises:

- Idle: zero extra presents or renderer calls, at most one redundant wait,
  process CPU at most 5% of one logical CPU with cursor blink disabled.
- Missing sync end: exactly one timeout, reset mode, observed completion between
  80 and 3,000 ms. Explicit end must not consume the timeout path.
- Close: at most 2,000 ms. The external runner has separate process deadlines
  of 5/15/60 minutes for quick/lifecycle/extended modes and retains progress logs.
- Post-warm-up growth: at most 64 MiB private bytes, 32 process handles,
  8 threads, 16 GDI and 16 USER objects. Collect at repeated checkpoints after
  managed finalization and queued dispatcher cleanup. Investigate continuing
  growth even below the hard limits; passing a short run does not prove no leak.
  Collect all four lifecycle checkpoints even after crossing a budget, then
  fail the overall profile. A separate +512 MiB/+2,048-handle safety ceiling
  aborts excessive growth early. Neither mechanism relaxes the acceptance limits.
- Report request-to-observed-completion median/p95/max from lifecycle frames.
  These include diagnostic readback and polling, not GPU frame time or input
  latency. Direct GPU-memory accounting is unavailable and is not inferred from
  process private bytes. Timed-soak resource samples are recorded every minute.

## Local lifetime investigation

The first full Debug run failed its handle budget at cycle 50: approximately
one event handle remained per window. A temporary local handle-type census
identified named `DwmDxBltEvent_*` objects. Repeated core and graphics capability
probes did not grow handles; raw native surfaces without WPF HwndHost did.
Excluding Windhawk did not remove the reproduction; the corrected fresh VT7
process was separately checked and had no Windhawk module loaded.

A small local DXGI-only control isolated the ordering on the development
Windows 10 build 19044 / Radeon RX 7900 XTX setup:

| Control, 60 window lifecycles | Process handles at cycles 10 through 60 |
| --- | --- |
| Single-threaded creation/presentation/destruction | 155 throughout |
| Matching VT7 device flags and window association, single thread | 152 throughout |
| Present on worker, exit worker before destroying HWND | 160, 170, 180, 190, 200, 210 |
| Release graphics on worker but still destroy HWND after worker exits | Same continuing growth |
| Keep worker alive through HWND destruction, then release/exit | 150 throughout |
| Same corrected ordering, WARP | 145 throughout |

This is local experimental evidence, not a universal DXGI implementation claim
or Windows 7 acceptance. Earlier explicit backend/context destruction and
window-association cleanup alone did not cure the growth. The actual correction
retains the worker across hides and native-window destruction. Clearing bindings
and flushing deferred graphics releases follows Microsoft's
[D3D11 Flush guidance](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/nf-d3d11-id3d11devicecontext-flush).
Temporary handle census code is not part of the distributable. The minimal
reproducer and logs are retained locally under `artifacts/vt7/diagnostics/`.

## Local results and unresolved WARP growth

Development environment: Windows 10 build 19044 x64, .NET Framework 4.8.9339.0,
Radeon RX 7900 XTX, actual system DPI 96. These are not Windows 7 results.

The corrected Debug build passes import verification, core/platform diagnostics,
six viewport modes, repaint comparisons and negatives, all 16 controlled recovery
scenarios, five settings modes and negatives, both missing/altered-font controls,
and quick hardware/WARP scheduling checks including the idle negative control.
The final assembled Release package passes the same regression suites and quick
profiles, app-local runtime/import verification and font integrity checks.
Four malformed stability-option combinations are rejected with exit code 2.
The timed active/idle soak has not been run locally.

Debug and Release hardware runs pass 100 measured lifecycles, 1,000 resizes and
500 tab round trips. Named per-window DXGI event retention is corrected. WARP
still crosses the investigation budget. The full Debug series retained after
the fix is:

| Closed-state checkpoint | Private bytes | Handles | Threads | GDI | USER |
| --- | ---: | ---: | ---: | ---: | ---: |
| After 2 warm-up windows | 129,712,128 | 912 | 45 | 6 | 16 |
| Cycle 25 | 150,704,128 | 953 | 48 | 6 | 33 |
| Cycle 50 | 165,318,656 | 977 | 48 | 6 | 43 |
| Cycle 75 | 162,750,464 | 989 | 48 | 6 | 47 |
| Cycle 100 | 165,015,552 | 995 | 46 | 6 | 48 |

WARP completed all operations without a rendering mismatch or hang, with a
worst close of 10 ms, but the overall result is **failed** at four resource
checkpoints. Resource growth slows but is not established as bounded; neither
harmless initialization nor a particular WARP/OS defect has been proved. A
temporary census saw additional I/O-completion handles, not the original named
DXGI events. Process-owned helper-window class counts stayed unchanged. This
does not establish the type or owner of the additional USER objects.

The two-window warm-up and all investigation budgets remain unchanged. Keep
this issue in C3 stability, not optional polish. The supplied Windows 7 comparison
below also fails. Isolate continuing growth or establish a repeatable plateau
with evidence. A quick pass cannot override this full-profile failure.

Local reports: `artifacts/vt7/reports/Debug/Stability-lifecycle/` and
`artifacts/vt7/reports/Release/Stability-lifecycle/`. Earlier failing controls
are also retained under `artifacts/vt7/diagnostics/pre-fix/`. Artifact folders
are local ignored evidence, not checked-in qualification results.

## Supplied Windows 7 comparison

The eight reports supplied from `K:/VT7_work/0.3.5/Logs/` are preserved with
matching hashes under `artifacts/vt7/evidence/atlas-stability-win7-0.3.5/`.
They identify Release 0.3.5, ABI 8, Windows 7 SP1 x64, .NET Framework 4.8.4795.0,
Radeon RX 6800 XT and measured system DPI 96. They do not independently establish
the ESU tier, driver version or archive hash. The user explicitly ran only the
quick and lifecycle launchers, not the timed soak or other regression launchers.
Embedded platform/core/font checks are present in all four final reports.

| Profile | Hardware | WARP |
| --- | --- | --- |
| Quick, 8 measured lifecycles | Pass | Pass |
| Full lifecycle, 100 measured lifecycles | Pass | Resource-budget failure |
| Timed active/idle soak | Not run | Not run |

Both full profiles completed 1,000 resizes and 500 tab round trips without
rendering mismatches or hangs. Worst close was 7 ms hardware and 8 ms WARP.
Short visible/hidden idle samples report zero extra presents, renderer calls or
waits, and zero measured CPU at the report's resolution. These are short
diagnostic samples, not proof of zero CPU use over an extended interval.

Hardware final growth was +5,324,800 private bytes, +13 handles, +3 threads,
unchanged GDI and +1 USER object, within all unchanged budgets. WARP's series:

| Checkpoint | Private bytes | Handles | Threads | GDI | USER |
| --- | ---: | ---: | ---: | ---: | ---: |
| Warm-up | 121,307,136 | 1,368 | 48 | 18 | 45 |
| 25 | 131,813,376 | 1,390 | 59 | 18 | 57 |
| 50 | 129,740,800 | 1,394 | 59 | 18 | 57 |
| 75 | 134,811,648 | 1,403 | 59 | 24 | 66 |
| 100 | 135,729,152 | 1,411 | 59 | 24 | 66 |

WARP first fails the +8-thread budget, already +11 at cycle 25. At cycle 75 it
also exceeds +32 handles and +16 USER objects. Additional process-owned helper
windows appear at that checkpoint: two `CiceroUIWndFrame`, one
`CicMarshalWndClass` and one `MSCTFIME UI`. Their appearance is an attribution
clue, not proof they explain all growth. The failure is not exclusive to the
Windows 10 development machine; its precise cause still needs isolation. Keep
the soak on hold while investigating. No C3 stability gate is closed by this run.

## Follow-up resource isolation, development machine only

These controls run on the Windows 10 development setup, not Windows 7. They
are not substitutes for the full scheduling profile. The managed controls use
two warm-up cycles, then 100 measured create/resize/hide/close cycles, except
the explicit 300-cycle control. Native-child controls check frame completion
and source markers, not the complete integrated pixel/synchronization suite.
Resources are sampled after dispatcher cleanup and managed finalization, with
a further sample after ten seconds closed. All existing budgets are unchanged.

| Control | Handles, warm-up to cycle 100 | USER, warm-up to cycle 100 | Result |
| --- | --- | --- | --- |
| Plain WPF window, no terminal surface | 872 to 873 | 12 to 12 | Within budget |
| WPF parent, direct native child, no HwndHost | 877 to 953 | 12 to 41 | Fails |
| WPF parent and TerminalSurface HwndHost | 877 to 965 | 12 to 46 | Fails |
| WPF software-only rendering, direct WARP child | 353 to 439 | 12 to 44 | Fails |
| WPF application, stock native parent instead of showing WPF window | 306 to 315 | 8 to 9 | Within budget |
| Explicit layered/transparent WPF parent, direct WARP child | 1,388 to 1,468 | 12 to 41 | Fails |

A separate native-only executable exercises the actual Release VT7 native
surface with a stock layered parent. Its 100-cycle WARP run keeps 169 handles
and 4 USER objects from warm-up to the final checkpoint. Repeating graphics
probes between cycles also stays flat at 170 handles and 4 USER objects.
This control has no managed application, so it is supporting isolation evidence,
not an otherwise identical comparison. The layered WPF control above checks
one presentation-style difference; it does not cure the growth.
The managed stock-parent control also keeps its native parent at 1,000 x 800
while the shown WPF parent is resized. Both resize the native child. This
matrix implicates the shown-parent environment, but does not independently
separate parent resizing from WPF composition or establish allocation ownership.

The extended bounded control still grows between cycles 100 and 300: handles
969 to 995, USER 46 to 50. After ten seconds closed it retains 995 handles and
50 USER objects. Growth slows, but this is **not a demonstrated plateau**.
Private bytes fall after the windows close in these controls, while the extra
handles and USER objects remain. This is not evidence of equivalent GPU-memory
usage, nor a reason to widen the budgets.

### Input queues and IME control

Optional checkpoint diagnostics dynamically resolve Microsoft's documented
[thread-start query](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntqueryinformationthread).
Unavailable attribution does not create a new rendering dependency. Origins
are logged as module basenames plus offsets, not private absolute paths. A
thread-pool start address does not identify its current callback or allocation
owner. The read-only
[GetGUIThreadInfo](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getguithreadinfo)
query checks only this process's nonzero thread IDs. Success establishes that
the thread has an input queue; it does not identify who requested it.

The normal-input direct-child repeat produced:

| Checkpoint | Handles | USER | Native pool threads with input queues | Total native pool threads |
| --- | ---: | ---: | ---: | ---: |
| Warm-up | 877 | 12 | 2 | 35 |
| 25 | 921 | 29 | 18 | 36 |
| 50 | 939 | 36 | 25 | 36 |
| 75 | 945 | 37 | 26 | 36 |
| 100 | 953 | 40 | 29 | 36 |

One additional CLR-start thread also gains an input queue. The USER increase
matches the increase in queue-bearing threads at these checkpoints. This
supports a lazy per-thread initialization hypothesis, not proof of a harmless
upper bound or proof that WPF, WARP, or a third-party module owns every object.
The run still fails its handle and USER budgets.

A temporary process-local IME-disable control, called before WPF startup,
kept USER at 6 throughout 100 cycles but still grew from 877 to 967 handles.
It failed the handle budget at all four checkpoints. The experiment implicates
the input subsystem in the USER component, but does not solve handle retention.
That code and its command-line case were removed after the experiment. VT7
retains normal IME behavior; disabling multilingual input is not a product fix.
No WARP worker-thread suppression or accessibility disablement was adopted.

### Environment and next decision

The user confirms ESET is active on both development and Windows 7 machines.
`ebehmoni.dll`, described as ESET Deep Behavioral Inspection Monitor, was
observed in both a failing integrated development run and the flat native-only
control. Its presence alone does not explain the difference. No ESET setting
had been changed for those initial controls. The earlier fresh
Windhawk-excluded reproduction remains recorded separately above.

The user then temporarily added only
`D:/Git/VT7/artifacts/vt7/bin/Debug/VT7.Host.exe` to ESET HIPS Deep Behavioral
Inspection exclusions. A fresh process ran the identical normal-input
`native-child` WARP control, with no rebuild, two warm-up cycles and 100 measured
cycles. Loaded-module snapshots at 3.09 and 50.13 seconds contained neither
`ebehmoni.dll` nor a Windhawk-named module. The runner did not change security
settings or independently inspect the exclusion configuration.

| Checkpoint | Private bytes | Handles | Threads | GDI | USER | Native pool threads with input queues |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Warm-up | 121,278,464 | 871 | 49 | 6 | 12 | 2 |
| 25 | 151,293,952 | 915 | 51 | 6 | 29 | 18 |
| 50 | 153,206,784 | 937 | 51 | 6 | 37 | 26 |
| 75 | 154,611,712 | 947 | 51 | 6 | 40 | 29 |
| 100 | 155,811,840 | 959 | 48 | 6 | 45 | 34 |
| Ten seconds closed | 107,536,384 | 959 | 48 | 6 | 45 | 34 |

All 100 cycles complete, but the process exits 1 with four resource-budget
failures. Final growth is +88 handles and +33 USER objects. As in the earlier
control, the USER delta matches +32 native pool threads and +1 CLR-start thread
gaining input queues. The reproduction persists with ESET's in-process
inspection module absent from both samples. This does not rule out every ESET
component or external interaction, but does not support that module as a
necessary cause of this failure. No broader security exclusion is justified by
this result. The comparison process exited, and the user was asked to remove
the temporary exclusion. The user subsequently confirmed its removal. Security
settings were not independently inspected or changed by the diagnostic runner.

The host and native DLL hashes were unchanged before/after the run:

- Host: `E1712FF31C32803464C44E4B0A253D830E19A3DC1D167D1A69BEC825E9EBB7CC`.
- Native: `0CDCA6ABA58C4C0CE6F206B8FF99B1F6BF66D6AB82EFC3C7AA51547962FB0919`.

Reports are `isolation-native-child-eset-excluded.log` and `.progress.log` in
the diagnostic evidence directory. The accompanying `.log.context.json`
records arguments, hashes, exit status and module snapshots. This remains a
local Debug isolation result, not Release or Windows 7 qualification. No soak
was run and no production behavior was changed for the comparison.

The process-only tracing and native notification replay below provide the next
attribution evidence. Lifetime/boundedness still need verification; this is not
another font or visual-polish exercise. Review found no direct sampler handle leak or mechanism
that runs code on the enumerated threads. Resource totals and thread attribution
are sampled sequentially, not atomically; first-use diagnostic initialization
may appear at a later checkpoint and must remain a measurement caveat.
Do not raise the warm-up count, suppress WARP workers, disable IME, or mark the
gate passed merely to accommodate unexplained growth. A resulting correction
or justified initialization model still needs the unchanged integrated profile
on both machines before the timed soak.

### Process-only handle traces and native notification replay

The installed x64 SDK debugger was used with Microsoft's
[user-mode handle tracing](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-htrace).
Only the fresh VT7 process was traced. No registry/AppVerifier configuration,
system-wide ETW collection or security-setting change was made. The user had
confirmed removal of the temporary HIPS exclusion before these runs.

The first attempt completed the workload but missed its checkpoint breakpoint
and failed to open the exit-command file. The paused test and its debugger were
stopped; `handle-trace-cdb.log` is retained as an incomplete trace, not attribution
evidence. The corrected script uses the debugger's `VT7_Native` module alias
and inline exit commands. `handle-trace-cdb-v2.log` captures the checkpoints
and records handle tracing disabled before normal process/debugger exit.

The baseline capture is at the third native-surface creation, after two warm-up
cycles and after the next parent has already been created. The post-25 capture
likewise occurs with the next parent already present. These are not the exact
closed-state resource-budget sampling points. Debugging also changes timing
and thread-pool population. Treat these as attribution, not acceptance runs.

The current handle tables show 9 `IoCompletion` handles at baseline and 21 at
the post-25 capture. All 12 additional handle values match outstanding OPEN
records in the first complete trace difference:

- Eleven originate in `win32u!NtUserMessageCall`, reached through
  `USER32!fnPOWERBROADCAST`, `SendNotifyMessageW`, `PowerNotificationCallback`,
  `powrprof!PowerpSettingCallback` and `ntdll!RtlpWnfWalkUserSubscriptionList`.
- One originates in `win32u!NtUserPostMessage`, reached through
  `USER32!PostMessageW` and `WindowsBase_ni` frames.

This identifies Windows message delivery as the allocation path for those
handles, not a direct VT7 completion-port allocation. The returned power-
notification registration token is not the same object as an internal
`IoCompletion` handle. At process exit, the current table contains 28
`IoCompletion` handles. The final history difference exceeds the trace buffer's
coverage and is explicitly unavailable. Do not infer complete open/close
histories or uninterrupted lifetime from reused numeric handle values.

The monitored GUID is `GUID_MONITOR_POWER_ON`. Microsoft's
[registration API](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerpowersettingnotification)
delivers window-targeted power messages, and registrations are paired with
[unregistration](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-unregisterpowersettingnotification).
Current [WPF HwndTarget source](https://github.com/dotnet/wpf/blob/main/src/Microsoft.DotNet.Wpf/src/PresentationCore/System/Windows/InterOp/HwndTarget.cs)
uses a thread-static shared notification-window helper, created for the first
attached target and disposed after the last detaches. Reflection-only metadata
and IL inspection of the installed `PresentationCore.dll` 4.8.9346.0 independently
confirmed the same GUID, helper, registration, unregistration and HWND disposal
structure. No WPF objects were created during that inspection. Current source
alone is not treated as proof of the installed Framework implementation.

A native-only paired control then uses one persistent native parent and the
actual Release 0.3.5 native DLL, with two warm-up and 100 measured Atlas WARP
surface lifecycles. The power case adds one matched registration/unregistration
per cycle and processes incoming messages. The plain case omits only that
subscription. This is an OS API stress control, not a literal WPF-host replay.

| Checkpoint | Plain handles / USER | Power handles / USER | Power native pool threads with input queues |
| --- | --- | --- | ---: |
| Warm-up | 165 / 4 | 169 / 6 | 2 |
| 25 | 165 / 4 | 203 / 23 | 19 |
| 50 | 165 / 4 | 225 / 34 | 30 |
| 75 | 165 / 4 | 231 / 37 | 33 |
| 100 | 165 / 4 | 235 / 39 | 35 |
| Ten seconds closed | 165 / 4 | 235 / 39 | 35 |

The power case reports 102 successful registrations, 102 successful
unregistrations and 102 delivered notifications. Its post-warm-up increase is
exactly +66 handles and +33 USER objects alongside +33 queue-bearing pool
threads. Both cases keep GDI at zero. The plain case's native pool threads do
not acquire input queues during these samples. ESET's monitor was observed
loaded in both normal, non-debugger processes; no Windhawk-named module was
observed. Both complete their measurements, which is not a resource-budget pass.

This reproduces the growth without WPF and strengthens the per-thread Windows
notification/input-queue initialization explanation. It does not yet prove a
safe upper bound, account for every integrated-process resource, or establish
the same behavior on Windows 7. Do not disable power notifications or change the
application's WARP/IME policy to hide this result. The subsequent target
power/plain comparison is recorded below: Windows 7 grows in both modes, so the
development machine's power-specific explanation cannot be transferred unchanged.
A justified lifetime/boundedness model and integrated stability profiles remain
open.

Evidence: `raw-atlas-power-comparison.log`, `raw-atlas-plain-comparison.log`,
`isolation-native-child-htrace-v2.log` and its progress file, and the corrected
debugger trace, all under `artifacts/vt7/diagnostics/`. The raw control source
is `raw-atlas.cpp`. No existing VT7 application binary or issued archive was
changed during the tracing/replay work.

### Reproduction and retained evidence

The current source adds `--stability-test --renderer atlas-d3d-warp
--resource-isolation <case> --diagnostics-output <absolute-log-path>`.
Supported cases are `wpf`, `native-child`, `hwndhost`,
`native-child-software`, `native-parent`, `native-child-layered` and
`native-child-plateau` (300 cycles, not a claim that a plateau exists).
Explicit D3D hardware is also accepted for comparison. These controls reject
combination with lifecycle, soak or failure-injection profiles and are absent
from the already-issued 0.3.5 archive. Normal application startup is unchanged.

Local evidence is under `artifacts/vt7/diagnostics/`: `isolation-<case>.log`
and matching `.progress.log`, the additional
`isolation-native-child-input-queues.log`, removed-control
`isolation-native-child-noime.log`, `raw-atlas-warp.log`,
`raw-atlas-warp-probes.log`, and `raw-atlas-module-control.log`.
The native-only reproducer is `raw-atlas.cpp` in that same ignored directory.
The managed isolation controls remain source-only. A separate native comparison
package is documented below. The accepted 0.3.4 and issued 0.3.5 archives remain
unchanged.

The retained diagnostic source builds in Debug and passes import verification,
core/platform checks, all six viewport modes, the blank-frame negative, quick
hardware/WARP scheduling and the idle-negative control. Four malformed or
removed isolation-option combinations return exit code 2. These are fresh Debug
checks, not a rebuilt Release package or Windows 7 qualification of the new
thread-attribution code. Archive SHA256 values below were rechecked unchanged.

## Issued investigation artifact

- Build: 0.3.5 Release x64, native ABI 8, pinned MSVC 14.44.35207.
- Archive: `artifacts/VT7-atlas-viewport-0.3.5-x64.zip`, 10,541,563 bytes.
- SHA256: `57B2EE43BB9A1AC6AB227B7C7BE4E3FCB88C765753FDEDD988E14EF375604C86`.
- All 35 manifest-listed files were checked both in the assembled directory
  and directly inside the archive. The package includes quick, bounded-lifecycle
  and timed-soak launchers. Its README explicitly records the open WARP failure.
- Packaging gates on existing regressions and quick stability, not the full
  lifecycle/soak gate. The artifact is for comparison, not release acceptance.
- Accepted 0.3.4 remains unchanged, SHA256
  `9E112F6093FD0FBEEAA2409C655D9FEB7E22340F5823A8141FEE00C49E0A19CA`.

## Native resource comparison 0.1

- Archive: `artifacts/VT7-resource-comparison-0.1-x64.zip`, 2,938,282 bytes.
- SHA256: `16A058CE3AA41D9D6829F1ACC357CE0CD4CC9128DE04F12D2F8914B16198118D`.
- All 23 manifest-listed payload hashes were checked in the assembled directory
  and directly inside the archive. The archive contains 24 files including
  `SHA256SUMS.txt`, with local test logs excluded.
- Control SHA256: `F95C0183979B49488C19BE22C67419A88F9521B2FCCA66B4A02CD117F4C2DD1C`.
- Issued native DLL SHA256: `0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49`.

This separate investigation package contains the standalone native control, not
the WPF application. Its native DLL, three app-local MSVC runtimes, fonts and
legal/provenance files are byte-identical to the issued 0.3.5 payload. The control
source and ABI header are included as provenance copies. Neither existing
viewport archive is replaced. No security, input or power-policy setting is
changed by the control.

The five native images pass the existing x64, PE-version and forbidden-import
checks, and the pinned font verifier passes. The host has a static release CRT
and no Debug-runtime dependency. These audits do not prove Windows 7 execution.

The assembled package's launcher was run locally on Windows 10 build 19044.
Both processes and the launcher return exit 0, with all seven checkpoints,
balanced registration counts and final completion markers. The final control
identifies itself as 0.1, compiled September 13, 2026, 03:11:38, and loads the
issued Release 0.3.5 ABI 8 DLL. The user had confirmed removal of the temporary
HIPS exclusion before this run; security configuration was not independently
inspected or changed by the test.

| Mode | Warm-up handles / USER | Cycle 100 handles / USER | Ten seconds closed handles / USER | Registrations / unregistrations / deliveries |
| --- | --- | --- | --- | --- |
| Power | 176 / 6 | 236 / 36 | 236 / 36 | 102 / 102 / 102 |
| Plain | 166 / 4 | 166 / 4 | 166 / 4 | 0 / 0 / 0 |

GDI remains zero in both modes. This fresh package run independently reproduces
the paired-control result above. Completion verifies the measurement workflow,
not resource acceptance. Windows 7 execution was pending at issue time and is
recorded below; resource lifetime/boundedness remains open. Local evidence is retained under
`artifacts/resource-comparison-0.1/Logs/resource-comparison-17260-8923/` and is
excluded from the distributed archive.

### Supplied Windows 7 native comparison

The supplied `resource-comparison-18452-32699` contains `power.log`, `plain.log`
and `summary.txt`. Hash-matched copies are preserved under
`artifacts/vt7/evidence/resource-comparison-win7-0.1/resource-comparison-18452-32699/`.
The reports identify Windows 7 SP1 x64, NT 6.1.7601, control 0.1 compiled
September 13, 2026, 03:11:38, and native Release 0.3.5 ABI 8 compiled at 01:18:36.
These match the issued identities, but the logs do not independently establish
the transferred archive hash, driver, DPI, update tier or loaded third-party
modules. Earlier environment reports are not a fresh inventory for these runs.

Both processes and the launcher exit 0. Each process records all seven resource
checkpoints and the expected completion markers. Power reports 102 successful
registrations, 102 unregistrations and 102 deliveries; plain reports zero for
all three. No soak was performed.

| Checkpoint | Power handles / USER | Power queue-bearing group | Plain handles / USER | Plain queue-bearing group |
| --- | --- | ---: | --- | ---: |
| Warm-up | 165 / 31 | 27 | 161 / 30 | 26 |
| 25 | 174 / 40 | 36 | 172 / 41 | 37 |
| 50 | 174 / 40 | 36 | 174 / 43 | 39 |
| 75 | 175 / 41 | 37 | 175 / 44 | 40 |
| 100 | 175 / 41 | 37 | 175 / 44 | 40 |
| Ten seconds closed | 177 / 41 | 37 | 177 / 44 | 40 |

The queue-bearing group is the sampled `ntdll.dll+f8de0` start address, not a
symbolicated function or established ownership category. USER equals four plus
that group's input-queue-bearing count at every sample. GDI remains nine in
both processes. At cycle 100, power is +10 handles, +10 USER and +2,605,056 private
bytes from warm-up; plain is +14 handles, +14 USER and +1,458,176 private bytes.
At the final closed-surface sample, the respective deltas are +12/+10/+2,658,304
and +16/+14/+1,515,520. The persistent parent is still alive at that sample.

The last +2 handles in each process coincide with two additional non-queue
threads in the same start-address group, while USER stays flat. Total sampled
threads grow from 37 to 42 in power and 36 to 44 in plain. These observations
help separate thread-count growth from queue-associated growth; they do not
identify the handle types or establish a fixed, fully initialized worker pool.
Resource and thread samples are sequential, not an atomic ownership snapshot.

This changes the target interpretation: unlike the development machine,
Windows 7 grows even without the control's explicit power subscription or
reported power deliveries. Neither WPF nor that subscription is required for
this target reproduction. It does not rule out all Windows message/input paths,
attribute allocations to a specific library, or establish security-product
involvement. The Windows 10 traced `IoCompletion` allocation family is not
automatically the Windows 7 retained-handle family.

The late flat USER intervals are encouraging but are not a proven long-term
bound, particularly while the thread/handle totals still change. These native
measurements do not supersede the integrated WARP lifecycle failure. Keep the
existing budgets and C3 gate open; no production behavior, security setting or
issued package was changed for this review.

Evidence SHA256:

- `power.log`: `79BA85A6EC488A948CA2BC900FE4D6D12581029F76DD44B64DBC43DD43BCC7B1`.
- `plain.log`: `254BB7F85480D56396C306888BCF3EB732FF33F9E786D683F577BBD3B2370C4B`.
- `summary.txt`: `A7F36C87AB674C9F95CD451785772FB2996CB6D4209A8D46B73DBE64CED4357D`.

### Next bounded investigation

No repeat of the unchanged 0.1 package or timed soak is requested. The next
proposed diagnostic compares repeated surface lifetimes with reuse of one
surface, without explicit power subscriptions. Keep the parent, warm-up,
resize/hide/show workload, message pumping, sampling cadence and environment
matched. Sample both cases with one live surface at equivalent checkpoints,
then compare matched final samples after the last surface is destroyed.

Add per-thread ID plus creation-time identity, start address and input-queue
status so surviving threads acquiring queues can be distinguished from new
threads, turnover and reused numeric IDs. Preserve pre-warm-up measurements.
A flat reuse case would implicate repeated surface lifetimes, not alone prove
harmless initialization: reuse also avoids repeated HWND, device, swap-chain
and presentation-worker creation. Account for the integrated process before
changing the acceptance model. This is a proposed control, not implemented or
accepted evidence.

### Native comparison reproduction

The supplied run above completes this handoff. These instructions remain for
reproduction, not an immediate repeat request.

Extract `VT7-resource-comparison-0.1-x64.zip` into a fresh writable folder and run
`RUN-RESOURCE-COMPARISON.cmd`. It runs power first, then plain, each with two
warm-up and 100 measured native WARP surface lifetimes and a final ten-second
closed-surface sample. Return the entire newly created
`Logs/resource-comparison-<run-id>` folder, including `power.log`, `plain.log`
and `summary.txt`. Keep partial reports if either process fails or hangs.
Include the actual Windows update tier, DPI, GPU/driver and any interruption.

Leave security protections and system settings unchanged. This is not a soak
and does not require rerunning the full viewport/scaling matrix. The launcher
explicitly reports measurement completion separately from resource-growth
acceptance. No budget is relaxed and the integrated WARP stability gate stays
open.

## Original 0.3.5 Windows 7 handoff

The bounded quick/lifecycle results from this handoff have already been
supplied and are recorded above. Do not repeat them or start the timed soak
while the attribution investigation remains open. The original instructions
below remain for reproduction of that earlier package.

Extract the complete 0.3.5 package into a new folder. Run the existing diagnostics,
viewport, repaint, recovery and settings launchers, then `RUN-STABILITY-TEST.cmd`.
After the quick run passes, use `RUN-STABILITY-LIFECYCLE.cmd`. Allow roughly
5-10 minutes total and return these bounded comparison results first. Do not
proceed to the timed soak after a lifecycle failure. After review, use
`RUN-STABILITY-SOAK.cmd` for the extended profile. Allow roughly 90 minutes
for both backends, keep the machine awake and do not change display settings.
Keep all named reports and `.progress.log` files, including failures. Supply the
actual DPI, GPU/driver, OS update tier and package identity with the results.

The supplied 0.3.4 DPI evidence is not retroactive proof of this renderer change.
The new test need not become another three-scale typography experiment. Confirm
the affected baseline and retain existing settings regressions. Separate ESU
confirmation remains a milestone-level step.

## Remaining scope

Opacity-zero WPF hosts exercise real native surfaces and workers, not physical
cover/uncover or compositor occlusion. Theme/high-contrast, broader device
transitions, actual driver loss, complete visual corpus qualification and full
Milestone 2 acceptance remain separate. Optional typography stays in Milestone 7.
