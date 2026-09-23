# VT7 documentation - start here

Last reconciled: 2026-09-23. Version 0.6.6's accepted Windows 7 profile and
keyboard results remain the current target baseline. H01 packages 0.1 through
0.3 pass all embedded shell/barrier paths on Windows 7 while exposing the full
traditional-console fallback boundary. Version 0.7.3 uses the documented
Windows 7 creation path, and package 0.4 passes the strict target run. Version
0.8.0 adds the first direct SSH.NET root profile; corrected package 0.2 passes
the complete Windows 7 controlled-server matrix. Version 0.8.1/package 0.3 fixes
the form labels but fails its selected Authentication-item visual check. Version
0.8.2/package 0.4 corrects that generated text and passes its focused visual
check. Version 0.9.0 implements the typed SSH overlay. Package 0.1 passed target
automation but failed real typed connections at a worker-thread WPF geometry
access. Version 0.9.1/package 0.2 fixes that boundary and connects on Windows 7,
but its shim times out while the remote session is active and later root return
stalls. Version 0.9.2/package 0.3 corrects the accepted-session lifetime and
lost-shim recovery boundaries and passes the complete controlled target matrix.
Version 0.10.0 implements KH01.2 read-only OpenSSH known-host trust. Package
0.2 passes the primary Windows 7 host but is rejected after exposing upstream
SSH.NET issue 1829 on NESSY. Version 0.10.1/package 0.3 pins the upstream
prerelease.6/f099365 correction and passes the automated and live SSH checks on
both NESSY and TURTLE. KH01.2 is accepted across both Windows 7 runtime tiers.

VT7 is the terminal application Windows 7 always deserved. Version 0.10.1 keeps
the accepted Command Prompt/WinPTY path and adds explicit Windows PowerShell 5.1
and versioned PowerShell 7 profiles through the 3A document/session/view
boundary. Exact Windows 7 5.1/7.2.24 automation passes, as do the applicable
ordinary profile checks. The 0.6.6 automated and all-profile keyboard checks
pass. H01 itself adds no live SSH session and makes no network connection.
Version 0.8.0 integrates the accepted SSH.NET closure behind ABI 11 as a direct
profile with strict host-key trust, remote PTY geometry and live resize. Its
Windows 7 matrix, plus separate `htop` and `nano` runs, passes. Version 0.8.2
scopes readable text styling to the SSH connection dialog and its generated
Authentication selection. The session-scoped coordinator enables eligible typed
`ssh` commands and is accepted on the controlled Windows 7 configuration.
The
application port is the priority; optional improvements belong in final
polish/release triage.

## Read in this order

1. [Development handoff](HANDOFF.md): current source and artifacts, accepted
   results, deferred C3/REL01 concern, code map and the current Milestone 5 task.
2. [Roadmap](../../ROADMAP.md): milestone gates and the deferred-work register.
3. [Port-first plan](architecture/2026-09-12-port-first-plan.md) and
   [WARP development deferral](architecture/2026-09-14-warp-development-deferral.md):
   execution policy, approved risk decision and conditional reopening criteria.
4. [Building VT7](../../BUILDING.md): pinned tools, build/test commands and
   packaging precautions. Use `VT7.sln`, not the inherited OpenConsole build.
5. [Current stability record](validation/2026-09-13-atlas-stability.md): findings,
   negative results, evidence limits, package hashes and target comparison.
6. [Session stream foundation](architecture/2026-09-14-session-stream-foundation.md):
   ABI 9 byte ingress, queue/EOF ownership contract, focused tests and the P01 boundary.
7. [WinPTY P01 characterization](validation/2026-09-14-winpty-p01.md): exact
   dependency pin, controlled child/backend/core comparison, verified Windows 7
   evidence and the bounded local-backend selection.
8. [Session ownership and external source review](architecture/2026-09-14-session-ownership-and-source-review.md):
   disposition of the supplied architecture analysis, the required separation
   between session and presentation lifetime, and the source/license ledger.
9. [Terminal document, transport, and typed-SSH handoff specification](architecture/2026-09-14-terminal-document-and-ssh-handoff-spec.md):
   implementation-ready ownership, ABI 11, transport, shim/IPC, ordering,
   fallback, SSH.NET lifecycle, security, staging, and acceptance contracts.
