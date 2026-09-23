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
> VT7 is currently in pre-alpha development. Version 0.11.0 retains selectable
> Command Prompt, Windows PowerShell 5.1 and versioned PowerShell 7 profiles to
> the accepted local transport. The exact PowerShell 5.1/7.2.24 transport,
> Unicode, resize, lifecycle and keyboard corpus passes on Windows 7. The 0.7.3
> H01 package adds a secured, typed `ssh` shim/fallback and output-ordering
> barrier; its exact Windows 7 three-shell run passes. Version 0.8.0 adds the
> first direct SSH.NET root profile with strict host-key verification, private-key
> or password authentication, a remote PTY and live resize. Package 0.2 passes
> the complete Windows 7 controlled-server matrix, including `htop` and `nano`.
> Package 0.3 corrects the form labels but its Windows 7 visual check finds the
> selected Authentication item still too light. Version 0.8.2/package 0.4 gives
> that generated selector text an explicit dark template and passes focused
> Windows 7 confirmation. Version 0.9.0 implements the session-scoped typed
> `ssh` overlay, structured trust/authentication prompt, committed-barrier switch
> and return to the originating shell. Package 0.1 passed its automated Windows
> 7 corpus but failed every real typed connection before network startup because
> its broker worker accessed WPF-owned geometry directly. Version 0.9.1/package
> 0.2 fixes that boundary and connects successfully on Windows 7, but rejects
> after its shim applies the five-second handshake timeout to the full remote
> session and leaves root input closed. Version 0.9.2/package 0.3 gives accepted
> completion the remote-session lifetime and guarantees root recovery after a
> lost shim. Package 0.3 passes the complete controlled Windows 7 overlay matrix.
> Version 0.10.0 adds KH01.2 read-only OpenSSH known-host trust to both direct
> and typed SSH.NET paths. Its package 0.2 passes on the primary Windows 7 host
> but exposes upstream SSH.NET issue 1829 on the NESSY non-ESU runtime. Version
> 0.10.1/package 0.3 pins the publisher-built SSH.NET
> 2026.0.1-prerelease.6/f099365 correction. Its automated corpus and both live
> SSH paths pass on TURTLE and the non-ESU NESSY machine, accepting KH01.2 across
> both Windows 7 .NET Framework 4.8 servicing tiers.
> Version 0.11.0 now implements KH01.3 first-contact trust: an unknown raw key
> is captured before authentication, then Cancel, Connect once, or Trust and
> connect drives a fresh SSH client. Durable trust safely appends and verifies
> the primary user `known_hosts` record. Local diagnostics pass; the new package
> and two-machine Windows 7 live matrix are pending.
> Other
> features described here remain project goals until implemented and verified.

Picking up development? Start with the [development handoff](doc/vt7/HANDOFF.md)
and [documentation index](doc/vt7/README.md). They distinguish current source,
issued test packages, accepted checkpoints and the next unresolved task. The
next Milestone 5 feature is governed by the completed
[OpenSSH-compatible known-host management specification](doc/vt7/architecture/2026-09-21-openssh-known-hosts-management-spec.md);
its disconnected [KH01.1 foundation](doc/vt7/validation/2026-09-22-known-hosts-kh01.md)
is accepted on Windows 7 against the required 10.0p2 oracle. The
[KH01.2 read-only integration](doc/vt7/validation/2026-09-22-known-hosts-kh01-2.md)
is accepted on both Windows 7 runtime tiers. The
[KH01.3 implementation record](doc/vt7/validation/2026-09-24-known-hosts-kh01-3.md)
documents the locally complete first-contact and durable-addition candidate;
Windows 7 acceptance is next.

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
  The [C4/3A technical specification](doc/vt7/architecture/2026-09-14-terminal-document-and-ssh-handoff-spec.md)
  now defines the document/view lifetime split and the later same-tab typed
  `ssh` handoff with an exact external-client fallback.
- A portable application package that can be extracted and run without modern
  Windows deployment infrastructure. (With a setup file to follow after the first
  full release)

These are engineering choices, not articles of faith. We will keep what proves
reliable on Windows 7 and change what does not.

## Compatibility target

The primary target is Windows 7 SP1 x64 with the Platform Update and the normal
runtime prerequisites documented in the [roadmap](ROADMAP.md). The required
baseline will not depend on unofficial post-EOL operating-system packages.

The current VT7 0.11.0 candidate retains ordinary .NET Framework 4.8 as the
runtime floor. It pins publisher-built SSH.NET `2026.0.1-prerelease.6`, whose
upstream `f099365` change resets receive-MAC state for older .NET Framework
implementations. The previous 2026.0.0 package connected on `mscorlib.dll`
`4.8.4795.0` but failed on a genuine non-ESU `4.8.4110.0` machine. That older
servicing level is now an explicit acceptance target instead of a forbidden
configuration.

