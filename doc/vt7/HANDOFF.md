# VT7 development handoff

Updated: 2026-09-24. Current source is version 0.11.0/native ABI 11. Version
0.6.6 remains accepted across the
Windows 7 PowerShell/profile and keyboard matrix. H01 packages 0.1 through 0.3
pass the Command Prompt, PowerShell 5.1 and PowerShell 7.2.24 embedded/barrier
paths while successively exposing the Windows 7 fallback restrictions: timeout,
`SetHandleInformation` error 87, then `CreateProcessW` error 1450 when traditional
console handles enter the extended handle list. Version 0.7.3 uses the native
Windows 7 standard-handle inheritance rule and keeps the explicit handle list on
Windows 8 or later. Package 0.4 passes the strict Windows 7 three-shell run and
H01 is accepted. Version 0.8.0 integrates the S01-accepted SSH.NET closure and
adds the first direct remote root profile. Corrected package 0.2 passes its full
Windows 7 controlled-server matrix, and separate `htop` and `nano` runs expose
no issue. Version 0.8.1/package 0.3 corrects the form labels, but its focused
visual check finds the selected Authentication item still light-on-light.
Version 0.8.2/package 0.4 gives that generated text an explicit dark template;
its focused Windows 7 visual confirmation passes. Version 0.9.0 implements the
typed SSH overlay coordinator. Package 0.1 passed target automation but failed
real typed connections at a worker-thread WPF geometry access. Version 0.9.1/
package 0.2 fixes that boundary and connects on Windows 7, but the accepted shim
times out after five seconds and later root return stalls. Version 0.9.2/package
0.3 corrects both lifecycle boundaries and passes the complete target matrix.
Version 0.10.0 implements KH01.2 read-only OpenSSH known-host trust. Package 0.2
passes the primary machine but is rejected after both SSH.NET paths fail on the
NESSY non-ESU .NET runtime. Version 0.10.1/package 0.3 pins upstream
2026.0.1-prerelease.6/f099365. Its automated corpus and both stored-key live SSH
paths pass on NESSY and TURTLE, accepting KH01.2 across both Windows 7 runtime
tiers.
Version 0.11.0 implements KH01.3 generation-safe unknown-host decisions and
durable primary-user-file addition for both SSH entry paths. Package 0.4 passes
local Release, staged path-with-spaces and independent extracted verification,
then passes the complete automated and controlled live matrix on NESSY and
TURTLE. KH01.3 is target accepted across both Windows 7 runtime tiers.
This is the current resumption guide. Start with the [documentation index](README.md)
if unfamiliar with the repository. The [roadmap](../../ROADMAP.md) owns gates;
dated validation records own test claims.

## Where we are

VT7 is an independent MIT-licensed Windows 7 SP1 x64 terminal application port.
Keep new VT7-authored code MIT licensed where possible. The owner's standing
2026-09-14 decision permits compatible permissive dependencies and assets,
including Apache-2.0, ISC-style, BSD-style and broader supplier notices, when
they help deliver the port. Record exact provenance and retain every required
notice. A materially restrictive, source-sharing, network-use or proprietary
term still requires a separate compatibility review. The
[standing licensing policy](architecture/2026-09-14-third-party-licensing-policy.md)
owns this decision. `NOTICE.md` now combines legal disclosure, upstream
references and human thanks.
The current application starts Command Prompt, Windows PowerShell 5.1 or a
versioned PowerShell 7 through pinned WinPTY 0.4.3, bounded session queues and
the TerminalCore-backed Atlas viewport inside a .NET Framework 4.8 WPF host.
The viewport selector deterministically replaces the active root session. Normal
PowerShell launches preserve user profiles and settings; only controlled tests
use `-NoProfile`. The accepted Command Prompt transport, Croatian text, Unicode
filename, child GUI, scrollback and printable-input snap behavior remain intact.
The exact 5.1/7.2.24 clean-profile transport and ordinary-profile corpus passes
on Windows 7. VT7 0.8.0 also has an accepted direct SSH.NET root session with
mandatory pinned-fingerprint trust, private-key/password authentication, remote
PTY geometry and live resize. The full required Windows 7 matrix passes, as do
separate `htop` and `nano` runs. Version 0.9.2 carries the Windows 7-accepted
production typed SSH overlay. Version 0.10.0 adds immutable read-only snapshots
of the four default OpenSSH trust sources to both SSH.NET paths. Version 0.10.1
carries the upstream Windows 7 receive-MAC correction and is accepted on both
current test tiers. VT7 has no production tabs/panes, final profile management,
or selection implementation yet.
The visible viewport/Diagnostics tabs and profile selector belong to the proof
host, not the finished multi-session UI. Version 0.6.5 returns Win32 focus to the
native HWND after shell startup/replacement and applies explicit selector colors,
but its navigation keys still escape into WPF. Version 0.6.6 handles them at the
`HwndHost` keyboard-sink boundary and passes the focused Windows 7 retest.

Port first. Preserve pinned upstream behavior wherever possible and adapt the
Windows 7 boundaries. Required correctness, security, accessibility and resource
lifetime are blockers when affected; optional typography and refinements belong
in Milestone 7. The owner-approved
[WARP development deferral](architecture/2026-09-14-warp-development-deferral.md)
moves the known resource concern to REL01 release-readiness review and stops
the dedicated tracing campaign. C4/3A is implemented and target accepted; its
document/transport/view contract now forms the 0.4.0/ABI 11 ownership boundary.
The first shared output boundary is implemented and S00 has rejected redirected
external OpenSSH for interactive PTY sessions.
Neither WARP attribution nor the earlier Arabic/geometry experiment chain is the
default next task. The typed overlay gate is accepted. The
[OpenSSH-compatible known-host management specification](architecture/2026-09-21-openssh-known-hosts-management-spec.md)
is complete. KH01.1 is implemented and passes local Debug, Release and package
verification. Package 0.1 also passes on Windows 7 through the mandatory 10.0p2
oracle gate. KH01.2 package 0.2 exposed the upstream SSH.NET 2026.0.0 failure on
NESSY; corrected package 0.3 passes on NESSY and TURTLE. KH01.3 package 0.4 is
locally and independently verified and its two-machine acceptance matrix passes.
KH01.4 deliberate removal/replacement and certificate policy is the current task.

