# Atlas viewport 0.3.0: first full-engine integration

> Historical validation record. Status and next steps below describe this checkpoint.
> For current work, see the [handoff](../HANDOFF.md) and
> [0.3.5 C3 stability investigation](2026-09-13-atlas-stability.md).

Date: 2026-09-12. Status: C1/C2 accepted on the supplied Windows 7 SP1 x64
configuration. This is not completion of Milestone 2 or a separate ESU result.
The [port-first plan](../architecture/2026-09-12-port-first-plan.md) governs scope.

## What changed

- The WPF/native viewport now connects real TerminalCore/IRenderData to the
  inherited renderer controller and AtlasEngine. The default is Atlas Direct3D11
  hardware, with explicit Direct3D11 WARP, Direct2D hardware/WARP, and GDI modes.
- A minimal `Win7FontFallback` uses baseline DirectWrite layout callbacks only
  to select and retain faces. Atlas still shapes logical source text and fits
  advances to authoritative core clusters on its inherited primary-font grid.
  Newer mandatory font-fallback interfaces are removed from the VT7 path.
- A bounded owned mapping cache holds at most 32 entries and 32,768 UTF-16 units.
  Configuration changes clear it. Four style variants and the existing private
  Unifont assets are supported, with system faces preferred and private fallback
  limited to uncovered standalone symbols/pictographs. Font hashes are checked
  before loading. Missing/altered assets fail instead of silently changing fonts.
- The real controller uses Windows 7 kernel events rather than address-based
  waits. Stop interrupts redraw/output/backoff waits; worker teardown precedes
  HWND/core/engine destruction. Restart reconciles the synchronized-output event
  with core state. The caret path uses `GetCaretBlinkTime`, without the newer
  caret-blink system metric. Full scheduling stress remains C3 work.
- Native ABI 3 carries renderer mode, requested/completed frame generations and
  diagnostic raster information. Atlas counts completed submissions, not WM_PAINT
  requests. Test-only readback runs on the renderer thread before discard Present;
  PNG encoding consumes an owned CPU copy. Ordinary visible runs do not read back
  every frame. EndPaint errors propagate to the controller's failure handling.

The detailed [font/renderer boundary](../../../src/vt7/VT7.Renderer/README.md) and
[core boundary](../../../src/vt7/VT7.Core/README.md) describe ownership and limits.
No optional fitter, Arabic repair, joined-span or alternate interaction pipeline
was added to Atlas. The upstream baseline is unchanged. Code remains MIT;
unmodified private fonts retain their OFL 1.1 license and provenance.

## Local evidence

Development system: Windows NT 10.0.19044 x64, .NET Framework 4.8.9339.0,
AMD Radeon RX 7900 XTX. Toolchain: Visual Studio 2022 17.14, MSVC 14.44.35207
(compiler 19.44.35228), SDK 10.0.26100.0. These are not Windows 7 results.

| Check | Local result | What it establishes |
| --- | --- | --- |
| Debug and Release builds | Pass | Full engine, controller, core and host link together |
| Core diagnostics, both configurations | Pass | Seven retained core checks and the new font-boundary check |
| Font boundary | 48 mappings pass | Six source fixtures, two sizes, four styles, cached repeats, complete logical ranges/core-cluster boundaries, symbol coverage and invalid-input controls |
| GDI reference, both configurations | Pass | Four HWND lifecycles and eight tab round trips per run |
| Atlas D3D11 hardware/WARP and D2D hardware/WARP, both configurations | All pass | Same lifecycle matrix, requested/completed frames, nonempty header ink, stable reset hashes, hidden-tab frame quiescence and disposal |
| Deliberately blank Atlas frame | Expected failure | Raster checks reject an empty frame even when the GPU path executes |
| Missing or altered private font, each of two assets | Four expected failures | Diagnostics reject absent/tampered assets in isolated package copies |
| Static binary/import audit | Pass | Current EXE/DLL boundary meets the existing Windows 7 audit rules |
| Older Atlas backend harness, Debug/Release | Pass | Four backend/device combinations, 19 frames each, pixel/resize/recreation and negative checks |
| Retained renderer probe 0.13, rebuilt Release | Pass | All eight validators plus injected-failure, CLI/report and private-font controls still pass against the changed core |

