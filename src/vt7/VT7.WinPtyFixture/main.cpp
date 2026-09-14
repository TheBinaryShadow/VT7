// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.

#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace
{
    struct Snapshot
    {
        std::wstring label;
        SHORT columns{};
        SHORT rows{};
        SHORT cursorX{};
        SHORT cursorY{};
        std::vector<CHAR_INFO> cells;
    };

    struct Result
    {
        std::wstring name;
        std::wstring operation;
        DWORD requestedOutputCodePage{};
        bool requestedCodePageValid{};
        bool outputCodePageSet{};
        DWORD outputCodePageSetError{};
        DWORD outputCodePage{};
        DWORD apiResult{};
        DWORD apiError{};
        DWORD modeBefore{};
        DWORD modeAfter{};
        std::vector<unsigned char> sourceBytes;
        std::vector<Snapshot> snapshots;
    };

    [[noreturn]] void Fail(const char* message)
    {
        throw std::runtime_error(message);
    }

    void Check(const BOOL result, const char* message)
    {
        if (!result)
        {
            Fail(message);
        }
    }

    std::string JsonString(const std::wstring_view text)
    {
        static constexpr char digits[]{ "0123456789abcdef" };
        std::string value;
        value.push_back('"');
        for (const auto character : text)
        {
            const auto unit = static_cast<uint16_t>(character);
            switch (unit)
            {
            case L'"': value += "\\\""; break;
            case L'\\': value += "\\\\"; break;
            case L'\b': value += "\\b"; break;
            case L'\f': value += "\\f"; break;
            case L'\n': value += "\\n"; break;
            case L'\r': value += "\\r"; break;
            case L'\t': value += "\\t"; break;
            default:
                if (unit >= 0x20 && unit <= 0x7e)
                {
                    value.push_back(static_cast<char>(unit));
                }
                else
                {
                    value += "\\u";
                    value.push_back(digits[(unit >> 12) & 0xf]);
                    value.push_back(digits[(unit >> 8) & 0xf]);
                    value.push_back(digits[(unit >> 4) & 0xf]);
                    value.push_back(digits[unit & 0xf]);
                }
                break;
            }
        }
        value.push_back('"');
        return value;
    }

    std::string HexBytes(const std::vector<unsigned char>& bytes)
    {
        static constexpr char digits[]{ "0123456789abcdef" };
        std::string value;
        value.reserve(bytes.size() * 2);
        for (const auto byte : bytes)
        {
            value.push_back(digits[byte >> 4]);
            value.push_back(digits[byte & 0xf]);
        }
        return value;
    }

    Snapshot Capture(const HANDLE output, const std::wstring_view label)
    {
        CONSOLE_SCREEN_BUFFER_INFO info{};
        Check(GetConsoleScreenBufferInfo(output, &info), "GetConsoleScreenBufferInfo failed");

        Snapshot snapshot;
        snapshot.label = label;
        snapshot.columns = static_cast<SHORT>(info.srWindow.Right - info.srWindow.Left + 1);
        snapshot.rows = static_cast<SHORT>(info.srWindow.Bottom - info.srWindow.Top + 1);
        snapshot.cursorX = static_cast<SHORT>(info.dwCursorPosition.X - info.srWindow.Left);
        snapshot.cursorY = static_cast<SHORT>(info.dwCursorPosition.Y - info.srWindow.Top);
        snapshot.cells.resize(static_cast<size_t>(snapshot.columns) * snapshot.rows);

        auto region = info.srWindow;
        const COORD bufferSize{ snapshot.columns, snapshot.rows };
        const COORD bufferOrigin{};
        Check(ReadConsoleOutputW(output, snapshot.cells.data(), bufferSize, bufferOrigin, &region), "ReadConsoleOutputW failed");
        return snapshot;
    }

    void Clear(const HANDLE output)
    {
        CONSOLE_SCREEN_BUFFER_INFO info{};
        Check(GetConsoleScreenBufferInfo(output, &info), "GetConsoleScreenBufferInfo failed");
        const auto cells = static_cast<DWORD>(info.dwSize.X) * info.dwSize.Y;
        DWORD written{};
        Check(FillConsoleOutputCharacterW(output, L' ', cells, {}, &written), "FillConsoleOutputCharacterW failed");
        Check(FillConsoleOutputAttribute(output, info.wAttributes, cells, {}, &written), "FillConsoleOutputAttribute failed");
        Check(SetConsoleCursorPosition(output, {}), "SetConsoleCursorPosition failed");
    }

    std::vector<unsigned char> Encode(const UINT codePage, const std::wstring_view text)
    {
        const auto size = WideCharToMultiByte(codePage, 0, text.data(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
        if (size <= 0)
        {
            Fail("WideCharToMultiByte sizing failed");
        }
        std::vector<unsigned char> bytes(static_cast<size_t>(size));
        if (WideCharToMultiByte(codePage, 0, text.data(), static_cast<int>(text.size()), reinterpret_cast<char*>(bytes.data()), size, nullptr, nullptr) != size)
        {
            Fail("WideCharToMultiByte conversion failed");
        }
        return bytes;
    }

    void WriteWide(const HANDLE output, const std::wstring_view text, DWORD& written)
    {
        Check(WriteConsoleW(output, text.data(), static_cast<DWORD>(text.size()), &written, nullptr), "WriteConsoleW failed");
    }

    bool TrySetOutputCodePage(Result& result, const UINT codePage)
    {
        result.requestedOutputCodePage = codePage;
        result.requestedCodePageValid = IsValidCodePage(codePage) != FALSE;
        result.outputCodePageSet = SetConsoleOutputCP(codePage) != FALSE;
        result.outputCodePageSetError = result.outputCodePageSet ? ERROR_SUCCESS : GetLastError();
        result.outputCodePage = GetConsoleOutputCP();
        return result.outputCodePageSet;
    }

    UINT CodePageFromCase(const std::wstring_view name)
    {
        if (name.ends_with(L"-437")) return 437;
        if (name.ends_with(L"-850")) return 850;
        if (name.ends_with(L"-852")) return 852;
        if (name.ends_with(L"-932")) return 932;
        if (name.ends_with(L"-65001")) return CP_UTF8;
        if (name.ends_with(L"-unsupported-control")) return 99999;
        Fail("unknown code page case");
    }

    std::wstring CodePageText(const UINT codePage)
    {
        switch (codePage)
        {
        case 437: return L"CP437 | caf\u00e9 | box: \u250c\u2500\u2510\u2514\u2500\u2518";
        case 850: return L"CP850 | caf\u00e9 | \u00d6l | Stra\u00dfe";
        case 852: return L"CP852 | HR: \u010d\u0107\u017e\u0161\u0111";
        case 932: return L"CP932 | \u65e5\u672c\u8a9e";
        case CP_UTF8: return L"CP65001 | HR: \u010d\u0107\u017e\u0161\u0111 | CJK: \u4e2d\u6587 | \U0001f600";
        default: Fail("unknown code page text");
        }
    }

    void RunCase(Result& result, const HANDLE output, const HANDLE input)
    {
        Clear(output);
        result.outputCodePage = GetConsoleOutputCP();

        if (result.name == L"write-console-w")
        {
            result.operation = L"WriteConsoleW Unicode and combining text";
            const std::wstring text{ L"WCW | HR: \u010d\u0107\u017e\u0161\u0111 | CJK: \u4e2d\u6587 | e\u0301 | \U0001f600" };
            WriteWide(output, text, result.apiResult);
            result.snapshots.push_back(Capture(output, L"final"));
        }
        else if (result.name == L"write-console-output-w")
        {
            result.operation = L"WriteConsoleOutputW positioned cells and legacy attributes";
            std::wstring text{ L"BUFFER-\u010d\u0107\u017e\u0161\u0111" };
            std::vector<CHAR_INFO> cells(text.size());
            for (size_t index = 0; index < text.size(); ++index)
            {
                cells[index].Char.UnicodeChar = text[index];
                cells[index].Attributes = static_cast<WORD>((index % 2 == 0 ? FOREGROUND_RED | FOREGROUND_INTENSITY : FOREGROUND_GREEN | FOREGROUND_BLUE) | BACKGROUND_BLUE);
            }
            SMALL_RECT target{ 5, 3, static_cast<SHORT>(5 + text.size() - 1), 3 };
            const COORD size{ static_cast<SHORT>(cells.size()), 1 };
            result.apiResult = WriteConsoleOutputW(output, cells.data(), size, {}, &target);
            result.apiError = result.apiResult ? ERROR_SUCCESS : GetLastError();
            result.snapshots.push_back(Capture(output, L"final"));
        }
        else if (result.name.starts_with(L"write-console-a-") || result.name.starts_with(L"write-file-"))
        {
            const bool consoleApi = result.name.starts_with(L"write-console-a-");
            const auto codePage = CodePageFromCase(result.name);
            result.operation = consoleApi ? L"WriteConsoleA code-page conversion" : L"WriteFile console code-page conversion";
            if (TrySetOutputCodePage(result, codePage))
            {
                result.sourceBytes = Encode(codePage, CodePageText(codePage));
                if (consoleApi)
                {
                    DWORD written{};
                    const auto ok = WriteConsoleA(output, result.sourceBytes.data(), static_cast<DWORD>(result.sourceBytes.size()), &written, nullptr);
                    result.apiError = ok ? ERROR_SUCCESS : GetLastError();
                    result.apiResult = written;
                }
                else
                {
                    DWORD written{};
                    result.apiResult = WriteFile(output, result.sourceBytes.data(), static_cast<DWORD>(result.sourceBytes.size()), &written, nullptr);
                    result.apiError = result.apiResult ? ERROR_SUCCESS : GetLastError();
                    result.apiResult = written;
                }
            }
            result.snapshots.push_back(Capture(output, L"final"));
        }
        else if (result.name == L"raw-vt-unprocessed" || result.name == L"raw-vt-processed")
        {
            const bool requestProcessing = result.name == L"raw-vt-processed";
            result.operation = requestProcessing ? L"WriteFile UTF-8 VT after requesting ENABLE_VIRTUAL_TERMINAL_PROCESSING" : L"WriteFile UTF-8 VT with ENABLE_VIRTUAL_TERMINAL_PROCESSING cleared";
            if (TrySetOutputCodePage(result, CP_UTF8))
            {
                Check(GetConsoleMode(output, &result.modeBefore), "GetConsoleMode failed");
                const DWORD requested = requestProcessing ? result.modeBefore | 0x0004u : result.modeBefore & ~0x0004u;
                const auto modeResult = SetConsoleMode(output, requested);
                result.apiError = modeResult ? ERROR_SUCCESS : GetLastError();
                GetConsoleMode(output, &result.modeAfter);
                const std::string bytes = "RAW-A\x1b[38;2;12;34;56mCOLOR\x1b[0m\x1b[3;10HPOS";
                result.sourceBytes.assign(bytes.begin(), bytes.end());
                DWORD written{};
                Check(WriteFile(output, result.sourceBytes.data(), static_cast<DWORD>(result.sourceBytes.size()), &written, nullptr), "raw VT WriteFile failed");
                result.apiResult = written;
            }
            result.snapshots.push_back(Capture(output, L"final"));
        }
        else if (result.name == L"fast-rewrite")
        {
            result.operation = L"Two hundred immediate carriage-return WriteConsoleW rewrites";
            DWORD written{};
            for (unsigned index = 0; index < 200; ++index)
            {
                wchar_t update[40]{};
                swprintf_s(update, L"rewrite %03u / 199\r", index);
                WriteWide(output, update, written);
            }
            WriteWide(output, L"rewrite 199 / 199", written);
            result.apiResult = 201;
            result.snapshots.push_back(Capture(output, L"final"));
        }
        else if (result.name == L"alternate-buffer")
        {
            result.operation = L"CreateConsoleScreenBuffer, activate, write, then restore primary buffer";
            DWORD written{};
            WriteWide(output, L"PRIMARY-BEFORE", written);
            const auto alternate = CreateConsoleScreenBuffer(GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, CONSOLE_TEXTMODE_BUFFER, nullptr);
            if (alternate == INVALID_HANDLE_VALUE)
            {
                Fail("CreateConsoleScreenBuffer failed");
            }
            try
            {
                Check(SetConsoleActiveScreenBuffer(alternate), "SetConsoleActiveScreenBuffer alternate failed");
                Clear(alternate);
                WriteWide(alternate, L"ALTERNATE-ACTIVE", written);
                Sleep(80);
                result.snapshots.push_back(Capture(alternate, L"alternate"));
                Check(SetConsoleActiveScreenBuffer(output), "SetConsoleActiveScreenBuffer primary failed");
                Sleep(80);
                result.snapshots.push_back(Capture(output, L"final"));
            }
            catch (...)
            {
                SetConsoleActiveScreenBuffer(output);
                CloseHandle(alternate);
                throw;
            }
            CloseHandle(alternate);
            result.apiResult = 1;
        }
        else if (result.name == L"resize")
        {
            result.operation = L"Observe initial console dimensions, then wait for WinPTY resize and input";
            result.snapshots.push_back(Capture(output, L"initial"));
            DWORD written{};
            WriteWide(output, L"RESIZE_READY", written);
            char signal{};
            DWORD read{};
            Check(ReadFile(input, &signal, 1, &read, nullptr), "resize signal ReadFile failed");
            result.apiResult = read;
            CONSOLE_SCREEN_BUFFER_INFO info{};
            Check(GetConsoleScreenBufferInfo(output, &info), "resize GetConsoleScreenBufferInfo failed");
            wchar_t dimensions[80]{};
            swprintf_s(dimensions, L"\r\nRESIZE_AFTER %dx%d", info.srWindow.Right - info.srWindow.Left + 1, info.srWindow.Bottom - info.srWindow.Top + 1);
            WriteWide(output, dimensions, written);
            result.snapshots.push_back(Capture(output, L"final"));
        }
        else if (result.name == L"exit-drain")
        {
            result.operation = L"Five hundred immediate WriteConsoleW lines followed by exit";
            DWORD written{};
            for (unsigned index = 0; index < 500; ++index)
            {
                wchar_t line[96]{};
                swprintf_s(line, L"drain-%03u ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\r\n", index);
                WriteWide(output, line, written);
            }
            result.apiResult = 500;
            result.snapshots.push_back(Capture(output, L"final"));
        }
        else
        {
            Fail("unknown fixture case");
        }

        result.apiError = result.apiError == ERROR_SUCCESS ? ERROR_SUCCESS : result.apiError;
        Sleep(80);
    }

    std::string Serialize(const Result& result)
    {
        std::string json = "{\n  \"schema\": \"vt7-p01-child-v2\",\n  \"case\": " + JsonString(result.name) +
            ",\n  \"operation\": " + JsonString(result.operation) +
            ",\n  \"requestedOutputCodePage\": " + std::to_string(result.requestedOutputCodePage) +
            ",\n  \"requestedCodePageValid\": " + (result.requestedCodePageValid ? "true" : "false") +
            ",\n  \"outputCodePageSet\": " + (result.outputCodePageSet ? "true" : "false") +
            ",\n  \"outputCodePageSetError\": " + std::to_string(result.outputCodePageSetError) +
            ",\n  \"outputCodePage\": " + std::to_string(result.outputCodePage) +
            ",\n  \"apiResult\": " + std::to_string(result.apiResult) +
            ",\n  \"apiError\": " + std::to_string(result.apiError) +
            ",\n  \"modeBefore\": " + std::to_string(result.modeBefore) +
            ",\n  \"modeAfter\": " + std::to_string(result.modeAfter) +
            ",\n  \"sourceBytesHex\": \"" + HexBytes(result.sourceBytes) + "\",\n  \"snapshots\": [\n";

        for (size_t snapshotIndex = 0; snapshotIndex < result.snapshots.size(); ++snapshotIndex)
        {
            const auto& snapshot = result.snapshots[snapshotIndex];
            json += "    {\"label\": " + JsonString(snapshot.label) +
                ", \"columns\": " + std::to_string(snapshot.columns) +
                ", \"rows\": " + std::to_string(snapshot.rows) +
                ", \"cursorX\": " + std::to_string(snapshot.cursorX) +
                ", \"cursorY\": " + std::to_string(snapshot.cursorY) +
                ", \"text\": [";
            for (SHORT row = 0; row < snapshot.rows; ++row)
            {
                std::wstring text;
                text.reserve(snapshot.columns);
                for (SHORT column = 0; column < snapshot.columns; ++column)
                {
                    text.push_back(snapshot.cells[static_cast<size_t>(row) * snapshot.columns + column].Char.UnicodeChar);
                }
                if (row != 0) json += ',';
                json += "\n      " + JsonString(text);
            }
            json += "\n    ], \"attributesHex\": [";
            for (SHORT row = 0; row < snapshot.rows; ++row)
            {
                std::vector<unsigned char> attributes;
                attributes.reserve(static_cast<size_t>(snapshot.columns) * 2);
                for (SHORT column = 0; column < snapshot.columns; ++column)
                {
                    const auto value = snapshot.cells[static_cast<size_t>(row) * snapshot.columns + column].Attributes;
                    attributes.push_back(static_cast<unsigned char>(value & 0xff));
                    attributes.push_back(static_cast<unsigned char>(value >> 8));
                }
                if (row != 0) json += ',';
                json += "\n      \"" + HexBytes(attributes) + "\"";
            }
            json += "\n    ]}";
            if (snapshotIndex + 1 != result.snapshots.size()) json += ',';
            json += '\n';
        }
        json += "  ]\n}\n";
        return json;
    }

    void Save(const std::wstring& path, const std::string_view bytes)
    {
        const auto file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file == INVALID_HANDLE_VALUE)
        {
            Fail("report CreateFileW failed");
        }
        DWORD written{};
        const auto ok = WriteFile(file, bytes.data(), static_cast<DWORD>(bytes.size()), &written, nullptr);
        CloseHandle(file);
        if (!ok || written != bytes.size())
        {
            Fail("report WriteFile failed");
        }
    }
}

int wmain(int argc, wchar_t** argv)
{
    try
    {
        std::wstring name;
        std::wstring reportPath;
        for (int index = 1; index + 1 < argc; index += 2)
        {
            if (std::wstring_view{ argv[index] } == L"--case") name = argv[index + 1];
            else if (std::wstring_view{ argv[index] } == L"--report") reportPath = argv[index + 1];
            else Fail("invalid fixture argument");
        }
        if (name.empty() || reportPath.empty())
        {
            Fail("usage: VT7.WinPtyFixture.exe --case NAME --report PATH");
        }

        const auto output = GetStdHandle(STD_OUTPUT_HANDLE);
        const auto input = GetStdHandle(STD_INPUT_HANDLE);
        if (!output || output == INVALID_HANDLE_VALUE || !input || input == INVALID_HANDLE_VALUE)
        {
            Fail("console standard handles unavailable");
        }

        Result result;
        result.name = name;
        RunCase(result, output, input);
        Save(reportPath, Serialize(result));
        return 0;
    }
    catch (const std::exception& error)
    {
        std::fprintf(stderr, "VT7 P01 fixture failed: %s (Win32 %lu)\n", error.what(), GetLastError());
        return 2;
    }
}
