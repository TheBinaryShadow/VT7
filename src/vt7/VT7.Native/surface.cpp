// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include <LibraryIncludes.h>
#include "include/vt7_native.h"
#include "../../cascadia/TerminalCore/Terminal.hpp"
#include "../../renderer/base/renderer.hpp"
#include "../../renderer/atlas/AtlasEngine.h"
#include <thread>

namespace
{
    constexpr wchar_t windowClass[] = L"VT7.TerminalSurface.3";
    constexpr COLORREF surfaceBackground = RGB(16, 24, 33);

    struct Surface
    {
        Microsoft::Terminal::Core::Terminal terminal;
        std::unique_ptr<Microsoft::Console::Render::AtlasEngine> atlas;
        Microsoft::Console::Render::Renderer renderer;
        HFONT font = nullptr;
        HFONT boldFont = nullptr;
        HWND window = nullptr;
        int cellWidth = 9;
        int cellHeight = 18;
        uint32_t paints = 0;
        uint32_t resizes = 0;
        std::atomic<HRESULT> lastError{S_OK};
        uint32_t mode = 1, requested = 0;
        bool running = false;
        bool capture = false, injectBlank = false;
        uint32_t creationFault = 0;
        uint32_t systemDpi = 96, effectiveDpi = 96, dpiOverride = 0;
        uint32_t fontFamily = 1, fontPoints = 12, fontWeight = FW_NORMAL, settingsGeneration = 1;
        std::mutex rasterMutex;
        std::vector<uint32_t> raster;
        uint32_t rasterWidth = 0, rasterHeight = 0, headerPixels = 0, framePixels = 0;
        uint64_t rasterHash = 0;
        bool ownedByWindow = false;
        bool initialized = false;
        bool closing = false;
        std::optional<Microsoft::Console::Render::TimerHandle> diagnosticTimer;
        uint32_t diagnosticTimerFires = 0;

        explicit Surface(uint32_t rendererMode) : renderer([this]() -> auto& {
            const auto guard = terminal.LockForWriting();
            return terminal.GetRenderSettings();
        }(), &terminal), mode(rendererMode & 0xff), capture((rendererMode & 0x100) != 0), injectBlank((rendererMode & 0x200) != 0),
            creationFault((rendererMode >> 10) & 3) {}

        void Capture(const Microsoft::Console::Render::Atlas::RenderingPayload& p)
        {
            wil::com_ptr<ID3D11Texture2D> buffer;
            THROW_IF_FAILED(p.swapChain.swapChain->GetBuffer(0, IID_PPV_ARGS(buffer.put())));
            if (injectBlank)
            {
                wil::com_ptr<ID3D11RenderTargetView> target;
                THROW_IF_FAILED(p.device->CreateRenderTargetView(buffer.get(), nullptr, target.put()));
                const float black[4]{0, 0, 0, 1};
                p.deviceContext->ClearRenderTargetView(target.get(), black);
            }
            D3D11_TEXTURE2D_DESC desc{}; buffer->GetDesc(&desc);
            desc.Usage = D3D11_USAGE_STAGING;
            desc.BindFlags = desc.MiscFlags = 0;
            desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
            wil::com_ptr<ID3D11Texture2D> staging;
            THROW_IF_FAILED(p.device->CreateTexture2D(&desc, nullptr, staging.put()));
            p.deviceContext->CopyResource(staging.get(), buffer.get());
            D3D11_MAPPED_SUBRESOURCE mapped{};
            THROW_IF_FAILED(p.deviceContext->Map(staging.get(), 0, D3D11_MAP_READ, 0, &mapped));
            const auto unmap = wil::scope_exit([&] { p.deviceContext->Unmap(staging.get(), 0); });
            std::vector<uint32_t> pixels(static_cast<size_t>(desc.Width) * desc.Height);
            for (UINT y = 0; y < desc.Height; ++y)
                memcpy(pixels.data() + y * desc.Width, static_cast<const BYTE*>(mapped.pData) + y * mapped.RowPitch, desc.Width * 4);
            uint64_t hash = 14695981039346656037ull;
            uint32_t nonBackground = 0, nonUniform = 0;
            for (size_t i = 0; i < pixels.size(); ++i)
            {
                const auto rgb = pixels[i] & 0xffffff;
                hash = (hash ^ rgb) * 1099511628211ull;
                if (rgb != (pixels.front() & 0xffffff)) ++nonUniform;
                if (i < static_cast<size_t>(desc.Width) * cellHeight && rgb != (pixels.front() & 0xffffff)) ++nonBackground;
            }
            const std::lock_guard guard(rasterMutex);
            raster = std::move(pixels); rasterWidth = desc.Width; rasterHeight = desc.Height;
            rasterHash = hash; headerPixels = nonBackground;
            framePixels = nonUniform;
        }

