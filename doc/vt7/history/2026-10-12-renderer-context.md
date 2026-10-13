# Earlier renderer checkpoint context

Historical material retained during my 2026-10-13 documentation cleanup.
Use the [current handoff](../HANDOFF.md) for active work and dated validation
records for acceptance. Earlier "current" and "next" statements keep their
original checkpoint scope.

# VT7 Atlas renderer boundary

Build 0.3.5, ABI 8, adds scheduling/stability diagnostics and corrects timer-read
locking and HWND/worker teardown order. Hidden workers park rather than exit;
the presentation worker outlives native HWND destruction, then releases its
graphics resources before joining. See the [stability record](../validation/2026-09-13-atlas-stability.md)
for local evidence and the supplied Windows 7 quick/hardware-lifecycle passes.
WARP exceeds the resource budget on both setups, and the timed soak remains
unrun. This is a test candidate. Earlier results below retain
their original build and scope. Use the [documentation index](../README.md)
and [current handoff](../HANDOFF.md) for the next bounded step.

The separate native comparison 0.1 uses the issued Release 0.3.5 ABI 8 DLL.
Both power and plain modes complete and grow on the supplied Windows 7 setup;
explicit power subscriptions and WPF are not required for this reproduction.
The development machine's power/plain contrast and traced allocation family
do not establish ownership on Windows 7. A fixed initialized pool or harmless
bound has not been proven. The later recreate/reuse comparison, focused trace
and retirement capture now have Windows 7 results; see the current handoff.
The separate [WPF reactivation diagnostic 0.1](../diagnostics/2026-09-14-resource-reactivation.md)
now completes two integrated work/close/idle rounds locally and on Windows 7
against one fixed baseline. The target retains three immediate failures, while
the two +180s handle/thread/GDI/USER counts match and private memory rises by
220 KiB. This does not identify retained handles or establish C3 acceptance.
The native renderer bytes remain unchanged.
The [approved REL01 decision](../architecture/2026-09-14-warp-development-deferral.md)
stops further dedicated tracing and accepts this risk for continued development.
C4/3A session work proceeds now. Milestone 7 reviews reliability evidence and
reopens investigation only if needed; recorded failures are not changed to passes.

Current managed application is version 0.16.0/ABI 11. SL01.3 adds a real
authentication/PTY fault diagnostic, with paired target acceptance pending.
Bounded SL01.2 phase budgets and SL01.1 remain accepted on LEOPARD, NESSY and
TURTLE. All 24 SL01.2 target
stages and my live checks pass. The issued native baseline remains 0.12.3; SL01.1
does not change renderer/font bytes. The terminal document/view split,
managed session boundary and opt-in resource-isolation controls are not present
in the issued original viewport archive. This source README and
those controls do not alter the frozen packages or their provenance files.

Build 0.3.0 implements the minimum Windows 7 font boundary and connects the real
AtlasEngine/controller to TerminalCore and the host. Debug/Release local tests
pass for both backends on hardware/WARP. Supplied Windows 7 tests now accept
C1/C2 on the tested setup, with broader C3 qualification open; see
the [integration record](../validation/2026-09-12-atlas-viewport.md).
Follow the [port-first checkpoints](../architecture/2026-09-12-port-first-plan.md).
Keep inherited shaping/grid/interaction behavior; optional fitting, joined Arabic
and paint experiments are Milestone 7 research, not integration prerequisites.

