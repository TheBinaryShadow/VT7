# VT7 and inherited OpenConsole tools

For the Windows 7 port, start with [BUILDING.md](../BUILDING.md), the
[documentation index](../doc/vt7/README.md) and [current handoff](../doc/vt7/HANDOFF.md).
The `*-VT7*.ps1` scripts operate on `VT7.sln` and its separate artifact tree.
The inherited OpenConsole tools documented afterward are not the VT7 build or
Windows 7 acceptance workflow.

## VT7 command reference

Run these PowerShell scripts from the repository root. Build and test defaults
use `Debug`; test/verification runners accept `-Configuration Release` and
`-BinaryDirectory <folder>` where indicated. A binary-directory override does
not redirect their fixed report paths under `artifacts/vt7/reports`, so preserve
existing evidence before a relevant regression run.

| Script | Purpose and relevant options |
| --- | --- |
| `Build-VT7.ps1` | Builds `VT7.sln` for x64; `-Configuration` selects `Debug` or `Release`; `-NoRestore` uses a verified dependency restore. |
| `Restore-VT7Dependencies.ps1` | Verifies pinned WIL/GSL/fmt archive hashes, re-extracts their headers, and restores the exact audited SSH.NET closure used by the diagnostic and host. |
| `Verify-VT7.ps1` | x64 PE/version/import audit; `-Configuration`, `-BinaryDirectory`, and mutually exclusive `-RendererProbeOnly`, `-AtlasProofOnly`, `-WinPtyProbeOnly` or `-InputProbeOnly`. Package assembly may use `-AllowAnyCpuManaged`; it accepts the x86 PE machine field only with a nonzero CLR COM descriptor and keeps all OS/import checks. |
| `Verify-VT7Fonts.ps1` | Verifies pinned fonts/licenses; `-FontDirectory` selects the asset folder. |
| `Test-VT7.ps1` | Native/core diagnostics and viewport checks; `-Configuration`, `-BinaryDirectory`, `-Renderers`, `-SkipNegative`. |
| `Test-VT7SessionStream.ps1` | ABI 9 UTF-8/VT session ingress, exact chunk-boundary raster, EOF recovery and HWND teardown; `-Configuration`, `-BinaryDirectory`. |
| `Test-VT7SessionOutbound.ps1` | ABI 10 generation queue and native HWND input/control/focus/resize checks; `-Configuration`, `-BinaryDirectory`, optional collision-resistant `-OutputDirectory`. |
| `Test-VT7OpenSsh.ps1` | Endpoint-independent S00 preflight for an explicitly selected external `ssh.exe`; captures exact raw stdout/stderr, identity/signature, algorithms, effective configuration and bounded stalled-peer cancellation. Optional `-ExpectedSshSha256` and `-ExpectedVersionPattern` reject drift. |
| `Test-VT7OpenSshNetwork.ps1` | Controlled Debian S00 cases with an out-of-band Ed25519 fingerprint and dedicated key. Pins the accepted client; tests strict trust, negotiated algorithms, exact `-T` channels/exit, final drain, forced-PTY initial size and active cancellation. Corrected source retains only generic endpoint/credential classifications; issued 0.1 has the privacy defect recorded below. |
| `Restore-VT7SshNet.ps1` | Restores the locked thirteen-package SSH.NET 2026.0.1-prerelease.6/f099365 net48 closure from the retained publisher-built package plus NuGet.org transitive dependencies, verifies every audited package hash, and pins the exact source license/notices. |
| `Build-VT7SshNet.ps1` | Builds only the isolated net48/x64 S01 diagnostic; `-Configuration` selects Debug or Release and `-NoRestore` uses the verified lock result. |
| `Test-VT7SshNet.ps1` | Runs S01 from a build or package directory. `-SelfTest` checks loads, modern algorithms, encrypted-key parsing and credential redaction without a server; network mode runs the controlled trust/authentication/PTY/lifecycle matrix. |
| `Package-VT7SshNet.ps1` | Builds and self-tests the non-overwriting S01 package, preserves all exact dependency notices and metadata, verifies recursive hashes and ZIP entries, and emits the Windows 7 artifact. |
| `Test-VT7SshNetFoundation.ps1` | Runs the application-host 0.12.3 offline SSH.NET contract: exact prerelease.6/f099365 runtime closure, structured address-family validation, direct-root ownership, geometry, credential-owner disposal, connection-dialog contrast, generation-bound first-contact UI and changed-key management dialog text contrast. It makes no network connection. |
| `Package-VT7SshNetDirect.ps1` | Creates the non-overwriting 0.8.2/ABI 11 direct-profile package, stages the accepted SSH.NET 2026.0.0 closure and every required notice, audits every native or managed image, runs the actual PowerShell 5.1 CMD launcher from a package path containing spaces, and independently verifies every ZIP entry. Package 0.2 is transport-accepted on Windows 7; package 0.3 fixes labels but misses selected Authentication text; package 0.4 corrects it and passes focused visual confirmation. Typed `ssh` remains disabled. |
| `Test-VT7SshOverlay.ps1` | Runs the current 0.12.3 combined session stream/input, SSH.NET foundation and H01 corpus, retaining the accepted typed-overlay lifecycle case with a real shim held beyond the five-second handshake timeout, then records the exact installed external OpenSSH identity. The distributed runner strictly requires PowerShell 7.2.24; `-AllowMissingPowerShell7` is local-development only. |
| `Package-VT7SshOverlay.ps1` | Creates the non-overwriting 0.9.2/ABI 11 typed-overlay package, stages the shim and SSH.NET closure with all notices, runs the real Windows PowerShell batch path from a directory containing spaces, and independently verifies every ZIP entry. Package 0.1 exposed worker-thread WPF geometry access. Package 0.2 connects after that correction but applies the handshake timeout to the remote-session completion wait. Package 0.3 corrects both boundaries and passes the complete controlled Windows 7 matrix. |
| `Package-VT7KnownHostsReadOnly.ps1` | Creates the non-overwriting 0.10.1/ABI 11 KH01.2 package 0.3 with the full direct and typed SSH.NET application, publisher-built prerelease.6/f099365 dependency, read-only four-source known-host policy, complete license closure and two-tier Windows 7 procedure. Package 0.2 is preserved as the primary-pass/NESSY-rejected result. It runs overlay and KH01 diagnostics from a path containing spaces. `Verify-VT7KnownHostsReadOnlyPackage.ps1` independently verifies hashes, manifest policy, images and a fresh extracted run. |
| `Package-VT7KnownHostsFirstContact.ps1` | Creates the non-overwriting 0.11.0/ABI 11 KH01.3 package 0.4. It stages both SSH entry paths, the pinned prerelease.6/f099365 closure and complete notices; runs overlay and durable known-host diagnostics from a path containing spaces; and emits a write-enabled manifest plus a controlled NESSY/TURTLE procedure. `Verify-VT7KnownHostsFirstContactPackage.ps1` independently checks hashes, policy fields, images and a fresh extracted run. |
| `Package-VT7KnownHostsManagement.ps1` | Creates non-overwriting 0.12.0/ABI 11 KH01.4 package 0.5 with deliberate removal, `.old` recovery and certificate policy. It stages all notices, runs both focused and overlay checks from a path with spaces, and emits a separate controlled Windows 7 procedure. `Verify-VT7KnownHostsManagementPackage.ps1` checks every staged hash, manifest field, binary image and an extracted launcher. |
| `Package-VT7KnownHostsManagementAcl.ps1` | Creates non-overwriting 0.12.1/ABI 11 KH01.4 package 0.6 with an explicit fresh `FileSecurity` copy and exact pre-replacement ACL verification. Package 0.5 is rejected by both Windows 7 machines at security read-back. `Verify-VT7KnownHostsManagementAclPackage.ps1` checks every staged hash, manifest field, binary image and an extracted launcher. |
| `Package-VT7KnownHostsManagementLiveAcl.ps1` | Creates non-overwriting 0.12.2/ABI 11 KH01.4 package 0.7. It structurally verifies owner/group/DACL before replacement, preserves fail-closed mismatch categories, covers inherited and protected ACL fixtures and fixes changed-key row contrast. Package 0.6 passes automated Windows 7 checks but not live removal. `Verify-VT7KnownHostsManagementLiveAclPackage.ps1` checks the archive and extracted launcher. |
| `Package-VT7KnownHostsManagementInheritedAcl.ps1` | Creates non-overwriting 0.12.3/ABI 11 KH01.4 package 0.8. It changes the inherited-ACL fixture to use the production structural security contract after package 0.7 fails that obsolete exact-SDDL assertion on NESSY. `Verify-VT7KnownHostsManagementInheritedAclPackage.ps1` checks the archive and extracted launcher. |
| `Test-VT7AtlasRepaint.ps1` | Exact repaint/cursor checks; `-Configuration`, `-BinaryDirectory`, `-Renderers`; retains its expected-failure control. |
| `Test-VT7AtlasRecovery.ps1` | Controlled recovery scenarios; `-Configuration`, `-BinaryDirectory`. |
| `Test-VT7AtlasSettings.ps1` | Font/settings checks; `-Configuration`, `-BinaryDirectory`, `-ExpectedSystemDpi` accepts `0`, `96`, `120` or `144`. Zero leaves the actual DPI unasserted. |
| `Test-VT7AtlasStability.ps1` | Quick by default; `-Lifecycle` and `-Soak` are mutually exclusive; `-Renderer` accepts `both`, `atlas-d3d-hardware` or `atlas-d3d-warp`; `-Configuration`, `-BinaryDirectory`. |
| `Test-VT7RendererProbe.ps1` / `Test-VT7AtlasProof.ps1` | Independent historical harness regressions; `-Configuration`, `-BinaryDirectory`. |
| `Build-VT7ResourceRetirement.ps1` | Builds only the standalone retirement sampler into a fresh diagnostic directory, using pinned tools. |
| `Package-VT7ResourceRetirement.ps1` | Requires `-BuildDirectory`; combines the new sampler with unchanged issued native assets, verifies provenance and ZIP contents, and refuses existing candidate outputs. |
| `Test-VT7ResourceRetirement.ps1` | PowerShell 2-compatible validator fixtures and optional supplied-log checks; `-CompleteLog`, `-PreflightLog`, `-StartupLog`. |
| `Test-VT7ResourceRetirementSampler.ps1` / `Test-VT7RetirementDebuggerHooks.ps1` | Standalone sampler rejection/cleanup controls and guarded debugger-command fixtures. See the [retirement protocol](../doc/vt7/diagnostics/2026-09-13-resource-retirement.md) for exact scope. |
| `Test-VT7RetirementExceptionPolicy.ps1` / `Test-VT7RetirementFallback.ps1` | SDK 8.1 debugger controls for exception dispatch/caps, immediate idle abort and unexpected-stop capture/termination. |
| `Build-VT7ResourceReactivation.ps1` | Separate net48/x64 WPF diagnostic from fresh source snapshots; pinned .NET SDK 9.0.318 and VS 2022 MSBuild; no native build. |
| `Test-VT7ResourceReactivation.ps1` | Requires `-BinaryDirectory` with the issued native/runtime/fonts staged; `-Case full` (default), `work-negative` or `idle-negative`; all runs have new output directories. |
| `Test-VT7ReactivationValidator.ps1` | Requires `-ReportPath`; verifies the complete real report, then rejects 22 altered/failed controls. Default `-ExitCode 3` retains budget failures. |
| `Test-VT7ReactivationRunner.ps1` | `-BinaryDirectory`, new `-OutputDirectory`; PS2-compatible CLI, timeout, exit-code, checksum and protocol-override rejection controls. |
| `Package-VT7ResourceReactivation.ps1` | Requires `-BuildDirectory`, `-QualificationDirectory`; checks qualified sources/evidence, preserves inherited bytes and refuses existing 0.1 outputs. |
| `Test-VT7WinPty.ps1` | Runs the eighteen-case P01 child/WinPTY/TerminalCore comparison. Fidelity and unavailable code pages are recorded; dependency, lifecycle, UTF-8, timeout and evidence failures abort. Supports standalone package paths and collision-resistant run identities. |
| `Test-VT7WinPtySession.ps1` | Runs the production `WinPtyTransport` and explicit Command Prompt profile through `TerminalSession`: Unicode environment, generation-1 input, authoritative resize, output drain, exit code and cancellation. |
| `Test-VT7PowerShellProfiles.ps1` | Runs 0.6.6 clean-profile Windows PowerShell 5.1 and exact PowerShell 7.2.24 contracts through production WinPTY. Windows PowerShell accepts its legacy ConsoleHost editor when PSReadLine is not auto-loaded; PowerShell 7 still requires PSReadLine prediction capability. Visible editing behavior remains manual. `-AllowMissingPowerShell7` is for local development only; the distributed target runner is strict. |
| `Test-VT7H01.ps1` | Runs the 0.7.3 H01 grammar, authenticated local shim/broker, exact fallback, wrong-capability and committed WinPTY barrier checks. The distributed runner strictly requires Command Prompt, Windows PowerShell 5.1 and PowerShell 7.2.24; `-AllowMissingPowerShell7` is local-development only. |
| `Package-VT7WinPty.ps1` | Builds and verifies the Release x64 P01 diagnostic, stages the pinned WinPTY native runtime, MIT license and app-local VC runtime, then creates a non-overwriting ZIP. |
| `Package-VT7WinPtyRoot.ps1` | Creates the non-overwriting 0.5.2/ABI 11 3B.1 Command Prompt candidate, runs the 3A regressions and real WinPTY transport check from staged bytes, includes native wheel scrollback and committed-character snap-to-live, and validates every ZIP entry. The candidate is 11,161,619 bytes with SHA256 `BDB12430AF3325EA4ED4AAE153CF7AF355411BF57E3DD4E4303132C372499A87`. |
| `Package-VT7PowerShellProfiles.ps1` | Creates the non-overwriting 0.6.6/ABI 11 3B.2 HwndHost keyboard-sink candidate with three local launchers, strict Windows 7 5.1/7.2.24 validation, ordinary-profile instructions and retained dependency notices. Local staging may explicitly skip absent or unqualified PowerShell 7; the issued CMD runner cannot. |
| `Package-VT7H01.ps1` | Creates the non-overwriting 0.7.3/ABI 11 H01 package 0.4, stages the shim under both command and explicit-system names, runs local staged checks, preserves notices and symbols, then independently validates every ZIP entry. That package is accepted on Windows 7. It enables no embedded SSH backend and makes no network connection. |
| `Test-VT7Input.ps1` | Runs the I01 native keyboard-layout and TerminalInput characterization, then opens the WPF/native-focus recorder. `-NonInteractive` performs the local automation-safe smoke test; target acceptance requires the guided interactive run. |
| `Package-VT7SessionOutbound.ps1` | Creates the non-overwriting 0.3.7 x64 target candidate whose exact Windows 7 run is accepted, verifies its native images and licenses, tests staged hashes, and validates every ZIP entry. |
| `Package-VT7SessionOwnership.ps1` | Creates the non-overwriting 0.4.0/ABI 11 3A target candidate whose exact Windows 7 run is accepted, runs document/view, fake-transport and prior outbound checks from staged bytes, and validates every ZIP entry. |
| `Package-VT7OpenSsh.ps1` | Creates the non-overwriting MIT-only S00 preflight package. It does not include OpenSSH; the target runner verifies itself and discovers the installed client under Program Files or on `PATH`. |
| `Package-VT7OpenSshNetwork.ps1` | Creates the non-overwriting controlled-server S00 package. It contains no OpenSSH binary or secret, pins the accepted client hash and verifies the packaged files before prompting for runtime-only connection values. |
| `Package-VT7Input.ps1` | Builds and verifies the Release x64 I01 diagnostic, stages its two probes with the existing license notices and app-local VC runtime, then creates a non-overwriting ZIP. |

