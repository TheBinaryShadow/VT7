# Milestone 3B.2 local PowerShell profiles

Date: 2026-09-19

Status: PowerShell profile, transport, Unicode, resize, lifecycle and WPF/native
keyboard-sink contracts accepted on Windows 7 in VT7 0.6.6/native ABI 11. The
underlying shell corpus first passed in 0.6.4. Both ordinary shells passed the
applicable manual checks, including multiline Croatian text, resizing,
scrollback and clean profile replacement. That run exposed a separate WPF/native
focus handoff and selector-contrast defect. Version 0.6.5 passes every automated
contract and starts, replaces and shuts down profiles cleanly on Windows 7, but
its direct `SetFocus` correction does not stop WPF from consuming Tab, Down and
End. Home returns from Diagnostics to the viewport tab after End moves focus out.
Version 0.6.6 implements and tests the missing `HwndHost` keyboard sink. All four
automated stages and the manual key check across every local profile pass on the
supplied Windows 7 target. The 0.6.6 correction is accepted.

## Scope

3B.2 adds typed local profiles for Command Prompt, Windows PowerShell 5.1 and
PowerShell 7. The visible host discovers installed profiles, shows them in the
Terminal viewport selector and replaces the active root session when the user
clicks `Start profile`. Replacement detaches input, closes and joins the old
`TerminalSession`, disposes its WinPTY transport, then starts a new session on
the existing `TerminalDocument`. This preserves the accepted 3A ownership split;
shell handles do not move into WPF or the native viewport.

Each profile owns an absolute executable path, explicit arguments, a validated
working directory and a sorted Unicode environment block. Windows PowerShell is
resolved beneath `%SystemRoot%\System32\WindowsPowerShell\v1.0`. PowerShell 7 is
resolved beneath 64-bit Program Files, preferring `PowerShell\7` and then
`PowerShell\7-preview`. The product version is read from the selected image and
shown in the UI. Only exact 7.2.24 satisfies the Windows 7 qualification gate;
another 7.x can be launched but is labeled unqualified on Windows 7.

Ordinary launches use only `-NoLogo`, so VT7 preserves user profile scripts,
execution policy, loaded modules and PSReadLine configuration. The controlled
diagnostic alone adds `-NoProfile`. Neither path changes machine or user policy,
the global console code page or PowerShell settings.

## Automated contract

`PowerShellProfileChecks` starts each clean profile through the production
`WinPtyTransport` and `TerminalSession` boundary. It submits one ordinary prompt
line terminated by the carriage return emitted by the production Enter-key
path. The line checks the runtime from inside the session, `ConsoleHost`,
Croatian environment text, the active Windows PowerShell editor, `TabExpansion2`,
a nested native `cmd.exe`, and required PowerShell 7 PSReadLine prediction
capability. Windows PowerShell returns 50 when it uses the legacy editor and 51
when PSReadLine is loaded. PowerShell 7 must return 72; failed assertions use
codes 81 through 89. The harness also proves generation-1 input, an authoritative 108 by
32 resize, output after input, exact input accounting, final UTF-8 drain,
preserved child exit and document closure. Visible multiline editing remains in
the manual ordinary-profile workflow.

The strict target path requires both runtime 5.1 and exact 7.2.24. The separate
`--allow-missing-powershell-7` switch exists only for development machines that
lack the target runtime. It accepts an explicit skip and cannot turn another 7.x
into 7.2.24 evidence. A local negative control confirmed that the strict path
rejects installed PowerShell 7.6.0-preview.5 with exit 1 and the expected reason.

## Rejected 0.6.0 through 0.6.3 target results

The 0.6.0 automated package ran on the Windows 7 SP1 x64 target with .NET
4.8.4795.0, `hr-HR` culture, Windows PowerShell 5.1.14409.1005 and PowerShell
7.2.24. The session outbound, session stream and WinPTY root stages all passed.
The first 3B.2 clean Windows PowerShell 5.1 case then failed with
`Timed out waiting for Windows PowerShell 5.1 natural exit.` PowerShell 7 was
therefore not run and the ordinary-profile checks were intentionally paused.

The runtime inventory and package hashes were correct. The 0.6.0 harness sent
the complete multiline block in one WinPTY input operation and then waited for
process exit. Version 0.6.1 split it into four observed writes, but retained the
same carriage-return-plus-line-feed terminator. Two independent 0.6.1 target
runs passed the first three stages and then produced the identical 5.1 natural-
exit timeout. This rules out the original one-write explanation.

VT7's production Enter-key encoder emits carriage return only. Version 0.6.2
removed the extra line feed and added counters. Its target result records all
four admitted writes, 575 input bytes and output after every line, including the
final exit expression: five output blocks and 747 bytes in total. The process
still remained alive. This proves the input and Enter paths and localizes the
failure to depending on the older console editor's continuation construct.

Version 0.6.3 removes that construct from the automated gate. This correction
does not change ordinary profile arguments, discovery or session ownership.
Its target process exits normally with code 84. That maps to `Get-Module
PSReadLine` returning no loaded module. The runtime, terminal input, direct exit
and process lifecycle therefore pass; the remaining failure is an invalid
assumption that clean Windows PowerShell 5.1 must auto-load an optional editor.