10. [OpenSSH-compatible known-host management specification](architecture/2026-09-21-openssh-known-hosts-management-spec.md):
    exact 10.0p2 compatibility baseline, shared-file grammar and precedence,
    SSH.NET trust state machine, safe Windows mutation, licensing and KH01 gates.
11. [Known-host foundation KH01.1](validation/2026-09-22-known-hosts-kh01.md):
    bounded parser/matcher and raw-key trust resolver, local OpenSSH differential
    evidence, exact package identity and accepted 10.0p2 Windows 7 result.
12. [Known-host read-only production trust KH01.2](validation/2026-09-22-known-hosts-kh01-2.md):
    four default source snapshots, direct/typed callback policy, the rejected
    2026.0.0 two-machine result, upstream f099365 correction, candidate identity
    and corrected Windows 7 procedure.
13. [WinPTY root transport 3B.1](validation/2026-09-17-winpty-root-3b.md):
    0.5.0 implementation, exact runtime/package identities, local results,
    Windows 7 procedure and remaining shell scope.
14. [PowerShell profiles 3B.2](validation/2026-09-17-powershell-profiles-3b2.md):
    explicit profile/version discovery, ordinary versus clean policy, visible
     root replacement, accepted Windows 7 5.1/7.2.24 evidence, candidate identity
     and the rejected 0.6.5/accepted 0.6.6 keyboard follow-up.
15. [Input I01 characterization](validation/2026-09-14-input-i01.md): exact
   package and verified Windows 7 Croatian HR Latin evidence, the downlevel
   `ToUnicodeEx` result and the accepted native-HWND input/resize contract.
16. [H01 typed-command shim and barrier](validation/2026-09-19-typed-ssh-h01.md):
    0.7.0-0.7.3 implementation, returned target results, corrected candidate identity, strict target
    procedure and the boundary that keeps embedded SSH disabled.
17. [Session outbound foundation](architecture/2026-09-14-session-outbound-foundation.md):
    ABI 10 input encoding, bounded generation ordering, control suppression,
    focus/resize ownership and accepted Windows 7 evidence.
18. [OpenSSH S00 evaluation](validation/2026-09-14-openssh-s00.md): accepted
    Windows 7 command transport, trust and lifecycle evidence; exact-source
    rejection of redirected interactive PTY geometry; and the S01-accepted
    SSH.NET candidate.
19. [SSH.NET dependency and license audit](research/2026-09-14-sshnet-license-audit.md):
    exact 2026.0.0 net48 closure, package hashes, third-party terms and the
    project-wide permissive dependency decision.
20. [SSH.NET S01 evaluation](validation/2026-09-14-sshnet-s01.md): isolated
    diagnostic design, 0.5 assertion findings, accepted 0.6 Windows 7 results,
    credential boundary and production teardown contract.
21. [SSH.NET direct-profile transport](validation/2026-09-19-sshnet-direct-profile.md):
    0.8.0 production transport boundary, accepted package 0.2 Windows 7 result,
    the rejected 0.8.1/package 0.3 selector result, and the corrected 0.8.2/
    package 0.4 candidate.
22. [Typed SSH.NET overlay coordinator](validation/2026-09-21-typed-ssh-overlay.md):
    0.9.0 production handoff, 0.9.1 dispatcher correction, 0.9.2 lifetime
    correction, exact package identity and accepted Windows 7 result.
23. [Third-party licensing policy](architecture/2026-09-14-third-party-licensing-policy.md):
    standing owner decision, review triggers, packaging requirements, current
    component inventory and acknowledgement rule.

The handoff is the current resumption guide. The roadmap owns acceptance gates.
Dated validation records own what was actually tested. Research and historical
"next steps" are not authorization to replace the active plan or expand scope.
If these disagree, reconcile them against source and evidence, do not silently
choose the more optimistic status. The September 14 owner-approved REL01
decision changes the development dependency; it does not rewrite failed tests.
C4/3A proceeded without another WARP trace prerequisite and is accepted. The
3B.1 Command Prompt transport and the 3B.2 PowerShell transport/profile corpus
are target accepted. The 0.6.5 direct-focus correction failed the manual key
check; the 0.6.6 `HwndHost` keyboard sink passes focused Windows 7 confirmation.
The corrected 0.7.3 H01 package passes its strict Windows 7 three-shell run.
The 0.8.0 direct SSH.NET package 0.2 passes its complete Windows 7 network run;
it does not enable the typed handoff. Version 0.8.1/package 0.3 fixes the labels
but fails its selected-item visual check. Version 0.8.2/package 0.4 passes the
focused Windows 7 confirmation of the corrected Authentication selector.

