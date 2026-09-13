# VT7 development handoff

Updated: 2026-09-13, after the supplied Windows 7 resource retirement 0.1 result and verified log archival.
This is the current resumption guide. Start with the [documentation index](README.md)
if unfamiliar with the repository. The [roadmap](../../ROADMAP.md) owns gates;
dated validation records own test claims.

## Where we are

VT7 is an independent MIT-licensed Windows 7 SP1 x64 terminal application port.
The current application is a static TerminalCore-backed Atlas viewport inside
a .NET Framework 4.8 WPF host. It has no interactive local shell, SSH session,
production tabs/panes/profiles, selection or session-input implementation yet.
The visible viewport/Diagnostics tabs belong to the proof host, not the finished
multi-session UI. Planned PowerShell 7 coverage through 7.2.24 is not a tested
VT7 session claim.

Port first. Preserve pinned upstream behavior wherever possible and adapt the
Windows 7 boundaries. Required correctness, security, accessibility and resource
lifetime are blockers when affected; optional typography and refinements belong
in Milestone 7. Do not resume the earlier Arabic/geometry experiment chain as
the default next task.

| Item | Current state |
| --- | --- |
| Working application version | 0.3.5, native ABI 8, x64. Version alone does not distinguish issued binaries from later source diagnostics. |
| Milestone 1 | Complete on the tested configurations, with the evidence limits in its record. |
| C1 minimum font boundary and C2 Atlas integration | Accepted on the supplied Windows 7 setup in 0.3.0. |
| C3 repaint, controlled recovery, scaling | Bounded 0.3.1/0.3.2 results and actual 0.3.4 96/120/144 DPI matrix accepted. |
| C3 scheduling/resource lifetime | Active. Quick hardware/WARP and hardware 100-cycle lifecycle pass locally and on the supplied Windows 7 setup; integrated WARP fails resource budgets on both. |
| Timed soak | Not run on either setup and currently on hold. |
| Latest target diagnostic | Retirement 0.1 completes all eight checkpoints with a supported WARP profile and zero invalid handles. Actual mode 3, callback drain, work close and wrapper free are recorded. All 34 baseline pool-worker identities are absent by the 90-second sample; USER returns from 38 to 4 and process handles fall from 141 to 107, unchanged at 180 seconds. |
| Remaining lifetime question | The target retains 54 process handles above pre-warmup after workers retire, including the same 32 factory handle values reporting one pool with zero workers. The native result does not yet explain the integrated WPF failure or establish a repeatable retained baseline. |
| Latest local diagnostic | Resource retirement 0.1 has a new exported sampler and the unchanged native 0.3.5 payload. The final Windows 10 collector completes eight checkpoints and full handle history under PowerShell 2; its unsupported WARP profile correctly supplies no target ownership claim. |
| Next bounded task | Design a bounded repeated work/close/idle observation in the integrated WPF host, within one process, to connect the native result to the integrated failure and test whether its retained baseline repeats. Exact design remains under review; no new diagnostic is built or issued for this step. No unchanged target rerun or timed soak is requested. |
| Milestone 2 | Open. Theme/high-contrast, broader device/environment and milestone-level ESU coverage also remain. |
| After renderer qualification | C4/Milestone 3A session feasibility: local-console fidelity, OpenSSH byte/control paths, input and ownership/security contracts. Then application/session delivery. |

## Resume safely

1. Read this file, the [current validation record](validation/2026-09-13-atlas-stability.md),
   and the [port-first plan](architecture/2026-09-12-port-first-plan.md).
2. Inspect `git status --short`, `git branch --show-current` and `git log -1`.
   The user's development branch is `initial-implementation-and-assessment`.
   Do not switch branches, discard changes, merge upstream or commit/push merely
   as a resumption step. Preserve unrelated work.
3. The 0.2 diagnostic source base is `928c4581e3747d622ebcd43cf36206125b623102`
   with uncommitted diagnostic additions. The build manifest hashes the actual
   source/header snapshots; HEAD alone does not identify them. Record the actual
   commit and dirty state for later builds.
4. Locate or obtain the exact issued binaries if reproducing an old result.
   `artifacts/` and the tester's `K:/VT7_work/` paths are not cloned with Git.
   Use hashes below; never infer a match from the filename or version alone.
