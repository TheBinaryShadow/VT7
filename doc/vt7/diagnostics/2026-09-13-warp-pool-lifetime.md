# WARP pool construction, cleanup and idle lifetime

Date: 2026-09-13. This records offline analysis of the completed Windows 7
[resource trace 0.3](2026-09-13-resource-trace.md) and the matching Microsoft
WARP image/PDB. No target workload, application rebuild or new package was
produced. Integrated WARP resource acceptance remains open.

## Finding

The inspected WARP device path initializes its pool wrapper, submits tasks
through one reusable work object, drains its callbacks and releases that object
during device destruction. Its mode-3 branch uses the Windows process default
pool; its other branch creates one private pool with minimum and maximum one
worker. No missing work-object close, enclosing-wrapper free or uninitialized
private-pool slot was found in this path. This is static code evidence, not
proof that those exact cleanup calls executed in the captured process.

The target's 32 `TpWorkerFactory` handle records all report the same pool
address, `0x266460`. They do not establish 32 separate pools. Their reported
minimum/maximum are 0/512, unlike the inspected private branch's 1/1. Together
with presentation callbacks on many Windows worker identities, this supports
default-pool use as an inference. Trace 0.3 did not capture the wrapper mode,
work pointer, or its relationship to that pool address, so dynamic ownership
is not yet established.

The factory reports an idle timeout of **67 seconds**. The entire sample span
is about 19.2 seconds, including only ten seconds after final close. Thus the
capture does not test retirement after the reported timeout. That timeout is
an observed internal field, not a public guarantee that every worker or its
resources disappears at 67 seconds. Retention through ten seconds does not
settle long-term leakage or boundedness.

## Inputs and inspection limits

The unchanged source capture is
`artifacts/vt7/evidence/resource-trace-win7-0.3/resource-trace-20260913-161711-9df20496/trace-combined.log`,
SHA256 `C9DCA08C65430AC9A9E69483A88476C62134A12AC382B33E6557C0E0DD849FB3`.
The issued parser's false rejection and separate corrected offline result remain
in the trace record. Neither the original logs nor the issued ZIP were rewritten.

| Inspected Microsoft data | Identity |
| --- | --- |
| D3D10Warp image | Version 6.2.9200.22592; x64; timestamp `5BB78029`; image size `279000`; checksum `281E7F`; SHA256 `35979BAF3D0538E74EE7E114F96D33A9558C0A4FE06E5A5D6FBFCCFB27794EDB` |
| D3D10Warp PDB | GUID `7394E810-65DA-4871-9C24-1F1987154DDF`, age 1; SHA256 `94A3B4289B11CDCB9F561BA7DCC446335CA0DFFB1134D545621B8DAA7B59CCA1` |

The image comes from Microsoft's exact symbol-server index and matches the
target's recorded module metadata and PDB identity. The target's complete DLL
was not supplied, so its byte-for-byte SHA256 equality is not claimed. The
downloaded image has no embedded Authenticode signature. The existing provenance
record preserves the official retrieval URLs and independent matching checks.

The downloaded image was only read and disassembled. Installed DbgHelp read
the local PDB; installed dumpbin 14.51.36257.0 decoded the image. These tools
do not change the pinned VT7 build toolchain. Public symbols have zero declared
function size and no source/type information; PE runtime-function/unwind ranges
and instruction bytes bound the inspection. Full-image disassembly is only a
search aid because it also decodes non-code bytes.

## Construction, work submission and destruction

All addresses below are RVAs in this WARP build, not portable breakpoints for
an arbitrary version. `wrapper` means WARP's C++ ThreadPool object, not a
Windows `TP_POOL` or process HANDLE.