Package 0.3 now passes the complete automated and stored-key live-path checks on
both tiers. NESSY proves the ordinary non-ESU `4.8.4110.0` floor; TURTLE proves
the newer `4.8.4795.0` configuration. KH01.3 is now implemented locally; its
generation-safe first-contact and durable user-store behavior must pass the same
two-tier target matrix before acceptance.

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

Current working source: **0.11.0, native ABI 11**. It retains the accepted 3A
document/session/view ownership and Command Prompt path, then adds explicit
Windows PowerShell 5.1 and versioned PowerShell 7 profiles through the same
production `WinPtyTransport`. Ordinary PowerShell launches preserve user
profiles; only controlled diagnostics use `-NoProfile`. The visible selector
replaces and joins the active root session without moving transport ownership
into WPF. The exact 0.6.4 Windows 7 run passes all four automated stages and both
ordinary shells pass Unicode, multiline, resize, scrollback, native-child and
lifecycle checks. It exposed that WPF retained focus after profile startup and
that the selected profile text lacked contrast. Version 0.6.5 applied explicit
selector colors and passed every automated contract plus startup, replacement
and shutdown on Windows 7, but its direct `SetFocus` correction did not stop WPF
from consuming Tab, Down and End. Version 0.6.6 implements the missing
`HwndHost` keyboard-sink path. All automated stages pass on Windows 7, and the
manual retest confirms the affected keys work properly in every local profile.
Version 0.7.3 implements the corrected H01 native shim and managed broker diagnostic. Its
per-session pipe capability, authenticated PID/console checks, restricted typed
grammar, exact external fallback and committed-output barrier pass locally and
in the strict Windows 7 Command Prompt, Windows PowerShell 5.1 and PowerShell
7.2.24 run. H01 is accepted for its bounded diagnostic scope. It does not enable
embedded SSH or contact a network endpoint. Version 0.8.0 incorporates the exact
S01-accepted SSH.NET 2026.0.0 dependency closure and implements a direct remote
root through the production `ITerminalTransport` boundary. The **Start SSH...**
dialog requires an out-of-band SHA256 host-key fingerprint and supports a
dedicated private key or password without persistence. The transport allocates
an `xterm-256color` PTY with real cell/pixel geometry, serializes input and live
resize, uses one ordered output reader, and performs stream-first shutdown. Its
offline package and regression suite pass locally. Package 0.2 passes the full
Windows 7 direct-profile matrix, scrollback and additional `htop`/`nano` runs.
Version 0.8.1/package 0.3 corrects the form labels, but the target visual check
finds its closed Authentication selection still light-on-light. Version
0.8.2/package 0.4 adds an explicit dark authentication-item template, verifies
the rendered selected text at 4.5:1 and passes focused Windows 7 confirmation. The
[direct-profile record](doc/vt7/validation/2026-09-19-sshnet-direct-profile.md)
defines the accepted direct-root boundary and evidence. Version 0.9.0 connects
the accepted H01 and SSH.NET paths: eligible typed `ssh` commands now open a
structured WPF prompt, switch the shared document to an SSH.NET overlay only
after the WinPTY barrier commits, and return to the same local shell. Package
0.1 proved the shim/barrier/return path on Windows 7 but rejected the production
connection: worker-thread startup touched dispatcher-owned geometry before
SSH.NET could connect. Version 0.9.1/package 0.2 routes that capture through the
document dispatcher and proves a real Windows 7 connection, but its accepted
shim times out after five seconds and returns the local prompt before the remote
session ends; later remote exit stalls root recovery. Version 0.9.2/package 0.3
separates bounded handshake I/O from session-lifetime completion, makes root
recovery unconditional after completion delivery, and adds a real delayed-shim
regression. The
[accepted overlay record](doc/vt7/validation/2026-09-21-typed-ssh-overlay.md)
documents the failures, corrections, exact package identity and complete
controlled Windows 7 result. Typed `ssh` now passes normal exit, sequential
handoff, explicit disconnect, all three local shells and exact fallback checks.
Version 0.10.0 loads immutable snapshots of the four default OpenSSH known-host
sources before either direct or typed SSH.NET connection. Stored raw-key matches
need no fingerprint re-entry; unknown hosts retain the exact fingerprint route,
and changed, revoked, unreadable or policy-rejected states fail before
authentication. Package 0.2 passes the primary machine but fails both SSH.NET
entry paths on NESSY because 2026.0.0 does not reset the receive HMAC after a
packet on the older .NET Framework implementation. Version 0.10.1/package 0.3
changes only this dependency boundary to publisher-built SSH.NET
2026.0.1-prerelease.6 from upstream commit `f099365`. The automated corpus and
both stored-key live paths pass on NESSY (`4.8.4110.0`) and TURTLE
(`4.8.4795.0`), accepting the correction and KH01.2 production read path.
Version 0.11.0 adds KH01.3 to both SSH entry paths. Unknown raw keys now stop
before authentication and enter a generation-bound prompt. Connect once pins
the exact captured host/key/store generation for one fresh client; Trust and
connect safely appends the primary user record, flushes, reloads and verifies it
before another fresh client. Changed, revoked, unreadable, fingerprint-mismatch
and certificate cases remain fail-closed. Local Debug diagnostics pass; target
acceptance is pending.
The exact 0.5.0 Windows 7 package also passes all three runners; manual
Command Prompt use, Croatian text and a Unicode filename pass. Ctrl+C interrupts
a running command; empty or partial prompt-line cancellation has the known
WinPTY 0.4.3 limitation. Version 0.5.1 added native mouse-wheel scrollback; its
Windows 7 run passed movement and retained-history behavior but exposed that
printable characters did not snap back to live output. Version 0.5.2 moves that
snap to VT7's committed-character boundary and passes local Debug/Release and
the supplied target-machine checks without further issues.
This accepts the bounded 3B.1 transport and the 3B.2 PowerShell transport/profile
corpus and its 0.6.6 keyboard correction. Neither
result closes the full 3B or 3C gate. S00 is
complete: the exact Microsoft 10.0p2
x64 client passes command bytes, trust and lifecycle tests, while its 0 by 0
PTY result and exact source reject the redirected interactive architecture.
The exact SSH.NET 2026.0.0 S01 diagnostic paths succeeded on Windows 7 against
controlled Debian. Corrected package 0.6 passes both confirmation runs and
selects SSH.NET as the embedded interactive candidate. Version 0.8.0 now uses
that locked closure in the production host; corrected package 0.2 passes the
complete direct-profile Windows 7 matrix. The completed
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

