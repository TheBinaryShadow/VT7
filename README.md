# VT7

**The terminal application Windows 7 always deserved.**

I'm building a modern terminal for Windows 7: local shells, dependable SSH,
tabs and panes, and the text rendering people expect from Windows Terminal.
VT7 reuses Microsoft's open-source Terminal core and rendering work, with a
.NET Framework 4.8 WPF host and adaptations for Windows 7.

VT7 is an independent MIT-licensed project. It is not affiliated with or
supported by Microsoft.

## Where the project stands

VT7 is in **pre-alpha development**. Local shells, typed SSH, remote resizing,
and OpenSSH-compatible known-host management work on the tested Windows 7
machines. The interface still contains development controls and SSH dialogs.
There is no supported public release yet.

Current source is **0.16.0 / native ABI 11**. The latest candidate tests SSH
authentication and PTY startup stalls. Its local checks pass; I still need
paired client/server results from all three Windows 7 test machines.
The [development handoff](doc/vt7/HANDOFF.md) records the exact candidate,
accepted baseline, and next step.

## What I want in 1.0

- A Windows Terminal-style tab strip, **+** for the default shell, a profile
  menu, and split panes. Windows 7 without usable Aero glass gets the same
  actions below a native title bar.
- Stable **Command Prompt**, **Windows PowerShell**, and conditional
  **PowerShell** profiles. Windows PowerShell launches the installed
  `powershell.exe`; its version belongs in details, not a separate profile.
- SSH started by typing `ssh`, with trust decisions, authentication, errors,
  and cancellation inside the terminal. There will be no separate New SSH
  shortcut or ordinary connection dialog in the finished interface.
- Unicode, text rendering, and font fallback support matching the selected
  current-stable upstream Terminal reference. This includes the required
  shaping, width, fallback, color/emoji, and font-axis behavior.
- Dependable settings, search, selection, clipboard, scrollback, key bindings,
  accessibility, and session lifecycle behavior.
- A portable x64 package with clear prerequisite handling.

These are release goals, not claims that every feature is finished. The
[roadmap](ROADMAP.md) separates accepted work from the remaining requirements.
Text/font parity and the final tab/SSH workflows must be complete before polish.

## Compatibility

The target is **Windows 7 SP1 x64 with .NET Framework 4.8**, the Platform Update,
the required loader/SHA-2/runtime updates, and a working graphics path. See the
[exact prerequisites and test tiers](doc/vt7/plan/compatibility.md).

**WMF 5.1 and an installed OpenSSH client are not VT7 prerequisites.** I have
tested Command Prompt and both SSH paths on LEOPARD, which retains PowerShell
2.0. That result does not qualify its full interactive PowerShell editor corpus.
Windows PowerShell 5.1 and PowerShell 7.2.24 have their own accepted local-shell
tests; PowerShell 7.3 and newer are outside the initial compatibility promise.

Local console sessions use WinPTY 0.4.3. Embedded SSH uses a pinned SSH.NET
dependency set and carries remote terminal bytes directly. Their capabilities
are tested separately, so a renderer result does not imply that every local
console application can produce the same output.

VT7 does not require replacement system DLLs, a global compatibility layer,
ConPTY, MSIX, or the Microsoft Store. It does not restore vendor support for
Windows 7 or promise every feature of modern Windows Terminal.

## Find what you need

| I want to... | Start here |
| --- | --- |
| Follow development or resume work | [Development handoff](doc/vt7/HANDOFF.md) |
| See the plan for 1.0 | [Roadmap](ROADMAP.md) |
| Build VT7 | [Building](BUILDING.md) |
| Find a specification or test result | [Documentation index](doc/vt7/README.md) |
| Contribute or report a problem | [Contributing](CONTRIBUTING.md), [Support](SUPPORT.md) |
| Report a vulnerability privately | [Security](SECURITY.md) |
| Understand source reuse | [Upstream policy](UPSTREAM.md) |

## Acknowledgements and license

VT7 depends on years of work by the Microsoft Terminal team, WinPTY, SSH.NET,
Unifont, and the wider terminal community. I want that work to remain clearly
credited wherever VT7 uses it.

VT7-authored code uses the [MIT License](LICENSE). Included components retain
their own terms, copyright notices, and attribution. The bundled Unifont assets
use their SIL Open Font License 1.1 option. See [NOTICE.md](NOTICE.md),
[font provenance](oss/unifont/README.md), and the
[third-party licensing policy](doc/vt7/architecture/2026-09-14-third-party-licensing-policy.md).
