# VT7

## The terminal application Windows 7 always deserved.

Windows 7 got so much right. It was quick, focused, familiar, and built around
the person sitting in front of the computer. For many of us it was more than an
operating system. It was the soul of where we learned, built, repaired, played,
and got work done.

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

Picking up development? Start with the [development handoff](doc/vt7/HANDOFF.md)
and [documentation index](doc/vt7/README.md). They distinguish current source,
issued test packages, accepted checkpoints and the next unresolved task.

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
and compatibility must be assessed. We will publish tested backend capabilities
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
- Pinned WinPTY 0.4.3 as the selected Windows 7 local legacy-console backend,
  integrated behind a replaceable boundary with explicit fidelity limits.
- A direct SSH backend for correct authentication, host-key handling, remote
  PTY allocation, and resize messages. S00 accepts Microsoft Win32-OpenSSH for
  non-PTY command transport but rejects its redirected process path for
  interactive sessions. The bounded SSH.NET 2026.0.0 S01 diagnostic is now
  target-tested and accepted. Corrected package 0.6 passes public-key-only and
  optional-password runs, including negotiated protection and owned shutdown.
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

Current working source: **0.3.7, native ABI 10**, with session-neutral byte
ingress plus a generation-checked outbound queue and native-HWND input/resize
adapter. The active task is C4 / Milestone 3A session feasibility. The exact
0.3.7 Windows 7 candidate passes. S00 is complete: the exact Microsoft 10.0p2
x64 client passes command bytes, trust and lifecycle tests, while its 0 by 0
PTY result and exact source reject the redirected interactive architecture.
The exact SSH.NET 2026.0.0 S01 transport paths succeeded on Windows 7 against
controlled Debian. Corrected package 0.6 passes both confirmation runs and
selects SSH.NET as the embedded interactive candidate. Its locked closure and
supplier notices remain isolated until production integration. The completed
[Windows 7 retirement diagnostic](doc/vt7/diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result)
confirms WARP work cleanup and worker-associated Event release by 90 seconds;
54 process handles remain above startup and the integrated WARP failure stays
open. Its complete logs are archived locally with verified file hashes. See the
[handoff](doc/vt7/HANDOFF.md) for current package identities, evidence, and the
source-only versus issued-artifact boundary. The progression
below preserves each earlier checkpoint's scope.

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

Engineering **0.3.5** adds renderer scheduling tests and corrects timer locking
and window/worker teardown order. It is a test candidate, not a completed
stability checkpoint: hardware passes 100 lifecycles locally and on the supplied
Windows 7 setup, while WARP exceeds the resource-growth budget on both.
Quick checks pass on both backends, but no timed soak has been run. The remaining
growth is deferred as REL01 under the owner's
[development decision](doc/vt7/architecture/2026-09-14-warp-development-deferral.md).
Further tracing is conditional release-readiness work; sessions can proceed.
Local handle tracing and
a paired native-only control implicate Windows power-notification/message
delivery paths on the development machine. The supplied Windows 7 control grows
with and without those subscriptions, so that specific explanation does not
transfer unchanged. Later target tracing and retirement identify a bounded
Event/worker path, and the WPF two-round late counts repeat. Retained handle
ownership and a permanent bound remain uncertain. See the
[stability investigation](doc/vt7/validation/2026-09-13-atlas-stability.md).

Engineering **0.3.6** adds the first production session boundary. A bounded
managed queue accepts ordered output from transport threads, marshals native
calls to the surface dispatcher, and feeds a persistent per-surface UTF-8 decoder
into TerminalCore. Its deterministic fixture renders Croatian HR Latin text and
VT styling identically as one chunk, one byte per write and irregular chunks.
Incomplete UTF-8 at EOF is explicit and a new generation recovers. Debug and
Release focused tests pass locally, and the byte-stream checks pass in the later
0.3.7 Windows 7 run. A real process transport remains ahead.
See the [session stream foundation](doc/vt7/architecture/2026-09-14-session-stream-foundation.md).

Engineering **0.3.7** implements the I01-selected native child-HWND input path.
OS-committed Croatian, AltGr and composed UTF-16 is encoded once by the same
TerminalInput instance whose modes follow parsed output. A Windows 7-specific
non-text entry point avoids live-thread `ToUnicodeEx`; handled Enter, Ctrl+C and
Ctrl+Break suppress their paired character messages while retaining distinct
Interrupt and Break operations. One bounded queue orders input, focus, resize,
paste and terminal-reply operation kinds by session generation. Debug and
Release focused tests pass locally. The exact target ZIP also passes on Windows
7 SP1 x64 with Croatian `hr-HR` culture and matching host/native hashes. See the
[session outbound foundation](doc/vt7/architecture/2026-09-14-session-outbound-foundation.md).

