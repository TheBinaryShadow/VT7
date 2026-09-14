# Integrated WPF resource reactivation 0.1

Date: 2026-09-14. This implements the user-approved follow-up to the
[Windows 7 retirement capture](2026-09-13-resource-retirement.md#supplied-windows-7-result).
It is a separate managed diagnostic using the real WPF application and the
unchanged issued native 0.3.5/ABI 8 payload. C3 remains open and the timed soak
remains on hold. A Windows 10 observation does not establish Windows 7 behavior.

## Question and fixed protocol

After one complete integrated work/close/idle round, does renewed activity raise
the resources retained in the equivalent late closed state? The earlier native
control observed worker retirement and Event closes, but did not answer this
question for the WPF application's actual window and surface lifetimes.

One process runs the following sequence, with Atlas D3D11 WARP forced and capture
readback enabled throughout the workload:

| Samples | Work or observation |
| --- | --- |
| 1 | Pre-warm-up, after the entry-point probe suite. |
| 2 | Closed after the original two warm-up window lifetimes, run once. This is the fixed budget baseline. |
| 3-6 | Round 1, closed after 25, 50, 75 and 100 measured lifecycles. |
| 7-9 | Round 1, closed +10, +90 and +180 seconds. |
| 10-13 | Round 2, closed after another 25, 50, 75 and 100 measured lifecycles. |
| 14-16 | Round 2, closed +10, +90 and +180 seconds. |

Both rounds use the same extracted `RunLifecycleCycle` method as the regular
integrated stability runner. Each repeats the round-local cycle-zero scheduling
suite: visible/hidden idle invariants, timer arm/cancel, explicit synchronized
output end, missing-end timeout, parked wake generations, producer notifications
and hidden output restoration. Every lifecycle keeps ten resizes, five tab
round trips, exact redraw checks and rotation through parked/active/hidden/
synchronized-wait close states. The totals are 202 window lifetimes including
warm-up, 200 measured lifecycles, 2,000 measured resizes and 1,000 measured tab
round trips. Native child HWND destruction is checked after every close, with
the original two-second shutdown limit.

The original entry-point probe suite runs once. The actual `MainWindow.Loaded`
probe suite still runs for every window, and ordinary status refreshes remain.
This retains the full host workload, including those hardware/WARP probes.
The new diagnostic routes ordinary `DiagnosticsLog` output to the run's
`reactivation.log.wpf-probes` directory. Its original per-second filenames and
update behavior remain; `reactivation.log` is the authoritative checkpoint log.
The regular host's compilation branch keeps its existing AppData log behavior.

The close origin is the completion of the last lifecycle, after dispatcher
drain and the destroyed-HWND assertion. Idle targets are measured from that
origin, not three successive additional delays. Ordinary asynchronous waits
keep the WPF dispatcher and application process alive. No periodic observer
polls a worker during the gaps; the next delay targets the next observation.
Checkpoint GC/finalizer/dispatcher draining and the existing 250 ms settling
delay remain, so resource timestamps are slightly later than their targets.

## Verdicts and evidence limits

Each quarter-batch checkpoint applies the original growth limits against sample
2: private bytes <=64 MiB, handles <=32, threads <=8, GDI <=16 and USER <=16.
Every immediate failure accumulates across both rounds. There is no replacement
baseline, extra warm-up, later pardon or budget widening. The original safety
ceilings stop collection at >=512 MiB private-byte growth or >=2,048 handle
growth. They also apply at the additional observation checkpoints.

Resource-budget failures permit continued observation within those safety
ceilings. Rendering, scheduling, pixel, operation-count, shutdown or collection
errors instead stop the run as incomplete. The collector distinguishes:

- Exit 0: all 16 samples collected and all eight immediate budgets met.
- Exit 3: all 16 samples collected, with immediate budget failures retained.
- Exit 1: incomplete collection, launcher failure or rejected evidence.
- Direct EXE exit 2: rejected arguments or output-file failure.

Neither complete outcome closes C3 or qualifies a timed soak. The validator
recomputes all eight verdicts and cumulative failures from the raw resources.
It checks sample/round order, operation and scheduling evidence, fixed baseline,
both sets of elapsed idle targets, every delta, thread histories and completion
versus process exit. Samples 2-16 compare with pre-warm-up; 3-16 also compare
with sample 2; sample 16 additionally compares with sample 9.

Each checkpoint adds own-process thread identities using nonzero TID plus
creation FILETIME. A temporary thread handle supplies process ownership,
creation time and zero-time liveness waits surrounding the optional start-address
and GUI-thread queries. The handle is closed before the row is logged and before
any idle wait. Only an identity live through those checks updates its history.
Rows retain unavailable/changed observations, raw queue errors and wait results.
Later missing identities are `NOT_OBSERVED`, not proof of exit or of a particular
handle's release. A failed GUI query is unavailable evidence, not proof that an
input queue does not exist. TID reuse with a different creation time is a new
identity. The sampler bounds each snapshot to 4,096 rows and retained history
to 8,192 identities; exhausting either makes collection incomplete.

Microsoft documents creation-time queries through
[GetThreadTimes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getthreadtimes)
and immediate liveness checks with a zero timeout through
[WaitForSingleObject](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitforsingleobject).
The optional start-address query uses runtime dynamic linking, as recommended
for [NtQueryInformationThread](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntqueryinformationthread).
[GetGUIThreadInfo](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getguithreadinfo)
is called only for a nonzero own-process TID with its structure size initialized.

Resource counters, helper-window summaries, old grouped thread origins and the
new identity inventory are sequential observations, not one atomic snapshot.
The observer itself allocates managed bookkeeping; compare equivalent states
within this diagnostic, not absolute totals with the native-only collector.
Module/offset labels are start-address context, not allocation ownership. This
diagnostic does not collect kernel handle types, OPEN/CLOSE histories or private
WARP cleanup hooks, and cannot attribute the residual handles by itself.

## Source, build and delivery

- [Diagnostic project](../../../src/vt7/VT7.ResourceReactivation/VT7.ResourceReactivation.csproj)
  explicitly compiles the actual host sources and XAML, plus a diagnostic entry
  point, two-round controller and checkpoint thread observer.
- [Shared lifecycle implementation](../../../src/vt7/VT7.Host/StabilityWindowChecks.cs)
  retains the original cycle body. `App.xaml.cs` and `DiagnosticsLog.cs` select
  the diagnostic entry point/log destination only under its compile symbol.
- [Build helper](../../../tools/Build-VT7ResourceReactivation.ps1) snapshots all
  compile inputs into a fresh directory. It pins .NET SDK 9.0.318 for SDK
  resolution, uses Visual Studio 2022 MSBuild/Roslyn and the .NET Framework 4.8
  targeting pack, and emits a Release AMD64 managed EXE. No native project
  reference or native rebuild occurs. The SDK is a developer build dependency;
  the target requires .NET Framework 4.8, not .NET 9.
- [Package helper](../../../tools/Package-VT7ResourceReactivation.ps1) requires
  `-BuildDirectory` and a `-QualificationDirectory` containing the recorded
  qualification. It verifies compiled-source/output identities, the full run,
  launcher/validator identities and every inherited file. It refuses an existing
  0.1 directory or ZIP. Previous and failed candidates remain preserved.
- [Target launcher](../../../src/vt7/VT7.ResourceReactivation/RUN-RESOURCE-REACTIVATION.cmd)
  selects 64-bit Windows PowerShell, checks package hashes and pins, starts one
  child with fixed arguments, and retains the complete run folder. The 2.0-
  compatible runner has a 2,400-second limit and terminates only its owned child
  on timeout. No debugger, symbol download or extra installation is required on
  the already configured Windows 7 machine.

The package is `artifacts/VT7-resource-reactivation-0.1-x64.zip`; the extracted
directory is `artifacts/resource-reactivation-0.1`. Only this package's
`RUN-RESOURCE-REACTIVATION.cmd` is its entry point. Other old launchers and the
original host EXE are mapped under provenance. Native/runtime/fonts, notices,
licenses and native symbols retain their required paths and exact bytes.

The diagnostic EXE SHA256 is
`324D29DE31F3B5A10F802D6C0BEA9603EE07098C61F47996C9398BACEC45F843`;
its portable PDB is
`37D1647198BD90DFD6384EE9EE55248EA23DE76EEA4A85036CC6591B72DE1BD0`.
The issued native DLL remains
`0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49`,
with matching native PDB
`C835ED74D7E119F0601AD1CE1DE8A70349BADD443D041E467756705CC8B6AAEE`.
The original viewport ZIP remains
`57B2EE43BB9A1AC6AB227B7C7BE4E3FCB88C765753FDEDD988E14EF375604C86`.

Build source HEAD is `8b10540e56c3d59f453ac6c3e363a9ec9e562b9f` plus the
recorded uncommitted diagnostic changes. Full input snapshots, individual hashes,
build log/binlog and Git status are retained; HEAD alone does not identify this
new executable. The final build is
`artifacts/vt7/diagnostics/resource-reactivation-build-20260914-004057921-807ea4d86d6b45c591188efbca569eb7/`.
After package sealing, the repository copies of `App.xaml.cs` and
`StabilityWindowChecks.cs` were restored from CRLF to their original LF line
ending convention. Their text is otherwise identical to the qualified source;
the [normalization record](../../../artifacts/vt7/diagnostics/reactivation-qualification-20260914-004826-6471060f/WORKSPACE-EOL-NORMALIZATION.json)
records both hashes. The exact compiled CRLF snapshots, EXE/PDB and sealed ZIP
remain untouched. Use those frozen snapshots for the issued byte identities.

## Local qualification and handoff

The sealed ZIP is 12,594,289 bytes, SHA256
`4308FFD8792B82F84D1D88BD9D98B489CEBE15DA0289148DFCB5BF97CA5B0A51`.
Its `SHA256SUMS.txt` is
`5D87ABB55F00CEAF24BF708221279C919E173BF1A3A569B09DFD69BC8CBF9417`.
All 353 ZIP files match the assembled package and an independent fresh
extraction, including all 352 checksummed files and the checksum file itself.
An attempted second packaging invocation correctly refuses the existing
candidate before writing. No issued viewport or earlier diagnostic was replaced.

The full managed-EXE run completed on Windows 10.0.19044 x64 with .NET Framework
4.8.9339.0, using forced Atlas WARP; the graphics probe reports an RX 7900 XTX.
PID 35812 and creation FILETIME 134338200920943416 match the launcher metadata.
Elapsed time was 963.503 seconds. Both scheduling suites, all 200 measured
lifecycles, 2,000 resizes and 1,000 tab trips completed; worst close was 102 ms.
All eight immediate budget checks failed and remain failures in the exit-3
complete report. This is diagnostic qualification, not C3 acceptance.

| Sample / state | Handles | Threads | GDI | USER | Private bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1, pre-warm-up | 300 | 9 | 0 | 6 | 52,191,232 |
| 2, fixed warmed baseline | 906 | 45 | 6 | 14 | 135,753,728 |
| 3, round 1 / 25 | 948 | 46 | 6 | 32 | 134,926,336 |
| 4, round 1 / 50 | 972 | 44 | 6 | 41 | 179,810,304 |
| 5, round 1 / 75 | 979 | 43 | 6 | 42 | 158,265,344 |
| 6, round 1 / 100 | 989 | 44 | 6 | 44 | 162,095,104 |
| 7, round 1 / closed +10s | 989 | 44 | 6 | 44 | 127,361,024 |
| 8, round 1 / closed +90s | 975 | 42 | 6 | 42 | 127,262,720 |
| 9, round 1 / closed +180s | 881 | 8 | 6 | 10 | 125,849,600 |
| 10, round 2 / 25 | 943 | 43 | 6 | 31 | 167,759,872 |
| 11, round 2 / 50 | 961 | 43 | 6 | 37 | 173,772,800 |
| 12, round 2 / 75 | 977 | 44 | 6 | 41 | 166,895,616 |
| 13, round 2 / 100 | 989 | 44 | 6 | 44 | 173,764,608 |
| 14, round 2 / closed +10s | 989 | 44 | 6 | 44 | 131,297,280 |
| 15, round 2 / closed +90s | 885 | 9 | 6 | 11 | 129,699,840 |
| 16, round 2 / closed +180s | 883 | 9 | 6 | 11 | 129,695,744 |

Round 2's +180s state exceeds round 1's equivalent state by two handles, one
thread, one USER object and 3,846,144 private bytes, with unchanged GDI. Only six
of the 45 fixed-baseline thread identities are observed live at either +180s
checkpoint. Queue-positive observations fall from 38 after each batch to four
and five at those late samples. Every thread row in this actual capture has
successful identity/liveness inspection; failed GUI queries remain unavailable.
The unequal +90s behavior also shows why the earlier timeout value must not be
treated as a release deadline. This one pair does not prove continuing residual
growth, a fixed harmless bound, handle ownership or Windows 7 behavior.

The complete report is
[`reactivation-test-full-20260914-004132078-38809b934ce5425881e5276e7e78ffe6/reactivation.log`](../../../artifacts/vt7/diagnostics/reactivation-test-full-20260914-004132078-38809b934ce5425881e5276e7e78ffe6/reactivation.log),
SHA256 `6831850801E4ADBFDAAE60AC3C0CBB7F9FAC98B987B5FA1AB84813564F1E9F83`.
The [sealed qualification manifest](../../../artifacts/vt7/diagnostics/reactivation-qualification-20260914-004826-6471060f/QUALIFICATION.json)
lists 273 evidence files and their hashes. The package preserves them under
`provenance/qualification/`, including the real full run and ordinary host logs.
The [extraction verification](../../../artifacts/vt7/diagnostics/reactivation-qualification-20260914-004826-6471060f/EXTRACTION-VERIFICATION.json)
records the independently checked archive. Local `artifacts/` contents are
ignored by Git and are absent from a fresh clone.

Additional qualification:

- Exact source comparison against HEAD verifies that the shared cycle is the
  original body extracted into a method; resource budgets and normal app/log
  compilation branches are unchanged. Both managed builds have zero warnings
  and errors. The diagnostic is AMD64, IL-only, assembly 0.1.0.0 and net48; its
  managed assembly references exactly match the issued host. Its portable PDB
  GUID/stamp matches the EXE's CodeView data (GUID
  `7086AC1A-19CA-4667-8415-B24347AC9370`, stamp 2866476007, age 1).
  Actual Roslyn is 4.1400.26.42407; exact compiler identity and P/Invoke inventory
  are in `managed-audit.json` within qualification evidence.
