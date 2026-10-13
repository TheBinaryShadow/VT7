# Pre-1.0 window, profile, and terminal SSH contract

Decision date: 2026-09-25. Status: approved product direction and researched
implementation constraints; implementation and Windows 7 acceptance are pending.
The [roadmap](../../../ROADMAP.md) owns the required Milestone 4 UI01 and
Milestone 5 SSHUX01 gates. KH01.5 remains the next known-host validation task.
This document defines the intended finished experience, not a claim about the
current proof host.

## Product behavior

The VT7 window should follow the familiar Windows Terminal interaction model
within Windows 7's capabilities. Each tab owns a real local terminal session;
the tab shows its profile icon, current title and close control. The **+** button
opens the configured default profile in a new tab. Its adjacent arrow opens a
menu of available profiles, with icons and keyboard shortcuts. Settings,
Command palette and About can occupy separate menu entries when those features
exist. Empty strip space drags the window and supports the normal caption
behaviors. The native minimize, maximize and close controls remain usable.
Split panes belong inside a tab and must not change the meaning of a tab as an
independent session container. Opening, switching, closing or resizing tabs must
not silently replace or terminate another tab's session. The present
**Terminal viewport**/**Diagnostics** proof tabs are not session tabs.
Tab creation, selection, close and profile choice need discoverable keyboard
paths; using the menu must restore input focus to the chosen native viewport.

The built-in shell choices use stable, recognizable labels:

| Menu label | Executable and discovery rule | Version information |
| --- | --- | --- |
| **Command Prompt** | The installed `cmd.exe` | Shown in details if useful. |
| **Windows PowerShell** | The installed Windows `powershell.exe`, whether 2.0 or 5.1 | Actual detected version in details/diagnostics, without renaming the menu item. |
| **PowerShell** | A discovered compatible `pwsh.exe`; absent when none is installed | Actual version, installation path and preview status in details/diagnostics. A preview build must not be presented as a stable release. |

The user selects a profile, not a hard-coded Windows PowerShell version. VT7
must re-evaluate availability safely at startup and when profiles are refreshed;
one machine may expose only Command Prompt and Windows PowerShell. A detected
PowerShell 2.0 entry does not imply that its interactive editing is qualified:
the [pre-WMF validation record](../validation/2026-09-24-pre-wmf51-windows7.md)
still limits that claim. PowerShell 5.1 and 7.2.24 retain their existing tested
scope. Profile IDs and saved default-profile references should survive a version
upgrade; missing executables must have a clear fallback or actionable error.

There is no SSH profile, **Start SSH...** button or **New SSH** shortcut in the
finished UI. From Command Prompt, Windows PowerShell or PowerShell, the user
types `ssh` at the local prompt. VT7's bundled shim and SSH.NET handoff must make
eligible typed commands work even on a machine without system OpenSSH. The
remote session occupies the originating tab's terminal view. On `exit`, clean
disconnect, cancellation or failure, control and the appropriate status return
to that tab's original local shell. Unsupported syntax must either use the
documented external-client fallback when available or fail clearly in that
terminal; it must not be silently reinterpreted.
The current embedded parser deliberately supports a bounded OpenSSH-like
grammar, including `user@host`, `-l`, `-p` and `-i`. SSHUX01 must map these
arguments into the terminal interaction without a connection form: explicit
identity paths take precedence; otherwise VT7 discovers supported default
identities or asks for a path/authentication method inside the terminal when
needed. The exact default-identity order and any additional `ssh_config`/agent
coverage must be specified and tested in Milestone 5. Neither installed
OpenSSH nor a preconfigured SSH profile is a prerequisite for the supported
typed path.

All SSH interaction appears **inside the terminal**, without a separate WPF or
OS dialog: first-contact trust, changed-key warning and recovery, key selection
when needed, password/passphrase or keyboard-interactive input where supported,
progress, cancellation and errors. A previously trusted matching key connects
without a repeated trust question. Unknown keys require a deliberate decision;
changed, revoked, unreadable or unsupported trust states retain the fail-closed
policy. The existing OpenSSH-compatible `known_hosts` files and safe `.old`
recovery contract remain authoritative. The current connection, trust and
management dialogs are temporary proof UI.

## Engineering boundary

Microsoft documents that WPF `WindowChrome` can extend content into the caption
while preserving its resize border, dragging, double-click maximize and system
menu. Interactive tabs and buttons in the caption need
`IsHitTestVisibleInChrome`; glass-frame sizing must leave room for the system
caption buttons. Aero composition can be unavailable on Windows 7, and
Microsoft recommends an alternate style then. UI01 should use a title-area tab
strip when the native chrome is sound, and a standard native title bar with the
same tab strip immediately below it when glass/composition is unavailable.
Both layouts provide the same tab and menu actions. Do not make custom-drawn
minimize/maximize/close buttons the only fallback. Test maximized taskbar bounds,
system menu, resize hit regions, theme changes, high contrast and DPI on real
Windows 7 machines. This is a design recommendation to validate in UI01, not a
claim of target acceptance. [WindowChrome](https://learn.microsoft.com/en-us/dotnet/api/system.windows.shell.windowchrome?view=netframework-4.8.1)
and [glass-frame behavior](https://learn.microsoft.com/en-us/dotnet/api/system.windows.shell.windowchrome.glassframethickness?view=netframework-4.8.1)
are the platform references.

The native terminal viewport is an `HwndHost`. WPF and Win32 have an airspace
boundary, so ordinary WPF content must not be assumed to overlay the viewport;
the tab strip belongs outside it. Test menu popup placement, mouse hit testing,
keyboard focus and IME transfer at that boundary. Microsoft notes that menus
and other popups use separate top-level windows, which makes them plausible
for the profile menu, but their target behavior still needs verification.
[WPF and Win32 interoperation](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/wpf-and-win32-interoperation)
is the platform reference.

The 3A document/session/view split already makes a session independent of a
particular viewport. The current `MainWindow`, however, owns only one active
document, root session and SSH overlay coordinator. UI01 must introduce real
per-tab ownership of the document, local root, optional remote overlay, input
generation, title and lifecycle before the title strip can represent sessions.
Hidden tabs continue bounded output draining; switching attachment must not
lose output, cross-wire input or issue a resize to the wrong transport. Closing
one tab must cancel only its work and dispose its resources. SSH prompts and
completion are bound to the originating tab and session generation, even if
another tab becomes active while a connection is pending.

SSHUX01 moves *presentation* from WPF dialogs to a VT7-owned terminal prompt
state. Trust and authentication decisions still originate from structured SSH.NET
and known-host results, never by parsing remote text or a localized shell
message. Prompt input is captured exclusively for the pending decision, cannot
reach the local shell or remote process, and is abandoned on cancellation,
disconnect, tab close or generation change. A terminal-area prompt region or
native/TerminalCore prompt layer is acceptable if it stays within the terminal
experience; a WPF overlay drawn over `HwndHost` is not a sound assumption.
Trusted-key verification precedes authentication. Secret input must not echo,
enter terminal scrollback, clipboard history, default diagnostics or logs, and
must be released after the attempt. Host provenance must remain apparent to the
user so remote output cannot masquerade as an actionable VT7 trust prompt.
Changed-key recovery can present the existing relevant-record selection and
two-step removal within this host-owned prompt flow; it must preserve the
current fail-closed and verified-backup rules.

The intended interaction follows Windows Terminal's `+` and adjacent profile
menu, and OpenSSH's in-terminal host-key experience. These are behavior
references, not new dependencies or a promise of complete feature parity.
[Windows Terminal tab/profile behavior](https://learn.microsoft.com/en-us/windows/terminal/install),
[PowerShell executable distinction](https://learn.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell?view=powershell-7.5),
and [OpenSSH host-key interaction](https://man.openbsd.org/ssh.1)
are the upstream references. No new third-party code or license is selected by
this specification.

## Gates and verification

1. **UI01, Milestone 4:** build real session tabs and the `+`/profile menu;
   make shell labels and conditional discovery stable; qualify caption and
   fallback layouts, per-tab lifecycle, keyboard shortcuts, focus and
   accessibility on Windows 7.
   Keep Diagnostics available through an appropriate developer/diagnostic path,
   rather than as a fake session tab.
2. **SSHUX01, Milestone 5:** retain the accepted shim, SSH.NET transport and
   known-host security rules while replacing every ordinary SSH WPF dialog and
   button with in-terminal interaction in the originating tab. Qualify typed
   `ssh` from every supported local shell, with and without installed OpenSSH,
   and test unknown/matching/changed/revoked/unreadable trust, each supported
   authentication method, retry/cancel, remote exit and status return.
3. **Milestone 6:** run assembled-product checks with multiple active and hidden
   tabs, pending SSH prompts during tab switching/close, heavy output,
   `htop`/`nano`/full-screen applications, theme/composition changes,
   96/120/144-DPI layouts, high contrast, screen reader and keyboard-only use.
   Recheck secret/log privacy and tab-isolation failures. These are real target
   checks, not documentation-only acceptance.

UI01 and SSHUX01 are required before Milestone 7's optional polish triage and
before 1.0 acceptance. KH01.5 and other current Milestone 5 transport/security
work may proceed before the UI migration. Pixel-perfect reproduction of every
Windows Terminal feature, full OpenSSH command/config coverage and Windows 10+
visual effects are outside this contract; deviations in a *supported* workflow
must be documented and tested rather than hidden by a proof-window fallback.