## Implementation and reproduction

- [Core boundary](../../src/vt7/VT7.Core/README.md): inherited parser/buffer/core,
  compatibility switches and deliberately absent features.
- [Renderer boundary](../../src/vt7/VT7.Renderer/README.md): full Atlas adapter,
  HWND presentation, fonts and retained experimental helpers.
- [Native resource investigation appendix](diagnostics/2026-09-13-resource-investigation.md):
  archived native-control source, header, launcher, debugger recipe and target
  transcripts. This preserves its source and procedure; the original binaries
  and supporting payload still require separate recovery or reconstruction.
- [Resource lifetime comparison 0.2](diagnostics/2026-09-13-resource-lifetime.md):
  completed recreate/reuse control and supplied Windows 7 evidence.
- [Focused resource trace](diagnostics/2026-09-13-resource-trace.md):
  classic debugger setup, unchanged binary identities, trace protocol and limits;
  target 0.1 stops at an unattended debugger prompt before application work;
  target 0.2 captures unhandled second chance during startup before WARP;
  trace 0.3 completes on the target and passes corrected offline validation;
  eleven additional Event handles correlate with WARP/GetThreadDesktop setup
  calls on existing worker identities. No repeat collection is requested.
- [WARP pool lifetime](diagnostics/2026-09-13-warp-pool-lifetime.md): offline
  construction, task submission and cleanup inspection; common pool association
  across 32 factory handles; observed 67-second idle timeout. This explains the
  bounded retirement follow-up without claiming target cleanup or a lifetime bound.
- [Resource retirement diagnostic 0.1](diagnostics/2026-09-13-resource-retirement.md):
  new sampler, unchanged native payload, guarded mode/work cleanup hooks,
  10/90/180-second idle observations and full handle history. The
  [Windows 7 capture](diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result)
  completes: mode 3 cleanup is recorded and all 34 baseline pool workers are
  absent by 90 seconds, with matching closes for the captured worker-associated
  Events. The full run is preserved in a
  [verified local evidence archive](../../artifacts/vt7/evidence/resource-retirement-win7-0.1/ARCHIVE-VERIFICATION-20260913-152421-53a65b82.json).
  No unchanged collection is requested.
- [WPF resource reactivation diagnostic 0.1](diagnostics/2026-09-14-resource-reactivation.md):
  the supplied Windows 7 run completes all 16 samples and retains three
  immediate failures. Its two +180s handle/thread/GDI/USER counts match, with
  +220 KiB private bytes. All 207 returned files are archived and verified;
  retained handle attribution and final C3 qualification remain incomplete.
  Further tracing is stopped and deferred under REL01; session work proceeds.
- [Integrated package instructions](../../src/vt7/packaging/README.txt): source
  template for viewport candidates, not a substitute for an issued ZIP's identity.
- [Build/test tools](../../tools/README.md): VT7 helpers versus inherited tools.
- [OpenSSH S00 preflight](validation/2026-09-14-openssh-s00.md): the MIT-only
  package inspects the installed external client without credentials or machine
  changes. Its two Windows 7 runs are accepted and archived. Controlled-server
  package 0.1 also completes against Debian 12. Raw bytes and trust pass; forced
  PTY starts at 0 by 0, and the changed-host diagnostic exposed a documented
  fingerprint/profile-path retention defect. Exact source confirms that the
  redirected client cannot carry VT7's PTY dimensions or resize events, so S00
  rejects it for interactive SSH. S01 accepts SSH.NET 2026.0.0 for embedded
  interactive transport.
- [SSH.NET S01 result](validation/2026-09-14-sshnet-s01.md): the exact locked
  closure and notices are packaged separately from the application. Release
  self-test and repeated path-with-spaces batch launch pass locally. Corrected
  0.6 passes public-key-only and optional-password Windows 7 network runs.

## Evidence by stage