| Item | Current state |
| --- | --- |
| Working application version | 0.11.0, native ABI 11, x64. It retains target-accepted KH01.2 and the publisher-built SSH.NET prerelease.6/f099365 fix, then adds target-accepted KH01.3 first-contact prompting and durable user-store addition to both SSH.NET paths. |
| Milestone 1 | Complete on the tested configurations, with the evidence limits in its record. |
| C1 minimum font boundary and C2 Atlas integration | Accepted on the supplied Windows 7 setup in 0.3.0. |
| C3 repaint, controlled recovery, scaling | Bounded 0.3.1/0.3.2 results and actual 0.3.4 96/120/144 DPI matrix accepted. |
| C3 scheduling/resource lifetime | Test failures preserved; further WARP tracing stopped and deferred as REL01. Quick hardware/WARP and hardware 100-cycle lifecycle pass on both setups. This concern no longer blocks feature development; final qualification is incomplete. |
| Timed soak | Not run on either setup. No immediate request; sustained-use qualification belongs with the assembled product and REL01 review, without requiring complete attribution first. |
| Latest resource target diagnostic | WPF reactivation 0.1 completes both 100-lifecycle rounds and all 16 checkpoints in 655.156 seconds, retaining three immediate budget failures. Both +180s states have 1,314 handles, 13 threads, GDI 18 and USER 10; private bytes rise by 220 KiB. |
| Remaining lifetime question | The two late integrated counts repeat, but individual handle identities/owners and a permanent bound are unproven. Final WPF handles remain 1,090 above pre-warm-up; this includes initialization and diagnostic effects. The previous native-only residual is 54 and is not directly comparable. |
| Latest local diagnostic | WPF resource reactivation 0.1 completes two 100-lifecycle batches and closed +10/+90/+180s observations after each, in one process. All 16 checkpoints validate and all eight immediate budget failures remain. The native 0.3.5 DLL is unchanged. |
| Session stream foundation | Implemented and locally validated in Debug and Release. Ordered transport-thread output reaches a per-surface decoder and TerminalCore through a bounded dispatcher queue; incomplete EOF and recovery are explicit. |
| Session ownership review | The supplied pushed-commit analysis was reconciled with the tree and its remaining 3A requirement is implemented and target accepted: production session/TerminalCore identity is separate from HWND/WPF presentation, with generation-safe transports and originating-transport replies. Version 0.5.0 now routes production resize to WinPTY for the Command Prompt slice. |
| 3A implementation specification | Implemented through 3A.1 and 3A.2 in 0.4.0. The [terminal document/transport/typed-SSH design](architecture/2026-09-14-terminal-document-and-ssh-handoff-spec.md) defines the wider handoff path; ABI 11 typed identities, managed transport lifecycle, bounded per-origin replies and fake root/overlay generations pass locally and on Windows 7. The first production local transport is implemented in 0.5.0, H01 is accepted in 0.7.3, and the direct remote root is implemented in 0.8.0. |
| 3A validation | Debug and Release builds pass the six-renderer smoke matrix, injected blank negative, session outbound and session stream checks. The exact Windows 7 run destroys the first HWND, drains 388 bytes with no attached view, reattaches generation 2 to raster `D90BE1DA17351A44`, switches fake root/overlay input generations 1/2/3, returns a TerminalCore device reply to its originating transport, and closes once. |
| 3A target package | Accepted `VT7-Session-Ownership-0.4.0-x64.zip`, SHA256 `93DFB2B35D94DE6610C8734889D837594D593F3584F0FAE78F4679853AAE0449`, 10,642,845 bytes, 27 verified files. Both target reports pass with package-matching host/native hashes. The three supplied files and independent analysis are archived under `artifacts/vt7/evidence/session-ownership-win7-0.4.0`. |
| 3B.1 implementation | `WinPtyTransport` owns the exact WinPTY 0.4.3 runtime, pipes, child handle, read loop and cancellation. The explicit Command Prompt profile pins executable, arguments, working directory and Unicode environment. Input and resize retain the 3A queue; EOF drains before child exit reporting. Local Debug and Release pass real spawn/input/100x30 resize/drain/exit 37, cancellation, 3A regressions and the full renderer/host suite. |
| 3B.1 accepted target package | `VT7-WinPty-Root-0.5.0-x64.zip`, SHA256 `5BC66EB5149301140BCB916EC270349DB1BC955309FEB3949B5C65E2185E5F3E`, 11,158,230 bytes, 33 verified files. All three target runners pass with package-matching hashes. Manual Croatian text, Notepad launch and `ććć.txt` creation pass. Active-command Ctrl+C works; prompt-line cancellation has the known WinPTY limitation. Ctrl+V/Ctrl+A retain classic control-character behavior. |
| 3B.1 scrollback result | `VT7-WinPty-Root-0.5.1-x64.zip`, SHA256 `2A0532EDA35B1B9D4CF805830C72DB8E82FC01941D96F87CEC1B5D57B68B46C0`, 11,193,875 bytes, 33 verified files. Windows 7 accepts wheel movement and retained history during output. Printable characters fail snap-to-live while Backspace, Delete and arrows pass. |
| 3B.1 accepted input-snap package | `VT7-WinPty-Root-0.5.2-x64.zip`, SHA256 `BDB12430AF3325EA4ED4AAE153CF7AF355411BF57E3DD4E4303132C372499A87`, 11,161,619 bytes, 33 verified files. Debug/Release verification and all three staged package runners pass locally. The supplied test-machine checks confirm printable input snaps to live output with no further issue. |
| 3B.1 target evidence | Seven supplied files plus `ARCHIVE-VERIFICATION.json` are preserved under `artifacts/vt7/evidence/winpty-root-win7-0.5.0`, 13,016 bytes. Target: Windows 7 SP1 x64, .NET 4.8.4795.0, PowerShell 5.1.14409.1005, `hr-HR`, RX 6800 XT. |
| 3B.2 implementation | Typed profiles pin executable, arguments, environment, working directory and discovered version. Ordinary PowerShell preserves user profiles; clean diagnostics verify 5.1/7.2.24 runtime, PSReadLine, completion, multiline input, Croatian text, native child, 108x32 resize, drain and exit. The UI and CLI select profiles and deterministic replacement closes the prior root. |
| 3B.2 rejected 0.6.0 candidate | `VT7-PowerShell-Profiles-0.6.0-x64.zip`, SHA256 `20EE217D36A9F7808DF0A289FD4DF5C0EFA8DEE2C717FCF079692939D770E596`, 11,185,489 bytes. Its first three runners pass on Windows 7, then the clean Windows PowerShell 5.1 case times out after a one-write multiline submission. Runtime discovery is correct: 5.1.14409.1005 and 7.2.24. Manual checks were paused. |
| 3B.2 rejected 0.6.1 candidate | `VT7-PowerShell-Profiles-0.6.1-x64.zip`, SHA256 `8D3B880E91A999A6A8954BA4CE0E7839A0E4E7E45E72C5C125F89C909A22A06F`, 11,192,382 bytes. Two target runs again pass the first three runners and time out in clean 5.1. Splitting the block did not fix the retained CRLF input terminator. Manual checks remain paused. |
| 3B.2 rejected 0.6.2 candidate | `VT7-PowerShell-Profiles-0.6.2-x64.zip`, SHA256 `469ED3F3C1ED914D7A89D3AF5D7C4036AE0121E0F84DB4D7976F01DBE27F949C`, 11,048,234 bytes. Its target counters record all four writes, 575 input bytes and output after every line, including the final exit expression, but the interactive continuation construct remains alive. Manual checks stayed paused. |
| 3B.2 rejected 0.6.3 candidate | `VT7-PowerShell-Profiles-0.6.3-x64.zip`, SHA256 `ECE1E0980B85506063324F523CC6F571FA0004D18F95384B8987A0050D43439D`, 11,044,543 bytes. The target exits normally with code 84, proving the Windows PowerShell 5.1 runtime, input and process lifecycle while identifying that PSReadLine is not auto-loaded. Requiring that optional editor was the remaining gate error. |
| 3B.2 accepted 0.6.4 candidate | `VT7-PowerShell-Profiles-0.6.4-x64.zip`, SHA256 `3B961B0E31ABD208C056A3B846C68F3BAF9899BFD91FDCD98AADD23A8E35BE46`, 11,043,866 bytes, 36 verified files. All four Windows 7 stages pass. Windows PowerShell 5.1 uses its accepted legacy editor; PowerShell 7.2.24 loads PSReadLine 2.1.0 with prediction capability. Ordinary Unicode, multiline, native child, resize, scrollback and lifecycle behavior passes. The run exposed WPF focus retention and selector contrast defects. |
| 3B.2 rejected 0.6.5 keyboard correction | `VT7-PowerShell-Profiles-0.6.5-x64.zip`, SHA256 `265165882549FE1BC8A67BAA3AD50046FC82A0793BFEA3E37E3551724E3BAB59`, 11,147,565 bytes, 36 verified files. Returns Win32 focus to the child HWND, implements `TabIntoCore`, verifies `WM_GETDLGCODE`, and gives the selector explicit colors. All automated checks and Windows 7 startup/replacement/shutdown pass, but Tab, Down and End still escape through WPF; Home returns from Diagnostics to the viewport tab after End moves focus out. The regression checked native focus and dialog codes but omitted `IKeyboardInputSink`. |
| 3B.2 accepted 0.6.6 keyboard-sink correction | `VT7-PowerShell-Profiles-0.6.6-x64.zip`, SHA256 `AB3B0C644674FE3B9C33EF11CAAE53E6D584E2957CF339E3D1B80E2E40F32B93`, 11,150,252 bytes, 36 verified files. Overrides `HwndHost.TranslateAcceleratorCore` and `TranslateCharCore` so terminal keys cross the WPF/native boundary before control traversal. The focused regression exercises Tab, Down, End and printable-text ownership through `IKeyboardInputSink`. Debug/Release, all four Windows 7 stages, all-profile manual keys and independent ZIP verification pass. No ABI, transport or dependency changed. |
| 3B.2 target evidence | The accepted 0.6.4 Logs folder, manual notes and screenshots are preserved under `artifacts/vt7/evidence/powershell-profiles-win7-0.6.4`. The passing 0.6.5 automated logs and failed manual-key disposition are under `artifacts/vt7/evidence/powershell-profiles-win7-0.6.5`. The accepted 0.6.6 automated logs and manual-key disposition are under `artifacts/vt7/evidence/powershell-profiles-win7-0.6.6`. Every archive has per-file SHA-256 metadata. |
| H01 implementation | Accepted for its bounded diagnostic scope. The native Windows 7-subsystem shim and managed broker implement the restricted typed grammar, per-session authenticated named pipe, PID/creation-time/ancestry/console checks, exact hashed fallback and a visible marker recognized only after WinPTY bytes commit through `SessionOutputPump`. Version 0.7.3 detects the real OS version: Windows 7 launches fallback with its native standard-handle inheritance behavior, while Windows 8 or later uses the explicit child handle list. The standalone H01 package does not enable embedded SSH; version 0.9.2 integrates its accepted boundary. |
| H01 rejected package 0.1 | `VT7-H01-0.1-x64.zip`, SHA256 `6428C10B3D446BD735D3E4E2F4596FAD7423E97EC6ACD1E40C2899EB09930820`, 11,938,989 bytes, 35 verified files. Two Windows 7 runs pass grammar and all three embedded/barrier paths, including exact PowerShell 7.2.24, then time out waiting for the external fixture. Evidence is archived under `artifacts/vt7/evidence/h01-win7-0.1-rejected`. |
| H01 rejected package 0.2 | `VT7-H01-0.2-x64.zip`, SHA256 `CF26FE708C844E3A764C89C766F6EF974A115E5921ADD688C15EA2B6D5784362`, 11,923,429 bytes, 35 verified files. Two Windows 7 runs again pass all embedded paths, then external fallback reports `SetHandleInformation failed ... (Win32 87)`. Evidence is archived under `artifacts/vt7/evidence/h01-win7-0.2-rejected`. |
| H01 rejected package 0.3 | `VT7-H01-0.3-x64.zip`, SHA256 `4EBED0D43DC516E7B5211467F941EB419B134CA8F924C4013E30853AD2BEC79C`, 11,915,112 bytes, 35 verified files. The target again passes all embedded paths, then external fallback reports `CreateProcessW external SSH failed (Win32 1450)`. Traditional Windows 7 console handles cannot be placed reliably in `PROC_THREAD_ATTRIBUTE_HANDLE_LIST`. Evidence is archived under `artifacts/vt7/evidence/h01-win7-0.3-rejected`. |
| H01 accepted package | `VT7-H01-0.4-x64.zip`, SHA256 `8B38721372CBCE51A8DC9EDC451756491A9FA742F3AD164F9EB3FB2F8375DA24`, 11,925,339 bytes, 35 verified files. Debug, Release, staged H01 and independent ZIP verification pass locally. The strict Windows 7 run passes grammar, all three embedded/barrier shell paths, exact fallback argv/exit/sanitization and wrong-capability denial. |
| H01 accepted evidence | The two returned files plus `ARCHIVE-VERIFICATION.json` are preserved under `artifacts/vt7/evidence/h01-win7-0.4-accepted`. Target: Windows 7 SP1 x64, .NET 4.8.4795.0, PowerShell 5.1.14409.1005, PowerShell 7.2.24, `hr-HR`, RX 6800 XT. |
| P01 WinPTY characterization | Complete. The official 0.4.3 native x64 artifacts are pinned. Debug, Release and all eighteen Windows 7 package 0.3 cases complete with verified evidence. WinPTY is selected for Windows 7 local legacy-console sessions behind the replaceable session boundary; raw VT, code-page, cursor-width and intermediate-state limits are explicit. |
| P01 target package | `VT7-WinPTY-P01-0.3-x64.zip`, SHA256 `6DD8560EDE4B4FEE9CCA3BC972F0437DAD216D9D0FE168E29989D96012CFDBCF`, 959,977 bytes, 15 verified files. Same-hash copy at `K:\VT7_work\VT7-WinPTY-P01-0.3-x64.zip`. Its complete target run has 109 files and 1,062,782 bytes. |
| I01 input characterization | Complete for the Windows 7 Croatian HR Latin 3A decision. Both controls receive required Croatian/AltGr text. Flags 1 and 5 both mutate `ToUnicodeEx` dead state. Native key/character, focus and resize ordering define the input adapter contract; broader layouts, printable repeat and IME remain in 3C. |
| I01 target package | `VT7-Input-I01-0.2-x64.zip`, SHA256 `45E730BDB00A27D3A42B6A61AB9A302E42CA118C18359B3364022B0CA75FF7E8`, 355,069 bytes, 13 verified files. Same-hash copy at `K:\VT7_work\VT7-Input-I01-0.2-x64.zip`. Its completed target run has 4 files and 354,713 bytes. Package 0.1 is a rejected local runner candidate and was not issued. |
| Session outbound 0.3.7 | Implemented and validated in Debug/Release and on the exact Windows 7 SP1 x64 candidate. ABI 10 encodes native-HWND committed/non-text input through TerminalInput without live-thread layout translation. One bounded generation queue orders bytes, Interrupt/Break, focus and the native authoritative resize. |
| Session outbound target package | `VT7-Session-Outbound-0.3.7-x64.zip`, SHA256 `1762520CD18A63E5A7BD30C7708658DA92B195830A3D68282A83FB21A4360CFC`, 10,560,527 bytes, 26 verified files. The accepted run has 2 files and 2,807 bytes; its host/native hashes match the package. |
| S00 OpenSSH evaluation | Complete. Preflight and controlled Debian cases accept exact Microsoft 10.0p2 x64 `ssh.exe` command bytes, strict trust, key authentication, negotiation, drain and cancellation. Forced PTY reports 0 by 0. Exact source proves its Windows geometry path requires console output and input events that VT7's redirected pipes cannot supply. External OpenSSH is accepted for non-PTY command transport and rejected for interactive VT7 SSH. |
| S00 preflight package | `VT7-OpenSSH-S00-Preflight-0.2-x64.zip`, SHA256 `1F8FE67D0E388D82248B6383035BE03E848D8FB3E71F85EE27C297ADF4149395`, 12,248 bytes, 8 verified files. It contains no OpenSSH binary. Both complete target runs are archived byte-identically as 44 files and 35,558 bytes. |
| S00 network package | Issued 0.1 is `VT7-OpenSSH-S00-Network-0.1-x64.zip`, SHA256 `8029CC9CF48F9BAEA839F16F3E104A552F848AB17A4A12636C966145B421B7FA`, 16,203 bytes, 8 verified top-level files. Its complete target run has 16 files and 149,987 bytes. The changed-host diagnostic retained a public host fingerprint and temporary profile path despite its privacy claim; raw evidence is restricted and a safe copy is archived. Corrected source advances any reissue to 0.2. |
| S01 candidate | Accepted. The isolated [SSH.NET 2026.0.0 diagnostic](validation/2026-09-14-sshnet-s01.md) passes its exact locked thirteen-package net48 closure and both Windows 7 controlled-Debian runs. Version 0.8.0 now incorporates that exact closure in the product host. |
| S01 target package | Accepted `VT7-SSHNET-S01-0.6-x64.zip`, SHA256 `7200827585B88E337AC3CD2074DDF34D1E6B5EF433A4FD4A305395DBF869292E`, 3,258,501 bytes, 62 verified files. Public-key-only and optional-password runs both pass; no credential fields are retained. The three sanitized manifests and verification metadata are archived under `artifacts/vt7/evidence/sshnet-s01-win7-0.6`. |
| Direct SSH.NET implementation | [Version 0.8.0](validation/2026-09-19-sshnet-direct-profile.md) implements `SshNetTransport`, ephemeral connection UI, mandatory SHA256 fingerprint verification, root PTY creation, ordered byte ingress, actual pixel/cell resize and stream-first shutdown through ABI 11. Debug/Release and all affected local regressions pass. |
| Direct SSH.NET rejected package 0.1 | `VT7-SSHNET-Direct-0.1-x64.zip`, SHA256 `764840E82E9979A82BC1C58850E0961B14B67556568FA89157BD56540A95724B`, 14,458,736 bytes, 82 verified files. Its first Windows 7 attempt stopped before log creation because quoted trailing `%~dp0` corrupted the following PowerShell 5.1 argument. No VT7 executable or network path ran. |
| Direct SSH.NET accepted transport package | `VT7-SSHNET-Direct-0.2-x64.zip`, SHA256 `5D11B42D94835C946E45D8ED8D9D261B2F3812E49FA293AB7EE9FB9430BB78D5`, 14,458,800 bytes, 82 verified files. The Windows 7 foundation and controlled Debian matrix pass, including trust/authentication, PTY/resize, Unicode/output, scrollback, EOF/idle-close, reconnect and local-profile isolation. Separate `htop` and `nano` runs also pass. The sole reported defect is low connection-dialog text contrast. |
| Direct SSH.NET rejected contrast package 0.3 | `VT7-SSHNET-Direct-0.3-x64.zip`, SHA256 `04C56F61FF3A23C52DB89E70A153A61932C37E4C59DE3323B9D2B376E8721D96`, 14,465,404 bytes, 82 verified files. Its Windows 7 foundation test passes and its ordinary form labels are readable, but the selected **Private key** Authentication item remains light-on-light. The logical-label assertion did not inspect the generated selector visual. Supplied evidence is archived under `artifacts/vt7/evidence/sshnet-direct-win7-0.3-contrast-rejected`. |
| Direct SSH.NET accepted contrast package 0.4 | `VT7-SSHNET-Direct-0.4-x64.zip`, SHA256 `FA4B2054EA9B68D4E78EE43FB838F358F2CD87D13F5B06A385ACC497B0D1BD46`, 14,459,542 bytes, 82 verified files. Version 0.8.2 gives the authentication choices an explicit dark template; the foundation check lays out the real selector and verifies its rendered selected text at 4.5:1. Debug/Release, all affected regressions, staged CMD launch, binary audit and ZIP verification pass. The owner confirms the closed selection and opened choices are readable and look correct on Windows 7. |
| Typed SSH overlay implementation | Version 0.9.0 connects the accepted H01 broker to SSH.NET with a session-scoped sequential coordinator, WPF-owned trust/authentication, committed-output barrier, root/overlay resize fanout, explicit disconnect and deterministic return to the originating local shell. See the [accepted record](validation/2026-09-21-typed-ssh-overlay.md). |
| Typed SSH overlay rejected package 0.1 | `VT7-SSHNET-Overlay-0.1-x64.zip`, SHA256 `F53326B898B6544798E10D30E895D1D389BECC1C590C3D1B9961508E51262A5E`, 15,230,388 bytes, 91 verified files. Its Windows 7 automation passed, and each typed attempt proved authenticated H01 entry, committed barrier, status 255 and return to the original prompt. Every real connection failed before network startup because the broker worker directly read dispatcher-owned document/viewport geometry; direct **Start SSH...** remained successful. Evidence: `artifacts/vt7/evidence/sshnet-overlay-win7-0.1-rejected`. |
| Typed SSH overlay rejected package 0.2 | `VT7-SSHNET-Overlay-0.2-x64.zip`, version 0.9.1, SHA256 `65FF2E09F83758D8E86A78CC08B3409D2D18BE04B85BA901799A318DBE34AD7C`, 15,194,306 bytes, 91 verified files. Its automated Windows 7 corpus passes and a typed SSH.NET overlay connects successfully, accepting the package 0.1 dispatcher correction. The shim then times out reading completion after five seconds, returns the local prompt while the overlay remains active and leaves root input closed after remote exit because completion delivery fails before the resume callback. Evidence: `artifacts/vt7/evidence/sshnet-overlay-win7-0.2-rejected`. |
| Typed SSH overlay accepted package 0.3 | `VT7-SSHNET-Overlay-0.3-x64.zip`, version 0.9.2, SHA256 `CAF09834CA1F7F025D96CC07D5F60AF8663C2F2167AA964EAB98D3AF3865B0DB`, 15,196,580 bytes, 91 verified files. The shim retains bounded handshake I/O but waits for accepted embedded completion for the remote-session lifetime; a closed host pipe still wakes it. The broker resumes root input in a `finally` path even if completion delivery loses the shim. H01 holds a real accepted shim for six seconds to exercise the former failure. Debug/Release, combined staged batch launch and independent ZIP verification pass locally. The complete controlled Windows 7 matrix passes without a reported defect: delayed connection, exit/root recovery, sequential handoff, explicit disconnect/status 255, three shells and external fallback. Review copy: `artifacts/VT7-SSHNET-Overlay-0.3-x64.zip`. |
| Known-host management specification | Complete on 2026-09-21. The design shares the default OpenSSH user/system files, pins Win32-OpenSSH 10.0p2 as the behavior oracle, compares exact key blobs, handles hashes/markers/certificates, aborts unknown discovery before authentication, retries through a fresh connection, preserves the fingerprint fallback and defines byte-preserving Windows mutation/recovery. KH01.1 through KH01.3 are target accepted; KH01.4 is next. |
| KH01.1 local implementation | `OpenSshKnownHosts` implements bounded byte-preserving parsing, host tokens, literal/pattern/negated/hashed matching, exact RFC 4253 blob identity and raw-key trust precedence. `KnownHostsFoundationChecks` covers all six trust results, deterministic hash properties, 1,024 arbitrary-byte inputs and disposable `ssh-keygen -F/-H/-R` comparisons. Certificates are policy-rejected until KH01.4. No production callback changed. |
| KH01.1 candidate package | `VT7-KnownHosts-KH01-0.1-x64.zip`, SHA256 `D367B5F7C81304F6FBC9056FD10E501B95EF93FFB5A662E370FCC4ECE16C76A7`, 14,483,182 bytes, 81 verified files. Debug/Release, local `ssh-keygen.exe` 9.5.5.2 differential checks, path-with-spaces batch launch, binary/dependency inspection, exact ZIP hashing and an independent extracted-package rerun pass. Review copy: `artifacts/VT7-KnownHosts-KH01-0.1-x64.zip`. |
| KH01.1 target result | Accepted on 2026-09-22. The owner reports all tests passed on Windows 7. The launcher could reach the test only after requiring the installed `ssh-keygen.exe` file version 10.0.0.0, the 10.0p2 oracle boundary. No target Logs directory is archived because the procedure requested it only on failure. |
| KH01.2 implementation | Version 0.10.0 loads immutable snapshots of the four default OpenSSH sources before connection and evaluates exact key blobs synchronously in `HostKeyReceived`. Stored matches need no fingerprint; unknown hosts retain the exact one-attempt pin. A supplied wrong pin and changed, revoked, unreadable or policy-rejected trust fail closed. Direct and typed paths share this transport boundary. Writes remain disabled. Version 0.10.1 changes the SSH.NET dependency only to carry the Windows 7 MAC correction. |
| KH01.2 rejected package 0.2 | `VT7-KnownHosts-KH01-0.2-x64.zip`, SHA256 `D55AEA3B7572D8177524D62FC113A385AF8DB7DB6B5083FAA0E132C8D1E562A6`, 15,258,892 bytes, 94 verified files. Debug/Release and packaging checks pass, and the primary Windows 7 machine passes both live SSH paths. Both paths fail during connection on NESSY because its SSH.NET 2026.0.0 dependency hits upstream issue 1829. Preserve this archive as rejected runtime evidence. |
| KH01.2 two-machine runtime finding | The primary Windows 7 machine uses .NET Framework `mscorlib.dll` `4.8.4795.0`. NESSY is a genuine non-ESU VM with `4.8.4110.0`; its complete offline VT7 corpus passes and Win32-OpenSSH reaches the same server. SSH.NET issue 1829 explains the 2026.0.0 failure. Upstream commit `f099365` resets the receive MAC on .NET Framework and maps to package `2026.0.1-prerelease.6`; `.5` predates that commit. |
| KH01.2 accepted package | `VT7-KnownHosts-KH01-0.3-x64.zip`, version 0.10.1, SHA256 `B046A3CA97D7EE138D59AB1742C964ACC791B501C10AA32DFD045A37429200A4`, 15,235,578 bytes, 94 verified files. It pins the publisher-built SSH.NET `2026.0.1-prerelease.6` nupkg, SHA256 `3981BA4F5A36DADFFDAC19BA8B8F207F594F57B3BA043A794277678669FBC35C`, whose nuspec and assembly both identify `f099365`. Debug/Release, overlay, packaged path-with-spaces and independent extracted checks pass. NESSY and TURTLE both pass the automated launcher and owner-confirmed typed/direct stored-key connections. Review copy: `artifacts/VT7-KnownHosts-KH01-0.3-x64.zip`. |
| KH01.2 accepted evidence | Four returned files plus `ARCHIVE-VERIFICATION.json` are preserved under `artifacts/vt7/evidence/known-hosts-kh01-2-win7-0.3`. Both machines use the same host/native and OpenSSH 10.0p2 hashes. NESSY reports .NET Framework `4.8.4110.0`; TURTLE reports `4.8.4795.0`. Both automated reports pass, and the owner confirms both stored-key live paths pass on each machine. No credentials are retained. |
| KH01.3 implementation | Version 0.11.0 aborts unknown discovery before authentication, presents generation-scoped **Cancel**, **Connect once** and **Trust and connect** actions, and retries through a fresh `SshClient`. Connect once binds exact host/key/store identities. Durable trust serializes writers, excludes new competing writers, preserves existing bytes and ACLs, creates missing paths owner-only, flushes and verifies the exact read-back. Changed/revoked/unreadable/mismatch/certificate states remain blocked. Local Debug foundation and UI checks pass. See the [KH01.3 record](validation/2026-09-24-known-hosts-kh01-3.md). |
| KH01.3 accepted package | `VT7-KnownHosts-KH01-0.4-x64.zip`, version 0.11.0, SHA256 `531B4A1D43894408F7AA38AC6E0BC22C6EBA1394519C3A70C1C9A83AA64B2C83`, 15,262,430 bytes, 94 verified files. Manifest source is clean commit `750bbca99`. Debug/Release, overlay, durable-writer, path-with-spaces and independent extracted checks pass. NESSY and TURTLE pass the exact automated launcher and owner-confirmed controlled live matrix. Review copy: `artifacts/VT7-KnownHosts-KH01-0.4-x64.zip`. |
| KH01.3 accepted evidence | Four returned files plus `ARCHIVE-VERIFICATION.json` are preserved under `artifacts/vt7/evidence/known-hosts-kh01-3-win7-0.4`. Both machines use the same host/native and OpenSSH 10.0p2 hashes. NESSY reports .NET Framework `4.8.4110.0`; TURTLE reports `4.8.4795.0`. Both automated reports pass, and the owner confirms the complete first-contact, persistence, reconnect and interaction matrix passes on each machine. No credentials are retained. |
| Next bounded task | Implement KH01.4 deliberate user-record removal/replacement with `.old` recovery and concurrency protection, then complete the declared certificate/marker policy before KH01.5 final acceptance. |
| Milestone 2 | Open. Theme/high-contrast, broader device/environment and milestone-level ESU coverage also remain. |
| Development sequence | Continue Milestone 5 through KH01.4-KH01.5 and later lifecycle/TUI hardening. Remaining C3/Milestone 2 qualification stays recorded without a blanket serial dependency. |

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
   The 0.3.7 source has a focused issued target candidate, not a complete application package. A later full candidate
   needs a new artifact identity and paths that preserve old evidence.