- Actual `work-negative` and `idle-negative` runs exit 1 with the intended
  workload/idle-invariant errors and incomplete collection. Neither produces a
  completed verdict. The preserved regular host separately passes quick hardware
  and WARP checks (8/80/40 per backend), and detects its original idle-negative
  control. Its separate qualification binary is not the delivered diagnostic.
- Actual Windows PowerShell 2.0 and 5.1 both accept the complete real capture,
  accept two explicitly synthetic validator controls and reject 22 altered
  reports/exit contradictions. The synthetic controls exercise all-budgets-pass
  exit 0 and thread-query uncertainty, later absence and same-TID/new-creation
  histories; they are labeled and are not runtime evidence.
- Both shells pass 16 CLI/launcher/wait controls: missing/duplicate/conflicting
  arguments, forbidden protocol overrides, preserving an existing report,
  preserving exits 0/3, bounded termination of only an owned child, and refusing
  corrupt, missing, traversing or duplicate package checksums before launch.
  Qualification caught PowerShell 2 returning 0 from an advanced script despite
  explicit exit; the distributed runner uses a plain script and checks its
  argument list explicitly. Its error exit now survives under both shells.
- The full workload ran through the developer process runner using the exact
  delivered EXE/native bytes. The distributed runner's component controls and
  validator were qualified separately; the complete distributed launcher was
  not rerun end-to-end locally. The supplied Windows 7 run below subsequently
  completed through the distributed launcher.

