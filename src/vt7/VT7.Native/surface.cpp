// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include <LibraryIncludes.h>
#include "include/vt7_native.h"
#include "utf8_terminal_stream.hpp"
#include "../../cascadia/TerminalCore/Terminal.hpp"
#include "../../renderer/base/renderer.hpp"
#include "../../renderer/atlas/AtlasEngine.h"
#include <thread>
#include <unordered_map>
#include <deque>

namespace
{
    constexpr wchar_t windowClass[] = L"VT7.TerminalSurface.3";
    constexpr COLORREF surfaceBackground = RGB(16, 24, 33);

    struct Surface;

    struct TerminalDocument
    {
        struct Reply
        {
            uint64_t origin = 0;
            uint64_t sequence = 0;
            std::vector<uint8_t> bytes;
        };
        static constexpr uint64_t expectedCookie = 0x544437444f43554dull;
        uint64_t cookie = expectedCookie;
        DWORD creatingThread = GetCurrentThreadId();
        Microsoft::Terminal::Core::Terminal terminal;
        VT7::Utf8TerminalStream outputStream;
        Microsoft::Console::Render::Renderer renderer;
        Surface* attachedView = nullptr;
        uint64_t attachmentGeneration = 0;
        uint64_t mutationSequence = 0;
        uint64_t streamGeneration = 0;
        uint64_t originGeneration = 0;
        uint64_t lastSequence = 0;
        std::unordered_map<uint64_t, uint64_t> producerSequences;
        std::deque<Reply> replies;
        size_t replyBytes = 0;
        uint64_t replySequence = 0;
        uint64_t currentOrigin = 0;
        HRESULT replyFailure = S_OK;
        bool streamActive = false;
        bool initialized = false;
        uint32_t scrollbackLines = 500;
        bool loadDemo = true;

        TerminalDocument(uint32_t columns, uint32_t rows, uint32_t scrollback, bool demonstration = true) : renderer([this]() -> auto& {
            const auto guard = terminal.LockForWriting();
            return terminal.GetRenderSettings();
        }(), &terminal)
        {
            const auto guard = terminal.LockForWriting();
            scrollbackLines = scrollback;
            loadDemo = demonstration;
            terminal.Create({ gsl::narrow<til::CoordType>(columns), gsl::narrow<til::CoordType>(rows) },
                gsl::narrow<til::CoordType>(scrollback), renderer);
            initialized = true;
            auto& settings = terminal.GetRenderSettings();
            settings.SetColorAlias(ColorAlias::DefaultForeground, TextColor::DEFAULT_FOREGROUND, RGB(235, 242, 248));
            settings.SetColorAlias(ColorAlias::DefaultBackground, TextColor::DEFAULT_BACKGROUND, surfaceBackground);
            settings.SaveDefaultSettings();
            terminal.SetWriteInputCallback([this](const std::wstring_view response) noexcept { QueueReply(response); });
            if (loadDemo) FillDemo();
        }