## What 0.5.0 changed

- `WinPtyTransport` implements the real local root behind `ITerminalTransport`
  and owns WinPTY, its pipes, child handle, output loop and cancellation.
- One explicit Command Prompt profile pins `%SystemRoot%\System32\cmd.exe`,
  `/d /q /k`, an absolute working directory and a Unicode environment block.
- The visible host now opens that real session. Hidden smoke and lifecycle tests
  retain deterministic fake transports.
- Natural EOF drains through TerminalCore before preserving the child exit code.
  Owner cancellation closes input, joins the reader and shuts down the agent.
- `TaskCompletionSource` continuations in the outbound queue run asynchronously,
  preventing natural child exit from synchronously joining its own worker.
- Debug and Release pass the real transport check and 3A regressions. The full
  Release renderer/host suite and a visible one-agent launch/close check pass.
- The exact Windows 7 package also passes all three runners. Manual Croatian
  text, child Notepad launch and Unicode filename creation pass. Ctrl+C aborts
  a running command; prompt-line cancellation remains an explicit 3C fidelity
  item because WinPTY 0.4.3 cannot provide it.
- Version 0.5.1 adds native child-HWND mouse-wheel handling. It honors the
  Windows row/page setting and high-resolution deltas, uses TerminalCore's
  user-scroll state and retains history position during new output. Windows 7
  confirms those behaviors but finds printable characters do not snap to live.
