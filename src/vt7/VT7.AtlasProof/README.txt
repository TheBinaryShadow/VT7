VT7 Atlas backend proof 0.1
==========================

The first real Atlas backend experiment for Windows 7.
This is an engineering harness, not the VT7 terminal application yet.

Validation update, 2026-09-11: the issued 0.1 package passed all four automated
modes on Windows 7 SP1 x64 (19 frames each). Visible Direct3D11 hardware/WARP
sessions also passed, including 8 hardware and 6 WARP R-key recreations.
See doc/vt7/validation/2026-09-11-atlas-backend-proof.md in the source repository.
The tested archive is preserved; this source-document update does not rebuild it.

Current handoff, 2026-09-13: VT7's integrated Atlas viewport is at 0.3.5/ABI 8.
Its WARP lifecycle resource gate remains open. The separate native comparison
0.1 grows on Windows 7 with and without explicit power subscriptions; this
fixed-glyph backend harness does not replace that integrated/native evidence.
See doc/vt7/README.md and doc/vt7/HANDOFF.md in the source repository. No repeat
of this unchanged accepted backend proof is requested for the current handoff.

Requires Windows 7 SP1 x64 with the VT7 prerequisites, including Platform
Update KB2670838 and the Universal CRT. App-local Visual C++ runtime DLLs
are included. No .NET, Power Automate, administrator access, or installation.
Extract everything into a writable local folder. Keep the old GDI proof.

Reproduction reference for a relevant regression or requested target check:
1. Run RUN-ATLAS-TESTS.cmd. It tests four modes and produces logs and PNGs
   under Logs. Each mode renders 19 frames through an actual Atlas backend.
2. Run RUN-ATLAS-HARDWARE.cmd. A native window should show cyan and white text.
   Resize it, cover/uncover it, minimize/restore it, and press R to explicitly
   recreate the device and target. Escape closes it.
3. Repeat with RUN-ATLAS-WARP.cmd. This forces WARP, without hardware fallback.
4. Send the Logs folder and a screenshot of the visible window, including any
   failed logs. Describe corruption, hangs, or unusual redraw behavior.

The Direct2D backend can be checked visually using RUN-ATLAS-D2D-HARDWARE.cmd
and RUN-ATLAS-D2D-WARP.cmd. The normal two launchers select Atlas Direct3D11.
No path silently substitutes GDI or changes the requested device/backend.
Run one launcher at a time; running it again overwrites its own log/images.

Automated checks use hidden windows. PNGs are pre-Present back-buffer captures,
not screenshots or proof that pixels reached the visible desktop. The batch
launcher has no hang watchdog; a normal run takes seconds. If a process hangs,
report it and retain the partially written log. Do not report it as a pass.
The development PowerShell test runner has a separate 60-second process limit.

What this exercises:
- The real Atlas BackendD3D shader/glyph-atlas path and BackendD2D path.
- Shared Windows 7 device creation and HWND discard/stretch presentation.
- Fixed, pre-mapped Consolas ASCII glyphs and full-frame drawing.
- Exact repeated-frame comparisons, resize and post-resize redraw, foreground
  changes, explicit device/target recreation, and rejected zero-sized resize.
- An event-driven visible window, with no periodic animation/idle timer.

What it does not establish:
- AtlasEngine font fallback/shaping or general Unicode coverage. The integrated
  viewport has separate bounded font-boundary acceptance from 0.3.0 onward.
- TerminalCore/controller/WPF integration, terminal input, shells, or sessions.
- Automatic hardware fallback, recovery from real device loss, DPI/theme
  acceptance, or long-running lifecycle/stability acceptance.

The harness intentionally leaves newer DirectWrite factory/fallback and color
font paths unused even on the development OS. AtlasEngine is not constructed
here. Its integrated Windows 7 font boundary is implemented separately in the
viewport, while this frozen proof remains a test of pre-mapped glyph backends.
The renderer library is linked only for the backend implementation and shared
presentation routines. The accepted VT7 0.2.1 GDI host is not changed.

Source and build instructions are in the VT7 repository's BUILDING.md.
This archive is an engineering test package, not a release.
License: MIT, with Microsoft Terminal and dependency notices preserved.
See LICENSE.txt, NOTICE.md, RENDERER-PROVENANCE.md, licenses, and SHA256SUMS.txt.
