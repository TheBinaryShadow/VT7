# Execution decisions through 2026-10-12

[Roadmap](../../../ROADMAP.md) | [Documentation](../README.md)

This is my historical execution context, retained on 2026-10-13. It explains
earlier sequencing and evidence; the current handoff identifies the next task.

## Research-driven execution plan

The [September 12 port-first decision](../architecture/2026-09-12-port-first-plan.md)
updates the [September 11 plan](../architecture/2026-09-11-research-driven-plan.md).
It keeps the platform floor, upstream baseline, required product workflows, and
recorded test results. Milestones 0 through 6 retain their numbers; Milestone 7
adds final polish and release readiness, not a requirement to implement every idea.

Short term: complete the application port. The minimum 2C font adaptation and
TerminalCore-backed Atlas viewport in 2D are implemented and accepted as C1/C2
on the supplied Windows 7 setup. The
[September 14 development decision](../architecture/2026-09-14-warp-development-deferral.md)
authorized C4 / Milestone 3A session feasibility, now accepted on Windows 7,
and moves active work to 3B. WARP resource follow-up is deferred
under REL01 in Milestone 7; it no longer blocks feature development. C3 and
Milestone 2 retain their unpassed results and remaining qualification gaps.
Long term: improve the finished port deliberately, using retained research and
user feedback without making optional enhancements an indefinite release barrier.

The decision defines C1-C5 deliverable checkpoints. Reuse upstream policies and
existing tests; run new bounded experiments only for named compatibility or
integration questions. Optional typography research is no longer the next step.

Implementation checkpoint: [Atlas viewport 0.3.0](../validation/2026-09-12-atlas-viewport.md)
now connects the minimum font adapter and real AtlasEngine/controller to the
core and host. Local Debug/Release checks pass in GDI and four Atlas modes.
The supplied Windows 7 run now accepts C1/C2 on its tested configuration.
C3 repaint/cursor checks in 0.3.1 now have supplied Windows 7 acceptance.
The 0.3.2 automatic fallback/recovery slice also passes the supplied Windows 7
run at its tested scale. The 0.3.3 higher-scale viewport/recovery failures are
resolved in the accepted 0.3.4 matrix: all positive suites pass at measured
Windows 7 96/120/144 system DPI. The bounded scaling gate is closed on this setup.
The following C3 slice adds synchronized-output/wait-notify, idle/resource and
shutdown stress checks.
The [0.3.5 scheduling/stability slice](../validation/2026-09-13-atlas-stability.md)
now implements those bounded diagnostics. Hardware passes 100 lifecycles locally
and on the supplied Windows 7 setup. WARP completes the operations but fails its
resource-growth budget on both. Local handle traces identify Windows power-
notification and message-posting paths. On the development machine, a native-only
control reproduces growth with matched power registrations/unregistrations,
while its no-notification counterpart stays flat. The supplied Windows 7 native
control instead grows in both modes, with USER growth tracking more native
threads reporting input queues. Neither WPF nor the control's explicit power
subscription is required for the target reproduction. Attribution and boundedness
remained open at that checkpoint, when the timed soak was put on hold. The
later REL01 decision below changes development sequencing, not those results.
Quick, full-lifecycle and timed-soak profiles
are separate evidence, not interchangeable passes.
The development control still fails after the approved ESET inspection
exclusion, with its in-process monitor absent from the module samples. The
exclusion was removed. The native power/plain target comparison is now recorded.
The separate [resource lifetime comparison 0.2](../diagnostics/2026-09-13-resource-lifetime.md)
now implements repeated surface recreation versus reuse under a matched bounded
workload, with individual thread identities and input-queue observations.
The supplied Windows 7 pair completes and both modes grow. Reuse retains all
38 baseline thread identities through iteration 100 while eight existing
identities first positively report queues and USER increases by eight.
Repeated surface creation is not necessary for this growth. The subsequent
Windows 7 trace identifies the bounded allocation/queue-call path. Subsequent
[offline WARP inspection](../diagnostics/2026-09-13-warp-pool-lifetime.md)
connects its default/private pool branches, reusable work and destruction path.
The 32 target factory handles all report one pool address and a 67-second idle
timeout, beyond the final ten-second observation. The new
[resource retirement diagnostic 0.1](../diagnostics/2026-09-13-resource-retirement.md)
uses a new sampler and unchanged native 0.3.5 payload. Its
[supplied Windows 7 result](../diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result)
completes with a supported profile and zero invalid handles, recording mode 3,
callback drain/work close and wrapper free. All 34 baseline pool workers are
absent by 90 seconds after close; USER falls 38 to 4 and handles 141 to 107,
unchanged at 180 seconds. All 15 measured-growth Events have matching CLOSE
records on their opening worker TIDs and disappear by 90 seconds; all 34
captured WARP/GetThreadDesktop Events have the same closing-path evidence.
The residual 54 process handles above pre-warmup and integrated
WPF failure remain unresolved. The locally qualified
[WPF reactivation diagnostic 0.1](../diagnostics/2026-09-14-resource-reactivation.md)
now implements two existing 100-lifecycle rounds in one process, each followed
by 10/90/180-second closed observations. It retains one initial two-lifetime
warm-up, the fixed baseline and every immediate budget failure. The full local
run completes with eight failures retained; its second +180s sample is two
handles, one USER object, one thread and 3,846,144 private bytes above the first.
This is bounded local evidence, not a proven bound or Windows 7 acceptance.
The supplied Windows 7 run now completes in 655.156 seconds with three immediate
failures retained. Its two +180s states match at 1,314 handles, 13 threads, GDI 18
and USER 10; private bytes increase by 220 KiB. Nine late thread identities are
common and four differ. This answers the two-round count comparison on that
target, without proving handle identity, ownership or a permanent bound.
I have accepted this uncertainty for continued development and
stopped the dedicated tracing campaign. Further attribution is conditional
REL01 work, not the next task. No soak has run or is requested now; later
whole-product qualification does not require complete handle attribution first.
The [focused trace](../diagnostics/2026-09-13-resource-trace.md) supplies
a process-scoped CDB launcher using the unchanged 0.2 executable and 0.3.5 DLL.
The 0.1 Windows 7 preflight passes, but its trace stops at a first-chance
invalid-handle prompt before the workload. Trace 0.2 captures that exception
reaching unhandled second chance during startup, before native DLL load or WARP.
Trace 0.3 adds a separate startup control and activates handle tracing at the
pre-warmup checkpoint, before surface creation. Its supplied target capture
completes and passes corrected offline validation after a nested Token Type
parsing bug is fixed. It directly correlates eleven retained Event opens with
WARP/GetThreadDesktop setup calls on eleven existing worker identities becoming
queue-positive. No target repeat is needed. Long-term behavior and retained ownership remain
uncertain and are recorded for REL01 release review. Original test failures
remain failures under the development deferral. Do not disable
notifications, IME or WARP workers as a fix.
This does not close Milestone 2 or start another optional typography experiment.

