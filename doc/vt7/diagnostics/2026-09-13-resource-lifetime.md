# Native resource lifetime comparison 0.2

Status: implemented, locally exercised and packaged as a separate candidate.
The supplied Windows 7 comparison completed both modes. Growth also occurs
while one surface is reused; allocation ownership remains unresolved.
Measurement completion does not accept resource growth or close C3.

This follows the [0.1 native comparison](2026-09-13-resource-investigation.md)
and its [Windows 7 findings](../validation/2026-09-13-atlas-stability.md#supplied-windows-7-native-comparison).
Both 0.1 target modes grew without requiring explicit power subscriptions.
This comparison asks whether growth depends on repeated surface lifetimes or
also occurs while one surface is reused, and how sampled thread identities and
positive input-queue observations change. The [supplied target result](#supplied-windows-7-comparison)
resolves that question: repeated surface creation is not necessary for the
observed early growth.

## Scope and source map

The standalone native executable loads the issued Release 0.3.5 ABI 8 DLL.
It does not rebuild that DLL, modify renderer policy, load the WPF host, change
input/security settings, register power notifications, or run graphics probes.

| File | Responsibility |
| --- | --- |
| [resource-lifetime.cpp](../../../src/vt7/VT7.ResourceLifetime/resource-lifetime.cpp) | Native workload, lifecycle control, thread/resource sampling and completion/failure output. |
| [vt7_native.h](../../../src/vt7/VT7.Native/include/vt7_native.h) | Canonical ABI 8 declarations used by the diagnostic. |
| [Run-ResourceLifetime.ps1](../../../src/vt7/VT7.ResourceLifetime/Run-ResourceLifetime.ps1) | Windows PowerShell 2.0 target runner, process deadlines and log validation. |
| [RUN-RESOURCE-LIFETIME.cmd](../../../src/vt7/VT7.ResourceLifetime/RUN-RESOURCE-LIFETIME.cmd), [README.txt](../../../src/vt7/VT7.ResourceLifetime/README.txt) | Target entry point and interpretation instructions. |
| [Build-VT7ResourceLifetime.ps1](../../../tools/Build-VT7ResourceLifetime.ps1) | Pinned x64 Release diagnostic build in a fresh directory, with source snapshots and compiler manifest. |
| [Package-VT7ResourceLifetime.ps1](../../../tools/Package-VT7ResourceLifetime.ps1) | Separately identified package, verified copies of issued dependencies and provenance. |
| [Test-VT7ResourceLifetime.ps1](../../../tools/Test-VT7ResourceLifetime.ps1) | Local bounded workload, identity consistency and rejection checks. |

The build/package/test helpers run on the development machine. Only the
distributed runner targets Windows PowerShell 2.0. The diagnostic uses static
release CRT, MSVC 14.44.35207, SDK 10.0.26100.0 and Windows 7 API/PE targets.
Build output directories are unique; packaging refuses an existing 0.2 folder
or archive, including partial output. Preserve it and assign a new candidate
identity before packaging again.

## Matched protocol

The runner starts recreate, then reuse, in separate processes. Both request
Atlas Direct3D11 WARP with capture diagnostics and use one persistent shown,
fully transparent layered native parent with matching styles and dimensions.
All surface ABI calls remain on the HWND owner thread.

Each mode performs two warm-up plus 100 measured iterations. Every iteration
resets the child to 1000 by 800 and resets the scheduling fixture, then performs
ten matching resizes, edits with concurrent notification bursts, authored-marker
checks and five hide/show trips. Both modes use the same message-pumping delays.
Recreate makes/destroys a surface each iteration; reuse retains one surface
through all iterations. Expected totals are 102 iterations, 1,020 resizes,
102 size resets and 510 hide/show trips in each mode; creates/destroys are
102/102 versus 1/1.

Completed frames must report the requested WARP backend and nonblank capture.
Each surface must have exactly one presentation-worker start. Every completed
frame must also report one graphics-device generation/attempt, zero recovery
failures, fallbacks and injected failures, and no historical rendering failure.
A recovered device loss makes this comparison incomplete because it changes
the intended device lifetime. Rendering recovery is not disabled in production.

| Sample | Phase | Surface state in both modes |
| --- | --- | --- |
| 1 | Pre-warm-up | No surface; persistent parent exists. |
| 2 | First warm-up iteration | One live surface after its workload. |
| 3 | Baseline after second warm-up iteration | One live surface after its workload. |
| 4 to 7 | Measured iterations 25, 50, 75, 100 | One live surface after its workload. |
| 8 | Final closed | Last surface destroyed; same 20 ms pump delay completed. |
| 9 | Final closed plus ten seconds | No surface; parent still exists during message pumping. |

Live checkpoints follow the same additional 250 ms message-pumping delay.
Recreate destroys its sampled live surface after the checkpoint. At the last
iteration both modes destroy their final surface before the closed samples.
Pre-warm-up and first warm-up evidence remain in the log. Compare equivalent
live states or equivalent closed states, not a retained surface against an
already destroyed one. Parent destruction and DLL unload occur after sampling.

## Thread and resource evidence

Each `RESOURCE` row includes private bytes, process handles, GDI, USER, sampled
thread count and monotonic sample begin/end times. Thread enumeration and
process counters are sequential, not atomic. Temporary sampler handles are
closed before process counters are read. Fixed storage for 2,048 sampled
threads and 16,384 identities is touched before the first sample; exceeding
either capacity fails explicitly. Sampling and logging still affect timing
and memory.

Thread identity is TID plus creation FILETIME, retained as a 64-bit hexadecimal
value. `surviving` means the same identity occurred at adjacent checkpoints;
`seen-earlier` means it reappeared after a sampling gap. A different creation
time for a previously observed TID is `new-identity-reused-tid`.
`NOT_OBSERVED` records absence from the next snapshot, not proven termination.
[`GetThreadTimes`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getthreadtimes)
supplies creation time; the diagnostic does not infer liveness from its exit
time, which is undefined while a thread remains alive.

`queue=observed` requires a successful `GetGUIThreadInfo` call bracketed by
checks that the opened, identified thread remains alive. `queue=unavailable`
does not establish queue absence. `first_queue_sample` is the first positive
observation, not the instant of queue creation. GUI queries can fail for a
missing thread or an absent queue; races and query errors remain explicit.
See Microsoft's [`GetGUIThreadInfo` contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getguithreadinfo).

The dynamically resolved
[`NtQueryInformationThread`](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntqueryinformationthread)
start-address query supplies an address and, where available, module plus
offset. This is not allocation ownership or a symbolicated stack. An ntdll
address does not identify a WARP-owned resource. Query status, module errors
and unavailable creation identity are retained. Unavailable per-thread
attribution can coexist with completed workload measurements.

Checkpoint sampling misses threads born and terminated between checkpoints,
including the fixture's joined notification producers. These logs cannot
establish every creation, queue transition or exit. A flat reuse case would
implicate repeated lifetimes collectively: reuse also avoids repeated HWND,
device, swap-chain and presentation-worker creation. It cannot alone prove
harmless initialization, a fixed worker pool or a specific leaking owner.
The earlier Windows 10 handle attribution does not become Windows 7 attribution.

## Completion and target operation

These are the issued reproduction instructions. The supplied comparison below
has completed; no unchanged repeat is requested.

Extract the whole archive into a fresh writable local folder and run
`RUN-RESOURCE-LIFETIME.cmd` once. No visible application window is expected.
Keep the same target setup and normal settings; note environment changes or
interruptions. Return the complete new `Logs/resource-lifetime-<run-id>` folder:
both stdout logs, both stderr logs and `summary.txt`.

The runner gives each process 600 seconds. It retains the child process handle,
terminates its own timed-out/unfinished child, preserves partial logs and rejects
unavailable/nonzero exit status. It checks the exact mode and native version,
all nine resource checkpoints, corresponding thread-row counts, workload totals,
zero power deliveries, empty stderr and the unique completion marker. Missing,
duplicated or malformed required evidence makes the comparison incomplete.
The process-scoped execution-policy switch does not change machine policy.

Native failure output uses `FAIL` and `INCOMPLETE`, returning 1. Exit 0 and
`COMPLETED` mean measurements finished, with resource acceptance explicitly
not evaluated. The integrated budgets remain +64 MiB private memory, +32
handles, +8 threads, +16 GDI and +16 USER after warm-up. This diagnostic does
not apply, relax or replace those gates. No timed soak is part of this task.

## Candidate identity and local validation

The recorded development executable SHA256 is
`438FC74130CE3D7A255BEDF368FEA1371778CB0A85CF9D5EBCF1A295C246F71F`.
Its source base is `928c4581e3747d622ebcd43cf36206125b623102` with uncommitted
diagnostic additions. HEAD alone does not identify those inputs; the build
manifest records dirty state and hashes the compiled source snapshots.

The issued native DLL must retain SHA256
`0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49`.
Packaging checks copied runtime/font/legal files against the pinned issued
0.3.5 manifest. Original native provenance remains a historical snapshot;
the new diagnostic's source, build and package manifests have separate roles.

Archive: `artifacts/VT7-resource-lifetime-0.2-x64.zip`, 3,799,264 bytes, SHA256
`8F2F1014A96B1781486574E4FF92AD8B43823CB96EC90BA1A2E71B656C03F388`.
All 37 hashed ZIP entries were independently read and checked against its
manifest after packaging. The packaged runner matches the full locally tested
runner byte for byte. The old 0.3.4, 0.3.5 and comparison 0.1 archive hashes
were rechecked unchanged. No production DLL was rebuilt.

Build directory, relative to the repository:
`artifacts/vt7/diagnostics/resource-lifetime-build-20260913-122947065-99e84331138d4eca8771354481b76f33/`.
The pinned Release build completed with warnings treated as errors. PE inspection
confirmed x64 and OS/subsystem 6.01; static imports are from KERNEL32, USER32,
OLE32 and PSAPI, using Windows 7-compatible APIs. This is not target execution.
The compiler timestamp is September 13, 2026, 14:29:47 local time.

Development environment: Windows 10 IoT Enterprise LTSC, NT 10.0.19044,
Ryzen 9 9950X3D and RX 7900 XTX. The workload explicitly selected software WARP;
the installed GPU does not identify the rendering backend. Normal security and
input settings remained in place. No fresh driver/update inventory was captured.

The first bounded verification completed nine checks with zero failures:
two one-cycle measurements; two injected workload failures; zero, 101 and
duplicate cycle arguments; missing DLL; and missing exports. The successful
cases verified six samples and thread-identity/queue-history consistency.
Expected negative cases returned 1 with `INCOMPLETE` and no completion marker.
The reuse failure also confirmed successful destruction of its retained surface.
Reports:
`artifacts/vt7/diagnostics/resource-lifetime-tests-20260913-123339409-f86da9914cce42f3b2f2140430c7a531/`.
The final verifier, including redirected-output flushing and owned-child
exception cleanup, then passed all nine cases against the assembled 0.2
package with zero failures. Reports:
`artifacts/vt7/diagnostics/resource-lifetime-tests-20260913-124146763-053a3603734240f6be2ab0073df2e4f8/`.

### Full local comparison

Both full modes and the corrected launcher returned 0 using the actual installed
Windows PowerShell 2.0 engine. Each mode produced all nine checkpoints, 102
iterations, 1,020 resizes, 102 size resets and 510 hide/show trips. Recreate
reported 102 creates/destroys; reuse reported one. Power totals were zero.
No device-recovery or worker-restart rejection fired. Both identity-unavailable
totals were zero; 42 identities were observed in recreate and 46 in reuse.

| Mode and checkpoint | Private bytes | Handles | GDI | USER | Threads |
| --- | ---: | ---: | ---: | ---: | ---: |
| Recreate baseline live | 33,832,960 | 216 | 0 | 8 | 37 |
| Recreate 100 live | 42,545,152 | 216 | 0 | 8 | 37 |
| Recreate closed plus 10 seconds | 16,093,184 | 165 | 0 | 4 | 36 |
| Reuse baseline live | 35,196,928 | 218 | 0 | 8 | 36 |
| Reuse 100 live | 41,402,368 | 218 | 0 | 8 | 46 |
| Reuse closed plus 10 seconds | 13,639,680 | 165 | 0 | 4 | 45 |

Handles and USER stayed flat over the measured live checkpoints in both modes.
Reuse gained ten sampled threads between baseline and iteration 100. Those
additional observations were in the `ntdll.dll+4D110` start-address group, with
GUI-query status unavailable. That is not proof of queue absence or ownership.
At the final closed sample, the only positive queue observation was the main
diagnostic thread in either mode. This local run does not reproduce the earlier
Windows 7 USER growth and cannot replace the target comparison. It also does
not establish a long-term thread/memory bound or accept integrated WARP.

Full log directory:
`artifacts/vt7/diagnostics/resource-lifetime-local-20260913-1230/Logs/resource-lifetime-20260913-143656-40f91c43/`.
SHA256:

- `recreate.log`: `6A32FB44ECD9786B17B98C14A8301D4EE729E79F1B8D338ED4C53F6350C184AE`.
- `reuse.log`: `D129BB6B2A9B3E62BDDDEAEA6F8C363658EEC6BC52BACF91F4539269DA7B53F7`.
- `summary.txt`: `DDCF32692A0D2FACE364570451FF836E8E5A43174125E880949A951EFDF64442`.

### Corrections and limits of local validation

The initial build failed because CL's response-file `/link` forwarding ended
at a newline. The corrected helper puts the quoted arguments on one line;
the failed build directory is retained. PowerShell 2 review found unsupported
`Out-File -LiteralPath`; the first full-launch attempt then failed before either
child started because PS2 cannot combine `Start-Process` window style and
redirected-stream parameter sets. The corrected runner uses a small C# process
wrapper in the separate PowerShell process, with hidden native children,
concurrent log draining, retained process identity and a 600-second deadline.
The successful full run above used that corrected wrapper. The earlier incomplete
launcher logs remain in `resource-lifetime-20260913-143439-3ce4836f/` beside it.

No ten-minute timeout was deliberately exhausted. Timeout cleanup was reviewed;
native workload failure, startup failure and normal completion were executed.
At local issue time, no soak, integrated acceptance rerun, new font qualification,
security exclusion, upstream merge or Windows 7 execution had been performed.
The next action at that point was the single bounded Windows 7 comparison;
the subsequently supplied result follows.

## Supplied Windows 7 comparison

The tester supplied
`K:/VT7_work/Logs/resource-lifetime-20260913-144532-55a231c4/`.
Hash-matched copies of both stdout logs, both empty stderr logs and `summary.txt`
are preserved under
`artifacts/vt7/evidence/resource-lifetime-win7-0.2/resource-lifetime-20260913-144532-55a231c4/`.
This review read the supplied evidence; it did not rebuild binaries or rerun
either workload.

The logs identify NT 6.1.7601 SP1 x64, diagnostic 0.2 compiled September 13,
2026 at 14:29:47, and native Release 0.3.5 ABI 8 compiled at 01:18:36. These
printed identities match the issued candidate. The logs do not independently
verify the transferred archive/DLL hashes, driver, DPI, servicing tier, launcher
PowerShell version or loaded third-party modules. They are not a fresh inventory
of the previously documented target environment.

Both processes and the launcher returned 0. Review checked all nine required
resource samples and all 300 thread rows in each mode, including identity
continuity and queue-observation metadata. Each mode reports 102 iterations,
1,020 resizes, 102 size resets and 510 hide/show trips. Creates/destroys are
102/102 for recreate and 1/1 for reuse. Power registrations, unregistrations
and deliveries are zero; no device-recovery or worker-restart rejection appears.
Measurement completion is established, with resource acceptance not evaluated.

### Process resources

Sample labels follow the matched protocol above; samples 2 through 7 contain
one live surface in each process. Both final samples retain the native parent.

| Mode | Sample / checkpoint | Private bytes | Handles | GDI | USER | Threads |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Recreate | 1 / pre-warm-up | 7,720,960 | 50 | 9 | 4 | 1 |
| Recreate | 2 / first warm-up live | 19,107,840 | 152 | 11 | 19 | 37 |
| Recreate | 3 / baseline live | 20,180,992 | 161 | 11 | 27 | 38 |
| Recreate | 4 / 25 live | 21,917,696 | 175 | 11 | 41 | 38 |
| Recreate | 5 / 50 live | 21,819,392 | 175 | 11 | 41 | 38 |
| Recreate | 6 / 75 live | 21,884,928 | 175 | 11 | 41 | 38 |
| Recreate | 7 / 100 live | 22,638,592 | 176 | 11 | 41 | 38 |
| Recreate | 8 / final closed | 14,798,848 | 140 | 9 | 38 | 36 |
| Recreate | 9 / closed plus ten seconds | 14,798,848 | 140 | 9 | 38 | 36 |
| Reuse | 1 / pre-warm-up | 7,720,960 | 51 | 9 | 4 | 1 |
| Reuse | 2 / first warm-up live | 19,517,440 | 157 | 11 | 23 | 37 |
| Reuse | 3 / baseline live | 20,193,280 | 167 | 11 | 32 | 38 |
| Reuse | 4 / 25 live | 21,045,248 | 175 | 11 | 40 | 38 |
| Reuse | 5 / 50 live | 21,045,248 | 175 | 11 | 40 | 38 |
| Reuse | 6 / 75 live | 21,000,192 | 175 | 11 | 40 | 38 |
| Reuse | 7 / 100 live | 21,118,976 | 175 | 11 | 40 | 38 |
| Reuse | 8 / final closed | 14,176,256 | 138 | 9 | 37 | 36 |
| Reuse | 9 / closed plus ten seconds | 14,176,256 | 140 | 9 | 37 | 36 |

From baseline to iteration 100, recreate is +15 handles, +14 USER and
+2,457,600 private bytes; reuse is +8 handles, +8 USER and +925,696 private
bytes. Both retain 38 sampled threads and 11 GDI objects at every measured
live checkpoint. Thus reuse is not flat over the full measured interval.

### Individual thread identities

Both processes have 34 sampled identities in the unsymbolicated
`ntdll.dll+F8DE0` start-address group by baseline. No new identity in that group,
or elsewhere in ntdll, is sampled after baseline. All 34 group identities remain
present through the final closed sample with unchanged TID plus creation time.

| Mode | Queue-positive group identities at baseline | At 25 | At 100 | Closed plus ten seconds | Baseline identities first positive at sample 4 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Recreate | 20 | 34 | 34 | 34 | 14 |
| Reuse | 25 | 33 | 33 | 33 | 8 |

All 14 additional recreate positive observations belong to baseline identities:
13 were first sampled during the first warm-up iteration and one at baseline.
All eight additional reuse positive observations belong to identities first
sampled during the first warm-up iteration. The same identities remain positive
at every subsequent checkpoint. Reuse's remaining group identity, TID 7516 with
creation `01DD437DDDD926F9`, has unavailable GUI queries through the final sample.
These are first positive queue observations, not proof of when queues were
created or proof that the earlier failed queries established queue absence.

Recreate retains 36 baseline identities at subsequent live checkpoints and
replaces two sampled identities: one with start `VT7.Native.dll+35C70`, the
other `D3D10Warp.dll+163E20`. Reuse retains all 38 baseline identities through
iteration 100. Across the whole run, 48 distinct identities are sampled in
recreate and 38 in reuse; no sampled numeric TID reuse occurs. Both logs report
zero unavailable creation identities. Origin/module queries succeed, liveness
brackets report running, and every unavailable GUI query records error 87.

After final surface destruction, each mode retains 36 of its existing
identities and no longer samples its last Native/WARP start-address pair.
USER drops by three, to 38 in recreate and 37 in reuse. The 14/eight additional
positive ntdll queue observations remain present. Both final handle counts are
140, but reuse rises from 138 to 140 during the final ten seconds with unchanged
sampled identities and queue observations. That +2 is not explained by newly
sampled threads. Recreate also adds one live handle between iterations 75 and
100 without a net increase in sampled threads or positive queue observations.
The logs do not identify those handles' types or allocation owners.

Recreate's +14 USER versus reuse's +8 is not evidence of six additional lifecycle
leaks: reuse already had five more positive group observations at baseline,
and the final groups differ by one. The numerical association between USER
and positive queue observations is useful but is not allocation attribution.

### Decision and remaining work

The bounded question is resolved: repeated surface creation is not necessary
for this Windows 7 early USER/handle growth. Positive queue observations spread
among already sampled thread identities even while one surface and one graphics
device are retained. This narrows the next investigation to ownership and the
triggering operation on a reused surface.

The subsequent [focused trace 0.3](2026-09-13-resource-trace.md) completes that
bounded collection and passes corrected offline validation. It links eleven
additional Event opens to WARP/GetThreadDesktop calls and matching setup/queue
observations on eleven existing identities. This is independent call-path
evidence; do not infer ownership merely from an ntdll start address or transfer
the Windows 10 `IoCompletion` attribution to these target Event handles.
No unchanged comparison repeat, extra warm-up, worker/IME suppression, budget
change or timed soak is requested. The flat later observations cover this short
run only; they do not establish a long-term bound, harmless initialization or
integrated stability acceptance. C3 remains open.

Evidence SHA256:

- `recreate.log`: `6C3C7AB9FB9B348620DA7D3E49F99EB421E1CB2365208F519839F212735F0E6B`.
- `reuse.log`: `5DEA0BFBC89A441ACFB2CB63F59D83E654B49056F90FD52C771F1F3BDEDA7AEE`.
- `summary.txt`: `DDCF32692A0D2FACE364570451FF836E8E5A43174125E880949A951EFDF64442`.
- Both empty stderr files: `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855`.

The summary hash also matches the local successful run because its content
contains the same protocol/completion text and no run-specific measurements.
The distinct stdout hashes and preserved directories identify the two runs.