The P01 row comparison uses `StringComparison.Ordinal`. Issued package 0.3 used
PowerShell culture comparison, which ignored embedded NULs in two raw-VT rows;
the target evidence retains both strings and its independent analysis corrects
the classification without a rerun. The next package identity is 0.4.

I01 package 0.2 now has a complete Windows 7 Croatian HR Latin run. Flags 1 and
5 both change `ToUnicodeEx` dead state on that target. The native-HWND committed
text/key and coalesced-resize decision is recorded in the
[I01 validation record](../doc/vt7/validation/2026-09-14-input-i01.md). Preserve
the package and returned evidence; no unchanged rerun is requested.

S00 preflight package 0.2 is accepted for the target's existing OpenSSH install.
It contains only VT7's MIT-licensed scripts and project notices, and it makes no
network connection beyond a disposable loopback stalled-peer cancellation
case. Two complete Windows 7 runs pin the exact Microsoft 10.0p2 x64 client and
repeat its endpoint-independent behavior. Preserve them; no unchanged rerun is
requested. See the
[S00 record](../doc/vt7/validation/2026-09-14-openssh-s00.md).

Controlled-server package 0.1 completes on the owner's Debian 12 endpoint and
dedicated `sshtest` account. It has eight top-level files, 16,203 bytes and
SHA256 `8029CC9CF48F9BAEA839F16F3E104A552F848AB17A4A12636C966145B421B7FA`.
The package passes Windows PowerShell 5.1 self-verification before and after ZIP
extraction, and rejects an altered packaged file. Its target run passes strict
trust, key-only authentication, exact channels, negotiation, final drain and
active cancellation. Forced PTY starts at 0 by 0. Its changed-host diagnostic
retained a public host fingerprint and temporary profile path despite the stated
privacy boundary; raw evidence is restricted and a sanitized copy is archived.
Current source fixes that retention and advances the default reissue to 0.2.
No unchanged network rerun is requested. Exact Microsoft 10.0p2 source confirms
that redirected `ssh.exe` cannot obtain VT7's PTY size or observe VT7 resize
events through its Windows console path. S00 is complete: the external client is
accepted for non-PTY command transport and rejected for interactive VT7 SSH.
The owner approved SSH.NET 2026.0.0 and its permissive supplier notices for S01.
The locked closure is now incorporated by both the isolated diagnostic and the
0.8.2 application host. Its
0.5 target run proved the trust, authentication, command, PTY, resize, drain,
cancellation and isolation paths. Corrected 0.6 passes local checks plus both
Windows 7 controlled-Debian runs and is the accepted S01 package.
See the [S01 record](../doc/vt7/validation/2026-09-14-sshnet-s01.md).

