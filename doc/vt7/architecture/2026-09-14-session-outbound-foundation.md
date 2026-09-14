# Session outbound and native input foundation 0.3.7

Decision date: 2026-09-14. Status: implemented and validated locally in Debug
and Release and on the exact issued Windows 7 SP1 x64 candidate.

This C4 / Milestone 3A slice implements the bounded outbound ordering and native
child-HWND input contract chosen by the completed
[I01 characterization](../validation/2026-09-14-input-i01.md). It remains
backend-neutral: the normal host currently drains to an audit sink, and no
WinPTY process or SSH connection is created. S00 is complete; the approved
SSH.NET 2026.0.0 S01 Windows 7 diagnostic is the next SSH task.

## Serialized outbound owner

`SessionOutboundQueue` owns one positive session generation and one
`ISessionOutboundSink`. Producers submit immutable operations for encoded input,
Interrupt, Break, focus, resize, paste or terminal replies. The queue assigns a
monotonic sequence, copies byte payloads, and sends operations to exactly one
asynchronous consumer in FIFO order.

Admission is bounded to 256 pending operations. UI input uses nonblocking
admission: a full queue is an explicit error instead of blocking the HWND
message thread. A generation mismatch returns `StaleGeneration`; completion
stops admission, drains accepted operations, completes the sink once and rejects
later work. Disposal is the explicit abandonment path used by the current
backend-free window close. A real backend owner must choose drain or abandonment
from its exit reason and observe `Completion` failures.

Only consecutive pending resize operations coalesce. The replacement keeps the
newest columns, rows and sequence, so an intervening byte/control operation
prevents coalescing across it. Paste and terminal-reply operation kinds are
present now so they enter this same order when implemented; no clipboard or
terminal-reply callback is connected in 0.3.7.

## Native HWND input adapter

`NativeHwndInputAdapter` is attached only to `TerminalSurface.WndProc`. WPF
preview input remains application-command observation and never enters the
terminal stream. The native surface is tab-stop capable, requests arrow, Tab,
character and other key messages through `WM_GETDLGCODE`, and takes focus on a
left click.

The adapter applies the I01 contract:

- `WM_CHAR` and `WM_SYSCHAR` carry OS-committed UTF-16. `WM_DEADCHAR` and
  `WM_SYSDEADCHAR` do not emit text; the later committed character does.
- Printable keydown is not translated again. Croatian, AltGr and composed text
  therefore use the keyboard-layout state exactly once.
- Known non-text keys and modifiers retain virtual key, scan, enhanced, repeat,
  toggle and left/right modifier state. They are encoded by the same inherited
  `TerminalInput` instance whose modes are changed by parsed output.
- Ctrl+C and Ctrl+Break enqueue distinct `Interrupt` and `Break` operations,
  each with ETX bytes. Their immediately correlated U+0003 character message is
  consumed. The same correlation prevents duplicate CR, HT or BS after a
  keydown already emitted Enter, Tab or Backspace through TerminalInput.
- Focus loss releases every tracked modifier into TerminalInput before the
  focus-loss operation. A missing physical key-up cannot leak modifier state
  into later input.

ABI 10 adds `VT7_EncodeSurfaceKey`, `VT7_EncodeSurfaceChar` and
`VT7_EncodeSurfaceFocus`. The key call uses the new
`Terminal::SendKeyEventWithoutLayoutTranslation` entry point. It preserves the
inherited mode-aware encoder while skipping `Terminal::_CharacterFromKeyEvent`.
This is required because Windows 7 ignored the attempted non-mutating
`ToUnicodeEx` flag in I01. The host does not implement a second general virtual
key to VT mapper.

The native result returns handled state and at most 256 UTF-8 bytes for one
window message. Current deterministic cases and ordinary key-message repeat
bursts fit this boundary. Larger input belongs to the paste path rather than a
single key message. This fixed result size must be revisited if later KKP or
synthetic-input tests produce a larger single-message encoding.

## Authoritative resize

The native surface still computes the cell grid and calls
`Terminal::UserResize`. After that update it posts the columns and rows back to
the hosted HWND using the private ABI 10 grid notification. `TerminalSurface`
coalesces those notifications at dispatcher background priority and submits one
resize operation for the newest grid. WPF `SizeChanged` is not an outbound
source. The same columns and rows are therefore ready for WinPTY resize or SSH
window-change without duplicating the two WPF dimension observations seen by
I01.

## Deterministic validation

`Test-VT7SessionOutbound.ps1` runs a hidden ABI 10 host check. It verifies:

