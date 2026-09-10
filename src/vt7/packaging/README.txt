VT7 static viewport proof 0.2.0
==============================

The terminal application Windows 7 always deserved, one tested step at a time.
This is an engineering build, not a usable terminal release. It displays a
fixed VT demonstration. It cannot run commands, local shells, or SSH sessions.

Target system
-------------

- Windows 7 SP1 x64 with Platform Update KB2670838
- .NET Framework 4.8 and the Universal C Runtime (KB2999226)
- KB2533623 or a superseding update, plus SHA-2/servicing prerequisites
- A Direct3D 11 driver, or a system capable of creating a WARP device

See the repository ROADMAP.md for the complete target and test tiers. Visual
C++ runtime DLLs are included beside the program. No system DLL replacement
or global compatibility layer is part of this proof.

This version has passed development-machine automated tests. Windows 7 testing
of this new viewport is still required. Earlier 0.1 startup results do not
establish compatibility of the newly integrated code.

Test procedure
--------------

1. Extract every file to a writable local folder. Keep all DLLs beside the EXE.
2. Run RUN-DIAGNOSTICS.cmd. Retain VT7-diagnostics.log, even if it fails.
3. Run RUN-VIEWPORT-TEST.cmd. Retain VT7-viewport-test.log, even if it fails.
   This runs hidden window, paint, resize, reset, and disposal tests.
4. Run RUN-VT7.cmd. Confirm the static terminal demonstration appears.
5. Inspect colors, bold, underline, box drawing, accented and wide characters.
   Report missing or clipped glyphs. Font fallback is not a finished feature.
6. Resize repeatedly, minimize/restore, switch tabs, and reset the demo.
   Resizing should preserve/reflow content, not recreate the demonstration.
7. Close and reopen several times. Send both logs and a screenshot, with your
   Windows update level, graphics driver version, CPU, and display scaling.

What this tests
---------------

- WPF startup, native ABI 2 loading, and Windows version detection.
- Windows 7-compatible DXGI, hardware D3D11, and WARP device creation.
- Seven checks against the actual TerminalCore/parser/text buffer.
- A real native child HWND, GDI paints, resize propagation, and disposal.

The viewport uses a temporary double-buffered GDI renderer, not Atlas or a
Direct3D renderer. Core Unicode tests check buffer behavior, not visual shaping.
See CORE-PROVENANCE.md for source provenance and deliberately excluded features.

There are no sessions, keyboard forwarding, selection/copy/paste, scrolling UI,
search, tabs for sessions, panes, or profiles yet. The Diagnostics tab is a test
panel, not a terminal session tab.

Diagnostics are written locally, including a copy in %LOCALAPPDATA%\VT7\Logs.
Nothing is uploaded. Logs include machine/software details and local paths;
review them before sharing. SHA256SUMS.txt covers the supplied files, including
symbols and licenses. It is an integrity list, not a digital signature.

License
-------

VT7 is MIT licensed. See LICENSE.txt, NOTICE.md, CORE-PROVENANCE.md, and licenses/.
The bundled Visual C++ runtime DLLs are Microsoft components redistributed under
the applicable Visual Studio license terms, not the VT7 MIT License.
