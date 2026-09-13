# Milestone 2 renderer assessment

Current execution checkpoint, 2026-09-13: C1/C2 font/core/Atlas integration and
[0.3.4 system-DPI acceptance](../validation/2026-09-12-atlas-scaling-correction.md)
are recorded on the supplied Windows 7 setup. C3 remains open: the
[0.3.5 integrated WARP lifecycle](../validation/2026-09-13-atlas-stability.md)
fails its resource budgets locally and on Windows 7. The native power/plain
comparison grows only with explicit power subscriptions on the Windows 10
development machine, but grows in both modes on the supplied Windows 7 run.
Ownership and boundedness remain unresolved. A recreate/reuse diagnostic is
proposed, not implemented; the timed soak stays on hold.

Use the [current handoff](../HANDOFF.md), [documentation index](../README.md),
[port-first plan](../architecture/2026-09-12-port-first-plan.md) and
[roadmap](../../../ROADMAP.md) for present work and completion state. Dated
findings and proposed experiments below retain their original scope; they do
not restart C1/C2 or make optional typography a current port gate.

Reviewed September 11, 2026, at VT7 commit
`4ffd050cc08eeaa01e25aa40734416ccabcdb13e` on
`initial-implementation-and-assessment`. The inherited Microsoft Terminal
baseline remains unchanged. This is a source/documentation assessment, not
evidence that Atlas has compiled or run under VT7.

Subsequent implementation progress is tracked in the
[2A build/probe record](../validation/2026-09-11-renderer-probe.md). The static
library now compiles. The subsequent
[Atlas backend experiment](../validation/2026-09-11-atlas-backend-proof.md)
now passes locally and on the tested Windows 7 SP1 x64 machine. All four
backend/device combinations pass automated pixel checks; visible Direct3D11
hardware/WARP sessions and repeated R-key recreation also pass. Font mapping,
controller integration, and full runtime acceptance remain open. The source
findings below describe the original reviewed commit; the validation records
track later implementation and tests without rewriting that historical snapshot.

## September 12 planning follow-up, historical

Sequencing is governed by the [September 12 port-first decision](2026-09-12-port-first-plan.md).
The source review and acceptance evidence below remain dated records. At that
decision, minimal font adaptation and the first integrated Atlas viewport came
next; optional
joined-word layout, glyph-quality refinements and enhanced hit testing belong
to Milestone 7. Validate inherited policies and our compatibility changes,
without requiring a typography redesign. Scheduling, source/cell correctness,
repaint, lifecycle and required-workflow defects remain renderer gates.

The [approved September 11 plan](2026-09-11-research-driven-plan.md) keeps the
renderer direction and strengthens 2C: define the core-owned text/cell geometry
shared by rendering, cursor, selection/search, mouse, IME, accessibility, and
session dimensions. Investigate the recorded missing glyph while comparing the
fallback adapter's correctness, retained ownership, and cost. These contracts
do not require implementing live sessions or the complete input/UI stack in 2C.

Behavior-level audits include flags and metrics such as caret-blink settings,
not only imports. The full controller's scheduling and teardown gates remain
open. The original assessment and first-slice plan below are historical context;
the roadmap and linked validation records describe present progress. No new
renderer tests were performed for this planning update.

## Conclusion and confidence

An application-local Atlas port is a reasonable implementation direction, but
the work is broader than replacing DXGI calls. Confirmed work spans build and
shader integration, presentation, DirectWrite fallback, the renderer scheduler,
native ownership, and new rendering-aware tests. The largest design uncertainty
is adapting font fallback/shaping without losing terminal-cell correctness.

