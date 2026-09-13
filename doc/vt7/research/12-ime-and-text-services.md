# IME composition and Text Services Framework

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P1; important for Chinese, Japanese, Korean and other composed input.

## Why a terminal needs an explicit design

VT7 currently displays a native child HWND but has no keyboard/IME forwarding. [1] A custom-drawn terminal is not automatically an editable WPF text control.

Windows 7 has both the Input Method Manager APIs and Text Services Framework (TSF). TSF is a COM-based framework for text services and is applicable from Windows XP onward. [2]

**Recommendation:** choose one authoritative owner of committed text and composition state per active pane. Decide early whether the first implementation uses a native IMM path or a deliberately designed TSF text store. A hidden WPF TextBox may assist a prototype, but it does not solve focus, candidate placement, airspace or duplicate events by itself.

## IMM behavior

WM_IME_COMPOSITION indicates changes to composition/result state. If no GCS flags are set, composition has been canceled. An application rendering preedit itself handles the message; otherwise the default IME window can handle presentation. [3]

ImmGetCompositionStringW uses **byte counts**, even for Unicode text. Query the required size, allocate accordingly, then fetch and interpret the resulting UTF-16 units. The returned size excludes a terminating NUL. [4]

ImmSetCandidateWindow sets candidate-window information for the input context. [5]

Proposed IMM flow:

1. Track composition start/end and active pane/input context.
2. On GCS_COMPSTR, update local preedit only.
3. On GCS_RESULTSTR, obtain the committed text and send it exactly once.
4. Render or delegate preedit according to the chosen mode.
5. Position composition/candidate UI at the terminal cursor using native client coordinates.
6. Release the acquired input context after use.
7. Cancel/finish composition deliberately on tab switch, close, focus loss and session restart.

Do not send tentative composition updates to the shell as commands. Do not forward both a handled result string and the character messages generated for that same result. Define the exact DefWindowProc/message-handling path to prevent duplication.

## TSF alternative

ITextStoreACP exposes application text through character positions and provides text, selection, geometry and notification methods. [6] RequestLock/OnLockGranted has a specific synchronous/asynchronous locking protocol. It is not a request to acquire the terminal's normal mutex blindly. [7]

**Design questions for a terminal text store:**

- Does the store expose only local composition, the current input region, or terminal scrollback?
- How does ACP UTF-16 indexing map to clusters and terminal cells?
- How are selection and caret bounds reported when the screen scrolls?
- How are pending edit sessions handled during reentrant layout/input callbacks?
- Which mutations are valid when the remote application, rather than the local widget, owns line editing?

**Recommendation:** treat TSF as a scoped text-input adapter, not permission for a text service to edit arbitrary historical terminal output. Preserve the application/PTY's authority over shell editing.

## Geometry and lifetime risks

Candidate placement must track pane movement, grid changes, system DPI, scroll position and caret movement. WPF's logical coordinates and native client pixels must not be mixed. A candidate list appearing at the top-left corner may indicate a coordinate/input-context defect rather than a font defect.

Keep input contexts, TSF document/context objects, event sinks and managed delegates alive for the exact registered period. Detach sinks before destroying the HWND. Never hold the core render lock while calling an external text-service component.

These are design recommendations based on the API contracts, not tested VT7 behavior.

## Acceptance corpus

Use Windows 7-compatible installed IMEs and record their names/versions:

| Scenario | Required observation |
| --- | --- |
| Japanese conversion and candidate cycling | Preedit local; selected result sent once |
| Chinese multi-character composition | Complete committed string and correct placement |
| Korean syllable composition/backspace | No duplicate partial syllables |
| Cancel composition with Escape | No unintended shell input |
| Switch pane/tab during composition | Defined cancellation/transfer; no stale candidate window |
| Resize while candidate list is visible | Geometry follows caret |
| Close session during composition | No callbacks to destroyed HWND |
| Non-ASCII/supplementary commit | Correct UTF-16/UTF-8 boundaries |

Test both direct SSH and WinPTY; success in one does not prove the other backend's input translation.

## Sources

- [1] [Current proof scope](../../../src/vt7/VT7.Core/README.md) and [native surface](../../../src/vt7/VT7.Native/surface.cpp).
- [2] Microsoft, [Text Services Framework](https://learn.microsoft.com/en-us/windows/win32/tsf/text-services-framework).
- [3] Microsoft, [WM_IME_COMPOSITION](https://learn.microsoft.com/en-us/windows/win32/intl/wm-ime-composition).
- [4] Microsoft, [ImmGetCompositionStringW](https://learn.microsoft.com/en-us/windows/win32/api/imm/nf-imm-immgetcompositionstringw).
- [5] Microsoft, [ImmSetCandidateWindow](https://learn.microsoft.com/en-us/windows/win32/api/imm/nf-imm-immsetcandidatewindow).
- [6] Microsoft, [ITextStoreACP](https://learn.microsoft.com/en-us/windows/win32/api/textstor/nn-textstor-itextstoreacp).
- [7] Microsoft, [ITextStoreACP::RequestLock](https://learn.microsoft.com/en-us/windows/win32/api/textstor/nf-textstor-itextstoreacp-requestlock).