Commands: `tools/Build-VT7.ps1`, `tools/Test-VT7.ps1`,
`tools/Test-VT7FontAssets.ps1`, `tools/Verify-VT7.ps1`,
`tools/Test-VT7AtlasProof.ps1`, and `tools/Test-VT7RendererProbe.ps1`.
Local logs/captures are under `artifacts/vt7/reports/<configuration>/`.
Isolated font-asset negative copies are under `artifacts/vt7/font-asset-negative-*`.
Packaging repeats the viewport matrix, font-asset controls and binary audit on
the assembled Release directory with its app-local runtime.

The integrated captures were visually inspected for sample text, indexed/true
colors, decorations, box drawing and mixed-script/fallback output. They are GPU
back-buffer captures, not screenshots of the user's desktop. The two fallback
symbols use Segoe UI Emoji on this development system, so their appearance does
not establish the private-font path on Windows 7. Diagnostics record selected
font file paths; target font identity and appearance must be examined separately.

Integration defects caught and corrected locally included construction-time core
lock assertions, test fixtures reading row zero after erase had moved the viewport,
and the risk of reading a discard back buffer after presentation. Tests now use
the actual viewport origin, hold the required lock and capture before Present.

## Handoff artifact

The new package is `artifacts/VT7-atlas-viewport-0.3.0-x64.zip`, produced by
`tools/Package-VT7Proof.ps1`. It includes the host/native binaries, pinned runtime,
private fonts, licenses/provenance, symbols, launchers and `SHA256SUMS.txt`.
The accepted 0.2.1 host, 0.1 backend and 0.13 probe archives are not replaced.

Issued archive: 10,389,955 bytes.
SHA-256: `BA2499B3E1C6C8C4ED666E7961A68C064298C5E06267D140C060C924A2553AF7`.
Release native build stamp: `Sep 12 2026 02:01:52`, ABI 3.
All 29 payload files were independently checked against `SHA256SUMS.txt` both
inside the zip and in the assembled directory, with no unmanifested payloads.
The assembled-package tests passed all five viewport modes, the blank-frame
negative and four font-asset negatives. The frozen 0.13 archive still matches
its recorded `C73263D43E9866F51F513F19FA832D1E06D6B61EA89178DC96F311196AB3E421` hash.

## Windows 7 acceptance procedure

1. Extract the complete new package into a fresh directory, including `fonts/`.
   Do not replace DLLs inside an older proof folder. Record OS servicing tier,
   GPU/driver, .NET version and display scaling separately for each setup.
2. Run `RUN-DIAGNOSTICS.cmd`, then `RUN-VIEWPORT-TEST.cmd`. Retain
   `VT7-diagnostics.log` and the complete `Logs` folder. The viewport launcher
   runs GDI and all four Atlas modes, with separate reports and Atlas PNGs.
3. Run `RUN-VT7.cmd` for visible hardware output and `RUN-ATLAS-WARP.cmd` for
   visible WARP output. Inspect text/colors, accents/combining text, CJK, box
   drawing, fallback symbols and cursor alignment. Resize, minimize/restore,
   cover/uncover, switch tabs, reset, and close/reopen. Supply screenshots.
4. Direct2D can be opened with `VT7.Host.exe --renderer atlas-d2d-hardware`
   or `--renderer atlas-d2d-warp`. `RUN-GDI-REFERENCE.cmd` is the comparison path.
   Preserve logs before rerunning launchers. They overwrite their own file names;
   batch launchers have no hang timeout. Report hangs and retain partial output.

## Supplied Windows 7 acceptance

The supplied run uses Windows NT 6.1.7601 SP1 x64, .NET Framework 4.8.4795.0,
AMD Radeon RX 6800 XT, and the issued 0.3.0 build stamp/ABI 3 above. Logs span
02:06:36 through 02:08:42 +02:00 on September 12. A precise driver/update inventory
and separate ESU run are not supplied for this checkpoint.

