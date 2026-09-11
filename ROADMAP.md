# VT7 Roadmap

This roadmap defines what VT7 is trying to achieve and how we will know when it
has arrived. It is intentionally ambitious. Windows 7 users have waited long
enough for a terminal that treats the platform as a first-class home.

VT7 is a port-first engineering effort. Milestones are ordered by technical dependency,
not assigned calendar dates. We will publish dates only after the underlying
risks are understood well enough to make those dates meaningful.

## Guiding principles

1. Windows 7 is the target, not an accidental compatibility mode.
2. A feature is not complete until it works on real Windows 7 systems.
3. Reliability and terminal correctness come before visual novelty.
4. The user should not need to replace system DLLs or install a system-wide
   compatibility layer.
5. Compatibility code should live inside VT7 when that produces the safest and
   most predictable application.
6. Upstream code, third-party work, and individual contributors must receive
   clear attribution.
7. Claims in the README and release notes must match tested reality.
8. Core/renderer capability and end-to-end session capability are separate
   promises. A backend limitation must be measured, not hidden or silently
   adopted as a permanent product limitation.
9. Reuse pinned upstream behavior first. Adapt incompatible Windows 7 boundaries
   without making enhanced typography or other optional improvements prerequisites.
10. Fix blockers in their owning milestone; record non-blocking ideas in
    Milestone 7 for bounded polish triage or explicit post-release work.

## Research-driven execution plan

The [September 12 port-first decision](doc/vt7/architecture/2026-09-12-port-first-plan.md)
updates the [September 11 plan](doc/vt7/architecture/2026-09-11-research-driven-plan.md).
It keeps the platform floor, upstream baseline, required product workflows, and
recorded test results. Milestones 0 through 6 retain their numbers; Milestone 7
adds final polish and release readiness, not a requirement to implement every idea.

Short term: complete the application port, starting with the minimum 2C font
adaptation and a real TerminalCore-backed Atlas viewport in 2D. Then close the
integrated renderer gates and proceed to sessions and the daily-driver interface.
Long term: improve the finished port deliberately, using retained research and
user feedback without making optional enhancements an indefinite release barrier.

The decision defines C1-C5 deliverable checkpoints. Reuse upstream policies and
existing tests; run new bounded experiments only for named compatibility or
integration questions. Optional typography research is no longer the next step.

Before substantial local-session integration or daily-driver UI construction,
3A must resolve WinPTY fidelity, the OpenSSH integration choice, and input/session
contracts. This brings SSH feasibility forward, not full Milestone 5 delivery.
Tests, privacy-aware diagnostics, dependency audits, and output-security policies
belong with each implementing change; Milestone 6 qualifies the assembled product.

Use the experiment IDs in the [validation backlog](doc/vt7/research/20-validation-and-experiments.md)
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

## Supported system target

The planned minimum target is:

- Windows 7 SP1 x64.
- The Windows 7 Platform Update, KB2670838.
- KB2533623 or a superseding servicing rollup that provides the required loader
  behavior.
- SHA-2 support and servicing prerequisites, including KB4474419 and KB4490628
  where applicable.
- The Universal C Runtime, KB2999226.
- .NET Framework 4.8 if the WPF host remains the selected application shell.
- A working Direct3D 11 graphics driver, with WARP used as a fallback where
  practical.

The final installer or portable package should detect missing prerequisites and
explain them in plain language. It must not fail with an unexplained missing
entry point or DLL error.

### Test tiers

| Tier | Configuration | Purpose |
| --- | --- | --- |
| A | Windows 7 SP1 x64 with the documented VT7 prerequisites | Required product floor |
| B | Windows 7 SP1 x64 with the final official client ESU servicing level | Fully serviced official client test |
| C | NT 6.1 systems carrying later Windows Server 2008 R2 Premium Assurance-derived updates through January 2026 | Additional compatibility coverage, not an official Windows 7 update path |
| D | Windows 7 virtual machines using WARP | Reproducible fallback and CI-oriented testing |

A release must pass Tier A. Other tiers expand confidence but do not silently
raise the minimum requirement.

Proofs 0.2.0 and 0.2.1 have been tested on fully updated non-ESU and fully ESU-updated
Windows 7 SP1 x64 setups. The non-ESU run has supplied logs and screenshots;
the ESU run is tester-confirmed. These establish the proof on the tested
configurations, not an exhaustive prerequisite-minimum or hardware matrix.
See the [original validation record](doc/vt7/validation/2026-09-10-viewport-proof.md)
and [0.2.1 acceptance](doc/vt7/validation/2026-09-10-milestone-1-cleanup.md).

## Shell and session targets

### Required for version 1.0

- Command Prompt.
- Windows PowerShell 5.1.
- PowerShell 7.0 through 7.2.24, with 7.2.24 treated as the primary PowerShell 7
  acceptance target.
- General Win32 console applications through the selected local PTY backend.
- Direct SSH sessions with remote PTY allocation and resize support.

PowerShell compatibility includes PSReadLine editing, history, completion,
prediction display, Ctrl+C, Unicode input and output, native child processes,
resize behavior, and clean shutdown. Merely launching `pwsh.exe` is not enough.

Shell versions, PSReadLine versions, runtimes, and prerequisites must be recorded
separately from VT7's host requirements. Compatibility goals do not imply current
vendor support. Version 7.2.24 is the primary PowerShell 7 gate; report tested
older versions individually rather than extrapolating one result to the range.

### Capability and fidelity contracts

Maintain a feature ledger distinguishing parser recognition, core representation,
rendering, host actions, and availability through each session backend. Record
tested, unavailable, and untested behavior separately. Terminal identity, device
replies, and environment hints must match the effective session capabilities.

- Core/renderer tests use deterministic direct input to prove UTF-8 decoding,
  Unicode/cell behavior, colors, and VT modes without local-console losses.
- Direct SSH must deliver remote terminal bytes without legacy screen-buffer
  reconstruction, with a real remote PTY and live dimension updates. An external
  SSH process is acceptable; an embedded library is not a requirement.