The current application source reports 0.12.3/ABI 11 and includes the native
document/view split, managed session/transport foundation, real Command Prompt
WinPTY root plus resource-isolation diagnostics absent from the issued 0.3.5
archive. The exact 0.5.0 Windows 7 package passes its automated runners and
manual Unicode workflow. Active-command Ctrl+C works; prompt-line cancellation
is a known WinPTY limit. Version 0.5.1 proves native wheel movement and retained
history on Windows 7. Version 0.5.2 corrects printable-character snap-to-live,
and the supplied checks pass. Version 0.6.6 retains the explicit selectable
PowerShell profiles and adds a tested WPF keyboard-sink path after 0.6.5 proved
that direct Win32 focus alone did not retain terminal navigation keys. Version
0.7.0 added the H01 typed-command shim and passed all embedded target paths, but
package 0.1 failed Windows 7 external fallback with duplicated console handles.
Package 0.2 shows the original handles reject inheritance-flag changes there.
Package 0.3 then proves Windows 7 rejects traditional console handles inside the
explicit handle list at `CreateProcessW`. Version 0.7.3 uses the documented
Windows 7 standard-handle transfer and retains the handle list on Windows 8+;
package 0.4 passes the strict Windows 7 three-shell run. H01 is accepted for its
bounded diagnostic scope. Version 0.8.0 adds the separate direct SSH.NET root
profile; corrected package 0.2 passes its complete Windows 7 controlled-server
matrix plus separate `htop` and `nano` runs. Version 0.8.1/package 0.3 corrects
the logical form labels but fails focused visual confirmation because the
generated selected Authentication item remains light. Version 0.8.2/package 0.4
styles and checks that rendered selection, and its focused Windows 7 visual
confirmation passes. Version 0.9.2/package 0.3 completes and target-accepts the
typed SSH overlay integration.
`Test-VT7KnownHosts.ps1` runs the KH01 parser, matcher, raw-key trust resolver,
four-source immutable loader, read-only authorization policy, deterministic
arbitrary-byte corpus and disposable
`ssh-keygen -F/-H/-R` differential oracle. `Package-VT7KnownHosts.ps1` creates
the refuse-overwrite package and exercises its CMD launcher from a path with
spaces. `Verify-VT7KnownHostsPackage.ps1` independently checks ZIP safety,
manifest fields, every staged SHA256, PE/dependency policy and a fresh extracted
run. Package 0.1 is locally verified against `ssh-keygen.exe` 9.5.5.2; its
launcher requires file version 10.0.0.0 on the Windows 7 target, where the owner
reports a clean pass. Package 0.2 adds the 0.10.0 production read path and passes
the primary machine, but is rejected after both live SSH.NET paths fail on NESSY
through upstream issue 1829. Version 0.10.1/package 0.3 pins publisher-built
SSH.NET prerelease.6/f099365. Its automated corpus and both live SSH paths pass
on NESSY and TURTLE, accepting KH01.2 across the two runtime tiers. Version
0.11.0/KH01.3 adds disposable tests for generation-bound retry pins, safe
primary-user addition, ACL and byte preservation, stale-store rejection,
concurrent writers and exact read-back. The diagnostics never read real trust
files or connect to a server; only an explicit live **Trust and connect** choice
writes the production primary user file. Package 0.4 and its complete controlled
matrix pass on NESSY and TURTLE; preserve the accepted evidence under
`artifacts/vt7/evidence/known-hosts-kh01-3-win7-0.4` and do not request an
unchanged rerun.
Version 0.12.0/KH01.4 adds selected ordinary user-record removal with an exact
`.old` copy and host-certificate CA/principal/validity/revocation checks. Its
automated tests use disposable files and a newly signed OpenSSH host
certificate. Package 0.5 fails ACL read-back on both Windows 7 tiers because
an unmodified `FileSecurity` object did not persist. Version 0.12.1 copies the
descriptor into a fresh object and verifies it before replacement; target
acceptance is tracked separately.
These opt-in host CLI controls
are documented in the [stability record](../doc/vt7/validation/2026-09-13-atlas-stability.md);
the stability runner does not expose a resource-isolation parameter. The separate
native comparison 0.1 has its own packaged launcher and reuses the issued native
DLL. Both modes grow on Windows 7; exit 0 means measurement completion. The
integrated WARP lifecycle gate remains open. No unchanged-suite repeat or timed
soak is requested. The completed recreate/reuse comparison and trace 0.3 identify
the target WARP call path. The locally qualified
[retirement diagnostic 0.1](../doc/vt7/diagnostics/2026-09-13-resource-retirement.md)
now has a completed Windows 7 capture: actual mode 3 work cleanup, retirement
of all 34 baseline Windows workers by 90 seconds and USER back to startup.
Process handles retain a 54-handle startup delta through 180 seconds. Integrated
host lifecycle/idle behavior and residual repeatability are now tested by the
separate, locally qualified [WPF reactivation 0.1](../doc/vt7/diagnostics/2026-09-14-resource-reactivation.md).
Its Windows 7 capture now completes and validates all 16 samples, retaining
three immediate failures. Both +180s samples have identical handle/thread/GDI/USER
counts and only +220 KiB private-byte growth. No unchanged rerun is needed;
the [REL01 decision](../doc/vt7/architecture/2026-09-14-warp-development-deferral.md)
now stops dedicated tracing and permits C4/3A development. The original resource
failures and unrun soak remain recorded. These scripts are reproduction tools,
not a pending diagnostic queue. Release review conditionally revisits the risk.

