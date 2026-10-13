# VT7 roadmap

I want VT7 1.0 to be a dependable Windows 7 terminal with familiar tabs and
profiles, terminal-only SSH, and current-upstream text/font support. A feature
is complete when its required tests pass on real Windows 7 machines.

Milestones follow technical dependencies rather than calendar dates. Several
have work in progress at once. An accepted diagnostic or feature slice does
not close its entire milestone.

## Current work

**SL01.3 is ready for target testing.** The 0.16.0 candidate adds twelve real
SSH authentication/PTY stall cases. Local checks pass; paired Windows 7
client/server acceptance is pending. SL01.1, bounded SL01.2, and KH01.1-KH01.5
are accepted within their recorded scopes.

The [handoff](doc/vt7/HANDOFF.md) is the place for the current candidate and next
action. Dated [validation records](doc/vt7/validation/README.md) retain failures,
fixes, exact package identities, and the evidence behind each acceptance.

## Milestones

| Milestone | Status | What completion means |
| --- | --- | --- |
| [0. Foundation](doc/vt7/plan/foundation.md#milestone-0-project-foundation) | Complete | Project policy, provenance, compatibility floor, and local build workflow. |
| [1. Proof of life](doc/vt7/plan/foundation.md#milestone-1-proof-of-life) | Complete on tested configurations | A standalone window and static TerminalCore viewport run on Windows 7. |
| [2. Renderer](doc/vt7/plan/renderer.md) | In progress | Atlas rendering, fallback, text/font parity, DPI, recovery, and stability pass their full gates. |
| [3. Local sessions](doc/vt7/plan/local-sessions.md) | Accepted foundation; qualification remains | CMD and installed supported PowerShell versions pass the required input, native-app, resize, and lifecycle corpus. |
| [4. Daily-driver interface](doc/vt7/plan/interface.md) | Required work remains | Independent tabs and panes, stable profiles, settings, search, clipboard, and accessible keyboard operation. |
| [5. SSH](doc/vt7/plan/ssh.md) | Active | Secure typed SSH with terminal-only interaction, dependable lifecycle behavior, and the remote application corpus. |
| [6. Product qualification](doc/vt7/plan/qualification.md) | Pending assembled product | The complete application passes the minimum-system, hardware, performance, privacy, and sustained-use matrix. |
| [7. Polish and release](doc/vt7/plan/release.md) | Pending required features | Selected finishing work, documented remaining risks, verified packages, and a release decision. |

Each linked milestone keeps its detailed checklist and evidence. I will update
those requirements in their own files instead of repeating the full history here.

## Required before polish

| Workstream | Required outcome |
| --- | --- |
| [UT01](doc/vt7/architecture/2026-10-05-upstream-text-and-font-parity-plan.md) | Match the selected current-stable upstream Unicode, text rendering, and font fallback corpus. This is text capability parity, not the entire Terminal feature set or identical antialiasing pixels. |
| [UI01](doc/vt7/architecture/2026-09-25-pre-1-0-ui-and-terminal-ssh-contract.md) | Real title-area session tabs, default-profile **+**, adjacent profile menu, stable shell names, and a Windows 7 no-glass fallback. |
| [SSHUX01](doc/vt7/architecture/2026-09-25-pre-1-0-ui-and-terminal-ssh-contract.md) | Type `ssh` in a local shell; handle trust and authentication in that terminal; return to the same local prompt on exit. No New SSH shortcut or ordinary SSH dialog. |

Security, correctness, required accessibility, and stability belong in the
milestone implementing the feature. Optional appearance and behavior beyond the
agreed upstream reference go in the [polish register](doc/vt7/plan/release.md#deferred-improvements-register).

## Compatibility and acceptance

The [compatibility plan](doc/vt7/plan/compatibility.md) defines prerequisites,
test tiers, shell targets, and separate local-console/SSH capability contracts.
WMF 5.1 and system OpenSSH are not product prerequisites. I will keep the
legacy PowerShell 2.0 runtime result separate from editor qualification.

The [port-first decision](doc/vt7/architecture/2026-09-12-port-first-plan.md)
remains the implementation approach: reuse proven upstream behavior and adapt
the Windows 7 boundaries. Historical research proposals do not create extra
release requirements.

## Deferred reliability review

I accepted the WARP resource uncertainty for continued development under
[REL01](doc/vt7/architecture/2026-09-14-warp-development-deferral.md). The original
budget failures remain failures. Dedicated tracing is stopped; ordinary product
qualification will inform release review. Reproducible accumulation, exhaustion,
crashes, hangs, shutdown defects, or relevant lifetime changes can reopen it.
The [full REL01 conditions](doc/vt7/plan/release.md#deferred-reliability-review)
remain part of the release requirements.

## Version 1.0 acceptance bar

VT7 1.0 is complete only when all of the following are true:

- It installs or runs portably on a clean Tier A system with understandable
  prerequisite handling.
- It does not require modified system files, a system-wide compatibility layer,
  MSIX, the Microsoft Store, or ConPTY.
- Command Prompt, Windows PowerShell 5.1, and PowerShell 7.2.24 pass the local
  session acceptance suite.
- Direct SSH supports secure host-key verification, authentication, remote PTY
  creation, live resize updates, and unmodified remote terminal byte delivery.
- The title-area **+** and profile menu open independent sessions; the stable
  **Windows PowerShell** entry starts the installed `powershell.exe`, while
  **PowerShell** appears only for a compatible installed `pwsh.exe`. The
  no-glass Windows 7 layout preserves the same tab actions.
- Typed `ssh` from a supported local shell uses in-terminal trust and
  authentication, never an ordinary connection dialog or SSH profile; a saved
  matching host reconnects without repeated approval and exit returns to the
  same tab's local prompt.
- Tabs, panes, profiles, settings, search, selection, clipboard, and scrollback
  are dependable enough for daily work.
- Core/renderer acceptance proves streaming UTF-8, wide/combining text, box
  drawing, indexed/true color, and VT state with deterministic fixtures and
  versioned font evidence. Missing glyphs must not corrupt original text.
- UT01 matches the selected current-stable upstream Unicode/text/font capability
  corpus, including required coverage, shaping, widths, fallback families,
  supported color/emoji and axes, settings and text interactions. Current-stable
  delta review and all Windows 7 comparison gates pass before polish/1.0.
- Direct SSH independently passes end-to-end Unicode, 256-color/true-color,
  mouse, bracketed-paste, alternate-screen, and resize tests on compatible
  remote applications.
- Local-console acceptance independently passes the required shell/native-app
  corpus, input/IME, colors and text preserved by the selected console path,
  interrupts, resize, and clean shutdown. The capability ledger publishes
  measured transport limits; unresolved required workflow failures block
  acceptance until fixed or explicitly reconsidered, not silently waived.
- Selection, copy, search, IME geometry, and native accessible text agree with
  the core's cells and original text. Output-triggered host actions obey tested
  trust policies and cannot cross session boundaries.
- The renderer works with a supported Direct3D 11 driver and has a documented
  fallback path.
- Full-screen applications survive repeated resize, maximize, restore, and
  alternate-screen exit without lasting display corruption.
- Failures produce actionable diagnostics instead of silent exits.
- Licensing and provenance are complete for every shipped component.

## Deliberate non-goals for version 1.0

- Identical antialiasing pixels or every feature of current Windows Terminal;
  UT01 text/font support parity and the specific tab/profile and SSH interaction
  contracts above remain required.
- MSIX, Microsoft Store, WinGet, or Windows shell registration that depends on
  post-Windows 7 deployment services.
- ConPTY implementation for the operating system.
- Replacement of the built-in Windows console host.
- Mica, acrylic, modern DirectComposition effects, or Windows 11 integration.
- x86, ARM, or ARM64 builds.
- Guaranteed support for PowerShell 7.3 or newer.
- Making Windows 7 a supported or secure operating system again.

## Beyond version 1.0

Milestone 7 triage carries optional work here with evidence and explicit scope;
it is not discarded when the first release ships. A substantial selected workstream
can receive its own milestone. Neither this list nor the polish register is a
promise to deliver every enhancement in the first release.

Possible later work includes serial connections, additional SSH features,
session restoration, quake mode, shell integration, richer accessibility,
plugin interfaces, and other architectures. These should not distract from
shipping a trustworthy Windows 7 terminal first.

Color/emoji and variable-axis capabilities supported by the selected upstream
reference now belong to required UT01 delivery before 1.0. Broader bidi behavior
beyond upstream and richer local-console transport remain separate evaluation
tracks; they cannot waive required text workflows or mask transport text loss.
Preserve the baseline accessibility and local workflows above.
