# Research-driven development plan

Current execution checkpoint, September 12: the supplied
[0.3.0 Windows 7 run](../validation/2026-09-12-atlas-viewport.md) accepts the bounded
C1/C2 font/core/Atlas integration. [0.3.1](../validation/2026-09-12-atlas-repaint.md)
passes the supplied Windows 7 repaint/cursor checks. The
[0.3.2 recovery slice](../validation/2026-09-12-atlas-recovery.md) also passes supplied target testing.
The [0.3.4 scaling matrix](../validation/2026-09-12-atlas-scaling-correction.md)
now passes all positive suites at actual Windows 7 96/120/144 DPI on the tested
setup, resolving the recorded 0.3.3 failures. Scheduling/idle/resource/shutdown
checks are next; theme and broader renderer qualification remain open.
This status supersedes next-task wording in the dated
assessment/plan below, without retroactively changing its original evidence.

Decision date: 2026-09-11. Status: approved planning direction, implementation
pending. This records the accepted review of the [research collection](../research/README.md).
The [roadmap](../../../ROADMAP.md) owns the execution checklist and completion
state. Research documents explain the evidence and alternatives; validation
records own runtime results. This planning change ran no application tests.

Updated sequencing, 2026-09-12: the [port-first decision](2026-09-12-port-first-plan.md)
supersedes this document's next-task wording. Reuse upstream behavior, implement
the minimal Windows 7 font boundary, then integrate AtlasEngine/controller with
TerminalCore. Optional typography and new interaction policies move to Milestone 7.
The contracts and milestone identities below remain; historical experiments are
not all prerequisites to integration. No existing result is relabeled or rerun.

## What stays unchanged

- Windows 7 SP1 x64 and the declared prerequisite/test tiers remain the target.
- TerminalCore/parser/buffer, the WPF/native HWND boundary, and the Atlas port
  remain the working architecture. No upstream merge or system-wide shim is chosen.
- The project remains MIT licensed, with existing attribution and component
  licenses retained. Evaluating a dependency does not add its code or notices.
- Milestone 1 acceptance and the fixed-glyph Atlas backend evidence keep their
  recorded scope. No new renderer, input, local-session, or SSH gate is closed.
- Command Prompt, Windows PowerShell 5.1, PowerShell 7.2.24 as the primary 7.x
  target, and first-class direct SSH remain required product workflows.

## Decisions

### 1. Continue the renderer, define shared text geometry

Proceed with 2C, including the previously deferred missing-glyph investigation.
The missing-glyph cause is now recorded and bounded fallback probes have passed.
Use that evidence for the minimal production adapter; choose it only after retained run ownership,
cluster/cell mapping, correctness, and cost are understood. Explicit family
mapping plus analyzer shaping remains a comparison candidate.

The core owns logical cells. Renderer pixels, cursor, selection, copy/search
ranges, mouse coordinates, IME placement, accessible ranges, and session resize
must derive from the same text/grid contracts. Preserve source text independently
of font coverage. Define contracts now without making Milestone 2 depend on a
finished IME, accessibility provider, or session backend.

Do not introduce paragraph-style bidi reordering accidentally through layout.
Record the inherited policy and versioned width/cluster behavior. Color emoji,
variable axes, and full bidi behavior need separate release-scope decisions.

### 2. Separate renderer and transport fidelity

Maintain a capability ledger covering parser recognition, core representation,
rendering, host actions, and availability per backend. A parsed sequence is not
automatically a usable feature. Distinguish tested, untested, and unavailable.

WinPTY is the first local candidate. Measure the native library/agent boundary
using child-console, stream, and final-core evidence before full integration.
Its screen reconstruction must not be presented as arbitrary lossless VT.
Keep the backend replaceable and investigate required workflow failures rather
than quietly accepting them as permanent limitations.

Direct SSH must avoid that screen-reconstruction path. The ambitious renderer
and direct-SSH color/Unicode targets remain; local capability claims reflect
measured end-to-end behavior, not the renderer's feature list.

### 3. Evaluate OpenSSH before building the daily-driver interface

The [OpenSSH reassessment](../research/22-win32-openssh-reassessment.md) makes
Microsoft Win32-OpenSSH the first SSH candidate to evaluate in 3A/S00, not a
selected shipping dependency. Modern SSH cryptography is an implementation
capability to validate, not a reason to build our own cryptographic algorithms.