        void SaveCapture(const wchar_t* path)
        {
            const std::lock_guard guard(rasterMutex);
            THROW_HR_IF(E_PENDING, raster.empty());
            const auto factory = wil::CoCreateInstance<IWICImagingFactory>(CLSID_WICImagingFactory);
            wil::com_ptr<IWICStream> stream;
            wil::com_ptr<IWICBitmapEncoder> encoder;
            wil::com_ptr<IWICBitmapFrameEncode> frame;
            THROW_IF_FAILED(factory->CreateStream(stream.put()));
            THROW_IF_FAILED(stream->InitializeFromFilename(path, GENERIC_WRITE));
            THROW_IF_FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, encoder.put()));
            THROW_IF_FAILED(encoder->Initialize(stream.get(), WICBitmapEncoderNoCache));
            THROW_IF_FAILED(encoder->CreateNewFrame(frame.put(), nullptr));
            THROW_IF_FAILED(frame->Initialize(nullptr));
            THROW_IF_FAILED(frame->SetSize(rasterWidth, rasterHeight));
            auto format = GUID_WICPixelFormat32bppBGRA;
            THROW_IF_FAILED(frame->SetPixelFormat(&format));
            THROW_HR_IF(E_UNEXPECTED, format != GUID_WICPixelFormat32bppBGRA);
            THROW_IF_FAILED(frame->WritePixels(rasterHeight, rasterWidth * 4,
                gsl::narrow<UINT>(raster.size() * 4), reinterpret_cast<BYTE*>(raster.data())));
            THROW_IF_FAILED(frame->Commit());
            THROW_IF_FAILED(encoder->Commit());
        }

        void Stop() noexcept
        {
            // Never wait while holding the core lock needed by the worker.
            // Hidden HWNDs retain their presentation worker, parked without CPU.
            renderer.SuspendPainting();
            running = false;
        }

        void CloseRenderer() noexcept
        {
            if (closing) return;
            closing = true;
            renderer.TriggerTeardown();
            if (atlas)
            {
                renderer.RemoveRenderEngine(atlas.get());
                atlas.reset();
            }
        }

        void Start()
        {
            if (atlas && initialized && !running && SUCCEEDED(lastError.load()) && IsWindowVisible(window))
            {
                const auto guard = terminal.LockForWriting();
                renderer.EnablePainting();
                running = true;
            }
        }

        void RequestPaint()
        {
            const auto guard = terminal.LockForWriting();
            requested = atlas ? atlas->RequestFrame() : requested + 1;
            renderer.TriggerRedrawAll();
        }

        ~Surface()
        {
            CloseRenderer();
            if (font) DeleteObject(font);
            if (boldFont) DeleteObject(boldFont);
        }

        void CreateFontForWindow()
        {
            const auto dc = GetDC(window);
            THROW_LAST_ERROR_IF(!dc);
            const auto release = wil::scope_exit([&] { ReleaseDC(window, dc); });
            systemDpi = effectiveDpi = GetDeviceCaps(dc, LOGPIXELSY);
            if (mode)
            {
                atlas = std::make_unique<Microsoft::Console::Render::AtlasEngine>();
                atlas->SetGraphicsAPI(mode <= 2 || mode == 5 ? Microsoft::Console::Render::Atlas::GraphicsAPI::Direct3D11 : Microsoft::Console::Render::Atlas::GraphicsAPI::Direct2D);
                atlas->SetSoftwareRendering(mode == 2 || mode == 4);
                THROW_IF_FAILED(atlas->SetHwnd(window));
                atlas->ConfigureWin7Recovery(mode == 5, creationFault,
                    [this] { PostMessageW(window, WM_APP + 1, 0, 0); });
                renderer.SetRendererEnteredErrorStateCallback([this] {
                    const auto hr = atlas->LastRenderFailure();
                    lastError.store(FAILED(hr) ? hr : E_FAIL);
                    PostMessageW(window, WM_APP + 1, 0, 0);
                });
                renderer.AddRenderEngine(atlas.get());
                renderer.SetThreadExitCallback([this] { atlas->ReleaseWin7DeviceResources(); });
                const auto guard = terminal.LockForWriting();
                renderer.AllowCursorVisibility(Microsoft::Console::Render::InhibitionSource::Host, true);
                renderer.AllowCursorBlinking(Microsoft::Console::Render::InhibitionSource::User, !capture);
                if (capture) atlas->SetFrameCapture([this](const auto& payload) { Capture(payload); });
                FontInfoDesired desired(L"Consolas", 0, FW_NORMAL, 12, CP_UTF8);
                desired.SetEnableColorGlyphs(false);
                auto info = terminal.GetFontInfo();
                THROW_IF_FAILED(atlas->UpdateDpi(effectiveDpi));
                THROW_IF_FAILED(atlas->UpdateFont(desired, info));
                terminal.SetFontInfo(info);
                til::size cells;
                THROW_IF_FAILED(atlas->GetFontSize(&cells));
                cellWidth = cells.width;
                cellHeight = cells.height;
                return;
            }
            const auto height = -MulDiv(12, GetDeviceCaps(dc, LOGPIXELSY), 72);
            font = CreateFontW(height, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                CLEARTYPE_QUALITY, FIXED_PITCH | FF_MODERN, L"Consolas");
            THROW_LAST_ERROR_IF(!font);
            boldFont = CreateFontW(height, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                CLEARTYPE_QUALITY, FIXED_PITCH | FF_MODERN, L"Consolas");
            THROW_LAST_ERROR_IF(!boldFont);
            const auto old = SelectObject(dc, font);
            const auto restore = wil::scope_exit([&] { SelectObject(dc, old); });
            TEXTMETRICW metrics{};
            THROW_IF_WIN32_BOOL_FALSE(GetTextMetricsW(dc, &metrics));
            cellWidth = std::max(1L, metrics.tmAveCharWidth);
            cellHeight = std::max(1L, metrics.tmHeight + metrics.tmExternalLeading);
        }

        void FillDemo()
        {
            // VT text goes through the actual upstream parser, dispatch, and buffer.
            terminal.Write(L"\x1b[0m\x1b[2J\x1b[H"
                L"\x1b[1;38;2;101;184;255mVT7 - the first terminal viewport\x1b[0m\r\n"
                L"Windows 7 deserves a terminal built with care.\r\n\r\n"
                L"This text lives in Microsoft TerminalCore's text buffer.\r\n"
                L"Resize the window: the core reflows the content.\r\n\r\n"
                L"Standard and bright colors:\r\n");
            for (int index = 0; index < 16; ++index)
            {
                terminal.Write(fmt::format(L"\x1b[{}m {:02} ", index < 8 ? 40 + index : 100 + index - 8, index));
            }
            terminal.Write(L"\x1b[0m\r\n\r\n256-color ramp:\r\n");
            for (int index = 16; index < 52; ++index)
            {
                terminal.Write(fmt::format(L"\x1b[48;5;{}m ", index));
            }
            terminal.Write(L"\x1b[0m\r\n\r\n"
                L"\x1b[38;2;255;170;80mTrue color\x1b[0m   "
                L"\x1b[1mBold\x1b[0m   \x1b[4mUnderline\x1b[0m   \x1b[7mReverse\x1b[0m\r\n"
                L"Unicode: caf\u00e9  \u03b1\u03b2\u03b3  e\u0301  \u4e2d\u6587\r\n"
                L"Fallback: \u262f \U0001f600 | Arabic (logical cells): \u0633\u0644\u0627\u0645\r\n"
                L"\u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\r\n"
                L"\u2502 Windows 7, VT7 \u2502\r\n"
                L"\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\r\n\r\n"
                L"Static proof - interactive sessions are coming later.");
        }

        #include "surface_repaint.inl"
        #include "surface_settings.inl"

        void Resize()
        {
            RECT client{};
            THROW_IF_WIN32_BOOL_FALSE(GetClientRect(window, &client));
            if (client.right <= 0 || client.bottom <= 0) return;
            const til::size size{ std::clamp<int>(client.right / cellWidth, 1, 512),
                                  std::clamp<int>(client.bottom / cellHeight, 1, 256) };
            const auto guard = terminal.LockForWriting();
            if (!initialized)
            {
                terminal.Create(size, 500, renderer);
                initialized = true;
                auto& settings = terminal.GetRenderSettings();
                settings.SetColorAlias(ColorAlias::DefaultForeground,
                    TextColor::DEFAULT_FOREGROUND, RGB(235, 242, 248));
                settings.SetColorAlias(ColorAlias::DefaultBackground,
                    TextColor::DEFAULT_BACKGROUND, surfaceBackground);
                settings.SaveDefaultSettings();
                FillDemo();
            }
            else
            {
                const auto result = terminal.UserResize(size);
                THROW_IF_FAILED(result);
                if (result == S_OK) ++resizes;
            }
            InvalidateRect(window, nullptr, FALSE);
        }

        void Paint(HDC destination)
        {
            RECT client{};
            THROW_IF_WIN32_BOOL_FALSE(GetClientRect(window, &client));
            if (client.right <= 0 || client.bottom <= 0 || !initialized) return;
            const auto dc = CreateCompatibleDC(destination);
            THROW_LAST_ERROR_IF(!dc);
            const auto deleteDc = wil::scope_exit([&] { DeleteDC(dc); });
            const auto bitmap = CreateCompatibleBitmap(destination, client.right, client.bottom);
            THROW_LAST_ERROR_IF(!bitmap);
            const auto deleteBitmap = wil::scope_exit([&] { DeleteObject(bitmap); });
            const auto oldBitmap = SelectObject(dc, bitmap);
            const auto restoreBitmap = wil::scope_exit([&] { SelectObject(dc, oldBitmap); });
            SetDCBrushColor(dc, surfaceBackground);
            FillRect(dc, &client, static_cast<HBRUSH>(GetStockObject(DC_BRUSH)));
            const auto oldFont = SelectObject(dc, font);
            const auto restoreFont = wil::scope_exit([&] { SelectObject(dc, oldFont); });
            SetTextAlign(dc, TA_LEFT | TA_TOP | TA_NOUPDATECP);

            const auto guard = terminal.LockForReading();
            const auto viewport = terminal.GetViewport();
            auto& buffer = terminal.GetTextBuffer();
            for (int y = 0; y < viewport.Height(); ++y)
            {
                const auto& row = buffer.GetRowByOffset(viewport.Top() + y);
                for (int x = 0; x < viewport.Width(); ++x)
                {
                    if (row.DbcsAttrAt(x) == DbcsAttribute::Trailing) continue;
                    const auto glyph = row.GlyphAt(x);
                    const auto attribute = row.GetAttrByColumn(x);
                    const auto colors = terminal.GetAttributeColors(attribute);
                    const auto width = row.DbcsAttrAt(x) == DbcsAttribute::Leading ? 2 : 1;
                    RECT cell{ x * cellWidth, y * cellHeight,
                        (x + width) * cellWidth, (y + 1) * cellHeight };
                    SetTextColor(dc, colors.first);
                    SetBkColor(dc, colors.second);
                    SelectObject(dc, attribute.IsIntense() ? boldFont : font);
                    THROW_IF_WIN32_BOOL_FALSE(ExtTextOutW(dc, cell.left, cell.top,
                        ETO_OPAQUE | ETO_CLIPPED, &cell, glyph.data(), static_cast<UINT>(glyph.size()), nullptr));
                    if (attribute.IsUnderlined())
                    {
                        RECT underline{ cell.left, cell.bottom - 2, cell.right, cell.bottom - 1 };
                        SetDCBrushColor(dc, colors.first);
                        FillRect(dc, &underline, static_cast<HBRUSH>(GetStockObject(DC_BRUSH)));
                    }
                }
            }
            THROW_IF_WIN32_BOOL_FALSE(BitBlt(destination, 0, 0, client.right, client.bottom, dc, 0, 0, SRCCOPY));
            ++paints;
        }
    };

    LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) noexcept
    {
        auto surface = reinterpret_cast<Surface*>(GetWindowLongPtrW(window, GWLP_USERDATA));
        if (message == WM_NCCREATE)
        {
            surface = static_cast<Surface*>(reinterpret_cast<CREATESTRUCTW*>(lparam)->lpCreateParams);
            surface->window = window;
            SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(surface));
        }
        if (surface)
        {
            try
            {
                switch (message)
                {
                case WM_CREATE:
                    surface->CreateFontForWindow();
                    surface->Resize();
                    return 0;
                case WM_SHOWWINDOW:
                    if (wparam) surface->Start();
                    else surface->Stop();
                    break;
                case WM_DESTROY:
                    surface->Stop();
                    break;
                case WM_SIZE:
                    if (surface->closing) return 0;
                    surface->Resize();
                    return 0;
                case WM_ERASEBKGND:
                    return 1;
                case WM_PAINT:
                {
                    PAINTSTRUCT paint{};
                    const auto dc = BeginPaint(window, &paint);
                    const auto finish = wil::scope_exit([&] { EndPaint(window, &paint); });
                    if (surface->closing) return 0;
                    if (surface->atlas)
                    {
                        surface->RequestPaint();
                        surface->Start();
                    }
                    else
                    {
                        surface->RequestPaint();
                        surface->Paint(dc);
                    }
                    return 0;
                }
                case WM_NCDESTROY:
                {
                    SetWindowLongPtrW(window, GWLP_USERDATA, 0);
                    const auto result = DefWindowProcW(window, message, wparam, lparam);
                    if (surface->ownedByWindow) delete surface;
                    return result;
                }
                }
            }
            catch (...)
            {
                surface->lastError = wil::ResultFromCaughtException();
                if (message == WM_CREATE) return -1;
                return 0;
            }
        }
        return DefWindowProcW(window, message, wparam, lparam);
    }

    Surface* Lookup(void* handle)
    {
        const auto window = static_cast<HWND>(handle);
        THROW_HR_IF(E_HANDLE, !IsWindow(window));
        THROW_HR_IF(RPC_E_WRONG_THREAD, GetWindowThreadProcessId(window, nullptr) != GetCurrentThreadId());
        wchar_t name[64]{};
        GetClassNameW(window, name, _countof(name));
        THROW_HR_IF(E_HANDLE, wcscmp(name, windowClass) != 0);
        const auto surface = reinterpret_cast<Surface*>(GetWindowLongPtrW(window, GWLP_USERDATA));
        THROW_HR_IF(E_HANDLE, !surface);
        return surface;
    }
}