- Local sessions must meet the shell/application acceptance corpus. WinPTY is
  the first candidate, not an assumption of transparent arbitrary VT transport.
  Its reconstructed console stream cannot be used to claim every core feature.

If a required local workflow fails, investigate an alternative or adaptation and
record an explicit scope decision before closing the gate. Do not waive the
workflow merely because the first backend cannot carry it. Publish measured
backend-specific limits without reducing the renderer or direct-SSH targets.

## Milestone 0: Project foundation

- [x] Establish the VT7 name, voice, goal, and independent-project disclaimer.
- [x] Record the Microsoft Terminal baseline and upstream policy.
- [x] Define the Windows 7 compatibility floor and test tiers.
- [x] Replace inherited Microsoft support and contribution directions.
- [x] Disable inherited release, project-board, and repository-management
  automation.
- [x] Establish a minimal local VT7 build, verification, test, and packaging
  workflow. Hosted CI remains future work.

## Milestone 1: Proof of life

The purpose of this milestone is to prove that the product shape can work before
we invest in the complete interface.

- [x] Define and document the supported developer toolchain.
- [x] Produce a standalone x64 VT7 executable.
- [x] Start on Windows 7 SP1 without unresolved post-Windows 7 imports in the
  tested configurations.
- [x] Open the WPF desktop host on the development system and Windows 7.
- [x] Implement a native HWND terminal surface and exercise it on Windows 7.
- [x] Implement a static TerminalCore-backed viewport with a temporary GDI
  renderer, passing core regression checks and visible output on Windows 7.
- [x] Package a diagnostic build for clean-machine testing.

Exit criterion: a VT7 window opens on Tier A hardware and displays a correctly
sized static terminal viewport without requiring a global compatibility layer.

Milestone 1, including the 0.2.1 cleanup, is complete on the tested Windows 7
configurations. Seven core checks and four complete window lifecycles pass in
the supplied non-ESU logs; screenshots show the static viewport, and the tester
confirms the ESU setup works as well. This is not a release qualification of
every system at the prerequisite floor.

Completed cleanup before renderer work:

- [x] Correct low-contrast tab labels and diagnostic values in the WPF host
  (0.2.1).
- [x] Add effective-color regression coverage and native viewport tab-switch
  checks, passing on the development system and Windows 7.
- [x] Rerun the 0.2.1 package and visually recheck both tabs and keyboard focus
  on Windows 7. Non-ESU logs and screenshots pass; the tester confirms Tab and
  arrow-key navigation, focus outlines, and all tests passing on the ESU setup.

See the [cleanup validation notes](doc/vt7/validation/2026-09-10-milestone-1-cleanup.md)
for the regression reproduced before the fix, test scope, and final acceptance.

Device-creation probes do not validate Atlas, and the temporary GDI viewport
does not close any Milestone 2 rendering goals. Minimal-prerequisite snapshots,
additional hardware, and sustained stability remain part of release hardening.

## Milestone 2: Windows 7 renderer

Port the real Atlas rendering path without losing the tested TerminalCore/host
boundary. This is not just a swap-chain change: the renderer controller,
DirectWrite font mapping, native lifetime rules, and test harness also need work.

The [code assessment and acceptance plan](doc/vt7/architecture/2026-09-11-renderer-assessment.md)
records the reviewed source, documented platform limits, proposed decisions,
and unresolved experiments. The isolated Atlas library now compiles in Debug
and Release; the full engine's font port and integration remain unproven. The independent
[capability probe](doc/vt7/validation/2026-09-11-renderer-probe.md) passes locally
and on the tested Windows 7 SP1 x64 machine (49 required checks, zero failures).
It does not load Atlas, and cannot
close Atlas rendering or integration gates.

The [backend experiment](doc/vt7/validation/2026-09-11-atlas-backend-proof.md)
now links and runs the real Atlas Direct3D11 and Direct2D backends with a shared
Windows 7 presentation adapter. Debug/Release hardware/WARP pixel tests pass
locally, and all four Release backend/device combinations pass on the tested
Windows 7 machine (19 frames each). Supplied screenshots show visible Direct3D11
output on hardware and WARP. Follow-up logs confirm eight hardware and six
WARP R-key recreations, each followed by successful presentation and clean exit.
This proves the fixed-glyph backend harness, not AtlasEngine font fallback or
TerminalCore integration. Separate ESU acceptance of this Atlas package is not
yet recorded; Milestone 1's ESU results do not substitute for it.

### 2A: Isolated build and capability baseline

- [x] Review the current Atlas, renderer-controller, font, host, and build paths
  and record confirmed dependencies separately from runtime questions.
- [x] Add an isolated VT7 renderer build using the pinned toolchain, explicit
  source/feature lists, and reproducible shader compilation. Do not import the
  complete upstream application build or silently change its baseline.
- [x] Audit the linked backend harness in Debug/Release and its assembled
  package, and validate that boundary on the tested Windows 7 machine.
- [ ] Extend the audit to the full engine's imports, runtime dependencies, and
  COM interface requests in Debug, Release, and the assembled package.
- [ ] Audit behavior as well as imports: flags, enum/metric values, interface
  methods, and resource ownership must work on the declared Windows 7 floor.
  Resolve the caret-blink metric assumption before cursor acceptance.
- [x] Add capability diagnostics for the actual graphics and font paths, with
  distinct required failures and optional-interface observations. The standalone
  probe passes on the development system and the tested Windows 7 setup.
- [x] Preserve the accepted 0.2.1 archive and keep GDI/core regressions passing
  through the isolated Atlas backend work.
- [ ] Add a selectable GDI reference path during Atlas/host integration and
  keep its regression checks passing.

Gate: an isolated, loadable renderer boundary with reviewed dependencies and
capability reports from Windows 7. Loading is not rendering acceptance.
This gate remains open: the full engine still needs font/runtime adaptation,
and a linked backend harness is not a load test of that full engine. The GDI proof and
accepted archive are preserved; selectable Atlas/GDI integration is still ahead.

### 2B: Windows 7 presentation path