Preserved evidence: `artifacts/vt7/evidence/atlas-viewport-win7-630d60e0/`,
containing the supplied diagnostic, both log folders and four screenshots.
The diagnostic SHA-256 is
`A53BD97505E646229BF9295FFE8165573AC89324199F57CAD9345061EB686E31`.

- `VT7-diagnostics.log` passes all seven core checks and the 48-mapping font suite.
- All five `Logs/viewport-*.log` reports pass, each with four HWND lifecycles
  and eight tab round trips: 20 lifecycles and 40 round trips total.
- All four Atlas reports identify the requested backend/device, completed frames,
  nonempty raster data and matching repeated-reset pixels. Hidden-tab frame
  quiescence, resize, minimize/restore and disposal checks pass.
- All 22 additional reports have `Passed: True`, no FAIL lines and `Error: None`.
  They are supplementary snapshots, not 22 independent full acceptance runs.
- Font diagnostics select Consolas for Latin, Meiryo for CJK, Segoe UI for Arabic,
  Segoe UI Symbol for U+262F and bundled Unifont Upper for U+1F600. The private
  missing-system-glyph path is exercised on the target, with unchanged source cells.
- Four screenshots show visible Direct3D11 hardware/WARP output and readable
  diagnostics. Supplied back-buffer captures cover all four Atlas modes; the
  Direct2D/WARP capture was also inspected. These do not prove visual equality
  across different backends or devices, whose raster hashes can differ.

C1/C2 are accepted for this configuration and bounded corpus. Broader font/DPI,
recovery, scheduling/stability and full Milestone 2 acceptance remain open.
Earlier ESU proof success is not a separate ESU test of this package.

One non-blocking diagnostic defect is visible: the hardware status label says
`paints 0` despite rendered text. The host refreshes status before asynchronous
render completion and does not subscribe to later frames. Automated checks wait
for actual completed requests and pass. Correct status refresh in the next build,
without adding continuous diagnostic log writes or misreporting requested frames.

## Limits and next checkpoint

This remains a fixed sample, not a shell, SSH session, selection UI or finished
terminal. GDI is an explicit reference, not an automatic recovery path. There is
no automatic hardware-to-WARP fallback yet. Completed submission counters do not
prove unobscured desktop presentation; header ink does not prove every glyph.
Repeat-reset identity is not an incremental edit/repaint correctness suite.

The initial font configuration uses one primary family and monochrome static
faces. Extra explicit family preferences and variable axes are unsupported.
The adapter preserves core clusters if OS callbacks split one by retaining the
cluster's starting face; complete coverage of arbitrary combining sequences is
not established. Bold/oblique private variants are simulations. The sample keeps
inherited logical-cell Arabic, not the more connected experimental probe output.
Appearance refinements belong in POL04/POL05; missing required glyphs, source/cell
loss or adaptation-induced unreadable text remain blockers.

At this build's C1/C2 acceptance, the next work was C3: integrated differential repaint and
cursor/grid checks, DPI/size/settings changes, automatic fallback/recovery,
idle/hidden/minimized CPU and bounded scheduling/teardown stress. The smoke tests
do not prove lost-wake freedom, resource-growth budgets or long-running stability.
Do not restart optional typography research unless a named port blocker needs it.

Later follow-up: the [0.3.4 matrix](2026-09-12-atlas-scaling-correction.md)
accepts bounded viewport, repaint, injected recovery and font/settings checks at
actual Windows 7 96/120/144 DPI. It resolves the intervening 0.3.3 scaling failures.
Theme and broader milestone qualification remained open at that checkpoint.
The subsequent [0.3.5 stability investigation](2026-09-13-atlas-stability.md)
records scheduling, idle, resource and shutdown checks and their open acceptance
issues. Use the [handoff](../HANDOFF.md) for current priorities. Earlier evidence
above retains its original scope.
