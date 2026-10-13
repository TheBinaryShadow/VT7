# Milestone 7: Polish and release readiness

[Roadmap](../../../ROADMAP.md) | [Documentation](../README.md)

These are the detailed requirements and recorded results for this milestone.
An accepted slice does not close an unchecked parent requirement.

## Milestone 7: Polish and release readiness

The final checkpoint before the first public release, repeated for later releases
and 1.0. Milestone 6 supplies whole-product qualification; this milestone reviews
the assembled user experience, chooses bounded polish work, and makes the release
decision. Neither postpones security or correctness fixes from earlier milestones.
UT01, UI01 and SSHUX01 are required implementing-milestone work and must be complete before
this optional polish checkpoint; they cannot be deferred as visual refinements.

- [ ] Review required workflows, known limitations, prerequisites, diagnostics,
  accessibility and first-run/documentation clarity in the assembled application.
- [ ] Review REL01 against product-qualification evidence and record acceptance
  with measured limits, a named investigation/fix, or an explicit further risk
  disposition. A review does not automatically reopen tracing.
- [ ] Triage every deferred item below: select for this release, defer to a named
  post-release backlog/milestone, or reject with a reason. Record the decision;
  an unchecked optional improvement is not automatically a release blocker.
- [ ] Finish the selected polish scope and revalidate affected Windows 7 paths.
  Do not introduce an experimental rendering/interaction policy without its tests.
- [ ] Verify the candidate package, provenance/licenses, evidence, release notes
  and support instructions. Claims must distinguish implemented, tested and deferred.
- [ ] Record the release scope and go/no-go decision. All required release gates
  must pass; a scope reduction needs explicit approval, not a polish label.

Exit criterion: required qualification passes, the selected polish is complete,
and every remaining idea has an explicit disposition. Local engineering packages
remain proofs, not public alpha releases. Optional enhancements may follow after
release; their mere presence in this register does not promise delivery in 1.0.

### Deferred reliability review

- **REL01: WARP resource lifetime and sustained-use qualification.** Status:
  **accepted risk for continued development; tracing stopped; conditional
  follow-up at release readiness**. Approved by me on 2026-09-14;
  see the [decision and evidence summary](../architecture/2026-09-14-warp-development-deferral.md).
  This is a reliability concern, separate from optional cosmetic POL work.
  The full Windows 7 two-round test has identical +180s handle/thread/GDI/USER
  counts and +220 KiB private bytes, with three immediate budget failures still
  recorded. The Windows 10 pair has small positive late deltas. No permanent
  bound or complete ownership is claimed, and no code fix is declared.
  Preserve issued artifacts, original limits, baseline/warm-up and failure exits.
  Continue 3B and feature development now. Milestone 6 supplies ordinary
  sustained-session and tab/pane resource evidence; Milestone 7 reviews it.
  Reopen earlier for reproducible continued accumulation, exhaustion,
  crashes/hangs, shutdown failure, material responsiveness loss, or an affected
  lifetime change that invalidates the evidence. A known threshold crossing
  alone does not mandate another trace. If reopened, state a finite question
  and stopping criteria first; the discussed best-case 2-3 target rounds are
  an estimate, not a mandatory checklist or guarantee. A release decision can
  accept explained, adequately measured behavior without attributing every
  internal Windows handle. Record any remaining risk explicitly; WARP support
  and required stability are not silently removed from the product scope.

### Deferred improvements register

Entries normally start as **deferred, awaiting release triage**, not active port work.
The 2026-10-05 UT01 decision promotes necessary POL04/POL05 parity capabilities
to required pre-1.0 work; only their beyond-upstream refinements remain deferred.
Keep IDs stable. Add observations here as they arise with user impact, evidence,
baseline behavior, proposed follow-up and a blocker trigger. A substantial separate
workstream may receive its own post-release milestone after an explicit decision.

- **POL01: Enhanced Arabic context and joined-word layout.** Better connected
  cursive output across style/font boundaries. Preserve the upstream logical-grid
  baseline now. Retain [0.10 context](../validation/2026-09-11-arabic-context-probe.md)
  and [0.11 joined-span](../validation/2026-09-11-joined-span-probe.md) evidence.
  Later compare context repair, span formation, centering and compression with
  the integrated baseline. Promote an actual adapter-induced shaping regression
  affecting the required corpus, not the desire for new paragraph-style layout.
