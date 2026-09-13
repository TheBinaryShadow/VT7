# Keyboard layouts, terminal key encoding, mouse and focus

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P0 before interactive sessions.

## Newly identified downlevel hazard

Observed in repository: both TerminalCore's key translation helper and TerminalInput::KeyboardHelper::getKeyboardKeyHelper call ToUnicodeEx with flags 0b101. Bit 2 is the “do not change keyboard state” behavior introduced in Windows 10 version 1607. [1][2]

**Inference:** the calls cannot rely on non-mutating translation on Windows 7. This can affect dead-key state even though ToUnicodeEx itself is a valid Windows 7 import. An import denylist will not catch the problem.

**Required experiment:** drive the actual inherited key path with dead keys and AltGr on Windows 7 before exposing it to users. Do not “fix” this merely by clearing bit 2: that still leaves state-mutating translation. Compare a design that receives already-translated text from the window/IME path and uses key metadata only for non-text keys. Keep full keyboard-protocol enhancements optional until their layout helpers are proven.

## Text input and key input are different

For a Unicode window, WM_CHAR carries UTF-16 units and can deliver surrogate pairs. It is produced through TranslateMessage, and there is no one-to-one relation between physical keys and character messages. [3]

ToUnicodeEx may return multiple characters or a negative dead-key result and changes keyboard state on the older path. Its input includes the active keyboard layout and modifier state. [2]

Recommended pipeline:

1. Resolve application shortcuts once.
2. Route committed text from one selected text-input owner.
3. Route non-text keys with virtual key, scan code, key state and repeat metadata.
4. Let the terminal input encoder honor the active terminal modes.
5. Serialize encoded output with paste/mouse/replies through the same session writer.

Do not independently send a printable key from WM_KEYDOWN and again from WM_CHAR. Do not assume Ctrl+Alt always means a shortcut; many layouts use AltGr for ordinary characters. Track left/right modifiers where the chosen encoder requires them.

## Reuse inherited mode logic selectively

The inherited TerminalInput tracks mouse modes, focus events, alternate-screen state, surrogate input and extended keyboard encodings. That source is already in the VT7 core project, but no interactive acceptance follows from compilation. [4]

**Recommendation:** preserve its established escape encoding where possible while auditing OS-sensitive translation helpers. Avoid a second independent table of cursor/function-key escapes in WPF.

Cursor keys, application keypad mode, Backspace/Delete, Enter, Escape, Ctrl combinations, repeats, and focus reporting require explicit tests in cmd, PSReadLine and remote TUIs. The escape stream suitable for direct SSH must also be tested against WinPTY's input translator.

## Mouse routing

Xterm documents distinct tracking modes, focus reports, and SGR mouse encoding; reporting coordinates and button releases depends on the mode negotiated by the application. [5]

WM_MOUSEWHEEL uses signed wheel deltas in units or fractions of 120, and coordinates can be negative on multi-monitor desktops. Extract signed coordinates and accumulate fractional deltas rather than discarding them. [6]

Proposed policy:

- If the application has requested mouse tracking, encode the corresponding cell event.
- Otherwise, wheel input scrolls local scrollback.
- Provide a deliberate selection override when mouse tracking is active.
- Convert screen/client pixels using the same cell transform as the renderer.
- Clamp or reject coordinates outside the terminal content rectangle.
- Track capture loss and focus changes so buttons/modifiers cannot remain stuck.

Mouse movement should not flood an unbounded write queue. Coalesce motion where permitted, preserving button transitions and mode changes.

## Cross-integrity input

SendInput is subject to UIPI and cannot inject into a higher-integrity application; its error result does not specifically identify UIPI blocking. [7]

**Recommendation:** session input belongs on the backend's transport, not global keyboard injection. Running VT7 elevated to compensate for input-routing defects would change the security model and would not establish correct per-tab behavior.

## Test matrix

US, Croatian, German and at least one non-Latin layout; dead-key composition; AltGr characters; Caps Lock/Num Lock; supplementary character input; key repeat; Ctrl+C/Ctrl+Break; Alt+key menu conflicts; focus lost while a modifier is down; mouse wheel fractions; negative desktop coordinates; and alternate-screen mouse selection.

Record both native input events and encoded bytes in a controlled non-secret test session. Assert exact bytes, not just visible echo.

## Sources

- [1] [TerminalCore translation](../../../src/cascadia/TerminalCore/Terminal.cpp) and [TerminalInput translation](../../../src/terminal/input/terminalInput.cpp).
- [2] Microsoft, [ToUnicodeEx](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-tounicodeex).
- [3] Microsoft, [WM_CHAR](https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-char).
- [4] [TerminalInput interface](../../../src/terminal/input/terminalInput.hpp) and [VT7 core source list](../../../src/vt7/VT7.Core/VT7.Core.vcxproj).
- [5] Xterm maintainer, [Control Sequences: mouse tracking and focus](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html).
- [6] Microsoft, [WM_MOUSEWHEEL](https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-mousewheel).
- [7] Microsoft, [SendInput](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput).