| Stage | Verified path |
| --- | --- |
| Construct | `UMDevice::Create` at `EF60` allocates one wrapper at device field `+7C0`. At `FB47..FB9B` it zeros every resource slot that CleanUp releases, including private pool `+30`, work `+38`, and success byte `+28`. |
| Select mode | Device byte `+40DC` maps to mode 3 when zero, mode 2 otherwise, at `FAF8..FB0C`. Selection examines profiling, processor count and creation/session/process conditions. Their target values were not captured. |
| Initialize | At `FBB2`, Create calls `ThreadPool::Init` (`1649B0`) with the wrapper, selected mode, and device pointer. Init stores mode at `+2C` and device at `+0`. |
| Default branch | Mode 3 calls `CreateThreadpoolWork(WorkCallBack,wrapper,NULL)` at `164BA7`, storing the result at `+38`. It creates no private pool; the caller has already zeroed `+30`. |
| Private branch | Other modes call `CreateThreadpool` at `164BD1`, storing `+30`; set maximum/minimum to 1 at `164BFD`/`164C0C`; then create one work object at `164C76`, with that pool in its callback environment. |
| Submit | `Task::Init` stores the wrapper at task `+A0`. TaskReadyToExecute (`165210`) normally queues the task and calls `SubmitThreadpoolWork` at `1652EE` using the existing wrapper `+38`. No new work object is created for each submission. A full-ring path can execute synchronously. |
| Execute | WorkCallBack (`165170`) receives the wrapper as callback context, takes a task from that wrapper's ring, and calls ExecuteTask at `1651DE`. The captured stack identifies Task_Present then GetThreadDesktop for the eleven late Event opens. |
| Destroy | `UMDevice::Destroy` (`10520`) loads device `+7C0`, calls WaitWhileBusy at `1086B`, CleanUp at `10873`, frees the wrapper's original aligned allocation at `10891`, then clears the device field. |

The mode-selection excerpt preserves the actual branch instructions and strings,
including process-name comparisons with `dwm` and `iexplore`. The processor
comparison at `FA94` uses R12D=2; do not misread it as a comparison with 1.
Private input fields are retained without assigning unverified flag names;
their runtime values and the selected target mode were not captured.

