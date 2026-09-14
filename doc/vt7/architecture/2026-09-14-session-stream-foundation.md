# Session stream foundation 0.3.6

Decision date: 2026-09-14. Status: implemented and locally validated in Debug
and Release. Windows 7 runtime validation belongs with the first real local
transport adapter; no target run is required to begin that work.

This is the first C4 / Milestone 3A production slice after the
[WARP development deferral](2026-09-14-warp-development-deferral.md). It creates
the common path by which a local or remote transport can deliver ordered bytes
to TerminalCore. This source slice does not instantiate WinPTY or an SSH
implementation and does not implement process creation, input, resize delivery
or terminal replies. The subsequently completed P01 record selects WinPTY for
Windows 7 local legacy-console sessions behind this boundary.

## Implemented boundary

ABI 9 adds four surface calls:

- `VT7_BeginSurfaceStream` clears the active/main terminal view, resets inherited
  VT state and opens a new decoder generation.
- `VT7_WriteSurfaceUtf8` accepts an ordered byte chunk of at most 1 MiB on the
  surface's creating UI thread.
- `VT7_EndSurfaceStream` records EOF. It returns
  `HRESULT_FROM_WIN32(ERROR_NO_UNICODE_TRANSLATION)` if EOF leaves an incomplete
  UTF-8 code point and discards that partial code point.
- `VT7_GetSurfaceStreamInfo` reports the generation, accepted bytes, decoded
  UTF-16 units, write calls, pending UTF-8 bytes, completion state and last
  stream HRESULT.

The native `Surface` owns one `Utf8TerminalStream`. Each accepted write converts
through the inherited incremental `til::u8u16` implementation and then calls
`Terminal::Write` while holding the terminal write lock. Decoder state is
committed only after conversion and the core write succeed. TerminalCore keeps
its own parser state, so a VT sequence may span any number of byte writes.

Malformed complete UTF-8 follows the inherited Windows conversion behavior and
is represented by the replacement character. An incomplete final code point is
different: the stream reports an EOF error rather than losing bytes silently.
Writes after EOF return `ERROR_INVALID_STATE`. A later begin creates a clean
generation and recovery is tested.

## Managed owner and backpressure

`SessionOutputPump` is constructed on the terminal surface dispatcher and owns
one native stream generation. A future transport reader may call `WriteAsync`
from any thread. The pump copies every accepted chunk, preserves FIFO order and
dispatches all native HWND calls to the UI thread.

The queue has 16 slots and each chunk is limited to 64 KiB. A producer awaiting
a full queue receives backpressure; at maximum chunk size no more than 1 MiB is
queued. `CompleteAsync` stops admission, drains all already accepted writes and
then ends the native stream. Disposal rejects or faults queued work before the
WPF owner destroys the native surface. The transport/session owner must await
completion when final output is required and use disposal only for abandonment.
One transport read loop serializes `WriteAsync` calls; concurrent producers must
be ordered by that owner before entering the pump.

The first visible fixture uses this exact queue with irregular chunk sizes. Its
Croatian HR Latin line covers `č ć ž š đ Č Ć Ž Š Đ`, and its styling sequences
exercise parser state across transport boundaries. The former static demo
remains available through the reset button and in the established renderer
regressions.

## Local validation

Run:

```powershell
.\tools\Build-VT7.ps1 -Configuration Debug -NoRestore
.\tools\Test-VT7SessionStream.ps1 -Configuration Debug
.\tools\Build-VT7.ps1 -Configuration Release -NoRestore
.\tools\Test-VT7SessionStream.ps1 -Configuration Release
.\tools\Verify-VT7.ps1 -Configuration Release
```

The focused test sends the same 388-byte fixture as one write, one byte per
write and an irregular 1/2/3/5/8/13 pattern. The one-byte run makes 388 writes,
including splits inside Croatian UTF-8 code points and VT control sequences,
and produces the exact single-write raster. It also verifies incomplete EOF,
new-generation recovery and HWND destruction. Headless native checks separately
split the fixture at every byte boundary and verify malformed/incomplete input.

Both configurations pass locally on Windows NT 10.0.19044 with the declared
pinned toolchain. Release static verification confirms x64 images, subsystem
6.1 and the existing forbidden-import gate. The established Debug diagnostics,
six viewport modes and expected blank-frame negative also pass after the ABI
change. These results validate the development boundary; they are not Windows 7
transport, input or sustained-session acceptance.

## Subsequent slices and current next step

P01 now selects WinPTY 0.4.3 for Windows 7 local legacy-console sessions behind
this byte boundary. Its controlled child/backend/core comparison passes on the
target with documented raw-VT, code-page, cursor-width and intermediate-state
limits. Production integration must keep process/agent handles separate, read
output without reordering, await final drain, and map authoritative grid changes
to WinPTY resize generations.

The [0.3.7 outbound foundation](2026-09-14-session-outbound-foundation.md) now
implements the generation-checked serialized queue and native-HWND adapter.
[I01](../validation/2026-09-14-input-i01.md) establishes the Windows 7
Croatian HR Latin boundary: OS-committed text comes once from the native HWND,
key metadata retains control/non-text distinctions, and the live UI thread must
not retranslate printable keys with `ToUnicodeEx`. The exact 0.3.7 target
candidate passes on Windows 7. S00 subsequently accepted direct external
OpenSSH command bytes and rejected its redirected interactive PTY architecture.
SSH.NET S01 0.6 accepts SSH.NET 2026.0.0 after both Windows 7
controlled-Debian runs pass. The result requires the production owner to dispose
the shell stream before disconnecting the client.
Before 3B connects either backend, apply the
[session ownership review](2026-09-14-session-ownership-and-source-review.md):
the production session and TerminalCore lifetime must be distinct from the
current transient HWND/WPF presentation lifetime.