Early failed build/qualification attempts remain in their original fresh
directories, including sandbox SDK discovery, build argument quoting and the
PowerShell 2 exit-policy investigation. They are not substituted for the final
qualified results and no partial candidate was silently overwritten.

## Supplied Windows 7 result

The returned `resource-reactivation-20260914-032308-629f4198` run completes the
requested two-round control. It ran on Windows 7 SP1 x64, .NET Framework
4.8.4795.0 and Windows PowerShell 5.1.14409.1005. The adapter probe reports the
RX 6800 XT; the Atlas workload is forced to D3D11 WARP. Companion logs report
96 DPI. System WARP is 6.2.9200.22592, SHA256
`35979BAF3D0538E74EE7E114F96D33A9558C0A4FE06E5A5D6FBFCCFB27794EDB`.
PID 10592 and creation FILETIME 134338225891220357 agree between launcher and
report. Elapsed time is 655.156 seconds, approximately 10 minutes 55 seconds.

Both scheduling suites, 200 measured lifecycles, 2,000 resizes and 1,000 tab
round trips complete. Worst close is 8 ms. All 16 samples validate, with no
unavailable thread identity/liveness rows. The 202 companion WPF proof reports
all say `Passed: True`, `Error: None`, ABI 8 and Atlas D3D11 WARP; their hardware
and WARP feature-level 11.0 probes succeed. These files retain the original
per-second overwrite behavior, so the authoritative workload count comes from
the validated main report. Exit 3 means complete collection with three failed
immediate resource checkpoints, not an incomplete trace or accepted C3.

