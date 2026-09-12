VT7 Atlas viewport 0.3.4
=======================

The terminal application Windows 7 always deserved, one tested step at a time.
This engineering build connects the real AtlasEngine and renderer controller
to TerminalCore in the WPF/native HWND viewport. It is still a static terminal
demonstration, not a usable shell or a public alpha release.

Target: Windows 7 SP1 x64, Platform Update KB2670838, .NET Framework 4.8,
UCRT KB2999226, required loader/SHA-2/servicing prerequisites, and D3D11 hardware
or WARP. See the source ROADMAP.md for the complete target/test tiers.
No system DLL replacement, font installation or compatibility layer is needed.

Keep all DLLs and the entire fonts directory beside the EXE. The included
Unifont files are checked against pinned SHA256 values before DirectWrite loads
them. A missing or altered file is a diagnostic failure, not silent fallback.

Windows 7 test procedure
------------------------

1. Extract the complete archive into a fresh writable folder. Do not overwrite
   the 0.3.3 evidence or accepted 0.3.2/0.3.1/0.3.0/0.2.1 viewport or 0.13 probe folders.
2. Run RUN-DIAGNOSTICS.cmd. Keep VT7-diagnostics.log, including failures.
3. Run RUN-VIEWPORT-TEST.cmd. It runs six hidden modes: GDI reference, Atlas
   Direct3D11 hardware/WARP, Atlas Direct2D hardware/WARP and automatic. Keep the entire
   Logs folder. Each Atlas mode also produces a diagnostic back-buffer PNG,
   not a desktop screenshot. The hidden tests include frame completion/pixels,
   repeat-reset consistency, resizing, tab hide/show and disposal.
   Also run RUN-REPAINT-TEST.cmd: four Atlas modes, two window sizes, 32 exact
   comparisons and eight cursor-cell checks per mode. Keep its captures and the
   repaint-negative.log, which must fail with Atlas differential repaint mismatch.
   Run RUN-RECOVERY-TEST.cmd for 16 controlled failure scenarios. All should PASS,
   including tests that intentionally reach a fatal state and assert retries stop.
   Errors are injected inside VT7, not into the driver. No system changes occur.
   Run RUN-SETTINGS-TEST.cmd and choose the ACTUAL Windows scaling: 100, 125 or
   150 percent. Five Atlas modes must pass. Reports include the selected DPI in
   their names and four PNGs per mode. A wrong expected system DPI must fail.
4. Run RUN-VT7.cmd for visible automatic Atlas Direct3D11. Run
   RUN-ATLAS-WARP.cmd for visible Atlas Direct3D11 WARP. The status identifies
   the actual backend and recovery/fallback counts. Auto mode can select WARP;
   forced modes never substitute a different device. GDI is never automatic.
   RUN-GDI-REFERENCE.cmd opens the retained GDI comparison path.
5. Enlarge the window to see the complete sample. Inspect Latin, bold,
   underline, box drawing, combining/CJK text, symbols and logical-cell Arabic.
   Resize, switch tabs, minimize/restore, reset and reopen several times.
   Inspect keyboard navigation, focus and readable Diagnostics too.
6. Return VT7-diagnostics.log, the Logs folder and desktop screenshots of
   hardware and WARP. Include GPU/driver, actual display scale and Windows
   update tier. Report any hang, missing glyph, misplaced cell or stale pixels.

To reproduce the accepted system-DPI matrix, run ALL five test launchers at Windows 7
100/125/150 percent scaling. Change scaling yourself, save your work before any
required sign-out, and start a new Windows session/application before testing.
The launcher does not change scaling. Internal renderer overrides of 96/120/144
DPI are simulations and do not count as three system-scaling runs. At each real
scale, also capture the normal and WARP viewport and Diagnostics, inspect text,
clipping, tabs and focus, then retain that scale's screenshots and Logs separately.
You can send the current-scale results first and test the other scales afterward.
At 150 percent especially, capture each visible window immediately after launch,
before manually resizing. Its title bar and bottom buttons should fit the work
area. Short viewports can scroll the sample's first lines out of view.

