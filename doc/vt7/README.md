# VT7 documentation - start here

Last reconciled: 2026-09-14, after accepting SSH.NET S01 on Windows 7.

VT7 is the terminal application Windows 7 always deserved. Version 0.3.7 now
adds the generation-checked outbound queue and native child-HWND input/resize
adapter to the 0.3.6 inbound stream. It has no process backend yet. The application
port is the priority; optional improvements belong in final polish/release triage.

## Read in this order

1. [Development handoff](HANDOFF.md): current source and artifacts, accepted
   results, deferred C3/REL01 concern, code map and the current C4/3A task.
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
9. [Input I01 characterization](validation/2026-09-14-input-i01.md): exact
   package and verified Windows 7 Croatian HR Latin evidence, the downlevel
   `ToUnicodeEx` result and the accepted native-HWND input/resize contract.
10. [Session outbound foundation](architecture/2026-09-14-session-outbound-foundation.md):
    ABI 10 input encoding, bounded generation ordering, control suppression,
    focus/resize ownership and accepted Windows 7 evidence.
11. [OpenSSH S00 evaluation](validation/2026-09-14-openssh-s00.md): accepted
    Windows 7 command transport, trust and lifecycle evidence; exact-source
    rejection of redirected interactive PTY geometry; and the S01-accepted
    SSH.NET candidate.
12. [SSH.NET dependency and license audit](research/2026-09-14-sshnet-license-audit.md):
    exact 2026.0.0 net48 closure, package hashes, third-party terms and the
    project-wide permissive dependency decision.
13. [SSH.NET S01 evaluation](validation/2026-09-14-sshnet-s01.md): isolated
    diagnostic design, 0.5 assertion findings, accepted 0.6 Windows 7 results,
    credential boundary and production teardown contract.
14. [Third-party licensing policy](architecture/2026-09-14-third-party-licensing-policy.md):
    standing owner decision, review triggers, packaging requirements, current
    component inventory and acknowledgement rule.

The handoff is the current resumption guide. The roadmap owns acceptance gates.
Dated validation records own what was actually tested. Research and historical
"next steps" are not authorization to replace the active plan or expand scope.
If these disagree, reconcile them against source and evidence, do not silently
choose the more optimistic status. The September 14 owner-approved REL01
decision changes the development dependency; it does not rewrite failed tests.
Proceed to C4/3A without another WARP trace prerequisite.

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
| Current development | [completed S00](validation/2026-09-14-openssh-s00.md), [accepted S01](validation/2026-09-14-sshnet-s01.md), [session outbound 0.3.7](architecture/2026-09-14-session-outbound-foundation.md), [session stream 0.3.6](architecture/2026-09-14-session-stream-foundation.md), [completed P01](validation/2026-09-14-winpty-p01.md), [completed I01](validation/2026-09-14-input-i01.md), [ownership/source review](architecture/2026-09-14-session-ownership-and-source-review.md), [C4 / Milestone 3A](../../ROADMAP.md#3a-session-feasibility-and-contracts) | The native HWND/outbound foundation passes on Windows 7. S00 accepts exact Microsoft 10.0p2 command transport and rejects its redirected interactive PTY path. S01 accepts SSH.NET 2026.0.0 for embedded interactive transport; the 3A session-identity/lifetime split is next. |
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
