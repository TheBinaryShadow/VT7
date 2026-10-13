# Milestone 2: Windows 7 renderer

[Roadmap](../../../ROADMAP.md) | [Documentation](../README.md)

These are the detailed requirements and recorded results for this milestone.
An accepted slice does not close an unchecked parent requirement.

## Find a section

- [2A: Isolated build and capability baseline](#2a-isolated-build-and-capability-baseline)
- [2B: Windows 7 presentation path](#2b-windows-7-presentation-path)
- [2C: DirectWrite and glyph path](#2c-directwrite-and-glyph-path)
- [UT01: current-upstream text and font parity](#ut01-current-upstream-text-and-font-parity)
- [2D: TerminalCore-to-Atlas integration](#2d-terminalcore-to-atlas-integration)
- [2E: Fallback, lifecycle, and deterministic regression checks](#2e-fallback-lifecycle-and-deterministic-regression-checks)
- [2F: Visual and stability acceptance](#2f-visual-and-stability-acceptance)

## Milestone 2: Windows 7 renderer

Port the real Atlas rendering path without losing the tested TerminalCore/host
boundary. This is not just a swap-chain change: the renderer controller,
DirectWrite font mapping, native lifetime rules, and test harness also need work.

The [code assessment and acceptance plan](../architecture/2026-09-11-renderer-assessment.md)
records the reviewed source, documented platform limits, proposed decisions,
and unresolved experiments. The full engine now compiles and runs locally in
Debug and Release through the 0.3.0 font/controller/core path; its bounded Windows 7
C1/C2 acceptance now passes on the supplied setup. The independent
[capability probe](../validation/2026-09-11-renderer-probe.md) passes locally
and on the tested Windows 7 SP1 x64 machine (49 required checks, zero failures).
It does not load Atlas, and cannot
close Atlas rendering or integration gates.

The [backend experiment](../validation/2026-09-11-atlas-backend-proof.md)
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
  The 0.3.0 VT7 caret path uses GetCaretBlinkTime instead of the newer metric;
  that implementation does not close the complete behavior audit.
- [x] Add capability diagnostics for the actual graphics and font paths, with
  distinct required failures and optional-interface observations. The standalone
  probe passes on the development system and the tested Windows 7 setup.
- [x] Preserve the accepted 0.2.1 archive and keep GDI/core regressions passing
  through the isolated Atlas backend work.
- [x] Add a selectable GDI reference path during Atlas/host integration and
  keep its local Debug/Release regression checks passing in 0.3.0.

Gate: an isolated, loadable renderer boundary with reviewed dependencies and
capability reports from Windows 7. Loading is not rendering acceptance.
This gate remains open for the complete behavior audit, not for lack of bounded
target load/render evidence. The full-engine adaptation passes local static
import audits; supplied Windows 7 C1/C2 evidence and the accepted 0.3.4 scaling
matrix cover the tested paths and setup. The accepted GDI archive is preserved
and the host offers selectable Atlas/GDI modes.

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
  The VT7 path has removed the newer waitable-object dependency and implements
  event-based waits. Its wider qualification remains open under C3/0.3.5.
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

0.3.0 implements the minimum boundary: baseline layout callbacks select owned
FontFace1 ranges, core-cluster boundaries remain authoritative, and Atlas keeps
its inherited shaping/fitting. A bounded cache and styled private symbol fallback
are in place. The 48-case local font check and missing/altered-asset controls pass.
Windows 7 font identities and the bounded mixed-script sample now pass;
C3 qualification still needs testing. No experimental Arabic/fitter pipeline has been adopted.

Accepted C1 scope: the minimum Windows 7 font adaptation needed by the real AtlasEngine,
preserving inherited shaping direction, cluster-to-cell advance fitting and primary
grid behavior. Reuse the 0.8 mapper's applicable ownership/fallback work, not the
entire experimental rendering stack. Enhanced Arabic layout and fitting/paint
alternatives are retained below as completed research and tracked in Milestone 7;
they are not prerequisites to the accepted first Atlas viewport. The retained
checklist below also records historical experiments, conditional adoption gates
and broader consumer/renderer qualification; it does not reopen C1/C2.

The supplied Windows 7 probe 0.2 passes 51 required checks and maps nine fixtures.
It identifies the original missing glyph as U+1F600, selected as Consolas glyph
zero, and exposes Arabic joining/order and advance-only emoji fitting defects.
See the [0.2 evidence](../validation/2026-09-11-font-mapping-probe.md).
The [researched 0.3 follow-up](../research/2026-09-11-font-coverage-and-fitting.md)
independently scans font coverage, directly draws a candidate if available,
fits whole ink rather than advances alone, and preserves shaped RTL runs.
Its eleven fixtures include mixed and marked Arabic. The
[0.3 validation record](../validation/2026-09-11-font-fitting-probe.md) separates
development-machine checks from the supplied Windows 7 run: 51 checks pass,
eleven fixtures map, and no scanned face covers U+1F600. I confirmed
KB2729094 installed. The 0.3 strict fitting passes containment but over-compresses
ordinary letters. [Probe 0.4](../validation/2026-09-11-natural-size-probe.md)
preserves natural proportions with an explicit bounded ink halo, keeping strict
compression for oversized groups. Its supplied Windows 7 run passes 51 checks,
maps all eleven fixtures, and keeps Latin, bold, and italic draws at natural size.
[Probe 0.5](../validation/2026-09-11-private-font-probe.md) adds pinned,
application-private Unifont/Unifont Upper under OFL 1.1 without changing the MIT
code license. Its bounded symbol fallback and two forced private-font fixtures
pass locally and on the supplied Windows 7 setup: 51 required checks, zero
failures, 13 mapped fixtures, and automatic U+1F600 fallback in Supplementary C.
All 76 original cell records match 0.4. Pixel-derived glyph quality and squeezed
one-cell symbols remain limitations, not final typography acceptance.
These partial F01/F02 results do not close the unchecked gates below.

The completed experiment sequence is described in the
[geometry and repaint test plan](../architecture/2026-09-11-font-geometry-test-plan.md):
geometry/size/DPI and differential repaint preceded adapter work. The 0.3.5
scheduling/stability harness now exists. Its unresolved WARP resource concern
is deferred under REL01; C4/3A session feasibility is accepted and current
development proceeds to 3B. The earlier typography experiment chain also remains deferred.
[Probe 0.6](../validation/2026-09-11-geometry-probe.md)
implements the offscreen geometry matrix and passes on the supplied Windows 7 setup.
Vertical overflow observations are covered by the approved upstream-aligned
fixed-grid/overlapping ordinary-text policy, not silently accepted clipping.
[Probe 0.7](../validation/2026-09-11-repaint-probe.md) adds the isolated
differential repaint experiment and passes the supplied Windows 7 run.
[Probe 0.8](../validation/2026-09-11-text-adapter-probe.md) now exercises a
reusable owned logical-order mapper candidate with upstream-default metrics.
It remains separate from AtlasEngine; the supplied 0.8 Windows 7 structural run
passes while exposing horizontal overflow and unresolved Arabic typography.
[Probe 0.9](../validation/2026-09-11-horizontal-fitting-probe.md) adds a
separate raster-measured horizontal fitter and neighbor-protection checks.
The supplied 0.9 Windows 7 run passes containment and repaint checks, with
67 earlier images unchanged. Narrow-symbol appearance is tracked under POL04;
integrated fallback correctness remains required.
[Probe 0.10](../validation/2026-09-11-arabic-context-probe.md) now separates
Arabic context repair, logical/visual ordering, and proportional/grid placement.
Its supplied Windows 7 structural/context run passes; no terminal bidi policy
is changed. [Probe 0.11](../validation/2026-09-11-joined-span-probe.md)
now tests shared-span fitting within the combined core allocation, independently
of production cursor/selection decisions. The supplied Windows 7 0.11 matrix
passes with all 103 earlier target images unchanged.
[Probe 0.12](../validation/2026-09-11-cross-style-ligature-probe.md) compares
whole-source lam-alef shapes with paint-only and different-outline spatial
composites. Different-outline hybrids remain REVIEW, not production policy.
[Probe 0.13](../validation/2026-09-11-marked-paint-probe.md) extends same-outline
paint to marks, joining context and core-cluster source selection. Its supplied
Windows 7 matrix passes all eight validators, with the 139 earlier target images
unchanged. The visible highlight mismatch and proposed interaction experiment
are deferred under POL02 in Milestone 7, not prerequisites to upstream-style Atlas.

- [x] Identify the exact Windows 7 missing cluster and selected font from supplied
  evidence: U+1F600, Consolas 5.24, glyph zero, original run 7 UTF-16 [60,62).
- [x] Distinguish unavailable font coverage from automatic fallback selection on
  the supplied target: 575 faces, zero supporting U+1F600, zero scan errors.
  KB2729094 is confirmed installed in my testing. This is a tested-machine observation,
  not a universal font inventory or a reason to reinstall that update.
- [ ] If adopting the optional whole-ink fitter (POL04), accept it visually on
  Windows 7, including emoji neighbors,
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
- [x] Record the approved direction after 0.12: carry forward same-outline
  paint, do not adopt different-outline spatial hybrids as the default, and
  keep outline-changing ligature policy explicit. This is now retained research
  under POL03, not a commitment to integrate it before the port works.
- [x] Implement the isolated 0.13 marked/contextual paint experiment: whole-shape
  color strips, core-cluster source selection/copy oracles, stale/color controls
  and partial color/selection repaint. Preserve the earlier 139 images.
- [x] Validate the bounded 0.13 matrix on the supplied Windows 7 setup: 432 source
  round trips, 432 raster references, 288 exact partial paint repaints and all
  139 earlier target images unchanged. Inspect marks, connections and fallback.
- [x] Implement the required Windows 7 font adaptation in 0.3.0, retaining
  upstream shaping/cell policies and owned mappings with a bounded cache.
  Local style/range checks pass; bounded target acceptance passes; wider cost measurements remain open.
  Experimental Arabic context repair, joined-word fitting, ligature styles and
  alternate hit testing are deferred to POL01-POL03. Their adoption conditions
  remain requirements for those enhancements, not for the baseline port.
- [x] Implement bounded private fallback mapping, caching, primary-grid metrics,
  simulated bold/oblique styles and fail-closed missing/altered-asset diagnostics
  for the initial Atlas integration. Bounded target rendering acceptance passes; broader qualification remains open.
  Track pixel-derived glyph
  quality and narrow-symbol refinements under POL04. This initial implementation
  does not establish color emoji, ZWJ or universal Unicode coverage. UT01 below
  now requires the applicable upstream capabilities before 1.0.
  Font repertoire does not replace core width tables.
- [x] Compare preserved pure/mixed/marked Arabic runs on Windows 7 in probe 0.3:
  joining/order follow the natural reference in these bounded samples.
- [ ] Preserve inherited terminal ordering and core-grid interaction contracts
  in the Atlas adapter. Verify ranges and cursor geometry; ordinary interactive
  selection, mouse, IME and accessibility follow in their owning milestones.
  No proportional/visual-bidi hit-test design is required for baseline integration.
- [x] Remove mandatory newer font-fallback and font-face interfaces; prove a
  Windows 7-compatible font mapping/shaping path before settling its design.
- [ ] Reuse the existing layout-callback/analyzer evidence for the production
  adapter. Compare another approach only if a named integration blocker requires
  it. Record correctness, font identity/lifetime, caching and cost (remaining F02).
- [x] Document the [text geometry contract](../architecture/2026-09-11-text-geometry-contract.md):
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
- [x] Record which advanced font capabilities are available, gracefully absent,
  or deferred. Do not claim color-font or variable-font parity from first pixels.
- [ ] Record the inherited Unicode width/cluster and bidi-ordering policies.
  Preserve original text even when a glyph is missing. Use versioned font/corpus
  evidence; prefer tested static faces for any initial bundled-font evaluation.
  UT01 supplies the 2026-10-05 scope decision for current-upstream text/font
  capabilities, including applicable color/emoji and variable-axis behavior.
  It does not require paragraph bidi beyond what the upstream reference supports.

Gate: a Windows 7-compatible full-engine font path with reproducible mixed-script
output, preserved source/core cells and upstream-aligned placement, owned data,
safe fallback and reviewed dependencies. Record inherited limitations separately
from adaptation defects. Enhanced joined Arabic, visual bidi and optional fitting
are not gate requirements. C1 and C2 are accepted in 0.3.0 on the supplied Windows 7
setup; C3 still owns the broader renderer checks below.

### UT01: current-upstream text and font parity

Required before Milestone 7 polish and VT7 1.0; implementation belongs to
2C/2F, with 3C/4 interaction/settings and Milestone 6 assembled qualification.
Follow the [UT01 delivery plan](../architecture/2026-10-05-upstream-text-and-font-parity-plan.md).
The initial behavior reference is stable Terminal v1.25.2733.0, commit
dc8ae365847d41f62d1ebca93815bb00959bc12f, checked on 2026-10-05. This does not
change VT7's source pin or authorize a wholesale upstream merge. Review the
then-current stable release's text/font deltas again before 1.0 freeze.

- [x] Confirm the scope I selected: one-to-one Unicode, text rendering and font fallback
  support, rather than the entire Terminal feature set. Record current results,
  source/API gaps and required delivery slices; no parity acceptance is claimed.
- [ ] **UT01.1:** pin reference binaries/fonts/settings and the differential
  corpus; inventory every applicable capability and Windows 7 adaptation.
- [ ] **UT01.2:** deliver sequence-aware coverage and ordered font-family/app-local
  fallback, including U+12032 and missing-family behavior without source/cell loss.
- [ ] **UT01.3:** match upstream grapheme/width modes, ambiguous-width settings,
  built-in glyphs, shaping, ligatures, features, style and wrapping/reflow behavior.
- [ ] **UT01.4:** deliver applicable upstream color-font/emoji, variation/ZWJ and
  variable-axis behavior through verified Windows 7-compatible implementations.
  Disabled color, ignored axes or a monochrome-only substitute do not pass parity.
- [ ] **UT01.5:** expose required font/text settings and qualify cursor,
  selection/copy/search, IME and accessibility against original text/core cells.
- [ ] **UT01.6:** accept matched-font and out-of-box coverage comparisons on the
  Windows 7 matrix, hardware/WARP, DPI and real local/SSH paths; audit current
  stable deltas, package closure, licenses, cache lifetime and performance.

Functional text parity does not require identical OS antialiasing pixels or
glyphs for characters unsupported by the reference fonts. Required coverage,
shaping, widths and interactions must match; font/raster differences must be
measured and identified. Missing modern OS APIs require an app-local adaptation,
not an implicit waiver. Unresolved required gaps block 1.0 unless I explicitly changes scope. The existing Windows 7 prerequisite floor is retained.

### 2D: TerminalCore-to-Atlas integration

- [x] Integrate the real renderer controller and IRenderData path with Atlas.
  Keep the core/test fixtures consistent with the selected renderer type.
- [x] Replace address-based waits in redraw/timers and synchronized output with
  Windows 7 kernel events and interruptible stop paths. Local tests pass;
  the 0.3.5 deadline/wake/shutdown tests have local and supplied target evidence,
  while WARP resource qualification remains open in 2B/2E.
- [x] Define device/thread ownership, core locking, tab hide/show, and teardown.
  Pause rendering before HWND destruction, keep the worker alive through that
  destruction, then release graphics on the worker and join before surface deletion.
  The 0.3.5 ordering supersedes the earlier worker-exit-first proposal.
- [x] Propagate actual font metrics, viewport size, invalidation, and settings
  through the native boundary; version any ABI changes in both native and host.
- [x] Render the existing TerminalCore sample through Atlas locally and package the
  first Windows 7 text-rendering proof with unambiguous backend diagnostics.

Gate: the existing sample visibly rendered by Atlas on Windows 7, with its
backend and completed-frame evidence recorded. This is the first user-testable
Atlas viewport, not completion of Milestone 2.
Implementation is present in 0.3.0, ABI 3. All five local modes pass lifecycle
checks; the four Atlas modes have completed-frame/readback evidence, repeat-reset
comparisons and a failing blank-frame control. The supplied Windows 7 run now
passes this gate: all five modes, 20 window lifecycles, 40 tab round trips,
visible hardware/WARP output and automatic private U+1F600 fallback. The blank
negative remains local evidence, not an additional supplied target test.

### 2E: Fallback, lifecycle, and deterministic regression checks

First C3 slice: [0.3.1 integrated repaint checks](../validation/2026-09-12-atlas-repaint.md)
compare normal invalidation with forced full redraw across two window sizes.
Local Debug/Release runs pass 128 exact comparisons and 32 cursor-cell checks
per configuration, plus the injected pixel-mismatch control. The status-label
correction has a first-frame regression check. The supplied Windows 7 run passes
the same matrix. This does not close recovery, DPI or scheduling/stability gates.

Second slice: [0.3.2 controlled recovery](../validation/2026-09-12-atlas-recovery.md)
adds an explicit automatic mode, sticky WARP fallback, retry diagnostics and
16 injected-failure scenarios, all passing on the supplied Windows 7 setup.
Third slice: [0.3.3 settings/DPI](../validation/2026-09-12-atlas-settings.md)
adds font family/size/weight transitions, reflow, hidden updates, input rejection,
exact repaint and WPF/native pixel-geometry checks. All five settings modes pass
at measured Windows 7 96/120/144 DPI. In that 0.3.3 build, at both higher scales
only 1/6 viewport and 7/16 recovery cases passed. Those failures remain recorded.
[0.3.4 scaling correction](../validation/2026-09-12-atlas-scaling-correction.md)
addresses monitor work-area startup fit, status text changing viewport height,
and a first-row-only blank-frame assumption. Its supplied Windows 7 matrix now
passes all 6 viewport modes, 4 repaint modes, 16 recovery cases and 5 settings
modes at each actual scale. Strict same-device image comparison is retained.
This accepts the bounded system-DPI checkpoint on the tested configuration.
The subsequent 0.3.5 slice supplies bounded synchronized-output/wait-notify,
idle/resource and shutdown checks. Its integrated WARP resource failures stay
recorded, with follow-up deferred under REL01. They no longer block session
development. C3 remains incompletely qualified; optional typography keeps its
separate POL entries in Milestone 7.

- [x] Add forced hardware/WARP modes and test automatic hardware-failure
  fallback. A GDI fallback must be reported and cannot pass an Atlas test.
- [x] Replace GDI-only paint-count assumptions with bounded frame-completion
  checks; retain tab contrast, child-window lifetime, and core regression tests.
  The 0.3.0 Windows 7 matrix passes. Its visible status label can show a stale
  count; 0.3.1 corrects reporting with local and supplied Windows 7 first-frame checks.
- [ ] Exercise resize/reflow, alternate-screen and cursor transitions, tab
  switching, expose/occlusion, minimize/maximize/restore, and repeated disposal
  using deterministic VT input without needing a session backend.
  0.3.4 passes deterministic resize/reflow, alternate-screen/cursor, tab,
  minimize/restore and disposal regressions at all three scales. Broader
  expose/occlusion/maximize and stress coverage still require qualification.
- [x] Inject recoverable device/presentation failures and verify bounded retry,
  resource recreation, clean shutdown, and understandable terminal failure.
  The 0.3.2 supplied target matrix accepts the bounded injected cases, not all
  failure sites or real driver-loss/suspend/remote-session behavior.
- [ ] Test wait/notify races, synchronized-output timeout, and teardown while
  rendering is idle, active, hidden, or recovering.
  The 0.3.5 harness exercises parked wake bursts, one-shot timer arm/cancel,
  explicit/missing sync end, hidden pending output and repeated disposal.
  Local and supplied Windows 7 WARP resource failures remain recorded. REL01
  defers further investigation to conditional release-readiness work; this
  unchecked qualification item did not prevent C4/3A and does not prevent 3B
  or later feature development.

Gate: automated lifecycle/recovery suites pass with the requested backend;
fault injection is recorded separately from real driver/device-loss evidence.
The REL01 exception changes the development dependency, not these test verdicts
or the requirement to assess reliability before release.

### 2F: Visual and stability acceptance

- [ ] Verify hardware Atlas and forced-WARP text rendering on Windows 7, with
  logs and screenshots. Use the non-ESU setup for iteration and confirm the ESU
  setup at milestone acceptance, not by assuming equivalent behavior.
- [ ] Verify font fallback, accents/combining marks, wide and supplementary
  characters, ligatures, box drawing, colors, decorations, and cursor alignment.
  Compare the original pinned baseline and UT01's selected current-stable corpus.
  Optional joined-word experiments are separate. Source loss, wrong cells and
  lasting corruption block acceptance; typographic refinements beyond required
  upstream parity go to Milestone 7.
- [x] Test Windows 7 system-DPI configurations at 100%, 125%, and 150%, including
  WPF/native sizing and clipping. The supplied 0.3.4 logs and hardware/WARP launch
  screenshots accept this bounded checkpoint on the tested Windows 7 setup.
  Treat newer per-monitor DPI, other monitors and a separate ESU run separately.
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