S00 now has an endpoint-independent OpenSSH preflight. It records the installed
client's exact identity, raw stdout/stderr routing, algorithm inventory,
effective configuration and bounded cancellation without credentials, a remote
server or machine changes. Its MIT-only package does not redistribute OpenSSH.
Two Windows 7 runs accept the exact official Microsoft 10.0p2 x64 executable
and repeat all byte-level behavior. Controlled-server package 0.1 also completes
against Debian 12: strict trust, key authentication, exact bytes, negotiation,
active cancellation and final drain pass. Forced PTY allocation reports an
unusable initial 0 by 0 size. One privacy claim failed because the changed-host
diagnostic retained a public host fingerprint and temporary Windows profile
path; restricted raw and sanitized evidence are separated. Exact 10.0p2 source
shows that redirected stdout cannot supply the console size and redirected
input receives no console resize events. S00 therefore accepts external
`ssh.exe` only for non-PTY command transport. S01 accepts SSH.NET 2026.0.0 as
the embedded interactive candidate. The owner approved its permissive license closure and the
project-wide notice policy. Package 0.6 accepts trust, public-key and password
authentication, command bytes, PTY resize/drain, cancellation, owned shutdown
and session isolation on Windows 7. See the
[S01 validation record](doc/vt7/validation/2026-09-14-sshnet-s01.md).

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
and the [September 14 development decision](doc/vt7/architecture/2026-09-14-warp-development-deferral.md)
make C4 / Milestone 3A session feasibility the current development step. Build 0.3.5
implements synchronized-output, idle CPU and shutdown checks after the accepted
0.3.4 scaling matrix. Its WARP resource concern remains recorded under REL01.
The recreate/reuse comparison, ownership trace and retirement diagnostic now
have Windows 7 results. The separate
[WPF reactivation diagnostic 0.1](doc/vt7/diagnostics/2026-09-14-resource-reactivation.md)
now completes both integrated lifecycle/idle rounds on Windows 7. Its two
+180s states match at 1,314 handles, 13 threads, GDI 18 and USER 10, with only
220 KiB more private memory in the second. Three immediate budget failures
remain. The owner has accepted the remaining resource uncertainty for continued
development and stopped dedicated WARP tracing. REL01 tracks conditional
follow-up in Milestone 7 release readiness; C3, theme and broader environment
qualification remain incomplete. Build 0.3.7 now supplies the shared byte-stream
foundation. P01 now completes its eighteen-case Windows 7 comparison and selects
WinPTY 0.4.3 for local legacy-console sessions, with raw-VT, code-page,
cursor-width and intermediate-state limits recorded. The separate
[I01 package 0.2](doc/vt7/validation/2026-09-14-input-i01.md) is locally
and Windows 7 qualified for Croatian HR Latin mapping, `TerminalInput`,
WPF/native focus, Ctrl and resize characterization. Windows 7 does not honor the
helper's non-mutating `ToUnicodeEx` flag, so the native HWND's committed-text
path owns printable input. That adapter and the bounded generation queue are now
implemented and target validated. S00 rejects direct redirected OpenSSH for
interactive PTY use, while S01 accepts SSH.NET 2026.0.0 as the embedded
interactive candidate. The immediate step is the 3A session-identity/lifetime
split. Full SSH delivery remains a later milestone.

- [x] Establish the VT7 project identity and scope.
- [x] Select and record the Microsoft Terminal upstream baseline.
- [x] Research the Windows 7 WPF, renderer, API, PTY, and SSH paths.
- [x] Produce a reproducible developer build for the first VT7 executable.
- [x] Open a static terminal viewport on Windows 7 SP1 x64.
- [x] Prove the isolated Atlas backends on Windows 7 hardware and forced WARP.
- [x] Integrate Atlas rendering, minimum font fallback and automatic graphics
  fallback with TerminalCore on the tested Windows 7 setup.
- [ ] Complete the remaining C3 renderer qualification, including WARP
  resource lifetime, broader environment checks and subsequent timed stability.
- [ ] Run an interactive local shell through the Windows 7 PTY backend.
- [ ] Complete the first direct SSH session.
- [ ] Add the daily-driver interface, including tabs, panes, profiles, and
  settings.
- [ ] Publish the first alpha build.

There are no public VT7 terminal releases yet. Local engineering proof packages
are not alpha releases. Please be careful with downloads that claim otherwise.

## Project documents

- [Development handoff](doc/vt7/HANDOFF.md) - current state, code map, evidence,
  unresolved questions, exact next task and safe resumption checklist.
- [Documentation index](doc/vt7/README.md) - current guidance, historical
  validation and research, with inherited upstream material clearly separated.
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

MIT remains the default for new VT7-authored code. The project owner's standing
2026-09-14 decision permits compatible permissive dependencies and assets under
Apache-2.0, ISC-style, BSD-style and other supplier terms when they help deliver
the port. Every inclusion keeps its own license, copyright and notice files and
is recorded in an artifact-level inventory. Licenses that impose source-sharing,
network-use, proprietary redistribution or other material distribution
conditions receive a separate compatibility review before adoption. See the
[project-wide third-party licensing policy](doc/vt7/architecture/2026-09-14-third-party-licensing-policy.md).

The renderer probe and Atlas viewport bundle unmodified GNU Unifont and Unifont Upper fonts
under their SIL Open Font License 1.1 option. These font assets retain their own
copyright/license and do not change VT7's MIT code license. See
[font provenance and licenses](oss/unifont/README.md) and
[third-party acknowledgements and notices](NOTICE.md).

## One last thing

Windows 7 still matters because its users still matter.

If VT7 can make one old workstation more useful, one administrator's day less
frustrating, one developer's tools more pleasant, or one much-loved computer
feel capable again, this project will have done something worthwhile.

Let's give Windows 7 the terminal it always deserved.