| Sample / state | Handles | Threads | GDI | USER | Private bytes | Positive queue queries |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1, pre-warm-up | 224 | 10 | 9 | 6 | 39,919,616 | 2 |
| 2, fixed warmed baseline | 1,372 | 48 | 18 | 43 | 124,948,480 | 36 |
| 3, round 1 / 25 | 1,390 | 53 | 18 | 51 | 134,377,472 | 44 |
| 4, round 1 / 50 | 1,395 | 54 | 18 | 52 | 134,955,008 | 45 |
| 5, round 1 / 75 | 1,402 | 55 | 18 | 54 | 136,396,800 | 47 |
| 6, round 1 / 100 | 1,408 | 55 | 18 | 54 | 138,731,520 | 47 |
| 7, round 1 / closed +10s | 1,408 | 55 | 18 | 54 | 138,457,088 | 47 |
| 8, round 1 / closed +90s | 1,320 | 13 | 18 | 12 | 136,495,104 | 5 |
| 9, round 1 / closed +180s | 1,314 | 13 | 18 | 10 | 136,495,104 | 3 |
| 10, round 2 / 25 | 1,390 | 55 | 18 | 54 | 138,485,760 | 47 |
| 11, round 2 / 50 | 1,394 | 56 | 18 | 54 | 138,805,248 | 47 |
| 12, round 2 / 75 | 1,401 | 57 | 18 | 55 | 138,973,184 | 48 |
| 13, round 2 / 100 | 1,406 | 57 | 18 | 56 | 139,042,816 | 49 |
| 14, round 2 / closed +10s | 1,406 | 57 | 18 | 56 | 138,772,480 | 49 |
| 15, round 2 / closed +90s | 1,325 | 14 | 18 | 12 | 136,761,344 | 5 |
| 16, round 2 / closed +180s | 1,314 | 13 | 18 | 10 | 136,720,384 | 3 |

