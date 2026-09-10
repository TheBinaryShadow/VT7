// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include <LibraryIncludes.h>
#include "include/vt7_native.h"
#include "../../cascadia/TerminalCore/Terminal.hpp"
#include "../VT7.Core/ProofRenderer.hpp"

namespace
{
    void Check(bool condition, const char* message)
    {
        if (!condition) throw std::runtime_error(message);
    }

    struct Fixture
    {
        Microsoft::Console::Render::Renderer renderer;
        Microsoft::Terminal::Core::Terminal core;
        Fixture()
        {
            const auto guard = core.LockForWriting();
            core.Create({80, 24}, 100, renderer);
        }
        std::wstring Row(int y)
        {
            return std::wstring{ core.GetTextBuffer().GetRowByOffset(y).GetText() };
        }
    };
}

int32_t __cdecl VT7_RunCoreTests(wchar_t* report, uint32_t reportCharacters)
{
    if (!report) return E_POINTER;
    if (reportCharacters == 0) return E_INVALIDARG;
    report[0] = L'\0';
    std::wstring output;
    bool passed = true;
    try
    {
        const auto run = [&](const wchar_t* name, auto&& body) {
            try
            {
                Fixture fixture;
                const auto guard = fixture.core.LockForWriting();
                body(fixture);
                output += std::wstring{ L"PASS: " } + name + L"\r\n";
            }
            catch (const std::exception& error)
            {
                passed = false;
                const auto message = std::string_view{ error.what() };
                output += std::wstring{ L"FAIL: " } + name + L": " + std::wstring{message.begin(), message.end()} + L"\r\n";
            }
            catch (...)
            {
                passed = false;
                output += std::wstring{ L"FAIL: " } + name + L" (native exception)\r\n";
            }
        };

        run(L"VT cursor movement and erase", [](Fixture& f) {
            f.core.Write(L"abcdef\rXY\x1b[K\x1b[3;5HZ");
            Check(f.Row(0).substr(0, 6) == L"XY    ", "CR or erase failed");
            Check(f.Row(2).at(4) == L'Z', "CUP failed");
        });
        run(L"True-color and indexed SGR", [](Fixture& f) {
            f.core.Write(L"\x1b[38;2;12;34;56mT\x1b[48;5;196mR\x1b[0mN");
            auto& row = f.core.GetTextBuffer().GetRowByOffset(0);
            Check(f.core.GetAttributeColors(row.GetAttrByColumn(0)).first == RGB(12,34,56), "true color differs");
            Check(f.core.GetAttributeColors(row.GetAttrByColumn(1)).second == RGB(255,0,0), "palette index differs");
            Check(f.core.GetAttributeColors(row.GetAttrByColumn(2)).first != RGB(12,34,56), "SGR reset failed");
        });
        run(L"Wide and combining Unicode cells", [](Fixture& f) {
            f.core.Write(L"A\u4e2dBe\u0301C");
            const auto& row = f.core.GetTextBuffer().GetRowByOffset(0);
            Check(row.DbcsAttrAt(1) == DbcsAttribute::Leading && row.DbcsAttrAt(2) == DbcsAttribute::Trailing, "wide-cell allocation failed");
            Check(row.GlyphAt(3) == L"B", "wide-cell advance failed");
            Check(row.GlyphAt(4) == L"e\u0301" && row.GlyphAt(5) == L"C", "combining-cell allocation failed");
        });
        run(L"Alternate screen restores main buffer", [](Fixture& f) {
            f.core.Write(L"MAIN\x1b[?1049h\x1b[HALT");
            Check(f.Row(0).substr(0, 3) == L"ALT", "alternate screen missing");
            f.core.Write(L"\x1b[?1049l");
            Check(f.Row(0).substr(0, 4) == L"MAIN", "main screen not restored");
        });
        run(L"Resize and reflow preserve text", [](Fixture& f) {
            std::wstring content;
            for (int i = 0; i < 150; ++i) content += static_cast<wchar_t>(L'A' + (i % 26));
            f.core.Write(content);
            THROW_IF_FAILED(f.core.UserResize({40, 24}));
            Check(f.core.GetViewport().Width() == 40, "shrink failed");
            THROW_IF_FAILED(f.core.UserResize({100, 30}));
            Check(f.core.GetViewport().Width() == 100 && f.core.GetViewport().Height() == 30, "grow failed");
            Check(f.Row(0).substr(0,100) + f.Row(1).substr(0,50) == content, "reflow changed buffer content");
        });
        run(L"VT sequence split across writes", [](Fixture& f) {
            f.core.Write(L"\x1b[38;2;10;");
            f.core.Write(L"20;30mS");
            const auto& row = f.core.GetTextBuffer().GetRowByOffset(0);
            Check(row.GlyphAt(0) == L"S", "split sequence was printed literally");
            Check(f.core.GetAttributeColors(row.GetAttrByColumn(0)).first == RGB(10,20,30), "split SGR lost state");
        });
        run(L"Windows 7 core lock contention", [](Fixture&) {
            til::recursive_ticket_lock lock;
            int total = 0;
            const auto increment = [&] {
                for (int index = 0; index < 2000; ++index)
                {
                    std::unique_lock first{lock};
                    std::unique_lock second{lock};
                    ++total;
                }
            };
            std::thread worker{increment};
            increment();
            worker.join();
            Check(total == 4000, "mutual exclusion failed");
        });
        if (output.size() >= reportCharacters) return HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER);
        wcscpy_s(report, reportCharacters, output.c_str());
        return passed ? S_OK : E_FAIL;
    }
    catch (...)
    {
        return wil::ResultFromCaughtException();
    }
}
