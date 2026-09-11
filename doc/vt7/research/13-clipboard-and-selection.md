# Clipboard, terminal selection and paste

Research date: 2026-09-11. Priority: P1.

## Windows clipboard contract

CF_UNICODETEXT is the Unicode text clipboard format, with NUL termination and CR-LF line endings. CF_TEXT/CF_OEMTEXT involve legacy encodings and may be converted using locale information. [1]

OpenClipboard can fail when another window has it open. [2] SetClipboardData transfers ownership of the supplied memory on success; memory objects must use GMEM_MOVEABLE. Opening with no owner and then emptying the clipboard can cause SetClipboardData to fail. [3]

**Recommended copy implementation:**

1. Take a consistent snapshot of the selected core text.
2. Release the core lock before clipboard access.
3. Convert selected logical line breaks to the declared clipboard form.
4. Allocate checked-size UTF-16 storage including the NUL.
5. Open using an appropriate application HWND, empty and set the format.
6. Free storage on failure; relinquish it only after successful transfer.
7. Close the clipboard on every path.

Use bounded retry/backoff for clipboard contention; do not hang the UI or hold the clipboard while waiting for I/O. If WPF's clipboard wrapper is used instead, its exception/thread requirements still need testing.

## Selection is a core-to-text operation

The inherited text buffer has copy/text extraction machinery, but selection UI and clipboard are absent from the current proof. [4]

Proposed selection semantics:

- Select logical cells, then expand endpoints to the chosen cluster boundary.
- Do not copy wide-character continuation cells as duplicate text.
- Preserve combining sequences and supplementary pairs.
- Distinguish rectangular selection from ordinary flowing selection.
- Distinguish a soft wrap from a hard newline.
- Define whether trailing blanks are retained.
- Keep selection stable or explicitly remap it during reflow.
- Copy text content, not the visible missing-glyph substitute or a font glyph ID.

**Recommendation:** use the same mapping for selection highlighting, clipboard extraction, search matches and accessibility ranges. Test it against the inherited buffer's behavior before adding independent WPF text indexing.

## Paste belongs to session input

Bracketed paste is a terminal protocol mode; when enabled, the terminal wraps pasted content with start/end markers so the application can distinguish it from typed input. It is not an unconditional framing format for every console backend. [5]

**Recommended behavior:**

1. Snapshot clipboard text and close the clipboard.
2. Resolve line-ending and embedded-control policy for the active profile.
3. Read the active terminal/backend mode.
4. Encode through the session's text encoder.
5. Queue one ordered paste operation, using bounded chunks.
6. Preserve framing/order relative to other input.
7. Permit cancellation with a documented outcome.

Do not translate a large paste into global SendInput keystrokes. The [input research](11-keyboard-and-mouse.md) explains why backend transport is the right boundary.

## Control characters and trust

**Recommendation:** make multiline-paste and embedded-control handling explicit. Bracketed paste is not a universal guarantee against execution: the receiving application/backend must support and interpret it. Test literal ESC, CR, LF, tabs, NUL and a paste terminator embedded in the payload.

Do not assume a remote application that enables clipboard-related terminal commands should have unrestricted access to the local clipboard. OSC-triggered clipboard access belongs to a separate opt-in capability with size limits, not the ordinary user Copy/Paste action. See [terminal trust boundaries](19-vt-protocol-and-security.md).

These are VT7 design recommendations; no clipboard feature was implemented by this research.

## Acceptance cases

| Operation | Check |
| --- | --- |
| Copy wrapped CJK/combining text | Exact original text, no artificial continuation cells |
| Copy supplementary characters | No unpaired surrogate at either endpoint |
| Rectangular selection | Defined spaces and row endings |
| Paste into cmd/PSReadLine/SSH editor | Correct mode, line endings and byte stream |
| Large paste while child stalls | Bounded memory and responsive cancel |
| Clipboard temporarily locked | Finite failure/retry, no leaked ownership |
| Resize or output during copy | Consistent snapshot |
| Tab switch during paste | Input remains with the intended session |

## Sources

- [1] Microsoft, [Standard Clipboard Formats](https://learn.microsoft.com/en-us/windows/win32/dataxchg/standard-clipboard-formats).
- [2] Microsoft, [OpenClipboard](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-openclipboard).
- [3] Microsoft, [SetClipboardData](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setclipboarddata).
- [4] [Text buffer](../../../src/buffer/out/textBuffer.cpp) and [proof scope](../../../src/vt7/VT7.Core/README.md).
- [5] Xterm maintainer, [Control Sequences: bracketed paste](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html).