The exact immediate failures against sample 2 are:

| Checkpoint | Exceeded growth limits |
| --- | --- |
| Round 1 / 100 | Handles +36, limit +32. |
| Round 2 / 75 | Threads +9, limit +8. |
| Round 2 / 100 | Handles +34, limit +32; threads +9, limit +8. |

The other five immediate checkpoints pass. Private bytes, GDI and USER remain
within their original budgets at all eight checks. Later reductions do not
replace these verdicts.

### Equivalent late states and identities

Between the two +180s observations, handles, threads, GDI and USER have exactly
zero count growth. Private bytes increase by 225,280 bytes, or 220 KiB. Thus
renewed activity does not raise those four late counts in this target run.
The late states are below the original warmed baseline by 58 handles, 35
threads and 33 USER objects, with unchanged GDI. The final private-byte delta
against that baseline is +11,771,904 bytes.

The thread identity sets are not identical: nine of the 13 identities are
common to both late samples and four differ. Seven original sample-2 identities
are live at both late checkpoints. The four replacements have the same start-
address groups: two `ntdll.dll+F8DE0`, one `clr.dll+8780` and one
`clr.dll+BC90`. The grouped start-address/queue observations match at the two
late samples, including three positive queue queries. The report also records
TID 6548 with two distinct creation times across the run, confirming why TID
alone must not be used as an identity. Full rows are in the analysis artifact.

