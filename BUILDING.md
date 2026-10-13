# Building VT7

Build on a modern Windows x64 development machine, then test the resulting
binaries on Windows 7. Use **VT7.sln**, not the inherited OpenConsole solution.
The [handoff](doc/vt7/HANDOFF.md) identifies the current candidate and target test.

## Developer prerequisites

| Component | Pinned requirement |
| --- | --- |
| Visual Studio | 2022, version 17.14 |
| MSVC | v143, 14.44.35207 |
| Windows SDK | 10.0.26100.0 |
| Managed targeting | .NET Framework 4.8 SDK and targeting pack |
| Build scripts | PowerShell 5.1 or newer |

The [.vsconfig](.vsconfig) lists the Visual Studio components. The VT7 projects
reject different MSVC/SDK versions so that compiler and import changes remain
visible. Visual Studio 2026 is not part of this build path.

These are development requirements. They do not require installing Visual
Studio or WMF 5.1 on a VT7 test machine. See the
[runtime prerequisites](doc/vt7/plan/compatibility.md) and
[legacy Windows 7 test record](doc/vt7/validation/2026-09-24-pre-wmf51-windows7.md).

## Build from the repository root

```powershell
.\tools\Build-VT7.ps1 -Configuration Debug
.\tools\Build-VT7.ps1 -Configuration Release
```

The first restore needs network access. The scripts verify pinned dependency
archives and license material. After a verified restore, `-NoRestore` permits
an offline build using the existing cache.

Output is under `artifacts\vt7\bin\<configuration>`. The managed application
currently reports 0.16.0; the issued native baseline is 0.12.3 / ABI 11. Product,
native, and diagnostic package versions are separate identities.

The [core notes](src/vt7/VT7.Core/README.md),
[renderer notes](src/vt7/VT7.Renderer/README.md), and
[third-party policy](doc/vt7/architecture/2026-09-14-third-party-licensing-policy.md)
explain source boundaries and provenance. Never substitute an unverified
dependency just to make a build pass.

## Choose checks for the change

The linked records explain prerequisites, commands, expected failures, and the
limits of each result. Run the checks relevant to the changed behavior and any
required package gates. This list does not request a rerun of every old probe.

| Area | Procedure or reference |
| --- | --- |
| Current SSH startup stalls | [SL01.3 procedure](doc/vt7/validation/2026-10-12-ssh-authenticated-startup-stalls-sl01-3.md), [portable README](src/vt7/packaging/SL01-3-README.txt) |
| Startup phase deadlines | [SL01.2](doc/vt7/validation/2026-10-11-ssh-startup-phase-deadlines-sl01-2.md) |
| SSH ownership and recovery | [SL01.1](doc/vt7/validation/2026-10-05-ssh-lifecycle-sl01-1.md) |
| Known hosts and certificates | [KH01.4](doc/vt7/validation/2026-09-24-known-hosts-kh01-4.md), [KH01.5](doc/vt7/validation/2026-10-05-known-hosts-kh01-5.md) |
| Local profiles and typed shim | [PowerShell profiles](doc/vt7/validation/2026-09-17-powershell-profiles-3b2.md), [H01](doc/vt7/validation/2026-09-19-typed-ssh-h01.md) |
| Session byte and input boundaries | [Stream tests](doc/vt7/architecture/2026-09-14-session-stream-foundation.md), [outbound tests](doc/vt7/architecture/2026-09-14-session-outbound-foundation.md) |
| Renderer, DPI, recovery, stability | [Validation index](doc/vt7/validation/README.md), [diagnostic command reference](doc/vt7/history/2026-10-12-build-and-diagnostic-reference.md) |

For example, the focused stream and outbound checks after a Debug build are:

```powershell
.\tools\Test-VT7SessionStream.ps1 -Configuration Debug
.\tools\Test-VT7SessionOutbound.ps1 -Configuration Debug
```

The stream capture requires an Atlas hardware device. A development-host pass
does not qualify the Windows 7 path or its full interactive shell corpus.

## Package a candidate

Each versioned packager has its own input and regression requirements. The
current [SL01.3 packager](tools/Package-VT7SshStartupStalls.ps1) requires a 0.16.0
Release host and the exact accepted SL01.2 candidate 0.4 archive. It assembles
a new stage, retains the native/dependency closure, records source hashes,
verifies contents, and refuses to replace an existing candidate.

Candidate 0.2 has already been issued. Do not rerun its packager over the issued
files or reuse its identity for changed contents. A new candidate needs a new
explicit package identity and matching runner/provenance checks.

Use the issued package's README for target testing. SL01.3's `--self-test`
needs no Debian fixture; live mode uses a separate fault peer. The server's
Python/Paramiko dependency is not a Windows runtime requirement.

## Preserve reproducibility

- Keep exact archive, binary, manifest, source, and dependency hashes in the
  dated validation record. Preserve failures and partial runs as well as passes.
- Keep the complete Logs and any required server audit together. Follow the
  current README's evidence instructions even when a run passes.
- Keep credentials, private keys, and ordinary terminal content out of reports.
- Separate local automation, Windows 7 automation, and my hands-on observations.
- Preserve issued artifacts when editing source documentation. Their manifests
  describe the inputs at issue time, not the latest working tree.

The [historical build and diagnostic reference](doc/vt7/history/2026-10-12-build-and-diagnostic-reference.md)
retains older binary-audit, packaging, renderer, and resource-investigation
commands. Its dated instructions are reproduction references. REL01 has stopped
dedicated WARP tracing; an old command is not a request to restart it.
