# Windows 7 API and behavior compatibility reference

Research date: 2026-09-11. This is a review aid for VT7's Windows 7 SP1 x64 target with its declared prerequisites, not an exhaustive import allowlist.

## How to read the matrix

- **Baseline:** available on Windows 7, sometimes originating in an earlier release. This does not certify every parameter combination.
- **Update:** requires the stated Windows 7 update or superseding implementation.
- **Later:** outside the declared target; avoid a mandatory dependency or implement a separate downlevel path.
- **Behavior:** the function exists, but a newer flag, metric, or semantic assumption may not.

Minimum-client statements apply to the named function/interface. Do not infer availability from a header filename, SDK version, IID suffix, or the API-set introduction field. For example, OpenClipboard's requirements name Windows 2000, while its API-set contract is labeled as introduced much later. Those are different facts. [1]

## Graphics and text

| API / facility | Windows 7 classification | Implication for VT7 | Source |
| --- | --- | --- | --- |
| Direct2D 1.1 and Windows 8-era DirectWrite/WIC | Update: KB2670838 | Record actual DLLs and required method results. | [2] |
| ID3D11Device1 / ID3D11DeviceContext1 | Update: Platform Update; partial downlevel functionality | Interface success does not establish support for every method. | [2][3] |
| IDXGIFactory2 HWND swap-chain path | Update with restrictions | Use supported HWND descriptors; no assumption that all DXGI 1.2 paths work. | [2] |
| CreateDXGIFactory2 function | Later: Windows 8.1 | Do not confuse this export with acquiring the IDXGIFactory2 interface. | [4] |
| IDXGISwapChain1::Present1 | Update: Platform Update | Supported entry point; validate descriptor/dirty-region semantics separately. | [5] |
| IDXGISwapChain2 | Later: Windows 8.1 | Do not require its newer frame-latency/presentation controls. | [6] |
| DirectComposition, non-HWND swap chains, desktop duplication | Later / unavailable in Windows 7 Platform Update | Opaque child HWND remains the supported design direction. | [2] |
| DXGI_SCALING_NONE | Unavailable on downlevel Platform Update | Use a documented supported alternative, such as the candidate STRETCH path. | [2] |
| D3D11 DXGI_SWAP_EFFECT_DISCARD / SEQUENTIAL | Baseline | Choose explicit preservation/redraw semantics. | [7] |
| D3D11 FLIP_SEQUENTIAL / FLIP_DISCARD | Later: Windows 8 / Windows 10 respectively | Do not transplant the modern Atlas swap descriptor unchanged. | [7] |
| IDWriteFactory1 | Update: Platform Update | Usable candidate factory boundary; not Factory2 functionality. | [8] |
| IDWriteFactory2 and IDWriteFontFallback | Later: Windows 8.1 | Existing mandatory Atlas fallback startup needs replacement. | [9][10] |
| IDWriteTextLayout::Draw and custom font collections | Baseline | Candidate routes for layout fallback and private fonts; validate cluster/cell mapping. | [11][12] |
| IDWriteFontCollection1 | Later: Windows 10 | Do not rely on the misleading inherited FontCache comment. | [13][14] |
| Native DirectWrite COLR/CPAL color rendering | Later: Windows 8.1 | Monochrome coverage and color rendering are separate capabilities. | [15] |
| DirectWrite variable-font axis support | Later: Windows 10 | Prefer tested static faces for initial acceptance; a font file's default-instance usability is a separate question. | [16] |

The details and recommended alternatives are in [DirectWrite](06-directwrite-and-shaping.md), [font assets](07-font-assets-and-emoji.md), and [graphics](08-graphics-and-presentation.md).

## Processes, input, threading and host APIs

