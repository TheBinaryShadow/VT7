# VT7

## The terminal application Windows 7 always deserved.

Windows 7 got so much right. It was quick, focused, familiar, and built around
the person sitting in front of the computer. For many of us it was more than an
operating system. It was the soul of where we learned, built, repaired, played,
and got work done.

It's terminal experience never received the same care.

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

VT7 is planned as a standalone x64 desktop application for Windows 7. It
will reuse the strongest portable parts of Microsoft's open-source Terminal,
including its terminal core, VT parser, text buffer, and rendering work, while
replacing dependencies that require newer versions of Windows.

The first complete release is intended to provide:

- Tabs and split panes.
- Profiles for local shells and remote connections.
- Command Prompt and Windows PowerShell 5.1 sessions.
- PowerShell 7 sessions, up to version 7.2.24.
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

Rich color and Unicode are core/renderer goals and end-to-end direct SSH goals.
Local Windows console sessions travel through a different path, whose usability
and compatiblity must be assessed. We will publish tested backend capabilities
rather than promise that every application can deliver everything the renderer
can draw. Missing font coverage must not corrupt the original text. Color emoji,
variable font axes, and full bidirectional terminal behavior need separate scope
decisions.

## The current direction

Our immediate priority is a working application port: bring the proven upstream
terminal behavior to Windows 7, adapting the parts that depend on newer Windows
features, system APIs, and similar.
We do not need to redesign terminal typography before people can use VT7.

Our longer-term ambition stays high. Better text rendering, thoughtful finishing
touches and ideas discovered along the way belong in the roadmap's final
**Polish and release readiness** milestone. We will review them before release,
complete a bounded selection, and explicitly carry optional work forward when
needed. Security, stability and required workflows are not polish. A useful terminal
first, then deliberate improvements, with care throughout.

The design is still being proven, but the working direction is:

- Microsoft Terminal's MIT-licensed TerminalCore and parser for terminal state
  and VT behavior.
- A .NET Framework 4.8 WPF desktop host with a native HWND terminal surface.
- A downleveled Atlas renderer that uses the DirectX capabilities available
  through the Windows 7 Platform Update.
- WinPTY as the first local session backend candidate, with console fidelity
  tested before committing to its integration behind a replaceable boundary.
- A direct SSH backend for correct authentication, host-key handling, remote
  PTY allocation, and resize messages. Evaluate Microsoft Win32-OpenSSH first,
  including an external-process path that preserves remote terminal bytes.
  The integration and shipping dependency have not yet been selected.
- A portable application package that can be extracted and run without modern
  Windows deployment infrastructure. (With a setup file to follow after the first
  full release)

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
| PowerShell 7 up-to version 7.2.24 | First-class local support |
| Native Windows console applications | Support through the local PTY backend |
| SSH | First-class remote support |

PowerShell 7.3 and newer depend on .NET versions that dropped Windows 7 support.
They are outside of the initial compatibility promise.

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

Engineering build **0.3.0** now connects TerminalCore to the real AtlasEngine and
renderer controller, with a minimum Windows 7 font adapter. Debug and Release
tests pass locally through Direct3D11 and Direct2D, on hardware and forced WARP;
GDI remains a selectable reference. The supplied Windows 7 run now passes C1/C2 on the tested configuration.
See the [Atlas viewport record](doc/vt7/validation/2026-09-12-atlas-viewport.md).
This is a static viewport, not yet an interactive terminal or a closed Milestone 2.

Engineering build **0.3.1** passes the supplied Windows 7 differential repaint,
cursor-cell and first-frame status checks on the tested setup. See the
[C3 repaint record](doc/vt7/validation/2026-09-12-atlas-repaint.md).

Build **0.3.2** adds automatic Direct3D11 hardware-to-WARP fallback,
bounded recovery and explicit failure reporting. Forced backend modes remain
strict. Debug, assembled Release and supplied Windows 7 checks pass for the
bounded recovery slice. Injected failures are not real driver-loss evidence.
See the [recovery record](doc/vt7/validation/2026-09-12-atlas-recovery.md).

Build **0.3.3** passes the font/settings tests at measured Windows 7 DPI 96, 120
and 144, but the higher-scale viewport/recovery suites exposed failures. It is
not accepted as an all-green scaling checkpoint. The corrective **0.3.4** build
now passes every positive suite at all three actual Windows 7 scales, including
startup fit, status-layout stability and recovery. This closes the bounded
scaling checkpoint on the tested setup, not Milestone 2. Scheduling, idle/resource
stress, themes and broader qualification remain ahead. See the
[scaling correction record](doc/vt7/validation/2026-09-12-atlas-scaling-correction.md).

VT7 already has its first real terminal viewport running on Windows 7. Engineering
build 0.2.0 brings together the WPF host, a native HWND surface, TerminalCore,
and the VT parser, with a temporary GDI renderer and working buffer reflow.

