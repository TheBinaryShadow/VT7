// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include <LibraryIncludes.h>
#include "include/vt7_native.h"
#include "../../cascadia/TerminalCore/Terminal.hpp"
#include "../VT7.Core/ProofRenderer.hpp"

namespace
{
    constexpr wchar_t windowClass[] = L"VT7.TerminalSurface.2";
    constexpr COLORREF surfaceBackground = RGB(16, 24, 33);

    struct Surface
    {
        Microsoft::Console::Render::Renderer renderer;
        Microsoft::Terminal::Core::Terminal terminal;
        HFONT font = nullptr;
        HFONT boldFont = nullptr;
        HWND window = nullptr;
        int cellWidth = 9;
        int cellHeight = 18;
        uint32_t paints = 0;
        uint32_t resizes = 0;
        HRESULT lastError = S_OK;
        bool ownedByWindow = false;
        bool initialized = false;

        ~Surface()
        {
            if (font) DeleteObject(font);
            if (boldFont) DeleteObject(boldFont);
        }

        void CreateFontForWindow()
        {
            const auto dc = GetDC(window);
            THROW_LAST_ERROR_IF(!dc);
            const auto release = wil::scope_exit([&] { ReleaseDC(window, dc); });
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
                L"\u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\r\n"
                L"\u2502 Windows 7, VT7 \u2502\r\n"
                L"\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\r\n\r\n"
                L"Static proof - interactive sessions are coming later.");
        }

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
            lastError = S_OK;
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
                case WM_SIZE:
                    surface->Resize();
                    return 0;
                case WM_ERASEBKGND:
                    return 1;
                case WM_PAINT:
                {
                    PAINTSTRUCT paint{};
                    const auto dc = BeginPaint(window, &paint);
                    const auto finish = wil::scope_exit([&] { EndPaint(window, &paint); });
                    surface->Paint(dc);
                    return 0;
                }
                case WM_NCDESTROY:
                    SetWindowLongPtrW(window, GWLP_USERDATA, 0);
                    if (surface->ownedByWindow) delete surface;
                    return DefWindowProcW(window, message, wparam, lparam);
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

int32_t __cdecl VT7_CreateSurface(void* parent, void** result)
try
{
    if (!result) return E_POINTER;
    *result = nullptr;
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
    auto surface = std::make_unique<Surface>();
    const auto window = CreateWindowExW(0, windowClass, L"VT7 terminal viewport",
        WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS, 0, 0, 900, 500, parentWindow, nullptr, module, surface.get());
    if (!window)
    {
        THROW_IF_FAILED(surface->lastError);
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
    Lookup(window);
    THROW_IF_WIN32_BOOL_FALSE(DestroyWindow(static_cast<HWND>(window)));
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
    *info = { sizeof(*info), static_cast<uint32_t>(viewport.Width()), static_cast<uint32_t>(viewport.Height()),
        static_cast<uint32_t>(surface->cellWidth), static_cast<uint32_t>(surface->cellHeight),
        surface->paints, surface->resizes, surface->lastError };
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
