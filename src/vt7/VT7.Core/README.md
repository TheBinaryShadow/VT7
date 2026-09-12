# VT7 Core and renderer boundary

Engineering version 0.3.4 builds the real Microsoft Terminal core, parser, dispatch,
text buffer, and supporting types into `VT7.Core.lib`, then links that library
into `VT7.Native.dll`. The static library is not a separate runtime dependency.
This is a static viewport proof, not an interactive terminal release.

The [port-first plan](../../../doc/vt7/architecture/2026-09-12-port-first-plan.md)
keeps this inherited core and its cell semantics as the integration foundation.
Adapt incompatible platform boundaries and restore required workflows without
using optional renderer experiments to redefine terminal widths or source order.
Non-blocking improvements are tracked in the roadmap's final polish milestone.

## Provenance

The inherited source baseline is Microsoft Terminal commit
`c7572cde0c69733e4511787dc963eb336f17adbf`, retained in this repository with its
MIT license and notices. `VT7.Core.vcxproj` is the authoritative source list.
VT7-specific host, boundary, renderer adapter, and tests live under `src/vt7`.

Three header dependencies are restored from fixed source revisions by
`tools/Restore-VT7Dependencies.ps1`. That script verifies SHA-256 archive hashes
before extraction, does not execute dependency install scripts, and puts the
sources in the ignored `artifacts/vt7/deps` directory.

| Component | Version | Revision | License |
| --- | --- | --- | --- |
| Microsoft WIL | 1.0.250325.1 | `b6ec76a2d9a609897f25a7fa0a0bdf4238e94e35` | MIT |
| Microsoft GSL | 4.2.2 | `152d6eb989a1ecd23fe9c9cfb2fb8cfc7c0cd0c1` | MIT |
| fmt | 12.1.0 | `407c905e45ad75fc29bf0f9bb7c5c2fd3475976f` | MIT |

Inherited helper code also includes Chromium safe math, interval tree, PCG,
wyhash, and the X.Org color table. Retain `NOTICE.md` and the component notices.
Portable proof packages include the dependency license files and a copy of
this document. Bundled Microsoft Visual C++ runtime DLLs remain governed by
the applicable Visual Studio redistribution terms, not VT7's MIT license.

## Deliberate proof-only differences

The `VT7_CORE` definition scopes these changes to the VT7 projects. The original
upstream project files are not redirected to this proof configuration.

- `TerminalCore/pch.h`, `Terminal.hpp`, and `Terminal.cpp`: exclude WinRT
  settings projections, settings-driven creation and appearance helpers. The
  host uses the native `Terminal::Create` entry point and core defaults.
- `Terminal.cpp` and `buffer/out/textBuffer.cpp`: omit ICU URL discovery and
  search. URL discovery yields no patterns; search returns `std::nullopt`
  (unsupported), not a successful empty result. Neither feature is exposed by
  the proof host. A future search implementation needs an explicit dependency
  and Unicode correctness decision.
- `til/ticket_lock.h`: use a Windows 7 SRW exclusive lock instead of
  `WaitOnAddress` and wake-by-address APIs. The surrounding recursive ownership
  handling is retained. SRW locking does not promise ticket-lock FIFO fairness;
  contention and shutdown testing must grow with interactive sessions.
- `til/winrt.h`: omit only the WinRT string/GUID formatting specializations.
- `types/utils.cpp`: exclude unused UUID, UWP drag/drop, and ICU emoji helper
  definitions that pull in newer platform dependencies. They are not emulated.
- `renderer/base/renderer.hpp/.cpp`: use the actual renderer controller, with
  Windows 7 kernel events replacing address-based redraw and synchronized-output
  waits. Stop signals interrupt waiting before the worker is joined. The old
  `ProofRenderer.hpp` is now only a forwarding compatibility header, not a second
  renderer class. Frozen proof 0.2.1 used the earlier notification-only adapter.
- `terminalrenderdata.cpp`: use `GetCaretBlinkTime` without the newer caret-blink
  system metric, treating zero/infinite or out-of-range intervals as no blink.
- `ProofFeatures.hpp`: explicitly select the feature flags needed by this
  isolated build without the upstream feature-staging runtime.

## Native viewport

The WPF `HwndHost` owns a native child window through C ABI version 4 (0.3.0 used ABI 3). That
window writes a fixed VT demonstration through `Terminal::Write`, reads actual
buffer rows and attributes, and calls `Terminal::UserResize` as its client size
changes. Resizing does not replace the content with a fresh demonstration.
The reset button is the only action that explicitly recreates the demo buffer.

Atlas is now the default renderer, using the actual controller/IRenderData path,
primary-font metrics and inherited cell fitting. Direct3D11 and Direct2D each
have explicit hardware/WARP modes. Hide/show stops and restarts the worker;
teardown stops it before destroying native resources. Default automatic mode
can fall back from Direct3D11 hardware to WARP; forced modes remain strict.
See the [renderer boundary](../VT7.Renderer/README.md).

The selectable reference renderer uses double-buffered GDI and a Consolas cell grid. It
draws the core's foreground/background colors, bold and underline attributes,
and wide-cell allocation. This makes the native/core boundary testable before
the Direct3D renderer port. It does not establish production font fallback,
complex shaping, emoji rendering, per-monitor DPI behavior, cursor animation,
accessibility, or rendering performance. GDI drawing is separate from the
hardware and WARP device probes shown in diagnostics.