The proof has been tested on fully updated Windows 7 SP1 x64 setups both without
ESU and with the full ESU update set. Supplied logs and screenshots document the
non-ESU run; the tester separately confirmed the ESU setup. Core regression and
window-lifecycle checks pass, and the sample is visibly rendered on Windows 7.
See the [validation record](doc/vt7/validation/2026-09-10-viewport-proof.md) for
the evidence and scope.

This is a static proof, not an interactive shell. The accepted cleanup build,
0.2.1, corrects the tab/diagnostic contrast defect and adds checks for effective
text colors and native viewport tab switching. The Windows 7 recheck passes:
non-ESU logs and screenshots confirm the correction, and the tester confirms
keyboard navigation, visible focus, and a successful separate ESU run.
Milestone 1 is complete on the tested configurations. See the
[cleanup validation notes](doc/vt7/validation/2026-09-10-milestone-1-cleanup.md).
Atlas has now drawn its first real frames on Windows 7, too. The separate
backend proof runs both Atlas Direct3D11 and Direct2D on hardware and WARP.
All four automated modes pass, and screenshots show the Direct3D11 sample
visibly rendered on both devices. Resize/redraw and explicit device recreation
pass, including repeated R-key recreation in the visible windows. See the
[Atlas backend validation](doc/vt7/validation/2026-09-11-atlas-backend-proof.md).

This is another foundation stone, not a finished terminal renderer. That Atlas
backend proof uses fixed, pre-mapped Consolas glyphs. Build 0.3.0 adds the actual
font/controller/core path, now accepted on the tested Windows 7 setup. Broader
renderer qualification and session backends remain ahead.
The accepted 0.2.1 GDI proof stays intact while Milestone 2 continues.

The separate font and geometry experiments have progressed through
[renderer probe 0.13](doc/vt7/validation/2026-09-11-marked-paint-probe.md).
The supplied Windows 7 run passes all eight validation suites, including marked
Arabic painting and partial repaint, while preserving every earlier comparison
image. Same-outline color painting is promising; different-outline hybrids are
not being adopted as the default. Enhanced joined-word layout and its unresolved
cursor/selection mapping are deferred research, not prerequisites to the port.
These probe results are not a completed Atlas terminal renderer.

The [port-first plan](doc/vt7/architecture/2026-09-12-port-first-plan.md)
sets the next acceptance step: the remaining C3 renderer gates. After the accepted
0.3.4 Windows 7 scaling matrix, the next bounded slice covers synchronized-output
timeouts, idle CPU, resource growth and shutdown stress. Theme and broader
environment coverage remain open. Before substantial session integration
or daily-driver UI work, a new feasibility gate will test local-console fidelity,
direct OpenSSH I/O and resize, and Windows 7 input behavior. Full SSH delivery
remains a later milestone. These are approved plans, not new compatibility results.

- [x] Establish the VT7 project identity and scope.
- [x] Select and record the Microsoft Terminal upstream baseline.
- [x] Research the Windows 7 WPF, renderer, API, PTY, and SSH paths.
- [x] Produce a reproducible developer build for the first VT7 executable.
- [x] Open a static terminal viewport on Windows 7 SP1 x64.
- [x] Prove the isolated Atlas backends on Windows 7 hardware and forced WARP.
- [ ] Integrate complete terminal rendering, font fallback, and automatic
  graphics fallback with TerminalCore.
- [ ] Run an interactive local shell through the Windows 7 PTY backend.
- [ ] Complete the first direct SSH session.
- [ ] Add the daily-driver interface, including tabs, panes, profiles, and
  settings.
- [ ] Publish the first alpha build.

There are no public VT7 terminal releases yet. Local engineering proof packages
are not alpha releases. Please be careful with downloads that claim otherwise.

## Project documents

- [Roadmap](ROADMAP.md) - milestones, requirements, acceptance criteria, and
  non-goals.
- [Research and planning decision](doc/vt7/architecture/2026-09-11-research-driven-plan.md)
  - original shared contracts and experiment-to-milestone mapping.
- [Port-first execution plan](doc/vt7/architecture/2026-09-12-port-first-plan.md)
  - current short/long-term goals, integration checkpoints and improvement triage.
- [Building](BUILDING.md) - pinned toolchain, proof build, binary verification,
  packaging, and Windows 7 test procedure.
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

The renderer probe and Atlas viewport bundle unmodified GNU Unifont and Unifont Upper fonts
under their SIL Open Font License 1.1 option. These font assets retain their own
copyright/license and do not change VT7's MIT code license. See
[font provenance and licenses](oss/unifont/README.md) and [third-party notices](NOTICE.md).

## One last thing

Windows 7 still matters because its users still matter.

If VT7 can make one old workstation more useful, one administrator's day less
frustrating, one developer's tools more pleasant, or one much-loved computer
feel capable again, this project will have done something worthwhile.

Let's give Windows 7 the terminal it always deserved.
