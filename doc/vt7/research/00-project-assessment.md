# Project assessment and research priorities

Assessed 2026-09-11. Repository HEAD: **28cb8bf7d023e270989b37d038c35364cf87540b**. Assessment includes the existing uncommitted working files, including VT7.Renderer, VT7.RendererProbe, Win7Presentation, Atlas changes, and updated build/validation documents. Their presence is not evidence that they have been committed, packaged, or accepted.

The working tree was being developed during this research. A final read at approximately **04:11 UTC** also found VT7.AtlasProof and its test harness. Its source constructs fixed Consolas glyph payloads and calls the real Atlas backends directly, bypassing AtlasEngine font mapping and TerminalCore. The harness requests hardware/WARP and D2D/D3D runs with redraw/readback checks. This is useful additional test infrastructure; no results from running that new harness were assessed here. [14]

## Goal and architectural fit

Later implementation evidence, not part of the original research run: the
[backend validation record](../validation/2026-09-11-atlas-backend-proof.md)
now documents all four Windows 7 backend/device tests passing, visible
Direct3D11 hardware/WARP output, and 8/6 R-key recreations. Read the evidence
table below as the original source-review snapshot. Its then-unassessed
backend harness now has runtime evidence, but still bypasses font mapping and
TerminalCore/controller integration. The missing glyph remains tracked in 2C.

VT7 is intended to be a standalone x64 Windows 7 SP1 terminal with tabs, panes, profiles, local shells, SSH, modern VT behavior, good Unicode rendering, and portable distribution. The preferred architecture reuses Microsoft Terminal's portable core and Atlas work while replacing dependencies on newer Windows services. The project explicitly excludes providing OS-level ConPTY or requiring replaced system DLLs. [1][2]

The inherited baseline is Microsoft Terminal commit c7572cde0c69733e4511787dc963eb336f17adbf. Upstream history and licenses are retained. Historical Windows 7 branches and removed renderer paths are reference material, not ready-made ports of the current baseline. [3]

**Assessment:** the decomposition is sound for proving feasibility. It isolates the UI, terminal state, rendering, and eventual transports. The greatest remaining risk is semantic integration: preserving the same text, cell coordinates, input interpretation, and lifetime rules across independently evolving subsystems.

## What the evidence establishes

| Area | Evidence inspected | Limit of the conclusion |
| --- | --- | --- |
| Host/native/core | WPF HwndHost owns a native child window through ABI 2; the window writes a fixed demonstration into TerminalCore, draws using GDI, and resizes/reflows the core. [4][5] | No interactive session or input forwarding is present in this proof. |
| Windows 7 viewport | 0.2.0 logs/screenshots and 0.2.1 cleanup records show successful static viewport operation. Non-ESU artifacts were supplied; separate ESU success is tester-confirmed. [6][7] | Fully serviced machines do not establish the exact minimum prerequisite image. |
| Regression scope | Seven focused core checks, four window lifecycles, and eight tab round trips are recorded for the cleanup proof. [7] | These do not establish sustained use, IME, accessibility, modern shaping, or shell correctness. |
| Atlas build | The isolated renderer target is documented as compiling Atlas translation units and generating shaders. It is not referenced by VT7.Native or shipped in the capability package. [8] | A static library can contain unsupported references until link/runtime paths become active. |
| Graphics/font probe | The independent Windows 7 probe reports 49 required checks with no failures, but one missing glyph. [9] | It does not load Atlas, identify the missing character, prove terminal-cell mapping, or establish visible frame correctness. |
| Working presentation code | Win7Presentation.cpp requests hardware/WARP explicitly and creates an opaque HWND discard swap chain, with positive-size checks and full-dirty marking. [10] | Source inspection is not acceptance of either actual full redraw or safe resource teardown. |
| New backend proof source | VT7.AtlasProof constructs fixed glyphs, forces full-dirty frames, and includes pre-Present readback and recreation checks. [14] | It bypasses real font fallback and core/controller integration; source and test expectations are not a test result. |
| DirectWrite startup | AtlasEngine.cpp still requests Factory2 and system fallback; common.h contains partial Factory1/FontFace1 adaptation. [11] | The presentation port cannot by itself remove this Windows 8.1 font dependency. |
| Search/dependencies | VT7_CORE excludes ICU search/URL discovery; SearchText reports unavailable. The proof renderer is an invalidation adapter, not the real controller. [4] | Search and renderer scheduling require explicit restoration decisions. |

## Important architectural conclusions

1. **Make session capabilities explicit.** WinPTY's screen reconstruction, a direct SSH channel, and any future direct byte-stream backend have different fidelity. Test local legacy-console colors/Unicode separately from direct VT rendering. The [console analysis](02-console-and-winpty.md) explains the likely local limitations.
2. **Keep one authoritative cell model.** The core's cell allocation must drive cursor movement, selections, resize messages, hit testing, and accessibility. A font's natural advance is insufficient to define the terminal grid.
3. **Choose the shaping boundary before optimizing Atlas.** A layout-callback adapter may supply Windows 7 font fallback, but needs a mapping between UTF-16 text, glyph clusters, and terminal cells. Resolve the existing missing-glyph report first.
4. **Prove the scheduler as an independent component.** Replacing one WaitOnAddress-backed core lock leaves the upstream render-thread waits and synchronized-output protocol unresolved. [12]
5. **Treat prerequisites as capabilities with provenance.** Capture DLL versions, interface/method results, update inventories, and exact packaged runtimes. Installed-KB names alone can be misleading when superseding updates provide the same capability.
6. **Plan native text interaction now.** A rendered HWND does not automatically acquire WPF text selection, IME placement, or a screen-reader text model.