There is no session backend, keyboard forwarding, mouse interaction, clipboard,
selection UI, scrolling UI, search, hyperlink UI, image display, or soft-font
display. Some corresponding upstream machinery is compiled because it belongs
to the parser/core dependency graph, but it is not an advertised proof feature.

## Checks and acceptance

0.3.1 adds an ordered diagnostic repaint command, normal-invalidation/full-redraw
comparisons and cursor-cell bounds, plus a first-frame status-label regression.
These checks pass locally and in the supplied Windows 7 run. See the
[C3 slice record](../../../doc/vt7/validation/2026-09-12-atlas-repaint.md).

0.3.2 exercises the existing six-attempt renderer retry loop with controlled
Atlas device/presentation errors and an automatic WARP policy. Recovery tests
retain sampled core text, effective colors, grid and cursor state; forced-mode
recreation also compares exact RGB output. Core parsing/shaping policy is not
changed. See the [recovery record](../../../doc/vt7/validation/2026-09-12-atlas-recovery.md).

0.3.4 corrects host scaling integration and diagnostic assumptions, with ABI 7
frame dimensions and whole-frame nonuniformity. No core reflow policy changes.
The supplied Windows 7 0.3.4 matrix passes at actual 96/120/144 DPI, including
same-device recovery pixel/core comparisons and settings reflow. This accepts
the bounded scaling checkpoint; scheduling/resource stress and broader
qualification remain open. See the
[acceptance record](../../../doc/vt7/validation/2026-09-12-atlas-scaling-correction.md).

0.3.3 updates Atlas/core font metrics while the render worker is parked, then
uses UserResize to reflow existing content. Tests preserve a nonblank styled
fixture across family/size/weight and DPI changes, compare exact full redraws,
restore baseline pixels and exercise a hidden settings update. This is not the
Milestone 4 settings UI or arbitrary-font configuration. See the
[settings record](../../../doc/vt7/validation/2026-09-12-atlas-settings.md).

`VT7_RunCoreTests` exercises the real core with seven checks: cursor and erase,
indexed/true-color attributes, wide/combining cell allocation, alternate-screen
restoration, resize/reflow content preservation, sequences split across writes,
and the SRW-backed core lock under contention. These are focused regression
checks, not a replacement for the upstream test suite. Unicode buffer checks
do not verify the appearance of glyphs on screen.

The eighth check exercises the new font boundary with 48 mappings across six
texts, two sizes and four styles, cached repeats, core-cluster preservation,
font-file identities, required symbol coverage and invalid inputs. It does not
replace a mixed-script raster/interaction acceptance suite.

`tools/Test-VT7.ps1` runs diagnostics and six viewport modes: GDI plus both
Atlas backends on hardware/WARP and automatic. Each mode gets four complete WPF/native-window
lifecycles, repeated resizing, minimize/restore, reset and disposal, plus eight
tab round trips. Atlas tests wait for a completed requested frame, check captured
header ink, identical repeat resets, and no frame growth while hidden. Readback
is on the renderer thread before discard presentation; PNG saving uses an owned
CPU copy. An injected blank-frame control must fail. Captures are not desktop
screenshots or universal glyph correctness oracles. Test cursors do not blink.
Reports and static import audits are kept under `artifacts/vt7/reports`.

The [0.3.0 integration record](../../../doc/vt7/validation/2026-09-12-atlas-viewport.md)
records local results and supplied Windows 7 C1/C2 acceptance. The results below
refer to the older GDI packages and are not used as substitutes for the new Atlas results.

Proof 0.2.0 passes these checks on the development machine and in supplied logs
from a fully updated Windows 7 SP1 x64 non-ESU setup. The Windows 7 window test
records four complete lifecycles, each with 18 paints and 15 resizes. Supplied
screenshots show the 105 x 22-cell static viewport and its sample text, colors,
attributes, and box drawing. The tester also confirmed a separate fully
ESU-updated setup as working and tested; separate ESU logs are not part of the
current evidence set.

The viewport proof is established on those tested configurations. Version 0.2.1
corrects the host-only tab/diagnostic contrast defect without changing the
TerminalCore sources or native ABI 2 layout. The native patch version is bumped
so logs distinguish the cleanup package from 0.2.0.

The expanded window test measures effective text/background contrast and makes
eight round trips between tabs, checking that the native child hides, returns
with the same handle and grid, and repaints. The new guard failed on the old
diagnostic colors (1.05:1) and passes after the correction (minimum 10.81:1 on
the development machine and in the supplied Windows 7 non-ESU log). This is
not pixel-level or full accessibility QA.

The 0.2.1 Windows 7 cleanup acceptance is complete on the tested configurations.
The supplied non-ESU logs pass all seven core checks, eight tab round trips,
and four window lifecycles with 22 paints and 15 resizes each. Screenshots show
readable headers/values and the 105 x 21-cell viewport. The tester confirms
Tab/arrow-key navigation and visible focus, and separately confirms all tests
passing on the ESU setup. Separate ESU logs were not supplied.

These results do not establish production font/shaping quality, Atlas
rendering, sustained stability, or compatibility with every minimum-prerequisite
installation.

The repository validation record is
`doc/vt7/validation/2026-09-10-viewport-proof.md`. The earlier 0.1 results remain
a separate record of the smaller host/bridge boundary.
Cleanup evidence is recorded in
`doc/vt7/validation/2026-09-10-milestone-1-cleanup.md`.
