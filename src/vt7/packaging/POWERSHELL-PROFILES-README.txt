VT7 local PowerShell profiles 0.6.6 / ABI 11
================================================

This Milestone 3B.2 engineering candidate adds explicit local profiles for
Windows PowerShell 5.1 and PowerShell 7.2.24 beside the accepted Command Prompt
profile. The Terminal viewport selector can replace the current root session with any
discovered profile. Each replacement closes and joins the prior WinPTY session,
starts a new TerminalSession generation and clears the active terminal buffer.
Version 0.6.6 returns keyboard focus to the native terminal after startup and
profile replacement, processes terminal navigation keys through the WPF
HwndHost keyboard-sink boundary, and retains the explicit readable selector.

Target: Windows 7 SP1 x64 with the Platform Update, .NET Framework 4.8, UCRT,
the project's recorded loader/SHA-2 prerequisites, Windows PowerShell 5.1 and
PowerShell 7.2.24. Keep every package file and directory beside VT7.Host.exe.
No installation, execution-policy change, global code-page change or user-
profile modification is performed.

PROFILE POLICY

Ordinary launches use -NoLogo and preserve the user's PowerShell profile
scripts, execution policy, modules and normal PSReadLine configuration. Only the
bounded automated test uses -NoProfile so its verdict cannot depend on personal
startup scripts. PowerShell 7 is resolved to an explicit 64-bit Program Files
path. Exact version 7.2.24 is the Windows 7 qualification gate; another 7.x
version may be shown in the selector but is labeled unqualified on Windows 7.

AUTOMATED CHECK

Run RUN-POWERSHELL-PROFILES.cmd first. It verifies package hashes and pinned
WinPTY identity, reruns the accepted 3A and Command Prompt transport checks, and
then requires both PowerShell runtimes. It checks:

Version 0.6.6 submits one ordinary prompt line terminated by the carriage return
emitted by a terminal Enter key. Each failed assertion exits with a distinct code.
The automated gate no longer depends on an older console editor's continuation-
prompt behavior; the manual workflow below owns visible multiline validation.
Windows PowerShell 5.1 accepts its built-in ConsoleHost editor when PSReadLine is
not auto-loaded; PowerShell 7.2.24 still requires its bundled PSReadLine and
prediction capability. A timeout records the WinPTY input/output counters.

- explicit executable, arguments, environment and working-directory contracts;
- ordinary-profile preservation and clean-profile diagnostic isolation;
- runtime 5.1 and exact runtime 7.2.24 from inside each console session;
- TabExpansion2 completion, optional Windows PowerShell PSReadLine or its legacy
  ConsoleHost editor, and required PowerShell 7 PSReadLine prediction capability;
- Croatian Unicode through the child environment and WinPTY input path;
- a nested native cmd.exe child;
- authoritative 108 by 32 resize, output drain, exit-code preservation and
  TerminalDocument closure.

Every run creates a new folder beneath Logs. Return the entire new Logs folder
whether the check passes or fails. Terminal content, commands, keystrokes,
credentials and user profile contents are not recorded.

ORDINARY WINDOWS POWERSHELL 5.1 CHECK

Run RUN-VT7-WINDOWS-POWERSHELL.cmd. Confirm the title and selector say Windows
PowerShell 5.1, then check:

1. Type Croatian HR Latin text including č ć ž š đ and edit it with Left, Right,
   Home, End, Backspace and Delete before pressing Enter.
2. Run two harmless commands, then use Up and Down to move through history.
3. Type Get-Chi and press Tab. Completion should produce Get-ChildItem.
4. Enter a multiline block such as:

     & {
       'VT7 multiline čćžšđ'
     }

5. Run `cmd.exe /d /q /c echo VT7 native child` and then `notepad.exe`. Close
   Notepad and confirm the prompt remains usable.
6. Resize repeatedly, print enough output for scrollback, scroll away from live
   output and type a character to return to the live prompt.

ORDINARY POWERSHELL 7.2.24 CHECK

Run RUN-VT7-POWERSHELL-7.cmd and repeat the editing, history, completion,
multiline, native-child, resize and scrollback checks. Also run:

  $PSVersionTable.PSVersion
  Get-Module PSReadLine
  Get-PSReadLineOption | Select-Object PredictionSource

The runtime must report 7.2.24. PredictionSource must be present. If prediction
is enabled in the user's existing PSReadLine settings, confirm the displayed
suggestion updates cleanly while typing and accepting or ignoring it. VT7 does
not change the user's prediction setting.

PROFILE REPLACEMENT CHECK

Use the selector at the bottom of the Terminal viewport and click Start profile
to move among Command Prompt, Windows PowerShell 5.1 and PowerShell 7.2.24.
Confirm each selection opens the named shell, the previous winpty-agent.exe does
not survive, the viewport accepts input immediately, and closing VT7 leaves no
child shell or WinPTY agent. Starting a profile intentionally terminates the
previous root session; tabs and concurrent sessions are later work.

After each launch, verify Tab, Down and End remain terminal keys without first
clicking the viewport. Confirm the selected profile name is readable in the
closed selector.

Report any visible corruption, duplicated characters, missing history or
completion, bad continuation prompts, hangs, stale input, wrong profile title,
or surviving child process.

LICENSES

This candidate adds no dependency. It includes unmodified official WinPTY 0.4.3
runtime files and its MIT license. Included fonts retain OFL 1.1; VT7 and
incorporated dependencies retain the licenses and notices supplied here.