The `ntdll.dll+F8DE0` group has 35 identities at baseline, 29 queue-positive.
It has 41 identities with 40 positive queue queries at round 1 / 100, and 43
with 42 positives at round 2 / 100. At each corresponding +180s sample, only
one identity from that end-of-work group is still observed: TID 9556, creation
`01DD43E79A4E6D6C`. That identity has no positive GUI-query observation in the
capture. None of the 40 or 42 end-of-work queue-positive identities appears at
its round's late checkpoint. The late group consists of three identities with
GUI queries unavailable, not proven queue absence.

Together with the earlier native capture's direct Event-close evidence, this
supports idle retirement as an explanation for much of the integrated transient
growth. The new run itself supplies sequential snapshots, not worker-exit
events or handle OPEN/CLOSE histories. Module offsets alone do not establish
resource ownership. Equal handle counts can conceal replacement of handles,
and one pair of late samples does not establish a permanent bound.

There is still a substantial initialized-process residual: the final sample
is 1,090 handles, three threads, nine GDI objects, four USER objects and
96,800,768 private bytes above pre-warm-up. This includes full WPF/framework,
per-window probe and diagnostic-observer effects; it cannot be attributed
entirely to WARP or compared directly with the native-only residual of 54
handles. The Windows 10 pair above also remains distinct evidence, with its
small positive late-count deltas. Neither result overrides the other.

### Archive and independent validation

All 207 returned files, totaling 883,594 bytes, are preserved in the
[local evidence archive](../../../artifacts/vt7/evidence/resource-reactivation-win7-0.1/resource-reactivation-20260914-032308-629f4198/).
Every length and SHA256 was checked against the original K: run, with source
hashes rechecked after copying. The originals are unchanged. The
[original inventory](../../../artifacts/vt7/evidence/resource-reactivation-win7-0.1/ARCHIVE-VERIFICATION-20260914-015018-0563ca2a.json)
retains every per-file length and hash; its aggregate `TotalBytes` is null due
to a metadata summation error. The
[supplement](../../../artifacts/vt7/diagnostics/reactivation-win7-analysis-20260914-035352-1bca9b9a/ARCHIVE-SUPPLEMENT.json)
reverifies the local files and supplies the explicit sum without altering that
record or the raw evidence.

The main report SHA256 is
`168C44C2C17BFAA9B1360669D76136BD742DF8926F3ED7247E3D3507BB923C35`.
The returned manifest, checksum list and validator match the sealed issued
package byte for byte; the validator also matches the repository source.
The issued ZIP still has SHA256
`4308FFD8792B82F84D1D88BD9D98B489CEBE15DA0289148DFCB5BF97CA5B0A51`.
The completed launcher attests its package preflight. Target executable/DLL
copies were not supplied in this log folder, so this is not an independent
rehash of the target's loaded binaries.

The trusted repository validator independently accepts the archived report
under Windows PowerShell 5.1 with exit 3, three failures and matching PID; its
[result](../../../artifacts/vt7/diagnostics/reactivation-win7-analysis-20260914-035352-1bca9b9a/VALIDATION-PS51.json)
records the exact validator/report hashes. A separate Python analysis recomputes
all eight budgets, the resource deltas, identity intersections, process metadata
and companion proof results. Its [script and outputs](../../../artifacts/vt7/diagnostics/reactivation-win7-analysis-20260914-035352-1bca9b9a/)
are preserved separately from the raw logs. These ignored local artifacts are
not included in a fresh Git clone.

### Initial recommendation after this capture

The recommendation below preceded the owner's development-risk decision and
is retained as history. It is superseded for execution by
[REL01](../architecture/2026-09-14-warp-development-deferral.md): stop dedicated
tracing, proceed to C4/3A, and revisit only when evidence or release review needs
it. The original budgets and failed results remain unchanged. No new test or
soak is requested. Milestone 7 tracks reliability review, not cosmetic polish.

The requested Windows 7 control is complete; an unchanged rerun is unnecessary.
The useful next investigation is the identity and ownership of retained handles
in the integrated process, comparing initialization, end-of-work and equivalent
late states. A focused handle-type inventory can guide which lifetime paths
need tracing, and whether a correction or an evidence-backed acceptance-policy
change is appropriate. Extra observation must account for its own resource and
timing effects. This is a proposed direction, not a new diagnostic build or a
budget change. C3 remains open, the original immediate failures stand, and the
timed soak remains on hold.