        void QueueReply(const std::wstring_view response) noexcept
        {
            try
            {
                THROW_HR_IF(E_UNEXPECTED, currentOrigin == 0);
                const auto count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, response.data(),
                    gsl::narrow<int>(response.size()), nullptr, 0, nullptr, nullptr);
                THROW_LAST_ERROR_IF(count == 0 && !response.empty());
                std::vector<uint8_t> encoded(gsl::narrow<size_t>(count));
                if (count)
                {
                    const auto written = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, response.data(),
                        gsl::narrow<int>(response.size()), reinterpret_cast<char*>(encoded.data()), count, nullptr, nullptr);
                    THROW_LAST_ERROR_IF(written != count);
                }
                for (size_t offset = 0; offset < encoded.size(); offset += VT7_TERMINAL_REPLY_BYTES)
                {
                    const auto length = std::min<size_t>(VT7_TERMINAL_REPLY_BYTES, encoded.size() - offset);
                    THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_BUFFER_OVERFLOW),
                        replies.size() >= 64 || replyBytes + length > 64 * 1024);
                    Reply reply{ currentOrigin, ++replySequence,
                        std::vector<uint8_t>(encoded.begin() + offset, encoded.begin() + offset + length) };
                    replyBytes += length;
                    replies.emplace_back(std::move(reply));
                }
            }
            catch (...)
            {
                if (SUCCEEDED(replyFailure)) replyFailure = wil::ResultFromCaughtException();
            }
        }

        void FillDemo()
        {
            terminal.Write(L"\x1b[0m\x1b[2J\x1b[H"
                L"\x1b[1;38;2;101;184;255mVT7 - the first terminal viewport\x1b[0m\r\n"
                L"Windows 7 deserves a terminal built with care.\r\n\r\n"
                L"This text lives in Microsoft TerminalCore's text buffer.\r\n"
                L"Resize the window: the core reflows the content.\r\n\r\n"
                L"Standard and bright colors:\r\n");
            for (int index = 0; index < 16; ++index)
                terminal.Write(fmt::format(L"\x1b[{}m {:02} ", index < 8 ? 40 + index : 100 + index - 8, index));
            terminal.Write(L"\x1b[0m\r\n\r\n256-color ramp:\r\n");
            for (int index = 16; index < 52; ++index)
                terminal.Write(fmt::format(L"\x1b[48;5;{}m ", index));
            terminal.Write(L"\x1b[0m\r\n\r\n"
                L"\x1b[38;2;255;170;80mTrue color\x1b[0m   "
                L"\x1b[1mBold\x1b[0m   \x1b[4mUnderline\x1b[0m   \x1b[7mReverse\x1b[0m\r\n"
                L"Unicode: caf\u00e9  \u03b1\u03b2\u03b3  e\u0301  \u4e2d\u6587\r\n"
                L"Fallback: \u262f \U0001f600 | Arabic (logical cells): \u0633\u0644\u0627\u0645\r\n"
                L"\u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\r\n"
                L"\u2502 Windows 7, VT7 \u2502\r\n"
                L"\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\r\n\r\n"
                L"Static proof - interactive sessions are coming later.");
            ++mutationSequence;
        }

        ~TerminalDocument()
        {
            renderer.TriggerTeardown();
            cookie = 0;
        }
    };

    struct Surface
    {
        static constexpr uint64_t expectedCookie = 0x5444375649455748ull;
        uint64_t cookie = expectedCookie;
        DWORD creatingThread = GetCurrentThreadId();
        TerminalDocument* document;
        Microsoft::Terminal::Core::Terminal& terminal;
        VT7::Utf8TerminalStream& outputStream;
        std::unique_ptr<Microsoft::Console::Render::AtlasEngine> atlas;
        Microsoft::Console::Render::Renderer& renderer;
        std::unique_ptr<TerminalDocument> ownedDocument;
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
        bool closing = false;
        uint64_t attachmentGeneration = 0;
        std::optional<Microsoft::Console::Render::TimerHandle> diagnosticTimer;
        uint32_t diagnosticTimerFires = 0;
        int64_t wheelDeltaRemainder = 0;

        Surface(TerminalDocument* terminalDocument, uint32_t rendererMode) : document(terminalDocument),
            terminal(terminalDocument->terminal), outputStream(terminalDocument->outputStream), renderer(terminalDocument->renderer),
            mode(rendererMode & 0xff), capture((rendererMode & 0x100) != 0), injectBlank((rendererMode & 0x200) != 0),
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
            renderer.SetRendererEnteredErrorStateCallback({});
            renderer.SetThreadExitCallback({});
            if (atlas)
            {
                renderer.RemoveRenderEngine(atlas.get());
                atlas.reset();
            }
        }

        void Start()
        {
            if (atlas && document->initialized && !running && SUCCEEDED(lastError.load()) && IsWindowVisible(window))
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

        void ScrollWheel(const short wheelDelta)
        {
            if (!wheelDelta || !document->initialized) return;

            UINT configuredLines = 3;
            if (!SystemParametersInfoW(SPI_GETWHEELSCROLLLINES, 0, &configuredLines, 0))
                configuredLines = 3;
            if (configuredLines == 0) return;

            const auto guard = terminal.LockForWriting();
            const auto viewport = terminal.GetViewport();
            const auto rowsPerNotch = configuredLines == WHEEL_PAGESCROLL ?
                std::max(1, viewport.Height()) : gsl::narrow<int>(std::min<UINT>(configuredLines, 1000));

            // Preserve sub-notch precision while honoring the Windows wheel setting.
            // Positive WM_MOUSEWHEEL deltas move toward older output (a smaller top).
            wheelDeltaRemainder -= static_cast<int64_t>(wheelDelta) * rowsPerNotch;
            const auto rowDelta = wheelDeltaRemainder / WHEEL_DELTA;
            wheelDeltaRemainder %= WHEEL_DELTA;
            if (!rowDelta) return;

            const auto currentTop = terminal.GetScrollOffset();
            const auto targetTop = std::clamp<int64_t>(currentTop + rowDelta, 0, INT_MAX);
            terminal.UserScrollViewport(gsl::narrow<int>(targetTop));
            InvalidateRect(window, nullptr, FALSE);
        }

        ~Surface()
        {
            CloseRenderer();
            if (font) DeleteObject(font);
            if (boldFont) DeleteObject(boldFont);
            cookie = 0;
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

        void BeginStream()
        {
            const auto guard = terminal.LockForWriting();
            terminal.HardResetWithoutErase();
            terminal.Write(L"\x1b[?1049l\x1b[?2026l\x1b[0m\x1b[3J\x1b[2J\x1b[H");
            outputStream.Begin();
            InvalidateRect(window, nullptr, FALSE);
        }

        void WriteStream(const std::string_view bytes)
        {
            {
                const auto guard = terminal.LockForWriting();
                THROW_IF_FAILED(outputStream.Write(bytes, [this](const std::wstring_view text) {
                    terminal.Write(text);
                }));
            }
            InvalidateRect(window, nullptr, FALSE);
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
            if (!document->initialized)
            {
                terminal.Create(size, gsl::narrow<til::CoordType>(document->scrollbackLines), renderer);
                document->initialized = true;
                auto& settings = terminal.GetRenderSettings();
                settings.SetColorAlias(ColorAlias::DefaultForeground,
                    TextColor::DEFAULT_FOREGROUND, RGB(235, 242, 248));
                settings.SetColorAlias(ColorAlias::DefaultBackground,
                    TextColor::DEFAULT_BACKGROUND, surfaceBackground);
                settings.SaveDefaultSettings();
                if (document->loadDemo) FillDemo();
            }
            else
            {
                const auto result = terminal.UserResize(size);
                THROW_IF_FAILED(result);
                if (result == S_OK) ++resizes;
            }
            ++document->mutationSequence;
            PostMessageW(window, WM_APP + 2, gsl::narrow<WPARAM>(size.width), gsl::narrow<LPARAM>(size.height));
            InvalidateRect(window, nullptr, FALSE);
        }

        void Paint(HDC destination)
        {
            RECT client{};
            THROW_IF_WIN32_BOOL_FALSE(GetClientRect(window, &client));
            if (client.right <= 0 || client.bottom <= 0 || !document->initialized) return;
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
                case WM_GETDLGCODE:
                    return DLGC_WANTARROWS | DLGC_WANTTAB | DLGC_WANTCHARS | DLGC_WANTALLKEYS;
                case WM_LBUTTONDOWN:
                    SetFocus(window);
                    break;
                case WM_MOUSEWHEEL:
                    surface->ScrollWheel(static_cast<short>(HIWORD(wparam)));
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

    TerminalDocument* LookupDocument(void* handle)
    {
        THROW_HR_IF(E_HANDLE, !handle);
        const auto document = static_cast<TerminalDocument*>(handle);
        THROW_HR_IF(E_HANDLE, document->cookie != TerminalDocument::expectedCookie);
        THROW_HR_IF(RPC_E_WRONG_THREAD, document->creatingThread != GetCurrentThreadId());
        return document;
    }

    Surface* LookupView(void* handle)
    {
        THROW_HR_IF(E_HANDLE, !handle);
        const auto view = static_cast<Surface*>(handle);
        THROW_HR_IF(E_HANDLE, view->cookie != Surface::expectedCookie);
        THROW_HR_IF(RPC_E_WRONG_THREAD, view->creatingThread != GetCurrentThreadId());
        return view;
    }

    void ValidateRendererMode(uint32_t mode)
    {
        THROW_HR_IF(E_INVALIDARG, (mode & 0xff) > 5 || (mode & ~0xfffu) ||
            ((mode & 0xe00) && (!(mode & 0x100) || !(mode & 0xff))) || ((mode >> 10) & 3) == 3);
    }

    HWND CreateViewWindow(HWND parent, Surface* surface)
    {
        THROW_HR_IF(E_HANDLE, !IsWindow(parent));
        THROW_HR_IF(RPC_E_WRONG_THREAD, GetWindowThreadProcessId(parent, nullptr) != GetCurrentThreadId());
        HMODULE module = nullptr;
        THROW_IF_WIN32_BOOL_FALSE(GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
            GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, reinterpret_cast<LPCWSTR>(&WindowProc), &module));
        WNDCLASSEXW klass{ sizeof(klass) };
        klass.lpfnWndProc = WindowProc;
        klass.hInstance = module;
        klass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        klass.lpszClassName = windowClass;
        if (!RegisterClassExW(&klass)) THROW_LAST_ERROR_IF(GetLastError() != ERROR_CLASS_ALREADY_EXISTS);
        const auto window = CreateWindowExW(0, windowClass, L"VT7 terminal viewport",
            WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | WS_TABSTOP, 0, 0, 900, 500,
            parent, nullptr, module, surface);
        if (!window)
        {
            THROW_IF_FAILED(surface->lastError.load());
            THROW_LAST_ERROR();
        }
        return window;
    }

    void InvalidateAttached(TerminalDocument* document)
    {
        if (document->attachedView && document->attachedView->window)
            InvalidateRect(document->attachedView->window, nullptr, FALSE);
    }

    void BeginDocumentStream(TerminalDocument* document, uint64_t generation)
    {
        THROW_HR_IF(E_INVALIDARG, generation == 0);
        THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_INVALID_STATE), !document->initialized);
        const auto guard = document->terminal.LockForWriting();
        document->terminal.HardResetWithoutErase();
        document->terminal.Write(L"\x1b[?1049l\x1b[?2026l\x1b[0m\x1b[3J\x1b[2J\x1b[H");
        document->outputStream.Begin();
        document->streamGeneration = generation;
        document->originGeneration = 0;
        document->lastSequence = 0;
        document->producerSequences.clear();
        document->replies.clear();
        document->replyBytes = 0;
        document->replySequence = 0;
        document->replyFailure = S_OK;
        document->streamActive = true;
        ++document->mutationSequence;
        InvalidateAttached(document);
    }

    void WriteDocumentStream(TerminalDocument* document, uint64_t generation, uint64_t origin,
        uint64_t sequence, std::string_view bytes)
    {
        THROW_HR_IF(E_INVALIDARG, !document->streamActive || generation == 0 ||
            generation != document->streamGeneration || origin == 0 || sequence == 0);
        const auto prior = document->producerSequences.find(origin);
        THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_INVALID_STATE),
            prior != document->producerSequences.end() && sequence <= prior->second);
        const auto guard = document->terminal.LockForWriting();
        document->currentOrigin = origin;
        const auto clearOrigin = wil::scope_exit([&] { document->currentOrigin = 0; });
        THROW_IF_FAILED(document->outputStream.Write(bytes, [document](const std::wstring_view text) {
            document->terminal.Write(text);
        }));
        THROW_IF_FAILED(document->replyFailure);
        document->originGeneration = origin;
        document->lastSequence = sequence;
        document->producerSequences[origin] = sequence;
        ++document->mutationSequence;
        InvalidateAttached(document);
    }

    HRESULT EndDocumentStream(TerminalDocument* document, uint64_t generation, uint32_t eofKind)
    {
        THROW_HR_IF(E_INVALIDARG, generation == 0 || generation != document->streamGeneration || eofKind > 1);
        const auto guard = document->terminal.LockForWriting();
        document->streamActive = false;
        ++document->mutationSequence;
        if (eofKind)
        {
            document->outputStream.Abandon();
            return S_OK;
        }
        return document->outputStream.End();
    }

    void CompleteInputResult(VT7_INPUT_RESULT* result, const bool handled, const std::wstring& output)
    {
        if (!result) THROW_HR(E_POINTER);
        if (result->struct_size != sizeof(*result)) THROW_HR(E_INVALIDARG);
        VT7_INPUT_RESULT value{};
        value.struct_size = sizeof(value);
        value.handled = handled ? 1u : 0u;
        if (!output.empty())
        {
            const auto count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, output.data(),
                gsl::narrow<int>(output.size()), nullptr, 0, nullptr, nullptr);
            THROW_LAST_ERROR_IF(count == 0);
            THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER), count > gsl::narrow<int>(sizeof(value.bytes)));
            const auto written = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, output.data(),
                gsl::narrow<int>(output.size()), reinterpret_cast<char*>(value.bytes), count, nullptr, nullptr);
            THROW_LAST_ERROR_IF(written != count);
            value.byte_count = gsl::narrow<uint32_t>(written);
        }
        *result = value;
    }
}

