# Windows 7 research for VT7

Research date: **2026-09-11**. Scope: implementation decisions for VT7's Windows 7 SP1 x64 target. This directory contains research only; it does not change the product baseline or certify an implementation.

VT7 aims to combine the inherited TerminalCore/parser/buffer with a .NET Framework 4.8 WPF host, a native terminal HWND, a downleveled Atlas renderer, WinPTY local sessions, and direct SSH. The accepted product so far is a static viewport proof; the renderer and session boundaries need further engineering. [1][2]

## Planning adoption

The [approved September 11 plan](../architecture/2026-09-11-research-driven-plan.md)
and [roadmap](../../../ROADMAP.md) now adopt the reviewed findings. They own the
current execution order: continue 2C, then finish renderer integration; run the
3A WinPTY/OpenSSH/input feasibility gate before substantial local integration
or daily-driver UI work. Text geometry, session ownership, input, accessibility,
and output-security contracts move ahead of their dependent UI features.

This is planning adoption, not runtime acceptance or dependency selection. The
original subsystem recommendations remain research, and historical priority
tables should be read with the adopted experiment mapping. The platform floor,
upstream baseline, licensing, and existing validation results are unchanged.

## Reading order

Implementation follow-up: the later
[Atlas backend validation](../validation/2026-09-11-atlas-backend-proof.md)
records Windows 7 automated passes for both Atlas backends on hardware/WARP,
visible Direct3D11 output, and repeated R-key recreation. The original research
snapshots remain research, not execution reports. This new evidence is limited
to fixed glyphs; font mapping, controller integration, and session work remain.

Start with the [project assessment](00-project-assessment.md), [API availability matrix](21-api-availability.md), and [experiment plan](20-validation-and-experiments.md). The subsystem files contain platform behavior, relevant APIs, implementation consequences, and targeted tests.

| Subsystem | Research |
| --- | --- |
| Windows baseline, loader, runtime and distribution | [01-platform-loader-runtime.md](01-platform-loader-runtime.md) |
| Legacy console, PTYs and WinPTY fidelity | [02-console-and-winpty.md](02-console-and-winpty.md) |
| Processes, jobs, pipes and cancellation | [03-process-lifecycle-and-ipc.md](03-process-lifecycle-and-ipc.md) |
| UTF-8, UTF-16 and console code pages | [04-encoding-and-streaming.md](04-encoding-and-streaming.md) |
| Graphemes, cell width, bidi and search | [05-unicode-cells-and-search.md](05-unicode-cells-and-search.md) |
| DirectWrite fallback and shaping | [06-directwrite-and-shaping.md](06-directwrite-and-shaping.md) |
| Font collections, deployment, emoji and rasterization | [07-font-assets-and-emoji.md](07-font-assets-and-emoji.md) |
| D3D11, DXGI, Direct2D and WARP | [08-graphics-and-presentation.md](08-graphics-and-presentation.md) |
| Render scheduling, synchronization and COM lifetime | [09-threading-and-renderer-lifecycle.md](09-threading-and-renderer-lifecycle.md) |
| WPF, native HWNDs, DPI and desktop composition | [10-wpf-hwnd-and-dpi.md](10-wpf-hwnd-and-dpi.md) |
| Keyboard layouts, mouse and terminal input | [11-keyboard-and-mouse.md](11-keyboard-and-mouse.md) |
| IME and Text Services Framework | [12-ime-and-text-services.md](12-ime-and-text-services.md) |
| Clipboard, selection and paste | [13-clipboard-and-selection.md](13-clipboard-and-selection.md) |
| Accessibility, themes and caret behavior | [14-accessibility-and-system-settings.md](14-accessibility-and-system-settings.md) |
| Command Prompt and PowerShell | [15-shell-compatibility.md](15-shell-compatibility.md) |
| SSH sessions and remote PTYs | [16-ssh-and-remote-pty.md](16-ssh-and-remote-pty.md) |
| Winsock, cryptography, credentials and HTTPS | [17-networking-and-cryptography.md](17-networking-and-cryptography.md) |
| Files, paths, configuration and persistence | [18-filesystem-and-settings.md](18-filesystem-and-settings.md) |
| VT protocol integration and terminal trust boundaries | [19-vt-protocol-and-security.md](19-vt-protocol-and-security.md) |
| Diagnostics and Windows 7 acceptance experiments | [20-validation-and-experiments.md](20-validation-and-experiments.md) |
| Cross-cutting API compatibility reference | [21-api-availability.md](21-api-availability.md) |
| Microsoft Win32-OpenSSH and revised SSH feasibility | [22-win32-openssh-reassessment.md](22-win32-openssh-reassessment.md) |

## Evidence conventions

- Bracketed numbers identify sources in the **same file**. Each file ends with its own bibliography.
- **Documented** means the cited platform specification or API documentation describes the behavior.
- **Observed in repository** means source or an existing validation record was inspected. Previously recorded tests were not rerun for this research.
- **Inference / recommendation** means an engineering conclusion, not an OS guarantee or implemented feature.
- **Experiment** means work still required. Proposed expected outcomes are not test results.

External sources were consulted on the research date. Microsoft Learn pages often describe several Windows generations together: the existence of an API does not imply that every flag, interface extension, or behavior on that page exists on Windows 7. A successful QueryInterface also does not prove that every method works on the downlevel implementation. [3]

Unicode specifications and dependency master branches are moving references. Pin the exact data, source revision, binaries, and fonts when implementing a decision. This research deliberately separates the application's Unicode tables, the OS shaping engine, the installed fonts, and the backend transport.

The most consequential finding is the distinction between **renderer capability** and **end-to-end session capability**. WinPTY polls a legacy console and reconstructs a terminal stream; direct SSH supplies a different path. A common renderer cannot recover information already lost upstream. See the WinPTY analysis for the evidence and qualifications. [4]

## Sources

- [1] [VT7 goals](../../../README.md), working tree inspected 2026-09-11.
- [2] [VT7 roadmap](../../../ROADMAP.md), working tree inspected 2026-09-11.
- [3] Microsoft, [Platform Update for Windows 7](https://learn.microsoft.com/en-us/windows/win32/direct3darticles/platform-update-for-windows-7).
- [4] WinPTY project, [architecture and supported systems](https://github.com/rprichard/winpty).