- Version 0.5.2 adds VT7-scoped snap-on-input to TerminalCore's committed-
  character boundary. This preserves `WM_CHAR` ownership of Croatian, dead-key
  and AltGr text. ABI 11 is unchanged; local and supplied target checks pass.
- Exact identities, evidence and limits are in the
  [3B.1 validation record](validation/2026-09-17-winpty-root-3b.md).

## What 0.4.0 changed

- ABI 11 splits `TerminalDocument` from `TerminalView`/HWND identity. Documents
  validate attachment and producer generations, reject attached destruction,
  retain core/decoder state headlessly, and queue bounded originating-transport
  replies outside the TerminalCore callback lock.
- `TerminalSurface` is now a WPF attachment facade over a separately owned
  managed `TerminalDocument`. `SessionOutputPump` targets the document dispatcher,
  so destroying an `HwndHost` cannot terminate or redirect its byte stream.
- `TerminalSession` and `ITerminalTransport` define explicit root/overlay states,
  transport completion results, close reasons and generation-checked input/output.
  `MainWindow` owns this session rather than a backend queue and HWND directly.
- The focused test destroys the first HWND after a stream prefix, drains the
  remaining deterministic bytes while detached, reattaches generation 2 and
  matches the always-attached raster. Fake root/overlay/root generations 1/2/3
  share one stream and return a TerminalCore device reply to its origin.
