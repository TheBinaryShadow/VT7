# WinPTY root transport 3B.1

Date: 2026-09-17

Status: version 0.5.0 is qualified locally and on the supplied Windows 7 SP1 x64
target for the 3B.1 transport, Unicode and lifecycle scope. Active-command
Ctrl+C works. Prompt-line cancellation is a classified WinPTY 0.4.3 fidelity
limit. The same run exposed missing viewport scroll input; version 0.5.1 adds
native mouse-wheel scrollback. Its target run accepts wheel movement and retained
history but finds printable-character snap-to-live missing. Version 0.5.2 fixes
that boundary and is accepted after the reported target-machine checks pass
without further issues.

## Scope

Version 0.5.0/native ABI 11 replaces the visible proof host's fake root with a
real `WinPtyTransport` behind `ITerminalTransport`. One explicit Command Prompt
profile pins `%SystemRoot%\System32\cmd.exe`, `/d /q /k`, an absolute working
directory and a sorted Unicode environment block. Hidden diagnostic paths keep
their deterministic fake transports.

This is the first production local-session slice of 3B. It does not qualify
Windows PowerShell 5.1, PowerShell 7.2.24, PSReadLine, arbitrary console
applications, tabs, panes, SSH or the complete Milestone 3B gate.

## Implementation

- `WinPtyTransport` owns the WinPTY handle, input/output pipes, child process
  handle, agent relationship, read loop and cancellation registration.
- Startup uses the P01-selected WinPTY 0.4.3 configuration: no special config
  flags, no mouse mode, a ten-second agent timeout, overlapped output before
  input, and `AUTO_SHUTDOWN | EXIT_AFTER_SHUTDOWN` spawn flags.
- All input and authoritative resize operations retain the 3A bounded,
  generation-checked outbound queue. `winpty_set_size` receives the native grid.
- Output is sequenced into the existing document pump. Natural EOF waits for
  the child and retains its exit code. Owner cancellation closes input, frees
  WinPTY when required, joins the reader and ends the document stream.
- Session completion continuations now run asynchronously. This prevents a
  natural child exit from making the outbound worker synchronously enter its
  own disposal/join path.
- Normal visible startup creates the real Command Prompt session. Session exit
  leaves the final scrollback visible and reports the result in the host status.
- The host build copies the exact pinned `winpty.dll`, `winpty-agent.exe` and
  `winpty-LICENSE.txt` beside the executable. No new license family is added;
  WinPTY 0.4.3 is MIT licensed and was already approved and disclosed.

## Automated contract

`Test-VT7WinPtySession.ps1` verifies the exact WinPTY hashes and, in a packaged
run, every entry in `SHA256SUMS.txt`. Its real Command Prompt case proves:

- explicit profile identity, paths, arguments and a Croatian Unicode
  environment value;
- root generation 1 and initial output;
- one authoritative resize to 100 by 30;
- one exact 45-byte UTF-8 input operation;
- output after admitted input and a complete document drain;
- reported child exit code 37; and
- a separate owner-cancellation path with no surviving session callback.

The diagnostic deliberately does not retain terminal content or keystrokes.

## Local results

Debug and Release builds pass the new check. Release recorded `cmd.exe` PID
34360, one 100 by 30 resize, 45 input bytes, 144 output bytes in two blocks and
exit code 37. The cancellation case also passed. Both 3A focused regressions
pass after the lifecycle change, and the complete Release host suite passes GDI,
all five Atlas smoke modes and the injected blank-frame negative. A visible
Release launch created exactly one new `winpty-agent.exe`; normal WPF close
returned host exit 0 and left no new agent process.

Local Release identities:

| File | SHA256 |
| --- | --- |
| `VT7.Host.exe` | `E9678559CBA28A408A5F3A67397DD9D90ECCEA019F7CC0AB241983603AF59355` |
| `VT7.Native.dll` | `728E37F16ED71CD3124028161B6B1D58B8AFACB29CF59A5A138B6E3B24D313F5` |
| `winpty.dll` | `936F611C2129600D35AB7AAD45546A837F4F3A9CA7F673E5D66B48C313B9CD75` |
| `winpty-agent.exe` | `9ADD1A61155EC47CF6F347FAF776B746EEBBDE1DC9360D81B8A909DA34650642` |

The local machine was Windows NT 10.0.19044 x64, .NET Framework 4.8.9339.0,
`hr-HR` culture, PowerShell 7.6.5 and an AMD Radeon RX 7900 XTX. These results
do not establish Windows 7 acceptance.

## Issued Windows 7 candidate

`VT7-WinPty-Root-0.5.0-x64.zip` contains 33 verified files and is 11,158,230
bytes. Its SHA256 is
`5BC66EB5149301140BCB916EC270349DB1BC955309FEB3949B5C65E2185E5F3E`.
The package includes the exact WinPTY runtime and license, app-local VC runtime,
3A regression runners, the 3B.1 runner, a manual Command Prompt launcher,
symbols, fonts, notices and supplier licenses.

