# Command Prompt, Windows PowerShell and PowerShell 7

Research date: 2026-09-11. Priority: P0 for local-session acceptance.

## Product target versus vendor lifecycle

VT7 targets cmd, Windows PowerShell 5.1, and PowerShell 7.0 through 7.2.24, with 7.2.24 the main PowerShell 7 acceptance target. These are project compatibility goals, not a statement of current Microsoft support. [1]

WMF 5.1 is available for Windows 7 SP1 through the official package, including the x64 KB3191566 archive. [2] A stock Windows 7 installation does not imply the required shell/module versions are installed.

PowerShell 7.2 uses .NET 6, while 7.3 uses .NET 7. [3] The official 7.2.24 release is dated 2024-10-22 and records a .NET SDK/dependency update. [4] Use the exact selected release and bundled runtime inventory rather than an unversioned pwsh.exe on PATH.

Microsoft's historical .NET installation requirements list Windows 7 loader prerequisite KB3063858. Verify it or an applicable superseding update as a **shell prerequisite**, separately from VT7's .NET Framework host. [5]

## Detect and launch deliberately

Proposed profile metadata:

- Resolved executable path and architecture.
- Version, edition and bundled runtime where applicable.
- Working directory and explicit environment overlay.
- Startup arguments and whether user profiles are enabled.
- Console input/output code pages.
- PSReadLine version, edit mode and prediction configuration.
- Backend and tested capability profile.

Use a clean-profile baseline for diagnosis, followed by the normal profile configuration. Do not silently change user profiles, execution policy, global console defaults or installed modules to make a test pass.

cmd, powershell.exe and pwsh.exe parse arguments differently. A profile command line should not be repackaged through cmd /c unless that shell interpretation is intentional. Include executable paths with spaces and non-ASCII working directories in acceptance.

## Four encoding layers in PowerShell

Windows PowerShell 5.1 file-output defaults vary by cmdlet; Out-File/redirection commonly use UTF-16LE, while other paths use different defaults. PowerShell 6+ generally uses UTF-8 without BOM. Windows PowerShell can misread a non-ASCII UTF-8 script without a BOM as the legacy ANSI code page. [6]

**Recommendation:** distinguish:

1. Script-file decoding.
2. Console input/output encoding.
3. Native-process pipeline encoding, including OutputEncoding.
4. VT7's backend stream decoder.

A correct terminal display cannot repair a script already decoded incorrectly or a pipeline already converted to a lossy code page. Test bytes written to files separately from visible console output.

## PSReadLine is the practical compatibility gate

PSReadLine supplies interactive editing facilities and has its own versioned behavior and requirements. [7] Merely seeing a PowerShell prompt does not validate its cursor placement, redraw, completion or key handling.

Proposed acceptance suite:

| Area | Cases |
| --- | --- |
| Editing | Left/right, word motion, Home/End, insert/delete, multiline editing |
| History | Up/down, incremental search, non-ASCII history |
| Completion | Tab completion, menus, long paths and spaces |
| Prediction | Inline/list display if supported by the selected module |
| Width | Combining text, CJK, emoji, long prompt and continuation prompt |
| Resize | Shrink/grow while editing and while completion is visible |
| Interrupts | Ctrl+C at idle, during command, during a native child |
| Paste | Multiline input, tabs, long paste and bracketed mode behavior |
| Native children | Console API applications, redirected children, full-screen tools |
| Shutdown | Exit, crash, restart, close while output remains |

Capture both the child console state and VT7's terminal stream when a redraw fails. This separates PSReadLine's width assumptions, legacy console limitations, WinPTY reconstruction and the renderer.

## Reporting capability honestly

The host can support true-color VT rendering while a Windows 7 local application/console path still cannot deliver equivalent data. Do not enable modern terminal-detection environment variables solely to make a shell emit features the backend cannot transport. See [WinPTY fidelity](02-console-and-winpty.md).

A terminal type, TERM/COLORTERM value, or shell feature flag is a behavioral promise to applications. Start with an explicit tested profile and expand it when end-to-end acceptance succeeds.

## Sources

- [1] [VT7 shell target and acceptance criteria](../../../ROADMAP.md).
- [2] Microsoft, [Windows Management Framework 5.1 download](https://www.microsoft.com/en-us/download/details.aspx?id=54616).
- [3] Microsoft, [PowerShell support lifecycle and runtime mapping](https://learn.microsoft.com/en-us/powershell/scripting/install/powershell-support-lifecycle).
- [4] PowerShell project, [7.2.24 release](https://github.com/PowerShell/PowerShell/releases/tag/v7.2.24).
- [5] Microsoft, [Historical .NET Windows 7 prerequisites](https://learn.microsoft.com/en-us/dotnet/core/install/windows#windows-7--81--server-2012).
- [6] Microsoft, [about_Character_Encoding, including Windows PowerShell distinctions](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.6).
- [7] PowerShell project, [PSReadLine source and documentation](https://github.com/PowerShell/PSReadLine).
