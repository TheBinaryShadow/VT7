# Focused resource retirement diagnostic 0.1

Date: 2026-09-13. This implements the bounded follow-up from the
[WARP pool inspection](2026-09-13-warp-pool-lifetime.md). The supplied Windows 7
collection completes; its [result](#supplied-windows-7-result) confirms work
cleanup and retirement of all 34 baseline Windows workers by the 90-second
checkpoint. This diagnostic does not change the application renderer or its
integrated resource budgets, and is not the timed soak.

## Question and controlled workload

Does the target execute WARP's default-pool branch and complete work cleanup,
and do the surviving Windows worker identities and associated resources retire
after a longer idle period? Trace 0.3 retained them at ten seconds, while its
factory reported a 67-second idle timeout. That field is not a promise that
every worker or resource disappears at that deadline.

The new standalone EXE preserves the previous reused-surface workload: forced
WARP, two warm-up plus 25 measured iterations, one surface creation/destruction,
270 resizes, 27 size resets, 135 hide/show trips, and no power registrations.
It preserves the normal input/IME/security and native threading behavior.
The issued native 0.3.5 Release/ABI 8 DLL, runtime and fonts are reused unchanged.

There are eight checkpoints: pre-warmup, warmup-live, baseline-live,
measured-live at iteration 25, final-closed, and final-closed at 10/90/180 seconds.
The last three waits pump the ordinary message loop for 10, 80 and 90 seconds.
Checkpoint and sampler overhead is additional, so labels are observation targets,
not promises of exact wall times. Each wait logs its start, end, requested and
observed duration. Resource and thread snapshots remain sequential, not atomic.

## Binary identity and source

| Input | Identity |
| --- | --- |
| New EXE | `VT7.ResourceRetirement.exe`, diagnostic 0.1, x64; 164,864 bytes; SHA256 `9F07A67AC9A4B0226BAFD1E313E47DF2D9D426C5A0555377B6AD647A3F886FD4` |
| New PDB | SHA256 `CDA8F9C462B0DC89CF2D571B3AC27F4696F31774EEA18E5B9616B140261F97E0`; GUID `59868A29-3BE1-41EE-B7BF-DC7860952695`, age 1 |
| Unchanged native DLL | 0.3.5 Release, ABI 8; SHA256 `0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49` |
| Unchanged native PDB | SHA256 `C835ED74D7E119F0601AD1CE1DE8A70349BADD443D041E467756705CC8B6AAEE`; GUID `ED268A2C-CE8E-4B5B-8549-1DD819575BAD`, age 15 |

The build uses pinned MSVC 14.44.35207 and SDK 10.0.26100.0, x64, static release
CRT, `/W4 /WX`, and subsystem/OS version 6.1. Raw PE/PDB parsing and installed
DbgHelp independently match the new EXE/PDB. The new exported, non-inlined
`VT7RetirementSample` has x64 RCX=phase, EDX=iteration, R8B=live. The debugger
uses that export, checked against its private PDB, instead of reusing the old
executable's private RVA. Its observed RVA is 1AB0 for these exact bytes.

Build evidence is retained under
`artifacts/vt7/diagnostics/resource-retirement-build-20260913-144824654-6e76aaf42ca2491aa4c73d61279c5d05/`.
The manifest records HEAD, dirty state, compiler identity/arguments and actual
source snapshots. Build version or Git HEAD alone is not a binary identity.

Sources are [main.cpp](../../../src/vt7/VT7.ResourceRetirement/main.cpp),
[build helper](../../../tools/Build-VT7ResourceRetirement.ps1),
[runner](../../../src/vt7/VT7.ResourceRetirement/Run-ResourceRetirement.ps1),
[validator](../../../src/vt7/VT7.ResourceRetirement/Validate-ResourceRetirement.ps1),
and [packager](../../../tools/Package-VT7ResourceRetirement.ps1).
Each build gets a fresh directory. The packager requires `-BuildDirectory`,
checks the frozen build against current source, and refuses an existing 0.1
directory or ZIP. A later rebuild requires intentional new identity and runner
pins; never replace an earlier candidate.

## Collection protocol

The PowerShell 2.0-compatible launcher verifies all package hashes and the
explicit EXE/PDB/native pins. It copies the six CDB command files into a fresh
Logs directory and rehashes those copies. CDB's working directory is that Logs
directory, so nested scripts execute the frozen copies. The EXE, native DLL and
private symbol paths are absolute. Inherited symbol/source server paths are
cleared, and no Windows symbols are downloaded during collection.

There are three separate child processes: debugger preflight, startup control,
then the full retirement trace. The first two have 60-second limits; the full
trace has a 600-second limit. The startup control stops at the exported sample
entry before surface creation, with no setup hook or NT handle tracing. The
full trace retains early USER32 setup observations but enables handle tracing
at pre-warmup after startup, following the working trace 0.3 arrangement.

The loaded WARP image is checked before any private breakpoint is armed.
The guarded profile is x64 D3D10Warp 6.2.9200.22592, timestamp 5BB78029,
image size 279000, checksum 281E7F, CodeView GUID
7394E810-65DA-4871-9C24-1F1987154DDF age 1. The gate checks those header/CodeView
fields and 28 DWORDs of instruction data at hook and related field-use sites.
It is a layout guard, not full loaded-image integrity attestation. The launcher
also records the system WARP file's path/version/SHA256 for comparison with the
actual loaded-module record. No system DLL is replaced or copied into the package.

A different PE profile produces `TARGET_EVIDENCE=UNSUPPORTED` and can complete
generic resource collection without private hooks. Matching PE metadata but
different CodeView/instruction bytes aborts before those hooks are armed. A
matched trace needs consistent initialization, mode/device/wrapper/work fields,
one callback observation, callback-drain return, work-close return, any required
private-pool close, cleared slots after cleanup return, and successful wrapper
free. The callback hook is intentionally one-shot, not a callback census.
Initialization and cleanup observations are capped at 128 records.

Before post-close waits, the collector disables USER32 setup and removes private
ownership breakpoints. It also clears the WARP load-event command explicitly;
changing break status alone does not remove an event command. Only checkpoint
and process-exit hooks remain as planned stops. Windows still delivers ordinary
debug events, and elapsed ticks include time suspended by the debugger. These
are measurements under a debugger, not exact uninterrupted idle-time proof.
The relevant behavior is documented in Microsoft's
[event-command semantics](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/sx--sxd--sxe--sxi--sxn--sxr--sx---set-exceptions-).

Each checkpoint captures full handle inventory and native resource/thread rows.
Five htrace intervals cover baseline-to-25, close, 10, 90 and 180 seconds, with
fresh snapshots between them. The final checkpoint additionally dumps all
retained OPEN/CLOSE/BADREF histories through `!htrace 0 0x10000`, before final
module inventory. Parsed, dumped and actual entry counts must agree and remain
below the 65,536-record capacity. Missing data, overflow or reaching that capacity
cannot pass as complete history. The original source logs remain authoritative;
numeric handle values alone are not continuous kernel-object identity proof.
See Microsoft's [htrace contract](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-htrace).

First-chance invalid handles during startup/live work retain the existing own-
context capture and normal `gn` dispatch. Second chance, the 16th event,
unexpected interactive stops, and collection errors abort with partial logs.
An invalid handle during idle observation aborts immediately after its context
is captured. No exception is silently marked handled, and no function is called
inside a stopped Windows worker to force resource release.

## Qualification

| Check | Result and scope |
| --- | --- |
| Pinned build / PE / symbols | Pass, new EXE/PDB identity above; no native rebuild. |
| Sampler negative controls | 13 cases pass in current PowerShell and actual Windows PowerShell 5.1, including invalid modes/durations and cleanup after an injected live-work failure. |
| Validator controls | 181 synthetic/adversarial cases plus all three final collector logs pass under actual PowerShell 2 and 5.1: 184 cases in each run, empty stderr. SDK 8.1's 65-entry real full-history output also parses. |
| Guard/hook fixture | Five cases pass with SDK 8.1 CDB 6.3.9600.16384 under PowerShell 5.1: matched layout, bad instruction bytes, bad CodeView, unsupported metadata, event cap; field extraction, one-shot callback and idle event-command clearing checked. |
| Exception policy | Nine SDK 8.1 cases pass under PowerShell 5.1: startup/live handled dispatch, unhandled second chance and 16-event caps, live checkpoint 4 dispatch, and idle checkpoints 5/8 capture then abort before the fixture handler executes. |
| Unexpected-stop fallback | Actual PowerShell 2 and 5.1 capture the stop context and quit before application work; validator rejects the incomplete trace. Captured elapsed times are 116 and 101 ms respectively. |
| First collector development run | Windows 10 / PowerShell 5.1 completes all eight checkpoints and normal exit, no invalid handles. It predates final full-history capture and is not the final collector identity. |
| Final collector | Windows 10 / actual PowerShell 2 completes preflight, startup and all eight checkpoints with CDB exit 0, zero invalid handles and 4,308 full-history records. The three measured wait segments are exactly 10,000/80,000/90,000 ms. `TARGET_EVIDENCE=UNSUPPORTED` correctly distinguishes this host's WARP version. |
| Issued ZIP | Two independent audits verify all 81 files, 80 checksum entries and 38 inherited file mappings. Runtime sources match the final collector run. Fresh extraction passes preflight under PowerShell 5.1/SDK 8.1 CDB; an attempted second packaging invocation refuses existing outputs without modifying them. |
| Windows 7 target | Supplied run completes all eight checkpoints, matched private profile, normal exit and zero invalid handles. Work cleanup returns; all 34 baseline pool-worker identities retire by 90 seconds. Resource acceptance remains separate; see the result below. |

The hook fixture maps Microsoft PE headers/sections into non-executable data
memory and uses synthetic wrapper/device/work objects. It does not execute
Microsoft WARP code. It checks the production guard and command extraction,
not actual Windows 7 callback timing or cleanup. The initial fixture found a
semicolon in a CDB comment that became a command when the nested script folded
lines; that source was corrected and the fresh fixture passed. Failed attempts
remain retained separately.

Additional evidence directories under `artifacts/vt7/diagnostics/`:

- `retirement-debugger-hooks-20260913-145944589-2b680172744c49aebe0ece9a77ee4962/`:
  exact production script snapshots, fixture source/compiler inputs and five
  CDB transcripts, RESULTS.json SHA256
  `540773775B9B8C56A9133731F3A8925CA067AABE34339DB7BF172EE40975AF99`.
- `retirement-validator-20260913-165701/`: PowerShell 2/5.1 validator transcripts.
- `retirement-validator-actual-20260913-170226/`: final actual-log and synthetic
  results, 184 cases each under PowerShell 2/5.1.
- `retirement-exception-policy-20260913-150230772-0c33e54d24ab46d387e5a85a2bbb2c2a/`:
  nine exception cases; RESULTS.json SHA256
  `50441A0F694ADA557DC97D7D5F3615885D5B237964B8D677155AB2A8BB0CD2E9`.
- `retirement-fallback-20260913-150154-b102454a/` and
  `retirement-fallback-20260913-150200-63ab5610/`: PowerShell 2/5.1 fallback controls.
- `resource-retirement-sampler-tests-20260913-145106918-38dcbae9cf734d2a9676bb5940dcb617/`:
  PowerShell 5.1 sampler negative controls and staged unchanged native assets.
- `retirement-collector-qa-20260913-145325849-a68a6c76/`: first development run.
- `retirement-final-collector-qa-20260913-145800598-c35e2414/`: final collector
  snapshots and Logs, with full history enabled.

The final run is `resource-retirement-20260913-165800-9ec8f673`. Its combined
retirement log SHA256 is
`F49119026855E312D6D6AD8B57BAF0D07619352B43724CAAC3B735D70F0B4EA8`;
summary SHA256 is
`5FCDDBDB00D97CD4E24CE926D3A54A857337053EDBFE54FC43EFFF6EC6BA11D6`.
Both initial-stage stderr files and retirement stderr are empty. Source/runtime
hashes identify this qualification independently of the final ZIP wrapper.

Assembly evidence is retained in
`retirement-package-assembly-20260913-150544870-ba96a652/`. The independent ZIP,
provenance, qualified-source and overwrite-refusal audit is
`retirement-issued-audit-20260913/PACKAGE-AUDIT.json`. That directory also holds
the freshly extracted archive and preflight run
`resource-retirement-20260913-170722-f94a1d08`, with launcher/debugger exit 0.
All these directories are under `artifacts/vt7/diagnostics/`. The issued lifetime
0.2 and trace 0.3 archive hashes still match their preserved identities.

## Issued target handoff

The issued candidate is
[`VT7-resource-retirement-0.1-x64.zip`](../../../artifacts/VT7-resource-retirement-0.1-x64.zip),
9,291,976 bytes, SHA256
`71460374C301D9606121D8660A610630F012579030A223E4DC516563679DA43C`.
Its `SHA256SUMS.txt` hash is
`0EE826A21B443DBE87FE330B5A63027A2531E37D61DE2071F8ECF96F6CF7703E`:
80 checksum entries, 81 ZIP files (92 entries including directories).

The supplied run below completes this handoff. These instructions remain for
reproduction; no unchanged repeat is requested.

Preserve existing packages and logs. Extract it into a new local folder on Windows 7,
run `RUN-RESOURCE-RETIREMENT.cmd`, allow approximately four to six minutes, and
return the entire new `Logs/resource-retirement-...` folder, including partial
logs on failure. Keep the existing working SDK 8.1 debugger and normal system
settings. No Visual Studio or PowerShell installation change is needed.

The results must be reviewed for actual mode/work cleanup, worker identity
retirement, and matching resource histories. Retirement and resource release
would support a lifetime explanation for this control, not accept the integrated
application. Retention at 180 seconds would remain unresolved, not automatically
prove an unbounded leak. C3 resource qualification remains open and the integrated
timed soak stays on hold.

## Supplied Windows 7 result

The supplied run is `resource-retirement-20260913-170928-9ad405a7`, originally
read directly from `K:/VT7_work/Logs/`. After the user's explicit copy request,
the complete run was archived at
[`artifacts/vt7/evidence/resource-retirement-win7-0.1/resource-retirement-20260913-170928-9ad405a7/`](../../../artifacts/vt7/evidence/resource-retirement-win7-0.1/resource-retirement-20260913-170928-9ad405a7/).
All 17 files, totaling 7,310,791 bytes, match the source by size and SHA256;
the source hashes were rechecked after copying and the original logs remain
unchanged. The separate
[archive verification record](../../../artifacts/vt7/evidence/resource-retirement-win7-0.1/ARCHIVE-VERIFICATION-20260913-152421-53a65b82.json)
records every file's relative path, size and hash, both locations and the copy
time. The archive is local ignored evidence under `artifacts/`, so a fresh Git
checkout still requires an artifact transfer. An independent check of the local
archive verifies all 17 file identities and passes preflight, startup and
retirement text validation with `SUPPORTED` status. It launches no debugger or
application workload. The following are derived observations, not replacement
transcripts.

| Supplied file | SHA256 |
| --- | --- |
| `retirement-combined.log` (3,602,095 bytes) | `DD20EAB4F24F214433A08E1F66256935B6A465A8E6ADD6A2934EF620BB888A29` |
| `summary.txt` | `F2634B4CE2FC6D8C7B1729ECE5F22521B46C2C764282B5AEDB1FBC1D42DFA961` |
| `preflight-combined.log` | `8729B12A0C4C22715B64E3C133868FBCDFD8777F1D6345E43B561C8420122744` |
| `startup-combined.log` | `D4B212BA130166603B045765151C755A34FA80A08A1087893317FBC416BFC5A6` |
| `package-SHA256SUMS.txt` | `0EE826A21B443DBE87FE330B5A63027A2531E37D61DE2071F8ECF96F6CF7703E` |

The package manifest hash and all six supplied CDB script hashes match the issued
archive. The launcher reports Windows 7 SP1 build 7601 x64 and PowerShell
5.1.14409.1005, using the existing SDK 8.1 debugger. Preflight, startup and
retirement debugger exits are zero, all three stderr files are empty, and the
launcher records complete supported collection with zero invalid handles.
Independent read-only validation of all three logs using the repository
validator also passes, reporting a supported target profile.

The system WARP file SHA256 is now directly recorded as
`35979BAF3D0538E74EE7E114F96D33A9558C0A4FE06E5A5D6FBFCCFB27794EDB`, matching
the previously inspected Microsoft image. The actual module record names the
same System32 path and the guarded 6.2.9200.22592 image/CodeView identity
(lines 741-782). The guard passes before private hooks are armed. This does not
assert a hash of every in-memory module byte.

### Actual WARP work lifetime

Lines 797-800 record one wrapper at `0x3893C0`, device `0x395C78`, mode 3,
successful initialization and work pointer `0x3A2110`. The private-pool slot is
zero before and after initialization. The one-shot callback sees that same
wrapper/device/work tuple on a Windows worker. Combined with the exact inspected
mode-3 branch, this establishes use of the process default pool in this run.

Lines 9458-9462 record cleanup entry, callback-drain return, work-close return,
cleanup return with the work and pool slots zero, and successful wrapper free.
The work-close API has no result code; the evidence establishes that the call
returned, followed by cleared state and wrapper release. No private-pool close
is observed or required by this zero-slot default branch. No Init failure or
second wrapper lifetime appears.

This fills the dynamic gap left by trace 0.3: WARP returned through its normal
work cleanup before the Windows workers retired. Microsoft's
[work-close contract](https://learn.microsoft.com/en-us/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-closethreadpoolwork)
concerns the work object; the
[thread-pool architecture](https://learn.microsoft.com/en-us/windows/win32/procthread/thread-pools)
assigns worker management to the pool. The observed delay is consistent with
those distinct lifetimes, rather than evidence of a skipped WARP work close.

### Resource and worker retirement

All rows are from this one process and its sequential sampler. The pre-warmup
and closed rows include the persistent native parent, not the integrated WPF
MainWindow lifecycle. Raw line references identify RESOURCE rows.

| Sample | Phase | Private bytes | Process handles | GDI | USER | Threads | Line |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | Pre-warmup | 2,871,296 | 53 | 9 | 4 | 1 | 719 |
| 2 | Warmup live | 13,352,960 | 157 | 11 | 21 | 37 | 3145 |
| 3 | Baseline live | 12,738,560 | 163 | 11 | 26 | 38 | 6608 |
| 4 | Measured live, 25 | 12,685,312 | 178 | 11 | 41 | 38 | 9419 |
| 5 | Final closed | 4,796,416 | 141 | 9 | 38 | 36 | 11478 |
| 6 | Closed +10s | 4,796,416 | 141 | 9 | 38 | 36 | 13496 |
| 7 | Closed +90s | 3,969,024 | 107 | 9 | 4 | 2 | 15157 |
| 8 | Closed +180s | 3,969,024 | 107 | 9 | 4 | 2 | 63784 |

Baseline-to-25 growth is 15 process handles and 15 USER objects with 38 sampled
threads unchanged. The 15 additional positive queue observations belong to
existing baseline worker identities. This run's count is 15, not the earlier
trace 0.3 run's eleven.

All 34 baseline `ntdll+F8DE0` / TppWorkerThread TID-plus-creation-time identities
survive through the ten-second closed sample and are absent at 90 and 180
seconds. The remaining two sampled identities are the main thread (TID 8112)
and an NTDLL waiter (TID 9436, start RVA `13C50`), not surviving members of that
34-worker group. USER falls by 34 to its startup value of four. Queue-query
failure still means unavailable evidence, not proof of queue absence.

The target NTDLL CodeView GUID `6FE566EC-ECD3-410A-B5D2-451CCD8796ED`, age 1,
matches the previously verified Microsoft PDB. Its retained resolution maps
`F8DE0` to `TppWorkerThread` and `13C50` to `TppWaiterpThread`, both with zero
displacement. This uses exact matching public symbols, not the target's
nearest-export fallback labels. The symbol provenance remains in
`artifacts/vt7/diagnostics/win7-ntdll-symbolication-28116/`.

All 32 factory handles (`0x244..0x2C0` in steps of four) remain at samples 2-8
and report one pool address, `0x376580`, minimum/maximum 0/512 and the same
67-second idle timeout. Reported total/waiting workers change from 33/33 at
warmup to 34/34 at baseline through closed+10s, then 0/0 at 90 and 180 seconds.
Their PointerCount changes 67, 68 and 34 respectively; HandleCount remains 33.
Factory handle retention and worker retirement are separate observations; 32
handle values do not establish 32 distinct pools.

The measured wait segments are 10,015, 80,013 and 90,012 ms. Sample start ticks
are approximately 10.062, 90.106 and 181.383 seconds after the first closed
sample start. Idle ownership/setup hooks are disabled at line 9506. Retirement
occurred between the 10- and 90-second observations; no exact retirement instant
or guarantee that the 67-second field controls every worker is claimed.

### Event histories and retained handles

The complete bounded history contains 3,268 records: 1,661 OPEN and 1,607 CLOSE,
with no BADREF records. Parsed and dumped counts both report `0xCC4` at lines
62651-62652, far below the 65,536 capacity. The five outstanding-open diffs
contain 15, zero, zero, one and zero records respectively. An outstanding-open
diff alone is not a list of all closes; the full history supplies the closing
records below.

All 15 Events added between baseline and measured iteration 25 have an OPEN
through the WARP Task_Present/GetThreadDesktop path, a corresponding USER32
setup event and the first positive queue observation on the same existing
baseline TID-plus-creation-time identity. Each is absent at baseline, present
at measured/closed/+10s, and absent at +90s/+180s. Each has a later CLOSE on its
own opening worker TID in the NtTerminateThread/RtlExitUserThread path.

| Event value (hex) | Worker TID | Setup event | Measured diff OPEN line | Full-history CLOSE line |
| --- | ---: | ---: | ---: | ---: |
| 724 | 11060 | 36 | 9265 | 17002 |
| 5C0 | 9608 | 35 | 9275 | 16930 |
| 490 | 8388 | 34 | 9285 | 17191 |
| 408 | 8344 | 33 | 9295 | 17101 |
| 3A4 | 8440 | 32 | 9305 | 17119 |
| 2E4 | 6288 | 31 | 9315 | 17146 |
| 1AC | 1712 | 30 | 9325 | 17011 |
| 10C | 1680 | 29 | 9335 | 17083 |
| 7B8 | 6272 | 28 | 9345 | 17164 |
| 748 | 1752 | 27 | 9355 | 16975 |
| 718 | 9520 | 26 | 9365 | 17065 |
| 704 | 8268 | 25 | 9375 | 16966 |
| 6D0 | 8588 | 24 | 9385 | 17038 |
| 66C | 8512 | 23 | 9395 | 17173 |
| 658 | 10232 | 22 | 9405 | 17217 |

All are unnamed auto-reset Events. For the first eight listed numeric values,
older completed OPEN/CLOSE pairs precede the attributed GetThreadDesktop OPEN.
That attributed OPEN is the last OPEN for each, followed by its worker-exit
CLOSE. None of the 15 values reopens afterward within the retained history.
The other seven have one OPEN and one CLOSE. This checks value reuse within
the captured interval instead of treating a numeric handle as permanent identity.
Prior queue-query error 87 is unavailable evidence; liveness checks returned
WAIT_TIMEOUT on both sides of those live-thread queries.

Across the entire WARP workload, 34 GetThreadDesktop Event OPEN records pair
one-to-one with 34 worker-exit CLOSE records on their respective worker TIDs.
All 34 values disappear between the 10- and 90-second inventories, together
with the 34 worker identities. This provides direct closing-path evidence for
the investigated Events, beyond a correlation between totals. History records
do not timestamp each close; the inventories establish the observation bracket.

The net inventory change from +10s to +90s is 34 fewer NT handles: those 34
Events close, one ALPC Port (`0x20C`) disappears, and one new Event (`0x5A8`)
appears. The new Event opens during TID 8388's exit through the recorded
critical-section/heap/FLS path (diff line 15135, full-history line 17200) and
remains at both late samples. Its role is not established by nearest-export
stack labels. Event inventory totals change 55 to 22, not 55 to 21, because of
that additional open. No handle-value/type inventory change occurs from 90 to
180 seconds.

Compared with pre-warmup, the final NT inventory has 52 additional entries:
32 TpWorkerFactory, nine Event, three Timer, two Thread, two Mutant, and one
each of KeyedEvent, IoCompletion, Key and ALPC Port. Process handle counters
and full-history net OPEN-minus-CLOSE both give +54. Two net-OPEN values,
`0x1FC` and `0x200`, are not listed in the final NT inventory. This difference
is explicitly unresolved; neither full resource ownership nor exact equivalence
of sequential inventory/counter/history views is claimed.

Reproducible read-only analysis is retained under
`artifacts/vt7/diagnostics/retirement-target-handles-20260913/`: `analyze.py`
derives the inventory/setup/thread/history correlations, and `verify-result.py`
independently checks their counts, ordering, value reuse and paired worker
closes. Those original analysis invocations read the K: log in memory and saved
no raw logs or excerpts; the scripts retain that input path. The independent
check passes for all 15 measured Events and all 34 GetThreadDesktop Events
with the source SHA256 above. The subsequent user-authorized archive preserves
those exact input bytes locally. The repository validator can read the archived
stage logs directly; use the verified archive when the original K: path is no
longer available. These scripts and this report do not replace the raw archive.

### Remaining question

At 90/180 seconds, USER and GDI have returned to pre-warmup totals, but process
handles remain 54 higher and private bytes 1,097,728 higher, with one extra
sampled thread. The default-pool factory handles also remain. This is not a
complete return to startup and one work/idle round does not establish a stable
residual across repeated rounds.

The result supports delayed worker-associated retention for this native control
and removes the proposed missing WARP work-close explanation for its captured
path. It does not qualify the integrated WPF host's resource growth, repeated
retirement/restart behavior, continuous live work or a long-term bound. Existing
C3 resource verdicts and budgets remain unchanged, and the timed soak stays on
hold. The next bounded investigation should bridge this result to the integrated
host's actual window/surface lifetimes and compare repeated closed/idle states
in the same process.

A bounded design is two rounds of the existing integrated 100-lifecycle work,
with closed+10/90/180-second samples after each. Run the original two warm-ups
only once, keep the original baseline and all immediate 25/50/75/100-cycle
resource checks, and retain every budget failure across both rounds. Repeat
the original round-local cycle-zero scheduling checks, pixel validation, tab
transitions and close-state rotation. Keep the WPF dispatcher/process alive
during idle, with normal input, notification and security behavior. Compare
each round's late closed state to startup, the fixed warmed baseline and the
previous round's equivalent late state; later release must not erase an
immediate C3 failure. This tests the integrated lifetime and whether a second
activity burst raises the retained baseline, without substituting a new warm-up
or the long timed soak.

The current integrated runner samples after WPF window/HwndHost disposal and
then throws on aggregate resource failure before any late observation. Its
isolation variant has only a ten-second final wait. Neither current CLI nor the
issued native-only retirement ZIP implements the proposed two-round control.
It needs a separate diagnostic identity, bounded timeout and local qualification.
The current host groups thread start addresses and GUI-query results, so the
new control also needs checkpoint-only creation-time identities to distinguish
worker survival from TID reuse, preserving failed queries and releasing its
temporary inspection handles before idle. A managed diagnostic build should
reuse the issued native DLL rather than rebuilding or replacing that payload.
No new application build or diagnostic package is issued
by this analysis, and no unchanged retirement 0.1 repeat is requested.