- **POL02: Interaction and paint for experimental joined spans.** The
  [0.13 highlight discrepancy](../validation/2026-09-11-marked-paint-probe.md)
  shows that correct source selection need not paint the expected visible glyph.
  Keep ordinary core-grid cursor/selection now; defer the proposed visible-position
  experiment, spare-space/edge clicks and mark/ligature ownership. These must be
  resolved before adopting POL01's alternate layout. Incorrect source copy or
  cell mapping in the baseline is an immediate blocker in its owning milestone.
- **POL03: Cross-style lam-alef and glyph painting.** Preserve
  [0.12 comparisons](../validation/2026-09-11-cross-style-ligature-probe.md)
  and 0.13 marked paint. Same-outline painting remains a candidate; different-
  outline spatial hybrids are not adopted. Later investigate seams and deliberate
  style ownership without slicing source clusters. Baseline source loss or an
  adaptation-induced style/cell regression is blocking; optional hybrid styling is not.
- **POL04: Fallback glyph appearance and fitting.** Retain the original glyph
  discrepancy, [font coverage findings](../research/2026-09-11-font-coverage-and-fitting.md),
  [0.6 geometry](../validation/2026-09-11-geometry-probe.md) and
  [0.9 horizontal fitting](../validation/2026-09-11-horizontal-fitting-probe.md).
  The missing U+1F600 cause and bounded private-font proof are established; the
  minimum Atlas fallback is accepted in the supplied 0.3.0 Windows 7 run.
  Retain the [2026-10-05 U+12032 prompt finding](../validation/2026-10-05-ssh-lifecycle-sl01-1.md#separate-ssh-prompt-glyph-finding)
  as a required UT01.2 supplementary-script fixture. Its UTF-8 bytes are
  f0 92 80 b2; this pre-existing coverage gap
  occurs in both current and older SSH packages, outside the bounded private
  symbol fallback. It does not invalidate SL01.1 lifecycle acceptance.
  Required upstream coverage/fitting belongs to UT01, not optional polish.
  Keep the primary grid and upstream overhang policy.
  Review squeezed one-cell symbols, pixel-derived shapes and stacked-mark appearance
  later. Missing required fallback, illegible required text caused by my port,
  source loss or stale/erased neighbor pixels remain renderer blockers.
- **POL05: Advanced font and bidi capabilities.** Current-upstream repertoire,
  ordered family fallback, supported color/emoji and variable-axis behavior are
  now required UT01 work. The present static/monochrome, single-primary-family
  viewport is an initial implementation limit, not the final parity target.
  See the [UT01 plan](../architecture/2026-10-05-upstream-text-and-font-parity-plan.md),
  [geometry contract](../architecture/2026-09-11-text-geometry-contract.md)
  and [font research](../research/07-font-assets-and-emoji.md).
  Broader behavior beyond the measured upstream reference, including a new full
  paragraph-bidi design, remains separately scoped. No universal glyph-repertoire
  claim is made. Required-corpus failures and unsupported required font settings
  block their implementing gates rather than receiving a polish deferral.
- **POL06: Optional presentation and performance refinements.** Retain the
  conservative complete-frame HWND presentation baseline. Evaluate dirty-region/
  scroll optimizations and visual refinements only against integrated measurements
  and the [renderer acceptance plan](../architecture/2026-09-11-renderer-assessment.md).
  Idle spinning, unbounded growth, recovery loops or unusable responsiveness remain
  blockers; an optimization is optional when the correctness/performance gates pass.
- **POL07: Richer renderer failure diagnostics.** The
  [0.3.2 recovery slice](../validation/2026-09-12-atlas-recovery.md) separates
  transient errors, fatal state, requested/actual backend and device generations.
  Retain this bounded reporting for port work. Later add exact core/controller
  stage provenance and the driver's device-removal reason so a historical Atlas
  HRESULT is not mistaken for a newer non-Atlas failure's cause. Broader injection
  sites belong with that work. A failure hidden as success, repeated recovery loop
  or inability to diagnose a current port blocker promotes the relevant fix now.

