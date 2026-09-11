# VT protocol integration and terminal trust boundaries

Research date: 2026-09-11. Priority: P0 when connecting the first real session. This file concerns application behavior; it does not claim that Windows 7's system console implements modern VT.

## The inherited parser is only part of the terminal

Observed in repository: OutputStateMachineEngine dispatches cursor/attribute operations and OSC actions for titles, clipboard writes, working-directory metadata and hyperlinks. DCS dispatch includes sixel. AdaptDispatch forwards clipboard content to the terminal API. Terminal::ReturnResponse forwards replies through the installed input callback. Their existence in upstream source does not establish that VT7's proof has implemented the corresponding host action or renderer path. [1][2][3]

The modern Microsoft console reference describes VT as both output controls and input-side replies. It explicitly allows sequences to be split across writes. It is a protocol reference, not evidence of Windows 7 console-host feature support. [4] The different paths are analyzed in the [local-console](02-console-and-winpty.md) and [SSH](16-ssh-and-remote-pty.md) notes.

**Recommendation:** maintain a VT7 feature ledger with five columns: recognized by parser; represented by core; rendered; host action implemented; available through each backend. A parsed control sequence is not an end-to-end feature.

## Stream and callback contracts

Recommended integration invariants:

1. Give each session its own decoder, parser state and input encoder. Preserve them across arbitrary transport chunks.
2. Serialize output for that session. Decode text without stripping or interpreting escape bytes in an unrelated UI layer.
3. Preserve control ordering with ordinary text. Coalesce redraw requests, not terminal bytes or state mutations.
4. Route protocol replies to the originating session's input queue. Never display a reply as output or send it to the currently selected tab by accident.
5. Keep host callbacks short. Copy owned data and dispatch UI work without synchronous lock inversion between core, renderer and WPF.
6. Invalidate queued actions with a session/surface generation on close. A recycled HWND or tab index must not become a new destination for old output.

These are proposed contracts, not claims that the current callbacks satisfy them. They follow from the inspected parser and response boundaries. [1][3]

**Backpressure proposal:** bound queued bytes, scrollback, image storage and pending UI work independently. Pause transport consumption when necessary instead of dropping bytes in a multibyte character or escape sequence. A bounded redraw queue does not bound terminal history memory.

## Output can request privileged desktop actions

Terminal output may come from a remote machine, a repository tool, or even a displayed file. Treat its requests as data from that session, not as user commands to the desktop. The controls below are real protocol/parser surfaces; the proposed policies are VT7 design choices.

| Surface | Observed/specification behavior | Proposed host boundary |
| --- | --- | --- |
| Clipboard | OSC 52 can replace selection data; the xterm protocol also has a query form. VT7's inherited parser dispatches writes and explicitly excludes the query path at that branch. [1][5] | Make remote clipboard writes an explicit policy; impose decoded-size limits. Do not add clipboard reads merely to complete a protocol checklist. |
| Hyperlinks | The inherited parser and buffer accept hyperlink metadata. [1][2] | Require user activation, validate URI schemes, display the actual destination, and keep link metadata distinct from rendered label text. |
| Title | Output can set the terminal title. [1][3] | Bound title length; keep a stable session/profile identity available. A title must not select credentials, trust state or executable paths. |
| Working directory | An OSC action forwards a supplied URI. [1][2] | Treat it as session metadata. Validate local versus remote authority before using it for local file opening or new-session startup. |
| Image/downloadable-font data | Inherited DCS dispatch contains image/font-related operations. [1][2] | Inventory actual reachability and memory limits before enabling support; unknown operations should have bounded handling. |
| Device/status queries | The core has an input-response callback. [3] | Advertise only implemented capabilities. Keep replies scoped to the current session and rate-limit unreasonable amplification if required. |

This is a threat model and implementation checklist, not a finding of exploitable vulnerabilities in the static proof.

## Modes, resets and capability reporting

The inherited input/output implementations contain mode-dependent behavior. Upstream device attributes are generated in AdaptDispatch, while TerminalInput translates input according to terminal modes. These paths need a shared integration contract. [2][6]

Proposed acceptance cases:

- Normal and alternate buffers: entry/exit, saved cursor, scrollback policy, resize and selection invalidation.
- Cursor-key/keypad modes: application and normal sequences, including after shell/application exit.
- Mouse tracking and bracketed paste: enable, disable, reset, lost focus, and a full-screen program that crashes while modes are active.
- Colors and palette changes: default colors versus indexed colors versus true color; theme changes and reverse video.
- Synchronized output: begin/end, timeout, interrupted process, resize and closing the tab. A missing end marker must not permanently freeze the UI.
- Device attributes and size queries: replies match the selected backend's effective behavior and actual grid.

Do not advertise sixel, color-font rendering, modern keyboard protocols, or another extension solely because an upstream dispatch method exists. The renderer/controller and local transport may not preserve it.

## Bounded parser and integration testing

Proposed corpus: split every short sequence at each byte boundary; split UTF-8 immediately before/within ESC-adjacent text; huge numeric parameters; long OSC/DCS strings; malformed base64; incomplete termination at disconnect; repeated title/clipboard changes; invalid surrogate input at a direct UTF-16 boundary; and arbitrary control bytes mixed with ordinary text.

Assert buffer/cursor state, generated replies, allowed host actions, peak memory and completion time. An image that looks correct is insufficient if the reply went to another session or clipboard changed unexpectedly. Retain minimized byte fixtures with expected state rather than relying entirely on screenshots.

For replay tools, disable external desktop actions by default and record intended actions as structured results. That lets diagnostic captures exercise the parser without repeating a clipboard mutation or opening a link. This is a proposed test-harness property.

## Sources

- [1] [OutputStateMachineEngine.cpp](../../../src/terminal/parser/OutputStateMachineEngine.cpp), especially ActionOscDispatch and ActionDcsDispatch; working tree inspected 2026-09-11.
- [2] [AdaptDispatch](../../../src/terminal/adapter/adaptDispatch.cpp), including device attributes, clipboard, hyperlinks, working-directory and sixel paths.
- [3] [Terminal API callbacks](../../../src/cascadia/TerminalCore/TerminalApi.cpp).
- [4] Microsoft, [Console Virtual Terminal Sequences](https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences).
- [5] Xterm, [Control Sequences: OSC selection operations](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html).
- [6] [Terminal input implementation](../../../src/terminal/input/terminalInput.cpp).
