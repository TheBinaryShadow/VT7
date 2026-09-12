// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include <LibraryIncludes.h>
#include "include/vt7_native.h"
#include "../../cascadia/TerminalCore/Terminal.hpp"
#include "../../renderer/base/renderer.hpp"
#include "../VT7.Renderer/Win7FontFallback.hpp"

namespace
{
    void Check(bool condition, const char* message)
    {
        if (!condition) throw std::runtime_error(message);
    }

    struct Fixture
    {
        Microsoft::Terminal::Core::Terminal core;
        Microsoft::Console::Render::Renderer renderer;
        Fixture() : renderer([this]() -> auto& {
            const auto guard = core.LockForWriting();
            return core.GetRenderSettings();
        }(), &core)
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
        run(L"Windows 7 Atlas font boundary: 48 mappings, cache/configuration and invalid-input controls", [&output](Fixture& f) {
            wil::com_ptr<IDWriteFactory1> factory;
            THROW_IF_FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory1), reinterpret_cast<IUnknown**>(factory.put())));
            wil::com_ptr<IDWriteFontCollection> collection;
            THROW_IF_FAILED(factory->GetSystemFontCollection(collection.put(), FALSE));
            VT7::Text::FontFallback fallback(factory.get());
            const wchar_t* samples[]{L"Atlas ASCII", L"caf\u00e9 e\u0301", L"A\u4e2d\u6587B", L"\u0633\u0644\u0627\u0645", L"A\u262fB", L"A\U0001f600B"};
            for (const auto em : {16.f, 24.f})
            {
                fallback.Configure(collection.get(), L"Consolas", em, DWRITE_FONT_WEIGHT_NORMAL, L"en-US");
                for (const std::wstring text : samples)
                {
                    f.core.Write(L"\x1b[2J\x1b[H"); f.core.Write(text);
                    const auto& row = f.core.GetTextBuffer().GetRowByOffset(f.core.GetViewport().Top());
                    std::wstring original;
                    std::vector<UINT16> columns;
                    UINT16 column = 0;
                    while (original.size() < text.size())
                    {
                        const auto glyph = row.GlyphAt(column);
                        columns.insert(columns.end(), glyph.size(), column);
                        original.append(glyph);
                        column += row.DbcsAttrAt(column) == DbcsAttribute::Leading ? 2 : 1;
                    }
                    columns.push_back(column);
                    Check(original == text, "Font fixture source changed");
                    for (size_t style = 0; style < 4; ++style)
                    {
                        auto mapped = fallback.Map(text, columns, style);
                        const auto cached = fallback.Map(text, columns, style);
                        Check(mapped.size() == cached.size(), "Cached mapping differs");
                        UINT32 covered = 0;
                        for (size_t i = 0; i < mapped.size(); ++i)
                        {
                            const auto& range = mapped[i];
                            if (em == 16.f && style == 0)
                            {
                                UINT32 count = 0;
                                THROW_IF_FAILED(range.face->GetFiles(&count, nullptr));
                                std::vector<IDWriteFontFile*> files(count);
                                const auto release = wil::scope_exit([&] { for (auto file : files) if (file) file->Release(); });
                                THROW_IF_FAILED(range.face->GetFiles(&count, files.data()));
                                for (const auto file : files)
                                {
                                    wil::com_ptr<IDWriteFontFileLoader> loader;
                                    THROW_IF_FAILED(file->GetLoader(loader.put()));
                                    if (const auto local = loader.try_query<IDWriteLocalFontFileLoader>())
                                    {
                                        const void* key = nullptr; UINT32 keySize = 0, length = 0;
                                        THROW_IF_FAILED(file->GetReferenceKey(&key, &keySize));
                                        THROW_IF_FAILED(local->GetFilePathLengthFromKey(key, keySize, &length));
                                        std::wstring path(length + 1, L'\0');
                                        THROW_IF_FAILED(local->GetFilePathFromKey(key, keySize, path.data(), length + 1));
                                        path.resize(length);
                                        output += fmt::format(L"FONT: {} UTF16 [{},{}) face {}\r\n", text, range.start, range.end, path);
                                    }
                                }
                            }
                            Check(range.start == covered && range.end > range.start && range.end <= text.size() && range.face,
                                "Mapped source partition invalid");
                            Check(range.end == text.size() || columns[range.end] != columns[range.end - 1], "Font boundary split core cluster");
                            Check(range.start == cached[i].start && range.end == cached[i].end && range.face == cached[i].face, "Retained face/cache identity changed");
                            for (UINT32 pos = range.start; pos < range.end; ++pos)
                            {
                                UINT32 scalar = text[pos];
                                if (scalar >= 0xd800 && scalar <= 0xdbff && pos + 1 < range.end)
                                    scalar = 0x10000 + ((scalar - 0xd800) << 10) + text[++pos] - 0xdc00;
                                if (scalar == 0x1f600 || scalar == 0x262f)
                                {
                                    UINT16 index = 0;
                                    THROW_IF_FAILED(range.face->GetGlyphIndicesW(&scalar, 1, &index));
                                    Check(index != 0, "Standalone symbol fallback has glyph zero");
                                }
                            }
                            covered = range.end;
                        }
                        Check(covered == text.size(), "Mapped source truncated");
                    }
                }
            }
            bool rejected = false;
            try { fallback.Map(L"bad", {}, 0); } catch (...) { rejected = true; }
            Check(rejected, "Malformed column map was accepted");
            rejected = false;
            try { const UINT16 columns[]{0, 1}; fallback.Map(L"x", columns, 4); } catch (...) { rejected = true; }
            Check(rejected, "Invalid style index was accepted");
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