Before substantial local-session integration or daily-driver UI construction,
3A must resolve local-console fidelity, the SSH integration choice, and
input/session contracts. P01 selects WinPTY for Windows 7 legacy-console
sessions within explicit limits; I01 closes the Windows 7 Croatian input
boundary; and S00 rejects unmodified redirected Windows OpenSSH for interactive
SSH after accepting its command transport, trust and lifecycle behavior. I approved SSH.NET 2026.0.0 and its permissive closure for S01. This brings SSH
feasibility forward, not full Milestone 5 delivery.
Tests, privacy-aware diagnostics, dependency audits, and output-security policies
belong with each implementing change; Milestone 6 qualifies the assembled product.

Use the experiment IDs in the [validation backlog](../research/20-validation-and-experiments.md)
to connect decisions, implementations, and exact Windows 7 evidence. Research
recommendations and unchecked gates are not implemented or accepted features.

### Blocker and improvement triage

A blocker prevents an agreed workflow, Windows 7 execution, terminal/text
correctness, safe interaction, stability, security, baseline accessibility, or
legal distribution. It stays in the implementing milestone. Optional appearance,
new behavior beyond upstream, and optimizations with a correct baseline go to
Milestone 7 with evidence and a follow-up condition. Do not hide a port regression
as polish or silently reduce a promised workflow. Investigate uncertain cases
with a bounded comparison before deciding. Historical research priorities are
not additional current gates.

REL01 is an explicit development-risk deferral approved on September 14. The
known WARP investigation-budget failures do not by themselves block C4/3A or
subsequent feature work. Reproducible exhaustion, continuing accumulation,
crashes/hangs, shutdown failure or a concrete lifetime defect can reopen it.
Milestone 7 reviews ordinary product-qualification evidence and records a
disposition; it does not automatically require another tracing campaign.