Run `RUN-WINPTY-ROOT.cmd` first and return its complete `Logs` directory. After
it passes, run `RUN-VT7-COMMAND-PROMPT.cmd` and manually check ordinary and
Croatian HR Latin typing, editing, Ctrl+C, resizing, scroll output, `exit`, and
whether any WinPTY agent survives.

## Supplied Windows 7 result

The returned run on Windows NT 6.1.7601 SP1 x64, .NET Framework 4.8.4795.0,
Windows PowerShell 5.1.14409.1005, `hr-HR` culture and an AMD Radeon RX 6800 XT
matches the issued host, native, WinPTY DLL and agent hashes. All three packaged
runners pass:

- the outbound suite retains distinct Ctrl+C/Ctrl+Break operations, Croatian
  committed text and authoritative resize ordering;
- the ABI 11 ownership suite retains exact raster `D90BE1DA17351A44`, headless
  drain, generation-2 reattachment, fake generations 1/2/3 and originating
  replies; and
- the production root launches `cmd.exe` PID 3680, resizes to 100 by 30, writes
  45 bytes, drains 144 bytes in two blocks, preserves exit code 37 and passes
  owner cancellation.

The visible proof log passes at 105 by 21 cells on Atlas D3D11 hardware. Manual
use was otherwise clean: ordinary and Croatian HR Latin text rendered correctly,
Notepad launched from the session and created `ććć.txt`, and the user reported
no other interaction problem.

The apparent Ctrl+C failure occurred only at an empty or partly typed prompt.
A follow-up test against a running command aborted it correctly. Ctrl+V and
Ctrl+A produced their classic console control characters (`^V` and `^A`), which
is expected before VT7 implements host paste and selection keybindings. The
native adapter proves that Ctrl+C creates exactly one `Interrupt` operation
containing ETX and suppresses its correlated character message. [Exact WinPTY 0.4.3 source](https://github.com/rprichard/winpty/blob/0.4.3/src/agent/ConsoleInput.cc#L340-L346)
then special-cases ETX while processed input is enabled and calls
`GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0)`. [Upstream issue 116](https://github.com/rprichard/winpty/issues/116)
records the same distinction: an active command can be aborted while interactive
Command Prompt or PowerShell may not cancel the current input line. The target
result matches that known limitation. It is recorded for 3C fidelity work and
does not indicate a VT7 control-delivery defect.

The user also found that the 0.5.0 viewport had no scroll input. Its 500-line
TerminalCore scrollback buffer was populated correctly, but the native child
HWND never handled `WM_MOUSEWHEEL`. Version 0.5.1 retains ABI 11 and adds the
missing presentation input path. It honors the Windows wheel-lines setting,
accumulates high-resolution wheel deltas, calls TerminalCore's
`UserScrollViewport` and preserves a user-scrolled view while output continues.
The Windows 7 run confirms scrolling in both directions during and after output,
with the view retained on older lines. Backspace, Delete and arrow keys return
to live output, but printable characters do not.

The difference follows directly from VT7's accepted I01 input architecture.
Upstream Terminal calls its key encoder before its character encoder, and the
key path performs snap-on-input. VT7 deliberately takes printable text only
from the native HWND's `WM_CHAR`, preserving Windows-owned Croatian, dead-key
and AltGr composition without live-thread `ToUnicodeEx`. Version 0.5.2 applies
the snap at that committed-character boundary. The regression now sends a real
printable `x`, verifies its encoded byte and verifies the viewport returns to
live output. Debug and Release verification pass locally.

The immutable follow-up candidate is
`VT7-WinPty-Root-0.5.1-x64.zip`, 11,193,875 bytes, 33 verified files, SHA256
`2A0532EDA35B1B9D4CF805830C72DB8E82FC01941D96F87CEC1B5D57B68B46C0`.
Packaging reran the outbound, ownership and real WinPTY transport checks from
the staged bytes; all pass. Its wheel and retention behavior pass on Windows 7;
its printable-character snap behavior does not.

The corrected candidate is `VT7-WinPty-Root-0.5.2-x64.zip`, 11,161,619 bytes,
33 verified files, SHA256
`BDB12430AF3325EA4ED4AAE153CF7AF355411BF57E3DD4E4303132C372499A87`.
All three staged package runners and Debug/Release verification pass. The ZIP is
copied to `artifacts/`. On the supplied test machines, ordinary printable input
now returns the scrolled viewport to live output and no additional issue was
reported. This closes the bounded 3B.1 scrollback correction.

The seven supplied files and an archive manifest are preserved under
`artifacts/vt7/evidence/winpty-root-win7-0.5.0` (13,016 bytes including the
manifest). No terminal content, credentials or private endpoint data is present.

## Next step

Continue 3B with explicit Windows PowerShell 5.1 and PowerShell
7.2.24 profiles plus their PSReadLine and native-child acceptance corpus.
Prompt-line cancellation, paste and selection keybindings remain in 3C.
