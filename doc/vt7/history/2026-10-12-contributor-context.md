# Earlier contributor context

Historical material retained during my 2026-10-13 documentation cleanup.
Use the [current handoff](../HANDOFF.md) for active work and dated validation
records for acceptance. Earlier "current" and "next" statements keep their
original checkpoint scope.

## What helps most right now

Follow the [port-first plan](../architecture/2026-09-12-port-first-plan.md):
reuse pinned upstream behavior and focus on Windows 7 adaptation and application
integration. State which current checkpoint or required workflow a change serves.
For a new experiment, name the blocking question, bounded test and decision it
will enable before expanding the probe suite.

Record non-blocking observations in the roadmap's Milestone 7 register, with
user impact, evidence, baseline/workaround, proposed follow-up and a condition
that would make the issue blocking. Optional typography, UI refinements and
optimizations should not interrupt the port. Release triage may defer them to
post-release work. Source loss, unsafe input, security, stability and failures
of required workflows remain immediate concerns, not optional polish.

Start with [BUILDING.md](../../../BUILDING.md) and the current
[stability record](../validation/2026-09-13-atlas-stability.md).
The working source is 0.12.3/ABI 11. It combines the accepted document/session/
view ownership and bounded inbound/outbound paths with Command Prompt, Windows
PowerShell 5.1 and versioned PowerShell 7 profiles through pinned WinPTY 0.4.3.
Local Debug/Release, lifecycle and clean-profile PowerShell 5.1 checks pass. The
exact Windows 7 3B.1 Command Prompt candidate also passes its
automated transport/lifecycle checks and manual Croatian/Unicode workflow;
active-command Ctrl+C passes; prompt-line cancellation is a known WinPTY 0.4.3
limit. The 0.5.1 target run accepts wheel movement and retained history but found
printable-character input did not snap to live output. Version 0.5.2 corrects
that boundary and passes the supplied test-machine checks. Version 0.6.6 retains
visible profile selection, preserves ordinary PowerShell user profiles and
strictly separates local preview discovery from exact 7.2.24 qualification. Its
exact Windows 7 3B.2 automation and ordinary profile lifecycle pass. The run
found WPF focus retention and selector contrast defects. Version 0.6.5 passed
the automated contract and lifecycle retest, but direct Win32 focus did not keep
Tab, Down or End inside the viewport. Version 0.6.6 implements the missing
`HwndHost` keyboard sink; all automated Windows 7 stages and the manual key test
across every local profile pass. Version 0.7.3 adds the corrected H01
typed-command shim, authenticated local broker, exact fallback and committed
WinPTY barrier diagnostic. Package 0.1 passed all three embedded paths on
Windows 7 but exposed invalid cross-process use of duplicated console handles.
Package 0.2 then proved those downlevel handles reject inheritance-flag changes.
Package 0.3 proves the explicit handle list also rejects traditional console
handles at process creation. Package 0.4 uses Windows 7's standard-handle
transfer without broad handle inheritance and passes the strict three-shell
target run. H01 is accepted. Version 0.8.0 adds the first production
`SshNetTransport` as a separate direct root profile with mandatory SHA256
host-key pinning, private-key/password authentication, actual cell/pixel PTY
geometry, live resize and stream-first teardown. Its exact locked dependency
closure and local regressions pass. Package 0.2 passes the complete Windows 7
controlled-server matrix plus `htop` and `nano`. Package 0.3 corrects the form
labels but leaves the selected Authentication item too light; version 0.8.2/
package 0.4 explicitly styles and checks that generated selector text, and its
focused Windows 7 visual confirmation passes. Version 0.9.0 implements the
session-scoped typed `ssh` overlay, structured prompt, committed-barrier switch
and return to the original shell. Package 0.1 passed the target automation but
failed real typed connections when its broker worker read dispatcher-owned
geometry. Version 0.9.1/package 0.2 fixes that boundary and connects on Windows
7, but its shim times out while the accepted remote session remains active and
the later completion cannot reopen root input. Version 0.9.2/package 0.3 gives
accepted completion the session lifetime, guarantees root recovery after a lost
shim and passes its delayed-shim regression. Package 0.3 passes the complete
controlled Windows 7 overlay matrix. Start with the
[KH01.4 validation record](../validation/2026-09-24-known-hosts-kh01-4.md)
for the current known-host work: the 0.12.0/package 0.5 candidate failed
security read-back on both Windows 7 machines. Version 0.12.1/package 0.6
passes the automated corpus on both, but live removal stops before mutation
at `temporary-security`. Version 0.12.2 adds structural security comparison
and legible key rows. Package 0.7 exposed an obsolete exact-SDDL assertion
in its inherited-ACL fixture on Windows 7. Version 0.12.3 corrects that test;
package 0.8 passes the exact automated and controlled live known-host matrix
on NESSY and TURTLE. KH01.4 is accepted; KH01.5 live certificate serving remains.
Also read the
[accepted overlay record](../validation/2026-09-21-typed-ssh-overlay.md),
[direct-profile validation record](../validation/2026-09-19-sshnet-direct-profile.md),
[session stream contract](../architecture/2026-09-14-session-stream-foundation.md)
and [session outbound contract](../architecture/2026-09-14-session-outbound-foundation.md).
The completed [I01 record](../validation/2026-09-14-input-i01.md) defines
the Windows 7 Croatian native-HWND committed-text/key/resize boundary for the
implemented outbound adapter. Its bounded target checks are accepted; live
backend, broader layout, printable-repeat and IME acceptance remain later work.
The earlier 0.2 host/core proof ran on tested Windows 7 non-ESU and ESU setups;
that historical result does not qualify every later build or update tier.

