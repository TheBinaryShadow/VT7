// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include "../../renderer/atlas/pch.h"
#include "../../renderer/atlas/BackendD2D.h"
#include "../../renderer/atlas/BackendD3D.h"
#include "../VT7.Renderer/Win7Presentation.hpp"
#include <fstream>
#include <iomanip>

using namespace Microsoft::Console::Render::Atlas;

namespace
{
    constexpr u32 proofBackground = 0xff20160e; // Atlas uses ABGR, not COLORREF.
    constexpr wchar_t windowClass[] = L"VT7.AtlasBackendProof";

    struct Proof
    {
        std::ofstream log;
        RenderingPayload p;
        std::unique_ptr<IBackend> backend;
        wil::com_ptr<AtlasFontFace> face;
        HWND window = nullptr;
        bool d2d = false;
        bool ready = false;
        bool failed = false;
        unsigned frames = 0;
        std::wstring capturePath;
        bool injectRenderFailure = false;

        ~Proof()
        {
            ready = false;
            backend.reset();
            Win7::DestroySwapChain(p);
            if (window) DestroyWindow(window);
        }

        void Check(bool passed, const char* label)
        {
            log << (passed ? "PASS: " : "FAIL: ") << label << std::endl;
            if (!passed) { failed = true; THROW_HR(E_FAIL); }
        }