Implementation checkpoint: `Win7Presentation` is shared by the AtlasEngine
presentation branch and the backend harness. It selects older device/context/
swap-chain interfaces, an opaque HWND discard/stretch target, and full redraw.
The harness tests exact pixels across four resize stages and device recreation;
its visible mode parks in the message loop without a periodic render timer.
The fixed-glyph presentation checkpoint now passes on the tested Windows 7
machine. Full controller scheduling and wider lifecycle acceptance remain open.

- [x] Replace mandatory newer graphics factory/device/context/swap-chain requirements
  with interfaces and methods supported by the Windows 7 Platform Update.
- [x] Use an opaque native HWND target, compatible bitblt swap effect, scaling,
  buffer count, and flags. Exclude the DirectComposition surface path.
- [ ] Remove mandatory frame-latency waitable objects and implement bounded,
  interruptible scheduling without busy-spinning while hidden or minimized.
- [x] Start with a correctly redrawn full frame and conservative presentation.
  Enable dirty-rectangle/scroll optimizations only after separate validation.
- [x] Exercise both an explicit hardware device and explicit WARP device in
  the backend harness, including resize, rejected zero-sized buffers,
  minimize/restore, and explicit target recreation.

Gate: actual Windows 7 frame presentation, resize, and recovery of a test target
on hardware and WARP. A cleared frame still does not prove Atlas text rendering.
The fixed-glyph backend proof now supplies that initial presentation evidence.
2B remains open for bounded interruptible controller scheduling; explicit
recreation does not establish automatic recovery from real device loss (2E).

### 2C: DirectWrite and glyph path

Current gate: the minimum Windows 7 font adaptation needed by the real AtlasEngine,
preserving inherited shaping direction, cluster-to-cell advance fitting and primary
grid behavior. Reuse the 0.8 mapper's applicable ownership/fallback work, not the
entire experimental rendering stack. Enhanced Arabic layout and fitting/paint
alternatives are retained below as completed research and tracked in Milestone 7;
they are not prerequisites to the first Atlas viewport.

The supplied Windows 7 probe 0.2 passes 51 required checks and maps nine fixtures.
It identifies the original missing glyph as U+1F600, selected as Consolas glyph
zero, and exposes Arabic joining/order and advance-only emoji fitting defects.
See the [0.2 evidence](doc/vt7/validation/2026-09-11-font-mapping-probe.md).
The [researched 0.3 follow-up](doc/vt7/research/2026-09-11-font-coverage-and-fitting.md)
independently scans font coverage, directly draws a candidate if available,
fits whole ink rather than advances alone, and preserves shaped RTL runs.
Its eleven fixtures include mixed and marked Arabic. The
[0.3 validation record](doc/vt7/validation/2026-09-11-font-fitting-probe.md) separates
development-machine checks from the supplied Windows 7 run: 51 checks pass,
eleven fixtures map, and no scanned face covers U+1F600. The user confirmed
KB2729094 installed. The 0.3 strict fitting passes containment but over-compresses
ordinary letters. [Probe 0.4](doc/vt7/validation/2026-09-11-natural-size-probe.md)
preserves natural proportions with an explicit bounded ink halo, keeping strict
compression for oversized groups. Its supplied Windows 7 run passes 51 checks,
maps all eleven fixtures, and keeps Latin, bold, and italic draws at natural size.
[Probe 0.5](doc/vt7/validation/2026-09-11-private-font-probe.md) adds pinned,
application-private Unifont/Unifont Upper under OFL 1.1 without changing the MIT
code license. Its bounded symbol fallback and two forced private-font fixtures
pass locally and on the supplied Windows 7 setup: 51 required checks, zero
failures, 13 mapped fixtures, and automatic U+1F600 fallback in Supplementary C.
All 76 original cell records match 0.4. Pixel-derived glyph quality and squeezed
one-cell symbols remain limitations, not final typography acceptance.
These partial F01/F02 results do not close the unchecked gates below.

The completed experiment sequence is described in the
[geometry and repaint test plan](doc/vt7/architecture/2026-09-11-font-geometry-test-plan.md):
geometry/size/DPI and differential repaint preceded adapter work. The current
next step is minimal adapter integration, not another typography probe. [Probe 0.6](doc/vt7/validation/2026-09-11-geometry-probe.md)
implements the offscreen geometry matrix and passes on the supplied Windows 7 setup.
Vertical overflow observations are covered by the approved upstream-aligned
fixed-grid/overlapping ordinary-text policy, not silently accepted clipping.
[Probe 0.7](doc/vt7/validation/2026-09-11-repaint-probe.md) adds the isolated
differential repaint experiment and passes the supplied Windows 7 run.
[Probe 0.8](doc/vt7/validation/2026-09-11-text-adapter-probe.md) now exercises a
reusable owned logical-order mapper candidate with upstream-default metrics.
It remains separate from AtlasEngine; the supplied 0.8 Windows 7 structural run
passes while exposing horizontal overflow and unresolved Arabic typography.
[Probe 0.9](doc/vt7/validation/2026-09-11-horizontal-fitting-probe.md) adds a
separate raster-measured horizontal fitter and neighbor-protection checks.
The supplied 0.9 Windows 7 run passes containment and repaint checks, with
67 earlier images unchanged. Narrow-symbol appearance is tracked under POL04;
integrated fallback correctness remains required.
[Probe 0.10](doc/vt7/validation/2026-09-11-arabic-context-probe.md) now separates
Arabic context repair, logical/visual ordering, and proportional/grid placement.
Its supplied Windows 7 structural/context run passes; no terminal bidi policy
is changed. [Probe 0.11](doc/vt7/validation/2026-09-11-joined-span-probe.md)
now tests shared-span fitting within the combined core allocation, independently
of production cursor/selection decisions. The supplied Windows 7 0.11 matrix
passes with all 103 earlier target images unchanged.
[Probe 0.12](doc/vt7/validation/2026-09-11-cross-style-ligature-probe.md) compares
whole-source lam-alef shapes with paint-only and different-outline spatial
composites. Different-outline hybrids remain REVIEW, not production policy.
[Probe 0.13](doc/vt7/validation/2026-09-11-marked-paint-probe.md) extends same-outline
paint to marks, joining context and core-cluster source selection. Its supplied
Windows 7 matrix passes all eight validators, with the 139 earlier target images
unchanged. The visible highlight mismatch and proposed interaction experiment
are deferred under POL02 in Milestone 7, not prerequisites to upstream-style Atlas.

