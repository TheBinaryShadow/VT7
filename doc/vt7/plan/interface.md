# Milestone 4: Daily-driver interface

[Roadmap](../../../ROADMAP.md) | [Documentation](../README.md)

These are the detailed requirements and recorded results for this milestone.
An accepted slice does not close an unchecked parent requirement.

## Milestone 4: Daily-driver interface

- [ ] **UI01: real session tabs before cosmetic polish.** Give each tab its own
  document, local root, optional SSH overlay, input generation and lifecycle.
  Place tab title/icon/close controls in a Windows Terminal-like title strip,
  with **+** opening the default profile and an adjacent arrow listing detected
  profiles and shortcuts. Preserve native caption controls and drag/resize/
  maximize/system-menu behavior. On Windows 7 without usable Aero glass, keep
  the same tab actions below a standard native title bar. The proof host's
  viewport/Diagnostics tabs do not satisfy this gate. Follow the
  [pre-1.0 UI and SSH contract](../architecture/2026-09-25-pre-1-0-ui-and-terminal-ssh-contract.md).
- [ ] Horizontal/vertical split panes within real session tabs, keeping session
  lifetime separate from transient WPF layout and respecting native HWND
  airspace. Search chrome and splitters must not rely on ordinary WPF overlays
  over the terminal.
- [ ] Use stable built-in menu labels: **Command Prompt**,
  **Windows PowerShell** for the installed `powershell.exe` (2.0 or 5.1), and
  **PowerShell** only when a compatible `pwsh.exe` is discovered. Show actual
  versions and preview status in details/diagnostics; do not duplicate a
  Windows PowerShell profile for each version or imply that the still
  unqualified PowerShell 2.0 editor has passed the 5.1 corpus. Detect missing
  executables and preserve stable saved profile identities across upgrades.
- [ ] Profile creation/editing with explicit backend and executable selection,
  capabilities, and runtime requirements.
- [ ] Versioned UTF-8 JSON settings with validation, last-known-good recovery,
  recoverable replacement, concurrent-save handling, and explicit portable-mode
  behavior on Unicode/read-only paths (D01).
- [ ] Search, selection, copy, paste, and scrollback using the shared cell/text
  model. Decide literal/regex, case-folding, normalization, soft-wrap, and offset
  semantics before restoring search. Audit any selected dependency such as ICU;
  preserve original text and do not hold the core lock during long searches.
- [ ] Test cluster-safe selection/copy, reflow, clipboard contention, multiline
  and bounded/cancelable paste, and the separate OSC clipboard policy (C01).
- [ ] Configurable key bindings.
- [ ] Color schemes, fonts, cursor styles, and background settings.
- [ ] Session titles, activity indication, and close confirmation.
- [ ] Keyboard-only operation, visible focus, and a practical Windows 7
  accessibility baseline: native terminal text/ranges, selection and bounds,
  bounded notifications, and safe provider lifetime (A01). Accessible host
  controls alone do not satisfy terminal accessibility.
- [ ] Validate a Windows 7-compatible screen reader, live high-contrast/settings
  changes, no-blink caret preference, system-DPI geometry, and input focus during
  dialogs, pane switching, and active composition.

Exit criterion: the primary workflows no longer require a developer harness or
manual configuration edits, and the tab strip represents independent sessions
on the qualified Windows 7 window styles.

