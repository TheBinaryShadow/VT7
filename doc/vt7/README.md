# VT7 documentation - start here

Last reconciled: 2026-09-13, after the supplied Windows 7 resource retirement 0.1 result and verified log archival.

VT7 is the terminal application Windows 7 always deserved. It is currently a
static Atlas viewport proof, not yet an interactive terminal. The application
port is the priority; optional improvements belong in final polish/release triage.

## Read in this order

1. [Development handoff](HANDOFF.md): current source and artifacts, accepted
   results, unresolved C3 work, code map and the current bounded task.
2. [Roadmap](../../ROADMAP.md): milestone gates and the deferred-work register.
3. [Port-first plan](architecture/2026-09-12-port-first-plan.md): execution
   policy and the C1 through C5 checkpoint definitions.
4. [Building VT7](../../BUILDING.md): pinned tools, build/test commands and
   packaging precautions. Use `VT7.sln`, not the inherited OpenConsole build.
5. [Current stability record](validation/2026-09-13-atlas-stability.md): findings,
   negative results, evidence limits, package hashes and target comparison.

The handoff is the current resumption guide. The roadmap owns acceptance gates.
Dated validation records own what was actually tested. Research and historical
"next steps" are not authorization to replace the active plan or expand scope.
If these disagree, reconcile them against source and evidence, do not silently
choose the more optimistic status.

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
  The proposed next control uses two integrated lifecycle/idle rounds to test the
  retained baseline; no unchanged collection is requested.
- [Integrated package instructions](../../src/vt7/packaging/README.txt): source
  template for viewport candidates, not a substitute for an issued ZIP's identity.
- [Build/test tools](../../tools/README.md): VT7 helpers versus inherited tools.

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
| Active C3 work | [0.3.5 stability](validation/2026-09-13-atlas-stability.md) | Hardware lifecycle passes; integrated WARP resource growth remains unresolved. |
| Latest bounded diagnostic | [Windows 7 resource retirement 0.1](diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result) | Supported capture completes; workers retire by 90 seconds and USER returns to 4, but 54 process handles above pre-warmup remain. Integrated repeatability needs a bounded follow-up design; no C3 or timed-soak acceptance. |

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
