# Port first, improve deliberately

Decision date: 2026-09-12. Status: approved documentation and planning direction.
This updates the sequencing in the [September 11 plan](2026-09-11-research-driven-plan.md)
and geometry experiments. The [roadmap](../../../ROADMAP.md) owns milestone
completion and the deferred-work register. No application behavior, upstream
baseline, package, license, or test result changes with this decision.

## Short-term goal

Finish the Windows 7 application port. Reuse the pinned upstream terminal core,
parser, buffer, renderer behavior, and interaction policies wherever possible.
Adapt the host, graphics/font interfaces, synchronization, and session boundaries
that cannot run unchanged on Windows 7. Upstream-first does not mean merging
new upstream commits or reproducing every modern Windows Terminal feature.

The next deliverable is the real AtlasEngine rendering TerminalCore content in
the VT7 viewport on Windows 7, followed by renderer acceptance and interactive
sessions. It is not another optional typography probe. The fixed-glyph Atlas
harness and the separate 0.13 font probe do not yet establish that integration.

## Long-term goal

Deliver a dependable, welcoming terminal that makes Windows 7 users' everyday
work better. Keep the agreed local-shell, SSH, interface, accessibility, and
portable-package goals. Preserve valuable ideas and evidence for deliberate
improvement after the port works. A faithful port is the foundation, not a ceiling
on future quality, and not a promise of exact current-upstream parity.

## Classify work before starting it

- **Port or release blocker:** prevents an agreed workflow, Windows 7 execution,
  correct terminal state/text, safe input/selection, stability, bounded lifecycle,
  security, accessibility baseline, or legal distribution. Fix it in the owning
  milestone, with tests proportional to the changed boundary.
- **Non-blocking improvement:** enhanced behavior, cosmetic refinement, optional
  capability, or optimization with a correct baseline already available. Add it
  to Milestone 7's deferred-work register instead of extending the current gate.
- **Uncertain:** run the smallest comparison needed to identify the affected
  workflow and whether the defect comes from our adaptation, inherited behavior,
  or an experimental departure. Record the result, then integrate or defer.

Reusing upstream is not permission to ship a security defect or waive a required
workflow. Equally, an inherited typography limitation is not automatically a
Windows 7 port blocker. A changed implementation must not corrupt source text,
misreport cells, or leave lasting rendering damage to pass a visual test.

For each new non-blocking observation record: an ID, the problem and user impact,
source/evidence links, current workaround or baseline behavior, proposed follow-up,
and the condition that would promote it to a blocker. Add a separate milestone
only for a substantial independent workstream, not for each interesting finding.
Get an explicit scope decision before changing a promised workflow or platform floor.

## Revised immediate checkpoints

| Checkpoint | Deliverable and evidence | Boundary |
| --- | --- | --- |
| C1: Minimal font boundary (2C) | Remove mandatory newer font interfaces; choose and integrate Windows 7 face selection while retaining upstream shaping direction, primary grid, and cluster advance fitting. Prove owned data, fallback and missing-asset behavior, source/cell integrity, and representative mixed-script output. | Reuse the 0.8 candidate where it fits; do not require joined-span or visual-bidi experiments. Audit the actual full-engine paths, not only the standalone mapper. |
| C2: First Atlas viewport (2D plus required 2B work) | Connect real AtlasEngine, renderer controller and IRenderData to TerminalCore/native HWND, with Windows 7-safe waits, metrics, redraw and teardown. Package a visible Windows 7 build. | Run full-engine load/import checks and hardware/WARP smoke tests. This is integration evidence, not Milestone 2 completion. |
| C3: Renderer acceptance (2E/2F and remaining 2A/2B gates) | Integrated repaint, cursor/grid alignment, fallback, recovery, resize, DPI/theme, and bounded idle/stress checks on the declared test setups. | Compare against inherited policies; triage optional appearance differences into Milestone 7. No correctness or lifecycle gate is waived. |
| C4: Session choices (3A) | Bounded local-console, OpenSSH byte/control path and input experiments plus ownership/security contracts. | Reuse existing implementations; choose the integration from evidence, not a complete new backend research program. |
| C5: Usable application (3B/3C, 4, 5) | Required local shells, input, daily-driver interface and direct SSH, tested end to end. | Keep renderer and transport fidelity separate. Hardening accompanies each change. |

Checkpoints are deliverables, not new milestone numbers. Schedule experiments
only to resolve a named blocker or integration choice. State the question,
smallest fixture, pass/fail criterion and next action before building a probe.
Stop when the decision is supported; do not automatically add a new experiment
for every observation. Reuse accepted evidence and rerun affected regressions,
without treating old results as proof of a newly integrated path.

## Typography research is retained, not production policy

Probes 0.10 through 0.13 explored context repair, whole-word fitting/centering,
cross-style lam-alef and source-to-paint ownership. Their recorded Windows 7
passes remain valid for the tested experiments. They did not implement production
cursor/selection behavior or establish that their choices match upstream.

The proposed next visible-position/source interaction experiment is deferred
under POL02 in Milestone 7. Its highlight mismatch is a blocker to adopting that
experimental layout, not a prerequisite to integrating upstream-style Atlas.
Different-outline hybrids remain unaccepted; same-outline paint is a research
candidate, not a shipping commitment. The 0.9 fitting strategy is also optional
unless an integrated defect demonstrates a need for it.

Actual source loss, broken core-cell mapping, mandatory missing APIs, unsafe
resource ownership, or lasting repaint corruption remain current blockers.
Ordinary grid-based cursor, selection, copy, IME and accessible ranges must
still work in their implementing milestones. Deferring an enhanced mapping
does not defer those essential application features.

## Release readiness without an endless polish queue

Milestones 0 through 6 retain their identifiers and evidence. Milestone 7 is the
final polish and release-readiness checkpoint before the first public release,
revisited for subsequent releases and 1.0. At that checkpoint, fix required
release defects and select a bounded set of optional improvements. Give every
remaining idea an explicit defer/reject decision or a post-release milestone.
An unchecked optional idea does not block a release by itself. Security and
correctness are addressed when discovered, not postponed until this checkpoint.

Historical research priorities and validation procedures describe their original
scope. Read them with this decision and the current roadmap; they are not orders
to execute all suggested experiments before proceeding with the port.