int32_t __cdecl VT7_CreateSurface(void* parent, uint32_t rendererMode, void** result)
try
{
    if (!result) return E_POINTER;
    *result = nullptr;
    THROW_HR_IF(E_INVALIDARG, (rendererMode & 0xff) > 5 || (rendererMode & ~0xfffu) ||
        ((rendererMode & 0xe00) && (!(rendererMode & 0x100) || !(rendererMode & 0xff))) ||
        ((rendererMode >> 10) & 3) == 3);
    const auto parentWindow = static_cast<HWND>(parent);
    THROW_HR_IF(E_HANDLE, !IsWindow(parentWindow));
    THROW_HR_IF(RPC_E_WRONG_THREAD, GetWindowThreadProcessId(parentWindow, nullptr) != GetCurrentThreadId());
    HMODULE module = nullptr;
    THROW_IF_WIN32_BOOL_FALSE(GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
        GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, reinterpret_cast<LPCWSTR>(&WindowProc), &module));
    WNDCLASSEXW klass{ sizeof(klass) };
    klass.lpfnWndProc = WindowProc;
    klass.hInstance = module;
    klass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    klass.lpszClassName = windowClass;
    if (!RegisterClassExW(&klass)) THROW_LAST_ERROR_IF(GetLastError() != ERROR_CLASS_ALREADY_EXISTS);
    auto surface = std::make_unique<Surface>(rendererMode);
    const auto window = CreateWindowExW(0, windowClass, L"VT7 terminal viewport",
        WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS, 0, 0, 900, 500, parentWindow, nullptr, module, surface.get());
    if (!window)
    {
        THROW_IF_FAILED(surface->lastError.load());
        THROW_LAST_ERROR();
    }
    surface->ownedByWindow = true;
    surface.release();
    *result = window;
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_DestroySurface(void* window)
try
{
    const auto surface = Lookup(window);
    surface->Stop();
    // The presentation worker must outlive complete native HWND cleanup.
    surface->ownedByWindow = false;
    if (!DestroyWindow(static_cast<HWND>(window)))
    {
        surface->ownedByWindow = true;
        THROW_LAST_ERROR();
    }
    delete surface;
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_GetSurfaceInfo(void* window, VT7_SURFACE_INFO* info)
try
{
    if (!info) return E_POINTER;
    if (info->struct_size != sizeof(*info)) return E_INVALIDARG;
    const auto surface = Lookup(window);
    const auto guard = surface->terminal.LockForReading();
    const auto viewport = surface->terminal.GetViewport();
    const std::lock_guard rasterGuard(surface->rasterMutex);
    *info = { sizeof(*info), static_cast<uint32_t>(viewport.Width()), static_cast<uint32_t>(viewport.Height()),
        static_cast<uint32_t>(surface->cellWidth), static_cast<uint32_t>(surface->cellHeight),
        surface->atlas ? surface->atlas->CompletedFrames() : surface->paints, surface->resizes, surface->lastError.load(),
        surface->atlas ? surface->atlas->ActualMode() : 0, surface->requested, surface->atlas ? surface->atlas->CompletedRequest() : surface->requested,
        surface->headerPixels, surface->rasterHash,
        surface->mode, surface->atlas ? surface->atlas->DeviceGeneration() : 0,
        surface->atlas ? surface->atlas->DeviceAttempts() : 0,
        surface->atlas ? surface->atlas->RecoveryFailures() : 0,
        surface->atlas ? surface->atlas->Fallbacks() : 0,
        surface->atlas ? surface->atlas->InjectedFailures() : 0,
        surface->atlas ? surface->atlas->LastRenderFailure() : S_OK,
        surface->framePixels, surface->rasterWidth, surface->rasterHeight };
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_SaveSurfaceCapture(void* window, const wchar_t* path)
try
{
    if (!path || !*path) return E_INVALIDARG;
    Lookup(window)->SaveCapture(path);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_GetSurfaceSettings(void* window, VT7_SURFACE_SETTINGS* settings)
try
{
    if (!settings) return E_POINTER;
    if (settings->struct_size != sizeof(*settings)) return E_INVALIDARG;
    const auto surface = Lookup(window);
    RECT client{};
    THROW_IF_WIN32_BOOL_FALSE(GetClientRect(static_cast<HWND>(window), &client));
    *settings = { sizeof(*settings), surface->systemDpi, surface->effectiveDpi, surface->dpiOverride,
        surface->fontFamily, surface->fontPoints, surface->fontWeight, surface->settingsGeneration,
        static_cast<uint32_t>(client.right), static_cast<uint32_t>(client.bottom) };
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_SetSurfaceFont(void* window, uint32_t family, uint32_t points, uint32_t weight, uint32_t diagnosticDpi)
try
{
    Lookup(window)->SetFont(family, points, weight, diagnosticDpi);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_InjectSurfaceFailure(void* window, uint32_t fault)
try
{
    const auto surface = Lookup(window);
    THROW_HR_IF(E_INVALIDARG, !surface->atlas || !surface->capture || fault < 1 || fault > 3);
    // Park the worker before arming the fault so the next requested frame owns it.
    surface->Stop();
    surface->atlas->InjectPresentFailures(fault == 3 ? UINT32_MAX : fault);
    surface->RequestPaint();
    surface->Start();
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_ResetSurface(void* window)
try
{
    const auto surface = Lookup(window);
    const auto guard = surface->terminal.LockForWriting();
    surface->terminal.HardResetWithoutErase();
    surface->FillDemo();
    InvalidateRect(static_cast<HWND>(window), nullptr, FALSE);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_SurfaceRepaintCheck(void* window, uint32_t operation, uint32_t step, wchar_t* report, uint32_t capacity)
{
    if (!report || capacity < 2) return E_INVALIDARG;
    report[0] = L'\0';
    try
    {
        const auto result = Lookup(window)->RepaintCheck(operation, step);
        if (result.size() >= capacity) return HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER);
        wcscpy_s(report, capacity, result.c_str());
        return S_OK;
    }
    catch (const std::exception& ex)
    {
        const std::string_view text(ex.what());
        const std::wstring message(text.begin(), text.end());
        wcsncpy_s(report, capacity, message.c_str(), _TRUNCATE);
        return E_FAIL;
    }
    catch (...) { return wil::ResultFromCaughtException(); }
}

int32_t __cdecl VT7_GetSchedulingInfo(void* window, VT7_SCHEDULING_INFO* info)
try
{
    if (!info || info->struct_size != sizeof(*info)) return E_INVALIDARG;
    const auto surface = Lookup(window);
    const auto guard = surface->terminal.LockForWriting();
    const auto stats = surface->renderer.GetSchedulingSnapshot();
    const auto mode = surface->terminal.GetRenderSettings().GetRenderMode(
        Microsoft::Console::Render::RenderSettings::Mode::SynchronizedOutput);
    *info = { sizeof(*info), stats.waits, stats.frames, stats.syncWaits, stats.syncTimeouts,
        stats.waiting, stats.synchronizing, static_cast<uint32_t>(mode), surface->diagnosticTimerFires, stats.threadStarts };
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_SchedulingCommand(void* window, uint32_t operation, uint32_t step)
try
{
    const auto surface = Lookup(window);
    THROW_HR_IF(E_INVALIDARG, !surface->atlas || !surface->capture || operation > 7 || step > 999999);
    const auto guard = surface->terminal.LockForWriting();
    auto& terminal = surface->terminal;
    if (operation >= 6)
    {
        THROW_HR_IF(E_INVALIDARG, operation == 6 && (step < 1 || step > 1000));
        if (!surface->diagnosticTimer)
            surface->diagnosticTimer = surface->renderer.RegisterTimer("VT7 diagnostic one-shot", [surface](auto&, auto) {
                ++surface->diagnosticTimerFires;
            });
        if (operation == 6) surface->renderer.StartTimer(*surface->diagnosticTimer, std::chrono::milliseconds(step));
        else surface->renderer.StopTimer(*surface->diagnosticTimer);
        return S_OK;
    }
    if (operation == 0)
    {
        terminal.Write(L"\x1b[?1049l\x1b[?2026l\x1b[0m\x1b[2J\x1b[H\x1b[?25l");
    }
    if (operation == 1) terminal.Write(L"\x1b[?2026h");
    if (operation == 5)
    {
        terminal.Write(L"\x1b[?20");
        terminal.Write(L"26h");
    }
    if (operation == 2) terminal.Write(L"\x1b[?2026l");
    else
    {
        const auto marker = fmt::format(L"VT7 scheduling {:06}", step);
        if (operation == 4)
        {
            const auto& row = terminal.GetTextBuffer().GetRowByOffset(terminal.GetViewport().Top());
            for (size_t x = 0; x < marker.size(); ++x)
                THROW_HR_IF(E_UNEXPECTED, row.GlyphAt(gsl::narrow<til::CoordType>(x)) != std::wstring_view(marker).substr(x, 1));
            return S_OK;
        }
        terminal.Write(L"\x1b[H");
        terminal.Write(marker);
    }
    surface->requested = surface->atlas->RequestFrame();
    surface->renderer.NotifyPaintFrame();
    if (operation == 3)
    {
        // Only NotifyPaintFrame is called off-thread. Both producers are joined
        // before this UI-owned command returns, so no callback can outlive HWND.
        const auto wake = [&] { for (int i = 0; i < 64; ++i) surface->renderer.NotifyPaintFrame(); };
        std::thread first(wake);
        const auto join = wil::scope_exit([&] { first.join(); });
        std::thread second(wake);
        second.join();
    }
    return S_OK;
}
CATCH_RETURN()
