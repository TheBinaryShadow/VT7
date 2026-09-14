// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.

#include <LibraryIncludes.h>
#include <winpty.h>

#include "../VT7.Native/utf8_terminal_stream.hpp"
#include "../../cascadia/TerminalCore/Terminal.hpp"
#include "../../renderer/base/renderer.hpp"

#include <array>
#include <cstdint>
#include <cstdio>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace
{
    constexpr DWORD InitialColumns = 80;
    constexpr DWORD InitialRows = 24;
    constexpr DWORD ProbeTimeoutMilliseconds = 30000;

    class Handle final
    {
    public:
        Handle() = default;
        explicit Handle(HANDLE value) noexcept : _value{ value } {}
        ~Handle() { reset(); }
        Handle(const Handle&) = delete;
        Handle& operator=(const Handle&) = delete;
        Handle(Handle&& other) noexcept : _value{ other.release() } {}
        Handle& operator=(Handle&& other) noexcept
        {
            if (this != &other) reset(other.release());
            return *this;
        }
        HANDLE get() const noexcept { return _value; }
        explicit operator bool() const noexcept { return _value && _value != INVALID_HANDLE_VALUE; }
        HANDLE release() noexcept { const auto value = _value; _value = nullptr; return value; }
        void reset(HANDLE value = nullptr) noexcept
        {
            if (_value && _value != INVALID_HANDLE_VALUE) CloseHandle(_value);
            _value = value;
        }
    private:
        HANDLE _value{};
    };

    class WinPtyError final
    {
    public:
        ~WinPtyError() { if (_value) winpty_error_free(_value); }
        winpty_error_ptr_t* put() noexcept
        {
            if (_value) winpty_error_free(_value);
            _value = nullptr;
            return &_value;
        }
        std::wstring message() const
        {
            return _value && winpty_error_msg(_value) ? winpty_error_msg(_value) : L"unknown WinPTY error";
        }
    private:
        winpty_error_ptr_t _value{};
    };

    class WinPtyConfig final
    {
    public:
        explicit WinPtyConfig(winpty_config_t* value) noexcept : _value{ value } {}
        ~WinPtyConfig() { if (_value) winpty_config_free(_value); }
        winpty_config_t* get() const noexcept { return _value; }
    private:
        winpty_config_t* _value{};
    };

    class WinPtySpawnConfig final
    {
    public:
        explicit WinPtySpawnConfig(winpty_spawn_config_t* value) noexcept : _value{ value } {}
        ~WinPtySpawnConfig() { if (_value) winpty_spawn_config_free(_value); }
        winpty_spawn_config_t* get() const noexcept { return _value; }
    private:
        winpty_spawn_config_t* _value{};
    };

    class WinPty final
    {
    public:
        explicit WinPty(winpty_t* value) noexcept : _value{ value } {}
        ~WinPty() { if (_value) winpty_free(_value); }
        winpty_t* get() const noexcept { return _value; }
    private:
        winpty_t* _value{};
    };

    struct CoreFixture
    {
        Microsoft::Terminal::Core::Terminal core;
        Microsoft::Console::Render::Renderer renderer;

        CoreFixture() : renderer([this]() -> auto& {
            const auto guard = core.LockForWriting();
            return core.GetRenderSettings();
        }(), &core)
        {
            const auto guard = core.LockForWriting();
            core.Create({ InitialColumns, InitialRows }, 1000, renderer);
        }
    };

    [[noreturn]] void Fail(const std::string& message)
    {
        throw std::runtime_error(message);
    }

    std::string NarrowAscii(const std::wstring_view text)
    {
        std::string value;
        value.reserve(text.size());
        for (const auto character : text)
        {
            value.push_back(character >= 0x20 && character <= 0x7e ? static_cast<char>(character) : '?');
        }
        return value;
    }

    std::string JsonString(const std::wstring_view text)
    {
        static constexpr char digits[]{ "0123456789abcdef" };
        std::string value{ "\"" };
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

    std::string HexColor(const COLORREF color)
    {
        static constexpr char digits[]{ "0123456789abcdef" };
        const unsigned char bytes[]{ GetRValue(color), GetGValue(color), GetBValue(color) };
        std::string value;
        value.reserve(6);
        for (const auto byte : bytes)
        {
            value.push_back(digits[byte >> 4]);
            value.push_back(digits[byte & 0xf]);
        }
        return value;
    }

    std::string HexWordLittleEndian(const WORD value)
    {
        static constexpr char digits[]{ "0123456789abcdef" };
        const unsigned char bytes[]{ static_cast<unsigned char>(value & 0xff), static_cast<unsigned char>(value >> 8) };
        std::string result;
        result.reserve(4);
        for (const auto byte : bytes)
        {
            result.push_back(digits[byte >> 4]);
            result.push_back(digits[byte & 0xf]);
        }
        return result;
    }

    std::wstring Quote(const std::wstring_view value)
    {
        std::wstring quoted{ L"\"" };
        size_t slashes{};
        for (const auto character : value)
        {
            if (character == L'\\')
            {
                ++slashes;
                continue;
            }
            if (character == L'"')
            {
                quoted.append(slashes * 2 + 1, L'\\');
                quoted.push_back(L'"');
            }
            else
            {
                quoted.append(slashes, L'\\');
                quoted.push_back(character);
            }
            slashes = 0;
        }
        quoted.append(slashes * 2, L'\\');
        quoted.push_back(L'"');
        return quoted;
    }

    std::wstring JoinPath(const std::wstring_view directory, const std::wstring_view name)
    {
        std::wstring result{ directory };
        if (!result.empty() && result.back() != L'\\') result.push_back(L'\\');
        result.append(name);
        return result;
    }

    void Save(const std::wstring& path, const void* data, const size_t size)
    {
        Handle file{ CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr) };
        if (!file) Fail("CreateFileW failed for output artifact");
        const auto bytes = static_cast<const unsigned char*>(data);
        size_t offset{};
        while (offset < size)
        {
            DWORD written{};
            const auto portion = static_cast<DWORD>(std::min<size_t>(size - offset, 1024 * 1024));
            if (!WriteFile(file.get(), bytes + offset, portion, &written, nullptr) || written == 0)
            {
                Fail("WriteFile failed for output artifact");
            }
            offset += written;
        }
    }

    std::string SerializeCore(CoreFixture& fixture, const VT7::Utf8TerminalStreamSnapshot& stream)
    {
        const auto guard = fixture.core.LockForWriting();
        const auto viewport = fixture.core.GetViewport();
        const auto cursor = fixture.core.GetTextBuffer().GetCursor().GetPosition();
        std::string json = "{\"columns\": " + std::to_string(viewport.Width()) +
            ", \"rows\": " + std::to_string(viewport.Height()) +
            ", \"cursorX\": " + std::to_string(cursor.x) +
            ", \"cursorY\": " + std::to_string(cursor.y - viewport.Top()) +
            ", \"text\": [";

        for (til::CoordType rowIndex = 0; rowIndex < viewport.Height(); ++rowIndex)
        {
            const auto& row = fixture.core.GetTextBuffer().GetRowByOffset(viewport.Top() + rowIndex);
            if (rowIndex != 0) json.push_back(',');
            json += "\n      " + JsonString(row.GetText());
        }
        json += "\n    ], \"colorsRgb\": [";
        for (til::CoordType rowIndex = 0; rowIndex < viewport.Height(); ++rowIndex)
        {
            const auto& row = fixture.core.GetTextBuffer().GetRowByOffset(viewport.Top() + rowIndex);
            if (rowIndex != 0) json.push_back(',');
            json += "\n      \"";
            for (til::CoordType column = 0; column < viewport.Width(); ++column)
            {
                const auto colors = fixture.core.GetAttributeColors(row.GetAttrByColumn(column));
                json += HexColor(colors.first);
                json += HexColor(colors.second);
            }
            json.push_back('"');
        }
        json += "\n    ], \"legacyAttributesHex\": [";
        for (til::CoordType rowIndex = 0; rowIndex < viewport.Height(); ++rowIndex)
        {
            const auto& row = fixture.core.GetTextBuffer().GetRowByOffset(viewport.Top() + rowIndex);
            if (rowIndex != 0) json.push_back(',');
            json += "\n      \"";
            for (til::CoordType column = 0; column < viewport.Width(); ++column)
            {
                json += HexWordLittleEndian(row.GetAttrByColumn(column).GetLegacyAttributes());
            }
            json.push_back('"');
        }
        json += "\n    ], \"stream\": {\"bytes\": " + std::to_string(stream.bytes) +
            ", \"utf16Units\": " + std::to_string(stream.utf16Units) +
            ", \"writes\": " + std::to_string(stream.writes) +
            ", \"pendingBytes\": " + std::to_string(stream.pendingBytes) +
            ", \"ended\": " + std::string(stream.ended ? "true" : "false") +
            ", \"lastError\": " + std::to_string(static_cast<uint32_t>(stream.lastError)) + "}}";
        return json;
    }

    std::vector<unsigned char> DrainOutput(const HANDLE output, CoreFixture& fixture, VT7::Utf8TerminalStream& stream)
    {
        Handle event{ CreateEventW(nullptr, TRUE, FALSE, nullptr) };
        if (!event) Fail("CreateEventW failed");
        const auto deadline = GetTickCount64() + ProbeTimeoutMilliseconds;
        std::vector<unsigned char> captured;
        std::array<unsigned char, 4096> buffer{};

        for (;;)
        {
            ResetEvent(event.get());
            OVERLAPPED operation{};
            operation.hEvent = event.get();
            DWORD read{};
            auto completed = ReadFile(output, buffer.data(), static_cast<DWORD>(buffer.size()), &read, &operation);
            if (!completed)
            {
                const auto error = GetLastError();
                if (error == ERROR_BROKEN_PIPE)
                {
                    break;
                }
                if (error != ERROR_IO_PENDING)
                {
                    Fail("WinPTY output ReadFile failed: " + std::to_string(error));
                }
                const auto now = GetTickCount64();
                if (now >= deadline || WaitForSingleObject(event.get(), static_cast<DWORD>(deadline - now)) != WAIT_OBJECT_0)
                {
                    CancelIo(output);
                    Fail("WinPTY output drain timed out");
                }
                if (!GetOverlappedResult(output, &operation, &read, FALSE))
                {
                    const auto result = GetLastError();
                    if (result == ERROR_BROKEN_PIPE)
                    {
                        break;
                    }
                    Fail("WinPTY output overlapped completion failed: " + std::to_string(result));
                }
            }

            if (read == 0)
            {
                break;
            }
            captured.insert(captured.end(), buffer.begin(), buffer.begin() + read);
            const std::string_view bytes{ reinterpret_cast<const char*>(buffer.data()), read };
            const auto conversion = stream.Write(bytes, [&](const auto text) {
                const auto guard = fixture.core.LockForWriting();
                fixture.core.Write(text);
            });
            if (FAILED(conversion))
            {
                Fail("incremental UTF-8 conversion failed: " + std::to_string(static_cast<uint32_t>(conversion)));
            }
        }
        return captured;
    }
}