- Debug and Release builds, session stream/outbound suites, all six renderer
  smoke modes and the injected blank-frame negative pass locally. The exact
  0.4.0 package also passes its focused Windows 7 outbound and ownership runs
  with package-matching binaries; see the
  [3A validation record](validation/2026-09-17-session-ownership-3a.md).

## What 0.3.7 changed

- ABI 10 adds key, committed-character and focus encoding calls against the same
  TerminalInput state updated by output parsing. Non-text key metadata uses a
  no-layout entry point and cannot mutate Windows 7 dead-key state.
- `SessionOutboundQueue` admits at most 256 pending operations, assigns one
  generation and monotonic sequence, rejects stale/closed/full admission,
  drains accepted work on completion and coalesces only consecutive resizes.
- `NativeHwndInputAdapter` owns terminal input only at the child HWND. It emits
  OS-committed UTF-16 once, keeps Interrupt and Break distinct, suppresses paired
  ETX/Enter/Tab/Backspace characters, and reconciles tracked modifiers on focus
  loss.
- Native resize publishes the exact post-`UserResize` grid; the host coalesces
  it once. WPF dimension events never become PTY resize operations.
- `Test-VT7SessionOutbound.ps1` passes locally in Debug and Release, as do the
  existing session-stream regressions and static PE/import checks. The exact
  target package passes its hash-verifying `cmd.exe`/Windows PowerShell 5.1
  launcher from a path with spaces. Its returned Windows 7 SP1 x64 run also
  passes the bounded queue, native input/resize, TerminalCore, stream and font
  checks with exact package host/native hashes.