- stale-generation rejection, bounded full-queue behavior, FIFO drain and
  post-completion rejection;
- consecutive resize coalescing with the newest grid and sequence;
- native HWND committed Croatian `č`/`ć` and an AltGr character;
- one CR for Enter, one Interrupt for Ctrl+C and one Break for Ctrl+Break, with
  no duplicated character-path control byte;
- inherited TerminalInput Up-arrow encoding as `ESC [ A`;
- focus serialization and modifier reconciliation; and
- one coalesced resize matching the native terminal grid.

Debug and Release pass locally on Windows NT 10.0.19044 with the pinned build
toolchain. The existing session-stream test also passes in both configurations,
the established Debug diagnostics/six-renderer viewport matrix and blank-frame
negative pass, and static verification confirms x64, subsystem 6.1, ABI 10 and
the forbidden import gate.

The exact candidate is `VT7-Session-Outbound-0.3.7-x64.zip`, 10,560,527 bytes,
SHA256 `1762520CD18A63E5A7BD30C7708658DA92B195830A3D68282A83FB21A4360CFC`,
with 26 verified files. Its manifest records source HEAD
`8b10540e56c3d59f453ac6c3e363a9ec9e562b9f` and the dirty source state. The
issued archive is retained locally under
`artifacts\vt7\packages\VT7-Session-Outbound-0.3.7-x64.zip`.

The batch entry point and exact ZIP pass locally through `cmd.exe` and Windows
PowerShell 5.1 from a path containing spaces. Two earlier unissued local
candidates exposed `Get-FileHash` availability and unquoted `Start-Process`
argument problems. They were deleted and never copied to the target. The issued
runner uses an in-process SHA-256 implementation, quotes its report path, creates
a collision-resistant `Logs` child, and retains environment plus diagnostic
output.

## Supplied Windows 7 result

The returned run `session-outbound-20260914-063714-74969eea` completes and
reports `Passed: True`. Its environment is Windows 7 SP1 build 7601, x64 OS and
process, .NET Framework 4.8.4795.0, Croatian `hr-HR` culture, English `en-US` UI
culture and Windows PowerShell 5.1.14409.1005. The graphics preflight passes on
an AMD Radeon RX 6800 XT in hardware and WARP at feature level 11.0.

The run identifies Release x64 build 0.3.7 and native ABI 10. Its host SHA256
`164C34E2DFEE8460F1CF8FB738EEE6A5460CCCE622B9C6BD4931C495E1A107C8`
and native SHA256
`E8F4E06693EF5A40BD0C08857340F22251B86FE2338EDF913DA47727E54E0E42`
match the issued package. The bounded queue passes stale-generation rejection,
full-queue backpressure, FIFO drain and consecutive-pending-resize coalescing.
The native HWND path passes one committed Croatian UTF-16 input, distinct
Ctrl+C and Ctrl+Break without duplicate ETX, TerminalCore non-text encoding,
focus reconciliation and one authoritative resize grid. The inherited
TerminalCore, byte-stream and Windows 7 font-boundary checks also pass.

The two returned files total 2,807 bytes. Their source and archived SHA256
inventories match. The raw run is preserved under
`artifacts\vt7\evidence\session-outbound-win7-0.3.7\session-outbound-20260914-063714-74969eea\`;
see the [archive verification](../../../artifacts/vt7/evidence/session-outbound-win7-0.3.7/ARCHIVE-VERIFICATION.json)
and [independent analysis](../../../artifacts/vt7/evidence/session-outbound-win7-0.3.7/INDEPENDENT-ANALYSIS.json).
This accepts the bounded 0.3.7 target slice. It does not claim a production
backend or complete Milestone 3A.

## Remaining boundary

This slice does not yet complete the production session owner. TerminalCore and
the incremental decoder still live in the interim HWND-backed `Surface`; view
recreation is therefore not session-neutral yet. Terminal-generated replies are
represented by the queue contract but are not wired from the core callback.
Printable repeat, additional layouts and IME/candidate geometry remain in 3C as
recorded by I01. Mouse input, paste policy, clipboard access and host actions are
also outside this slice.

S00 rejects unmodified redirected Win32-OpenSSH for interactive PTY sessions
after accepting its non-PTY command path. S01 now evaluates the approved
SSH.NET 2026.0.0 candidate. Before 3B connects WinPTY, the
terminal/core/session identity must move out of the transient view,
and inbound output, outbound input/replies, resize, cancellation, EOF, exit and
teardown must use the same generation owner described in the
[session ownership review](2026-09-14-session-ownership-and-source-review.md).
