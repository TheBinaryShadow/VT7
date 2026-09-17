VT7 WinPTY root transport 0.5.2 / ABI 11
==========================================

This engineering candidate is the first production local-session slice of
Milestone 3B. It connects one explicit Command Prompt profile to the accepted
WinPTY 0.4.3 backend through the 3A TerminalSession ownership boundary.

Target: Windows 7 SP1 x64 with the Platform Update, .NET Framework 4.8, UCRT,
and the project's recorded loader/SHA-2 prerequisites. No installation or
system change is performed. Keep every file and directory beside VT7.Host.exe.

AUTOMATED CHECK

Run RUN-WINPTY-ROOT.cmd first. It verifies every package hash and the exact
pinned WinPTY DLL, agent and license. It then runs the accepted 3A outbound and
ownership checks followed by the real Command Prompt transport check. Each test
creates a collision-resistant folder beneath Logs. Return the entire new Logs
directory whether the run passes or fails.

The new check proves:

- an explicit absolute cmd.exe profile, working directory and Unicode
  environment block;
- generation-1 input through the ordered TerminalSession outbound queue;
- an authoritative 100 by 30 WinPTY resize;
- complete output drain before preserving child exit code 37;
- deterministic owner cancellation and WinPTY agent shutdown; and
- TerminalCore stream closure only after the final output block.

MANUAL INTERACTION CHECK

After the automated check passes, run RUN-VT7-COMMAND-PROMPT.cmd. VT7 should
open a real Command Prompt. Check ordinary typing and Enter, Croatian HR Latin
characters, Backspace and cursor editing, Ctrl+C on a running command, several
window resizes, a command that prints enough lines to scroll, mouse-wheel
scrollback in both directions, keyboard input returning the view to live output,
and `exit`.

For the live-output scroll check, this Windows PowerShell 5.1 command emits 200
numbered lines over about ten seconds:

  powershell -NoProfile -Command "1..200 | ForEach-Object { Write-Host ('line {0}' -f $_); Start-Sleep -Milliseconds 50 }"

Wheel upward while it is still printing. The view should remain on the chosen
older lines while output continues. Wheel downward to the newest output, then
wheel up once more and press an ordinary key; keyboard input should return the
view to the live prompt.
Report what worked and any visible corruption, duplicated characters, hangs,
or surviving winpty-agent.exe process. This package does not record terminal
content, keystrokes or credentials.

SCOPE

This candidate covers Command Prompt only. It does not yet qualify Windows
PowerShell 5.1, PowerShell 7.2.24, PSReadLine, arbitrary console applications,
tabs, panes or SSH. Those remain later 3B and Milestone 5 work.

The package includes unmodified official WinPTY 0.4.3 x64 runtime files and its
MIT license. Included fonts retain OFL 1.1; VT7 and incorporated dependencies
retain the licenses and notices supplied in this package.
