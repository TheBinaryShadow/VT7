# Accessibility, high contrast, caret and system settings

Research date: 2026-09-11. Priority: P1.

## A drawn terminal needs a text provider

Windows UI Automation custom controls expose provider interfaces; the simplest window-hosted provider starts with IRawElementProviderSimple, with fragment interfaces for a more complex tree. [1] Text and TextRange patterns expose text, selections, visible ranges and text attributes. [2]

**Recommendation:** expose the terminal through a real text model derived from the buffer, not one accessibility element per glyph or a screenshot description. WPF's accessible tab controls do not automatically expose the native terminal's content.

ITextProvider is a suitable historical baseline to investigate. ITextProvider2 has a Windows 8 minimum, so current guidance that discusses both interfaces must be read with that distinction. [3][4]

Audit every modern UIA helper imported from upstream. A newer convenience notification function must not become a mandatory import just because the older core provider interfaces are available.

## Proposed accessible model

| Element | Information |
| --- | --- |
| Terminal pane | Stable name, role, focus, bounds and active session |
| Text provider | Document/visible ranges and selection |
| Text range | Original text, movement units, attributes and rectangles |
| Focus/selection changes | Meaningful, bounded notifications |
| Closed pane | Detached provider with no dangling native state |

Proposed semantics:

- Use original logical text, preserving wide/combining characters.
- Convert core ranges to visible screen rectangles through the renderer's current geometry.
- Keep ranges coherent when scrollback is pruned or the terminal reflows.
- Return a consistent snapshot without holding the renderer lock through a client callback.
- Coalesce rapid output notifications so assistive technology is usable during sustained output.
- Distinguish an inaccessible operation from an empty selection.

The current inherited UIA code may provide useful algorithms, but its modern platform and application dependencies need a separate source/import audit before reuse.

## High contrast and themes

SystemParametersInfo with SPI_GETHIGHCONTRAST reports the user's high-contrast setting. Microsoft recommends system color pairs and omitting distracting backgrounds when enabled, and calls out system-color-change handling. [5]

**Recommendation:** use paired foreground/background resources for host controls and a deliberate terminal high-contrast policy. A hard-coded attractive palette is insufficient. Decide whether to override application colors or preserve them with a user-selected mode; document that choice.

Refresh relevant state on theme/system-color/settings changes and on focus/activation where appropriate. Test while the application is already open, not only after restart.

The 0.2.1 proof fixes a real host contrast defect and validates effective brushes, but the record explicitly excludes full accessibility and pixel-level acceptance. [6]

## Caret behavior and a hidden compatibility assumption

GetCaretBlinkTime returns milliseconds; INFINITE indicates no blink and zero indicates failure. [7]

Observed in repository: Terminal::GetBlinkInterval additionally reads GetSystemMetrics(SM_CARETBLINKINGENABLED). [8] This metric must be investigated on Windows 7; the import GetSystemMetrics alone is not sufficient evidence for support of every metric value.

**Recommendation:** build a Windows 7 caret policy from documented behavior and captured settings, with an explicit non-blinking result. Avoid resetting a timer continuously when blink is disabled. Do not treat an unsupported metric returning zero as a proven user preference.

## Keyboard-only operation

Every tab, pane, menu and settings/error dialog needs reachable focus and a visible indicator. The terminal must provide a deliberate way to leave shell input and navigate application chrome. Screen-reader navigation must not inadvertently inject commands into the session.

Test:

- Tab/arrow navigation and focus restoration after dialogs.
- High-contrast changes while running.
- Screen-reader reading of output, current selection and pane names.
- Scrollback changes while a UIA client retains a range.
- Zoom/system DPI changes and bounds.
- Provider calls during close and concurrent output.
- No-blink caret preference.

Record exact assistive-technology versions that run on the Windows 7 test image. A modern screen reader on the development OS cannot substitute for this acceptance.

## Sources

- [1] Microsoft, [Server-side UI Automation providers](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-serversideprovider).
- [2] Microsoft, [Text and TextRange patterns](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-implementingtextandtextrange).
- [3] Microsoft, [ITextProvider](https://learn.microsoft.com/en-us/windows/win32/api/uiautomationcore/nn-uiautomationcore-itextprovider).
- [4] Microsoft, [ITextProvider2 requirements](https://learn.microsoft.com/en-us/windows/win32/api/uiautomationcore/nn-uiautomationcore-itextprovider2).
- [5] Microsoft, [High contrast parameter](https://learn.microsoft.com/en-us/windows/win32/winauto/high-contrast-parameter).
- [6] [Contrast/focus cleanup validation](../validation/2026-09-10-milestone-1-cleanup.md).
- [7] Microsoft, [GetCaretBlinkTime](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getcaretblinktime).
- [8] [Terminal render data / blink interval](../../../src/cascadia/TerminalCore/terminalrenderdata.cpp).