- [x] Identify the exact Windows 7 missing cluster and selected font from supplied
  evidence: U+1F600, Consolas 5.24, glyph zero, original run 7 UTF-16 [60,62).
- [x] Distinguish unavailable font coverage from automatic fallback selection on
  the supplied target: 575 faces, zero supporting U+1F600, zero scan errors.
  KB2729094 is user-confirmed installed. This is a tested-machine observation,
  not a universal font inventory or a reason to reinstall that update.
- [ ] Accept whole-ink fitting visually on Windows 7, including emoji neighbors,
  italic overhang, and compression quality. Extend vertical/DPI/size coverage
  before adopting the fitting policy in Atlas.
- [x] Bundle unmodified, pinned static Unifont/Unifont Upper 17.0.05 in the
  independent probe, with original font licensing, provenance, hash checks,
  and missing/altered-file negative tests. No system font installation.
- [x] Validate both private faces on the supplied Windows 7 setup: visible forced BMP/SMP glyphs,
  U+1F600 missing-system fallback, unchanged source/core cells and shaped scripts.
  Keep system fonts preferred. The current substitution covers only standalone
  symbols/pictographs occupying a complete core cluster/run, not arbitrary text.
- [x] Build the next geometry probe with a frozen 0.5 reference plus 12/18/24 DIP
  text at 96/120/144/192 DPI. Derive grid metrics from the primary font, never
  fallback advances; log rounding, baseline, vertical ink, compression, and clipping.
- [ ] Validate the selected upstream vertical-ink and clipping policy in actual
  Atlas, using relevant 0.6 fixtures. Record non-blocking stacked-mark appearance
  and fitting refinements under POL04; do not reopen the selected row-height policy.
- [x] Validate the supplied 0.6 Windows 7 structural matrix: 204 fixtures,
  1,164 ink records, 24 stacked-mark observations, and unchanged target reference.
  Integrated policy/correctness acceptance remains open, not a new line-height design.
- [ ] Validate size/DPI transitions and snapshot invalidation, with identical
  core text/cells and no stale metrics. Separate offscreen scale tests from
  actual Windows 7 HWND/display-DPI behavior.
- [ ] Compare incremental repaint against full redraw on the same renderer and
  configuration after each deterministic edit. Include old/new ink damage,
  neighboring backgrounds, combining/wide glyph changes, and viewport edges.
- [x] Implement that comparison in the separate 0.7 software-damage probe:
  480 transitions, 24 required negative detections, partial glyph redraw, and
  exact RGB comparison with outside-damage sentinels. Atlas invalidation is unchanged.
- [x] Validate 0.7 on the supplied Windows 7 setup: 480 exact comparisons,
  24 detected negative cases, unchanged outside damage and original images.
- [x] Select upstream's fixed primary-font grid and overlapping ordinary-text
  ink policy, retaining its special clipping cases. Older probe metrics stay frozen.
- [ ] Repeat differential checks and verify clipping exceptions in actual Atlas.
- [x] Implement a separate owned logical-order mapper candidate in probe 0.8:
  baseline DirectWrite layout face selection, analyzer shaping, retained FontFace1,
  upstream-default metrics, core-group advance correction, and boundary/key checks.
- [x] Validate the 0.8 structural comparison on the supplied Windows 7 setup:
  192 mappings, retained data, 1,344 stale checks, and unchanged earlier images.
- [x] Implement a separate horizontal fitting candidate in probe 0.9, preserving
  raw mapper output, source/cells, natural-size Latin/italic, and vertical scale.
  Add raster bounds, neighbor sentinels, overflow controls and partial-row repaint.
- [x] Validate 0.9 containment on the supplied Windows 7 setup: 144 cases,
  94 fitted groups, 72 exact row repaints and visible emoji/B separation.
  Private-symbol compression quality remains open. Natural overhang allowance
  is not a universal no-overlap claim.
- [x] Implement the separate 0.10 Arabic context experiment: retain baseline
  layout data, reshape whole-source context per selected face/style, reject
  unsafe boundary-spanning clusters, and compare logical/visual grid placement
  against native and repaired proportional references. Keep the mapper unchanged.
- [x] Validate 0.10 on the supplied Windows 7 setup: cross-bold/italic/family and fallback boundaries,
  context/isolated-word controls, retained/direct raster identity, marked text,
  join controls, mixed digits, source/cell ownership and explicit lam-alef reviews.
- [x] Implement the separate 0.11 joined-span experiment: one shared horizontal
  transform across a fixture-declared Arabic span, unchanged core allocation,
  raster containment, source ownership, stale/displaced/unfitted controls and
  partial repaint comparisons. Preserve the earlier 103 images and lam-alef reviews.
- [x] Validate the bounded 0.11 matrix on Windows 7, including connected appearance, natural-width
  centering/spare allocation, compressed spans, marks and A/B neighbors. This
  is not yet a production joining-span segmenter or mixed-paragraph bidi mode.
- [x] Implement the separate 0.12 cross-style lam-alef comparison: exact selected
  faces, whole-source cluster observations, common-scale variants, spatial hybrid
  and same-outline paint lanes, pixel references and dropped-color/stale controls.
- [x] Validate 0.12 on Windows 7. Review italic/family hybrid seams and fallback
  cluster observations; do not equate contained spatial slices with character-
  owned font styling or accept a cluster-wide font choice implicitly.
- [x] Record the user-approved direction after 0.12: carry forward same-outline
  paint, do not adopt different-outline spatial hybrids as the default, and
  keep outline-changing ligature policy explicit. This is now retained research
  under POL03, not a commitment to integrate it before the port works.
