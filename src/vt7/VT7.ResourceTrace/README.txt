VT7 focused resource trace 0.3 (Windows 7 SP1 x64)
================================================

Working-source update after the supplied 0.3 run
----------------------------------------------
The Windows 7 capture completed all stages and workload. The issued validator
miscounted a nested Token "Type Primary" field; corrected offline validation
accepts the existing logs. No new target run or installation is requested.
The issued ZIP remains intact. Instructions below describe reproduction;
any future reissue needs a new package identity. See the repository trace
record for the Event-handle/WARP presentation findings and remaining limits.

Install the classic x64 debugger first
-------------------------------------
If your existing SDK 8.1 debugger passed the trace 0.1 preflight, keep it.
No reinstall or additional Visual Studio component is needed for trace 0.3.

Install Microsoft's standalone x64 Debugging Tools MSI from the Windows 8.1 SDK:
https://download.microsoft.com/download/B/0/C/B0C80BA3-8AD6-4958-810B-6882485230B5/standalonesdk/Installers/X64%20Debuggers%20And%20Tools-x64_en-us.msi

Alternatively, use https://go.microsoft.com/fwlink/p/?LinkId=323507 and select
ONLY "Debugging Tools for Windows". The complete SDK, Visual Studio, Windows
Performance Toolkit and Application Verifier are unnecessary here. With the
default installation location, this supplies:
C:\Program Files (x86)\Windows Kits\8.1\Debuggers\x64\cdb.exe

The SDK's signed installer permits Windows 7 (6.1). The standalone MSI's x64
debugger is 6.3.9600.16384, used for local qualification on Windows 10. The
supplied Windows 7 preflight passed with updated CDB 6.3.9600.17298 and engine
6.3.9600.17336. Trace 0.1 stopped at a first-chance invalid-handle exception.
Trace 0.2 captured it reaching unhandled second chance during Windows startup,
before the native DLL loaded or any WARP work began. Trace 0.3 adds a startup
control and postpones handle tracing until pre-warmup. Its Windows 7 capture
now completes and passes corrected offline validation. Do not copy the current
10.0.26100 debugger onto Windows 7: its engine needs a newer Windows API.

Visual Studio 2022 version 17.7 and later cannot install on Windows 7.
VT7's pinned VS 2022 17.14/MSVC 14.44 build environment belongs on the modern
development machine. The Windows 7 machine runs the produced application
and this debugger. Targeting Windows 7 differs from hosting Visual Studio.
The tester has installed Visual Studio 2022 Enterprise 17.6. That is recorded
as available tooling, not qualification of it as the pinned VT7 build environment.

Run the trace
-------------
1. Extract the whole ZIP into a new folder, such as
   K:\VT7_work\resource-trace-0.3. Keep the supplied symbols and fonts folders.
   Use a normal local drive path without semicolons or quotation marks.
2. Double-click RUN-RESOURCE-TRACE.cmd under the same normal account/session
   used for the earlier comparison. Administrator privileges are unnecessary
   for debugging the child that this script launches.
   The supplied target has Windows PowerShell 5.1 and PowerShell 7.2.24 installed
   side-by-side. The launcher calls powershell.exe (5.1 there), not pwsh.exe.
   Its PowerShell 2.0 compatibility also covers unupgraded Windows 7 machines.
3. Wait for completion. Three separate diagnostic processes run in sequence:
   debugger preflight, startup control, then the full trace. A failed stage
   stops the sequence. The startup control has no USER32 setup hook or handle
   tracing, and quits at the first sample entry before surface creation.
   No visible application window is expected. Preflight and startup each have
   a 60-second limit; the trace has a 600-second limit. Normally this takes much less.
4. Return the ENTIRE newly created Logs\resource-trace-... directory, including
   partial logs if the launcher reports INCOMPLETE. Do not repeat a failing
   run or change system settings before the evidence is reviewed.

If you installed the debugger elsewhere, run from 64-bit Windows PowerShell:
  .\Run-ResourceTrace.ps1 -CdbPath 'D:\Tools\Debuggers\x64\cdb.exe'

Optional installation check only:
  .\Run-ResourceTrace.ps1 -PreflightOnly

The launcher verifies every packaged checksum and separately pins the EXE,
native DLL and both PDB hashes. Keep its files unchanged. No debugger binaries
are included. Every invocation creates a separate log folder.

What is being observed
----------------------
This is the EXACT resource lifetime 0.2 EXE and issued native 0.3.5/ABI 8 DLL.
Nothing was rebuilt. It reuses one surface with forced WARP, two warm-up and
25 measured iterations: 270 resizes, 27 fixture resets and 135 hide/show trips.
The ordinary input, worker, graphics and security behavior stays enabled.

