VT7 focused resource retirement diagnostic 0.1 (Windows 7 SP1 x64)
================================================================

Purpose
-------
This follows the completed resource trace 0.3. That capture retained Windows
pool workers and their resources at ten seconds after WARP closed, while the
worker factory reported a 67-second idle timeout. This diagnostic records the
actual WARP pool mode and cleanup path, then observes the normally running
process at 10, 90 and 180 seconds after closing the reused surface.

This is a new standalone measurement EXE with the SAME issued VT7.Native 0.3.5
Release, ABI 8 DLL, runtime, fonts and legal notices. The application renderer
has not been rebuilt or changed. Completion is collection evidence, not a
resource-growth pass, proof of harmless retention, or an integrated timed soak.

Run once and return the whole log folder
--------------------------------------
1. Extract the entire ZIP into a NEW local folder, such as
   C:\VT7_work\resource-retirement-0.1. Keep all supplied files and subfolders.
   Use a path without semicolons or quotation marks.
2. Double-click RUN-RESOURCE-RETIREMENT.cmd in that folder, under the same
   normal Windows account and session used for the preceding trace.
3. Allow approximately four to six minutes. No visible application window is
   expected. Leave the diagnostic running throughout its post-close wait.
4. Return the ENTIRE new Logs\resource-retirement-... folder. Include partial
   logs if the launcher reports INCOMPLETE. Do not repeat a failed run or change
   system settings before its evidence is reviewed.

The existing working classic x64 SDK 8.1 debugger is sufficient. No new debugger,
Visual Studio component or PowerShell installation is needed. The launcher uses
powershell.exe (Windows PowerShell 5.1 on the supplied Windows 7 machine), not
the side-by-side pwsh.exe. It is also written for Windows PowerShell 2.0.

If the working debugger is installed elsewhere, launch from 64-bit Windows
PowerShell with its explicit path:
  .\Run-ResourceRetirement.ps1 -CdbPath 'D:\Tools\Debuggers\x64\cdb.exe'

Optional installation check only:
  .\Run-ResourceRetirement.ps1 -PreflightOnly

The launcher verifies package checksums and binary identities before collection.
Keep the package unchanged. Each invocation creates a separate log folder.
Debugger and Microsoft WARP binaries/PDBs are not included or downloaded.

Collection scope
----------------
The same forced-WARP reused-surface workload performs two warm-up iterations
and 25 measured iterations: one create/destroy pair, 270 resizes, 27 fixture
resets and 135 hide/show trips. The ordinary graphics, worker, input and
security behavior remains enabled. Existing resource budgets are unchanged.

Eight sample entry checkpoints cover pre-warm-up, first warm-up live,
post-warm-up live baseline, measured-live, final-closed, and final-closed at
10, 90 and 180 seconds. The standalone EXE pumps normally during idle time;
it does not simulate retirement time by holding the process stopped in CDB.
The retained native parent window has the same lifetime as in comparison 0.2.
Timing records identify the elapsed process time and debugger observations;
checkpoint snapshots are sequential, not simultaneous.

Three separate child processes run in order: debugger preflight, startup
control, and full collection. The first two have 60-second limits. Full
collection has a 600-second limit. A failed stage stops the sequence and
retains its logs. Only these diagnostic children are debugged. No registry,
system-wide debugger, global flags, Application Verifier, kernel debugger or
unrelated process attachment is configured.

The startup control ends at the exported sample entry before surface creation,
without the USER32 setup hook or handle tracing. Full collection observes early
USER32 thread setup, then enables process-local NT handle tracing at pre-warm-up
after ordinary startup and before first WARP surface creation.
Ownership and USER32 setup hooks are disabled before idle observation. Only
checkpoint and diagnostic-exit hooks remain during that period.

Private WARP breakpoints are specific to the Windows 7 image previously
examined: D3D10Warp.dll 6.2.9200.22592, x64, timestamp 5BB78029, image size
279000, checksum 281E7F. The launcher and debugger verify the profile and guarded
instruction bytes before using those offsets. These checks are not a claim
that arbitrary WARP versions share this layout. An unsupported profile reports
TARGET_EVIDENCE=UNSUPPORTED and may complete collection without the private
hooks. It cannot produce a Windows 7 pool-ownership finding. Return its logs
for review if this occurs on the Windows 7 target. Local Windows 10 qualification
covers the collector and later checkpoints, not these Windows 7 private hooks.

On the matched profile, the trace records WARP wrapper/mode/work pointers and
cleanup observations. Handle inventories and histories, worker identities,
queue observations, worker-factory fields and loaded/unloaded module records
support correlation in this same process. The final checkpoint also dumps the
full bounded NT handle history so that the measured interval's Event handles
can be checked for later CLOSE records and handle-value reuse. A missing or
overwritten history prevents claiming continuous handle identity.
No function is injected into a
stopped worker and no runtime-owned event, pool or desktop handle is closed by
the collector. Windows private structures and hooks are evidence aids, not
documented guarantees of ownership or complete coverage.

Exception and symbol handling
-----------------------------
First-chance STATUS_INVALID_HANDLE (0xC0000008) is recorded with its own context
and stack, then passed to the application's normal handlers with gn during
startup and live work. It is never silently marked handled. An unhandled second
chance or the 16th such event aborts collection. During idle observation, the
first invalid-handle exception ends collection after preserving its context,
because another exceptional debugger stop would disrupt that observation.
An unexpected interactive debugger prompt is captured and rejected instead of
waiting invisibly for user input. The live-work policy follows trace 0.3;
retirement observation adds the stricter idle abort.

The child debugger uses only the supplied VT7 symbols. Inherited symbol-server
paths are cleared. No Windows symbols are downloaded during the run. Windows
symbol warnings followed by export-symbol fallback can be expected; VT7's own
PDBs must load correctly. Raw addresses and module metadata are preserved for
offline analysis, since nearest-export labels are not exact function names.

Interpretation
--------------
COLLECTION=COMPLETE means the required workload, records, checkpoints and
normal exit were captured. Results still require review. Debugging and handle
history storage affect timing and resource use; these counters do not replace
normal integrated stability qualification.

Retirement of baseline worker identities with corresponding resource changes
would support worker-lifetime retention in this control. Surviving resources
after worker retirement would redirect the teardown investigation. Continued
retention at 180 seconds would leave lifetime unresolved; the observed idle
timeout is not a public promise that every worker retires by that deadline.
Handle values may be reused and an unavailable GUI query is not proof of queue
absence. No outcome in this run alone establishes an unbounded leak or a safe
bound for the integrated application.

Provenance
----------
PACKAGE-MANIFEST.json records each inherited file's original and packaged path,
the new EXE/PDB build manifest, and collector source identities. The old lifetime
0.2 EXE/PDB are retained as historical files under provenance, not run by this
launcher. Original runtime/font/license and core/renderer provenance files keep
their exact bytes. New build and collector source snapshots are included.
VT7 source is MIT-licensed. SHA256SUMS.txt covers the packaged files.

Official references
-------------------
Handle tracing: https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-htrace
Thread pools: https://learn.microsoft.com/en-us/windows/win32/procthread/thread-pools
Work creation: https://learn.microsoft.com/en-us/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-createthreadpoolwork
Work callback wait: https://learn.microsoft.com/en-us/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-waitforthreadpoolworkcallbacks
Work close: https://learn.microsoft.com/en-us/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-closethreadpoolwork