| API / facility | Windows 7 classification | Implication for VT7 | Source |
| --- | --- | --- | --- |
| CreatePseudoConsole / OS ConPTY | Later: Windows 10 version 1809 | Windows 7 needs another local-session backend. | [17] |
| WinPTY | Third-party implementation targeting older Windows | Pin its build and measure legacy-console fidelity; not an OS ConPTY backport. | [18] |
| Nested job objects | Later: Windows 8 | Test inherited jobs and documented breakaway behavior. | [19] |
| WaitOnAddress | Later: Windows 8 | Replace inherited address-wait protocols, not just one typedef. | [20] |
| SRW locks and condition variables | Baseline, introduced in Vista | Candidate synchronization primitives; nonrecursive/predicate-loop rules matter. | [21] |
| SetDefaultDllDirectories / LOAD_LIBRARY_SEARCH flags | Update: KB2533623 or superseding implementation | Resolve the documented downlevel entry point dynamically; keep bootstrap loadable. | [22] |
| ToUnicodeEx | Behavior: bit 2 no-state-change semantics only from Windows 10 version 1607 | Existing function imports are compatible while inherited flag assumptions are not. | [23] |
| Per-monitor DPI awareness | Later: Windows 8.1 | Windows 7 acceptance uses system DPI. | [24] |
| GetDpiForWindow | Later: Windows 10 version 1607 | Do not use it as an unconditional geometry dependency. | [25] |
| IMM composition APIs / TSF | Baseline | Pick an explicit IME/text-store design; rendering a window supplies neither automatically. | [26] |
| ITextProvider2 | Later: Windows 8 | Start from older provider/text interfaces and audit additional helpers. | [27] |
| GetAddrInfoExCancel | Later: Windows 8 | Design resolver cancellation and stale-result ownership without this mandatory import. | [28] |
| BCryptGenRandom with system-preferred RNG | Baseline | Supported candidate for OS cryptographic randomness. | [29] |
| Win32 manifest/registry long-path opt-in | Later: Windows 10 version 1607 | Windows 7 still needs API-specific extended-path handling or explicit limits. | [30] |
| .NET Framework 4.8 | Baseline-compatible host framework | 4.8.1 is not an interchangeable deployment target. | [31] |

## Important behavior traps that are not missing imports

Observed/researched issues deserving targeted tests:

1. **ToUnicodeEx state:** both Terminal.cpp and terminalInput.cpp pass 0b101. The newer non-mutating flag is the compatibility concern, while the base API exists. Test dead keys/AltGr before choosing a replacement. [23][32]
2. **FontCache comment:** a comment says IDWriteFontCollection1 is supported since Windows 7; Microsoft documents Windows 10. The use is within the nearby-font-loading branch, which also involves a newer factory. This is a latent audit hazard, not proof that the current VT7 package executes that branch. [13][14]
3. **Caret metric:** terminalrenderdata.cpp uses SM_CARETBLINKINGENABLED through GetSystemMetrics. Its downlevel semantics were not established by the consulted public metric documentation. Treat this as unresolved; do not invent a minimum OS version or assume a zero result means the user disabled blinking. [33][34]
4. **Graphics interfaces:** Platform Update intentionally omits parts of the newer APIs. Interface version is not a complete capability flag. [2]
5. **Console modes:** current console documentation includes features from modern Windows. A successful compilation against SetConsoleMode does not prove all modern flags work on Windows 7. Use the [local-console experiments](02-console-and-winpty.md). [35]

These are source-level findings and documentation limits, not runtime failures reproduced by this research.

## Proposed audit procedure

1. Enumerate shipped native and managed binaries, including transitively loaded dependencies.
2. Check normal/delay imports and dynamically loaded module/export names.
3. Trace required COM interface acquisition and every newly used method.
4. Review flags, enum/metric values, structure versions, shader requirements and behavioral assumptions on otherwise old APIs.
5. Run real dependency loading and required operations on the declared minimum image.
6. Record optional-feature failures separately from baseline failures, with the fallback exercised.

Prefer explicit capability probes for the operations VT7 needs. Keep an unsupported-feature message distinguishable from E_INVALIDARG caused by a bad descriptor, missing optional debug tooling, or device removal. A successful build and a short import denylist remain necessary but insufficient evidence.

## Sources