- [x] Implement the isolated 0.13 marked/contextual paint experiment: whole-shape
  color strips, core-cluster source selection/copy oracles, stale/color controls
  and partial color/selection repaint. Preserve the earlier 139 images.
- [x] Validate the bounded 0.13 matrix on the supplied Windows 7 setup: 432 source
  round trips, 432 raster references, 288 exact partial paint repaints and all
  139 earlier target images unchanged. Inspect marks, connections and fallback.
- [ ] Integrate only the required Windows 7 font adaptation, preserving upstream
  shaping/cell policies and checking style/fallback ownership and bounded costs.
  Experimental Arabic context repair, joined-word fitting, ligature styles and
  alternate hit testing are deferred to POL01-POL03. Their adoption conditions
  remain requirements for those enhancements, not for the baseline port.
- [ ] Resolve private fallback's production mapping, caching, metrics/style and
  missing-asset behavior before Atlas integration. Track pixel-derived glyph
  quality and narrow-symbol refinements under POL04; no color emoji, ZWJ composition, or
  universal Unicode coverage claim. Font repertoire does not replace core width tables.
- [x] Compare preserved pure/mixed/marked Arabic runs on Windows 7 in probe 0.3:
  joining/order follow the natural reference in these bounded samples.
- [ ] Preserve inherited terminal ordering and core-grid interaction contracts
  in the Atlas adapter. Verify ranges and cursor geometry; ordinary interactive
  selection, mouse, IME and accessibility follow in their owning milestones.
  No proportional/visual-bidi hit-test design is required for baseline integration.
- [ ] Remove mandatory newer font-fallback and font-face interfaces; prove a
  Windows 7-compatible font mapping/shaping path before settling its design.
- [ ] Reuse the existing layout-callback/analyzer evidence for the production
  adapter. Compare another approach only if a named integration blocker requires
  it. Record correctness, font identity/lifetime, caching and cost (remaining F02).
- [x] Document [text geometry contract v0.1](doc/vt7/architecture/2026-09-11-text-geometry-contract.md):
  core authority, snapshot ownership, coordinate spaces, natural ink/damage,
  and consumer rules. Diagnostic visual bidi is not the production default.
- [ ] Implement and verify the authoritative core-cell model and mappings among UTF-16,
  clusters, glyphs, cells, and pixels. Cursor, selection, hit testing, IME,
  accessibility, and session dimensions must share these contracts; their full
  interactive implementations remain in later milestones.
- [ ] Preserve cluster boundaries, fallback runs, cell allocation, baseline,
  decorations, and bold/italic variants. Test missing-family and missing-glyph
  behavior rather than treating successful Latin output as Unicode acceptance.
- [ ] Audit both Atlas backends, including Direct2D glyph rasterization used by
  BackendD3D. Replace unchecked interface assumptions with verified capabilities.
- [ ] Record which advanced font capabilities are available, gracefully absent,
  or deferred. Do not claim color-font or variable-font parity from first pixels.
- [ ] Record the inherited Unicode width/cluster and bidi-ordering policies.
  Preserve original text even when a glyph is missing. Use versioned font/corpus
  evidence; prefer tested static faces for any initial bundled-font evaluation.
  Color emoji, variable-font axes, and full bidi terminal behavior require
  separate scope decisions, not an implied promise inside Unicode support.

Gate: a Windows 7-compatible full-engine font path with reproducible mixed-script
output, preserved source/core cells and upstream-aligned placement, owned data,
safe fallback and reviewed dependencies. Record inherited limitations separately
from adaptation defects. Enhanced joined Arabic, visual bidi and optional fitting
are not gate requirements. Next: C2/2D, the first integrated Atlas viewport.

### 2D: TerminalCore-to-Atlas integration

- [ ] Integrate the real renderer controller and IRenderData path with Atlas.
  Keep the core/test fixtures consistent with the selected renderer type.
- [ ] Replace address-based waits in redraw/timers and synchronized output with
  Windows 7-safe synchronization, preserving deadlines and avoiding lost wakes.
- [ ] Define device/thread ownership, core locking, tab hide/show, and teardown.
  Stop rendering before releasing the HWND, core, engine, or device resources.
- [ ] Propagate actual font metrics, viewport size, invalidation, and settings
  through the native boundary; version any ABI changes in both native and host.
- [ ] Render the existing TerminalCore sample through Atlas and package the
  first Windows 7 text-rendering proof with unambiguous backend diagnostics.

Gate: the existing sample visibly rendered by Atlas on Windows 7, with its
backend and completed-frame evidence recorded. This is the first user-testable
Atlas viewport, not completion of Milestone 2.

### 2E: Fallback, lifecycle, and deterministic regression checks

- [ ] Add forced hardware/WARP modes and test automatic hardware-failure
  fallback. A GDI fallback must be reported and cannot pass an Atlas test.
- [ ] Replace GDI-only paint-count assumptions with bounded frame-completion
  checks; retain tab contrast, child-window lifetime, and core regression tests.
- [ ] Exercise resize/reflow, alternate-screen and cursor transitions, tab
  switching, expose/occlusion, minimize/maximize/restore, and repeated disposal
  using deterministic VT input without needing a session backend.
- [ ] Inject recoverable device/presentation failures and verify bounded retry,
  resource recreation, clean shutdown, and understandable terminal failure.
- [ ] Test wait/notify races, synchronized-output timeout, and teardown while
  rendering is idle, active, hidden, or recovering.

Gate: automated lifecycle/recovery suites pass with the requested backend;
fault injection is recorded separately from real driver/device-loss evidence.

### 2F: Visual and stability acceptance

- [ ] Verify hardware Atlas and forced-WARP text rendering on Windows 7, with
  logs and screenshots. Use the non-ESU setup for iteration and confirm the ESU
  setup at milestone acceptance, not by assuming equivalent behavior.
- [ ] Verify font fallback, accents/combining marks, wide and supplementary
  characters, ligatures, box drawing, colors, decorations, and cursor alignment.
  Judge baseline behavior against the pinned upstream policy and agreed corpus,
  not the optional joined-word experiments. Source loss, wrong cells and lasting
  corruption block acceptance; additional typographic refinements go to Milestone 7.