Compare a known-good console run with direct I/O using exact versioned binaries.
Prove intact remote terminal bytes, initial dimensions, live window-change,
prompt/diagnostic routing, host-key decisions, and cancellation. A login or
forced PTY request alone is insufficient. Do not inject resize commands into
the shell or guess authentication state from arbitrary localized terminal text.

Choose among an unmodified external client, a narrow maintained helper adaptation,
and an embedded library based on those results and maintenance cost. An external
process is first-class when its byte and control paths meet the contract.
OpenSSH's protocol/trust machinery can be reused; VT7 still owns deliberate
configuration, UX, lifecycle, and integration. The release/support label,
advisories, licensing, and future update responsibility need explicit review.
Windows 7 compatibility is not an OS security-support guarantee. SSH crypto
does not change any separate WinHTTP/.NET HTTPS requirements.

### 4. Establish input, ownership, and trust before real sessions

3A owns the written session contract: decoder/parser/input state per session,
ordered writes and replies, bounded queues and history, backpressure, latest-grid
resize, stage-specific cancellation, and drain/exit/teardown ordering. Callbacks
must not outlive their owner or follow the currently selected pane by accident.

Investigate the inherited ToUnicodeEx flag assumption before input integration.
Separate committed text from non-text keys and resolve shortcuts once. Choose
an IME owner and accessible-range design early; deliver local input/IME in 3C
and native accessibility in 4, with direct-SSH input revalidation in 5.

Before connecting real output, define explicit policies for OSC clipboard access,
hyperlinks, titles, working-directory metadata, and large OSC/DCS payloads.
Authenticated remote output is still untrusted desktop-action data. Replay must
disable external actions by default. Diagnostics must not routinely record
terminal content or credentials; dumps and detailed captures need opt-in sharing.

### 5. Test continuously, qualify the whole product at the end

Add tests and diagnostics with the subsystem, including behavior-level API audits
for flags, metrics, and method combinations. Pin actual binaries, data, and fonts.
Check clean-machine dependency closure when adding runtimes, then qualify the
complete release on the minimum image in Milestone 6. Existing fully updated
machines do not alone certify the exact prerequisite floor.

## Execution and experiment mapping

Experiment definitions and evidence requirements remain in the
[validation backlog](../research/20-validation-and-experiments.md).

| Stage | Experiments / decision evidence | Completion boundary |
| --- | --- | --- |
| 2C | F01 evidence, remaining production F02 | Minimum Windows 7 font/cell adapter with inherited shaping/grid policies; enhanced typography is deferred, not an integration gate. |
| Remaining 2B/2D/2E/2F | G01, G02, T01 | Extend existing backend evidence to integrated redraw, scheduling, ownership, recovery, and visual acceptance. Do not repeat accepted checks merely to rename them. |
| 3A | P01, I01, S00 plus written contracts | Local fidelity and SSH architecture choices before substantial 3B or 4 work; no production SSH claim. |
| 3B/3C | U01, P02, I01, I02; initial paste/output-policy checks | Required local shells/native apps, input/IME, ordered streaming, bounded lifecycle and safe host actions. |
| 4 | A01, C01, D01; U01 range checks | Usable panes/profiles/settings, native accessible text, cluster-safe copy/search and persistence. |
| 5 | S01 and direct-SSH U01/I01/I02/C01 coverage | Selected SSH implementation passes trust, authentication, terminal fidelity, resize, and failure acceptance. |
| Every runtime addition and 6 | L01 and extended regression/soak matrix | Dependency closure, privacy, exact package evidence, and complete-product qualification. |
| 7 | Deferred POL01-POL06 and new observations | Bounded polish selection, explicit disposition of optional work, and release readiness. |

Priority labels in original research are not a global instruction to execute
everything immediately. In particular, SSH selection moves forward to 3A,
accessibility contracts precede their UI implementation, and security is not
deferred to final hardening. 3A experiments need only a bounded harness, not a
finished interface. Milestone 2 remains independent of live transports.

## Next handoff

The next implementation slice is C1/2C: adapt the real AtlasEngine font boundary
using the existing evidence and upstream-aligned cell/shaping policy. Then C2/2D
delivers the integrated Atlas viewport, followed by renderer acceptance and 3A before
substantial session/UI construction. This record does not authorize expanding
the baseline, importing an unreviewed dependency, or bypassing an unresolved gate.
Do not build the deferred 0.13 interaction follow-up as the next task.
