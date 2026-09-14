# Continue development with WARP resource follow-up deferred

Decision date: 2026-09-14. Status: approved by the project owner after reviewing
the Windows 7 reactivation result and the cost of further investigation.
Tracking item: **REL01** in [Milestone 7: Polish and release readiness](../../../ROADMAP.md#deferred-reliability-review).

## Decision and development sequence

Continue application development now. Stop the dedicated WARP resource tracing
campaign and defer any further attribution to REL01. The current resource
concern is accepted as a known risk for continued development. It is not a
claim that WARP is fixed, leak-free, fully qualified, or ready for public release.

The next development checkpoint is **C4 / Milestone 3A: session feasibility and
contracts**. Establish the local-console transport and input behavior, evaluate
the direct OpenSSH byte/control path, and define session ownership, cancellation
and output-security contracts. Then proceed to the existing local-session and
application milestones. The user's Croatian HR Latin layout is a primary input
fixture, including AltGr, dead keys and composed text; Ctrl+C and resize belong
in the session feasibility checks. A visible prompt alone is insufficient.

Do not request another handle inventory, debugger capture, reactivation rerun,
new hardware configuration or timed soak as a prerequisite to starting that work.
Preserve the renderer teardown fix and run regressions relevant to new changes.
An affected correctness, security or reproducible stability failure still needs
attention in the work that exposes it.

C3 and Milestone 2 are not relabeled complete. The existing resource failures and
remaining theme/high-contrast, broader environment and release-qualification
gaps stay recorded. Their incomplete status does not impose a blanket serial
dependency on C4/3A. This explicitly supersedes the earlier instruction to
finish WARP attribution before proceeding with development.

## Findings supporting the decision

The dated records own exact environments, identities, raw metrics and limits.
The following findings are the basis for this risk decision, not new tests.

| Evidence | Established result and limit |
| --- | --- |
| [Integrated scheduling/stability 0.3.5](../validation/2026-09-13-atlas-stability.md) | A real shutdown-order defect retaining `DwmDxBltEvent_*` resources was corrected. Destroy the native HWND on its owner while the presentation worker is alive, then release graphics on that worker and join it. Quick hardware/WARP and hardware 100-lifecycle checks pass locally and on the supplied Windows 7 setup. Remaining WARP growth fails investigation budgets on both. |
| [Native isolation](../diagnostics/2026-09-13-resource-investigation.md) | Windows 10 power/plain controls separate, but both modes grow on Windows 7. The target growth needs neither WPF nor explicit power subscriptions. The security-exclusion control did not remove the development-machine failure; the exclusion was removed. A discarded IME-disable experiment did not solve handles. No input/security workaround is adopted. |
| [Recreate/reuse comparison 0.2](../diagnostics/2026-09-13-resource-lifetime.md#supplied-windows-7-comparison) | Growth also occurs with one reused surface. Additional positive queue observations occur on existing baseline identities. Repeated surface creation is not a necessary condition for this target behavior. |
| [Focused trace 0.3](../diagnostics/2026-09-13-resource-trace.md) | Eleven measured Event opens correlate with WARP presentation tasks calling USER32 `GetThreadDesktop` on existing pool-worker identities that become queue-positive. Corrected offline validation accepts the retained capture. This supplies a bounded call path, not a general leak diagnosis. Earlier incomplete collectors and their corrections remain documented. |
| [WARP pool inspection](../diagnostics/2026-09-13-warp-pool-lifetime.md) | Device/work construction and cleanup paths were identified. The 32 target worker-factory handles reference one pool, not 32 pools. The observed idle timeout is not a guaranteed release deadline. |
| [Native retirement 0.1](../diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result) | Windows 7 records actual mode 3 and callback drain/work close/wrapper free. All 34 baseline pool workers are absent by +90s, with matching worker-exit CLOSE records for all 34 captured WARP/GetThreadDesktop Events. USER returns from 38 to 4; handles fall from 141 to 107 and remain there at +180s. A residual of 54 handles above pre-warm-up remains unexplained. |
| [Full WPF reactivation 0.1](../diagnostics/2026-09-14-resource-reactivation.md#supplied-windows-7-result) | Windows 7 completes two 100-lifecycle rounds, 2,000 resizes, 1,000 tab trips and all 16 samples in 655.156 seconds. Worst close is 8 ms; all 202 companion WPF reports pass. Three immediate resource checkpoints still fail. |

The equivalent Windows 7 late states, 180 seconds after each work round, are:

| Resource | Round 1 | Round 2 | Difference |
| --- | ---: | ---: | ---: |
| Handles | 1,314 | 1,314 | 0 |
| Threads | 13 | 13 | 0 |
| GDI objects | 18 | 18 | 0 |
| USER objects | 10 | 10 | 0 |
| Private bytes | 136,495,104 | 136,720,384 | +225,280 (220 KiB) |

Nine of the 13 late thread identities are common and four differ. None of the
40/42 queue-positive `ntdll.dll+F8DE0` identities at the respective ends of work
appears at that round's +180s sample. This supports substantial transient
resource growth receding during idle. Sequential snapshots do not prove thread
exit events or the identity and ownership of each retained handle. Failed GUI
queries are unavailable evidence, not queue absence.

The final integrated state remains 1,090 handles above pre-warm-up. Full WPF,
framework initialization, per-window probes and observer effects are included;
this is not a WARP-only total and is not comparable directly with the native
residual of 54. The Windows 10 qualification also remains separate: its second
late state grows by two handles, one thread, one USER object and 3,846,144 private
bytes. Two late observations do not prove a permanent bound on either system.

The exact target failures remain round 1 / 100 (+36 handles, limit +32), round
2 / 75 (+9 threads, limit +8), and round 2 / 100 (+34 handles and +9 threads).
These are investigation-budget failures, not demonstrated OS resource exhaustion.
The original limits, warm-up, fixed baseline, exit codes and negative controls
remain unchanged. Accepting development risk does not turn a failed test green.

## Why Milestone 7, and when to reopen

REL01 belongs in Milestone 7's **release-readiness reliability review**, separate
from the optional POL appearance/enhancement items. The unknown is sustained
application behavior and any retained resource ownership that matters to it.
It does not require a new trace merely because a known immediate count crosses
the same old diagnostic threshold.

Milestone 6 already includes long-running sessions, repeated tabs/panes, WARP
coverage and whole-product resource measurements. Use that ordinary qualification
and relevant development results at the Milestone 7 review. Reviewing REL01
does not automatically restart the tracing campaign. Further investigation is
conditional on evidence or a specific unresolved release decision.

Reopen sooner if relevant workloads show:

- Reproducible continued resource accumulation across equivalent settled states,
  or material sustained growth during active use suggesting exhaustion.
- Resource exhaustion, crashes, hangs, shutdown failures or significant
  responsiveness degradation plausibly connected to this lifetime path.
- A concrete VT7-owned lifetime defect, or a renderer/session change that
  invalidates the cleanup and retirement evidence.

At release review, record one explicit disposition: accept the observed behavior
with the measured workload/environment limits; investigate a named remaining
question; or fix a demonstrated defect and validate the change. A further
deferral needs a documented risk/scope decision. Do not silently drop WARP
support or claim untested hardware/Windows configurations. Complete attribution
of every internal Windows handle is not a release criterion by itself.

The timed soak remains **not run**. There is no immediate soak request. Later
sustained-use qualification need not wait for complete handle attribution.
The issued runners and their gate/exit behavior remain frozen; any necessary
future harness change must preserve the old results and have a distinct identity.

## Bounded plan only if investigation becomes necessary

The estimate discussed was **two or three additional target-machine rounds in
the best case**, each with local preparation, validation and log review. It was
not a guarantee, a required remaining checklist, or authorization to run them now.

If reopened, choose only the measurements needed for the named decision. The
candidate sequence is one focused retained-handle inventory if attribution is
needed, one sustained active/idle observation if existing application evidence
does not answer boundedness, and a confirmation or fix-regression run if needed.
Set the question, pass/fail criteria, safety limits and stopping decision before
building. Reassess after at most three target rounds instead of automatically
creating another diagnostic for each unexplained observation.

If those runs establish repeatable resource levels, required operations and
clean shutdown over an adequate declared workload, acceptance may require no
new code fix. If they reveal continuing growth, the resulting defect needs a
separate implementation/retest estimate. No fixed number of tests can guarantee
that every newly discovered defect will be resolved.

## Evidence and resumption

The [reactivation record](../diagnostics/2026-09-14-resource-reactivation.md#archive-and-independent-validation)
links the 207-file, 883,594-byte verified target archive, package/report hashes,
PowerShell validator result and independent resource/identity analysis. The
[retirement record](../diagnostics/2026-09-13-resource-retirement.md#supplied-windows-7-result)
retains its separate 17-file archive and handle-close histories. Raw failures,
partial captures, source snapshots, PDBs and issued packages are preserved;
`artifacts/` is local ignored evidence and is not present in a fresh clone.

Use [HANDOFF.md](../HANDOFF.md) for the next task and the
[roadmap](../../../ROADMAP.md) for gates. This decision supersedes earlier
mandatory-next-trace and attribution-before-development instructions in dated
records. It does not rewrite their findings, change the upstream baseline,
alter application code, or authorize a new diagnostic package.
