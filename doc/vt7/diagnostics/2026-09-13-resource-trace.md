# Focused native WARP resource trace, 2026-09-13

Current execution decision, 2026-09-14: the owner approved
[REL01](../architecture/2026-09-14-warp-development-deferral.md), stopping further
dedicated WARP tracing and proceeding to C4/3A session development. This record
preserves historical findings and reproduction instructions; its proposed next
diagnostics are not active tasks. Original failures and release-qualification
limits remain recorded. Further investigation is conditional on relevant evidence
or Milestone 7 release review.

## Status and purpose

Resource tracing adds a bounded, process-local debugger observation to the
unchanged resource lifetime 0.2 executable and issued native 0.3.5/ABI 8 DLL.
The Windows 7 recreate/reuse comparison grew in both modes, so repeated surface
creation is not necessary for the observed growth. The remaining question is
which call paths create the retained queue-related resources and NT handles.
See the [comparison record](2026-09-13-resource-lifetime.md) and
[C3 stability record](../validation/2026-09-13-atlas-stability.md).

Traces 0.1 and 0.2 completed locally with the SDK 8.1 debugger on Windows 10.
On Windows 7, trace 0.1 waited at a first-chance exception until timeout; trace
0.2 correctly dispatched that exception, captured its second chance, and
terminated promptly. Both target attempts ended during startup, before any
application sample or WARP workload. Their evidence and historical package
identities are preserved below. Trace 0.3 adds a separate startup control and
defers handle tracing until the existing pre-warm-up sample entry. The final
three-stage package completes locally under Windows PowerShell 5.1 and SDK 8.1
CDB. The supplied Windows 7 run also completes all stages and workload, but its
issued validator falsely rejects a nested token Type field. Corrected offline
validation accepts the preserved capture; no repeat run is required. The target
trace now identifies eleven new Event handles on the WARP/GetThreadDesktop
call path, correlated to eleven existing worker identities becoming queue-positive.

Collection completion does not establish allocation ownership, accept resource
growth, close C3, or qualify an extended soak. The startup exception's cause
and the original retained-resource ownership both remain open.

## Classic debugger selection and provenance

Use Microsoft's standalone x64 Debugging Tools MSI from the Windows 8.1 SDK.
The SDK installer also offers the **Debugging Tools for Windows** feature.
The default x64 CDB location is
`C:\Program Files (x86)\Windows Kits\8.1\Debuggers\x64\cdb.exe`.
Visual Studio, the full SDK, Windows Performance Toolkit and Application Verifier
are unnecessary for this collection. The modern VT7 build environment stays on
the development machine; Visual Studio 2022 17.7 and later cannot install on
Windows 7. See Microsoft's [Visual Studio host requirements](https://learn.microsoft.com/en-us/troubleshoot/developer/visualstudio/installation/visual-studio-2022-unsupported-operating-systems).

Official download provenance, checked on 2026-09-13:

- [Microsoft SDK archive](https://learn.microsoft.com/en-us/windows/apps/windows-sdk/downloads-archive).
- [SDK 8.1 bootstrap link](https://go.microsoft.com/fwlink/p/?LinkId=323507).
- [Resolved SDK bootstrap](https://download.microsoft.com/download/B/0/C/B0C80BA3-8AD6-4958-810B-6882485230B5/standalonesdk/sdksetup.exe).
- [Exact x64 debugger MSI](https://download.microsoft.com/download/B/0/C/B0C80BA3-8AD6-4958-810B-6882485230B5/standalonesdk/Installers/X64%20Debuggers%20And%20Tools-x64_en-us.msi).

| Download | Bytes | SHA256 |
| --- | ---: | --- |
| `sdksetup.exe` | 998056 | `5107822A5A99BCDEF4C7B7C7EEA218425692F0185750B0D4FAFD441034A7486B` |
| `X64 Debuggers And Tools-x64_en-us.msi` | 19587072 | `028EC393BA3854D4295AB7472BF83D3F040F2FADD5B8C390D425E8C2E7547FC4` |

Both downloads had valid Authenticode signatures from Microsoft Corporation.
The MSI SHA1, `C1C58E069AF7B0A9222AC640AD1153804734D14E`, also matched
the payload hash in the signed bootstrap's embedded manifest. Bootstrap file
version is `8.100.26936`; the MSI ProductVersion is `8.100.25984`. These SDK
identifiers differ from the actual CDB, DbgEng, DbgHelp and SymSrv version,
`6.3.9600.16384`.

The bootstrap user-experience manifest displays an OS warning for
`VersionNT < "6.1"`. Its `OptionId.WindowsDesktopDebuggers` feature has no newer
OS installation condition. This is installer evidence for the Windows 7 floor,
not a claim that a trace has passed on Windows 7. A historical
[Microsoft debugger overview](https://github.com/MicrosoftDocs/windows-driver-docs/blob/6d5f4c461a0c53a24b965c95ec94ce47d91fa256/windows-driver-docs-pr/debugger/index.md)
also lists Windows 7 as both a debugger host and target. That period statement
does not qualify current 26100 tools.

The development machine's SDK `10.0.26100.7705` debugger engine imports
`GetSystemTimePreciseAsFileTime`, which is unavailable on Windows 7. It must not
be copied to the target. Import inspection of the extracted 6.3 CDB, DbgEng,
DbgHelp, SymSrv and NtsdExts found `GetSystemTimeAsFileTime` and no import of
`GetSystemTimePreciseAsFileTime`. This narrower observation is not a complete
downlevel import or behavior qualification.

Local tools and evidence are retained under
`artifacts/vt7/diagnostics/debugger-sdk81-tooling/`, including `PROVENANCE.md`,
the signed downloads, extracted bootstrap metadata, read-only MSI table records,
the extraction script and import reports. Existing 7-Zip extracted the bootstrap,
MSI streams and embedded CABs; Windows Installer tables were opened read-only
to restore filenames and directories. No SDK installer, MSI installation or
MSI custom action ran. CDB, DbgEng and DbgHelp individually also had valid
Microsoft signatures, and `cdb.exe -version` succeeded locally.

The debugger engine is neither rebuilt nor redistributed in the VT7 package.
The user obtains Microsoft tools separately and keeps matching adjacent DLLs
and extension directories together. Do not replace system DbgHelp or combine
old CDB with unrelated newer DbgHelp/SymSrv binaries. Microsoft's
[DbgHelp distribution guidance](https://learn.microsoft.com/en-us/windows/win32/debug/dbghelp-versions)
distinguishes redistributable package material from the nonredistributable
Windows system copy; this diagnostic does not rely on redistributing either.

## Unchanged application and private symbols

The trace invokes the existing `VT7.ResourceLifetime.exe` with
`VT7.Native.dll reuse --cycles 25`. Neither application binary was rebuilt for
this diagnostic. The native DLL in `resource-lifetime-0.2` and the issued
`atlas-viewport-0.3.5` directory has the same SHA256. The existing matching native
PDB comes from the latter directory.

| Input | SHA256 |
| --- | --- |
| `VT7.ResourceLifetime.exe` | `438FC74130CE3D7A255BEDF368FEA1371778CB0A85CF9D5EBCF1A295C246F71F` |
| `VT7.ResourceLifetime.pdb` | `C2696000C6829C54DE5CA284379ED199E06E773A2ECE5308B29257A32B76F02B` |
| `VT7.Native.dll` | `0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49` |
| `VT7.Native.pdb` | `C835ED74D7E119F0601AD1CE1DE8A70349BADD443D041E467756705CC8B6AAEE` |

The local SDK 8.1 trace reports `private pdb symbols` for both modules. The
preflight resolves the existing `sample(char *, unsigned int, bool)` at image
RVA `0x1470` and disassembles its entry. This RVA belongs to the pinned EXE only;
it must not be carried over to a rebuilt executable. Packaging and the runner
pin all four hashes independently of the ordinary file checksum list.

## Original trace 0.1 and 0.2 collection protocol

This section preserves the protocol used by the issued 0.1 and 0.2 packages.
Their command files are retained with the package and target evidence. Current
working instructions and debugger commands are in
[`README.txt`](../../../src/vt7/VT7.ResourceTrace/README.txt),
[`preflight.cdb`](../../../src/vt7/VT7.ResourceTrace/preflight.cdb), and
[`trace.cdb`](../../../src/vt7/VT7.ResourceTrace/trace.cdb). The current 0.3
startup boundary and activation changes are described separately below.

1. Preflight launches its own diagnostic child, verifies the private sample
   symbol and `USER32!ClientThreadSetup` entry, and exercises `!htrace -enable
   0x10000`, `-snapshot`, `-diff`, `!handle`, and `-disable`. It quits before
   application work begins. A successful preflight permits a fresh trace child.
2. The trace uses forced WARP and one reused surface, with two warm-up and
   25 measured iterations. This performs 270 resizes, 27 fixture resets and
   135 hide/show trips. The input, worker, graphics and security behavior of
   the issued binary remains intact. Existing optional power notifications and
   probe modes are off, as recorded by `CONFIG`.
3. Six breakpoints at the existing sampler entry capture the pre-warm-up state,
   first warm-up live state, post-warm-up live baseline, 25 measured live state,
   final closed state, and final closed state after ten seconds. The last two
   retain the native parent window, as in lifetime comparison 0.2. These debugger
   observations precede the sampler's sequential thread/counter observations;
   they are not simultaneous snapshots.
4. A `USER32!ClientThreadSetup` breakpoint records decimal PID/TID, TEB,
   instruction/stack/return addresses, latest checkpoint and up to 24 stack
   frames. The 256-event limit disables that breakpoint and emits a truncation
   marker that makes collection incomplete. No function call is injected into
   a stopped worker. This internal exported hook does not guarantee coverage
   of every input-queue allocation.
5. `!handle 0 f` inventories NT handles at every checkpoint. Explicit htrace
   snapshots separate baseline-to-25, 25-to-closed and closed-to-closed-plus-ten-
   seconds diffs. Normal process exit records its status and counts, disables
   tracing and emits the closing marker.

CDB debugs only its launched child. The runner sets no registry, global flags,
IFEO, postmortem debugger, Application Verifier or kernel debugger configuration,
and attaches to no unrelated process. Its preflight and trace time limits are
60 and 600 seconds. Each invocation creates a distinct log directory; partial
logs remain useful when collection fails.

The runner clears inherited symbol-server settings in the CDB child environment
and uses the package's local symbols directory. The initial development runs
used the two local issued artifact symbol directories instead. No online symbol
server was configured. Expected Windows PDB lookup errors may fall back to
exports, but both VT7 private PDBs must load. The final commands capture module
inventories at the live baseline and final closed checkpoint, preserving raw
addresses, image bases, sizes, timestamps and versions even when graphics
modules unload at close. Nearest-export-plus-
offset labels must not be interpreted as exact Windows function names.

## Local SDK 8.1 evidence

Evidence is retained in
`artifacts/vt7/diagnostics/resource-trace-development/`:

- `preflight-sdk81-combined.log` and `preflight-sdk81-debugger.log`.
- `trace-sdk81-combined.log` and `trace-sdk81-debugger.log`.
- The corresponding stderr files, both empty for these runs.

The native OS record is `10.0.19044`, x64. The old debugger's `version` command
labels the host Windows 8/9600, while its own kernel32 record is
`10.0.19041.7725`. The old banner must not be used as target-OS evidence.

Preflight resolved the sample entry and USER32 hook, enabled tracing, took and
diffed snapshots, inventoried handles, disabled tracing and reached its end
marker. The trace then completed all six checkpoints and two setup events,
with `VT7_TRACE_EXIT status=0 checkpoints=6 setup_events=2`. Both VT7 private
PDBs loaded. The final workload record has 27 iterations, one create, one
destroy, 270 resizes, 27 size resets and 135 hide/show trips. Attribution sampled
62 distinct thread identities with no unavailable creation identity.

| Interval | Reported new stack traces | Outstanding newly opened handles reported by htrace |
| --- | ---: | --- |
| Post-warm-up baseline to 25 measured iterations | `0x452` | None |
| 25 measured iterations to final close | `0xb2` | None |
| Final close to closed plus ten seconds | `0x7c` | None |

The ordinary sampler recorded these debugger-affected counters:

| Sample | Private bytes | Handles | GDI | USER | Threads |
| --- | ---: | ---: | ---: | ---: | ---: |
| Pre-warm-up | 3342336 | 120 | 0 | 4 | 4 |
| First warm-up live | 33705984 | 184 | 0 | 7 | 44 |
| Post-warm-up live baseline | 34820096 | 184 | 0 | 7 | 52 |
| 25 measured live | 41201664 | 184 | 0 | 7 | 62 |
| Final closed | 38690816 | 132 | 0 | 4 | 61 |
| Closed plus ten seconds | 24678400 | 132 | 0 | 4 | 61 |

These are development-host observations under a debugger, not Windows 7
resource acceptance. The two observed setup events and the absence of reported
outstanding new NT handles do not explain the target's retained USER growth.

## Interpretation limits and next evidence

[Microsoft's htrace documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-htrace)
and the exact SDK 8.1 CHM describe current-process handle histories and snapshot
diffs. They do not provide a numeric retained-event capacity, stack-depth or
wraparound guarantee. The chosen `0x10000` argument was accepted locally; it is
not evidence of unlimited history or a particular retained stack depth. These
are NT-handle observations, not a complete inventory of USER, GDI or COM
allocations. A repeated numeric handle can represent a new allocation after
the previous handle closed.

Queue observations must be correlated with setup events from the same run.
The sampler uses TID plus creation FILETIME, while setup events provide TID/TEB
without creation FILETIME. Ambiguous TID reuse, unsampled transient threads,
missing hook matches and unavailable GUI queries remain unassigned or unknown.
An unavailable GUI query does not establish queue absence, and a thread start
address does not identify the owner of later allocations.

Debugger pauses and handle-history storage affect scheduling, timing and
memory. Missing or overwritten histories, incomplete setup-hook coverage,
unresolved Windows stacks and remaining final-close ownership cannot be treated
as evidence of absence. `COLLECTION=COMPLETE` is a collection result only.

If exact Windows symbols become necessary, Microsoft documents
[offline retrieval with a SymChk manifest](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/using-a-manifest-file-with-symchk).
Retrieve symbols for the exact loaded modules on a modern host and transfer a
local cache. The [public symbol service requires TLS 1.2 or later](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/microsoft-public-symbols);
this trace does not require changing the target's TLS defaults or registry.

The supplied Windows 7 attempts below do not reach the workload. The next
protocol adds a startup control before attempting delayed handle tracing under
the same account/session. Review failed or partial collection before repeating
it or changing settings. Workload execution under the target debugger and
allocation attribution remain pending.

## Issued trace package and launcher qualification

The separate `artifacts/VT7-resource-trace-0.1-x64.zip` is 8,297,623 bytes,
SHA256 `AAFA42259DDF706400F77DDC75BAF7F41BB9876960C2B740DF7484175A830033`.
All 54 manifest-listed ZIP entries were rehashed from the archive and matched;
there were no unmanifested payload files. The original lifetime 0.2, native
comparison 0.1 and viewport 0.3.5 archives were rechecked unchanged. No debugger
is in the ZIP, and no existing candidate was replaced.

The versioned [package helper](../../../tools/Package-VT7ResourceTrace.ps1)
records actual Git HEAD/dirty state, pins the issued input hashes, preserves
their notices and provenance, and snapshots the new trace scripts and helpers.
Source HEAD is `928c4581e3747d622ebcd43cf36206125b623102` with uncommitted
diagnostic work; the package manifest hashes the actual copied source bytes.

The user reports Windows PowerShell 5.1 plus PowerShell 7.2.24 side-by-side on
the Windows 7 machine. `RUN-RESOURCE-TRACE.cmd` selects `powershell.exe`, which
is 5.1 there, rather than `pwsh.exe`. This records installed tools, not a VT7
session-backend acceptance claim.

Launcher qualification on Windows 10.0.19044 x64 using SDK 8.1 CDB:

- A full PowerShell 2.0 scratch run completed, including a package path with
  spaces. It caught and corrected an earlier CLR 2 incompatibility:
  `SHA256CryptoServiceProvider` cleanup now uses public `Clear()`.
- A full PowerShell 5.1 scratch run completed after adding the live-baseline
  module inventory. Its successful evidence is under
  `artifacts/vt7/diagnostics/resource-trace-runner-ps51-ae32779b/Logs/resource-trace-20260913-151227-2161fc6a/`.
  That scratch directory's README was later intentionally changed for the
  checksum-rejection control; it is not an issued package.
- The final packaged runner completed under PowerShell 5.1, including checksum
  verification, preflight, all six checkpoints, two setup events, exact workload
  totals and exit 0. Its output explicitly remains `OWNERSHIP=REQUIRES_REVIEW`
  and `RESOURCE_ACCEPTANCE=OPEN`.
- All 60 text fixture checks passed under PowerShell 2.0 and 5.1. These include
  missing/duplicated records, failed commands, truncation, malformed workloads,
  stack/identity inconsistencies and a retained invalid initial trace. A real
  older nonempty diff validates 567 handle histories, including four explicit
  PID 4 records without user stacks; their attribution remains unavailable.
  The [test helper](../../../tools/Test-VT7ResourceTrace.ps1) launches no workload.
- Missing-debugger and changed-checksum launcher controls both exit 1 before
  starting CDB. Their logs are retained beside the scratch success above.
- A 2,000-ms timeout test under PowerShell 2.0 stopped its own initial-break
  CDB and diagnostic child after 2,034 ms. Captured parent/child IDs and creation
  times confirmed both had exited, with no application workload entered.
  Evidence: `artifacts/vt7/diagnostics/resource-trace-timeout-20260913-151259-b0939f23/`.

Final package qualification evidence lives under
`artifacts/resource-trace-0.1/Logs/resource-trace-20260913-151421-516ac5a5/`.
These logs were created after packaging and are not in the issued ZIP.

| Final local evidence | SHA256 |
| --- | --- |
| `preflight-combined.log` | `4CA9F2004AB6EBD77FF6A17935E5C1BD98A0A20BD7675D2BF11CFA1273A69AA4` |
| `trace-combined.log` | `28A067C1E850F9505B01EEBE5A8838405C75FA22CCDFF1A29A837C032CFCE77F` |
| `summary.txt` | `482AF9D1D3158C74B370BD0EE6B4667912D653A528432DF4F32B4B2F8994BBB6` |

The PowerShell 5.1 fixture transcript is
`artifacts/vt7/diagnostics/resource-trace-development/validator-final-60-ps51.txt`,
SHA256 `3778F32F988DEEFD109E1FA540DA8975AA3187401012E1B08200611D27CBE7B2`.
The initial current-debugger scratch trace contained an invalid `.version`
command and is retained as incomplete; the shipped command is `version`.
These local checks establish collection readiness, not Windows 7 execution
or any new resource acceptance.

## Supplied Windows 7 trace 0.1 result

The subsequently supplied run is retained at
`artifacts/vt7/evidence/resource-trace-win7-0.1/resource-trace-20260913-151714-26f04e23/`.
The received `preflight.cdb`, `trace.cdb` and `package-SHA256SUMS.txt` were
rehashed and exactly match the issued 0.1 scripts and checksum manifest.
Their SHA256 values are respectively
`5EFB73DC892A8567CC314F3BD209005501C62C247B6885C74CA1572893D02923`,
`9E0ADB698DCD03FBB8DA451F31497A2BAC691CC4EF63E28DBA14394C4A3B3234`, and
`83F5708583F3104961C66F2A45575BCD295977AEDF3B4F8ABA9CF550F64626E8`.

| Supplied evidence | SHA256 |
| --- | --- |
| `preflight-combined.log` | `AD07E1240B30ADF0B61F34A7C077C42F88B75C9F4CAB503063DFB836198349AF` |
| `trace-combined.log` | `DCD225480D55303A1C0912699F835D449265E6850EA241CE611B6E78E5F12E3A` |
| `summary.txt` | `A8675F326F229071554EE38D76B7588DDE7A555CB3DB3C82CF38C9F43E6A7106` |

The summary records Windows 7 SP1 x64 (`6.1.7601`) and Windows PowerShell
`5.1.14409.1005`. The installed SDK 8.1 tools are patched versions: CDB and
DbgHelp `6.3.9600.17298`, with DbgEng, Ext and Exts `6.3.9600.17336`.
The summary retains their individual SHA256 values. They differ from the local
base MSI's `6.3.9600.16384`; that difference is provenance, not evidence of a
debugger defect. The user also reports Visual Studio 2022 Enterprise 17.6 on
this target. This is consistent with the earlier restriction applying to 17.7
and later, and does not qualify a target-side VT7 build environment.

Preflight completed with CDB exit 0. The full trace enabled htrace and reached
one `ClientThreadSetup` event at checkpoint 0, during process initialization.
It then stopped at first-chance `0xC0000008` (invalid handle), with the debugger
at `ntdll!KiRaiseUserExceptionDispatcher+0x3a`. No sampler checkpoint, native
DLL load or application workload was recorded. CDB waited at its command prompt
until the runner's timeout; the summary reports `INCOMPLETE` and launcher exit 1.

This is an incomplete collection caused by an unhandled debugger prompt, not
evidence of an application hang, allocation owner or WARP failure. The log has
no stack or exception record for the invalid-handle event. The preceding
`ClientThreadSetup` stack is a different event and cannot identify that invalid
operation. No supplied evidence establishes that the exception is harmless,
that htrace caused it, or that the patched debugger versions caused it.

## Trace 0.2 correction

A separate 0.2 correction retains the existing EXE, native DLL and PDBs and adds
an explicit invalid-handle exception policy to the collection scripts:

- First-chance events record the event identity, exception record, registers,
  up to 24 stack frames and loaded modules. `gn` then passes the exception to
  the application's normal handlers; it does not mark the exception handled
  with `gh`. The sixteenth event records an abort marker and terminates the
  diagnostic rather than allowing an unbounded exception stream.
- A second-chance invalid-handle event records evidence and a distinct abort
  marker, then terminates the diagnostic. It cannot count as completed collection.
- A queued fallback command on redirected CDB stdin records an unexpected
  debugger stop and exits the diagnostic. This prevents an unanticipated prompt
  from silently consuming the full timeout. The outer timeout remains a limit
  for a running or unresponsive debugger.

Microsoft documents the distinction between first and second chance in
[exception filters](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/sx--sxd--sxe--sxi--sxn--sxr--sx---set-exceptions-),
and [the `gn` command](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/gn--gn--go-with-exception-not-handled-)
preserves the application's handling opportunity. Invalid-handle exceptions
break by default; collecting and dispatching first chance is not a decision
that the underlying operation is acceptable. Any recorded exception still
requires review. Local negative controls, final package identity and Windows 7
execution of the correction are recorded separately below.

### Trace 0.2 package and qualification

`artifacts/VT7-resource-trace-0.2-x64.zip` is 8,055,884 bytes, SHA256
`0442029DC3BC4D4CFF89CE11089B16855E47C500146E962D8C55A751685E6D5D`.
All 57 manifest payload entries were rehashed from the archive and after fresh
extraction. ZIP path separators were normalized for manifest comparison; the
PowerShell 5.1 archive extracts correctly on the local Windows host. The old
trace 0.1, lifetime 0.2 and viewport 0.3.5 archives remain byte-identical.
No application binary or debugger was rebuilt or replaced. The separately
compiled regression fixture is development-only and is not shipped as a binary.

The final package's full 25-iteration run completed on Windows 10.0.19044 x64
under Windows PowerShell 5.1 using SDK 8.1 CDB 6.3.9600.16384. Preflight,
all six checkpoints, two setup events, exact workload totals and process exit
completed. No invalid-handle exception occurred in this ordinary local run.
Evidence is retained under
`artifacts/resource-trace-0.2/Logs/resource-trace-20260913-155408-deb5c62b/`:

| Evidence | SHA256 |
| --- | --- |
| `preflight-combined.log` | `C667DCD2DE79E727AC0AAE5A22C5E91FEB4BBBBDE65B8FB7780F9D1165249A0F` |
| `trace-combined.log` | `4825616AD0FA7B14A444902B4E246E20016215FC631C45D1DDB1A6058157025D` |
| `summary.txt` | `64BCEF54B4D36ABE9CECA3E90E072C340179FDF33C0330671008BEE0284D843C` |

The [exception policy regression](../../../tools/Test-VT7TraceExceptionPolicy.ps1)
compiles a separate [SEH fixture](../../../tools/testdata/VT7TraceExceptionFixture.cpp),
extracts the exact policy block from `trace.cdb`, and checks three cases:

| Case | Observed result |
| --- | --- |
| One handled invalid-handle exception | One captured episode and dispatch; the fixture's own handler ran and normal completion followed. 95 ms. |
| Unhandled invalid-handle exception | First-chance dispatch followed by the second-chance abort and quit. 75 ms. |
| Repeated handled exceptions | Sixteen recorded episodes, fifteen dispatches/fixture handlers, then the limit abort and quit. No completion. 171 ms. |

These are controlled exception-policy tests, not a reproduction or explanation
of the target's invalid operation. Their exact source/command snapshots, build
log, identities and results are in
`artifacts/vt7/diagnostics/trace-exception-policy-20260913-135109743-7c233634418349a091a2d340dee94686/`.
An earlier preserved fixture attempt exposed a CDB syntax error from `q;` inside
the cap branch. Removing that trailing semicolon made the final three cases pass.

The [unexpected-stop regression](../../../tools/Test-VT7TraceFallback.ps1)
uses the actual process helper and queued command against an initial debugger
break. It captured the last event, exception/register/stack/module context,
quit in 76 ms without starting application work, and was rejected by the trace
validator. Evidence is in
`artifacts/vt7/diagnostics/trace-fallback-20260913-135345-8b2b555b/`.
The leading empty `.echo` separates the abort marker from CDB's unterminated
prompt; the validator includes the complete abort reason in its error message.

All 85 validator fixture cases passed under actual Windows PowerShell 2.0.
They include the supplied paused target trace as a required rejection. The
nonzero-exception acceptance fixture explicitly combines real handled-fixture
context with a normal trace, adapting its process identity and module label;
it is synthetic input to validation, not an actual VT7 exception result.
The final PowerShell 5.1 fixture transcript is retained at
`artifacts/vt7/diagnostics/resource-trace-0.2-development-359c7445/validator-final-ps51.log`.

The supplied Windows 7 run of this correction is recorded next. Its new
exception policy worked, but startup did not complete. Neither trace 0.1 nor
0.2 should be repeated unchanged. The correction does not resolve C3 or
establish whether the target exception or retained resources are acceptable.

## Supplied Windows 7 trace 0.2 result

The complete received directory is preserved at
`artifacts/vt7/evidence/resource-trace-win7-0.2/resource-trace-20260913-160144-8a929ea8/`.
The received command files and checksum manifest were rehashed against the
issued `artifacts/resource-trace-0.2/` copies and match exactly. The diagnostic
binary identities remain those in the unchanged-input table above.

| Supplied evidence | SHA256 |
| --- | --- |
| `preflight.cdb` | `5EFB73DC892A8567CC314F3BD209005501C62C247B6885C74CA1572893D02923` |
| `trace.cdb` | `27B61D593C203A06CFC0FEBEDF5BEFA84914A33B3E0E8273A020806D4F1D4C1F` |
| `package-SHA256SUMS.txt` | `23377BD823942FAACA9532A36A4C367381C844DD3625520F8DFC8CB25B26CD13` |
| `preflight-combined.log` | `E6CF2AE7E142C0365CBE4C36BFCDD331E6A4370A224FAC650E0866DE3D0E24F9` |
| `preflight-debugger.log` | `CACFEBE60498F5193BA1F1DCE3C6315D84F0885BD9E0E8C8FE36011800AF929A` |
| `trace-combined.log` (44,817 bytes) | `2653D24EC15261F4597FDC73E4558204B79A4E5696C154F5E38537BB49565A88` |
| `trace-debugger.log` (44,877 bytes) | `376FBACF99BC8636A989603D327959261DF0AABE10B07E01222C9038FB3BBA99` |
| `summary.txt` | `58495C828BAC6209F866776187E6BB96DF67791D47555F111C34F5535C05ED61` |
| Both empty stderr logs | `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855` |

The summary again records Windows 7 SP1 x64, Windows PowerShell
`5.1.14409.1005`, CDB/DbgHelp `6.3.9600.17298` and DbgEng/Ext/Exts
`6.3.9600.17336`, with the same debugger hashes as supplied trace 0.1. The
reported side-by-side PowerShell 7.2.24 and Visual Studio 2022 Enterprise 17.6
remain environment context, not additional qualification or a reason to
install or switch tools.

Preflight completed and exited 0. It resolved the private sample entry and
USER32 export, successfully enabled/snapshotted/diffed/disabled htrace, and
inventoried 12 NT handles. As designed, this child quit at the initial debugger
break without testing continuation through process startup.

The trace child, PID 8912 and initial TID 9772, enabled htrace before continuing
startup. It recorded one `ClientThreadSetup` event at checkpoint 0, then one
first-chance invalid-handle episode and `VT7_INVALID_HANDLE_DISPATCH`. The
application did not handle that exception: a second-chance event followed,
with `VT7_TRACE_ABORT_INVALID_HANDLE_SECOND`, its context, and `quit:`. CDB
exited 0 because the command explicitly quit; the launcher correctly rejected
the abort marker and exited 1. This run did not wait for the outer timeout.

Both exception records identify `0xC0000008`, exception address
`000000007767AAAA`, and zero exception parameters. The captured stack contains
these raw addresses and nearest-export labels:

| Instruction/return address | Debugger label |
| --- | --- |
| `000000007767AAAA` | `ntdll!KiRaiseUserExceptionDispatcher+0x3a` |
| `00000000776EFF34` | `ntdll!LdrQueryImageFileKeyOption+0xa4` |
| `000000007764497F` | `ntdll!RtlInitializeCriticalSectionEx+0x1faf` |
| `00000000776A8A80` | `ntdll!longjmp+0x2c950` |
| `00000000776528FE` | `ntdll!LdrInitializeThunk+0xe` |

The loaded `ntdll.dll` has base `0000000077610000`, image size `0x0019F000`,
timestamp `0x694CD07A`, and version `6.1.7601.28116`
(`win7sp1_ldr_escrow.251224-1758`). No matching Windows PDB was loaded. The
labels and offsets are not proof of exact internal function identities or
the failing API. The first-chance register snapshot includes `RBX=0xE` and
`RSI=0x48`; neither value is established as the invalid handle, an argument,
or an allocation owner. The exception record itself supplies no handle value.

There is no application banner, native DLL load, sample, surface or WARP
workload in this trace. The preceding setup stack belongs to another event
and must not be substituted for the exception stack. The record establishes
an unhandled startup exception under this instrumentation. It does not
establish whether early htrace, the setup breakpoint, debugger presence,
system code or another startup interaction caused it. The `gn` policy remains
appropriate; changing to `gh` would bypass the application's handling path.

## Trace 0.3 startup control and delayed handle tracing

Trace 0.3 retains the exact lifetime 0.2 EXE, native 0.3.5 DLL and matching
PDBs. Its revised protocol uses three fresh debugger children in sequence,
with each required stage validated before the next begins. It uses the already
installed SDK 8.1 debugger; no further debugger, SDK, Visual Studio or shell
installation is required.

1. **Preflight:** retain the existing initial-break symbol and debugger-command
   checks. This establishes that the commands are available, not that startup
   or the workload can run under them.
2. **Startup control:** run [`startup.cdb`](../../../src/vt7/VT7.ResourceTrace/startup.cdb)
   with the same bounded invalid-handle policy, no `ClientThreadSetup`
   breakpoint and no htrace activation. Its only code breakpoint is the pinned
   sample entry at RVA `0x1470`. The expected boundary is
   `VT7_STARTUP_READY phase=pre-warmup iteration=0 live=0 invalid_handles=N`.
   The control records loaded modules and `VT7_STARTUP_END`, then quits before
   executing the sampler. It covers CRT startup, sampler storage initialization,
   COM initialization, native DLL loading, and creation/pumping of the native
   parent window. It does not produce an initial `RESOURCE` or `THREAD` sample,
   create a VT7 surface, execute WARP work, or demonstrate normal application
   teardown. It still runs under a debugger and is not a no-debugger control.
3. **Full trace:** preserve the early `ClientThreadSetup` breakpoint and the
   same exception policy. Defer `!htrace -enable 0x10000` until the first
   sample-entry breakpoint, between `VT7_HTRACE_ACTIVATE_BEGIN` and
   `VT7_HTRACE_ACTIVATE_END`. This is after the startup-control boundary is
   reached and before the first surface creation. Then retain all six samples,
   the reused-surface workload, baseline/close diffs, event limits, fallback stop handling and
   completion requirements.

Preflight and startup each have a 60-second limit; the full trace has a
600-second limit. Startup and full trace retain the queued unexpected-stop
fallback. A failed required stage prevents the following child from starting.
The installed PowerShell and SDK 8.1 tools remain sufficient for this sequence.

Both new command paths also place `!lmi ntdll` between
`VT7_NTDLL_CODEVIEW_BEGIN` and `VT7_NTDLL_CODEVIEW_END`. Microsoft's
[`!lmi` documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-lmi)
describes its module-header inspection. Where available, the record includes
the loaded image's CodeView/RSDS PDB identity and age for later exact-symbol
retrieval on the development host. This is optional metadata, not a claim
that a matching Windows PDB loaded or that exact Windows stack names are
available. It does not require copying a system DLL or enabling target symbol
downloads. Availability of this metadata on the target remains to be checked.

The [source boundary](../../../src/vt7/VT7.ResourceLifetime/resource-lifetime.cpp)
places pre-warm-up `sample()` immediately before the loop's first
`VT7_CreateSurface` call. The earlier supplied Windows 7 reuse comparison had
one thread at sample 1 and 38 at the post-warm-up baseline. The 34 sampled
`ntdll` worker identities of interest therefore appeared after this boundary
in that comparison. Deferred htrace retains coverage of surface/WARP creation
and the baseline-to-25 growth interval. It gives up the creation histories of
NT handles already open before checkpoint 1, including some startup, COM,
module and parent-window resources; their later presence cannot recover those
missing open stacks.

Keeping the setup-hook timing fixed while moving htrace activation tests one
specific instrumentation change. A passing startup control followed by a
pre-checkpoint-1 full-trace failure would narrow the remaining difference to
the added setup instrumentation and run-specific effects. It would not prove
that the hook caused the exception. A completed delayed-htrace run would
establish collection under the revised protocol, not harmlessness, leak
ownership or equivalence to normal execution. If required by that evidence,
setup-only and handle-only workload traces remain separate follow-up options.

The startup and full trace copy the same exception-policy block. The
[exception-policy regression](../../../tools/Test-VT7TraceExceptionPolicy.ps1)
now compares those copies as well as exercising handled, unhandled and
repeated exceptions against the exact full-trace block. First chance is still
dispatched with `gn`; second chance, the event limit, and unexpected stops
remain collection failures.

### Trace 0.3 local qualification and package identity

The final `artifacts/VT7-resource-trace-0.3-x64.zip` is 8,060,952 bytes, SHA256
`E0DCA8AD0532E401903D46DE6E352303C56D9392DF0B613C40FC2AFDAB461059`.
Its checksum manifest SHA256 is
`A6869BF86DC400946D645F03A63CA1B97DC4DB7C2A50329B209159569659560D`.
This is a separate diagnostic identity; no application binary was rebuilt.

The final packaged launcher completes all three stages on Windows 10 under
Windows PowerShell 5.1.19041.7725 with SDK 8.1 CDB 6.3.9600.16384:
`artifacts/resource-trace-0.3/Logs/resource-trace-20260913-161208-c026e689/`.
Every CDB stage and the launcher exit zero, and all stage stderr files are empty.
The startup control reaches pre-warmup/iteration 0/live 0 with zero invalid
handles, records modules, then quits before any sample or surface work.
The full trace records all six checkpoints, activates htrace inside checkpoint
1 before its inventory, collects seven successful snapshots and three diffs,
and finishes 27 iterations, one create/destroy pair, 270 resizes, 27 fixture
resets and 135 hide/show trips. It records two setup events and zero invalid
handles. This is collection qualification, not a resource-growth verdict.

SHA256 of final packaged-run evidence:

| File | SHA256 |
| --- | --- |
| `preflight-combined.log` | `D09080E9ADA2BE77FC30717F904463B32793523FB0602DCB4F3085A893E53FEE` |
| `startup-combined.log` | `A6400F29CEAAFA0D572C2F3F691AE47D52E557007430AD74C3010A7D31AB98A1` |
| `trace-combined.log` | `BDE693FC2693EC65709484770DA387762C8590CA0362D69BD982B7D2FAC3965B` |
| `summary.txt` | `632B52305092736D88BE2D9BDE0B24C84325B8220418534BB2270E6DEECE9F39` |

The frozen runtime command and validator identities are:

| File | SHA256 |
| --- | --- |
| `startup.cdb` | `9FA406C85E839545120F4753935F43C36D9C1346AEA740E9781614C3CFA18C16` |
| `trace.cdb` | `E5A60B07DDA5BB425E4BEE9246C15964A8BE3A8D3A52AFBA30D26D1091E9E4DE` |
| `Run-ResourceTrace.ps1` | `D5D91817F9BE2DB507977534A2B3FED2FFF0E092F61BB1FD16044E5E93A97F51` |
| `Validate-ResourceTrace.ps1` | `853F1304A965CCB081182793D8FC40852FC04A706BDAEE40052C16DFEFDDB673` |

Earlier component qualification used the same command bytes with actual Windows
PowerShell 2.0 and the old SDK debugger, retained in
`artifacts/vt7/diagnostics/resource-trace-0.3-development-20260913/`.
The copied exception-policy blocks pass the handled, unhandled and 16-event cap
controls in
`artifacts/vt7/diagnostics/trace-exception-policy-20260913-140613132-149f9e58cca14cadb753473f069d35b1/`.
The current runner's unexpected-prompt fallback captures context and quits in
104 ms, correctly rejecting collection, in
`artifacts/vt7/diagnostics/trace-fallback-20260913-141010-0657e6d0/`.
These are separate development fixtures; they are not evidence that the VT7
workload encountered a handled exception.

The independent ZIP audit hashes all 59 checksum-listed payload files and the
checksum manifest, both directly inside the ZIP and after fresh extraction.
It checks all 38 inherited lifetime mappings and 12 trace/helper source
mappings. The ZIP has 60 files plus seven directory entries; Windows ZIP
backslash names are normalized for comparison. Trace 0.1, trace 0.2, lifetime
0.2 and viewport 0.3.5 archive pins remain unchanged. Audit evidence:
`artifacts/vt7/diagnostics/resource-trace-0.3-archive-audit-1789308841396-0b69ec55/AUDIT.json`.
The new package manifest SHA256 is
`E10E2B94E29B075A0242A0C1CD4B0035443291EA720E3504E8FFF9C05951BFBC`.

All 126 text-validation fixtures pass under actual Windows PowerShell 2.0 and
5.1 against the final packaged logs, with exit 0 and empty stderr. The suite
includes the retained Windows 7 failures, actual nonempty handle histories,
and explicitly synthetic handled-exception combinations. Startup/activation
mutations, raw SDK 8.1 second-chance wording without its explicit abort marker,
and earlier trace versions are rejected. Exact inputs, commands, versions and
source hashes are in the audit directory's `FIXTURE-RESULTS.json`. Transcripts:

| File in that audit directory | SHA256 |
| --- | --- |
| `fixture-ps2-stdout.log` | `0E2B1912CD67AAE5091161D9AA77B931C5768C3706516F0263885546E3E29E57` |
| `fixture-ps51-stdout.log` | `1D27F71535F0614003F038312A168E66977E943FA40A8CCBCAFAFD25BA0E6AC4` |

Two actual launcher controls from fresh separate extractions also pass:

- `-PreflightOnly` completes preflight, records `COLLECTION=NOT_RUN`, exits 0,
  and launches neither startup nor trace.
- A deliberately substituted startup script prints
  `VT7_TRACE_ABORT_STARTUP_CONTROL_TEST` and quits CDB with exit 0. The launcher
  rejects that capture with exit 1 and never starts the full trace or workload.
  Only this synthetic extraction's startup script and its checksum entry are
  changed; issued files and all binary/PDB pins remain intact.

Evidence is retained in
`artifacts/vt7/diagnostics/resource-trace-03-stage-gate-qa-399976fb/RESULTS.json`,
SHA256 `F9747632ADB56ECCB01345EA842272681BC66CD4F1FAC11B4A76829E2ADA53B3`.
An earlier development QA harness attempt failed before CDB launch because its
parent environment exposed duplicate Path/PATH keys. That attempt remains in
`resource-trace-03-stage-gate-qa-11158f83`; canonicalizing only the QA child's
environment allowed the actual PowerShell 5.1 launcher controls to run.
This was not an issued-runner change or a target result.

The subsequently supplied Windows 7 result is recorded below. C3 remains open.

## Supplied Windows 7 trace 0.3: completed capture and parser correction

The complete supplied folder was copied with source/destination SHA256 checks:
`artifacts/vt7/evidence/resource-trace-win7-0.3/resource-trace-20260913-161711-9df20496/`.
It retains all 14 returned files, the screenshot and an added copy manifest.
All three captured CDB scripts and the captured checksum manifest match the
issued 0.3 package. PowerShell is 5.1.14409.1005, Windows is 6.1.7601 SP1 x64,
and the target SDK 8.1 debugger identities match those in trace 0.2.

| Supplied file | Bytes | SHA256 |
| --- | ---: | --- |
| `preflight-combined.log` | 10,370 | `0430FCED3498109CC00ADB6AF5B491EEF47DB9917E706844D14963E9045AA8B6` |
| `startup-combined.log` | 61,646 | `4ACBC90228E9B2FE6BCEF3E25CBF7D062BD1D602A69ADA266D53BF1BC2B72D2F` |
| `trace-combined.log` | 569,665 | `C9DCA08C65430AC9A9E69483A88476C62134A12AC382B33E6557C0E0DD849FB3` |
| `summary.txt` | 3,466 | `A8EBA5E161012882D77F793989F814D31A186A2E9E94473DD4779B3889194AFA` |

Preflight and the separate startup control pass. The full trace reaches all
six checkpoints, completes 27 total iterations with one surface create/destroy,
270 resizes, 27 resets and 135 hide/show trips, and exits normally. It records
36 setup events, zero invalid-handle exceptions, seven successful htrace
snapshots and all three diffs. All three CDB processes exit 0 with empty stderr.
The issued launcher nevertheless exits 1 after validation with
`INCOMPLETE: A handle inventory entry has no type.` Preserve that original
summary; offline revalidation is a separate result, not a rewritten target run.

The validator counted every indented `Type` line in the entire inventory.
Windows 7's detailed Token entry includes its top-level `Type Token` and a
nested `Type Primary` in Object Specific Information. Thus each of the six
inventories had exactly one more matching Type row than handles, although
every handle had a type. The source correction scopes Type parsing to each
handle's top-level fields and reconciles the per-type counts with the summary.
Missing, duplicated or inconsistent top-level types still fail validation.
The old SDK's separately observed Windows 10 `IRTimer` entries aggregated as
`None` are handled by a narrow, tested compatibility mapping.

This correction changes only the offline validator and regression source.
The issued ZIP, captured scripts and original logs remain intact. There is no
new target package or requested rerun. Any future reissue must use a new package
identity instead of overwriting 0.3.

The corrected validator SHA256 is
`DEC6422CB53C0859A6D8518BEC30D5B1634B74F782DEE965F678CAF5CB321450`;
the revised fixture helper SHA256 is
`4E36C8E788A92402E7B578A239ADD03C23D2724F71423FCBBB488A4DC4F12696`.
All 137 fixtures pass against both the preserved Windows 7 and Windows 10
captures under actual PowerShell 2.0 and 5.1: four offline runs, each exit 0
and empty stderr. Prior Windows 7 trace 0.1/0.2 failures still reject. Results,
input identities, commands, corrected source snapshots and transcripts are in
`artifacts/vt7/diagnostics/resource-trace-0.3-offline-revalidation-1789309290771-d8abc328/REVALIDATION.json`,
SHA256 `05E68F91350FCF1EE23428E043FCB83CE9B258AA5F304478ED2906E5043ECDEC`.

### What the target capture establishes

| Sample | Phase | Sampled threads | Queue-positive threads | USER | Process handles | Detailed NT inventory | Event entries |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | Pre-warmup | 1 | 1 | 4 | 53 | 40 | 13 |
| 2 | First warm-up live | 37 | 18 | 23 | 161 | 145 | 69 |
| 3 | Post-warm-up baseline | 38 | 25 | 30 | 168 | 152 | 76 |
| 4 | Measured 25 live | 39 | 36 | 41 | 179 | 163 | 87 |
| 5 | Final closed | 37 | 35 | 38 | 141 | 126 | 55 |
| 6 | Final closed plus 10 seconds | 37 | 35 | 38 | 141 | 126 | 55 |

Debugger inventories and the later process counters are different observations;
their absolute totals are not interchangeable. From sample 3 to 4, both grow
by eleven handles, all eleven detailed entries are Events, and all other
enumerated NT type counts stay constant. USER and queue-positive observations
also increase by eleven. This debugger run is not a replacement stability test.

The 36 setup records comprise one main-thread loader event, one native
presentation-thread event whose private stack includes AtlasEngine::StartPaint
and GetClientRect, and 34 WARP/GetThreadDesktop events. Those 34 match distinct
sampled `ntdll+0xF8DE0` identities. This is call-path evidence, not an inference
from the module holding a thread's start address.

The baseline-to-25 htrace diff contains 2,439 new history records and eleven
outstanding OPEN records. Every outstanding record has the same six-frame
family, beginning with `USER32!GetThreadDesktop+0xA`, followed by D3D10Warp RVAs
`0x41C19`, `0x165474`, `0x1651E3` and NTDLL RVAs `0xCEB4`, `0xF94D7`.
Each is the same PID/TID as one setup event between samples 3 and 4, and each
of those eleven TIDs belongs to a baseline TID-plus-creation-FILETIME identity
whose first positive queue observation is sample 4. Ten were first sampled
at sample 2; TID 6768 was first sampled at sample 3.

| Setup event | Decimal TID | Event handle |
| ---: | ---: | --- |
| 26 | 5848 | `0x674` |
| 27 | 3828 | `0x684` |
| 28 | 5868 | `0x68C` |
| 29 | 4056 | `0x6C8` |
| 30 | 8728 | `0xEC` |
| 31 | 9964 | `0x180` |
| 32 | 8644 | `0x220` |
| 33 | 8376 | `0x1D0` |
| 34 | 6768 | `0x380` |
| 35 | 8704 | `0x40C` |
| 36 | 8396 | `0x464` |

All eleven values are absent from the baseline inventory and listed as unnamed
Events at samples 4, 5 and 6. Their thread identities survive through sample 6.
The two later intervals have 118 and 76 new history records, respectively, but
no newly outstanding opens. This supports retention through final surface close
and the ten-second delay; it is not a full per-handle close/reopen history or
proof of continuous object identity from numeric handle values alone.

All 34 baseline `ntdll+0xF8DE0` identities are queue-positive by sample 4 and
remain through sample 6. A 35th identity in that group first appears at sample
4, stays queue-unavailable, and has no setup record. Unavailable queries are
not proof of queue absence. The native presentation worker and the separate
D3D10Warp-start thread disappear from samples 5/6. The latter has no setup event.
The final module inventory lists D3D10Warp under unloaded modules, while the
worker identities and Event values remain listed. All 33 final Event appearances
(eleven handles at three checkpoints) report auto-reset, waiting, access
`0x1F0003`, and no name. Their specific kernel purpose is not established.

The returned desktop handle is not one of these Event handles. Microsoft's
[GetThreadDesktop contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getthreaddesktop)
does not require the caller to close its returned desktop handle. The evidence
does not justify manually closing Windows' internal Event handles or forcing
termination of runtime-owned workers.

Derived tables, complete setup stacks and the analysis script are retained in
`artifacts/vt7/diagnostics/win7-trace03-ownership-20260913-142050867-faa4f504/`.
They are derived from the immutable combined log, not replacement source data.
The allocation/queue-call path is now identified for this bounded target interval.
What remains open is its resource lifetime contract, any corrective application
boundary, a defensible long-term bound, and the unchanged integrated C3 verdict.

### Matching symbols and the presentation call site

The new `!lmi ntdll` output records target PDB GUID
`6FE566EC-ECD3-410A-B5D2-451CCD8796ED`, age 1. The corresponding PDB was
retrieved from Microsoft's symbol server and checked as data with both a raw
PDB parser and DbgHelp. Its DBI age is 1; its separate PDB information-stream
age is 3. DbgHelp reports the expected module GUID and age 1. Do not mistake
that distinction for a mismatched target PDB.

The target D3D10Warp module inventory identifies version 6.2.9200.22592,
timestamp `5BB78029`, size `0x279000`, checksum `0x281E7F`. Microsoft's indexed
image matches those fields and is x64. Its CodeView identity is
`7394E810-65DA-4871-9C24-1F1987154DDF`, age 1; its matching PDB passes raw
GUID/DBI-age checks and DbgHelp/symchk matching. The target DLL itself was not
copied, so no byte-for-byte SHA256 comparison with that target file is claimed.
The downloaded image has no embedded Authenticode signature; provenance here
is the official download, metadata match and PDB matching, not signature validation.

| Downloaded data | Bytes | SHA256 |
| --- | ---: | --- |
| NTDLL PDB | 1,076,224 | `1FFFEE2B78861DB131C23BA1BD7DFE6E22CDB48F62512B592F6107D01DA54672` |
| D3D10Warp image | 2,565,120 | `35979BAF3D0538E74EE7E114F96D33A9558C0A4FE06E5A5D6FBFCCFB27794EDB` |
| D3D10Warp PDB | 986,112 | `94A3B4289B11CDCB9F561BA7DCC446335CA0DFFB1134D545621B8DAA7B59CCA1` |

The supplied raw stack addresses now resolve as follows:

| Module RVA | Symbol and displacement |
| --- | --- |
| `D3D10Warp+0x41C19` | `Task_Present+0x39` |
| `D3D10Warp+0x165474` | `Task::ExecuteTask+0x134` |
| `D3D10Warp+0x1651E3` | `ThreadPool::WorkCallBack+0x73` |
| `ntdll+0xCEB4` | `TppWorkpExecuteCallback+0xA4` |
| `ntdll+0xF94D7` | `TppWorkerThread+0x6F7` |
| Sampled `ntdll+0xF8DE0` start | `TppWorkerThread+0` |
| Sampled `ntdll+0x13C50` start | `TppWaiterpThread+0` |

Thus the direction of the observed presentation callback is:

```text
Windows TppWorkerThread / TppWorkpExecuteCallback
  -> WARP ThreadPool::WorkCallBack
  -> WARP Task::ExecuteTask
  -> WARP Task_Present
  -> USER32 GetThreadDesktop
  -> Windows client-thread setup
```

The public symbol records have no source lines and zero declared function
sizes. Read-only PE import inspection and disassembly independently confirm
the relevant WARP call site. At RVA `0x41C0B`, Task_Present calls GetCurrentThreadId;
at `0x41C11` it passes the returned thread ID in ECX; at `0x41C13` it calls
GetThreadDesktop through the USER32 import slot. Its return address is exactly
`0x41C19`, the one recorded in both the setup and handle histories. The
function compares that returned desktop with task field `+0x40`, attempts
SetThreadDesktop if different, and later attempts to restore the saved desktop.
The shown SetThreadDesktop return values are not tested, so this proves the
attempted association/restoration sequence, not that either switch succeeded.

WorkCallBack's direct call to ExecuteTask has return RVA `0x1651E3`;
ExecuteTask's indirect task-function call has return RVA `0x165474`. Those
instructions agree with the dynamic captured Task_Present stack. The image
was only parsed/disassembled, never executed or substituted on either machine.
No target symbol-server traffic or new runtime collection was needed.

Matching NTDLL symbols also refine the older startup exception stack:
`0x6AAAA` is KiRaiseUserExceptionDispatcher+0x3A, `0xDFF34` is
RtlQueryImageFileKeyOption+0xA4, `0x3497F` is LdrpInitializeProcess+0x1C4F,
and `0x428FE` is LdrInitializeThunk+0xE. `0x98A80` still resolves only to a
distant compiler-generated label and is not a meaningful exact function name.
These names do not establish which handle was invalid or why. The completed
0.3 capture demonstrates a working revised protocol, not a causal explanation
of that earlier startup exception.

Symbol files, inspection script, header/import records, matching reports,
resolved RVAs and bounded disassembly are retained under
`artifacts/vt7/diagnostics/win7-ntdll-symbolication-28116/`.
Its `PROVENANCE.md` records the exact Microsoft download URLs, tool/API method,
raw-byte/disassembly scope and limitations; `warp-threadpool-symbols.json`
preserves the inspection points below.
The subsequent [offline pool-lifetime investigation](2026-09-13-warp-pool-lifetime.md)
examines WARP's ThreadPool construction, work scheduling and destruction, and
rechecks the retained workers and factory records. The existence of a
TppWorkerThread does not establish default-pool versus private-pool ownership.
This record does not authorize suppressing WARP workers, closing their internal
Events, adding warm-up or relaxing resource budgets.

Bounded public-symbol enumeration supplied these inspection points:
ThreadPool::Init (`0x1649B0`), CleanUp (`0x164CD0`), CreateTask (`0x164E80`),
WaitWhileBusy (`0x164FC0`), WorkCallBack (`0x165170`) and TaskReadyToExecute
(`0x165210`). These names have zero public symbol size; they do not by
themselves prove pool ownership or correct cleanup. The matching image imports
CreateThreadpool, CloseThreadpool and their work-item APIs. The linked follow-up
records the completed Init/CleanUp, caller and submission inspection, plus the
common pool address across all 32 factory handles and their 67-second idle
timeout. This capture's ten-second final wait does not test retirement after
that interval. A new bounded diagnostic is proposed there; no unchanged trace
repeat or new application qualification follows from the offline findings.