`Package-VT7Proof.ps1`, `Package-VT7RendererProbe.ps1` and
`Package-VT7AtlasProof.ps1` delete/recreate fixed package folders and archives
for viewport 0.3.5, probe 0.13 and backend proof 0.1 respectively. They expose
only `-SkipBuild`, not a destination override. Do not run them over issued
artifacts during this investigation. Future packaging needs distinct paths and
identity first. Packaging success and quick gates are not full target acceptance.

## Inherited OpenConsole workflow

These are a collection of tools and scripts to make your life building the
OpenConsole project easier. Many of them are designed to be functional clones of
tools that we used to use when developing inside the Windows build system.

## Razzle

This is a script that quickly sets up your environment variables so that these
tools can run easily. It's named after another script used by Windows developers
to similar effect.
 - It adds msbuild to your path.
 - It adds the tools directory to your path as well, so all these scripts are
 easily available.
 - It executes `\tools\.razzlerc.cmd` to add any other personal configuration to
 your environment as well, or creates one if it doesn't exist.
 - It sets up the default build configuration to be 'Debug'. If you'd like to
 manually specify a build configuration, pass the parameter `dbg` for Debug, and
 `rel` for Release.

## bcz

`bcz` can quick be used to clean and build the project. By default, it builds
the `%DEFAULT_CONFIGURATION%` configuration, which is `Debug` if you use `razzle.cmd`.

 - `bcz dbg` can be used to manually build the Debug configuration.
 - `bcz rel` can be used to manually build the Release configuration.