5. Review build scripts before packaging. The current package helper replaces
   its fixed 0.3.5 directory and ZIP. Do not run it over retained evidence.
   A later candidate needs an intentional new artifact identity and paths that
   preserve old evidence. An isolated workspace protects existing files but does
   not replace assigning that new identity. This update creates no application build.

## What 0.3.5 changed

- Renderer timer deadlines are read under the core lock and the lock is released
  before waiting. The pinned synchronized-output timeout policy remains intact.
- A hidden presentation worker parks and acknowledges pause instead of exiting.
- Final close pauses rendering, completes native HWND destruction on its owner
  thread while the presentation worker still exists, then releases graphics on
  that worker, joins it and deletes the surface. Do not restore worker-exit-before-
  HWND-destruction ordering from an older research proposal.
- ABI 8 supplies scheduling counters and capture-only fixtures. The tests cover
  synchronized-output end/missing-end, parked redraw/timer wakes, hidden output,
  resize/tab churn and disposal from several states.
- This corrected the locally reproduced per-window `DwmDxBltEvent_*` retention.
  It did not solve the remaining integrated WARP resource growth.

The precise implementation, regression scope and chronology are in the
[stability record](validation/2026-09-13-atlas-stability.md). None of this changed
the [upstream baseline or merge policy](../../UPSTREAM.md).

## Findings that must not be lost

1. Integrated 0.3.5 WARP completes its operations without the recorded pixel
   mismatch or hang but fails the resource-growth verdict. Hardware passes.
   A quick pass or successful rendering cannot override that failure.
2. Development-machine isolation implicated shown-parent/message/input behavior.
   A longer 300-cycle control still grew; its name `native-child-plateau` is not
   evidence that a plateau exists. A removed process-local IME-disable experiment
   reduced USER growth but not handles. Normal IME behavior remains enabled.
3. The ESET inspection-module-excluded development control still failed. The
   user removed that narrow exclusion. This does not rule out every security
   component, but gives no reason to request broader exclusions. Windhawk
   exclusion also did not remove the earlier reproduction.
4. Process-only CDB tracing on Windows 10 attributed the 12 new current
   `IoCompletion` handles in the complete baseline-to-25-cycle interval: 11 to
   Windows power-message delivery, one to a WPF message-posting path. Final trace
   history overflowed. Do not claim complete final lifetime histories or equate
   notification registration tokens with those internal completion handles.
5. A native-only paired control on Windows 10 grew with matched power
   subscriptions but stayed flat without them. WPF was unnecessary there.
6. Windows 7 did not reproduce that separation. Both native modes grew with
   zero GDI growth, and USER totals tracked additional queue-bearing threads.
   Explicit power subscription is unnecessary for this target reproduction.
   Windows 10 handle types/stacks are not automatically Windows 7 attribution.
7. The later Windows 7 recreate/reuse comparison 0.2 completes both modes.
   From baseline to iteration 100, recreate gains 15 handles/14 USER and reuse
   gains eight/eight; live sampled thread counts stay 38. All 14/eight additional
   positive queue observations belong to existing baseline identities in the
   `ntdll.dll+F8DE0` group. Reuse retains all 38 baseline identities through the
   last live checkpoint. This removes repeated surface creation as a necessary
   condition, without proving harmlessness or which module owns the resources.
8. Trace 0.3 now supplies direct call-path evidence. Eleven new unnamed Event
   opens between baseline and iteration 25 map one-to-one to WARP setup calls
   on eleven existing TID-plus-creation identities becoming queue-positive.
   Exact symbols resolve the callback chain to NTDLL TppWorkerThread /
   TppWorkpExecuteCallback, WARP ThreadPool::WorkCallBack / Task::ExecuteTask /
   Task_Present, then USER32 GetThreadDesktop. Those Event values and identities
   remain listed after final surface close plus ten seconds. Later handle diffs
   contain no newly outstanding opens. This attributes the bounded call path,
   not a long-term bound or the integrated C3 result.
9. [Offline WARP pool inspection](diagnostics/2026-09-13-warp-pool-lifetime.md)
   finds initialized resource slots, one reusable work object, callback drain,
   work close and wrapper free in the device path. Mode 3 uses the default pool;
   mode 2 creates a private pool with minimum/maximum one worker. This does not
   prove the captured target executed either branch or its cleanup calls.