Microsoft documents that a NULL
[CreateThreadpoolWork environment](https://learn.microsoft.com/en-us/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-createthreadpoolwork)
uses the default callback environment, whose
[default pool](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-initializethreadpoolenvironment)
is process-wide. Closing WARP's work object does not constitute shutting down
that shared pool.

## What cleanup releases

`ThreadPool::CleanUp` (`164CD0..164E6D`, end exclusive) performs this order,
null-checking each owned slot and clearing it afterward:

1. Wait for work callbacks with `cancelPending=FALSE` at `164CF7`, then close
   the work object at `164D01`.
2. Close a non-NULL private pool at `164D14`. The default branch has no owned
   private pool in that slot.
3. Close two Events (`+900`, `+8C0`), delete/free three critical-section locks,
   and destroy/free three allocator objects.

The enclosing wrapper is freed by UMDevice::Destroy, as above. The Init-failure
path also cleans up; Create subsequently performs a null-guarded second cleanup,
frees the wrapper, clears device `+7C0`, and returns an allocation error.
The complete WaitWhileBusy method only performs an optional infinite Event
wait, with optional logging; CleanUp separately drains the Windows callbacks.
CloseHandle/HeapFree and WaitForSingleObject return values are not checked in
these sequences. Static presence of the calls does not prove runtime success.

The two Events explicitly created by Init are manual-reset. The eleven late
Events in the captured GetThreadDesktop path are auto-reset, so this inspection
does not identify them as those two wrapper-owned handles. Their kernel purpose
and complete close/reopen history remain unknown. The GetThreadDesktop result
is a desktop handle, not one of these Event values, and its
[contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getthreaddesktop)
does not require CloseDesktop by the caller.

The documented callback
[wait](https://learn.microsoft.com/en-us/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-waitforthreadpoolworkcallbacks)
and [work close](https://learn.microsoft.com/en-us/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-closethreadpoolwork)
operations concern that work object's callbacks and storage.
[Pool close](https://learn.microsoft.com/en-us/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-closethreadpool)
can be asynchronous if bound objects remain. None of these reviewed contracts
promises immediate restoration of process handle/USER/thread counts. This
does not prove harmlessness, authorize closing a runtime-owned pool, or relax
VT7's existing resource budgets.

## Rechecked target pool and module evidence

Every detailed factory record at samples 2 through 6 has Pool `0x266460`, Worker
Process `0x2384`, minimum 0, maximum 512 and idle timeout `-670000000 x100ns`.
The timeout magnitude is 67 seconds. The same 32 handle values, `0x244` through
`0x2C0` in steps of four, are enumerated at each of those samples.

| Sample | Phase | Factory handles | Reported HandleCount | PointerCount | Total/waiting workers |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | pre-warmup | 0 | - | - | - |
| 2 | warmup-live | 32 | 33 | 67 | 33/33 |
| 3 | baseline-live | 32 | 33 | 68 | 34/34 |
| 4 | measured-live | 32 | 33 | 69 | 35/35 |
| 5 | final-closed | 32 | 33 | 69 | 35/35 |
| 6 | final-closed-10s | 32 | 33 | 69 | 35/35 |

The Pool field is a debugger-reported user-mode association, not a unique
kernel-object address. Identical fields support a common pool association;
they are not a formal identity proof for all handle references, proof that no
other pool exists, or an accounting for the extra reported HandleCount. Do not
equate the internal `Bound object count: 0` field with the public API's set of
work/I/O/timer/wait objects bound to a TP_POOL without further evidence.

All 34 baseline TppWorkerThread TID-plus-creation-time identities remain at
final+10s; a 35th appeared at the measured checkpoint. All 34 baseline identities
have positive queue observations by that checkpoint. The final loaded-module
list contains no WARP row; its unloaded-history list contains one. These were
checked separately, since an unloaded-history row alone would not establish
absence from the loaded list. Unload does not prove a particular cleanup call
or exclusive WARP ownership of surviving Windows workers.

## Next bounded diagnostic and decision

Subsequent implementation: [resource retirement diagnostic 0.1](2026-09-13-resource-retirement.md)
now implements and locally qualifies this follow-up. Its separate record owns
the issued package identity and the subsequent completed
[Windows 7 result](2026-09-13-resource-retirement.md#supplied-windows-7-result):
actual mode 3 cleanup returns and all 34 baseline Windows workers retire by
90 seconds, while some process resources remain. The proposal
below records the decision from this offline inspection, not a target result.

The useful question is whether the resources track surviving Windows pool
workers after WARP releases its work, and whether they disappear when those
workers retire. The present evidence favors investigating that lifetime over
patching a missing WARP pool close. It does not yet answer the integrated
application's long-term resource-growth failure.

A focused successor should record the actual wrapper, mode, work pointer and
cleanup entry/return, then retain the same reused-surface workload and let the
closed-surface process pump normally for post-close samples at 10, 90 and 180
seconds. Correlate thread identities, queues, handle types, the eleven opened
Event histories, factory fields and module state in the same process. Record
actual elapsed times and debugger stops. Inactivity begins with the last work,
not with arbitrary wall time spent paused in the debugger.

The existing lifetime 0.2 executable has a fixed ten-second final wait and no
CLI override. A longer observation therefore needs an intentionally new
diagnostic identity and appropriate protocol/validator updates; it cannot be
obtained by rerunning the unchanged ZIP or sleeping with all debuggee threads
stopped. Preserve existing packages, normal policies, two warm-up iterations,
25 measured iterations and the integrated budgets. Qualify any new collector
locally before requesting another target capture. No such package is issued by
this offline investigation; the integrated timed soak remains on hold.

| Subsequent observation | Interpretation and next decision |
| --- | --- |
| Actual wrapper uses mode 3 and work cleanup returns | Confirms the missing dynamic link to the default branch; pool-worker lifetime remains a Windows/shared-process question. |
| Worker identities retire and corresponding resources disappear | Supports worker-lifetime retention for this control; still requires a defensible bound and integrated qualification. |
| Workers retire but attributed resources remain | Investigate resource teardown beyond worker survival; counts alone still do not prove continuous handle identity. |
| Workers and resources remain at 180 seconds | Lifetime remains unresolved. The observed timeout is not a deadline for all workers, and two late samples do not prove an unbounded leak. |
| Cleanup is missing, incomplete or uses a different mode | Follow that concrete ownership discrepancy before selecting an application correction. |

## Retained reproducible analysis

These directories are under ignored `artifacts/vt7/diagnostics/`; they must be
retained separately from a fresh repository clone. Their scripts derive results
from the unchanged capture or Microsoft image as data.

- `warp-pool-lifetime-20260913/`: caller inspection script, PE ranges/bytes,
  imports, strings, symbol resolutions, annotated excerpts and FINDINGS.md.
- `win7-ntdll-symbolication-28116/init-analysis/`: complete bounded Init/helper
  disassembly, callback environment header evidence, FINDINGS.md and hashes;
  separate submission follow-up links tasks to the existing work object.
- `warp-pool-cleanup-20260913-163250337-ae2af6e0/`: complete cleanup/wait/helper
  disassembly, independent caller follow-up, module inventories and hashes.
- `resource-trace-0.3-pool-evidence-audit-1789310112572-eb007cba/`: extraction
  script, EVIDENCE.json with raw line references, pool grouping, worker identities,
  timing and official API source notes.

Documentation and evidence checks accompany this analysis. No new runtime
test, application fix, target verification or stability pass is claimed.