| Stage | Start with | Scope |
| --- | --- | --- |
| First executable | [Proof of life](validation/2026-09-10-proof-of-life.md) | Host/native/runtime and graphics probes. |
| Milestone 1 | [Viewport](validation/2026-09-10-viewport-proof.md), [cleanup](validation/2026-09-10-milestone-1-cleanup.md) | Static GDI core viewport and UI cleanup on tested setups. |
| Isolated Atlas | [Backend proof](validation/2026-09-11-atlas-backend-proof.md) | Fixed glyphs and device recreation, not full engine integration. |
| Font research | [Research index](research/README.md), [probe 0.13](validation/2026-09-11-marked-paint-probe.md) | Experiments retained for reference; joined-word geometry is not product policy. |
| C1/C2 | [Atlas viewport 0.3.0](validation/2026-09-12-atlas-viewport.md) | Minimum font boundary and actual core/controller/Atlas integration. |
| C3 repaint/recovery | [0.3.1 repaint](validation/2026-09-12-atlas-repaint.md), [0.3.2 recovery](validation/2026-09-12-atlas-recovery.md) | Bounded target passes; injected recovery is not real driver-loss evidence. |
| C3 scaling | [0.3.3 failures](validation/2026-09-12-atlas-settings.md), [0.3.4 correction](validation/2026-09-12-atlas-scaling-correction.md) | Actual Windows 7 96/120/144 DPI matrix accepted for 0.3.4 on the supplied setup. |
| Deferred reliability concern | [REL01 decision](architecture/2026-09-14-warp-development-deferral.md) | Hardware lifecycle passes; WARP resource failures remain. Accepted risk for continued development; conditional Milestone 7 review. |
| Current development | [KH01.2 read-only trust](validation/2026-09-22-known-hosts-kh01-2.md), [accepted typed SSH overlay](validation/2026-09-21-typed-ssh-overlay.md), [known-host specification](architecture/2026-09-21-openssh-known-hosts-management-spec.md), [KH01.1 foundation](validation/2026-09-22-known-hosts-kh01.md), [Milestone 5](../../ROADMAP.md#milestone-5-first-class-ssh) | Version 0.10.1/ABI 11 retains the accepted local, direct SSH.NET and typed-overlay baselines. KH01.2 loads the four default OpenSSH sources before both connection paths, accepts stored matches without fingerprint re-entry, preserves the exact unknown-host pin, and blocks changed/revoked/unreadable/policy states. Package 0.2 passed TURTLE but was rejected after both live SSH paths failed on NESSY. Package 0.3 pins publisher-built SSH.NET `2026.0.1-prerelease.6`, which contains the upstream Windows 7/.NET Framework MAC-reset fix. Its automated and live-path checks pass on NESSY and TURTLE, accepting KH01.2; KH01.3 durable first-contact trust is next. |
| Previous native target result | [Windows 7 resource retirement 0.1](diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result) | Supported capture completes; workers retire by 90 seconds and USER returns to 4, but 54 process handles above pre-warmup remain. No C3 or timed-soak acceptance. |
| Latest resource target result | [WPF reactivation 0.1](diagnostics/2026-09-14-resource-reactivation.md#supplied-windows-7-result) | Two integrated rounds complete, with 16 valid samples and three immediate failures. Both +180s handle/thread/GDI/USER counts match; private bytes rise 220 KiB. No permanent bound or C3 acceptance. |

Older records retain their dates, build numbers, reported environments and
acceptance boundaries. A pass on one version, machine, renderer or update tier
does not automatically qualify another. Local completion, Windows 7 completion,
resource acceptance and timed-soak acceptance are separate statements.

## Policies and inherited material

- [Project identity and goals](../../README.md).
- [Upstream provenance and synchronization](../../UPSTREAM.md).
- [Contributing and handoff maintenance](../../CONTRIBUTING.md).
- [Support and diagnostic reporting](../../SUPPORT.md).
- [Security reporting](../../SECURITY.md), [community conduct](../../CODE_OF_CONDUCT.md).
- [MIT code license](../../LICENSE), [third-party notices](../../NOTICE.md),
  [private fallback font provenance](../../oss/unifont/README.md).
- [General documentation index](../README.md): retained Microsoft Terminal
  specifications, build notes and user documentation are upstream references,
  not current VT7 features or required Windows 7 build steps.

`artifacts/` is ignored and is not part of a fresh clone. The handoff records
where local evidence was retained, what is preserved in versioned text and what
must be obtained separately. No public VT7 terminal release is claimed.