        void Initialize()
        {
            p.s = DirtyGenerationalSettings();
            auto settings = p.s.write();
            settings->target.write()->hwnd = window;
            settings->targetSize = { 800, 352 };
            auto font = settings->font.write();
            font->cellSize = { 10, 22 };
            font->fontSize = 16;
            font->baseline = 17;
            font->descender = 5;
            font->advanceWidth = 10;
            font->fontWeight = 400;
            font->thinLineWidth = 1;
            font->underline = { 19, 1 };
            font->doubleUnderline[0] = { 18, 1 };
            font->doubleUnderline[1] = { 20, 1 };
            font->strikethrough = { 10, 1 };
            font->colorGlyphs = false;
            settings->misc.write()->backgroundColor = proofBackground;
            settings->misc.write()->foregroundColor = 0xffffffff;

            THROW_IF_FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, p.d2dFactory.put()));
            THROW_IF_FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory1),
                reinterpret_cast<IUnknown**>(p.dwriteFactory1.put())));
            wil::com_ptr<IDWriteFontCollection> collection;
            THROW_IF_FAILED(p.dwriteFactory1->GetSystemFontCollection(collection.put(), FALSE));
            UINT index = 0;
            BOOL exists = FALSE;
            THROW_IF_FAILED(collection->FindFamilyName(L"Consolas", &index, &exists));
            Check(exists != FALSE, "Consolas is installed (no implicit family substitution)");
            wil::com_ptr<IDWriteFontFamily> family;
            wil::com_ptr<IDWriteFont> fontObject;
            wil::com_ptr<IDWriteFontFace> baseFace;
            THROW_IF_FAILED(collection->GetFontFamily(index, family.put()));
            THROW_IF_FAILED(family->GetFirstMatchingFont(DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STRETCH_NORMAL,
                DWRITE_FONT_STYLE_NORMAL, fontObject.put()));
            THROW_IF_FAILED(fontObject->CreateFontFace(baseFace.put()));
            face = baseFace.query<AtlasFontFace>();
        }

        void CreateBackend()
        {
            backend.reset();
            Win7::DestroySwapChain(p);
            Win7::CreateDevice(p);
            DXGI_ADAPTER_DESC1 desc{};
            THROW_IF_FAILED(p.dxgi.adapter->GetDesc1(&desc));
            log << "Device: " << (p.s->target->useWARP ? "explicit WARP" : "explicit hardware")
                << "; vendor/device=" << desc.VendorId << '/' << desc.DeviceId
                << "; featureLevel=0x" << std::hex << p.device->GetFeatureLevel() << std::dec << std::endl;
            if (d2d) backend = std::make_unique<BackendD2D>();
            else backend = std::make_unique<BackendD3D>(p);
            Win7::CreateSwapChain(p);
            DXGI_SWAP_CHAIN_DESC1 desc1{};
            THROW_IF_FAILED(p.swapChain.swapChain->GetDesc1(&desc1));
            Check(desc1.BufferCount == 1 && desc1.SwapEffect == DXGI_SWAP_EFFECT_DISCARD &&
                desc1.Scaling == DXGI_SCALING_STRETCH && desc1.Flags == 0,
                "Windows 7 discard/stretch descriptor, one buffer, no flags");
        }

        void Sample(u16 width, u16 height, bool alternate = false)
        {
            auto settings = p.s.write();
            settings->targetSize = { width, height };
            const u16 columns = std::max<u16>(1, width / 10);
            const u16 rows = std::max<u16>(1, height / 22);
            settings->viewportCellCount = { columns, rows };
            p.unorderedRows = Buffer<ShapedRow>(rows);
            p.rows = Buffer<ShapedRow*>(rows);
            p.colorBitmapRowStride = (static_cast<size_t>(columns) + 7) & ~size_t{7};
            p.colorBitmapDepthStride = p.colorBitmapRowStride * rows;
            p.colorBitmap = Buffer<u32, 32>(p.colorBitmapDepthStride * 3);
            p.backgroundBitmap = { p.colorBitmap.data(), p.colorBitmapDepthStride };
            p.foregroundBitmap = { p.colorBitmap.data() + p.colorBitmapDepthStride, p.colorBitmapDepthStride };
            p.underlineBitmap = { p.colorBitmap.data() + p.colorBitmapDepthStride * 2, p.colorBitmapDepthStride };
            std::fill(p.backgroundBitmap.begin(), p.backgroundBitmap.end(), proofBackground);
            std::fill(p.foregroundBitmap.begin(), p.foregroundBitmap.end(), 0xffffffff);
            std::fill(p.underlineBitmap.begin(), p.underlineBitmap.end(), 0xffffffff);
            for (auto& generation : p.colorBitmapGenerations) generation.bump();
            constexpr std::wstring_view lines[]{
                L"VT7 - Atlas backend proof 0.1",
                L"The terminal application Windows 7 always deserved.",
                L"",
                L"Real Atlas backend. Fixed Consolas glyphs, no font fallback yet.",
                L"Resize, cover/uncover, minimize and restore this window.",
                L"Press R to recreate the device and target. Escape closes.",
                L"",
                L"0123456789  ABCDEFGHIJKLMNOPQRSTUVWXYZ  abcdefghijklmnopqrstuvwxyz",
                L"!@#$%^&*()  [] {} <> / \\ | + - = _ : ; . , ?",
            };
            for (u16 y = 0; y < rows; ++y)
            {
                auto& row = p.unorderedRows[y];
                p.rows[y] = &row;
                row.Clear(y, 22);
                const auto line = y < ARRAYSIZE(lines) ? lines[y].substr(0, columns) : std::wstring_view{};
                for (const auto c : line)
                {
                    const UINT32 codepoint = c;
                    UINT16 glyph = 0;
                    THROW_IF_FAILED(face->GetGlyphIndicesW(&codepoint, 1, &glyph));
                    THROW_HR_IF(DWRITE_E_NOFONT, !glyph);
                    row.glyphIndices.push_back(glyph);
                    row.glyphAdvances.push_back(10);
                    row.glyphOffsets.emplace_back();
                    row.colors.push_back(y == 0 ? (alternate ? 0xff60ff60 : 0xffffff60) : 0xffffffff);
                }
                if (!line.empty()) row.mappings.emplace_back(face, 0, line.size());
            }
            p.MarkAllAsDirty();
        }

        // Read pixels BEFORE Present: DISCARD makes post-Present contents undefined.
        std::vector<u32> Readback()
        {
            wil::com_ptr<ID3D11Texture2D> buffer;
            THROW_IF_FAILED(p.swapChain.swapChain->GetBuffer(0, IID_PPV_ARGS(buffer.put())));
            D3D11_TEXTURE2D_DESC desc{};
            buffer->GetDesc(&desc);
            desc.Usage = D3D11_USAGE_STAGING;
            desc.BindFlags = desc.MiscFlags = 0;
            desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
            wil::com_ptr<ID3D11Texture2D> staging;
            THROW_IF_FAILED(p.device->CreateTexture2D(&desc, nullptr, staging.put()));
            p.deviceContext->CopyResource(staging.get(), buffer.get());
            D3D11_MAPPED_SUBRESOURCE mapped{};
            THROW_IF_FAILED(p.deviceContext->Map(staging.get(), 0, D3D11_MAP_READ, 0, &mapped));
            const auto unmap = wil::scope_exit([&] { p.deviceContext->Unmap(staging.get(), 0); });
            std::vector<u32> pixels(static_cast<size_t>(desc.Width) * desc.Height);
            for (UINT y = 0; y < desc.Height; ++y)
                memcpy(pixels.data() + y * desc.Width, static_cast<const BYTE*>(mapped.pData) + y * mapped.RowPitch, desc.Width * sizeof(u32));
            return pixels;
        }

        std::vector<u32> Frame(bool readback)
        {
            p.MarkAllAsDirty();
            backend->Render(p);
            if (injectRenderFailure)
            {
                log << "Injected render failure (reporting test, not device-loss recovery)" << std::endl;
                THROW_HR(E_FAIL);
            }
            auto pixels = readback ? Readback() : std::vector<u32>{};
            if (!capturePath.empty() && frames == 0 && readback)
            {
                // Diagnostic back-buffer image, not a desktop screenshot. Use
                // the original WIC factory, with no process-lifetime COM cache.
                const auto factory = wil::CoCreateInstance<IWICImagingFactory>(CLSID_WICImagingFactory);
                wil::com_ptr<IWICStream> stream;
                wil::com_ptr<IWICBitmapEncoder> encoder;
                wil::com_ptr<IWICBitmapFrameEncode> frame;
                THROW_IF_FAILED(factory->CreateStream(stream.put()));
                THROW_IF_FAILED(stream->InitializeFromFilename(capturePath.c_str(), GENERIC_WRITE));
                THROW_IF_FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, encoder.put()));
                THROW_IF_FAILED(encoder->Initialize(stream.get(), WICBitmapEncoderNoCache));
                THROW_IF_FAILED(encoder->CreateNewFrame(frame.put(), nullptr));
                THROW_IF_FAILED(frame->Initialize(nullptr));
                THROW_IF_FAILED(frame->SetSize(p.s->targetSize.x, p.s->targetSize.y));
                auto format = GUID_WICPixelFormat32bppBGRA;
                THROW_IF_FAILED(frame->SetPixelFormat(&format));
                THROW_HR_IF(E_UNEXPECTED, format != GUID_WICPixelFormat32bppBGRA);
                THROW_IF_FAILED(frame->WritePixels(p.s->targetSize.y, p.s->targetSize.x * sizeof(u32),
                    gsl::narrow<UINT>(pixels.size() * sizeof(u32)), reinterpret_cast<BYTE*>(pixels.data())));
                THROW_IF_FAILED(frame->Commit());
                THROW_IF_FAILED(encoder->Commit());
                log << "First frame saved as a diagnostic back-buffer PNG" << std::endl;
            }
            const auto hr = Win7::Present(p);
            THROW_IF_FAILED(hr);
            log << "Frame " << ++frames << ": " << p.s->targetSize.x << 'x' << p.s->targetSize.y
                << "; Present=0x" << std::hex << static_cast<unsigned long>(hr) << std::dec
                << (readback ? "; pre-Present readback" : "") << std::endl;
            return pixels;
        }

        void Resize(u16 width, u16 height)
        {
            Sample(width, height);
            backend->ReleaseResources();
            Win7::ResizeSwapChain(p);
        }

        void SelfTest()
        {
            for (const auto size : { u16x2{800, 352}, u16x2{537, 247}, u16x2{320, 176}, u16x2{800, 352} })
            {
                Resize(size.x, size.y);
                const auto first = Frame(true);
                Check(std::any_of(first.begin(), first.begin() + size.x * 22,
                    [](u32 pixel) { return (pixel & 0xffffff) != 0x0e1620; }), "header glyph pixels are present");
                Check((first.back() & 0xffffff) == 0x0e1620, "bottom-right background is fully redrawn");
                const auto repeat = Frame(true);
                Check(first == repeat, "full redraw after discard is pixel-identical");
                Sample(size.x, size.y, true);
                const auto changed = Frame(true);
                Check(first != changed, "new foreground reaches the rendered frame");
                Sample(size.x, size.y);
                Check(Frame(true) == first, "restoring foreground restores the exact frame");
            }
            const auto expected = Frame(true);
            CreateBackend();
            Check(Frame(true) == expected, "explicit device/target recreation restores the frame");
            p.s.write()->targetSize = { 0, 0 };
            bool rejected = false;
            try { Win7::ResizeSwapChain(p); }
            catch (const wil::ResultException& ex) { rejected = ex.GetErrorCode() == E_INVALIDARG; }
            Check(rejected, "zero-sized resize rejected before DXGI");
            p.s.write()->targetSize = { 800, 352 };
            Check(Frame(true) == expected, "target survives rejected zero-sized resize");
            Check(!backend->RequiresContinuousRedraw(), "static backend does not request continuous redraw");
            log << "Automated backend checks passed: True" << std::endl;
        }

        void Paint()
        {
            if (!ready || failed || IsIconic(window) || !IsWindowVisible(window)) return;
            RECT rect{};
            THROW_IF_WIN32_BOOL_FALSE(GetClientRect(window, &rect));
            if (rect.right <= 0 || rect.bottom <= 0) return;
            // The Atlas payload uses u16 dimensions. Do not truncate giant windows.
            THROW_HR_IF(E_INVALIDARG, rect.right > UINT16_MAX || rect.bottom > UINT16_MAX);
            if (p.s->targetSize.x != rect.right || p.s->targetSize.y != rect.bottom)
                Resize(static_cast<u16>(rect.right), static_cast<u16>(rect.bottom));
            Frame(false);
        }
    };

    LRESULT CALLBACK WindowProcedure(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
    {
        auto proof = reinterpret_cast<Proof*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        if (message == WM_NCCREATE)
        {
            proof = static_cast<Proof*>(reinterpret_cast<CREATESTRUCTW*>(lparam)->lpCreateParams);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(proof));
        }
        if (!proof) return DefWindowProcW(hwnd, message, wparam, lparam);
        try
        {
            switch (message)
            {
            case WM_ERASEBKGND: return 1;
            case WM_SIZE:
                if (wparam == SIZE_MINIMIZED) proof->log << "Window minimized: rendering parked" << std::endl;
                else InvalidateRect(hwnd, nullptr, FALSE);
                return 0;
            case WM_PAINT:
            {
                PAINTSTRUCT ps{};
                BeginPaint(hwnd, &ps);
                const auto end = wil::scope_exit([&] { EndPaint(hwnd, &ps); });
                proof->Paint();
                return 0;
            }
            case WM_KEYDOWN:
                if (wparam == VK_ESCAPE) PostMessageW(hwnd, WM_CLOSE, 0, 0);
                if (wparam == 'R' && proof->ready && !proof->failed)
                {
                    proof->CreateBackend();
                    proof->log << "User requested device/target recreation" << std::endl;
                    InvalidateRect(hwnd, nullptr, FALSE);
                }
                return 0;
            case WM_CLOSE:
                proof->ready = false;
                // Unwind the loop; the owner destroys backend, swap chain, then HWND.
                PostQuitMessage(0);
                return 0;
            }
        }
        catch (...)
        {
            proof->failed = true;
            proof->log << "FAIL: window rendering HRESULT=0x" << std::hex
                << static_cast<unsigned long>(wil::ResultFromCaughtException()) << std::dec << std::endl;
            PostQuitMessage(1);
            return 0;
        }
        return DefWindowProcW(hwnd, message, wparam, lparam);
    }
}