int32_t __cdecl VT7_CreateTerminalDocument(const VT7_TERMINAL_DOCUMENT_SETTINGS* settings, void** result)
try
{
    if (!settings || !result) return E_POINTER;
    *result = nullptr;
    THROW_HR_IF(E_INVALIDARG, settings->struct_size != sizeof(*settings) ||
        settings->columns < 1 || settings->columns > 512 || settings->rows < 1 || settings->rows > 256 ||
        settings->scrollback_lines > 32767 || settings->load_demonstration > 1);
    auto document = std::make_unique<TerminalDocument>(settings->columns, settings->rows,
        settings->scrollback_lines, settings->load_demonstration != 0);
    *result = document.release();
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_DestroyTerminalDocument(void* handle)
try
{
    const auto document = LookupDocument(handle);
    THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_BUSY), document->attachedView != nullptr);
    delete document;
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_GetTerminalDocumentInfo(void* handle, VT7_TERMINAL_DOCUMENT_INFO* info)
try
{
    if (!info) return E_POINTER;
    if (info->struct_size != sizeof(*info)) return E_INVALIDARG;
    const auto document = LookupDocument(handle);
    uint32_t columns = 0, rows = 0;
    if (document->initialized)
    {
        const auto guard = document->terminal.LockForReading();
        const auto viewport = document->terminal.GetViewport();
        columns = gsl::narrow<uint32_t>(viewport.Width());
        rows = gsl::narrow<uint32_t>(viewport.Height());
    }
    const auto snapshot = document->outputStream.Snapshot();
    *info = { sizeof(*info), columns, rows, document->attachedView ? 1u : 0u,
        document->attachmentGeneration, document->mutationSequence, document->streamGeneration,
        snapshot.bytes, snapshot.utf16Units, snapshot.writes, snapshot.pendingBytes,
        snapshot.ended ? 1u : 0u, snapshot.lastError };
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_BeginDocumentStream(void* handle, uint64_t generation)
try
{
    BeginDocumentStream(LookupDocument(handle), generation);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_WriteDocumentUtf8(void* handle, uint64_t generation, uint64_t origin,
    uint64_t sequence, const uint8_t* bytes, uint32_t length)
try
{
    if (length && !bytes) return E_POINTER;
    if (length > 1024u * 1024u) return E_INVALIDARG;
    const auto text = reinterpret_cast<const char*>(bytes);
    WriteDocumentStream(LookupDocument(handle), generation, origin, sequence,
        std::string_view{ text ? text : "", length });
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_EndDocumentStream(void* handle, uint64_t generation, uint32_t eofKind)
try
{
    return EndDocumentStream(LookupDocument(handle), generation, eofKind);
}
CATCH_RETURN()

int32_t __cdecl VT7_ReadDocumentReply(void* handle, VT7_TERMINAL_REPLY* reply)
try
{
    if (!reply) return E_POINTER;
    if (reply->struct_size != sizeof(*reply)) return E_INVALIDARG;
    const auto document = LookupDocument(handle);
    if (document->replies.empty()) return S_FALSE;
    const auto& queued = document->replies.front();
    VT7_TERMINAL_REPLY value{};
    value.struct_size = sizeof(value);
    value.byte_count = gsl::narrow<uint32_t>(queued.bytes.size());
    value.origin_transport_generation = queued.origin;
    value.sequence = queued.sequence;
    memcpy(value.bytes, queued.bytes.data(), queued.bytes.size());
    document->replyBytes -= queued.bytes.size();
    document->replies.pop_front();
    *reply = value;
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_CreateTerminalView(void* parent, void* documentHandle, uint32_t rendererMode,
    void** viewResult, void** childResult)
try
{
    if (!viewResult || !childResult) return E_POINTER;
    *viewResult = nullptr;
    *childResult = nullptr;
    ValidateRendererMode(rendererMode);
    const auto document = LookupDocument(documentHandle);
    THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_BUSY), document->attachedView != nullptr);
    auto view = std::make_unique<Surface>(document, rendererMode);
    view->attachmentGeneration = ++document->attachmentGeneration;
    document->attachedView = view.get();
    auto rollback = wil::scope_exit([&] {
        if (document->attachedView == view.get()) document->attachedView = nullptr;
    });
    const auto child = CreateViewWindow(static_cast<HWND>(parent), view.get());
    rollback.release();
    *childResult = child;
    *viewResult = view.release();
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_DetachTerminalView(void* handle)
try
{
    const auto view = LookupView(handle);
    if (!view->window) return S_FALSE;
    view->Stop();
    const auto child = view->window;
    view->ownedByWindow = false;
    THROW_IF_WIN32_BOOL_FALSE(DestroyWindow(child));
    view->window = nullptr;
    view->CloseRenderer();
    if (view->document->attachedView == view) view->document->attachedView = nullptr;
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_DestroyTerminalView(void* handle)
try
{
    const auto view = LookupView(handle);
    if (view->window) THROW_IF_FAILED(static_cast<HRESULT>(VT7_DetachTerminalView(handle)));
    delete view;
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_GetTerminalViewInfo(void* handle, VT7_TERMINAL_VIEW_INFO* info)
try
{
    if (!info) return E_POINTER;
    if (info->struct_size != sizeof(*info)) return E_INVALIDARG;
    const auto view = LookupView(handle);
    *info = { sizeof(*info), view->window ? 1u : 0u, view->attachmentGeneration, view->window };
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_ResizeTerminalDocument(void* handle, uint64_t generation, uint32_t columns, uint32_t rows)
try
{
    const auto document = LookupDocument(handle);
    THROW_HR_IF(E_INVALIDARG, generation == 0 || columns < 1 || columns > 512 || rows < 1 || rows > 256);
    THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_INVALID_STATE), generation != document->attachmentGeneration || !document->initialized);
    const auto guard = document->terminal.LockForWriting();
    THROW_IF_FAILED(document->terminal.UserResize({ gsl::narrow<til::CoordType>(columns), gsl::narrow<til::CoordType>(rows) }));
    ++document->mutationSequence;
    InvalidateAttached(document);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_EncodeTerminalKey(void* handle, uint32_t virtualKey, uint32_t scanCode,
    uint32_t controlKeyState, uint32_t keyDown, uint32_t repeatCount, VT7_INPUT_RESULT* result)
try
{
    if (!result) return E_POINTER;
    if (result->struct_size != sizeof(*result) || virtualKey > 0xffff || scanCode > 0xffff ||
        keyDown > 1 || repeatCount == 0 || repeatCount > 0xffff) return E_INVALIDARG;
    const auto document = LookupDocument(handle);
    THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_INVALID_STATE), !document->initialized);
    const auto guard = document->terminal.LockForWriting();
    std::wstring output;
    bool handled = false;
    for (uint32_t index = 0; index < repeatCount; ++index)
    {
        const auto encoded = document->terminal.SendKeyEventWithoutLayoutTranslation(
            gsl::narrow<WORD>(virtualKey), gsl::narrow<WORD>(scanCode),
            Microsoft::Terminal::Core::ControlKeyStates{ controlKeyState }, keyDown != 0);
        handled |= encoded.has_value();
        if (encoded) output.append(*encoded);
    }
    CompleteInputResult(result, handled, output);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_EncodeTerminalChar(void* handle, uint32_t character, uint32_t scanCode,
    uint32_t controlKeyState, uint32_t repeatCount, VT7_INPUT_RESULT* result)
try
{
    if (!result) return E_POINTER;
    if (result->struct_size != sizeof(*result) || character > 0xffff || scanCode > 0xffff ||
        repeatCount == 0 || repeatCount > 0xffff) return E_INVALIDARG;
    const auto document = LookupDocument(handle);
    THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_INVALID_STATE), !document->initialized);
    const auto guard = document->terminal.LockForWriting();
    std::wstring output;
    bool handled = false;
    for (uint32_t index = 0; index < repeatCount; ++index)
    {
        const auto encoded = document->terminal.SendCharEvent(gsl::narrow<wchar_t>(character),
            gsl::narrow<WORD>(scanCode), Microsoft::Terminal::Core::ControlKeyStates{ controlKeyState });
        handled |= encoded.has_value();
        if (encoded) output.append(*encoded);
    }
    CompleteInputResult(result, handled, output);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_EncodeTerminalFocus(void* handle, uint32_t focused, VT7_INPUT_RESULT* result)
try
{
    if (!result) return E_POINTER;
    if (result->struct_size != sizeof(*result) || focused > 1) return E_INVALIDARG;
    const auto document = LookupDocument(handle);
    THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_INVALID_STATE), !document->initialized);
    const auto guard = document->terminal.LockForWriting();
    const auto encoded = document->terminal.FocusChanged(focused != 0);
    CompleteInputResult(result, encoded.has_value(), encoded.value_or(L""));
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_CreateSurface(void* parent, uint32_t rendererMode, void** result)
try
{
    if (!result) return E_POINTER;
    *result = nullptr;
    ValidateRendererMode(rendererMode);
    auto document = std::make_unique<TerminalDocument>(80, 24, 500);
    auto surface = std::make_unique<Surface>(document.get(), rendererMode);
    document->attachedView = surface.get();
    document->attachmentGeneration = 1;
    surface->attachmentGeneration = 1;
    const auto window = CreateViewWindow(static_cast<HWND>(parent), surface.get());
    surface->ownedDocument = std::move(document);
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
    surface->document->attachedView = nullptr;
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
    surface->outputStream.Abandon();
    surface->document->streamActive = false;
    surface->terminal.HardResetWithoutErase();
    surface->FillDemo();
    ++surface->document->mutationSequence;
    InvalidateRect(static_cast<HWND>(window), nullptr, FALSE);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_BeginSurfaceStream(void* window)
try
{
    const auto surface = Lookup(window);
    BeginDocumentStream(surface->document, surface->outputStream.Snapshot().generation + 1ull);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_WriteSurfaceUtf8(void* window, const uint8_t* bytes, uint32_t length)
try
{
    if (length != 0 && !bytes) return E_POINTER;
    if (length > 1024u * 1024u) return E_INVALIDARG;
    const auto text = reinterpret_cast<const char*>(bytes);
    const auto surface = Lookup(window);
    WriteDocumentStream(surface->document, surface->document->streamGeneration, 1,
        surface->document->lastSequence + 1, std::string_view{ text ? text : "", length });
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_EndSurfaceStream(void* window)
try
{
    const auto surface = Lookup(window);
    return EndDocumentStream(surface->document, surface->document->streamGeneration, 0);
}
CATCH_RETURN()

int32_t __cdecl VT7_GetSurfaceStreamInfo(void* window, VT7_SURFACE_STREAM_INFO* info)
try
{
    if (!info) return E_POINTER;
    if (info->struct_size != sizeof(*info)) return E_INVALIDARG;
    const auto snapshot = Lookup(window)->outputStream.Snapshot();
    *info = { sizeof(*info), snapshot.generation, snapshot.bytes, snapshot.utf16Units,
        snapshot.writes, snapshot.pendingBytes, snapshot.ended ? 1u : 0u, snapshot.lastError };
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_EncodeSurfaceKey(void* window, uint32_t virtualKey, uint32_t scanCode,
    uint32_t controlKeyState, uint32_t keyDown, uint32_t repeatCount, VT7_INPUT_RESULT* result)
try
{
    if (!result) return E_POINTER;
    if (result->struct_size != sizeof(*result) || virtualKey > 0xffff || scanCode > 0xffff ||
        keyDown > 1 || repeatCount == 0 || repeatCount > 0xffff) return E_INVALIDARG;
    const auto surface = Lookup(window);
    const auto guard = surface->terminal.LockForWriting();
    std::wstring output;
    bool handled = false;
    for (uint32_t index = 0; index < repeatCount; ++index)
    {
        const auto encoded = surface->terminal.SendKeyEventWithoutLayoutTranslation(
            gsl::narrow<WORD>(virtualKey), gsl::narrow<WORD>(scanCode),
            Microsoft::Terminal::Core::ControlKeyStates{ controlKeyState }, keyDown != 0);
        handled |= encoded.has_value();
        if (encoded) output.append(*encoded);
    }
    CompleteInputResult(result, handled, output);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_EncodeSurfaceChar(void* window, uint32_t character, uint32_t scanCode,
    uint32_t controlKeyState, uint32_t repeatCount, VT7_INPUT_RESULT* result)
try
{
    if (!result) return E_POINTER;
    if (result->struct_size != sizeof(*result) || character > 0xffff || scanCode > 0xffff ||
        repeatCount == 0 || repeatCount > 0xffff) return E_INVALIDARG;
    const auto surface = Lookup(window);
    const auto guard = surface->terminal.LockForWriting();
    std::wstring output;
    bool handled = false;
    for (uint32_t index = 0; index < repeatCount; ++index)
    {
        const auto encoded = surface->terminal.SendCharEvent(gsl::narrow<wchar_t>(character),
            gsl::narrow<WORD>(scanCode), Microsoft::Terminal::Core::ControlKeyStates{ controlKeyState });
        handled |= encoded.has_value();
        if (encoded) output.append(*encoded);
    }
    CompleteInputResult(result, handled, output);
    return S_OK;
}
CATCH_RETURN()

int32_t __cdecl VT7_EncodeSurfaceFocus(void* window, uint32_t focused, VT7_INPUT_RESULT* result)
try
{
    if (!result) return E_POINTER;
    if (result->struct_size != sizeof(*result) || focused > 1) return E_INVALIDARG;
    const auto surface = Lookup(window);
    const auto guard = surface->terminal.LockForWriting();
    const auto encoded = surface->terminal.FocusChanged(focused != 0);
    CompleteInputResult(result, encoded.has_value(), encoded.value_or(L""));
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