- [1] Microsoft, [OpenClipboard requirements and API set](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-openclipboard).
- [2] Microsoft, [Platform Update for Windows 7](https://learn.microsoft.com/en-us/windows/win32/direct3darticles/platform-update-for-windows-7).
- [3] Microsoft, [ID3D11Device1](https://learn.microsoft.com/en-us/windows/win32/api/d3d11_1/nn-d3d11_1-id3d11device1) and [ID3D11DeviceContext1](https://learn.microsoft.com/en-us/windows/win32/api/d3d11_1/nn-d3d11_1-id3d11devicecontext1).
- [4] Microsoft, [CreateDXGIFactory2](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_3/nf-dxgi1_3-createdxgifactory2).
- [5] Microsoft, [Present1](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_2/nf-dxgi1_2-idxgiswapchain1-present1).
- [6] Microsoft, [IDXGISwapChain2](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_3/nn-dxgi1_3-idxgiswapchain2).
- [7] Microsoft, [DXGI_SWAP_EFFECT](https://learn.microsoft.com/en-us/windows/win32/api/dxgi/ne-dxgi-dxgi_swap_effect).
- [8] Microsoft, [IDWriteFactory1](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_1/nn-dwrite_1-idwritefactory1).
- [9] Microsoft, [IDWriteFactory2](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_2/nn-dwrite_2-idwritefactory2).
- [10] Microsoft, [IDWriteFontFallback](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_2/nn-dwrite_2-idwritefontfallback).
- [11] Microsoft, [IDWriteTextLayout::Draw](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextlayout-draw).
- [12] Microsoft, [Custom font collections](https://learn.microsoft.com/en-us/windows/win32/directwrite/custom-font-collections).
- [13] Microsoft, [IDWriteFontCollection1](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_3/nn-dwrite_3-idwritefontcollection1).
- [14] [Inherited FontCache.h](../../../src/renderer/base/FontCache.h).
- [15] Microsoft, [Color font support](https://learn.microsoft.com/en-us/windows/win32/directwrite/color-fonts).
- [16] Microsoft, [Variable fonts](https://learn.microsoft.com/en-us/windows/win32/directwrite/opentype-variable-fonts).
- [17] Microsoft, [CreatePseudoConsole requirements](https://learn.microsoft.com/en-us/windows/console/createpseudoconsole).
- [18] WinPTY, [implementation overview](https://github.com/rprichard/winpty).
- [19] Microsoft, [Job objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).
- [20] Microsoft, [WaitOnAddress](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitonaddress).
- [21] Microsoft, [SRW locks](https://learn.microsoft.com/en-us/windows/win32/sync/slim-reader-writer--srw--locks) and [condition variables](https://learn.microsoft.com/en-us/windows/win32/sync/condition-variables).
- [22] Microsoft, [SetDefaultDllDirectories](https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-setdefaultdlldirectories).
- [23] Microsoft, [ToUnicodeEx flags](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-tounicodeex).
- [24] Microsoft, [High DPI development](https://learn.microsoft.com/en-us/windows/win32/hidpi/high-dpi-desktop-application-development-on-windows).
- [25] Microsoft, [GetDpiForWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getdpiforwindow).
- [26] Microsoft, [WM_IME_COMPOSITION](https://learn.microsoft.com/en-us/windows/win32/intl/wm-ime-composition) and [Text Services Framework](https://learn.microsoft.com/en-us/windows/win32/tsf/text-services-framework).
- [27] Microsoft, [ITextProvider2](https://learn.microsoft.com/en-us/windows/win32/api/uiautomationcore/nn-uiautomationcore-itextprovider2).
- [28] Microsoft, [GetAddrInfoExCancel](https://learn.microsoft.com/en-us/windows/win32/api/ws2tcpip/nf-ws2tcpip-getaddrinfoexcancel).
- [29] Microsoft, [BCryptGenRandom](https://learn.microsoft.com/en-us/windows/win32/api/bcrypt/nf-bcrypt-bcryptgenrandom).
- [30] Microsoft, [Maximum path length limitation](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation).
- [31] Microsoft, [.NET Framework system requirements](https://learn.microsoft.com/en-us/dotnet/framework/get-started/system-requirements).
- [32] [Terminal.cpp](../../../src/cascadia/TerminalCore/Terminal.cpp) and [terminalInput.cpp](../../../src/terminal/input/terminalInput.cpp).
- [33] [Blink interval implementation](../../../src/cascadia/TerminalCore/terminalrenderdata.cpp).
- [34] Microsoft, [GetSystemMetrics](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getsystemmetrics).
- [35] Microsoft, [SetConsoleMode](https://learn.microsoft.com/en-us/windows/console/setconsolemode).
