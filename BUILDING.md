# Building VT7

VT7 currently builds the 0.8.2/ABI 11 application: a WPF desktop
host, native HWND view, separate TerminalCore document/session owner, AtlasEngine
and renderer controller, a real pinned WinPTY 0.4.3 local root transport, and the
first direct SSH.NET 2026.0.0 remote root transport. Normal startup launches an
explicit `%SystemRoot%\System32\cmd.exe` profile; **Start SSH...** opens the
ephemeral direct connection dialog.
Hidden regression modes retain deterministic fixtures and fake transports. The
Command Prompt transport, Unicode and lifecycle scope passes locally and on the
supplied Windows 7 target. Active-command Ctrl+C passes; prompt-line cancellation
is a known WinPTY 0.4.3 limit. Native mouse-wheel scrollback and the 0.5.2
printable-character snap-to-live correction pass on the supplied test machines.
The PowerShell profiles and H01 diagnostic are target accepted. SSH.NET direct
package 0.2 passes its complete controlled-server Windows 7 run. Package 0.3
corrects the ordinary dialog labels but leaves the generated Authentication
selection light-on-light. Version 0.8.2/package 0.4 adds an explicit item
template, verifies the rendered selection at 4.5:1 and passes focused Windows 7
visual confirmation; typed SSH remains disabled.

The solution also builds an independent capability probe and an Atlas backend
proof (0.1). The latter renders fixed glyphs through real Atlas backends and
has passed automated Windows 7 hardware/WARP tests plus visible Direct3D11
checks. It remains separate from the integrated host. The supplied 0.3.0 Windows 7
run accepted the bounded full-engine C1/C2 path. The integrated 0.3.4 correction
now passes the supplied actual 100%, 125% and 150% system-DPI matrix; broader
renderer acceptance remains separate.

Start with the [documentation index](doc/vt7/README.md) and
[current handoff](doc/vt7/HANDOFF.md) for package identities, evidence and the
current 3B.1 development checkpoint. The [session stream contract](doc/vt7/architecture/2026-09-14-session-stream-foundation.md)
records ABI 9 ingress. The [session outbound contract](doc/vt7/architecture/2026-09-14-session-outbound-foundation.md)
records ABI 10 input/resize ordering and its focused test. The [port-first checkpoints](doc/vt7/architecture/2026-09-12-port-first-plan.md)
and [roadmap](ROADMAP.md) retain the broader implementation order.
The commands below are build and regression references, not requests to repeat
the accepted suites or unchanged diagnostic package. They
do not require extending every probe before application integration. The
[0.3.0 validation record](doc/vt7/validation/2026-09-12-atlas-viewport.md) records
the initial Windows 7 C1/C2 acceptance. The
[0.3.4 validation record](doc/vt7/validation/2026-09-12-atlas-scaling-correction.md)
separates local checks, accepted target scaling results and remaining C3 coverage.

## Scheduling and stability checks

The [0.3.5 scheduling/stability record](doc/vt7/validation/2026-09-13-atlas-stability.md)
records the completed quick/lifecycle runs and the unresolved resource gate.
`tools/Test-VT7AtlasStability.ps1` selects quick hardware/WARP checks by default;
`-Lifecycle` selects 100/1000/500 lifetime/resize/tab counts. The separate `-Soak`
option adds 30 minutes active and 10 minutes idle per backend to that matrix,
but remains on hold. `-Lifecycle` and `-Soak` cannot be combined.
All accept `-Configuration Debug|Release` and `-BinaryDirectory` like the other
integrated tests. Progress logs survive a runner timeout. Quick passes do not
replace the extended Windows 7 acceptance run.

The 0.3.5 package is an investigation candidate: hardware passes the 100-cycle
profile locally and on the supplied Windows 7 setup, but WARP exceeds its
resource budget on both. Package creation runs the quick regression gate, not
full stability acceptance. The
[REL01 decision](doc/vt7/architecture/2026-09-14-warp-development-deferral.md)
accepts this uncertainty for continued development and stops dedicated tracing.
No soak is requested now; later product qualification need not wait for complete
handle attribution. Existing runner verdicts and issued packages stay unchanged.
`-Renderer atlas-d3d-hardware` or `-Renderer atlas-d3d-warp` selects one backend
for investigation; its default is `both`. The quick runner also executes the
expected-failure idle control, even when one backend is selected.

Current source also contains opt-in `--resource-isolation` controls, documented
in the stability record. They are not present in the already-issued 0.3.5 zip
and are not acceptance profiles. No input or security feature is disabled by
the retained controls. Preserve the issued archive when building diagnostics.

The separate `VT7-resource-comparison-0.1-x64.zip` tests native Atlas WARP with
and without matched Windows power-notification subscriptions. It reuses the
issued 0.3.5 native DLL, runtimes and fonts; its `VT7.Host.exe` is a native-only
diagnostic, not the WPF application. Its reproduction launcher is
`RUN-RESOURCE-COMPARISON.cmd`, which creates a fresh
`Logs/resource-comparison-<run-id>` folder. Exit 0 means both measurements
completed, not that growth was accepted. Both supplied Windows 7 runs complete,
but both grow, unlike the development machine's power/plain contrast. Preserve
this result without treating the notification explanation as target-proven.
This is not a soak and needs no security exclusions or system-setting changes.
See the stability record for package identity and the completed thread-lifetime
investigation history. No repeat of this unchanged package is requested.

The separate [resource lifetime comparison 0.2](doc/vt7/diagnostics/2026-09-13-resource-lifetime.md)
implements the recreate/reuse follow-up as versioned native diagnostic source.
It dynamically loads the exact issued 0.3.5 DLL; it does not rebuild the product.
Build with `tools/Build-VT7ResourceLifetime.ps1`, then pass its `OutputDirectory`
to `tools/Package-VT7ResourceLifetime.ps1 -BuildDirectory`. Each build uses a
fresh directory; packaging refuses an existing 0.2 directory or ZIP. Developer
verification uses `tools/Test-VT7ResourceLifetime.ps1 -BinaryDirectory` against
an assembled diagnostic directory. These developer helpers require PowerShell
5.1 or newer. The distributed `RUN-RESOURCE-LIFETIME.cmd` uses a PowerShell 2.0
compatible runner with nine matched samples and a 600-second per-process timeout.
The supplied Windows 7 comparison now completes both modes and records growth
even with one reused surface. Its narrow question is answered; see the linked
record for findings and completed ownership-attribution history. No repeat of the
unchanged package is requested.

The [focused resource trace 0.3](doc/vt7/diagnostics/2026-09-13-resource-trace.md)
reuses those exact binaries and both matching private PDBs, without a rebuild.
`tools/Package-VT7ResourceTrace.ps1` creates a fresh package and refuses an
existing candidate. The target installs classic x64 Debugging Tools from the
Windows 8.1 SDK, then runs `RUN-RESOURCE-TRACE.cmd`. Its PowerShell 2.0 runner
checks hashes, debugger preflight and a separate startup control before a
25-iteration reuse trace. The
supplied 0.1 target preflight passed, but its trace waited at a first-chance
invalid-handle debugger prompt before application work. Version 0.2 records
and dispatches first chance, aborts on unhandled second chance or repeated
exceptions, and captures unexpected interactive stops. Its supplied target
capture records unhandled second chance during Windows startup, before native
DLL load or WARP work. Version 0.3 preserves that policy, adds a control without
the setup hook or handle tracing, and activates handle tracing at pre-warmup,
before the first surface. Its supplied target workload completes, but the issued
validator miscounts nested Token metadata. Corrected offline validation accepts
the existing capture; no new package or target rerun is needed. The trace now
links eleven additional Event handles to WARP/GetThreadDesktop and Windows
thread setup on existing worker identities. Resource lifetime and C3 remain
open. The [offline pool inspection](doc/vt7/diagnostics/2026-09-13-warp-pool-lifetime.md)
records the cleanup path and a 67-second factory idle timeout, beyond this
executable's fixed ten-second final wait. Keep the target's already working
SDK 8.1 installation.

