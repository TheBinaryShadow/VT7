# WPF, native HWND hosting, DPI and desktop composition

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P1; affects renderer and interface design.

Implementation status, 2026-09-12: the [0.3.4 scaling matrix](../validation/2026-09-12-atlas-scaling-correction.md)
passes all positive suites on the supplied Windows 7 SP1 x64 setup at actual
96/120/144 system DPI. Native initial-window work-area fit, WPF/client/raster
geometry, status-layout stability and the bounded viewport lifecycle are tested.
The earlier status-wrapping and blank-first-row failures are resolved. This does
not establish multi-monitor moves, per-monitor awareness, Aero/basic/high contrast,
remote/suspend behavior or session input. Recommendations below retain that scope.

## Existing ownership

VT7.Host targets .NET Framework 4.8 and uses HwndHost. BuildWindowCore creates the native child; DestroyWindowCore calls the native destruction function. Public surface calls are currently UI-thread operations. The manifest declares system DPI awareness. [1]

HwndHost is the documented WPF mechanism for hosting a Win32 child window. The native window must be created as a child of the parent HWND supplied by WPF. [2]

**Recommendation:** preserve this simple ownership boundary through the renderer port. Session objects should have lifetimes independent of transient WPF layout objects, but the render surface must not outlive its actual HWND.

## Airspace constrains UI design

WPF/Win32/DirectX interoperation assigns each pixel to one HWND region. WPF content cannot freely alpha-blend or draw over the native child's region as if it were an ordinary WPF visual. [3]

Design consequences:

- Put tab strips, pane splitters, profile controls and search chrome outside the terminal HWND rectangle.
- Draw terminal selection, cursor, search highlights and IME preedit in the native renderer, or use a deliberately designed separate window.
- Do not assume a WPF Adorner over the terminal will appear correctly.
- Test popups, tooltips, context menus and drag indicators across the HWND boundary.
- Do not animate/rotate/clip the terminal host as if it were a texture without a separate composition design.

These are recommendations based on airspace behavior. The current opaque HWND direction is a useful constraint, not a missing cosmetic feature to bypass during first-pixel work.

## Windows 7 DPI model

System DPI awareness predates Windows 7; per-monitor awareness begins with Windows 8.1 and per-monitor v2 is later still. A Windows 7 acceptance run must therefore use the system-DPI model instead of assuming WM_DPICHANGED/GetDpiForWindow-era behavior. [4]

Recommended geometry contract:

1. WPF lays out in device-independent units.
2. Native client dimensions are measured in the applicable pixel coordinate space.
3. The renderer chooses actual pixel cell metrics from the selected font and system DPI.
4. The grid is the positive integer number of cells fitting the content area.
5. Core resize and backend resize receive that same grid.
6. Selection, cursor and IME placement use the identical pixel/cell transform.

Avoid applying the DPI conversion twice when HwndHost has already sized the child. Avoid using a stale GDI cell size after switching to DirectWrite metrics.

Test 96, 120 and 144 system DPI with a fresh logon/session where necessary. Record both WPF logical size and native client pixels. Test monitor moves as geometry/composition cases; do not mislabel them Windows 7 per-monitor DPI acceptance.

## Focus and input routing

The native child is a separate input surface. WPF tab focus and a painted focus outline do not prove that terminal keystrokes reach the correct child or that native Tab returns to WPF navigation.

**Proposed focus policy:**

- Click/activate a terminal pane: give its native input owner focus.
- Application shortcuts are resolved once, before session input.
- Tab belongs to the shell while the terminal is active unless an explicit application navigation command is used.
- Switching tabs/panes cancels or transfers composition deliberately.
- Hiding a tab preserves its session but stops unnecessary presentation.

The current cleanup validates tab round trips and the same child handle returning visible. This is valuable regression coverage, but keyboard forwarding and IME are absent from that proof. [5]

## Desktop and RDP transitions

The Windows 7 graphics path must be tested with Aero enabled and disabled, lock/unlock, resolution changes, remote desktop connection/disconnection, and sleep/resume. The reason is not that all such transitions necessarily recreate the device: the rendering and host layers must handle whichever size, visibility or device outcome actually occurs. See [graphics](08-graphics-and-presentation.md).

**Recommendation:** track visibility separately from session activity. A hidden SSH tab still needs channel draining and terminal-state updates; it simply need not present frames. Restoring it must draw the latest complete state.

Do not use WPF's rendering tier as evidence that the native Atlas device is hardware accelerated. They are separate rendering systems and need separate diagnostics.

## Experiments

Repeated split-pane layout, minimum sizes, rapid tab switches, top-level minimize/restore, moving between displays, opening menus over the terminal, focus traversal, system DPI changes between logons, and close during native rendering.

Record child HWND lifetime, pixel bounds, grid dimensions, active input owner, frame generation and clipping. Validate visible pixels as well as internal counters.

## Sources

- [1] [Host project](../../../src/vt7/VT7.Host/VT7.Host.csproj), [TerminalSurface.cs](../../../src/vt7/VT7.Host/TerminalSurface.cs), [manifest](../../../src/vt7/VT7.Host/app.manifest), [native ABI](../../../src/vt7/VT7.Native/include/vt7_native.h).
- [2] Microsoft, [Host a Win32 control in WPF](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/walkthrough-hosting-a-win32-control-in-wpf).
- [3] Microsoft, [Technology Regions / airspace](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/technology-regions-overview).
- [4] Microsoft, [High DPI desktop development](https://learn.microsoft.com/en-us/windows/win32/hidpi/high-dpi-desktop-application-development-on-windows).
- [5] [0.2.1 cleanup acceptance](../validation/2026-09-10-milestone-1-cleanup.md) and [core proof scope](../../../src/vt7/VT7.Core/README.md).
