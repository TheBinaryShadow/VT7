# VT7

## The terminal application Windows 7 always deserved.

Windows 7 got so much right. It was quick, focused, familiar, and built around
the person sitting in front of the computer. For many of us it was more than an
operating system. It was the place where we learned, built, repaired, played,
and got real work done.

Its terminal experience never received the same care.

VT7 exists to finish that story.

Our goal is to build a modern, fast, beautiful terminal for Windows 7, with the
features people now expect from a serious command-line environment. Tabs,
panes, profiles, excellent text rendering, rich color, dependable resizing,
local shells, and first-class SSH should feel at home on Windows 7 instead of
feeling borrowed from another era.

This is not a skin, a repackaged binary, or a nostalgia mock-up. VT7 is an
independent open-source engineering effort to create a real terminal
application for Windows 7.

> [!IMPORTANT]
> VT7 is currently in pre-alpha development. The repository does not yet
> produce a usable Windows 7 terminal. Features described here are project
> goals until they are implemented and verified on Windows 7 hardware.

## What we are building

VT7 is planned as a standalone x64 desktop application for Windows 7 SP1. It
will reuse the strongest portable parts of Microsoft's open-source Terminal,
including its terminal core, VT parser, text buffer, and rendering work, while
replacing dependencies that require newer versions of Windows.

The first complete release is intended to provide:

- Tabs and split panes.
- Profiles for local shells and remote connections.
- Command Prompt and Windows PowerShell 5.1 sessions.
- PowerShell 7.0 through 7.2.24 sessions.
- SSH sessions with proper remote PTY creation and resize handling.
- Unicode, wide characters, combining characters, box drawing, and emoji where
  the selected font and Windows 7 can support them.
- 16-color, 256-color, and true-color terminal output.
- Mouse input, bracketed paste, alternate screen buffers, and modern VT
  sequences.
- Search, selection, copy, paste, scrollback, and configurable key bindings.
- GPU-accelerated rendering through the Windows 7 Direct3D 11 stack, with a
  software-rendering fallback where practical.
- Portable distribution without MSIX or Microsoft Store dependencies.

## The current direction

The design is still being proven, but the working direction is:

- Microsoft Terminal's MIT-licensed TerminalCore and parser for terminal state
  and VT behavior.
- A Windows 7-compatible desktop host, currently expected to use WPF with a
  native HWND terminal surface.
- A downleveled Atlas renderer that uses the DirectX capabilities available
  through the Windows 7 Platform Update.
- A WinPTY-based local session backend because Windows 7 does not provide
  ConPTY.
- A direct SSH backend for correct authentication, host-key handling, remote
  PTY allocation, and resize messages.
- A portable application package that can be extracted and run without modern
  Windows deployment infrastructure.

These are engineering choices, not articles of faith. We will keep what proves
reliable on Windows 7 and change what does not.

## Compatibility target

The primary target is Windows 7 SP1 x64 with the Platform Update and the normal
runtime prerequisites documented in the [roadmap](ROADMAP.md). The required
baseline will not depend on unofficial post-EOL operating-system packages.

We also intend to test systems that have later Windows Server 2008 R2-derived
NT 6.1 updates. Those systems are an additional compatibility tier, not the
minimum requirement and not an officially supported Windows 7 update path.

Planned shell coverage:

| Shell or session | VT7 goal |
| --- | --- |
| Command Prompt | First-class local support |
| Windows PowerShell 5.1 | First-class local support |
| PowerShell 7.0 to 7.2.24 | First-class local support |
| Native Windows console applications | Support through the local PTY backend |
| SSH | First-class remote support |

PowerShell 7.3 and newer depend on .NET versions that dropped Windows 7. They
are outside the initial compatibility promise.

## What VT7 is not

- VT7 is not affiliated with, endorsed by, or supported by Microsoft.
- VT7 is not a promise of exact feature parity with current Windows Terminal.
- VT7 is not a replacement for the Windows console host inside the operating
  system.
- VT7 will not add ConPTY or other missing operating-system services to Windows
  7.
- VT7 does not make an unsupported operating system secure or supported again.
- VT7 will not require users to replace system DLLs or install a global
  compatibility layer.

The aim is not to drag every modern Windows feature backward. The aim is to
build the best terminal we can for the platform we love.

## Project status

- [x] Establish the VT7 project identity and scope.
- [x] Select and record the Microsoft Terminal upstream baseline.
- [x] Research the Windows 7 WPF, renderer, API, PTY, and SSH paths.
- [ ] Produce a reproducible developer build for the first VT7 executable.
- [ ] Open a static terminal viewport on Windows 7 SP1 x64.
- [ ] Render correctly through Direct3D 11 and the software fallback.
- [ ] Run an interactive local shell through the Windows 7 PTY backend.
- [ ] Complete the first direct SSH session.
- [ ] Add the daily-driver interface, including tabs, panes, profiles, and
  settings.
- [ ] Publish the first alpha build.

There are no official VT7 binaries yet. Please be careful with downloads that
claim otherwise.

## Project documents

- [Roadmap](ROADMAP.md) - milestones, requirements, acceptance criteria, and
  non-goals.
- [Upstream](UPSTREAM.md) - source baseline, divergence policy, and upstream
  synchronization.
- [Contributing](CONTRIBUTING.md) - how to help and the standards we follow.
- [Support](SUPPORT.md) - where to ask questions and report problems.
- [Security](SECURITY.md) - how to report a vulnerability privately.

## Acknowledgements

VT7 stands on years of open-source work by the Microsoft Terminal team and its
contributors. Keeping that history and attribution intact matters to us.

WinPTY and the wider terminal community have already solved many hard problems
that make this project possible. We intend to be good neighbors and careful
students of that work.

## License

VT7 is licensed under the [MIT License](LICENSE). The repository retains the
copyright and license notices of Microsoft Terminal and other included
open-source components. New VT7 contributions are made under the same MIT
License unless a file clearly states otherwise.

## One last thing

Windows 7 still matters because its users still matter.

If VT7 can make one old workstation more useful, one administrator's day less
frustrating, one developer's tools more pleasant, or one much-loved computer
feel capable again, this project will have done something worthwhile.

Let's give Windows 7 the terminal it always deserved.