CDB launches only that child. No system-wide debugger, registry setting,
global flags, Application Verifier, kernel debugging or unrelated attachment
is configured. The debugger is stopped if its bounded timeout is exceeded;
normal debug-child ownership also ends that run's diagnostic process.

Both startup control and full trace record each first-chance
STATUS_INVALID_HANDLE (0xC0000008) with
its own exception record, registers, up to 24 stack frames and module inventory.
It then uses gn to let the application's normal handlers process the exception.
It does not mark the exception handled or bypass application handlers. An
unhandled second chance or the 16th such event records an abort and ends this
diagnostic immediately. Any recorded exception still requires review even if
the workload later completes. This preserves the trace 0.2 exception policy.

The launcher queues a capture-and-quit command for an unexpected interactive
debugger prompt. It records the last event and context, then rejects collection,
instead of leaving a hidden debugger waiting for a command until the timeout.
Normal breakpoint commands and explicit exception dispatch run first. This is
a tracing control, not a renderer or resource-lifetime fix.

The existing sample() entry is at image RVA 0x1470 in the pinned EXE only.
Its six entry breakpoints correspond to pre-warm-up, first warm-up live,
post-warm-up live baseline, 25 measured live, final closed and closed plus
ten seconds. These precede the ordinary thread/counter observations by a
debugger pause; the snapshots are sequential, not simultaneous. The final
closed samples still retain the one native parent window, as in comparison0.2.

An internal exported USER32!ClientThreadSetup breakpoint records up to 256
setup events with decimal PID/TID, TEB, instruction/stack/return addresses,
the latest checkpoint number and up to 24 stack frames. Reaching the cap
disables that breakpoint and marks the collection incomplete. No calls are
injected into a stopped worker to inspect it. USER32's internal hook is not
a documented guarantee of catching every input-queue allocation.

The full trace activates process-local !htrace at the pre-warmup sample entry,
after CRT/COM startup, native DLL load and parent-window creation, but before
the first WARP surface is created. Early startup NT handle histories are outside
its scope. The USER32 setup breakpoint still starts at the initial debugger
stop; delaying handle tracing is the only hook-timing change from trace 0.2.

!htrace records NT handle open/close histories. !handle inventories
are captured at all six checkpoints. Separate diffs cover baseline-to-25,
25-to-closed, and closed-to-closed-plus-ten-seconds, with explicit snapshots
between intervals. These inspect NT handles, not USER object allocations.
Earlier handle values appearing in later inventories do not by themselves
prove uninterrupted survival: closed handle values can be reused.

The launcher clears inherited symbol-server paths in the CDB child environment
and uses only this package's symbols directory. Windows symbol-download errors
followed by "Defaulted to export symbols" are expected in this offline trace.
VT7's private PDBs must load. Module inventories at the live baseline and final
closed checkpoint preserve image bases, sizes, timestamps and versions for
later interpretation, including graphics modules that might unload at close.
Both startup and trace also run !lmi ntdll to preserve embedded PDB identifiers
for later symbol retrieval on the development machine. No symbol downloads
occur in the debugger. Nearest-export-plus-offset Windows labels are not exact
function names; retain raw addresses for review.

How the result will be judged
----------------------------
STARTUP_CONTROL=COMPLETE means the separate control reached pre-warmup without
the setup hook or handle tracing. It does not measure WARP or prove why the
earlier trace failed. If it fails, inspect startup logs before interpreting
the tracing setup. If it passes but the full trace fails before pre-warmup,
handle tracing has not yet started in that process.

COLLECTION=COMPLETE means the expected workload, checkpoints, setup records,
handle commands and normal diagnostic exit were observed. It is NOT resource
acceptance or a finding that the retained resources are harmless.

We will correlate newly queue-positive baseline identities against setup
events in the SAME run. Sampler identities include TID plus creation FILETIME;
setup events have TID/TEB but no creation FILETIME. Ambiguous TID reuse or
unsampled transient threads must remain unassigned. Missing setup matches mean
incomplete hook coverage. An unavailable GUI query does not prove queue absence.

Debugging and handle-history storage change timing, scheduling and memory use.
This run is for ownership evidence; its counters cannot replace normal stability
qualification. Missing/overwritten handle histories, unresolved Windows stacks
and any unobserved final-close ownership remain explicit limitations.

Official references
-------------------
SDK archive: https://learn.microsoft.com/en-us/windows/apps/windows-sdk/downloads-archive
Debuggers: https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/debugger-download-tools
Handle tracing: https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-htrace
VS host requirements: https://learn.microsoft.com/en-us/troubleshoot/developer/visualstudio/installation/visual-studio-2022-unsupported-operating-systems

VT7 source is MIT-licensed. Original notices, fonts, runtime license material,
issued provenance and new trace-source snapshots are preserved in this package.