- [ ] Test Windows 7 system-DPI configurations at 100%, 125%, and 150%, including
  WPF/native sizing and clipping. Treat newer per-monitor DPI separately.
- [ ] Verify Aero/basic and high-contrast behavior, keyboard focus, and readable
  host diagnostics without silently overriding explicit terminal colors.
- [ ] Run the quantified stress/idle checks in the acceptance plan, collect
  resource and frame-time measurements, and investigate continuing growth or
  unexplained rendering while idle. Record remaining coverage gaps honestly.
- [ ] Pass Debug/Release verification and tests, audit the complete portable
  package, and record the exact build, backend, environment, and results.

Exit criterion: real Atlas text rendering works on the tested Windows 7 hardware
and WARP paths and passes the lifecycle, font, DPI, theme, and stability checks
above without persistent corruption, hangs, or device-loss loops. First pixels,
a successful factory query, or a newer-Windows run alone cannot close this
milestone. Minimum-prerequisite/extended hardware release qualification remains
part of Milestone 6 and must not be claimed from the two existing test setups.

Out of scope: local shells, SSH, daily-driver UI expansion, upstream merging,
system DLL replacement, and modern composition effects. Early restrictions
must be documented, not silently turned into permanent product limitations.

## Milestone 3: Local interactive sessions

### 3A: Session feasibility and contracts

Run bounded experiments before committing to transport and input designs. These
do not require daily-driver tabs or a finished SSH interface.

- [ ] Characterize a pinned WinPTY native library/agent build (P01). Compare
  child console state, reconstructed bytes, and final core state for W/A console
  APIs, direct buffer writes, raw VT, code pages, colors, Unicode, alternate
  buffers, and resize. Select the local backend from that evidence.
- [ ] Evaluate a pinned Microsoft Win32-OpenSSH client first (S00), recording
  exact binaries/runtime hashes, Windows 7 configuration, and negotiated
  algorithms. Compare a known-good local-console run with direct byte I/O.
- [ ] Prove unmodified remote VT/UTF-8 bytes, initial/live PTY dimensions, prompt
  and diagnostic routing, trust decisions, and cancellation. `ssh -tt` and a
  successful login alone do not close S00. Never substitute commands typed into
  shell input for SSH window-change messages.
- [ ] Record the SSH architecture choice: unmodified external OpenSSH, a narrowly
  scoped maintained helper adaptation, or an embedded library if its structured
  control is a better fit. No dependency is selected solely by this roadmap.
  Document licensing, update responsibility, and reasons for rejecting alternatives.
- [ ] Test the inherited `ToUnicodeEx` helpers on Windows 7 (I01), especially
  dead keys and AltGr. Do not assume newer non-mutating flag semantics or merely
  clear the flag without checking keyboard-state effects.
- [ ] Define one session owner, per-session decoder/parser/input state, ordered
  writes including terminal replies, bounded queues/backpressure, coalesced
  resize generations, EOF/drain/exit distinctions, cancellation, and teardown.
  Hidden panes keep consuming output without presenting unnecessary frames.
- [ ] Separate committed text from non-text key metadata. Choose the IME input
  owner and composition/candidate geometry contract; define accessible text/range
  mapping before the UI depends on it. Implementations follow in 3C and 4.
- [ ] Define host-action policies before feeding real session output: bounded
  titles/OSC/DCS, explicit clipboard permissions, user-activated validated links,
  and untrusted working-directory metadata. Scope callbacks/replies to the
  originating session and reject stale work after close. Diagnostic replay must
  not perform desktop actions by default.

Gate: evidence-backed backend choices and written session/input/security contracts
exist before 3B or Milestone 4 construction. Record failed experiments and resolve
required capability gaps instead of marking them passed. S00 is architectural
feasibility, not full SSH acceptance or a promise to ship the evaluated release.

### 3B: Local backend integration

- [ ] Integrate the selected native local backend behind a replaceable boundary,
  preserving its lifecycle and ownership contracts without requiring Cygwin UI.
- [ ] Launch Command Prompt, Windows PowerShell 5.1, and PowerShell 7.2.24 with
  explicit executable, arguments, environment, working directory, and versions.
- [ ] Validate PSReadLine editing, history, completion, supported prediction,
  multiline prompts, and native children, using clean and ordinary profiles.
  Do not silently alter execution policy, user profiles, or global code pages.
- [ ] Propagate the authoritative grid to the child console during resize;
  compare results across code pages, long prompts, wide/combining text, and
  full-screen applications.
- [ ] Stream output through a persistent decoder and core (U01). Test every
  boundary of short UTF-8/VT fixtures, malformed/incomplete input, EOF, restart,
  and replies. The existing UTF-16 core tests do not prove byte-stream decoding.

Gate: required shells and representative native applications work end to end
with documented fidelity, not merely a visible prompt.

### 3C: Input and lifecycle acceptance

- [ ] Forward text, non-text keys, mouse, paste, focus, and control events once
  and in order through the session, not global keyboard injection. Test terminal
  modes, selection override, large/canceled paste, and Ctrl+C/Ctrl+Break.
- [ ] Implement and test the chosen IME path (I02): preedit stays local, committed
  text is sent once, candidate UI follows the caret, and tab/focus/resize/close
  transitions leave no stale composition. Record Windows 7 IME versions.
- [ ] Test US, Croatian, German, and a non-Latin keyboard layout, including
  AltGr, dead keys, repeats, modifier loss, and WPF/native focus routing (I01).
- [ ] Exercise spawn/read/write/resize cancellation, agent or child failure,
  final-output drain, restart, and forced termination (P02). Include child trees
  and inherited jobs; document Windows 7 containment/breakaway limits explicitly.
- [ ] Prove bounded shutdown and queue growth, no cross-session input/replies,
  no callbacks after destruction, and a responsive dispatcher under output.
- [ ] Add privacy-aware diagnostics and deterministic session/host-action
  regressions with the implementation. Do not log ordinary terminal content or
  credentials by default.

