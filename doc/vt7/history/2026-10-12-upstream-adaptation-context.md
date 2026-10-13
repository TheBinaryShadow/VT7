# Earlier upstream adaptation context

Historical material retained during my 2026-10-13 documentation cleanup.
Use the [current handoff](../HANDOFF.md) for active work and dated validation
records for acceptance. Earlier "current" and "next" statements keep their
original checkpoint scope.

The 0.2 viewport proof compiles selected inherited sources directly into a
VT7-only static library. Its `VT7_CORE` compatibility branches, dependency pins,
disabled features, and testing limits are recorded in
[the core boundary notes](../../../src/vt7/VT7.Core/README.md). Review those branches when
updating any affected upstream file. The GDI proof surface is VT7-specific and
does not replace the Atlas integration work.

The isolated `VT7.Renderer` target now compiles the inherited Atlas backends,
shaders, and ColorFix, plus VT7's shared Windows 7 presentation helper. The
`VT7_ATLAS` branches select older graphics/font-face interfaces and disable
unsupported optional paths. Backend interface-query fixes also touch the
inherited Atlas sources. Review these changes when updating the affected files;
the [renderer boundary notes](../../../src/vt7/VT7.Renderer/README.md) describe their scope.
The standalone backend proof has passed on the tested Windows 7 machine.
Build 0.3.0 now integrates AtlasEngine with the real renderer controller and core.
Its narrow font adapter uses baseline DirectWrite layout callbacks for face
selection, then leaves shaping and cell advance fitting with Atlas. The VT7
controller uses kernel events in place of address-based waits; the caret path
uses `GetCaretBlinkTime` without the newer system metric. Local tests pass,
and the supplied Windows 7 run accepts the bounded C1/C2 integration. Broader
renderer qualification remains open. See the
[integration record](../validation/2026-09-12-atlas-viewport.md).
This work does not change the recorded upstream baseline or merge policy.

Build 0.3.1 adds VT7-only integrated repaint/cursor diagnostics and a bounded
host status refresh, without further Atlas font/shaping changes. Its tests use
normal core invalidation and inherited InvalidateAll as the full-redraw reference.
The [C3 record](../validation/2026-09-12-atlas-repaint.md) records local
and supplied Windows 7 acceptance of the bounded slice.

Build 0.3.2 adds VT7-only automatic driver selection and controlled recovery
instrumentation around the inherited controller retry loop and Atlas presentation
boundary. Forced modes stay strict; no upstream merge or shaping-policy change
is included. See the [recovery record](../validation/2026-09-12-atlas-recovery.md).

Build 0.3.3 adds a VT7 native font/settings boundary and deterministic tests around
inherited Atlas UpdateDpi/UpdateFont and TerminalCore UserResize. It does not change
upstream shaping, cell fitting or reflow policies. The frame wait now includes
newer pending requests observed during the wait. System-aware WPF behavior stays
separate from diagnostic renderer-DPI overrides. See the
[settings record](../validation/2026-09-12-atlas-settings.md).

Build 0.3.4 corrects VT7 host startup sizing and status-driven layout, and
replaces a first-row-only test assumption with a whole-frame diagnostic. ABI 7
adds raster dimensions for recovery evidence. These are local integration/test
changes, not an upstream merge or new shaping/reflow policy. See the
[scaling correction](../validation/2026-09-12-atlas-scaling-correction.md).
All positive 0.3.4 suites now pass on the supplied Windows 7 setup at measured
96/120/144 system DPI. This is bounded integration acceptance, not evidence of
new upstream merges, universal compatibility or completion of Milestone 2.

The 0.3.5 [scheduling/stability slice](../validation/2026-09-13-atlas-stability.md)
changes VT7-only timer locking, pause/resume and final HWND/worker lifetime, with
ABI 8 diagnostics. It retains the pinned parser and synchronized-output timeout
policy. These changes are not an upstream merge or a new shaping policy.
The supplied Windows 7 quick profiles and hardware lifecycle profile pass;
WARP resource growth and the unrun timed soak keep full stability acceptance open.
Subsequent source-only diagnostics and the separate native resource comparison
do not change the upstream baseline or parser/shaping policies. Windows 7 grows
in both native power/plain modes, so local Windows 10 allocation traces are not
target attribution. The current handoff records the next proposed control.