The isolated Atlas backend proof now also has Windows 7 hardware/WARP results,
including visible Direct3D11 and repeated device recreation. Read the
[backend validation record](../validation/2026-09-11-atlas-backend-proof.md)
before renderer changes. Preserve the GDI regressions and keep fixed-glyph
backend evidence separate from full font shaping, controller integration,
automatic recovery, and session acceptance.

- Reproducible Windows 7 build and runtime investigation.
- Hardening the isolated TerminalCore boundary and removing modern renderer
  dependencies.
- Windows 7 Atlas, DXGI, Direct3D 11, and WARP work.
- WPF styling/contrast fixes, visual regression coverage, and native HWND
  lifetime and resize hardening.
- Windows 7 acceptance of the implemented PowerShell 5.1/7.2.24 profiles and
  their ordinary PSReadLine/native-child corpus under the P01 fidelity limits.
- Hardening of the Windows 7-accepted typed-command SSH.NET overlay. S00 rejected
  unmodified redirected OpenSSH for interactive PTY sessions; 0.9.2 keeps it as
  the exact fallback for unsupported syntax.
- Dependency, imported-API, and behavior-level compatibility audits.
- Automated tests that protect Windows 7-specific behavior.
- Physical Windows 7 testing with precise system and driver information.

Follow the [port-first checkpoints](../architecture/2026-09-12-port-first-plan.md)
and link relevant changes to the [experiment IDs](../research/20-validation-and-experiments.md).
The minimum font boundary and integrated Atlas viewport now have local and
supplied Windows 7 C1/C2 acceptance in 0.3.0. C3 work followed that checkpoint;
the current REL01 decision below permits C4/3A development. See the
[integration record](../validation/2026-09-12-atlas-viewport.md).
0.3.1 C3 repaint/cursor and status checks have local and supplied Windows 7
acceptance recorded in the
[repaint record](../validation/2026-09-12-atlas-repaint.md).
0.3.2 automatic fallback and controlled recovery pass supplied target testing;
see the [recovery record](../validation/2026-09-12-atlas-recovery.md). Keep
injected failures distinct from real driver failures and forced renderer modes strict.
0.3.3 font/settings tests passed at actual Windows 7 96/120/144 DPI but exposed
higher-scale viewport/recovery failures. Current 0.3.4 passes all positive suites
at those scales on the supplied setup, accepting the bounded scaling checkpoint.
Build 0.3.5 implements scheduling/idle/resource/shutdown checks, with distinct quick, full-lifecycle
and extended-soak profiles. Follow the [stability record](../validation/2026-09-13-atlas-stability.md),
keep resource-growth failures visible and do not equate a quick pass with target
soak acceptance. Native HWND destruction must finish before its presentation
worker exits; hidden workers park rather than terminate.
Hardware lifecycle passes locally and on the supplied Windows 7 setup, while
integrated WARP growth remains unresolved. The native-only comparison grows in
both modes on Windows 7, unlike the development machine's power/plain contrast.
The recreate/reuse control now completes on Windows 7 and grows in both modes.
The [focused reuse trace](../diagnostics/2026-09-13-resource-trace.md)
now supplies target call-path evidence for eleven Event opens during WARP
presentation-thread initialization. Its completed capture passes corrected
offline validation; do not request an unchanged repeat. The
[offline pool inspection](../diagnostics/2026-09-13-warp-pool-lifetime.md)
now documents WARP's work cleanup and the target factory's 67-second idle
timeout. The new [retirement diagnostic 0.1](../diagnostics/2026-09-13-resource-retirement.md)
now has a [completed Windows 7 capture](../diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result)
with supported mode 3, completed work/wrapper cleanup and all 34 baseline pool
workers absent by 90 seconds. USER returns to 4, while handles remain 107,
or 54 above pre-warmup, through 180 seconds. The native 0.3.5 payload is unchanged.
The separate [WPF reactivation diagnostic 0.1](../diagnostics/2026-09-14-resource-reactivation.md)
now completes two full lifecycle/idle rounds on the supplied Windows 7 setup,
with the issued native DLL unchanged. Both +180s states have the same handle,
thread, GDI and USER counts; private memory rises by 220 KiB. Three of the eight
immediate checkpoints still fail. Preserve the initial baseline and all verdicts;
matching late counts do not prove matching handles or a permanent safe bound.
The [approved development deferral](../architecture/2026-09-14-warp-development-deferral.md)
stops further tracing and tracks conditional follow-up as REL01 in Milestone 7
release readiness. Proceed to C4/3A and feature development. Preserve original
budgets, warm-up, baseline and failed exits; no input/security workaround is
adopted. Future sustained-use qualification does not require complete handle
attribution first. Reopen tracing only for a named evidence or release question.
Retain negative controls and exact same-device
comparisons; see the [correction record](../validation/2026-09-12-atlas-scaling-correction.md).
The 3A feasibility gate applies before substantial local
integration or daily-driver UI work. Research priority labels are not new test
results. The explicit REL01 development-risk decision changes sequencing,
while retaining the failed tests and unresolved release qualification.