Exit criterion: all required local shells can be used for sustained interactive
work, including child applications, composed input, resize stress, and clean
exit. The 3A SSH decision is recorded; production SSH delivery remains Milestone 5.
Repeat backend-sensitive input and IME tests over direct SSH there.

## Milestone 4: Daily-driver interface

- [ ] Tabs and horizontal/vertical split panes, keeping session lifetime separate
  from transient WPF layout and respecting native HWND airspace. Search chrome
  and splitters must not rely on ordinary WPF overlays over the terminal.
- [ ] Profile creation/editing with explicit backend and executable selection,
  capabilities, and runtime requirements.
- [ ] Versioned UTF-8 JSON settings with validation, last-known-good recovery,
  recoverable replacement, concurrent-save handling, and explicit portable-mode
  behavior on Unicode/read-only paths (D01).
- [ ] Search, selection, copy, paste, and scrollback using the shared cell/text
  model. Decide literal/regex, case-folding, normalization, soft-wrap, and offset
  semantics before restoring search. Audit any selected dependency such as ICU;
  preserve original text and do not hold the core lock during long searches.
- [ ] Test cluster-safe selection/copy, reflow, clipboard contention, multiline
  and bounded/cancelable paste, and the separate OSC clipboard policy (C01).
- [ ] Configurable key bindings.
- [ ] Color schemes, fonts, cursor styles, and background settings.
- [ ] Session titles, activity indication, and close confirmation.
- [ ] Keyboard-only operation, visible focus, and a practical Windows 7
  accessibility baseline: native terminal text/ranges, selection and bounds,
  bounded notifications, and safe provider lifetime (A01). Accessible host
  controls alone do not satisfy terminal accessibility.
- [ ] Validate a Windows 7-compatible screen reader, live high-contrast/settings
  changes, no-blink caret preference, system-DPI geometry, and input focus during
  dialogs, pane switching, and active composition.

Exit criterion: the primary workflows no longer require a developer harness or
manual configuration edits.

## Milestone 5: First-class SSH

Deliver the architecture selected by 3A/S00. An external process with lossless
terminal I/O and a proven control path is a first-class implementation option.

- [ ] Integrate the selected implementation and pin its complete redistributable
  dependency set. Recheck security advisories, Windows 7 execution, licensing,
  release/support status, and the maintenance/update process before shipping.
- [ ] Implement host-key verification and recoverable known-host management.
  Separate unknown, changed, matching, and unreadable trust records; never
  silently accept a mismatch or continue authentication past a failed decision.
- [ ] Support password, private-key, passphrase, and agent authentication where
  the selected implementation permits it. Keep prompts/diagnostics distinct
  from remote terminal data; do not infer structured trust decisions from
  arbitrary localized terminal text. Protect secrets and exclude them from logs.
- [ ] Allocate the requested remote terminal type and dimensions.
- [ ] Send remote window-change messages for relevant grid changes, coalescing
  bursts but delivering the latest size. Verify remote dimensions, not only
  successful local writes.
- [ ] Handle stage-specific deadlines/cancellation, stalled peers, partial I/O,
  rekey under output, keepalives, EOF/close/exit status, and reconnection UX (S01).
  Never replay already-submitted input automatically on reconnection.
- [ ] Test `vim`, `htop`, `tmux`, `mc`, `less`, full-screen TUIs, mouse input,
  bracketed paste, Unicode, 256-color/true-color output, alternate-screen
  restoration, and the shared keyboard/IME/clipboard paths on Windows 7.

Exit criterion: SSH is a first-class VT7 connection type with lossless remote
terminal bytes, secure trust/authentication handling, initial/live PTY sizing,
and bounded lifecycle behavior. Neither a line-oriented redirected command nor
`ssh.exe` through legacy console reconstruction substitutes for this gate.

## Milestone 6: Product qualification and hardening

Qualify the assembled port for release readiness, then extend this evidence
through alpha/beta feedback. Milestone 7 makes the public release decision;
hardening and release review repeat as the product approaches 1.0.

- [ ] Qualify the complete product across a repeatable physical/virtual Windows 7
  matrix. Verify a clean minimum Tier A image without developer tools (L01),
  plus separately recorded ESU, WARP, and additional hardware coverage. Recheck
  prerequisite/dependency closure whenever a new runtime is introduced, not
  only at final packaging; shell requirements remain separate from host needs.
- [ ] Consolidate and extend the parser, buffer, renderer, input, settings, PTY,
  SSH, accessibility, and output-policy regression suites developed in each
  milestone. This is not their first implementation stage.
- [ ] Verify opt-in diagnostic privacy, redaction, exact run/package manifests,
  and bounded resource behavior across the assembled product.
- [ ] Add crash reporting artifacts that users can attach manually.
- [ ] Measure startup, memory, active/hidden/minimized CPU, input-to-present
  latency, queue/cache growth, and sustained output against budgets established
  on target hardware. Extend earlier per-milestone measurements.
- [ ] Test long-running sessions and repeated tab and pane creation.
- [ ] Produce signed or checksum-verifiable portable release artifacts.
- [ ] Document installation, prerequisites, recovery, and uninstallation.

## Milestone 7: Polish and release readiness

The final checkpoint before the first public release, repeated for later releases
and 1.0. Milestone 6 supplies whole-product qualification; this milestone reviews
the assembled user experience, chooses bounded polish work, and makes the release
decision. Neither postpones security or correctness fixes from earlier milestones.

- [ ] Review required workflows, known limitations, prerequisites, diagnostics,
  accessibility and first-run/documentation clarity in the assembled application.
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

### Deferred improvements register

All entries start as **deferred, awaiting release triage**, not active port work.
Keep IDs stable. Add observations here as they arise with user impact, evidence,
baseline behavior, proposed follow-up and a blocker trigger. A substantial separate
workstream may receive its own post-release milestone after an explicit decision.

- **POL01: Enhanced Arabic context and joined-word layout.** Better connected
  cursive output across style/font boundaries. Preserve the upstream logical-grid
  baseline now. Retain [0.10 context](doc/vt7/validation/2026-09-11-arabic-context-probe.md)
  and [0.11 joined-span](doc/vt7/validation/2026-09-11-joined-span-probe.md) evidence.
  Later compare context repair, span formation, centering and compression with
  the integrated baseline. Promote an actual adapter-induced shaping regression
  affecting the required corpus, not the desire for new paragraph-style layout.