10. In trace 0.3, the 32 target TpWorkerFactory entries all report Pool `0x266460`, not 32
    distinct pools. Their minimum/maximum are 0/512 and idle timeout is 67
    seconds. All 34 baseline Windows workers survive final+10s, while WARP is
    absent from the final loaded list. The observation is too short to test
    retirement after that interval; the timeout is not a release deadline.
11. The later [Windows 7 retirement result](diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result)
    records mode 3 and completed work/wrapper cleanup. In this process, all 34
    baseline pool-worker identities remain at final+10s but are absent at +90s
    and +180s; the factory reports zero workers. USER returns to its pre-warmup
    value of 4, with GDI 9. All 15 Event values added between baseline and
    iteration 25 have matching worker-exit CLOSE records and are absent by
    +90s; this holds for all 34 captured WARP/GetThreadDesktop Events. Process
    handles remain 107, or 54 above
    pre-warmup, so this is bounded retirement evidence, not integrated C3 acceptance.

Earlier comparison 0.1 Windows 7 deltas from post-warm-up through the ten-second final
closed-surface sample (one persistent native parent still exists):

| Mode | Handles | USER | Private bytes | Total sampled threads |
| --- | ---: | ---: | ---: | ---: |
| Power, 102 matched registration/unregistration pairs | +12 | +10 | +2,658,304 | 37 to 42 |
| Plain, zero registrations or deliveries | +16 | +14 | +1,515,520 | 36 to 44 |

At every target sample, USER equals four plus the queue-bearing
`ntdll.dll+f8de0` count. This is an unsymbolicated grouped start address, not
ownership proof. The final +2 handles in each mode coincide with two more
non-queue threads. Samples are sequential, not atomic. Brief flat intervals do
not prove a fixed pool or a long-term bound. Both modes exit 0 for completed
measurements, not resource acceptance. The complete target transcript is in the
[diagnostic appendix](diagnostics/2026-09-13-resource-investigation.md).

## Next bounded task

The [supplied Windows 7 retirement capture](diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result)
completes the current native diagnostic. No unchanged ZIP rerun is needed.
The next direction is a bounded repeated work/close/idle observation in the
integrated WPF host, within one process, to connect the native retirement result
to the integrated WARP resource failure and test retained-baseline repeatability.
The proposed control runs two existing 100-lifecycle batches, each followed by
closed+10/90/180-second observations. Keep one initial two-lifetime warm-up,
the original fixed baseline and every immediate budget failure. It needs
implementation and qualification; no follow-up diagnostic is built or issued
at this checkpoint. Keep the timed soak on hold and budgets unchanged.
The detailed record owns the capture hashes, verified archive and source location.