Engineering **0.4.0** implements Milestone 3A's ownership boundary. ABI 11 adds
opaque `TerminalDocument` and `TerminalView` handles, rejects destruction of an
attached document, keeps the decoder and core live without an HWND, and retains
the ABI 10 surface exports as a one-transition diagnostic facade. The managed
`TerminalSession` owns one continuous document pump, bounded outbound routing,
root/overlay generations and awaited transport closure. TerminalCore replies are
copied out of the core lock through a bounded native queue and returned to the
transport generation that caused them. Debug and Release tests destroy and
recreate the HWND during the 388-byte deterministic stream with an exact raster,
then switch fake root/overlay input generations 1/2/3 while both producers drain
into one document.

Engineering **0.5.0** implements the first 3B production transport slice. The
visible host now starts `%SystemRoot%\System32\cmd.exe` through the exact pinned
WinPTY 0.4.3 runtime, with explicit arguments, working directory and Unicode
environment. The transport owns its pipes, child and agent lifecycle, forwards
ordered input and authoritative resize operations, drains final output before
reporting the child exit code, and closes deterministically on owner
cancellation. Local Debug/Release and visible-close checks pass. The issued
Windows 7 candidate passes its automated runners and manual Croatian HR Latin,
Unicode filename and child-GUI checks. Ctrl+C exposed an open WinPTY control-
input boundary at an empty or partial prompt, while active-command interruption
works. Ctrl+V and Ctrl+A retain classic console behavior until host keybindings
are implemented.

Engineering **0.5.1** fixes the missing viewport navigation found in the first
manual Command Prompt run. The child HWND honors the Windows wheel-lines setting
and high-resolution deltas, delegates movement to TerminalCore's user-scroll
state, holds the selected history position as output arrives and snaps to live
output on input. ABI 11 is unchanged. Local Debug and Release verification pass;
the Windows 7 run confirms wheel movement and retained history. Backspace,
Delete and arrow keys snapped to live output, but printable characters did not.

Engineering **0.5.2** applies snap-on-input when the native HWND delivers a
committed character. This retains the I01 decision that Windows owns Croatian,
dead-key and AltGr composition through `WM_CHAR`, without synthesizing printable
text from keydown events. The regression now encodes an actual printable `x`
and verifies that it returns the viewport to live output.

Engineering **0.6.0** adds typed Windows PowerShell 5.1 and PowerShell 7
profiles, exact executable/version discovery, visible root-session selection and
strict 7.2.24 qualification. Normal launches retain user profiles and settings;
clean diagnostics verify PSReadLine, completion, multiline input, Croatian
environment text, native children, resize and final drain. See the
[3B.2 validation record](doc/vt7/validation/2026-09-17-powershell-profiles-3b2.md).

Engineering **0.6.1** split the multiline diagnostic into separately observed
writes after 0.6.0 timed out. Two Windows 7 runs still timed out because the
lines retained a carriage-return-plus-line-feed terminator.