The [resource retirement diagnostic 0.1](doc/vt7/diagnostics/2026-09-13-resource-retirement.md)
implements the successor with a new standalone EXE and unchanged issued native
DLL/runtime/fonts. Build using `tools/Build-VT7ResourceRetirement.ps1`, then
pass its fresh output directory to
`tools/Package-VT7ResourceRetirement.ps1 -BuildDirectory <directory>`.
The packager refuses an existing 0.1 directory or ZIP. Do not rebuild over an
issued candidate or change its runner pins without assigning a new identity.
The PowerShell 2-compatible target launcher, `RUN-RESOURCE-RETIREMENT.cmd`,
checks preflight and startup before 25 reuse iterations and post-close
observations at 10, 90 and 180 seconds. Allow four to six minutes and return the
entire new Logs folder. That target handoff now completes: WARP mode 3 work
cleanup returns and all 34 baseline Windows workers retire by 90 seconds, with
USER back to startup and 54 process handles still above startup at 180 seconds.
See the linked result for handle histories and limits. No unchanged repeat or
debugger reinstall is requested. Integrated C3 acceptance remains open; the
new WPF reactivation control below bridges this result to the actual host.

The [WPF resource reactivation diagnostic 0.1](doc/vt7/diagnostics/2026-09-14-resource-reactivation.md)
is now built and locally qualified. `tools/Build-VT7ResourceReactivation.ps1`
builds only the separate net48/x64 managed diagnostic from fresh source snapshots,
with .NET SDK 9.0.318 pinned for SDK resolution and the VS 2022/.NET Framework
4.8 tools. It does not build the native project or overwrite existing artifacts.
Before developer execution, stage the issued 0.3.5 native DLL, three VC runtime
DLLs and fonts alongside the new EXE and verify their issued manifest hashes.
`tools/Test-VT7ResourceReactivation.ps1 -BinaryDirectory <directory>` runs the
full fixed protocol; `-Case work-negative` or `-Case idle-negative` runs its
expected failure controls. Full collection takes about 16 minutes on the local
machine and has a 40-minute limit. The validator, runner controls, exact build
inputs and qualification evidence are linked from the diagnostic record.
`tools/Package-VT7ResourceReactivation.ps1 -BuildDirectory <directory>
-QualificationDirectory <directory>` verifies the completed qualification,
assembles the new package and refuses existing 0.1 outputs.

The supplied Windows 7 run completes in 655.156 seconds with 16 validated
samples and three immediate budget failures. Its two +180s states have identical
handle/thread/GDI/USER counts and a +220 KiB private-byte difference. See the
diagnostic record for identity histories, evidence hashes and limits. No unchanged
rerun is requested. For reproduction, extract
`VT7-resource-reactivation-0.1-x64.zip` into a new folder, run
`RUN-RESOURCE-REACTIVATION.cmd` and preserve the complete new Logs subfolder. The launcher selects 64-bit Windows PowerShell; its scripts were
qualified under actual PowerShell 2.0 and 5.1. No new runtime, SDK, debugger or
Visual Studio installation is needed on the user's configured target. The
package retains all eight immediate budget verdicts across both work/idle
rounds. Exit 3 means complete collection with resource failures, not an incomplete
trace; exit 0 means the immediate budgets also passed. Final C3 qualification
remains incomplete. Neither exit is a prerequisite to C4/3A under REL01.

## Pinned developer toolchain

The proof build is intentionally narrow and reproducible:

- Windows x64 development machine.
- Visual Studio 2022, version 17.14.
- MSVC v143, version 14.44.35207.
- Windows SDK 10.0.26100.0.
- .NET Framework 4.8 SDK and targeting pack.
- PowerShell 5.1 or newer to run the build scripts.