See the [session outbound foundation](architecture/2026-09-14-session-outbound-foundation.md).
At the 0.3.7 checkpoint the backend remained an audit sink, TerminalCore/session
identity was not yet separate from the HWND-backed surface, and no shell or SSH
transport was wired. Versions 0.4.0 and 0.5.0 supersede those limitations.

## What 0.3.6 changed

- ABI 9 adds begin/write/end/status calls for a per-surface UTF-8 byte stream.
  The native decoder uses inherited `til::u8u16` state and feeds the existing
  TerminalCore parser without joining or rewriting transport chunks.
- `SessionOutputPump` copies ordered chunks from any producer thread into a
  16-slot queue with a 64 KiB chunk limit, giving 1 MiB maximum queued output
  at full chunk size. Native HWND calls remain on the surface dispatcher.
- Completion stops admission, drains accepted output and then delivers EOF.
  Incomplete UTF-8 at EOF returns `ERROR_NO_UNICODE_TRANSLATION`; writes after
  EOF fail; a new generation clears decoder/terminal state and recovers.
- Normal startup now shows a streamed Croatian HR Latin and VT fixture. Existing
  renderer regressions still use the deterministic static demo through reset.
- `Test-VT7SessionStream.ps1` compares the exact rendered raster for one chunk,
  388 one-byte writes and irregular chunks, then verifies incomplete EOF,
  recovery and HWND destruction. Debug and Release pass locally. Release static
  verification and the established Debug six-renderer viewport matrix pass.

The detailed contract, evidence and remaining limits are in the
[session stream foundation](architecture/2026-09-14-session-stream-foundation.md).
At the 0.3.6 checkpoint the application did not instantiate WinPTY, implement
OpenSSH or return terminal replies. The later 0.3.7 queue, 0.4.0 document/session
owner and 0.5.0 Command Prompt transport supersede those local-session limits.

## P01 WinPTY diagnostic

P01 pins the official WinPTY 0.4.3 MSVC 2015 bundle, source tag commit
`3e1ab962d5262dd76159870c6dc0724927ca6a9d`. The archive SHA256 is
`35A48ECE2FF4ACDCBC8299D4920DE53EB86B1FB41E64D2FE5AE7898931BCEE89`.
The exact x64 DLL and agent hashes, license, architecture/import audit and test
design are in the [P01 validation record](validation/2026-09-14-winpty-p01.md).

`VT7.WinPtyFixture.exe` writes through WriteConsoleW, WriteConsoleOutputW,
WriteConsoleA, WriteFile, raw VT, rapid rewrites, alternate buffers, resize and
an exit-drain workload. It records actual console cells through a side file.
`VT7.WinPtyProbe.exe` retains WinPTY bytes and feeds each read through the ABI 9
decoder class into TerminalCore. `Test-VT7WinPty.ps1` normalizes console
lead/trail duplication for semantic comparison while preserving exact cells.

Debug and Release pass locally. All reconstructed streams are valid UTF-8 and
fully drained; dimensions and legacy attributes match in every case. The local
Windows 10 baseline records two narrow fidelity limits: unprocessed ESC cells
reconstruct as literal question marks, and a supplementary console glyph becomes
U+FFFD with a cursor-width difference. Only one of 200 fast rewrite states is
observed, but the final state matches. Both alternate/primary markers, the 100 by
30 resize and all 500 exit-drain lines survive.

The first Windows 7 attempt used package 0.1 and failed in its batch launcher
before creating `Logs`: quoted `%~dp0` ended in a backslash, causing Windows
PowerShell 5.1 to receive an illegal trailing quote in `BinaryDirectory`.
Package 0.2 changed only the launcher path form to `%~dp0.` and added a test-only
no-pause environment switch. Its Windows 7 run passed five cases, then
`SetConsoleOutputCP(932)` returned `ERROR_INVALID_PARAMETER` (87). The harness
incorrectly treated that target capability result as a fixture failure and
stopped. The 33 returned files are verified under
`artifacts/vt7/evidence/winpty-p01-win7-0.2/`.

Package 0.3 records requested/actual output code pages, `IsValidCodePage`, the
set result and exact error. An unavailable page sends no incorrectly mapped
bytes and the matrix continues. Both Debug and Release pass locally, as does an
invalid-code-page negative control. The exact shipped ZIP passes all eighteen
cases and the negative control from a path with spaces through `cmd.exe` plus
Windows PowerShell 5.1.

The complete target run is
`artifacts/vt7/evidence/winpty-p01-win7-0.3/winpty-p01-20260914-060948-29e797c8/`:
109 files and 1,062,782 bytes on Windows 7 SP1 x64 with `hr-HR` culture. All
children exit zero, all agents signal, all streams drain with valid UTF-8, and
all dimensions and legacy attributes match. Sixteen cases have ordinally equal
text. Both raw-VT cases differ because the legacy console stores ESC as NUL and
Windows 7 rejects `ENABLE_VIRTUAL_TERMINAL_PROCESSING` with error 87. CP932 is
valid but the console rejects `SetConsoleOutputCP(932)` with error 87. Five
cases have bounded cursor differences; resize, alternate-buffer and 500-line
exit-drain behavior pass.

The package's PowerShell `-cne` comparison ignored embedded NUL, so its two raw
`textEqual` fields are overly optimistic. `INDEPENDENT-ANALYSIS.json`, SHA256
`3E71AD551C519D93B461EEE4D21DEFC4768CE59021F04069391FF055F2D7156E`,
recomputes ordinal equality. Source now uses `StringComparison.Ordinal`; the
retained strings make another target run unnecessary.

P01 selects WinPTY 0.4.3 for Windows 7 local legacy-console applications behind
the replaceable session boundary. Do not describe it as lossless raw-VT
transport. Direct SSH remains a separate byte path.

## I01 input diagnostic