Rejected candidate identities:

| Archive | SHA256 | Size | Target disposition |
| --- | --- | ---: | --- |
| `VT7-PowerShell-Profiles-0.6.0-x64.zip` | `20EE217D36A9F7808DF0A289FD4DF5C0EFA8DEE2C717FCF079692939D770E596` | 11,185,489 bytes | Rejected after its one-write 5.1 multiline submission timed out |
| `VT7-PowerShell-Profiles-0.6.1-x64.zip` | `8D3B880E91A999A6A8954BA4CE0E7839A0E4E7E45E72C5C125F89C909A22A06F` | 11,192,382 bytes | Rejected after both split-line runs retained CRLF and timed out identically |
| `VT7-PowerShell-Profiles-0.6.2-x64.zip` | `469ED3F3C1ED914D7A89D3AF5D7C4036AE0121E0F84DB4D7976F01DBE27F949C` | 11,048,234 bytes | Rejected after all four CR-only writes produced output but the continuation construct stayed alive |
| `VT7-PowerShell-Profiles-0.6.3-x64.zip` | `ECE1E0980B85506063324F523CC6F571FA0004D18F95384B8987A0050D43439D` | 11,044,543 bytes | Rejected after normal exit 84 identified absent automatic PSReadLine loading in clean Windows PowerShell 5.1 |

No rejected candidate proceeds to its manual checklist.

## Local result

The modern development host has Windows PowerShell 5.1.19041.7725 with
PSReadLine 2.0.0 and PowerShell 7.6.0-preview.5 in the standard preview path.
The latter is outside the Windows 7 support target and was not counted as a
PowerShell 7.2.24 pass.

- Debug build passes.
- The Debug GDI diagnostic, six-renderer hidden-window matrix and injected blank
  negative pass.
- Debug session outbound, session stream, Command Prompt WinPTY root and 3B.2
  PowerShell-profile runners pass.
- Windows PowerShell 5.1 passes the complete clean-profile transport contract.
- The local allow-missing run records the installed 7.6.0 preview as an explicit
  unqualified skip.
- The strict-version negative rejects 7.6.0 preview as 7.2.24 evidence.
- Ordinary Windows PowerShell and discovered PowerShell 7 preview launches both
  create the WPF host, accept owner close and leave no new WinPTY agent behind.
- Release build and `Verify-VT7.ps1` pass all staged native PE, Windows 7
  subsystem, import and app-local runtime checks.
- All four runners pass from the staged Release package. The staged 3B.2 runner
  uses the local-only allow-missing switch; the distributed CMD runner does not.

## Supplied Windows 7 result

The strict 0.6.4 package ran on 2026-09-19 on Windows 7 SP1 x64 with .NET
Framework 4.8.4795.0, `hr-HR`, Windows PowerShell 5.1.14409.1005, exact
PowerShell 7.2.24 and an AMD Radeon RX 6800 XT. All four package stages report
`Passed: True`: session outbound, session stream, Command Prompt WinPTY root and
PowerShell profiles. The profile stage confirms that clean Windows PowerShell
uses its legacy ConsoleHost editor with completion, while PowerShell 7.2.24
loads PSReadLine with prediction capability. Both run a native child, accept the
authoritative resize, drain output and preserve exit through production WinPTY.

Ordinary Windows PowerShell 5.1 and PowerShell 7.2.24 both remained responsive,
resized correctly, retained scrollback, snapped to live output on committed text,
and cleanly replaced their shell and `winpty-agent.exe`. Closing VT7 left no
stale process. The supplied screenshots verify exact PowerShell 7.2.24 with
PSReadLine 2.1.0, multiline Croatian `čćžšđ` output in Windows PowerShell, and
the visible profile selector.

The manual run also isolated two host UI defects. Immediately after a profile
start, WPF retained keyboard focus, so Tab and Down traversed the Start/Reset
controls and End selected the Diagnostics tab. The native viewport already
returned `DLGC_WANTARROWS | DLGC_WANTTAB | DLGC_WANTCHARS |
DLGC_WANTALLKEYS`; the missing operation was moving Win32 focus to the child HWND
after the asynchronous profile start. The selected profile name also inherited
the application's light text on the operating system's light ComboBox chrome.
Neither issue changes the accepted shell, transport, resize or lifecycle result.

## Accepted 0.6.4 candidate

| Field | Value |
| --- | --- |
| Archive | `VT7-PowerShell-Profiles-0.6.4-x64.zip` |
| SHA256 | `3B961B0E31ABD208C056A3B846C68F3BAF9899BFD91FDCD98AADD23A8E35BE46` |
| Size | 11,043,866 bytes |
| Verified files | 36 |
| Application | 0.6.4 x64 |
| Native ABI | 11 |
| Local backend | pinned WinPTY 0.4.3 x64 |
| Source head recorded by manifest | `1a06231d05c37cd5faf9e28d571f94fc9d86af42` plus documented dirty 3B.2 source |