Release 0.3.4 now passes all positive suites at actual Windows 7 96/120/144 DPI
on the supplied SP1 x64, .NET Framework 4.8.4795.0, Radeon RX 6800 XT setup.
This accepts the bounded corrective scaling checkpoint, not all of Milestone 2
or a separate ESU/hardware matrix. AppData may record intentionally fatal test
surfaces as Passed: False; match these to the passing named recovery reports.
Only repaint-negative.log deliberately fails among the named packaged tests.
The source documentation records this post-test acceptance. The originally
issued archive remains unchanged, including its pre-acceptance README and hash.

What changed and what did not
-----------------------------

- Native ABI 7 and matching managed host, with actual completed-frame reporting,
  requested/actual device, device generations, retry/fallback and injection counts.
- Baseline Windows 7 DirectWrite layout selects font faces. Atlas retains its
  own logical-order shaping, primary grid and glyph-cluster advance fitting.
- Pinned private monochrome symbol fallback is used only when the system face
  lacks the standalone cluster, with DirectWrite bold/oblique simulations.
- Real renderer control with Windows 7 event waits; hidden tab workers stop
  before resources can be destroyed and restart on return.
- Seven inherited-core regression checks plus a 48-mapping font-boundary suite.
- Integrated normal-invalidation/full-redraw RGB comparisons, VT edits and cursor
  show/move/shape/hide bounds. The negative alters a saved CPU comparison pixel.
- Bounded first-frame status refresh fixes the stale zero-frame label. The label
  now says frames (snapshot), not a live counter. No per-frame logging is added.
- Automatic hardware-to-WARP fallback on eligible device creation failure or two
  consecutive recoverable device failures. WARP stays selected for this surface.
- Existing controller retry bound and interruptible shutdown, plus posted UI
  notifications on recovered/fatal transitions. Injection is diagnostic-only.
- Bounded primary-font settings: Consolas/Courier New, size and normal/bold weight,
  worker parking, core reflow, hidden updates and input validation. This is an
  engineering API/test, not the final settings UI or arbitrary-font preferences.
- Ten settings cases per Atlas mode, exact redraw/source/geometry checks, baseline
  restoration, and measured WPF/native system DPI. The visible status reports DPI.
- Frame waits include newer pending requests, avoiding stale settings readback.
- Corrective 0.3.4 fits the initial window to the monitor work area. Status text
  stays one line, with full details in its tooltip and logs, so recovery reporting
  cannot resize the terminal behind an image comparison. New controls reproduce
  the old wrapping behavior and accept a blank first row with visible text below.
  Entirely blank frames still fail. Recovery logs now include before/after client
  and captured image dimensions; strict same-device RGB comparison remains.

The new path does not adopt the optional Arabic joining/centering, cross-style
ligature or paint experiments. Their evidence is retained for final polish.
Only one primary family is accepted in this first integration; comma-separated
secondary-family lists and variable axes are explicitly unsupported. System
fallback still selects other families as needed. Color glyphs are disabled.
Unknown characters retain core text/cells; no universal font coverage is claimed.

The next work is bounded scheduling, idle CPU, resource-growth and shutdown stress.
Broader real-device-loss/race/soak acceptance, Windows 7 theme/high-contrast
coverage and full Milestone 2 qualification remain ahead. The actual
100/125/150 percent scaling checkpoint is accepted only on the tested setup.
There are no sessions, keyboard forwarding, interactive selection/copy/paste,
scrolling UI, search, session tabs, panes or profiles yet. The Diagnostics tab
is a test panel. Use the roadmap for current port-first checkpoints.

Privacy and licensing
---------------------

Logs remain local and include environment information and paths. Review before
sharing. Test captures contain only the fixed demonstration. Nothing is uploaded.
SHA256SUMS.txt is an integrity manifest, not a digital signature.

VT7 code remains MIT licensed. See LICENSE.txt, NOTICE.md, CORE-PROVENANCE.md,
RENDERER-PROVENANCE.md and licenses/. The unmodified Unifont assets retain
their separate OFL 1.1 license and attribution in fonts/. Visual C++ runtime
DLLs retain Microsoft's redistribution terms. No new third-party code is added.