- **POL02: Interaction and paint for experimental joined spans.** The
  [0.13 highlight discrepancy](doc/vt7/validation/2026-09-11-marked-paint-probe.md)
  shows that correct source selection need not paint the expected visible glyph.
  Keep ordinary core-grid cursor/selection now; defer the proposed visible-position
  experiment, spare-space/edge clicks and mark/ligature ownership. These must be
  resolved before adopting POL01's alternate layout. Incorrect source copy or
  cell mapping in the baseline is an immediate blocker in its owning milestone.
- **POL03: Cross-style lam-alef and glyph painting.** Preserve
  [0.12 comparisons](doc/vt7/validation/2026-09-11-cross-style-ligature-probe.md)
  and 0.13 marked paint. Same-outline painting remains a candidate; different-
  outline spatial hybrids are not adopted. Later investigate seams and deliberate
  style ownership without slicing source clusters. Baseline source loss or an
  adaptation-induced style/cell regression is blocking; optional hybrid styling is not.
- **POL04: Fallback glyph appearance and fitting.** Retain the original glyph
  discrepancy, [font coverage findings](doc/vt7/research/2026-09-11-font-coverage-and-fitting.md),
  [0.6 geometry](doc/vt7/validation/2026-09-11-geometry-probe.md) and
  [0.9 horizontal fitting](doc/vt7/validation/2026-09-11-horizontal-fitting-probe.md).
  The missing U+1F600 cause and bounded private-font proof are established; production
  fallback remains 2C work. Keep the primary grid and upstream overhang policy.
  Review squeezed one-cell symbols, pixel-derived shapes and stacked-mark appearance
  later. Missing required fallback, illegible required text caused by our port,
  source loss or stale/erased neighbor pixels remain renderer blockers.
- **POL05: Advanced font and bidi capabilities.** Color emoji, variable axes,
  broader font repertoire and full terminal bidi need separate scope, interaction
  and dependency decisions. Use static/monochrome fonts and inherited ordering
  initially. See the [geometry contract](doc/vt7/architecture/2026-09-11-text-geometry-contract.md)
  and [font research](doc/vt7/research/07-font-assets-and-emoji.md). No promise of
  universal Unicode coverage; required-corpus failures still receive blocker triage.
- **POL06: Optional presentation and performance refinements.** Retain the
  conservative complete-frame HWND presentation baseline. Evaluate dirty-region/
  scroll optimizations and visual refinements only against integrated measurements
  and the [renderer acceptance plan](doc/vt7/architecture/2026-09-11-renderer-assessment.md).
  Idle spinning, unbounded growth, recovery loops or unusable responsiveness remain
  blockers; an optimization is optional when the correctness/performance gates pass.

## Version 1.0 acceptance bar

VT7 1.0 is complete only when all of the following are true:

- It installs or runs portably on a clean Tier A system with understandable
  prerequisite handling.
- It does not require modified system files, a system-wide compatibility layer,
  MSIX, the Microsoft Store, or ConPTY.
- Command Prompt, Windows PowerShell 5.1, and PowerShell 7.2.24 pass the local
  session acceptance suite.
- Direct SSH supports secure host-key verification, authentication, remote PTY
  creation, live resize updates, and unmodified remote terminal byte delivery.
- Tabs, panes, profiles, settings, search, selection, clipboard, and scrollback
  are dependable enough for daily work.
- Core/renderer acceptance proves streaming UTF-8, wide/combining text, box
  drawing, indexed/true color, and VT state with deterministic fixtures and
  versioned font evidence. Missing glyphs must not corrupt original text.
- Direct SSH independently passes end-to-end Unicode, 256-color/true-color,
  mouse, bracketed-paste, alternate-screen, and resize tests on compatible
  remote applications.
- Local-console acceptance independently passes the required shell/native-app
  corpus, input/IME, colors and text preserved by the selected console path,
  interrupts, resize, and clean shutdown. The capability ledger publishes
  measured transport limits; unresolved required workflow failures block
  acceptance until fixed or explicitly reconsidered, not silently waived.
- Selection, copy, search, IME geometry, and native accessible text agree with
  the core's cells and original text. Output-triggered host actions obey tested
  trust policies and cannot cross session boundaries.
- The renderer works with a supported Direct3D 11 driver and has a documented
  fallback path.
- Full-screen applications survive repeated resize, maximize, restore, and
  alternate-screen exit without lasting display corruption.
- Failures produce actionable diagnostics instead of silent exits.
- Licensing and provenance are complete for every shipped component.

## Deliberate non-goals for version 1.0

- Exact feature or UI parity with current Windows Terminal.
- MSIX, Microsoft Store, WinGet, or Windows shell registration that depends on
  post-Windows 7 deployment services.
- ConPTY implementation for the operating system.
- Replacement of the built-in Windows console host.
- Mica, acrylic, modern DirectComposition effects, or Windows 11 integration.
- x86, ARM, or ARM64 builds.
- Guaranteed support for PowerShell 7.3 or newer.
- Making Windows 7 a supported or secure operating system again.

## Beyond version 1.0

Milestone 7 triage carries optional work here with evidence and explicit scope;
it is not discarded when the first release ships. A substantial selected workstream
can receive its own milestone. Neither this list nor the polish register is a
promise to deliver every enhancement in the first release.

Possible later work includes serial connections, additional SSH features,
session restoration, quake mode, shell integration, richer accessibility,
plugin interfaces, and other architectures. These should not distract from
shipping a trustworthy Windows 7 terminal first.

Color emoji rendering, variable-font axis control, full bidirectional terminal
behavior, and richer local-console transport are separate evaluation tracks.
None is automatically included in the Unicode claim or permanently ruled out
by an initial proof restriction. Record a scope/design decision before promising
them for a release; preserve the baseline accessibility and local workflows above.