These are recommendations derived from the inspected boundaries and the subsystem research, not changes to the roadmap.

## Development order that minimizes rework

Planning follow-up: the table below preserves the original research priorities.
The [adopted plan](../architecture/2026-09-11-research-driven-plan.md) and roadmap
now set execution order. OpenSSH evaluation is a required 3A feasibility gate
alongside WinPTY fidelity and keyboard behavior, before substantial local/UI
integration. Session, IME, accessibility-range, and output-security contracts
are defined early; full implementations remain in their assigned milestones.
The missing-glyph investigation belongs to 2C, not a restart of accepted backend
presentation work. None of these scheduling decisions supplies runtime evidence.

| Priority | Proposed investigation | Artifact needed before committing to the design |
| --- | --- | --- |
| P0 | Identify the exact missing glyph in the Windows 7 probe | Code points, source UTF-16 range, face/file/version, glyph IDs, and visible output |
| P0 | Prototype Windows 7 fallback-to-Atlas mapping | Retained glyph runs, cluster/cell correspondence, Arabic/Indic/CJK/combining samples |
| P0 | Validate discard/full redraw and resize ownership | Frame captures after sparse updates, resize, uncover, minimize and device recreation |
| P0 | Replace renderer waits with predicate-based synchronization | Lost-wake, timeout, synchronized-output and shutdown stress results |
| P0 before input integration | Investigate inherited ToUnicodeEx flag semantics | Dead-key/AltGr tests on Windows 7; the existing non-mutating flag is a later Windows feature [13] |
| P0 before session promises | Measure WinPTY fidelity | Captures from W and A console APIs, raw VT, alternate buffers, code pages and resize |
| P1 | Define session ownership and native/managed callbacks | Written create/close protocol and no callbacks after destruction |
| P1 | Build input and IME prototype | Keyboard-layout matrix, composition placement, no duplicate committed characters |
| P1 | Audit exact runtime/prerequisite closure | Clean minimum-image launch and complete package import/load report |
| P2 | Restore search, clipboard, accessibility and persistence | Chosen Unicode semantics and failure/rollback behavior |
| P2 | Evaluate Microsoft Win32-OpenSSH first, then select the SSH integration | Exact client/runtime record, raw I/O, prompt handling, host-key and live PTY-resize tests; see the [reassessment](22-win32-openssh-reassessment.md) [15] |

The detailed [experiment plan](20-validation-and-experiments.md) makes these investigations reproducible. This research did not build, launch, install, modify, or test any application outside this directory.

## Sources

- [1] [README](../../../README.md).
- [2] [Roadmap](../../../ROADMAP.md).
- [3] [Upstream policy](../../../UPSTREAM.md).
- [4] [Core proof boundary](../../../src/vt7/VT7.Core/README.md).
- [5] [Native viewport implementation](../../../src/vt7/VT7.Native/surface.cpp) and [HwndHost ownership](../../../src/vt7/VT7.Host/TerminalSurface.cs).
- [6] [0.2.0 validation](../validation/2026-09-10-viewport-proof.md).
- [7] [0.2.1 acceptance](../validation/2026-09-10-milestone-1-cleanup.md).
- [8] [Isolated renderer target](../../../src/vt7/VT7.Renderer/README.md).
- [9] [Renderer probe record](../validation/2026-09-11-renderer-probe.md).
- [10] [Working Windows 7 presentation implementation](../../../src/vt7/VT7.Renderer/Win7Presentation.cpp).
- [11] [Atlas startup](../../../src/renderer/atlas/AtlasEngine.cpp) and [shared renderer types](../../../src/renderer/atlas/common.h).
- [12] [Renderer controller](../../../src/renderer/base/renderer.cpp) and [address-wait helpers](../../../src/inc/til/atomic.h).
- [13] Microsoft, [ToUnicodeEx flags](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-tounicodeex); [inspected TerminalInput helper](../../../src/terminal/input/terminalInput.cpp). See [API compatibility details](21-api-availability.md).
- [14] [New Atlas backend proof source](../../../src/vt7/VT7.AtlasProof/main.cpp), [project](../../../src/vt7/VT7.AtlasProof/VT7.AtlasProof.vcxproj), and [test harness](../../../tools/Test-VT7AtlasProof.ps1), observed during final research review.
- [15] Microsoft Win32-OpenSSH project, [Windows 7 installation compatibility](https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH) and [modern client release](https://github.com/PowerShell/Win32-OpenSSH/releases/tag/10.0.0.0p2-Preview).