Engineering **0.6.2** sends the carriage return produced by VT7's real Enter-key
path without an additional line feed. It also records per-line WinPTY counters
if the target still stalls. The target received and echoed every line but stayed
inside the continuation construct.

Engineering **0.6.3** removes multiline continuation parsing from the automated
gate. One ordinary prompt line performs the same checks and exits directly with
a distinct code for every failed assertion. Its target result identifies absent
automatic PSReadLine loading in clean Windows PowerShell 5.1.

Engineering **0.6.4** accepts either the built-in Windows PowerShell ConsoleHost
editor or an auto-loaded PSReadLine module. PowerShell 7.2.24 still requires its
bundled PSReadLine and prediction capability. The manual workflow validates
visible history, completion and multiline behavior with the active editor. Its
Windows 7 automated suite passes; ordinary use verifies multiline Croatian text,
resize, scrollback and clean lifecycle while exposing WPF focus and selector
contrast defects.

Engineering **0.6.5** returns Win32 focus to the native terminal HWND after
profile startup and replacement and gives the closed profile selector an
explicit text/background pair. Target testing proved that focus alone does not
cross WPF keyboard preprocessing: Tab, Down and End can still navigate WPF.

Engineering **0.6.6** overrides the `HwndHost` keyboard sink for terminal
navigation, editing, control and character messages before WPF performs control
traversal. Its focused regression now exercises `IKeyboardInputSink`, including
Tab, Down, End and the printable-text boundary that the 0.6.5 check omitted.
All four Windows 7 stages and the manual all-profile key retest pass.

Engineering **0.7.0** implements the bounded H01 typed-command shim and barrier
diagnostic. A Windows 7-subsystem native `ssh.exe` shim authenticates to a
per-session local broker, reports its process/console identity, accepts only the
specified interactive grammar, and falls back to an exact hashed external
executable with CRT-compatible quoting and sanitized state. Embedded acceptance
uses a visible WinPTY marker whose bytes must commit through `SessionOutputPump`
before the host completes the handoff. Debug/Release and staged-package checks
pass locally.

The first Windows 7 H01 run passes all three embedded shell/barrier paths but
exposes that duplicated console handles cannot be used by the external fallback
child on Windows 7. Engineering **0.7.1** tries to mark the original handles
inheritable, but package 0.2 proves WinPTY's Windows 7 console handles reject
that operation with error 87. Engineering **0.7.2** then proves Windows 7 also
rejects traditional console handles inside `PROC_THREAD_ATTRIBUTE_HANDLE_LIST`
when `CreateProcessW` returns error 1450. Engineering **0.7.3** uses Windows 7's
documented standard-handle transfer with `bInheritHandles=FALSE`, while Windows
8+ retains the explicit handle-list path. Package 0.4 passes the strict Windows
7 three-shell target run and H01 is accepted.

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
authorized C4 / Milestone 3A session feasibility, now completed and accepted on
Windows 7. Build 0.5.0 implements the first 3B Command Prompt slice and passes
its bounded Windows 7 transport/Unicode/lifecycle scope. Active-command Ctrl+C
works; prompt-line cancellation is the known WinPTY limit. Build 0.5.1 proves
native wheel movement and retained history on the target; build 0.5.2 corrects
printable-character snap-to-live and passes the supplied target checks. Build
0.6.4 carries the accepted Windows 7 local PowerShell profile layer and editor-
fallback automation. Version 0.6.5 retains the accepted contracts and lifecycle
but fails the manual navigation-key correction. Version 0.6.6 adds the WPF
keyboard-sink implementation and passes focused target confirmation. The
0.7.3 H01 package passes its strict Windows 7 three-shell run. Version 0.8.0
implements the separate direct SSH.NET root profile; package 0.2 passes its full
Windows 7 network matrix plus `htop` and `nano`. Version 0.8.1/package 0.3
corrects the form labels but misses the selected Authentication item; version
0.8.2/package 0.4 corrects and checks that generated text. Version 0.9.2/package
0.3 enables the accepted typed SSH.NET overlay. The broader SSH and input corpus
remains open. Build 0.3.5
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
qualification remain incomplete. Build 0.4.0 now supplies the document/session
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
interactive candidate. The 3A session-identity/lifetime split is accepted on
Windows 7; the selected WinPTY root transport is now implemented and boundedly
target accepted for Command Prompt. Ctrl+C control delivery retains its stated
limit. The PowerShell 5.1/7.2.24 profile and transport corpus is accepted on the
supplied Windows 7 target. Full SSH delivery remains a later milestone.

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
- [x] Accept the first direct SSH session on Windows 7. Version 0.8.0 package
  0.2 passes the controlled-server matrix. Package 0.3 fixes the form labels but
  misses selected Authentication text; 0.8.2 package 0.4 corrects that remaining
  UI-only defect.
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
