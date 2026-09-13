# VT7 development handoff

Updated: 2026-09-13, after Windows 7 resource comparison 0.1 was reviewed.
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
| Latest target diagnostic | Native resource comparison 0.1 completes both modes on Windows 7; both modes grow. Measurement completion is not acceptance. |
| Next implementation | Proposed bounded recreate-versus-reuse control with individual thread identities. Not implemented yet. |
| Milestone 2 | Open. Theme/high-contrast, broader device/environment and milestone-level ESU coverage also remain. |
| After renderer qualification | C4/Milestone 3A session feasibility: local-console fidelity, OpenSSH byte/control paths, input and ownership/security contracts. Then application/session delivery. |

## Resume safely

1. Read this file, the [current validation record](validation/2026-09-13-atlas-stability.md),
   and the [port-first plan](architecture/2026-09-12-port-first-plan.md).
2. Inspect `git status --short`, `git branch --show-current` and `git log -1`.
   The user's development branch is `initial-implementation-and-assessment`.
   Do not switch branches, discard changes, merge upstream or commit/push merely
   as a resumption step. Preserve unrelated work.
3. At this audit, HEAD was `5692786b85bd96840a40a3a8839113aad52efb95`
   (`Add 0.3.5 scheduling and stability diagnostics`). The documentation audit
   adds further uncommitted guidance and snapshots. That commit is an orientation
   point, not an identity for these documentation edits or an issued package.
   Record the actual commit and dirty state for the next build.
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

Latest Windows 7 deltas from post-warm-up through the ten-second final
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

## The next bounded task

Question: does remaining resource growth depend on repeated surface lifetimes,
or also occur while one surface is reused, and which individual threads gain
input queues or leave retained resources?

Implement a separate diagnostic comparison, not a production renderer-policy
change. Keep explicit power subscriptions off in both modes, since they were
unnecessary for the Windows 7 result. Preserve current security/input settings.

- Match parent style, workload, warm-up, resize/hide/show operations, message
  pumping, sampling cadence and environment. Retain pre-warm-up samples.
- Use equivalent live-surface checkpoints in both cases, then matched final
  samples after the last surface is destroyed. Do not compare a live reused
  surface to a destroyed recreated surface and call the difference a leak.
- Record individual thread ID plus creation time, origin and queue status.
  Distinguish surviving threads acquiring queues from thread creation, turnover
  and numeric ID reuse. Report unavailable attribution without inventing it.
- Retain per-process handle, USER, GDI and private-memory totals. Keep sampling
  overhead and non-atomic snapshots explicit. A flat reuse case implicates
  repeated lifetimes, but also removes HWND/device/swap-chain/worker churn; it
  cannot alone establish harmless lazy initialization.
- Verify local operation and diagnostic failure/completion semantics, preserve
  prior packages, and issue a separately identified target candidate only when
  ready. Request only the bounded Windows 7 comparison and its full logs.
- Use the outcome to isolate ownership or establish an evidence-backed lifetime
  model. Then recheck the unchanged integrated profiles on both machines. Do
  not relax budgets, hide growth behind extra warm-up, suppress WARP workers,
  disable IME/accessibility/power behavior or run the timed soak as a substitute.

This is the next proposed implementation, not work performed by this handoff.
Stop the experiment when it resolves the named decision; do not extend the
research program for unrelated cosmetic findings.

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
to repeat every accepted suite. No tests were run by this documentation update:

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

| Artifact | Identity and scope |
| --- | --- |
| `VT7-atlas-viewport-0.3.4-x64.zip` | 10,523,404 bytes; accepted bounded scaling matrix, not complete renderer acceptance. |
| `VT7-atlas-viewport-0.3.5-x64.zip` | 10,541,563 bytes; Release ABI 8 investigation candidate, known WARP failure. |
| `VT7-resource-comparison-0.1-x64.zip` | 2,938,282 bytes; native-only Host plus exact issued 0.3.5 native/runtime/font/legal payload, not the WPF application. |

SHA256, in that order:

```text
9E112F6093FD0FBEEAA2409C655D9FEB7E22340F5823A8141FEE00C49E0A19CA
57B2EE43BB9A1AC6AB227B7C7BE4E3FCB88C765753FDEDD988E14EF375604C86
16A058CE3AA41D9D6829F1ACC357CE0CD4CC9128DE04F12D2F8914B16198118D
```

They were rechecked unchanged during this documentation audit. They are local
engineering artifacts under `artifacts/`, not public releases or Git-tracked
files. Issued source/provenance text inside a ZIP is a dated snapshot and is not
rewritten when the working documentation advances.

- Integrated target evidence: `artifacts/vt7/evidence/atlas-stability-win7-0.3.5/`.
- Latest native target evidence:
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

Documentation audit checks: local Markdown paths/anchors, archived diagnostic
source and transcript consistency after line-ending normalization, no added em
dashes, diff whitespace and the comment-only renderer project XML change.
The three issued archive hashes remain unchanged. No application build, runtime
test, security-setting change, upstream merge, commit or push was performed.