The [resource lifetime comparison 0.2](diagnostics/2026-09-13-resource-lifetime.md#supplied-windows-7-comparison)
has answered its narrow question: growth also occurs with one reused surface.
Do not request another unchanged comparison or extend it into a timed soak.

By iteration 25, the target `ntdll.dll+F8DE0` group has 34 positive queue
observations in recreate and 33 in reuse, from the same 34 baseline identities
in each run. These observations remain through final destruction plus ten
seconds. The prior failed GUI queries are unavailable evidence, not proof of
earlier queue absence. The two sampled identities with Native and D3D10Warp
start addresses disappear after final close; the other 36 identities survive.
Reuse handles increase 138 to 140 during the final delay with the same sampled
identities and queue observations. This residual is not attributed by the logs.

The reused-surface trace has identified the Windows 7 call path and retained
handle type for the eleven-handle growth interval. Offline inspection now
connects WARP device construction, task submission and work cleanup. The later
retirement capture now observes actual mode/cleanup and worker disappearance
beyond the reported 67-second idle timeout. The
[pool-lifetime record](diagnostics/2026-09-13-warp-pool-lifetime.md) preserves the
reasoning for that diagnostic. A correction or general bound still requires
connecting this native evidence to the integrated application.
The [focused resource trace 0.3](diagnostics/2026-09-13-resource-trace.md) now
supplies the process-scoped collection. It preserves the exact 0.2 executable
and issued native 0.3.5 DLL, includes both matching private PDBs, and traces
25 reuse iterations with six existing checkpoints. A module containing a
thread's start address is not its allocation owner. The internal USER32 setup
hook has no guaranteed queue-allocation coverage; match its events to the same
run's identities before drawing conclusions. Handle-history diffs concern NT
handles, not USER objects, and debugger timing/counters are not normal stability
measurements. The supplied target capture completes; the issued validator's
nested Token Type bug is corrected and the unchanged logs pass offline.
No new package, unchanged target rerun or full application build is needed
to validate the preserved 0.3 capture.

The user installed SDK 8.1 Debugging Tools. Target CDB/DbgHelp 6.3.9600.17298
and DbgEng/Ext/Exts 6.3.9600.17336 pass preflight; no reinstall is requested.
Trace 0.1 then stopped at first-chance invalid handle (`0xC0000008`) and an
interactive prompt before the application banner, native DLL load or any sample.
The previous USER32 setup stack is not the missing exception stack.

Trace 0.2 records the exception's own context and passes first chance with `gn`.
It aborts on unhandled second chance or the sixteenth such exception. A queued
stdin fallback captures any unexpected debugger prompt and ends the diagnostic
promptly. Its supplied target run records the same exception at second chance
11 ms after dispatch, before the application banner, native DLL or any sample.
Raw frames are in NTDLL startup, but nearest-export labels do not identify the
exact invalid operation or cause. No WARP work occurred in this capture.

Trace 0.3 preserves that exception policy. Its separate startup child uses
neither the USER32 setup hook nor handle tracing and quits at pre-warmup sample
entry, after CRT/COM, native load and parent-window creation. Only if that passes
does the full trace start. The full trace keeps the early setup hook, but activates
!htrace inside the first sample-entry breakpoint, before inventory/sampling and
first surface creation. Thus early startup NT opening histories are excluded;
all WARP surface work and the baseline-to-25 interval remain in scope. If this
full trace fails before pre-warmup, handle tracing is still off in that process.
Both stages preserve !lmi ntdll CodeView identifiers for later symbol retrieval.
The startup control has a 60-second limit and the full trace a 600-second limit.
This is diagnostic isolation, not proof that !htrace caused the startup failure.

The supplied 0.3 startup control and full trace both complete without an invalid
handle. All 36 setup records are preserved: main loader 1, native presentation
worker 1, WARP/GetThreadDesktop workers 34. Between baseline and sample 4,
eleven Event opens match eleven setup events and first positive queue samples
on existing identities. All 34 baseline TppWorkerThread identities become
queue-positive; a 35th new identity remains queue-unavailable with no setup
event. Do not interpret an unavailable query as proof that it has no queue.

The validator now checks one top-level Type per handle and reconciles each
type total. All 137 fixtures pass against both Win7 and Win10 captures under
PowerShell 2.0 and 5.1. The original target summary still records launcher exit 1;
the corrected offline result is separate. Keep the issued 0.3 ZIP intact.

Exact Microsoft NTDLL and WARP symbols are retained with download provenance
and independent GUID/age checks. WARP Task_Present, not its misleading nearest
export label, invokes GetThreadDesktop. That API's returned desktop handle
requires no CloseDesktop call; the observed Events are internal effects, not
application-owned desktop handles to close. Do not force worker termination or
change internal-threading flags as a substitute for understanding the boundary.
The completed Init/CleanUp, caller and submission inspection finds no obvious
missing work close on that path. Default-pool work closure leaves Windows in
control of its workers. In trace 0.3, factory parameters supported default-pool
use as an inference; the later retirement capture supplies actual mode 3 and
matching wrapper/work cleanup observations.

Retirement 0.1 keeps the two-warm-up/25-measured reused-surface workload and the
exact native 0.3.5 DLL. Its new sampler exports `VT7RetirementSample` and adds
10/90/180-second post-close checkpoints. Private WARP hooks require matching PE,
CodeView and instruction identities; an unsupported profile collects ordinary
resource evidence without using those offsets. At final close the collector
disables setup, ownership and module-load event hooks, leaving checkpoint/exit
breakpoints while the normal message pump runs. Unexpected stops or idle
exceptions make collection incomplete. The final full handle history retains
OPEN/CLOSE records and rejects a dump that reaches the history capacity.

The final Windows 10 collection passes under actual PowerShell 2 with eight
checkpoints, zero invalid handles and 4,308 full-history records. Its WARP profile
is correctly unsupported, so this is collector qualification rather than a
Windows 7 cleanup or retirement result. The 181 synthetic validator fixtures
plus its three actual stage logs pass offline under PowerShell 2 and 5.1.
The target-only hook and failure controls are documented separately in the
[retirement record](diagnostics/2026-09-13-resource-retirement.md).

The supplied Windows 7 retirement run then passes all three stages with a
supported profile and zero invalid handles. All 34 baseline pool workers are
absent by the 90-second sample, USER falls 38 to 4 and handles fall 141 to 107,
with both unchanged at 180 seconds. The same 32 factory handle values remain,
now reporting zero workers. The remaining 54 process handles above pre-warmup
and the integrated WPF failure still need a bounded follow-up. No timed soak
was run and this native retirement result does not accept C3.

Keep exception review separate from collection completion. The local
6.3.9600.16384 debugger qualifies the policy with separate handled, unhandled
and repeated-exception fixtures. Do not copy the current 10.0.26100 debugger to Windows 7; its engine
imports GetSystemTimePreciseAsFileTime. The VS 2022 17.14 build environment
belongs on the modern development host, not Windows 7. No global debugger,
kernel debugging, registry setting or security exclusion is used.

Keep normal rendering, input, accessibility and security behavior. No worker
suppression, extra warm-up or budget relaxation is justified. Use ownership
evidence to select a fix or support a bounded lifetime model, then rerun the
unchanged integrated profiles on both machines. The short flat interval in
this diagnostic does not close C3 or establish a long-term bound.

User test context: Croatian HR Latin is the primary input layout. The user
reports Windows PowerShell 5.1 and PowerShell 7.2.24 installed side-by-side on
the Windows 7 target. The trace launcher uses powershell.exe, hence 5.1 there;
this is an installed-tool inventory, not a VT7 session-backend qualification.
The user also reports Visual Studio 2022 Enterprise 17.6 with needed features
installed on the target. This does not replace the pinned modern-host build tools.
Immediately available hardware includes GTX 580, i7-9700, i7-6700, Athlon II and FX-8350.
The user can assemble broader hardware combinations later, after the application
is fully working with its features; this bounded comparison uses the existing
Windows 7 setup rather than requesting a hardware matrix now.

## Code map for that task

| Area | Files and role |
| --- | --- |
| Build/version | [VT7.sln](../../VT7.sln), [Directory.Build.props](../../src/vt7/Directory.Build.props), [Build-VT7.ps1](../../tools/Build-VT7.ps1). |
| CLI and diagnostic dispatch | [App.xaml.cs](../../src/vt7/VT7.Host/App.xaml.cs). |
| Managed lifecycle workload | [StabilityWindowChecks.cs](../../src/vt7/VT7.Host/StabilityWindowChecks.cs). |
| Process/thread samples | [ResourceDiagnostics.cs](../../src/vt7/VT7.Host/ResourceDiagnostics.cs). |
| WPF/native lifetime | [TerminalSurface.cs](../../src/vt7/VT7.Host/TerminalSurface.cs), [surface.cpp](../../src/vt7/VT7.Native/surface.cpp). |
| C ABI agreement | [vt7_native.h](../../src/vt7/VT7.Native/include/vt7_native.h), [exports.def](../../src/vt7/VT7.Native/exports.def), [NativeMethods.cs](../../src/vt7/VT7.Host/NativeMethods.cs). |
| Renderer worker/timers | [renderer.cpp](../../src/renderer/base/renderer.cpp), [renderer.hpp](../../src/renderer/base/renderer.hpp), VT7 compatibility branches. |
| Atlas/presentation | [AtlasEngine.cpp](../../src/renderer/atlas/AtlasEngine.cpp), [Win7Presentation.cpp](../../src/vt7/VT7.Renderer/Win7Presentation.cpp). |
| Font boundary, not current task | [Renderer README](../../src/vt7/VT7.Renderer/README.md), Win7TextMapper and private font fallback. Experimental fitters are not automatic production policy. |
| Assertions/runner | [Test-VT7AtlasStability.ps1](../../tools/Test-VT7AtlasStability.ps1), [packaging launchers](../../src/vt7/packaging/README.txt). |
| Native-only control | [Preserved source and recipe](diagnostics/2026-09-13-resource-investigation.md); not part of VT7.sln or the WPF Host source. |
| Recreate/reuse control | [Protocol and source map](diagnostics/2026-09-13-resource-lifetime.md); versioned standalone source, isolated build/package/test helpers. |
| Focused reuse trace | [Protocol and tool provenance](diagnostics/2026-09-13-resource-trace.md), `src/vt7/VT7.ResourceTrace/`, `tools/Package-VT7ResourceTrace.ps1`, `tools/Test-VT7ResourceTrace.ps1`. No application rebuild. |
| Worker retirement diagnostic | [Protocol, package and qualification](diagnostics/2026-09-13-resource-retirement.md), [sampler](../../src/vt7/VT7.ResourceRetirement/main.cpp), [collector](../../src/vt7/VT7.ResourceRetirement/retirement.cdb), [validator](../../src/vt7/VT7.ResourceRetirement/Validate-ResourceRetirement.ps1), [build helper](../../tools/Build-VT7ResourceRetirement.ps1), [package helper](../../tools/Package-VT7ResourceRetirement.ps1). New diagnostic only; native application payload unchanged. |

Current source-only managed isolation cases are `wpf`, `native-child`,
`hwndhost`, `native-child-software`, `native-parent`, `native-child-layered`
and `native-child-plateau` (300 cycles). They are not present in the issued
0.3.5 ZIP. No IME-disable case remains. Their retained source has local Debug
checks, not fresh Release/Windows 7 qualification.

## Build and test resumption

Use [BUILDING.md](../../BUILDING.md) for the complete prerequisites and commands.
The pinned developer tools are Visual Studio 2022/MSVC 14.44.35207, Windows SDK
10.0.26100.0 and .NET Framework 4.8 targeting files. Build on the development
machine, then validate the resulting artifact on Windows 7. This is a command
reference: select checks relevant to the next change, not an automatic request
to repeat every accepted suite. This diagnostic task did not rerun these
integrated application suites:

```powershell
.\tools\Build-VT7.ps1 -Configuration Debug
.\tools\Verify-VT7.ps1 -Configuration Debug
.\tools\Test-VT7.ps1 -Configuration Debug
.\tools\Test-VT7AtlasRepaint.ps1 -Configuration Debug
.\tools\Test-VT7AtlasRecovery.ps1 -Configuration Debug
.\tools\Test-VT7AtlasSettings.ps1 -Configuration Debug
.\tools\Test-VT7FontAssets.ps1 -Configuration Debug
.\tools\Test-VT7AtlasStability.ps1 -Configuration Debug
```

Build/restore can download pinned dependencies. Tests launch local processes and
overwrite their named report paths, so preserve earlier reports first. For the
known full lifecycle reproduction, use `-Lifecycle -Renderer atlas-d3d-warp`
on `Test-VT7AtlasStability.ps1`; its current failure is not a new regression by
itself. Do not add `-Soak` now. Read each negative-control verdict, not just a
generic search for `FAIL` across all reports. The viewport blank, repaint,
settings/font and idle negative tests intentionally reject their injected faults.

Unchanged post-warm-up investigation limits are +64 MiB private memory,
+32 handles, +8 threads, +16 GDI and +16 USER, sampled repeatedly. These are
test gates, not a claim that every smaller increase is harmless. Quick mode
has 8 measured lifecycles; full has 100/1,000/500 lifecycles/resizes/tab trips.
The extended active/idle profile is separate and has no results yet.

## Artifacts and evidence availability

The latest completed target capture uses `VT7-resource-retirement-0.1-x64.zip`. Its exact
size, hashes, provenance and local qualification are recorded in the
[retirement diagnostic record](diagnostics/2026-09-13-resource-retirement.md).
It preserves the earlier artifacts listed below. Its Windows 7 result is now
recorded; no unchanged rerun is requested.

| Artifact | Identity and scope |
| --- | --- |
| `VT7-atlas-viewport-0.3.4-x64.zip` | 10,523,404 bytes; accepted bounded scaling matrix, not complete renderer acceptance. |
| `VT7-atlas-viewport-0.3.5-x64.zip` | 10,541,563 bytes; Release ABI 8 investigation candidate, known WARP failure. |
| `VT7-resource-comparison-0.1-x64.zip` | 2,938,282 bytes; native-only Host plus exact issued 0.3.5 native/runtime/font/legal payload, not the WPF application. |
| `VT7-resource-lifetime-0.2-x64.zip` | 3,799,264 bytes; recreate/reuse measurements complete locally and on Windows 7. Both target modes grow; resource acceptance remains open. |
| `VT7-resource-trace-0.1-x64.zip` | 8,297,623 bytes; locally complete. Target preflight passes, but trace times out at an invalid-handle prompt before application work. Preserved, superseded by corrected trace 0.2. |
| `VT7-resource-trace-0.2-x64.zip` | 8,055,884 bytes; final packaged run passes locally under PowerShell 5.1. Target captures unhandled second-chance invalid handle during startup, before native DLL load or WARP work. Preserved. |
| `VT7-resource-trace-0.3-x64.zip` | 8,060,952 bytes; separate startup control and delayed handle tracing. Local and target captures complete. Issued target validator miscounts nested Token metadata; corrected offline validation accepts the preserved capture. ZIP unchanged. |

SHA256, in that order:

```text
9E112F6093FD0FBEEAA2409C655D9FEB7E22340F5823A8141FEE00C49E0A19CA
57B2EE43BB9A1AC6AB227B7C7BE4E3FCB88C765753FDEDD988E14EF375604C86
16A058CE3AA41D9D6829F1ACC357CE0CD4CC9128DE04F12D2F8914B16198118D
8F2F1014A96B1781486574E4FF92AD8B43823CB96EC90BA1A2E71B656C03F388
AAFA42259DDF706400F77DDC75BAF7F41BB9876960C2B740DF7484175A830033
0442029DC3BC4D4CFF89CE11089B16855E47C500146E962D8C55A751685E6D5D
E0DCA8AD0532E401903D46DE6E352303C56D9392DF0B613C40FC2AFDAB461059
```

The three earlier archives were rechecked unchanged during the 0.2 diagnostic
task; the new archive's entries were verified against its manifest. They are local
engineering artifacts under `artifacts/`, not public releases or Git-tracked
files. Issued source/provenance text inside a ZIP is a dated snapshot and is not
rewritten when the working documentation advances.

- Integrated target evidence: `artifacts/vt7/evidence/atlas-stability-win7-0.3.5/`.
- Native recreate/reuse target evidence:
  `artifacts/vt7/evidence/resource-lifetime-win7-0.2/resource-lifetime-20260913-144532-55a231c4/`.
- Supplied trace 0.1 timeout:
  `artifacts/vt7/evidence/resource-trace-win7-0.1/resource-trace-20260913-151714-26f04e23/`.
- Trace 0.1 local qualification:
  `artifacts/resource-trace-0.1/Logs/resource-trace-20260913-151421-516ac5a5/`.
  All 54 payload entries in the trace ZIP verified. The trace record includes
  60 validator fixtures, launcher failure controls and timeout cleanup evidence.
- Corrected trace 0.2 local qualification:
  `artifacts/resource-trace-0.2/Logs/resource-trace-20260913-155408-deb5c62b/`.
  All 57 archive entries and fresh extraction verified; handled, unhandled,
  repetition-limit and unexpected-prompt controls pass. The trace record
  preserves the separate exception fixture and 85 text-validation cases.
- Supplied trace 0.2 startup exception:
  `artifacts/vt7/evidence/resource-trace-win7-0.2/resource-trace-20260913-160144-8a929ea8/`.
  Preflight passes; first-chance context, normal dispatch and second-chance
  context are captured. The launcher correctly rejects collection despite
  CDB itself exiting zero after the explicit abort.
- Trace 0.3 final packaged qualification:
  `artifacts/resource-trace-0.3/Logs/resource-trace-20260913-161208-c026e689/`.
  Preflight, separate startup control, full trace and launcher pass. The trace
  reaches all six checkpoints with two setup events and zero invalid handles.
  All 59 checksum-listed payload files verify in the ZIP and fresh extraction.
  All 126 text-validation fixtures pass on PowerShell 2.0 and 5.1 against the
  final packaged logs, with transcripts retained in the archive audit directory.
  Preflight-only and startup-abort stage controls pass; the latter prevents
  the full trace from starting. Exact hashes and regression evidence are in
  the trace record. All earlier pinned archive identities remain unchanged.
- Supplied trace 0.3 and offline correction:
  `artifacts/vt7/evidence/resource-trace-win7-0.3/resource-trace-20260913-161711-9df20496/`;
  `artifacts/vt7/diagnostics/resource-trace-0.3-offline-revalidation-1789309290771-d8abc328/`.
  Corrected validator and fixture source snapshots, exact commands and all four
  137-case transcripts are retained. No runtime workload was launched to
  revalidate these logs. Derived identity/handle tables and exact symbols are
  linked from the trace record.
- Retirement 0.1 final local collector and offline validation:
  `artifacts/vt7/diagnostics/retirement-final-collector-qa-20260913-145800598-c35e2414/Logs/resource-retirement-20260913-165800-9ec8f673/`;
  `artifacts/vt7/diagnostics/retirement-validator-actual-20260913-170226/`.
  Three debugger stages complete on Windows 10 under PowerShell 2. The final
  history has 4,308 records; 184 offline checks pass on PowerShell 2 and 5.1.
  `TARGET_EVIDENCE=UNSUPPORTED` distinguishes this local qualification from
  the separate supplied Windows 7 result.
- Supplied retirement 0.1 target evidence is archived at
  [`artifacts/vt7/evidence/resource-retirement-win7-0.1/resource-retirement-20260913-170928-9ad405a7/`](../../artifacts/vt7/evidence/resource-retirement-win7-0.1/resource-retirement-20260913-170928-9ad405a7/).
  The user explicitly authorized copying the original K: run. All 17 files
  (7,310,791 bytes) match source sizes and SHA256 hashes, rechecked after copying;
  the original logs are unchanged. The separate
  [verification record](../../artifacts/vt7/evidence/resource-retirement-win7-0.1/ARCHIVE-VERIFICATION-20260913-152421-53a65b82.json)
  lists every archived file. This ignored artifact directory must be transferred
  separately for a fresh checkout.
  The [target result](diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result)
  records hashes, numerical findings and evidence limits.
- Earlier native power/plain evidence:
  `artifacts/vt7/evidence/resource-comparison-win7-0.1/resource-comparison-18452-32699/`.
- Local managed/native controls and CDB traces: `artifacts/vt7/diagnostics/`.
- Local integrated reports: `artifacts/vt7/reports/Debug/` and `Release/`.
- Versioned findings, hashes and limitations:
  [stability record](validation/2026-09-13-atlas-stability.md).
- Versioned native source/header/launcher, trace setup and latest target logs:
  [diagnostic appendix](diagnostics/2026-09-13-resource-investigation.md).

Full older raw traces, screenshots, binaries and PDBs still require a separate
artifact transfer. Do not say they are available from Git. The preserved source
allows a new diagnostic build, but compiler timestamps and environment mean it
is not the byte-identical issued executable. Assign it a new identity and qualify
its actual bytes. If source or a required artifact is missing, state that gap
instead of reconstructing a historical pass from memory.

Specific historical limits also remain: initial visible Atlas-backend logs
(848 hardware frames and 432 WARP frames) were overwritten by later same-name
R-key runs; only their documented totals survive unless a separate backup exists.
Some early probes identify a source base plus uncommitted changes, not a complete
rebuild manifest. Early ESU success was tester-confirmed without separate supplied
ESU logs or full update inventories. Do not retrofit stronger provenance into
those records.

## Before handing off again

Update this file, the applicable validation record and roadmap status together.
Record exactly what changed, source and artifact identity, configuration and
environment, passed/failed/incomplete/not-run cases, preserved evidence paths,
what remains unproven and one concrete next task. Keep the MIT and dependency
notices intact. Do not add an em dash. Do not commit generated artifacts or
private logs indiscriminately. Read [CONTRIBUTING.md](../../CONTRIBUTING.md) for
the full maintenance and provenance rules.

Earlier documentation audit checks: local Markdown paths/anchors, archived diagnostic
source and transcript consistency after line-ending normalization, no added em
dashes, diff whitespace and the comment-only renderer project XML change.
That documentation audit performed no application build or runtime test.
The later 0.2 diagnostic build and local checks are recorded separately in its
linked protocol. No security-setting change, upstream merge, commit or push is
part of the diagnostic task.