I01 package 0.2 combines an automatic native layout/encoder probe with a guided
.NET Framework 4.8 WPF and child-HWND focus recorder. The native side compares
Croatian HR Latin `ToUnicodeEx` flags 1 and 5 on separate threads, then exercises
the inherited `TerminalInput` encoder. The interactive side records controlled
Croatian, AltGr, dead-key, repeat, Ctrl+C, Ctrl+Break, focus and resize events
at both WPF and native boundaries. It does not launch a process backend or send
input outside its own window.

Debug and Release smoke runs pass locally. Release records 158 mappings, 30
AltGr mappings, a layout dead key and 25 encoder cases. The exact package ZIP
passes its batch entry point after extraction beneath a path with spaces under
Windows PowerShell 5.1. Package 0.1 exposed a result-hashing command-discovery
failure in that exact launcher test and is rejected; 0.2 uses an in-process
SHA-256 implementation.

The Windows 7 interactive run completes with zero validator issues, 772 event
records, 158 Croatian mappings and 30 AltGr mappings. Both controls contain the
required Croatian and AltGr text. `ToUnicodeEx` flags 1 and 5 both leave the dead
key active, so the documented Windows 10 bit-2 behavior is unavailable. Ctrl+C
and Ctrl+Break each arrive as a distinct native keydown followed by U+0003;
there are 32 focus events and three native sizes. No native printable-A repeat
was recorded, so that ordinary behavior remains in 3C rather than forcing an
unchanged compatibility rerun.

