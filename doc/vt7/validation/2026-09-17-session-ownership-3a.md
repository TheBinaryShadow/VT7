# 3A terminal document and session ownership validation

Date: 2026-09-17. Working source: VT7 0.4.0, native ABI 11, x64.

Status: accepted in Debug and Release locally and on the issued Windows 7 SP1
x64 target candidate. This record does not claim a real shell or SSH connection;
production WinPTY integration begins in 3B.

## Implemented boundary

- ABI 11 exposes opaque `TerminalDocument` and `TerminalView` handles. The
  document owns TerminalCore, scrollback, the incremental UTF-8 stream,
  producer generations and a bounded terminal-reply queue. The view owns the
  child HWND, Atlas engine, font/DPI state and renderer callbacks.
- One document allows one attached view. Destroying an attached document returns
  `HRESULT_FROM_WIN32(ERROR_BUSY)`. Detaching or destroying a view does not end
  the stream, clear TerminalCore or change the document identity.
- The stable upstream renderer controller remains with the document because
  TerminalCore stores its address. Detach stops its worker, unregisters view
  callbacks and removes the Atlas engine; reattach supplies a new engine and
  restarts the controller.
- `SessionOutputPump` targets the document dispatcher. Native writes carry stream,
  origin-transport and producer sequence values. TerminalCore responses are
  copied while the core is locked, drained afterward, and sent only to the
  transport generation that caused them.
- Managed `TerminalSession` owns the document pump, root/overlay state machine,
  bounded outbound queue, active input generation and awaited transport closure.
  `ITerminalTransport` exposes explicit state, completion result, start, write
  and close operations. The backend-free host uses the deterministic fake root
  until 3B supplies `WinPtyTransport`.
- ABI 10-era surface exports remain as a one-transition compatibility facade for
  established renderer and resource diagnostics.

## Acceptance evidence

The updated `Test-VT7SessionStream.ps1` requires all prior UTF-8/VT checks plus
these 3A controls:

1. reject destruction while the document has a view;
2. write a prefix, destroy the child HWND, and prove the document reports no
   attachment;
3. drain the remainder of the 388-byte fixture with no view;
4. attach generation 2 and reproduce raster `D90BE1DA17351A44` exactly;
5. switch fake root/overlay/root input generations 1/2/3 while root and overlay
   output share one decoder stream;
6. issue a TerminalCore device-attributes query and observe its reply only at
   the originating fake root;
7. close transports and the document stream exactly once.

The following completed successfully on the development machine:

```powershell
.\tools\Build-VT7.ps1 -Configuration Debug
.\tools\Test-VT7SessionStream.ps1 -Configuration Debug
.\tools\Test-VT7SessionOutbound.ps1 -Configuration Debug
.\tools\Test-VT7.ps1 -Configuration Debug

.\tools\Build-VT7.ps1 -Configuration Release
.\tools\Test-VT7SessionStream.ps1 -Configuration Release
.\tools\Test-VT7SessionOutbound.ps1 -Configuration Release
.\tools\Test-VT7.ps1 -Configuration Release
```

Both full smoke runs passed GDI, D3D11 hardware/WARP, D2D hardware/WARP,
automatic Atlas selection, and the injected blank-frame negative. Session
stream and outbound reports have `Passed: True` and no `FAIL:` line.

The non-overwriting target candidate is
`artifacts/VT7-Session-Ownership-0.4.0-x64.zip`, SHA256
`93DFB2B35D94DE6610C8734889D837594D593F3584F0FAE78F4679853AAE0449`,
10,642,845 bytes and 27 verified files. Its staged Release payload passed both
focused runners before ZIP creation; every archive entry was rehashed afterward.

## Windows 7 target result

The exact candidate completed on the Windows 7 SP1 x64 target on 2026-09-17.
Both focused reports have `Passed: True`, `Error: None`, application version
0.4.0 and native ABI 11. The runner-recorded binary identities match the issued
package:

- `VT7.Host.exe`: `AEC1EDB890D7005BE09BCF69800B58A0FC37DF1917FDAF4BDF7A3E16E24FC507`;
- `VT7.Native.dll`: `004F9F3AA2E820D899ACBA7579BB1A87D7D50C6A71E86FB38727AD92C5BD9FA2`.

The ownership run destroyed the first HWND, drained all 388 fixture bytes while
the document was detached, reattached view generation 2, and matched exact
raster `D90BE1DA17351A44`. The managed lifecycle then switched fake
root/overlay/root input generations 1/2/3, returned the TerminalCore reply to
its originating transport, drained both transports into one document stream,
and closed exactly once. The companion outbound run also passed stale-generation
rejection, bounded backpressure, FIFO drain, native Croatian input, distinct
Ctrl+C/Ctrl+Break handling, focus reconciliation and authoritative resize.
TerminalCore, UTF-8, font, hardware D3D11 and WARP regression checks passed in
both reports.

The three supplied evidence files total 5,680 bytes. Byte-identical copies,
per-file hashes, package correlation and an independent acceptance summary are
archived under
`artifacts/vt7/evidence/session-ownership-win7-0.4.0`.

## Remaining boundary

This closes 3A implementation and its focused Windows 7 target qualification,
not production transport delivery. The next bounded task is `WinPtyTransport`
behind the accepted interface, starting with one explicit Command Prompt
profile. H01, SSH.NET production integration, typed `ssh` interception,
trust/auth UI, IME, broader layouts and release qualification remain later work.