The [roadmap](../../../ROADMAP.md#milestone-2-windows-7-renderer) is the work
checklist. This document explains why its stages exist. Known dependencies can
be identified by inspection; completeness of the dependency closure, driver
behavior, visual quality, and performance require build/runtime evidence.

## Existing boundary to preserve

- [surface.cpp](../../../src/vt7/VT7.Native/surface.cpp) owns a TerminalCore
  instance and synchronous GDI drawing inside the WPF-owned native child HWND.
  It derives the grid from GDI font metrics and calls `Terminal::UserResize`.
- [ProofRenderer.hpp](../../../src/vt7/VT7.Core/ProofRenderer.hpp) only records
  invalidation generations. It is not the upstream renderer controller.
- [renderer.hpp](../../../src/renderer/base/renderer.hpp) selects that proof
  class whenever `VT7_CORE` is defined. The same selection affects native core
  tests, so adding a second, incompatible `Renderer` definition to the same
  binary is not a valid integration strategy.
- [TerminalSurface.cs](../../../src/vt7/VT7.Host/TerminalSurface.cs) owns the
  HWND lifecycle. Public surface calls currently belong to the UI thread;
  `PaintNow` synchronously exercises `WM_PAINT`.
- [graphics.cpp](../../../src/vt7/VT7.Native/graphics.cpp) proves device creation,
  not a swap chain, font factory, glyph rasterization, or presentation.

Keep the accepted 0.2.1 archive unchanged and retain a selectable GDI reference
implementation. Selection can initially be a developer option; no new settings
UI is needed. Never silently count that reference renderer as Atlas success.

## Confirmed source dependencies

| Area | Evidence in the reviewed source | Required response |
| --- | --- | --- |
| Build | [atlas.vcxproj](../../../src/renderer/atlas/atlas.vcxproj) uses upstream shared build imports, generated shader headers, and `oss/stb`; the VT7 projects do not compile Atlas or the full controller. | Add an isolated renderer source/build boundary and reproducible shader generation using the pinned SDK. Review source closure and all new libraries. |
| Configuration | [ProofFeatures.hpp](../../../src/vt7/VT7.Core/ProofFeatures.hpp) lacks Atlas feature selections. Atlas references `Feature_AtlasEngineLoudErrors`, `Feature_AtlasEnginePresentFallback`, and `Feature_NearbyFontLoading`. | Choose explicit proof behavior, preserve meaningful error reporting, and keep unsupported optional paths out of the initial build. |
| Graphics startup | [AtlasEngine.r.cpp](../../../src/renderer/atlas/AtlasEngine.r.cpp), `_recreateAdapter` and `_recreateBackend`, call `CreateDXGIFactory2` and require `ID3D11Device2`/`ID3D11DeviceContext2`. Debug also calls `DXGIGetDebugInterface1`. | Remove mandatory newer entry points/interfaces from both configurations; unavailable graphics debugging must not prevent startup. |
| Presentation | The same file requires flip swap effects, `DXGI_SCALING_NONE`, `IDXGISwapChain2`, a frame-latency waitable object, and contains a composition-surface branch. | Provide an opaque HWND/bitblt path with compatible flags, lifetime, and timing. Change creation, resize, wait, and presentation together. |
| WARP | `_recreateAdapter` searches enumerated adapters for the software flag; `_recreateBackend` chooses Direct2D automatically for software. | Prove explicit WARP creation, report device type separately from Atlas backend, and do not rely on adapter enumeration as the only software-device path. |
| Fonts | [common.h](../../../src/renderer/atlas/common.h) holds mandatory `IDWriteFactory2` and font-face-2 types. [AtlasEngine.cpp](../../../src/renderer/atlas/AtlasEngine.cpp) unconditionally gets system fallback and maps characters through it. [AtlasEngine.api.cpp](../../../src/renderer/atlas/AtlasEngine.api.cpp) can build a custom fallback list. | Design and test a Windows 7 mapping path, audit font-face storage/casts, and preserve glyph clusters, metrics, and style variants. |
| Glyph backends | [BackendD3D.cpp](../../../src/renderer/atlas/BackendD3D.cpp) rasterizes its atlas with Direct2D; [BackendD2D.cpp](../../../src/renderer/atlas/BackendD2D.cpp) draws to a DXGI surface. Both cast render-target outputs to device-context pointers. | Verify the actual interfaces instead of relying on inherited casts. Hardware D3D rendering does not eliminate the Direct2D/font dependency. |
| Scheduling | [renderer.cpp](../../../src/renderer/base/renderer.cpp) uses `til::atomic_wait` for redraw/timers and raw address waits for synchronized output. [til/atomic.h](../../../src/inc/til/atomic.h) maps directly to address-based Win32 waits/wakes. | Port both scheduling paths. The existing SRW core-lock adaptation does not solve these waits. |
| Host integration | The current surface destroys its state on `WM_NCDESTROY`, keeps paint/resize counters, and has no render worker. [terminalrenderdata.cpp](../../../src/cascadia/TerminalCore/terminalrenderdata.cpp) exposes core locking and font info for the real renderer. | Define construction/teardown ordering, device ownership, font/grid propagation, and thread-safe diagnostic snapshots before asynchronous rendering. |
| Verification | [Verify-VT7.ps1](../../../tools/Verify-VT7.ps1) scans a known import list. [ProofWindowChecks.cs](../../../src/vt7/VT7.Host/ProofWindowChecks.cs) expects an immediate GDI paint increment. | Extend dependency and runtime capability audits; add bounded completed-frame checks. A clean PE import list cannot detect unsupported COM methods or wrong flags. |

### Existing optional paths are not all blockers

`IDWriteFactory4`, newer color-glyph rendering contexts, and sprite batching
already have optional queries in parts of Atlas. `FontCache.h` gates nearby-font
loading on a newer factory. Audit those branches and their fallback behavior;
do not replace every newer type name mechanically. `BackendD3D::ClearView` is
inside debug-visualization conditionals, not its normal drawing path.

Conversely, an API that exists can still behave differently: review renderer
callbacks and system settings such as `Terminal::GetBlinkInterval`, which
consults `SM_CARETBLINKINGENABLED`. Import scanning alone is insufficient.

## Documented platform limits

These are platform facts, not new VT7 runtime results:

- The Windows 7 Platform Update supplies Direct2D 1.1 and Windows 8-era
  DirectWrite, but only parts of D3D11.1/DXGI 1.2. It does not supply
  DirectComposition. HWND swap chains are the applicable target;
  `DXGI_SCALING_NONE` is not supported. Hardware and WARP capability must be
  checked, not inferred from an interface version.
  [Microsoft platform-update guidance](https://learn.microsoft.com/en-us/windows/win32/direct3darticles/platform-update-for-windows-7).
- `CreateDXGIFactory2`, `ID3D11Device2`, and `IDXGISwapChain2` have Windows 8.1
  minimums. A successful `IDXGIFactory2` query in our existing probe does not
  establish support for those other APIs.
  [Factory creation](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_3/nf-dxgi1_3-createdxgifactory2),
  [device interface](https://learn.microsoft.com/en-us/windows/win32/api/d3d11_2/nn-d3d11_2-id3d11device2),
  [swap-chain interface](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_3/nn-dxgi1_3-idxgiswapchain2).
- For D3D11, flip-sequential starts with Windows 8 and flip-discard with
  Windows 10. The initial VT7 path therefore needs a bitblt swap effect.
  `Present1` itself is documented for the Windows 7 Platform Update; do not
  classify it as universally unavailable, or assume its optimizations work
  with every proposed swap-chain configuration.
  [Swap effects](https://learn.microsoft.com/en-us/windows/win32/api/dxgi/ne-dxgi-dxgi_swap_effect),
  [Present1](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_2/nf-dxgi1_2-idxgiswapchain1-present1).
- `IDWriteFactory1` is available with the Platform Update, while
  `IDWriteFactory2` and `IDWriteFontFace2` have Windows 8.1 minimums.
  [Factory1](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_1/nn-dwrite_1-idwritefactory1),
  [Factory2](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_2/nn-dwrite_2-idwritefactory2),
  [FontFace2](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_2/nn-dwrite_2-idwritefontface2).
- `WaitOnAddress` starts with Windows 8. A Windows 7 event/condition-variable
  design must preserve the caller's predicates, deadlines, and wake ordering.
  [WaitOnAddress](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitonaddress).
- Windows 7 testing is system-DPI testing. Native per-monitor awareness starts
  with Windows 8.1; the present VT7 manifest declares system awareness.
  [DPI awareness modes](https://learn.microsoft.com/en-us/windows/win32/hidpi/high-dpi-desktop-application-development-on-windows).

## Proposed implementation decisions

These are starting designs to validate, not claims of completed implementation.
In particular, the original worker-before-HWND teardown wording in item 5 is
superseded by the [0.3.5 lifetime correction](../validation/2026-09-13-atlas-stability.md):
rendering pauses, the HWND is destroyed while the worker remains alive, then
graphics cleanup and worker join complete before surface deletion.

1. **Isolate, then integrate.** Add a VT7 renderer static-library project or
   equivalent isolated target under `src/vt7`, sharing the pinned dependencies.
   Compile the real Atlas/backends and required base types without pulling in
   WinUI, WinRT settings, the full Terminal app, or an upstream merge. Review
   feature guards across the core, controller, and tests as one build contract.
2. **Use conservative presentation first.** Start with `CreateDXGIFactory1`,
   a supported device/context pair, an opaque HWND, and a documented bitblt
   descriptor. Prefer full redraw plus ordinary `Present` for the initial
   proof. A discard buffer requires redrawing the actual contents, not merely
   presenting a full rectangle while Atlas still emits partial updates. Decide
   discard versus sequential after a targeted preservation/resize test.
3. **Separate device and backend selection.** Hardware/WARP describes the D3D
   device; BackendD3D/BackendD2D describes Atlas's drawing implementation. Test
   BackendD3D on hardware first and BackendD2D on explicit WARP as the initial
   software candidate. Both backends share startup/font work; Direct2D is not
   an escape from that dependency. Log the actual combination and failure reason.
   Explicit WARP should use a valid `D3D11CreateDevice` argument combination,
   not a guessed software adapter.
   [Device creation contract](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/nf-d3d11-d3d11createdevice).
4. **Resolve fonts with a small experiment.** First prove one installed font,
   then a fallback run absent from it. Evaluate obtaining OS-resolved glyph
   runs through `IDWriteTextLayout::Draw` and a custom `IDWriteTextRenderer`,
   adapting them to Atlas's cell/cluster model. These callbacks are documented
   on Windows 7, but their suitability and cost for VT7 remain unproven. Compare
   against an explicit family-mapping approach if necessary. Do not substitute
   one-glyph-at-a-time font scans or code-unit splitting for cluster handling.
   [Text layout callbacks](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextlayout-draw),
   [text renderer interface](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nn-dwrite-idwritetextrenderer).
5. **Port the controller deliberately.** Prefer retaining upstream paint/data
   traversal while replacing its unsupported waits. A synchronous driver is
   acceptable for a small experiment but must not be called the finished
   integration. Preserve the core lock around data traversal, release it before
   blocking/presenting, and choose an explicit owner for single-threaded graphics
   resources. Document cross-thread initialization, COM use, and destruction.
   Teardown must wake sleepers and complete before HWND/core destruction; never
   rely on killing a render thread or leaving it with dangling resources.
6. **Keep the package self-contained.** Reproduce the four shader headers from
   the checked-in HLSL with the pinned SDK's compiler. Atlas also contains
   runtime `D3DCompileFromFile`/reflection and debug shader-reload paths. For
   first pixels, compile those optional paths out or explicitly account for
   their runtime DLLs. Review WIC/debug capture dependencies, app-local runtime
   imports, shader provenance, and the existing stb/component licenses. Do not
   assume that disabled UI settings remove a static DLL dependency.

No new third-party runtime, permanent feature reduction, or global compatibility
layer is selected by this plan. Revisit the design if an experiment requires
one of those changes. Modern color/variable-font features are not a first-pixel
gate, but unsupported behavior must be reported and the product bar retained.

## Original first implementation slice

Start with 2A and narrowly scoped experiments for 2B/2C:

- Isolated Atlas source/shader build, explicit features, and dependency audit.
- Capability report for factory/device/context, swap-chain path, DirectWrite,
  Direct2D, and font-face interfaces on the existing Windows 7 machine.
- A small HWND presentation probe and a glyph/fallback probe. Preserve the
  existing sample and GDI tests while these fail or evolve.

Only after these results should we settle the font adapter and final controller
integration. A loadable DLL, clear-color frame, and complete Atlas terminal
viewport are three distinct checkpoints. The last is the first Atlas package
for normal user testing, not the milestone exit.

## Acceptance and evidence

The following are planned checks, not results. Keep a deterministic VT-input
driver independent of shells so Milestone 2 does not depend on Milestone 3.

| Check | Planned acceptance |
| --- | --- |
| Regression | Existing seven core tests, tab contrast/navigation, and HWND lifetime checks still pass. Backend-specific tests assert the selected backend, not silent GDI fallback. |
| Frame completion | Bounded wait for a rendered/presented generation after invalidation, resize, and tab return. Capture a back-buffer or diagnostic image where useful; successful presentation alone is not proof of correct pixels. |
| Lifecycle stress | At least 100 create/destroy cycles, 1,000 varied resize operations, and 500 tab round trips per required rendering mode. No hangs, stale surfaces, invalid HWND access, or persistent content corruption. |
| VT transitions | Main/alternate screen, cursor movement/blink, erase, scrolling, resize/reflow, split writes, synchronized output including missing-end timeout, and repeated reset. Use direct VT injection, not claims of interactive-shell testing. |
| Failure handling | Inject device reset/removal and presentation/resize failures; verify bounded recovery or explicit failure, resource disposal, and shutdown during recovery. Synthetic failure is not evidence of a physical GPU reset. |
| Visual corpus | Existing sample plus bold/italic, ligatures, combining marks, CJK, supplementary characters, missing family/glyph, fallback runs, box drawing, decorations, colors, and cursor/cell alignment. Record installed fonts and expected missing-glyph behavior. |
| DPI/themes | Windows 7 100%, 125%, 150% system DPI with a fresh session where required; native/WPF sizing, clipping, monitor moves, Aero/basic, high contrast, and keyboard focus. Record newer-OS per-monitor tests separately. |
| Stability | At least 30 minutes of deterministic changing content/resize, then 10 minutes idle, for hardware and forced WARP. Sample private bytes, handles, threads, graphics resources where available, CPU, frame counts, and frame-time distribution after warm-up. Investigate continuing growth and unexplained idle redraw. |
| Delivery | Debug/Release build and tests, complete-package dependency/ABI checks, versioned archive with hashes, readable failure diagnostics, and fresh Windows 7 logs/screenshots. |

These counts establish an engineering gate, not a daily-driver soak guarantee.
Record a first-Atlas performance baseline and explicit acceptable budgets before
closing 2F; do not invent latency or memory guarantees from the GDI proof.
With cursor/animation disabled, unchanged content must not cause a continuous
present loop. Test hidden/minimized idle and shutdown separately from visible
work; an arbitrary sleep is not a substitute for a correct wake protocol.

Required initial coverage is hardware Atlas and forced WARP on the normally
updated Windows 7 SP1 x64 setup. Confirm the separate ESU setup at milestone
acceptance. Record actual GPU/driver, update tier, .NET, fonts, DPI/theme,
device/backend, build and package hash, interface results, presentation mode,
frame counts, recovery results, and retained logs/screenshots. Explicitly mark
unavailable VM, lower-feature-level, extra-driver, or minimum-prerequisite runs
as untested, not passed. The product's release floor remains unchanged.

## Questions that require experiments

- Which supported interface/method combination succeeds on each target driver,
  including the glyph-atlas Direct2D device context and the WARP swap chain?
- Can the selected fallback adapter retain shaping and cell allocation without
  excessive layout work, and does its font-face identity/cache behavior hold?
- Which bitblt descriptor and invalidation policy give correct redraw with
  acceptable cost, particularly after resize and exposed/occluded transitions?
- Does the controller's revised wake protocol preserve timers, output
  synchronization, and shutdown under contention without deadlocks or lost wakes?
- What additional link/runtime dependencies appear when the full source closure
  is actually compiled in both configurations?

Update this assessment as those questions are answered. No amount of additional
source inspection can replace these experiments or real Windows 7 acceptance.

Current answers and unresolved work belong to the dated validation records,
[handoff](../HANDOFF.md) and [roadmap](../../../ROADMAP.md). Preserve the source
review above as the September 11 snapshot instead of treating every original
question or procedure as a new prerequisite.