The accepted review copy is at
`D:\Git\VT7\artifacts\VT7-PowerShell-Profiles-0.6.4-x64.zip`. The package is
non-overwriting, recursively hashed and independently checks every ZIP entry.
It adds no dependency or license obligation. Existing WinPTY MIT, font OFL and
project supplier notices are retained.

## Rejected 0.6.5 keyboard correction

Version 0.6.5 makes `TerminalSurface` a WPF keyboard tab stop, implements the
`HwndHost.TabIntoCore` focus contract, and posts focus to the child HWND at WPF
input priority after every successful profile start or replacement. Its focused
session-outbound regression requires that the child takes Win32 focus and that
`WM_GETDLGCODE` claims arrows, Tab, characters and all keys. The selector now
uses explicit dark text on light chrome, including its item template. No native
ABI, TerminalCore, transport, profile discovery or dependency changed. The
Windows 7 automated run passes all four stages, and manual startup, replacement
and shutdown pass. Manual input disproves the fix: Tab still moves to surrounding
buttons, Down leaves the viewport, End selects Diagnostics, and Home returns to
the Terminal viewport tab. The regression only proved Win32 focus and
`WM_GETDLGCODE`; it did not invoke WPF's `IKeyboardInputSink` preprocessing path.

| Field | Value |
| --- | --- |
| Archive | `VT7-PowerShell-Profiles-0.6.5-x64.zip` |
| SHA256 | `265165882549FE1BC8A67BAA3AD50046FC82A0793BFEA3E37E3551724E3BAB59` |
| Size | 11,147,565 bytes |
| Verified files | 36 |
| Application | 0.6.5 x64 |
| Native ABI | 11 |

Debug build and the focused session-outbound check pass. Release build,
portable verification, all four staged runners, recursive package hashes and an
independent ZIP-entry verification also pass. The review copy is at
`D:\Git\VT7\artifacts\VT7-PowerShell-Profiles-0.6.5-x64.zip`.

The supplied 0.6.4 logs, notes and three screenshots are preserved locally under
`artifacts/vt7/evidence/powershell-profiles-win7-0.6.4` with per-file SHA-256
metadata in `ARCHIVE-VERIFICATION.json`. The passing 0.6.5 automated logs and
failed manual-key disposition are preserved separately under
`artifacts/vt7/evidence/powershell-profiles-win7-0.6.5`.

## Accepted HwndHost keyboard-sink correction

Version 0.6.6 overrides `TranslateAcceleratorCore` for terminal navigation,
editing, function, modifier and control keys and forwards those messages to the
native viewport before WPF performs control traversal. It also overrides
`TranslateCharCore` so committed character messages cross the same interop
boundary. Printable keydown remains unhandled there so the existing committed-
text path retains keyboard-layout and dead-key ownership.

The strengthened regression invokes `IKeyboardInputSink.TranslateAccelerator`
for Tab, Down, End and a printable key. It requires the first three to remain in
the terminal, verifies Tab and Down bytes through TerminalCore, and requires the
printable key to remain available for committed-text translation.

| Field | Value |
| --- | --- |
| Archive | `VT7-PowerShell-Profiles-0.6.6-x64.zip` |
| SHA256 | `AB3B0C644674FE3B9C33EF11CAAE53E6D584E2957CF339E3D1B80E2E40F32B93` |
| Size | 11,150,252 bytes |
| Verified files | 36 |
| Application | 0.6.6 x64 |
| Native ABI | 11 |

Debug and Release builds, portable verification, all four staged runners,
recursive hashes and independent ZIP-entry verification pass locally. The review
copy is at `D:\Git\VT7\artifacts\VT7-PowerShell-Profiles-0.6.6-x64.zip`.

## Windows 7 acceptance

The supplied 0.6.6 Release run passes the session-outbound, session-ownership,
WinPTY-root and exact PowerShell-profile stages on Windows 7 SP1 x64 with the
RX 6800 XT. The session-outbound report contains the new WPF keyboard-sink PASS
line and the package-matching host/native hashes. Manual testing confirms all
affected keys work properly in Command Prompt, Windows PowerShell 5.1 and
PowerShell 7.2.24, including after profile replacement.

The seven supplied files are preserved with per-file SHA-256 metadata under
`artifacts/vt7/evidence/powershell-profiles-win7-0.6.6`.

The automated runner does not retain terminal content, commands, keystrokes,
credentials or user profile contents. Ordinary-profile editing, history,
completion display, prediction rendering and visible profile replacement require
the manual checks; local clean-profile automation is not target acceptance.

## Remaining boundary

The 3B.2 PowerShell, WinPTY and WPF/native keyboard-sink behavior is accepted on
the supplied Windows 7 target. This milestone does not claim support for
PowerShell 7.3 or newer, concurrent tabs, arbitrary
full-screen applications, broad code-page coverage, clipboard keybindings or
the later SSH transport. The known WinPTY prompt-line Ctrl+C behavior remains
recorded from 3B.1.