int wmain(int argc, wchar_t** argv)
{
    try
    {
        std::wstring caseName;
        std::wstring fixturePath;
        std::wstring outputDirectory;
        for (int index = 1; index + 1 < argc; index += 2)
        {
            if (std::wstring_view{ argv[index] } == L"--case") caseName = argv[index + 1];
            else if (std::wstring_view{ argv[index] } == L"--fixture") fixturePath = argv[index + 1];
            else if (std::wstring_view{ argv[index] } == L"--output") outputDirectory = argv[index + 1];
            else Fail("invalid probe argument");
        }
        if (caseName.empty() || fixturePath.empty() || outputDirectory.empty())
        {
            Fail("usage: VT7.WinPtyProbe.exe --case NAME --fixture PATH --output DIRECTORY");
        }

        const auto childReportPath = JoinPath(outputDirectory, L"child.json");
        const auto rawPath = JoinPath(outputDirectory, L"backend.bin");
        const auto resultPath = JoinPath(outputDirectory, L"probe.json");

        WinPtyError error;
        WinPtyConfig config{ winpty_config_new(0, error.put()) };
        if (!config.get()) Fail("winpty_config_new: " + NarrowAscii(error.message()));
        winpty_config_set_initial_size(config.get(), InitialColumns, InitialRows);
        winpty_config_set_mouse_mode(config.get(), WINPTY_MOUSE_MODE_NONE);
        winpty_config_set_agent_timeout(config.get(), 10000);

        WinPty pty{ winpty_open(config.get(), error.put()) };
        if (!pty.get()) Fail("winpty_open: " + NarrowAscii(error.message()));

        Handle output{ CreateFileW(winpty_conout_name(pty.get()), GENERIC_READ, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr) };
        if (!output) Fail("opening WinPTY output pipe failed: " + std::to_string(GetLastError()));
        Handle input{ CreateFileW(winpty_conin_name(pty.get()), GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr) };
        if (!input) Fail("opening WinPTY input pipe failed: " + std::to_string(GetLastError()));

        auto commandLine = Quote(fixturePath) + L" --case " + Quote(caseName) + L" --report " + Quote(childReportPath);
        WinPtySpawnConfig spawnConfig{ winpty_spawn_config_new(
            WINPTY_SPAWN_FLAG_AUTO_SHUTDOWN | WINPTY_SPAWN_FLAG_EXIT_AFTER_SHUTDOWN,
            fixturePath.c_str(), commandLine.c_str(), nullptr, nullptr, error.put()) };
        if (!spawnConfig.get()) Fail("winpty_spawn_config_new: " + NarrowAscii(error.message()));

        HANDLE childValue{};
        HANDLE threadValue{};
        DWORD createProcessError{};
        if (!winpty_spawn(pty.get(), spawnConfig.get(), &childValue, &threadValue, &createProcessError, error.put()))
        {
            Fail("winpty_spawn: " + NarrowAscii(error.message()) + " CreateProcess=" + std::to_string(createProcessError));
        }
        Handle child{ childValue };
        Handle thread{ threadValue };

        CoreFixture core;
        VT7::Utf8TerminalStream stream;
        stream.Begin();

        if (caseName == L"resize")
        {
            Sleep(200);
            if (!winpty_set_size(pty.get(), 100, 30, error.put()))
            {
                Fail("winpty_set_size: " + NarrowAscii(error.message()));
            }
            {
                const auto guard = core.core.LockForWriting();
                THROW_IF_FAILED(core.core.UserResize({ 100, 30 }));
            }
            const char signal[]{ 'R', '\r', '\n' };
            DWORD written{};
            if (!WriteFile(input.get(), signal, static_cast<DWORD>(sizeof(signal)), &written, nullptr) || written != sizeof(signal))
            {
                Fail("writing resize fixture signal failed");
            }
        }

        auto captured = DrainOutput(output.get(), core, stream);
        const auto streamEnd = stream.End();
        if (FAILED(streamEnd))
        {
            Fail("WinPTY output ended with incomplete UTF-8");
        }

        if (WaitForSingleObject(child.get(), 2000) != WAIT_OBJECT_0)
        {
            Fail("child did not signal after WinPTY output EOF");
        }
        DWORD childExit{};
        if (!GetExitCodeProcess(child.get(), &childExit)) Fail("GetExitCodeProcess child failed");

        const auto agent = winpty_agent_process(pty.get());
        const auto agentWait = WaitForSingleObject(agent, 2000);
        DWORD agentExit = STILL_ACTIVE;
        if (agentWait == WAIT_OBJECT_0) GetExitCodeProcess(agent, &agentExit);

        Save(rawPath, captured.data(), captured.size());
        const auto coreJson = SerializeCore(core, stream.Snapshot());
        std::string result = "{\n  \"schema\": \"vt7-p01-probe-v1\",\n  \"case\": " + JsonString(caseName) +
            ",\n  \"winptyVersion\": \"0.4.3\",\n  \"winptyCommit\": \"3e1ab962d5262dd76159870c6dc0724927ca6a9d\",\n  \"initialColumns\": 80,\n  \"initialRows\": 24,\n  \"backendByteCount\": " + std::to_string(captured.size()) +
            ",\n  \"childExitCode\": " + std::to_string(childExit) +
            ",\n  \"agentWaitResult\": " + std::to_string(agentWait) +
            ",\n  \"agentExitCode\": " + std::to_string(agentExit) +
            ",\n  \"core\": " + coreJson + "\n}\n";
        Save(resultPath, result.data(), result.size());

        std::printf("VT7 P01 %s: child=%lu bytes=%zu decoder-writes=%u\n",
            NarrowAscii(caseName).c_str(), childExit, captured.size(), stream.Snapshot().writes);
        return childExit == 0 ? 0 : 3;
    }
    catch (const std::exception& error)
    {
        std::fprintf(stderr, "VT7 P01 probe failed: %s (Win32 %lu)\n", error.what(), GetLastError());
        return 2;
    }
    catch (...)
    {
        std::fprintf(stderr, "VT7 P01 probe failed with a native exception (Win32 %lu)\n", GetLastError());
        return 2;
    }
}