The native child HWND now owns terminal focus input. Its OS-generated committed
text path supplies printable/composed UTF-16 once; native key metadata supplies
non-text and control distinctions. The adapter correlates handled control keys
with their following character, reconciles modifiers on focus loss and sends
one coalesced native-grid resize. The exact identity, evidence and decision are in the
[I01 validation record](validation/2026-09-14-input-i01.md).

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
12. The [Windows 7 WPF reactivation result](diagnostics/2026-09-14-resource-reactivation.md#supplied-windows-7-result)
    completes both rounds with three immediate failures preserved. Its +180s
    handle/thread/GDI/USER counts match exactly, with +220 KiB private bytes.
    Nine of the 13 late thread identities are common and four differ. None of
    the 40/42 queue-positive `ntdll.dll+F8DE0` identities at the ends of the two
    batches appears at its corresponding +180s sample. Missing identities are
    not exit events; equal handle totals do not prove the same handles remain.

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

The owner has decided to continue development and return to the WARP concern
only when evidence or release review requires it. Follow the
[September 14 decision](architecture/2026-09-14-warp-development-deferral.md)
and [REL01](../../ROADMAP.md#deferred-reliability-review). Do not resume the
dedicated tracing campaign or request another diagnostic/soak as a prerequisite.

The technical design for recoverable trust is frozen in the
[OpenSSH-compatible known-host management specification](architecture/2026-09-21-openssh-known-hosts-management-spec.md).
KH01.1's disconnected parser, matcher, raw-key identity and trust precedence are
accepted on Windows 7. KH01.2 now connects that policy to both production
SSH.NET entry paths through immutable snapshots of the four default OpenSSH
sources. Package 0.2 passes the complete local gates and the primary live run,
but both SSH.NET paths fail on NESSY at the upstream 2026.0.0 receive-MAC defect.
Version 0.10.1/package 0.3 pins the publisher-built
2026.0.1-prerelease.6/f099365 correction. Its automated launcher and stored-key
typed `ssh` and **Start SSH...** paths pass on NESSY and TURTLE. The
[KH01.2 validation record](validation/2026-09-22-known-hosts-kh01-2.md) contains
the accepted evidence and boundary. KH01.3 now implements generation-safe
first-contact decisions, fresh-connection retry and byte-preserving persistence
in 0.11.0. Package 0.4 passes the exact automated and controlled live matrix on
NESSY and TURTLE, so KH01.3 is accepted. Proceed to KH01.4 deliberate
removal/replacement, recovery and certificate/marker policy.

The exact 0.3.7 Windows 7 run is accepted and archived. The
[S00 evaluation](validation/2026-09-14-openssh-s00.md) is complete on Windows 7
in two complete, repeatable runs. It freezes the exact official Microsoft
10.0p2 x64 client and shows that redirected input produces a PTY-allocation
diagnostic on stderr. No unchanged preflight rerun is requested. The
controlled-server package 0.1 completes on the owner's Debian 12 server and
dedicated `sshtest` account. Strict trust, key-only authentication, exact
non-PTY bytes, negotiation, final drain and active cancellation pass. Forced PTY
allocation reports 0 columns by 0 rows. Exact 10.0p2 source shows that its
Windows size query reads the stdout console buffer and its resize notification
comes from console input events. VT7's redirected pipes provide neither path,
so another resize run would not add evidence. S00 rejects this interactive
architecture while retaining the client as a command-only option.

SSH.NET 2026.0.0 is the accepted S01 transport candidate because it exposes
explicit PTY resize and structured trust/authentication. The owner accepted its audited
permissive Apache-2.0, ISC-style and supplier terms as a standing project-wide
policy. Corrected package 0.6 passes public-key-only and optional-password runs
on Windows 7 against controlled Debian, so S01 accepts SSH.NET as the embedded
interactive candidate. Version 0.8.0 now carries the exact locked closure and
stream-first shutdown rule into the production transport boundary. Package 0.1
is rejected only for its pre-launch batch quoting defect. Corrected package 0.2
passes the full Windows 7 direct-profile matrix and separate `htop` and `nano`
runs. Version 0.8.1/package 0.3 corrects the form labels but its target visual
check exposes the generated selected Authentication text as still light.
Version 0.8.2/package 0.4 corrects and checks that selector; its focused Windows
7 visual confirmation passes. Continue to
apply the ownership and security contracts in the
[session ownership and external source review](architecture/2026-09-14-session-ownership-and-source-review.md)
and the implementation-ready
[terminal document/transport/handoff specification](architecture/2026-09-14-terminal-document-and-ssh-handoff-spec.md).
Version 0.4.0 realizes the 3A document/view and managed fake-transport boundary.
Version 0.5.0 implements `WinPtyTransport` behind that interface for one
explicit Command Prompt root, without moving backend handles into `MainWindow`
or the view. It reuses P01's accepted WinPTY artifacts and preserves its
final-drain, child-process, grid and reconstruction limits. Versions 0.5.1 and
0.5.2 add and target-qualify wheel scrollback, retained history and printable-
character snap-to-live. Version 0.6.4 adds typed PowerShell profiles, visible root
replacement and an editor-aware 5.1/7.2.24 contract after 0.6.3 identified the
target's legacy Windows PowerShell editor; its Windows 7 profile/transport corpus
is accepted. Version 0.6.5 preserves the contract but fails its manual
navigation-key correction. Version 0.6.6 adds the WPF keyboard-sink path and
passes the complete target retest.
Version 0.7.0 adds the H01 native shim and authenticated managed broker without
enabling embedded SSH. Packages 0.1 through 0.3 pass the three embedded shell
paths and identify the successive Windows 7 console-handle restrictions. Version
0.7.3 uses Windows 7's native standard-handle inheritance and preserves the
explicit handle list on Windows 8 or later; package 0.4 passes the strict Windows
7 three-shell run and H01 is accepted.
Version 0.8.0 adds the direct SSH.NET root, ephemeral connection dialog, pinned
host-key trust, remote PTY geometry and live resize. Corrected package 0.2 passes
the complete controlled-server Windows 7 matrix plus `htop` and `nano`. Version
0.8.1/package 0.3 fixes the form labels but fails its focused selector check.
Version 0.8.2/package 0.4 corrects and verifies the rendered Authentication item,
and its focused Windows 7 visual confirmation passes. Version 0.9.2/package 0.3
then target-accepts overlay coordination and typed handoff. Recoverable trust
storage, broader remote lifecycle/TUI hardening and the daily-driver UI follow.

The two S00 preflight runs are preserved byte-identically under
`artifacts/vt7/evidence/openssh-s00-win7-preflight-0.2/`. They contain 44 raw
files and 35,558 bytes. The archive verification and independent analysis record
the per-file comparisons, exact package identity, official archive-entry match,
algorithm/default distinction, raw channel behavior and 807/808 ms cancellation.

The controlled-server run is archived under
`artifacts/vt7/evidence/openssh-s00-network-win7-0.1/`. Its private raw copy is
byte-identical but contains a public host fingerprint and temporary Windows
profile path, so it is not publication-safe. The sanitized copy and independent
analysis retain every behavioral result without those identifiers. Package 0.1
has SHA256 `8029CC9CF48F9BAEA839F16F3E104A552F848AB17A4A12636C966145B421B7FA`;
the original manifest has SHA256
`A3F4EE75A4379ACEA05498D41F1CB743B2F4EE99069A33CA78629C0CFA17C1DE`.

The [completed Windows 7 reactivation run](diagnostics/2026-09-14-resource-reactivation.md#supplied-windows-7-result)
has 16 valid samples, 200 measured lifecycles, 2,000 resizes and 1,000 tab trips
in 655.156 seconds. Worst close is 8 ms; all 202 companion WPF reports pass.
Both +180s states have 1,314 handles, 13 threads, GDI 18 and USER 10. Private
bytes differ by 220 KiB. Three original immediate checks still fail. Nine late
thread identities are common and four differ; handle identities are unproven.

All 207 files (883,594 bytes) are verified and archived under
`artifacts/vt7/evidence/resource-reactivation-win7-0.1/resource-reactivation-20260914-032308-629f4198/`.
The report SHA256 is
`168C44C2C17BFAA9B1360669D76136BD742DF8926F3ED7247E3D3507BB923C35`.
The diagnostic record links inventory/supplement, validator, independent analysis
and package provenance. The separate Windows 10 result retains eight immediate
failures and late deltas of +2 handles, +1 thread, +1 USER and +3,846,144 bytes.

Keep the original budgets, warm-up, baseline, reports and failed exits. This is
development-risk acceptance, not a declaration of a fix or C3/Milestone 2
completion. REL01 uses ordinary product qualification at release review and
reopens earlier for continuing accumulation, exhaustion, crashes/hangs, shutdown
failure or a concrete relevant lifetime defect. Another trace is conditional,
not inevitable; identifying every internal Windows handle is not a prerequisite
to acceptance. No new application code or diagnostic is issued by this decision.

## Retained diagnostic context

The following history and dated next-step reasoning preserve how the evidence
was obtained. The approved REL01 decision above supersedes any instruction here
to continue tracing or complete attribution before developing sessions.

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
the Windows 7 target. The strict 0.6.4 run qualifies that exact environment;
0.6.5 failed its focused navigation-key correction and 0.6.6 passes the same
bounded confirmation across every local profile. Corrected H01 0.7.3 passes its
focused run in that environment; it did not use the Debian server, OpenSSH
installation, keys or passwords.
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
| Integrated reactivation diagnostic | [Protocol and qualification](diagnostics/2026-09-14-resource-reactivation.md), [two-round controller](../../src/vt7/VT7.ResourceReactivation/ReactivationChecks.cs), [thread identities](../../src/vt7/VT7.ResourceReactivation/ReactivationThreads.cs), [validator](../../src/vt7/VT7.ResourceReactivation/Validate-ResourceReactivation.ps1), [launcher](../../src/vt7/VT7.ResourceReactivation/Run-ResourceReactivation.ps1). Separate managed project, shared actual host workload, unchanged native payload. |
| Process/thread samples | [ResourceDiagnostics.cs](../../src/vt7/VT7.Host/ResourceDiagnostics.cs). |
| Native document/view lifetime | [TerminalDocument.cs](../../src/vt7/VT7.Host/TerminalDocument.cs), [TerminalSurface.cs](../../src/vt7/VT7.Host/TerminalSurface.cs), [ABI declarations](../../src/vt7/VT7.Native/include/vt7_native.h), [surface.cpp](../../src/vt7/VT7.Native/surface.cpp). |
| C ABI agreement | [vt7_native.h](../../src/vt7/VT7.Native/include/vt7_native.h), [exports.def](../../src/vt7/VT7.Native/exports.def), [NativeMethods.cs](../../src/vt7/VT7.Host/NativeMethods.cs). |
| Session byte/transport path | [native decoder](../../src/vt7/VT7.Native/utf8_terminal_stream.hpp), [bounded managed pump](../../src/vt7/VT7.Host/SessionOutputPump.cs), [session/transport contract](../../src/vt7/VT7.Host/TerminalSession.cs), [visible fixture](../../src/vt7/VT7.Host/SessionStreamFixture.cs), [focused integration check](../../src/vt7/VT7.Host/SessionStreamWindowChecks.cs), [runner](../../tools/Test-VT7SessionStream.ps1). |
| Local profile model and UI | [TerminalProfile.cs](../../src/vt7/VT7.Host/TerminalProfile.cs), [MainWindow.xaml](../../src/vt7/VT7.Host/MainWindow.xaml), [MainWindow.xaml.cs](../../src/vt7/VT7.Host/MainWindow.xaml.cs). Explicit discovery, ordinary/clean policy, selection and root replacement. |
| PowerShell 3B.2 checks | [PowerShellProfileChecks.cs](../../src/vt7/VT7.Host/PowerShellProfileChecks.cs), [runner](../../tools/Test-VT7PowerShellProfiles.ps1), [package helper](../../tools/Package-VT7PowerShellProfiles.ps1), [validation record](validation/2026-09-17-powershell-profiles-3b2.md). |
| H01 shim and broker | [native shim](../../src/vt7/VT7.SshShim/main.cpp), [protocol](../../src/vt7/VT7.Host/SshShimProtocol.cs), [broker](../../src/vt7/VT7.Host/SshShimBroker.cs), [checks](../../src/vt7/VT7.Host/H01Checks.cs), [runner](../../tools/Test-VT7H01.ps1), [package helper](../../tools/Package-VT7H01.ps1), [validation record](validation/2026-09-19-typed-ssh-h01.md). |
| Direct SSH.NET root | [transport](../../src/vt7/VT7.Host/SshNetTransport.cs), [ephemeral options](../../src/vt7/VT7.Host/SshConnectionOptions.cs), [connection dialog](../../src/vt7/VT7.Host/SshConnectionDialog.cs), [offline checks](../../src/vt7/VT7.Host/SshNetFoundationChecks.cs), [runner](../../tools/Test-VT7SshNetFoundation.ps1), [package helper](../../tools/Package-VT7SshNetDirect.ps1), [validation record](validation/2026-09-19-sshnet-direct-profile.md). |
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
- Supplied I01 Windows 7 evidence:
  `artifacts/vt7/evidence/input-i01-win7-0.2/input-i01-20260914-052832-f87c2fc7/`.
  The four original files total 354,713 bytes and are copied unchanged.
  `ARCHIVE-VERIFICATION.json` records every source size/hash and
  `INDEPENDENT-ANALYSIS.json` records the accepted input/resize decision.
- Supplied session-outbound 0.3.7 Windows 7 evidence:
  `artifacts/vt7/evidence/session-outbound-win7-0.3.7/session-outbound-20260914-063714-74969eea/`.
  The two original files total 2,807 bytes and are copied unchanged.
  `ARCHIVE-VERIFICATION.json` records both source size/hash pairs and
  `INDEPENDENT-ANALYSIS.json` records the exact package identity and accepted
  queue/input/resize decision.
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
