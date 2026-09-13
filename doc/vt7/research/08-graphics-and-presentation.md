# Direct3D 11, DXGI, Direct2D, WARP and presentation

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P0.

## What the Platform Update supplies

Implementation follow-up: the
[Atlas backend proof](../validation/2026-09-11-atlas-backend-proof.md) now
passes on the tested Windows 7 system for Direct3D11/Direct2D on hardware/WARP.
It validates fixed-glyph full redraw, resize, and explicit recreation, with
visible Direct3D11 screenshots and R-key logs. The original recommendations
below remain relevant to full engine integration and broader lifecycle testing;
they are not claims that all those experiments were executed.

KB2670838 brings Direct2D 1.1 and Windows 8-era DirectWrite/WIC, but only partial Direct3D 11.1 and DXGI 1.2. DirectComposition is absent. Non-HWND swap chains, desktop duplication and several notification/shared-resource features are unavailable; DXGI_SCALING_NONE is unsupported. Hardware feature level remains 11.0 or lower. Windows 7 WARP does not supply shared surfaces. [1]

**Consequence:** implement and test the specific HWND method/descriptor combination, not an abstract “DXGI 1.2 supported” boolean. Keep device feature level, COM interface version and driver capability as separate fields.

## Device creation

D3D11CreateDevice requires consistent adapter/driver arguments: an explicit adapter pairs with D3D_DRIVER_TYPE_UNKNOWN; passing it with HARDWARE is invalid. Requesting unavailable runtime features can produce E_INVALIDARG. Debug-device creation can fail when the proper SDK layer is absent. [2]

Recommended candidate: an explicit null-adapter HARDWARE attempt, or an explicit chosen adapter with UNKNOWN; use a separate null-adapter WARP attempt for software. Request only feature levels the renderer actually supports. Include BGRA support for Direct2D interoperability and verify the chosen format/path. [2][3]

Observed in repository: Win7Presentation.cpp already uses explicit hardware/WARP creation, 11.0/10.1/10.0 feature levels, BGRA support, and a retry without the debug layer for the specific missing-layer error. It queries Device1/Context1 and derives the factory from the created device. These choices still need integrated runtime evidence. [4]

## Swap effects and redraw

DXGI_SWAP_EFFECT_DISCARD and SEQUENTIAL are bitblt modes. DISCARD does not preserve the back-buffer contents. FLIP_SEQUENTIAL starts with Windows 8 for D3D11; FLIP_DISCARD starts with Windows 10. [5]

The current candidate uses one BGRA8 buffer, STRETCH scaling, DISCARD, no extra swap-chain flags, an opaque HWND, and Present(1,0). [4]

**Critical invariant:** a discard swap chain requires drawing every needed pixel for the next frame. Calling Present with no dirty rectangles does not cause Atlas to redraw unchanged areas. Verify that the engine's invalidation and both backends really produce a complete frame every time.

A SEQUENTIAL candidate could retain contents, but its correctness and performance must be separately measured. Do not mix persistence assumptions from one effect with the other.

Present1 is documented on Windows 7 with the Platform Update. Dirty/scroll metadata requires the application's rendering to match the declared regions. Its existence does not establish that every optimization/configuration works on the target. [6] Keep the initial path conservative until full redraw is correct.

## Resize and resource dependencies

ResizeBuffers requires release of direct and indirect back-buffer references: textures, views, bindings, command lists, and any related surfaces. ClearState removes context bindings but does not destroy application-owned references. GDI-compatible surfaces also require outstanding DCs to be released. [7]

**Recommended resize transaction:**

1. Publish desired nonzero pixel dimensions and a generation.
2. Park rendering for zero-size/minimized targets.
3. On the render owner, release all target-dependent backend resources.
4. Unbind and release back-buffer references, then call ResizeBuffers.
5. Recreate render views/Direct2D targets; update the viewport.
6. Force complete redraw; only then acknowledge a completed generation.

The current helper's ClearState/Flush is not, by itself, evidence that all backend-owned views have been released. [4]

## Direct2D and glyph ownership

Direct2D interoperation requires compatible DXGI surfaces and does not automatically synchronize access to those surfaces. [3] The upstream Atlas D3D backend still rasterizes glyphs through Direct2D-related paths. [8]

**Recommendation:** query the required interface instead of reinterpreting an ID2D1RenderTarget output as a newer device-context pointer. Record which creation API, interface and pixel format actually succeed. Treat device loss as invalidating dependent glyph/target resources, while preserving terminal state.

## Presentation failures and desktop transitions

Present can report occlusion, device reset or device removal, and can wait on the message-pump thread. [9]

Proposed behavior:

- Occluded/hidden/minimized: park without a busy present loop; wake on meaningful visibility/content changes.
- Device removed/reset: record the reason, recreate device-dependent resources, redraw the core's current state.
- Repeated recovery failure: report the actual backend/device failure; an explicit fallback may be offered.
- UI teardown: keep the dispatcher responsive until the render owner is quiescent.

Test hardware and forced WARP, Aero and basic composition, lock/unlock, display changes, remote desktop attach/detach and sleep/resume. These are experiment dimensions, not guarantees of identical graphics behavior.

The independent probe's hidden presentation and readback are useful capability evidence. They are not visible Atlas terminal acceptance. [10]

## Sources

- [1] Microsoft, [Platform Update for Windows 7](https://learn.microsoft.com/en-us/windows/win32/direct3darticles/platform-update-for-windows-7).
- [2] Microsoft, [D3D11CreateDevice](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/nf-d3d11-d3d11createdevice).
- [3] Microsoft, [Direct2D/Direct3D interoperability](https://learn.microsoft.com/en-us/windows/win32/direct2d/direct2d-and-direct3d-interoperation-overview).
- [4] [Working Win7Presentation.cpp](../../../src/vt7/VT7.Renderer/Win7Presentation.cpp).
- [5] Microsoft, [DXGI_SWAP_EFFECT](https://learn.microsoft.com/en-us/windows/win32/api/dxgi/ne-dxgi-dxgi_swap_effect).
- [6] Microsoft, [Present1](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_2/nf-dxgi1_2-idxgiswapchain1-present1).
- [7] Microsoft, [ResizeBuffers](https://learn.microsoft.com/en-us/windows/win32/api/dxgi/nf-dxgi-idxgiswapchain-resizebuffers).
- [8] [Atlas BackendD3D](../../../src/renderer/atlas/BackendD3D.cpp) and [BackendD2D](../../../src/renderer/atlas/BackendD2D.cpp).
- [9] Microsoft, [Present](https://learn.microsoft.com/en-us/windows/win32/api/dxgi/nf-dxgi-idxgiswapchain-present).
- [10] [Existing capability-probe evidence](../validation/2026-09-11-renderer-probe.md).