## opencon (and openbash, openps)

`opencon` can be used to launch the **last built** OpenConsole binary. If given an
argument, it will try and run that program in the launched window. Otherwise, it
will default to cmd.exe.

`openbash` is similar, it immediately launches bash.exe (the Windows Subsystem
for Linux entrypoint) in your `~` directory.

Likewise, `openps` launches powershell.

## runformat & runxamlformat

`runxamlformat` will format `.xaml` files to match our coding style. `runformat`
will format the c++ code (and will also call `runxamlformat`). **`runformat`
should be called before making a new PR**, to ensure that code is formatted
correctly. If it isn't, the CI will prevent your PR from merging.

The C++ code is formatted with `clang-format`. Many editors have built-in
support for automatically running clang-format on save.

Our XAML code is formatted with
[XamlStyler](https://github.com/Xavalon/XamlStyler). I don't have a good way of
running this on save, but you can add a `git` hook to format before committing
`.xaml` files. To do so, add the following to your `.git/hooks/pre-commit` file:

```sh
# XAML Styler - xstyler.exe pre-commit Git Hook
# Documentation: https://github.com/Xavalon/XamlStyler/wiki
# Originally from https://github.com/Xavalon/XamlStyler/wiki/Git-Hook

# Define path to xstyler.exe
XSTYLER_PATH="dotnet tool run xstyler --"

# Define path to XAML Styler configuration
XSTYLER_CONFIG="XamlStyler.json"

echo "Running XAML Styler on committed XAML files"
git diff --cached --name-only --diff-filter=ACM  | grep -e '\.xaml$' | \
# Wrap in brackets to preserve variable through loop
{
    files=""
    # Build list of files to pass to xstyler.exe
    while read FILE; do
        if [ "$files" == "" ]; then
            files="$FILE";
        else
            files="$files,$FILE";
        fi
    done

    if [ "$files" != "" ]; then
        # Check if external configuration is specified
        [ -z "$XSTYLER_CONFIG" ] && configParam="" || configParam="-c $XSTYLER_CONFIG"

        # Format XAML files
        $XSTYLER_PATH -f "$files" $configParam

        for i in $(echo $files | sed "s/,/ /g")
        do
            #strip BOM
            sed -i '1s/^\xEF\xBB\xBF//' $i
            unix2dos $i
            # stage updated file
            git add -u $i
        done
    else
        echo "No XAML files detected in commit"
    fi

    exit 0
}
```

## testcon, runut, runft
`runut` will automatically run all of the unit tests through TAEF. `runft` will
run the feature tests, and `testcon` runs all of them. They'll pass any
arguments through to TAEF, so you can more finely control the testing.

A recommended workflow is the following command:
```
bcz dbg && runut /name:*<name of test>*
```
Where `<name of test>` is the name of the test testing the relevant feature area
you're working on. For example, if I was working on the VT Mouse input support,
I would use `MouseInputTest` as that string, to isolate the mouse input tests.
If you'd like to run all the tests, just ignore the `/name` param:
`bcz dbg && runut`

To make sure your code is ready for a pull request, run the build, then launch
the built console, then run the tests in it. The built console will inherit all
of the razzle environment, so you can immediately start using the macros:
 1. `bcz`
 2. `opencon`
 3. `testcon` (in the new console window)
 4. `runformat`

If they all come out green, then you're ready for a pull request!