These are development-host requirements. VS 2022 17.7 and later cannot install
on Windows 7; build with the pinned 17.14 on the modern development machine
and test the resulting binaries on Windows 7. The trace debugger is a separate,
older SDK component. See [Microsoft's host compatibility guidance](https://learn.microsoft.com/en-us/troubleshoot/developer/visualstudio/installation/visual-studio-2022-unsupported-operating-systems).

The repository rejects another MSVC or Windows SDK version for VT7 projects.
This keeps compiler and import changes visible while the Windows 7 floor is
being established. Visual Studio 2026 is not part of the supported VT7 build
path.

The checked-in [.vsconfig](.vsconfig) describes the required Visual Studio
components. It does not install the toolchain silently.

## Build

From a PowerShell prompt in the repository root:

```powershell
.\tools\Build-VT7.ps1 -Configuration Debug
```

For a Release source build:

```powershell
.\tools\Build-VT7.ps1 -Configuration Release
```

The build script restores pinned WIL, GSL, and fmt headers from GitHub and
verifies their archive hashes. Internet access is needed on the first restore.
Dependency revisions, licensing, and proof-only source changes are documented
in [the core boundary notes](src/vt7/VT7.Core/README.md). After a verified restore,
`-NoRestore` permits an offline build using the existing extracted sources.

Build output is written under `artifacts\vt7\bin\<configuration>`. Current source
reports 0.5.2/ABI 11. The latest issued viewport archive remains 0.3.5/ABI 8 and
the later standalone diagnostics intentionally retain that exact payload. Use
the issued archive hash and package manifest when referring to its evidence.

Run the focused session-stream regression after either configuration:

```powershell
.\tools\Test-VT7SessionStream.ps1 -Configuration Debug
```

It requires an Atlas hardware device for deterministic capture. The test checks
single-write versus byte-at-a-time raster identity, every native UTF-8/VT split,
incomplete EOF, recovery and surface disposal. See the
[session stream contract](doc/vt7/architecture/2026-09-14-session-stream-foundation.md).

Run the focused generation/outbound/native-HWND regression after either
configuration:

```powershell
.\tools\Test-VT7SessionOutbound.ps1 -Configuration Debug
.\tools\Test-VT7SessionOutbound.ps1 -Configuration Release
```

It checks bounded admission, stale generations, FIFO drain, resize coalescing,
Croatian and AltGr committed input, handled character suppression, distinct
Ctrl+C/Break operations, TerminalCore non-text encoding and focus cleanup. See
the [session outbound contract](doc/vt7/architecture/2026-09-14-session-outbound-foundation.md).

Create the distinct non-overwriting Windows 7 candidate with:

```powershell
.\tools\Package-VT7SessionOutbound.ps1
```

Run `RUN-SESSION-OUTBOUND.cmd` after extracting the ZIP into a fresh writable
folder. It verifies every packaged hash using a Windows PowerShell 5.1-compatible
in-process SHA-256 implementation and creates a new folder beneath `Logs`.

Run the endpoint-independent S00 OpenSSH preflight against an installed client:

```powershell
.\tools\Test-VT7OpenSsh.ps1 -SshPath 'C:\Program Files\OpenSSH\ssh.exe'
```

It captures raw stdout and stderr separately, records exact client identity,
signature availability, algorithms and effective configuration, and verifies
bounded cancellation against a disposable stalled loopback peer. It does not
read credentials, connect to an SSH server, change machine configuration or
close S00's network requirements. Create the MIT-only target package with:

```powershell
.\tools\Package-VT7OpenSsh.ps1
```

After extracting the issued ZIP into a fresh writable directory,
`RUN-OPENSSH-S00-PREFLIGHT.cmd` creates a complete `Logs` child. The package does
not contain or redistribute OpenSSH; it discovers the existing Program Files
installation or `ssh.exe` on `PATH`. Its two Windows 7 runs are accepted, so no
unchanged rerun is requested. See the
[S00 record](doc/vt7/validation/2026-09-14-openssh-s00.md).

Create the controlled Debian-server diagnostic with:

```powershell
.\tools\Package-VT7OpenSshNetwork.ps1
```

Issued `VT7-OpenSSH-S00-Network-0.1-x64.zip` requires the accepted 10.0p2 client
hash. Its Windows 7 run is complete and needs no unchanged rerun. Strict trust,
key-only authentication, exact non-PTY bytes, negotiated algorithms, active
cancellation and final drain pass; forced PTY allocation reports 0 by 0 initial
dimensions. Package 0.1 retained the public host-key fingerprint and temporary
profile path in its changed-host diagnostic, contrary to its privacy claim.
Restricted raw and sanitized evidence are archived separately. Current source
retains only diagnostic classifications and defaults to package identity 0.2 if
the network runner is reissued. Exact 10.0p2 source proves that redirected
`ssh.exe` cannot obtain VT7's PTY size or observe VT7 resize events through its
Windows console path. S00 is complete and requests no further external-client
run. The owner approved SSH.NET 2026.0.0 and its permissive supplier notices for
S01. The separately versioned diagnostic and exact dependency/license inventory
are now implemented. Build, test and package it independently of `VT7.sln`:

```powershell
.\tools\Restore-VT7SshNet.ps1
.\tools\Build-VT7SshNet.ps1 -Configuration Release -NoRestore
.\tools\Test-VT7SshNet.ps1 -Configuration Release -SelfTest
.\tools\Package-VT7SshNet.ps1 -NoBuild
```

Package 0.5 proved the Windows 7 transport paths but exposed overly strict
cipher and disconnect assertions. Corrected package 0.6 passes its local checks
and both Windows 7 controlled-server runs. S01 is accepted as recorded in the
[validation record](doc/vt7/validation/2026-09-14-sshnet-s01.md).

The production host consumes the same locked closure. The commands below retain
the accepted 0.8.2 direct-profile reproduction path:

```powershell
.\tools\Restore-VT7SshNet.ps1
.\tools\Build-VT7.ps1 -Configuration Release -NoRestore
.\tools\Test-VT7SshNetFoundation.ps1 -Configuration Release
.\tools\Package-VT7SshNetDirect.ps1 -NoBuild
```

The package performs a recursive image/import audit, preserves every dependency
notice, runs its offline foundation check and independently verifies the ZIP.
The [direct-profile record](doc/vt7/validation/2026-09-19-sshnet-direct-profile.md)
contains the Windows 7 controlled-server procedure.

KH01.1 adds a disconnected known-host parser, matcher, raw-key resolver and
OpenSSH differential oracle without changing production trust. Build, test,
package and independently verify its candidate with:

```powershell
.\tools\Build-VT7.ps1 -Configuration Release
.\tools\Test-VT7KnownHosts.ps1 -Configuration Release
.\tools\Package-VT7KnownHosts.ps1 -NoBuild
.\tools\Verify-VT7KnownHostsPackage.ps1
```

The package launcher pins the Windows 7 oracle to `ssh-keygen.exe` file version
10.0.0.0. The local runner records rather than assumes the installed version.
Package 0.1 has passed on the Windows 7 target through that exact-version gate;
the success procedure intentionally returned no Logs directory.
See the [KH01.1 record](doc/vt7/validation/2026-09-22-known-hosts-kh01.md).

KH01.2 connects that foundation to both production SSH.NET paths in read-only
mode. Build, run the offline policy and overlay regressions, package and verify:

```powershell
.\tools\Build-VT7.ps1 -Configuration Release
.\tools\Test-VT7KnownHosts.ps1 -Configuration Release
.\tools\Test-VT7SshNetFoundation.ps1 -Configuration Release
.\tools\Test-VT7SshOverlay.ps1 -Configuration Release -AllowMissingPowerShell7
.\tools\Package-VT7KnownHostsReadOnly.ps1 -NoBuild
.\tools\Verify-VT7KnownHostsReadOnlyPackage.ps1
```

Package 0.3 stages the complete application and typed shim for the accepted
two-tier Windows 7 read-only trust matrix. Package 0.2 is retained as the
TURTLE-pass/NESSY-rejected dependency result. See the
[KH01.2 record](doc/vt7/validation/2026-09-22-known-hosts-kh01-2.md).

KH01.3 adds generation-safe unknown-host decisions and verified durable
addition to the primary user file. Build, run both focused corpora, package and
independently verify it with:

```powershell
.\tools\Build-VT7.ps1 -Configuration Release
.\tools\Test-VT7KnownHosts.ps1 -Configuration Release
.\tools\Test-VT7SshNetFoundation.ps1 -Configuration Release
.\tools\Test-VT7SshOverlay.ps1 -Configuration Release -AllowMissingPowerShell7
.\tools\Package-VT7KnownHostsFirstContact.ps1 -NoBuild
.\tools\Verify-VT7KnownHostsFirstContactPackage.ps1
```

Package 0.4 is non-overwriting and leaves accepted package 0.3 intact. Its
offline corpus uses disposable trust files. Only the controlled live **Trust
and connect** action writes the tester's primary user `known_hosts`. See the
[KH01.3 record](doc/vt7/validation/2026-09-24-known-hosts-kh01-3.md). The exact
package and complete controlled matrix are accepted on NESSY and TURTLE; keep
the archived evidence and do not request an unchanged rerun.

KH01.4 adds a deliberate changed-key review, selected primary-user record
removal with a verified `.old` backup, and CA-signed host-certificate policy.
Its new package is non-overwriting and carries a separate Windows 7 procedure:

```powershell
.\tools\Build-VT7.ps1 -Configuration Release
.\tools\Test-VT7KnownHosts.ps1 -Configuration Release
.\tools\Test-VT7SshNetFoundation.ps1 -Configuration Release
.\tools\Test-VT7SshOverlay.ps1 -Configuration Release -AllowMissingPowerShell7
.\tools\Package-VT7KnownHostsManagementInheritedAcl.ps1 -NoBuild
.\tools\Verify-VT7KnownHostsManagementInheritedAclPackage.ps1
```

The automated KH01.4 corpus uses disposable keys and files; it never reads the
tester’s real trust store. The controlled live removal is explicitly chosen in
the UI. See the [KH01.4 record](doc/vt7/validation/2026-09-24-known-hosts-kh01-4.md).
The issued package 0.5 passed local checks but failed its disposable ACL
read-back on both Windows 7 tiers. Version 0.12.1/package 0.6 corrects that
automated failure on both machines, but live removal stops before mutation
at `temporary-security`. Version 0.12.2/package 0.7 compares owner, group,
inheritance protection and exact DACL entries and fixes key-row contrast;
Package 0.7 fails the inherited-ACL fixture's obsolete exact-SDDL assertion
on NESSY. Version 0.12.3/package 0.8 corrects that assertion; use package 0.8
for the resumed target run.

Run the P01 local-console characterization after building either configuration:

```powershell
.\tools\Test-VT7WinPty.ps1 -Configuration Debug
.\tools\Test-VT7WinPty.ps1 -Configuration Release
```

The restore step verifies the official WinPTY 0.4.3 MSVC release archive and
each staged x64 library, agent, header and license. The eighteen-case runner retains
child console cells, exact backend bytes and final TerminalCore state. Reported
text/cursor differences are evidence; dependency drift, invalid/incomplete UTF-8,
timeouts, child failures or incomplete reports fail. See the
[P01 record](doc/vt7/validation/2026-09-14-winpty-p01.md).

Create a distinct Windows 7 test package with:

```powershell
.\tools\Package-VT7WinPty.ps1
```

The P01 packager refuses an existing destination, includes the exact WinPTY
native runtime and MIT license, includes the pinned app-local Visual C++ runtime,
and statically audits every native image before writing the ZIP. Its packaged
launcher supports Windows PowerShell 5.1. A code page that the target console
cannot select is recorded with `IsValidCodePage`, the set result, exact error and
actual code page; the runner then continues without sending bytes under the wrong
mapping.

Run the production Command Prompt transport regression after either integrated
build:

```powershell
.\tools\Test-VT7WinPtySession.ps1 -Configuration Debug
.\tools\Test-VT7WinPtySession.ps1 -Configuration Release
```

It verifies the exact pinned WinPTY DLL, agent and license, then proves explicit
profile construction, root generation 1, real input, one authoritative resize,
final output drain, child exit reporting and deterministic cancellation. Create
the non-overwriting 3B.1 Windows 7 candidate with:

```powershell
.\tools\Package-VT7WinPtyRoot.ps1
```

The package runs the 3A regressions and new real transport check from staged,
hash-verified bytes before writing and reopening the ZIP. On Windows 7 run
`RUN-WINPTY-ROOT.cmd`, return all `Logs`, then use
`RUN-VT7-COMMAND-PROMPT.cmd` for the manual interaction check documented in its
README. See the [3B.1 record](doc/vt7/validation/2026-09-17-winpty-root-3b.md).

The older integrated packaging scripts retain fixed output paths and delete/recreate those
folders and ZIPs. `-SkipBuild` skips compilation only; it does not preserve an
existing package. Do not run them over issued artifacts. `Package-VT7Proof.ps1`
is still pinned to 0.3.5 and intentionally rejects later application builds.
The P01 diagnostic and 0.5.2 WinPTY-root candidate use separate non-overwriting
package paths.

Run the I01 input characterization locally after building either configuration:

```powershell
.\tools\Test-VT7Input.ps1 -Configuration Debug -NonInteractive
.\tools\Test-VT7Input.ps1 -Configuration Release -NonInteractive
```

`-NonInteractive` is a smoke test only. The completed target run omitted that
switch and used the seven-step WPF/native-HWND recorder for Croatian HR Latin,
AltGr, dead-key, Ctrl, focus and resize evidence. The non-overwriting package
0.2 is preserved; do not rebuild or rerun it without a new question and
identity. See the [I01 record](doc/vt7/validation/2026-09-14-input-i01.md).

| Packaging script | Fixed package folder / ZIP stem under `artifacts` |
| --- | --- |
| `Package-VT7Proof.ps1` | `atlas-viewport-0.3.5` / `VT7-atlas-viewport-0.3.5-x64` |
| `Package-VT7RendererProbe.ps1` | `renderer-probe-0.13` / `VT7-renderer-probe-0.13-x64` |
| `Package-VT7AtlasProof.ps1` | `atlas-backend-proof-0.1` / `VT7-atlas-backend-proof-0.1-x64` |
| `Package-VT7WinPty.ps1` | Next identity `vt7/packages/VT7-WinPTY-P01-0.4-x64` / matching ZIP; refuses replacement. Issued target evidence remains package 0.3. |
| `Package-VT7WinPtyRoot.ps1` | `vt7/packages/VT7-WinPty-Root-0.5.2-x64` / matching ZIP; refuses replacement. Local package checks pass. Version 0.5.1 establishes Windows 7 wheel movement and retained history; the 0.5.2 printable-character snap-to-live correction passes on the supplied test machines. |
| `Package-VT7Input.ps1` | `vt7/packages/VT7-Input-I01-0.2-x64` / matching ZIP; refuses replacement. Package 0.2 completed on the target and is preserved. |
| `Package-VT7OpenSsh.ps1` | `vt7/packages/VT7-OpenSSH-S00-Preflight-0.2-x64` / matching ZIP; refuses replacement and contains no OpenSSH binary. |
| `Package-VT7OpenSshNetwork.ps1` | Next identity `vt7/packages/VT7-OpenSSH-S00-Network-0.2-x64` / matching ZIP; refuses replacement and contains no OpenSSH binary or secret. Issued target evidence remains package 0.1. |
| `Package-VT7SshNetDirect.ps1` | Current accepted `vt7/packages/VT7-SSHNET-Direct-0.4-x64` / matching ZIP; refuses replacement. It validates the actual Windows PowerShell 5.1 CMD launcher from a path containing spaces, every dialog label and the rendered Authentication selection at 4.5:1. Package 0.1 is rejected for its launcher defect; 0.2 is transport-accepted; 0.3 fixes labels but fails the focused selector visual check; 0.4 passes that check. Application 0.8.2/ABI 11, exact SSH.NET closure, 82 verified files. |
| `Package-VT7KnownHosts.ps1` | `vt7/packages/VT7-KnownHosts-KH01-0.1-x64` / matching ZIP; refuses replacement. It stages the disconnected KH01.1 foundation, exercises the PowerShell 5.1 CMD launcher from a path containing spaces and records the exact `ssh-keygen` oracle. `Verify-VT7KnownHostsPackage.ps1` repeats ZIP, binary and extracted-launcher validation independently. |
| `Package-VT7KnownHostsReadOnly.ps1` | `vt7/packages/VT7-KnownHosts-KH01-0.3-x64` / matching ZIP; refuses replacement. It stages VT7 0.10.1, publisher-built SSH.NET 2026.0.1-prerelease.6/f099365, the complete typed shim, KH01.2 read-only policy corpus, all notices and controlled-server instructions. Package 0.2 is preserved as the primary-pass/NESSY-rejected 2026.0.0 result. `Verify-VT7KnownHostsReadOnlyPackage.ps1` independently checks ZIP safety, hashes, manifest policy, binary closure and a fresh extracted run. |
| `Package-VT7KnownHostsFirstContact.ps1` | `vt7/packages/VT7-KnownHosts-KH01-0.4-x64` / matching ZIP; refuses replacement. It stages VT7 0.11.0, both SSH entry paths, generation-bound first-contact decisions, durable writer regressions, the pinned prerelease.6/f099365 closure and all notices. `Verify-VT7KnownHostsFirstContactPackage.ps1` checks ZIP safety, hashes, write-enabled manifest policy, binary closure and a fresh extracted run. |
| `Package-VT7KnownHostsManagement.ps1` | `vt7/packages/VT7-KnownHosts-KH01-0.5-x64` / matching ZIP; refuses replacement. It stages VT7 0.12.0, changed-key review, selected primary-user removal, host-certificate policy, the pinned SSH.NET closure and complete notices. `Verify-VT7KnownHostsManagementPackage.ps1` checks ZIP safety, hashes, policy fields, images and a fresh extracted run. |
| `Package-VT7KnownHostsManagementAcl.ps1` | Issued `vt7/packages/VT7-KnownHosts-KH01-0.6-x64` / matching ZIP; refuses replacement. It stages VT7 0.12.1 with pre-replacement owner/group/DACL copy and verification. Package 0.5 is retained as rejected two-machine evidence. `Verify-VT7KnownHostsManagementAclPackage.ps1` independently checks the archive and extracted launcher. The 0.6 ZIP is SHA256 `DF56400ACB1B0266CD8BB5E99757BB8F08411B058799B1E028BDF5B3D8B218EF` (15,247,563 bytes, 94 files); automation passes on both Windows 7 machines but live removal stops safely at `temporary-security`. |
| `Package-VT7KnownHostsManagementLiveAcl.ps1` | Issued non-overwriting `vt7/packages/VT7-KnownHosts-KH01-0.7-x64` / matching ZIP. It stages VT7 0.12.2 with structural owner/group/DACL comparison and legible changed-key rows. `Verify-VT7KnownHostsManagementLiveAclPackage.ps1` independently checks the archive and extracted launcher. SHA256 `402F077ACF230943554C50D964EE9100A02569B4359C1F17C8F254A1B0AF5FC5` (15,264,946 bytes, 94 files); rejected after NESSY's inherited-ACL test fails an obsolete exact-SDDL assertion. |
| `Package-VT7KnownHostsManagementInheritedAcl.ps1` | Issued non-overwriting `vt7/packages/VT7-KnownHosts-KH01-0.8-x64` / matching ZIP. It stages VT7 0.12.3 with the inherited-ACL test aligned to production's structural security check. `Verify-VT7KnownHostsManagementInheritedAclPackage.ps1` independently checks the archive and extracted launcher. SHA256 `16509A782C8EE629E74F8CE4D4FE11E265C93763BB2E75036AC3C5FEE6920AEE` (15,283,778 bytes, 94 files); automated and controlled live known-host management pass on both Windows 7 machines. |

Issued P01 package 0.3 used a culture-sensitive PowerShell row comparison that
ignored embedded NULs in the two Windows 7 raw-VT cases. The retained strings
were independently compared ordinally and source is corrected. Preserve package
0.3 and its evidence; no target rerun or package 0.4 build is requested.

The integrated packager tests assembled Release files before archiving and
includes runtime DLLs, symbols, notices, dependency licenses and file checksums.
Its stability gate is the quick profile, not lifecycle or soak acceptance.
Generated artifacts are ignored by Git. Preserve all issued archives and logs.

## Verify the binary boundary

The solution also builds the Milestone 2 `VT7.Renderer.lib` isolated target
and independent `VT7.RendererProbe.exe`. The library now links into VT7.Native,
with the real AtlasEngine/controller/font path and a selectable GDI reference.
The older backend harness remains independently testable. See the
[renderer boundary](src/vt7/VT7.Renderer/README.md).

For a focused source regression of the independent graphics/font probe:

```powershell
.\tools\Test-VT7RendererProbe.ps1 -Configuration Debug
.\tools\Build-VT7.ps1 -Configuration Release -NoRestore
.\tools\Test-VT7RendererProbe.ps1 -Configuration Release
```

The frozen archive is `artifacts\VT7-renderer-probe-0.13-x64.zip`. For an explicitly
needed reproduction on Windows 7, its launcher is `RUN-RENDERER-PROBE.cmd`;
retain `VT7-renderer-probe.log` and the companion
`VT7-renderer-probe.log.bmp`. Version 0.5 preserves the original 0.1 sample and
includes an independent U+1F600 coverage scan, explicit candidate rendering, thirteen
real-core-cell fixtures, whole-ink fitting, and retained Arabic visual runs.
Natural-size glyphs use a bounded two-pixel ink halo at the probe's fixed 96 DPI;
oversized groups remain strictly fitted. Cell allocation never changes.
The bitmap compares natural layout with an experimental fitted visual-run path;
structural mapping success is not visual or bidi acceptance. It uses hidden
graphics windows and offscreen readback, not a visible terminal. Optional newer
interfaces may be unavailable without failing the baseline. The native probe
does not require .NET or Power Automate. Keep the complete `fonts` directory:
the build/package copies pinned Unifont and Unifont Upper 17.0.05 with their
OFL 1.1 license and provenance. These are private probe assets, not system-installed
fonts or a change to VT7's MIT code license. `tools/Verify-VT7Fonts.ps1` checks
their hashes. Missing or altered assets fail the diagnostic.

`Verify-VT7.ps1` audits the probe when present. For its assembled package, use
`-Configuration Release -RendererProbeOnly -BinaryDirectory <package-folder>`;
this checks all packaged EXE/DLL files and requires the app-local CRT files.
The [probe validation record](doc/vt7/validation/2026-09-11-renderer-probe.md)
records the successful original 0.1 local and supplied Windows 7 capability runs.
The [2C font experiment record](doc/vt7/validation/2026-09-11-font-mapping-probe.md)
tracks the supplied Windows 7 0.2 results separately. The
[0.3 follow-up](doc/vt7/validation/2026-09-11-font-fitting-probe.md) records the
supplied Windows 7 run and user confirmation that KB2729094 is installed. The
[0.4 follow-up](doc/vt7/validation/2026-09-11-natural-size-probe.md) tracks natural-size
fitting and its supplied Windows 7 result. The
[0.5 follow-up](doc/vt7/validation/2026-09-11-private-font-probe.md) adds bounded
private symbol fallback and two forced private-font fixtures. The supplied
Windows 7 run passes 51 checks and all 13 mappings, including automatic private
U+1F600 fallback. This accepts the bounded experiment, not production font quality.
No AtlasEngine is linked into the probe and no renderer worker is started;
TerminalCore is linked only to supply authoritative fixture cell spans. The
earlier renderer-probe 0.1/0.2/0.3/0.4, Atlas backend 0.1, and GDI 0.2.1 archives are retained.

The [geometry/repaint plan](doc/vt7/architecture/2026-09-11-font-geometry-test-plan.md)
now has its first implementation in [probe 0.6](doc/vt7/validation/2026-09-11-geometry-probe.md).
The unchanged command also writes twelve `.log.bmp.geometry-<size>-<dpi>.bmp`
images, alongside the frozen 0.5 reference image. These 13 images remain part of
the current package's output. `Test-VT7Geometry.ps1` independently checks the matrix as
part of `Test-VT7RendererProbe.ps1`. Offscreen DPI is simulated; no display-setting
change is requested. Vertical REVIEW observations do not imply final typography
acceptance. The supplied Windows 7 0.6 run passes the matrix checks with the same
24 stacked-mark observations; its reference image matches the target 0.5 image.
Both accepted archives are retained.

[Probe 0.7](doc/vt7/validation/2026-09-11-repaint-probe.md) adds the differential
repaint experiment: 480 edits across the same 12 configurations, independent
full-frame comparisons, and deliberately broken old-ink/neighbor cases.
`Test-VT7Repaint.ps1` runs as part of the renderer suite. There are 42 additional
repaint images, for 55 bitmap outputs total on success. Return the log and all
bitmaps together, preferably zipped. Red pixels in explicitly named negative
difference images are expected; normal sample difference images must be black.
This remains an isolated software damage experiment, not Atlas integration.

The supplied 0.7 Windows 7 result passes. The approved vertical policy follows
upstream: fixed primary-font rows with ordinary glyph overhang and special
clipping exceptions. [Probe 0.8](doc/vt7/validation/2026-09-11-text-adapter-probe.md)
adds 12 `.adapter-<size>-<dpi>.bmp` comparisons, bringing the total to 67 bitmaps.
Its reusable mapper candidate selects faces with baseline DirectWrite layout,
then shapes original core order using the analyzer. N is visual paragraph layout;
T is logical terminal order with upstream-default metrics/advance correction.
Arabic/Hebrew N and T intentionally differ; joining and horizontal overhang
quality still need review. This is not the integrated Atlas font path.
`Test-VT7TextAdapter.ps1` independently checks 192 mappings and reported coverage
as part of the renderer suite. The suite also injects a stale-snapshot failure.

The supplied 0.8 Windows 7 structural run passes, while documenting horizontal
overflow and unresolved Arabic typography. [Probe 0.9](doc/vt7/validation/2026-09-11-horizontal-fitting-probe.md)
adds 12 `.horizontal-<size>-<dpi>.bmp` images, R (raw) versus F (fitted), for
79 outputs total. It preserves the earlier 67 images. Whole-group raster fitting,
neighbor sentinels, natural Latin/italic pixel identity, deliberate overflow
controls, and 72 conservative partial-row repaints are checked by the probe.
`Test-VT7Horizontal.ps1` independently validates the logged matrix and bitmap
structure. The suite injects an unfitted overflow that must fail the baseline.
The supplied Windows 7 0.9 containment run passes. Narrow-symbol quality and
Atlas integration remain open; no new system setting or update is required.

[Probe 0.10](doc/vt7/validation/2026-09-11-arabic-context-probe.md) adds 24
`.arabic-<size>-<dpi>-<page>.bmp` images, for 103 bitmaps on success. Its five
lanes separate native layout, legacy mapper, repaired logical/visual grid
projections, and repaired proportional text. Arabic context repair is a bounded
probe, not an enabled terminal bidi mode. Unsafe lam-alef splits are explicit
REVIEW observations. Run `Test-VT7Arabic.ps1 -ReportPath <log>` to validate the
matrix; the renderer suite also injects lost context and requires failure.
The supplied Windows 7 0.10 run passes its structural/context checks, with
96 repaired runs and 24 explicit lam-alef boundary reviews. The fixed-grid
cursive spacing decision remains open.

[Probe 0.11](doc/vt7/validation/2026-09-11-joined-span-probe.md) adds 12
`.joined-<size>-<dpi>.bmp` images, for 115 bitmaps on success. It compares
per-group fitting with a single transform across a fixture-declared Arabic
span inside its combined core allocation. `Test-VT7Joined.ps1 -ReportPath <log>`
checks the matrix, ownership, containment, negative controls and 72 partial
repaint records. The renderer suite injects broken relative run placement.
The supplied Windows 7 0.11 matrix passes, with all 103 earlier target BMPs unchanged.

[Probe 0.12](doc/vt7/validation/2026-09-11-cross-style-ligature-probe.md) adds 24
`.ligature-<size>-<dpi>-<page>.bmp` images. Return the log and all 139 BMPs in a
ZIP. N/L/A/X/C compare native split styles, whole-source shapes in each selected
face, a REVIEW-only spatial hybrid and same-outline two-color painting.
`Test-VT7Ligature.ps1 -ReportPath <log>` validates the matrix independently.
The suite also injects lost paint styling. Its per-process timeout is now 120
seconds for the expanded matrix. The supplied Windows 7 0.12 matrix passes.

[Probe 0.13](doc/vt7/validation/2026-09-11-marked-paint-probe.md) adds twelve
`.paint-<size>-<dpi>.bmp` pages for 151 BMPs total. Return all images and the log.
U/C/S compare uniform text, per-core-cluster colors and a snapped selection on
marked/joined words. `Test-VT7Paint.ps1` checks the matrix and source mapping.
The suite also swaps paint colors as a required negative. Cursor/hit testing
is not implemented. The supplied Windows 7 0.13 run passes all eight validators:
51 required checks, zero failures, 432 paint raster comparisons and 288 partial
paint repaints. All 139 earlier target BMPs remain byte-identical. Source
selection preserves bases with marks, but the long-word highlight still exposes
the mismatch between allocated cells and centered glyph positions. Interaction
mapping is deferred under Milestone 7/POL02, not an accepted production behavior
or the next build task. The [port-first plan](doc/vt7/architecture/2026-09-12-port-first-plan.md)
prioritizes minimal font adaptation and an integrated Atlas viewport. The probe
commands and frozen packages remain reproducible regression/research tools;
their optional typography policies need not be implemented to finish the port.

Run the static Windows 7 compatibility gate after a build:

```powershell
.\tools\Verify-VT7.ps1 -Configuration Debug
```

The gate currently checks:

- Both VT7 images are x64 PE files.
- Their operating-system and subsystem versions do not exceed 6.1.
- Their static imports do not include the known post-Windows 7 APIs prohibited
  by the proof architecture.
- Release verification applies the same PE and import checks to the three bundled
  Visual C++ runtime DLLs.
- The repository text follows the project punctuation rule.

Complete `dumpbin` header and import reports are saved under
`artifacts\vt7\reports`. Static import inspection is necessary, but it is not a
substitute for testing on Windows 7.

## Regression command reference

Choose checks for the code being changed. The accepted probe and scaling
matrices below are not the current handoff queue. Existing runners use fixed
report paths even with `-BinaryDirectory`, so preserve earlier evidence first.

### Atlas backend experiment

The solution also builds `VT7.AtlasProof.exe`, which links the real Atlas
backends and shared Windows 7 presentation code. It deliberately bypasses the
AtlasEngine font mapper and the TerminalCore/controller path.
It is separate from the integrated Atlas/WPF viewport and retained GDI reference.

```powershell
.\tools\Test-VT7AtlasProof.ps1 -Configuration Debug
.\tools\Test-VT7AtlasProof.ps1 -Configuration Release
```

The test runner executes both backends on forced hardware and forced WARP,
with 19 frames per combination, pre-Present pixel readback, resize/redraw,
color changes, explicit device recreation, and negative CLI/failure checks.
It writes reports and diagnostic PNGs under
`artifacts\vt7\reports\<configuration>\Atlas`. Each process has a 60-second limit.
PNGs show the back buffer, not the visible desktop.

The archive is `artifacts\VT7-atlas-backend-proof-0.1-x64.zip`. Extract it on
Windows 7 and run `RUN-ATLAS-TESTS.cmd`, then the hardware and WARP launchers
for visible testing. The batch launcher does not impose a hang timeout.
`Verify-VT7.ps1 -AtlasProofOnly -BinaryDirectory <package directory>` audits
every assembled EXE/DLL. No .NET or Power Automate is needed for this harness.
See the [backend validation record](doc/vt7/validation/2026-09-11-atlas-backend-proof.md)
for limitations and current evidence.

The issued 0.1 package passed all four automated combinations on Windows 7
SP1 x64. Visible hardware/WARP Direct3D11 sessions and repeated R-key
recreation also passed. Keep that archive unchanged as the tested checkpoint;
documentation-only updates do not require repackaging it. Rerunning a launcher
overwrites its own log/images, so preserve evidence before repeating tests.

### Integrated Atlas/GDI host and core checks

0.3.0 has supplied Windows 7 C1/C2 acceptance; 0.3.1 repaint/cursor checks also
pass on the supplied target setup. Use the following in Debug or Release:

```powershell
.\tools\Test-VT7AtlasRepaint.ps1 -Configuration Debug
```

This runs 32 exact comparisons and eight cursor-cell checks per Atlas mode,
across two window sizes, plus an expected-failure pixel-mismatch control.
Reports/captures: `artifacts/vt7/reports/<configuration>/Repaint/`.
See the [test design and limits](doc/vt7/validation/2026-09-12-atlas-repaint.md).

0.3.2 adds `tools/Test-VT7AtlasRecovery.ps1 -Configuration Debug` (or Release):
16 controlled startup, removal, exhausted-retry and close-during-backoff scenarios.
Reports/captures live under `artifacts/vt7/reports/<configuration>/Recovery/`.
Each process has a 45-second outer limit; the in-process asynchronous wait is
10 seconds. These are injected failures, not real driver-loss evidence. See the
[policy and remaining gates](doc/vt7/validation/2026-09-12-atlas-recovery.md).

0.3.2 now has supplied Windows 7 acceptance of that bounded recovery matrix.
0.3.3 adds `tools/Test-VT7AtlasSettings.ps1 -Configuration Debug` (or Release).
Corrective 0.3.4 retained that matrix and added startup work-area, status-layout and
blank-first-row controls to the viewport tests. Same-device recovery still
requires exact RGB; before/after geometry is logged. The 0.3.3 higher-DPI failures
are retained historically; 0.3.4 passes every positive suite at all three measured
Windows 7 scales on the supplied setup. To reproduce, run all five packaged
test launchers at each actual 100/125/150 percent scale. See the
[corrective build record](doc/vt7/validation/2026-09-12-atlas-scaling-correction.md).
Five Atlas modes each run 10 font/settings cases and eight invalid-input checks,
plus hidden updates. Two separate local negative controls verify geometry and
expected system-DPI rejection. Reports/20 captures are under
`artifacts/vt7/reports/<configuration>/Settings/`. Use `-ExpectedSystemDpi 96`,
`120` or `144` to assert the actual environment, not change it. Renderer DPI
overrides are simulations. See the [settings record](doc/vt7/validation/2026-09-12-atlas-settings.md).

The recommended local test command waits for each process, checks its exit
code, and requires a fresh passing report:

```powershell
.\tools\Test-VT7.ps1 -Configuration Debug
```

It runs headless diagnostics, six hidden viewport modes and a blank-frame
negative control. Use
`-Configuration Release` for a release build. Reports are written to
`artifacts\vt7\reports\<configuration>\diagnostics-gdi.log` and
`window-smoke-test-<renderer>.log`, with a PNG for each Atlas mode.
Use `-Renderers gdi` or `-Renderers atlas-d3d-warp` for a focused recheck.
`tools/Test-VT7FontAssets.ps1 -Configuration Release` checks missing/altered
private assets in disposable copies, without changing the source fonts.

The WPF application can execute its native and graphics checks without opening
a window:

```powershell
.\artifacts\vt7\bin\Debug\VT7.Host.exe `
    --diagnostics `
    --diagnostics-output .\artifacts\vt7\reports\Debug\runtime-diagnostics.log
```

Exit code 0 means all required proof probes passed. The report records the
native ABI, detected Windows version, .NET runtime, graphics adapter, hardware
Direct3D 11 result, WARP result, DXGI 1.2 availability, nine TerminalCore
regression results and the 48-case font-boundary check. A copy is also
written to `%LOCALAPPDATA%\VT7\Logs` when that directory is writable.

Normal startup opens the visual proof window:

```powershell
.\artifacts\vt7\bin\Debug\VT7.Host.exe
```

The automated window smoke test creates and disposes four WPF/native-window
pairs. Each cycle changes the host dimensions eight times, checks that the
terminal grid shrinks, forces native paints, minimizes/restores, resets the
demo, and checks that the child HWND is destroyed. At both large and small
sizes, it switches to Diagnostics and back, checks ten diagnostic values and
both selected/unselected tab-header colors, then verifies the same child HWND
and grid return visibly and repaint. There are eight tab round trips in total.

Atlas tests wait for a completed requested frame, inspect pre-Present header ink,
compare repeated reset hashes and verify no frame growth while the tab is hidden.
They save a full-sample back-buffer PNG with blinking disabled for determinism.
The injected blank frame must fail the header-ink check. These are integration
oracles, not a full text-correctness, differential repaint or idle-CPU suite.

The contrast gate requires at least 4.5:1 using the effective foreground and
background brushes in the live WPF visual tree. This is not a screenshot check
or a claim of full accessibility compliance. Font rasterization, clipping,
keyboard focus behavior, and high-contrast configurations need visual testing:

```powershell
.\artifacts\vt7\bin\Debug\VT7.Host.exe --window-smoke-test
```

## Windows 7 proof procedure, reproduction reference

The 0.3.4 scaling matrix and bounded 0.3.5 quick/lifecycle handoff already have
supplied results. Do not repeat them, repeat native comparison 0.1, or start the
timed soak for this documentation handoff. Current development is C4/3A session
feasibility, with WARP follow-up deferred as REL01 in [HANDOFF.md](doc/vt7/HANDOFF.md).
The procedure below remains a reference for a future relevant regression or
explicitly requested environment qualification.

The development machine can prove the build and binary boundary, but only a
Tier A Windows 7 system can establish compatibility. Use a clean snapshot with:

- Windows 7 SP1 x64.
- Platform Update KB2670838.
- .NET Framework 4.8. VT7 0.12.3 uses SSH.NET
  `2026.0.1-prerelease.6`/`f099365`, which carries the receive-MAC reset needed
  by the non-ESU `mscorlib.dll` `4.8.4110.0` implementation.
- The remaining prerequisites listed in [ROADMAP.md](ROADMAP.md).

Record the loaded runtime file version with:

```powershell
(Get-Item "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\mscorlib.dll").VersionInfo.FileVersion
```

The value distinguishes the two current Windows 7 test tiers. It is evidence,
not a minimum-version gate for package 0.3.

KH01.2 package 0.3 passes its automated corpus and both stored-key live SSH
paths on NESSY (`4.8.4110.0`) and TURTLE (`4.8.4795.0`). Preserve that accepted
evidence. KH01.3 package 0.4 also passes its automation and controlled
first-contact, persistence, reconnect and interaction matrix on both machines.
Preserve its accepted evidence.
KH01.4 package 0.8 passes automated and controlled live management checks on
NESSY and TURTLE. Repeat that matrix only for a new change or new evidence.

Copy and extract the entire 0.3.5 zip, including `fonts/`, on that machine.
Run `RUN-DIAGNOSTICS.cmd` and `RUN-VIEWPORT-TEST.cmd`, retaining
`VT7-diagnostics.log` and the complete `Logs` folder. The latter runs GDI and
all four forced Atlas backend/device modes plus automatic mode, with separate logs and Atlas PNG captures.
Run `RUN-REPAINT-TEST.cmd` and retain all logs/captures, including the expected
failure `repaint-negative.log`. Verify the visible `frames (snapshot)` label
becomes nonzero after startup; it is not a live counter.
Run `RUN-RECOVERY-TEST.cmd`. All 16 scenarios should PASS, including assertions
about intentionally exhausted retries. Keep every recovery log and PNG.
Run `RUN-SETTINGS-TEST.cmd` and choose the current actual Windows scaling.
To reproduce the accepted matrix, repeat all five suites at actual Windows 7
100/125/150 percent scaling, restarting
the Windows session/application after the OS change as required. Save work before
signing out. The launcher does not change the OS. It preserves different DPI runs
in separately named reports, but overwrites another run at the same DPI.
Capture normal/WARP viewport and Diagnostics screenshots at each scale and inspect
clipping, legibility and focus. Capture the initial window before manual resizing
to verify work-area fit. Preserve each scale's results separately. Expected fatal
AppData snapshots are not failed recovery verdicts; correlate them with the named
test reports as described in the correction record.
Then run `RUN-VT7.cmd` (automatic Atlas Direct3D11) and inspect the viewport:

- Confirm that colored text, bold, underline, and box drawing appear.
- Note missing or clipped accented, combining, and CJK glyphs, including the
  chosen fonts and display scaling. Also inspect the two fallback symbols.
  Logical-cell Arabic is inherited behavior, not the earlier joined-word experiment.
- Narrow and widen the window repeatedly. Content should reflow without a
  crash, persistent blank surface, or continually increasing resource use.
- Minimize, restore, switch the diagnostic/viewport tabs, and reset the demo.
- Confirm that both headers and diagnostic values are readable. Use Tab and
  arrow keys to switch tabs and check the visible focus indicator.
- Close and reopen the program several times. Save screenshots and all logs.

Repeat visible checks with `RUN-ATLAS-WARP.cmd`. `RUN-GDI-REFERENCE.cmd` selects
the old reference. For visible Direct2D checks use `VT7.Host.exe --renderer
atlas-d2d-hardware` or `--renderer atlas-d2d-warp`. Automatic mode (`atlas-auto`)
can switch hardware to WARP and reports the actual backend; forced modes never
switch. Archive logs before rerunning, since launchers overwrite
their own output names. Report hangs with partial logs, never as a pass.

Do not claim Windows 7 runtime compatibility from PE inspection or a newer
Windows test alone. Record the exact OS servicing level, graphics driver, CPU,
diagnostic log, and outcome for each test.

## Recorded Windows 7 results

The 0.3.4 corrective matrix is accepted on the supplied Windows 7 SP1 x64
setup, .NET Framework 4.8.4795.0, AMD Radeon RX 6800 XT, at actual 96/120/144 DPI.
At each scale, diagnostics, 6 viewport modes, 4 repaint modes, 16 injected
recovery cases and 5 settings modes pass. Recovery dimensions remain stable;
native work-area checks and normal/WARP launch screenshots confirm initial fit.
See the [complete acceptance record](doc/vt7/validation/2026-09-12-atlas-scaling-correction.md)
for archive identity, counts and expected negative/fatal snapshots. This closes
the bounded scaling checkpoint, not theme, stress, separate ESU or broader
device/driver qualification. The earlier records below retain their original scope.

Proof 0.2.0 has been tested on fully updated Windows 7 SP1 x64 setups without
ESU and with the full ESU update set. The supplied non-ESU reports show ABI 2
loading, all seven core checks passing, and four native-window lifecycles with
18 paints and 15 resizes each. Hardware D3D11 and WARP device creation succeed
at feature level 11.0. Screenshots confirm the visible static viewport.

The tester separately confirmed the ESU setup as working and tested. Separate
ESU logs and an exact per-system update inventory were not supplied for this
record. See the [validation notes](doc/vt7/validation/2026-09-10-viewport-proof.md)
for the evidence, known defect, and remaining coverage.

### Host-styling correction in 0.2.1

In 0.2.0, tab labels had insufficient contrast and diagnostic values could
appear almost invisible against their dark panels. This was a WPF foreground/
style inheritance problem, not missing data or a TerminalCore failure.

Version 0.2.1 explicitly pairs tab text/background colors, adds a keyboard-focus
outline, and makes the diagnostic style inherit the base text style with an
explicit light foreground. The new test reproduced the original 1.05:1
diagnostic contrast failure before the fix; the corrected controls pass with a
minimum measured ratio of 10.81:1 on the development machine.

The new hidden tests also exercise tab switching and viewport restoration.
The supplied 0.2.1 Windows 7 non-ESU logs pass all seven core checks, eight tab
round trips at a minimum 10.81:1 contrast, and four window lifecycles, each with
22 paints and 15 resizes. Screenshots show readable headers and values. The
tester confirms Tab/arrow-key navigation and visible focus, and separately
confirms that all tests pass on the ESU setup. This closes Milestone 1 cleanup
acceptance on those configurations, not the full release matrix. See the
[cleanup validation notes](doc/vt7/validation/2026-09-10-milestone-1-cleanup.md).

## Current proof architecture

`VT7.Host` is an x64 .NET Framework 4.8 WPF executable. It loads
`VT7.Native.dll` through a small versioned C ABI. The native bridge is compiled
with the Windows 7 target macros and exposes platform and Direct3D probes.

The graphics proof deliberately uses `CreateDXGIFactory1`, `IDXGIAdapter1`, and
`D3D11CreateDevice`. DXGI 1.2 is detected through a COM interface query instead
of a static `CreateDXGIFactory2` import. That pattern lets the same binary use
the Windows 7 Platform Update capabilities without binding startup to a newer
Windows export.

`VT7.Core.lib` now links the inherited parser and terminal state implementation
into the bridge. A WPF `HwndHost` embeds the selectable Atlas/GDI surface through
ABI 10 (0.3.6 used ABI 9, 0.3.5 used ABI 8, 0.3.4 used ABI 7, 0.3.3 used ABI 6, 0.3.2 used ABI 5, 0.3.1 used ABI 4).
The renderer uses Windows 7 events. It parks while hidden and stays alive until
native HWND destruction completes, then releases graphics and joins before the
surface is deleted. The core is compiled without WinRT settings or ICU search/URL
detection. See the core boundary notes for the exact limitations.

The bounded AtlasEngine font mapping and controller/core integration checks pass
locally and on the supplied Windows 7 setup. WARP lifecycle resource growth
remains unresolved, including the native-only target reproduction with and
without explicit power subscriptions. C3 renderer qualification, local PTY sessions,
SSH and the final UI remain ahead.
The separate Atlas backend proof is established on the tested Windows 7 setup.
The Windows 7 host/core/viewport proof is now established on the tested
non-ESU and ESU configurations. Minimal-prerequisite clean snapshots, broader
hardware coverage, production text rendering, and long-running session
stability still require separate validation.