int wmain(int argc, wchar_t** argv)
{
    const wchar_t* output = nullptr;
    const wchar_t* capture = nullptr;
    bool warp = false, d2d = false, selfTest = false, injectFailure = false;
    for (int i = 1; i < argc; ++i)
    {
        if (wcscmp(argv[i], L"--output") == 0 && !output && i + 1 < argc) output = argv[++i];
        else if (wcscmp(argv[i], L"--capture") == 0 && !capture && i + 1 < argc) capture = argv[++i];
        else if (wcscmp(argv[i], L"--warp") == 0 && !warp) warp = true;
        else if (wcscmp(argv[i], L"--d2d") == 0 && !d2d) d2d = true;
        else if (wcscmp(argv[i], L"--self-test") == 0 && !selfTest) selfTest = true;
        else if (wcscmp(argv[i], L"--inject-render-failure") == 0 && !injectFailure) injectFailure = true;
        else return 64;
    }
    if (!output || !*output) return 64;
    if (injectFailure && !selfTest) return 64;
    if (capture && (!*capture || !selfTest || _wcsicmp(output, capture) == 0)) return 64;
    const auto com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const auto uninitialize = wil::scope_exit([&] { if (SUCCEEDED(com)) CoUninitialize(); });
    Proof proof;
    proof.log.open(output, std::ios::binary | std::ios::trunc);
    if (!proof.log) return 2;
    proof.d2d = d2d;
    proof.injectRenderFailure = injectFailure;
    if (capture) proof.capturePath = capture;
    proof.log << "VT7 Atlas backend proof 0.1\nBuild: " << __DATE__ << ' ' << __TIME__ << "; compiler=" << _MSC_FULL_VER
#ifdef NDEBUG
        << "; Release x64\n"
#else
        << "; Debug x64\n"
#endif
        << "Backend: Atlas " << (d2d ? "Direct2D" : "Direct3D11") << "; " << (warp ? "forced WARP" : "forced hardware")
        << "; mode=" << (selfTest ? "hidden automated checks" : "visible manual check")
        << "\nFixed pre-mapped Consolas glyphs. Not AtlasEngine font mapping or TerminalCore integration.\n" << std::flush;
    using VersionFn = LONG (WINAPI*)(OSVERSIONINFOW*);
    const auto versionFn = reinterpret_cast<VersionFn>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"));
    OSVERSIONINFOW version{ sizeof(version) };
    if (versionFn && versionFn(&version) == 0)
        proof.log << "Windows NT: " << version.dwMajorVersion << '.' << version.dwMinorVersion << '.' << version.dwBuildNumber << std::endl;
    try
    {
        THROW_IF_FAILED(com);
        WNDCLASSW wc{};
        wc.lpfnWndProc = WindowProcedure;
        wc.hInstance = GetModuleHandleW(nullptr);
        wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        wc.lpszClassName = windowClass;
        THROW_LAST_ERROR_IF(!RegisterClassW(&wc));
        const std::wstring title = std::wstring(L"VT7 Atlas backend proof - ") + (d2d ? L"Direct2D" : L"Direct3D11") + (warp ? L" - WARP" : L" - Hardware");
        proof.window = CreateWindowExW(0, windowClass, title.c_str(), WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT, 850, 420, nullptr, nullptr, wc.hInstance, &proof);
        THROW_HR_IF(E_FAIL, !proof.window);
        proof.Initialize();
        proof.p.s.write()->target.write()->useWARP = warp;
        proof.Sample(800, 352);
        proof.CreateBackend();
        if (selfTest) proof.SelfTest();
        else
        {
            proof.ready = true;
            ShowWindow(proof.window, SW_SHOWNORMAL);
            MSG msg{};
            BOOL result;
            while ((result = GetMessageW(&msg, nullptr, 0, 0)) > 0)
            {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
            THROW_HR_IF(E_FAIL, result == -1);
            proof.Check(proof.frames > 0 && !proof.failed, "manual session produced frames and closed without a rendering error");
            proof.log << "Visual correctness requires tester confirmation. No automatic visual-acceptance claim." << std::endl;
        }
    }
    catch (...)
    {
        proof.failed = true;
        proof.log << "FAIL: HRESULT=0x" << std::hex << static_cast<unsigned long>(wil::ResultFromCaughtException()) << std::dec << std::endl;
    }
    proof.log << "Failed: " << (proof.failed ? "True" : "False") << "; frames=" << proof.frames << std::endl;
    if (!proof.log) return 2;
    return proof.failed ? 1 : 0;
}
