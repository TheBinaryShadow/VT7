// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.

#include <LibraryIncludes.h>
#include "../../terminal/input/terminalInput.hpp"

#include <array>
#include <atomic>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

using Microsoft::Console::VirtualTerminal::TerminalInput;

namespace
{
    constexpr wchar_t CroatianKlid[] = L"0000041A";
    HKL requestedLayout{};

    struct Translation
    {
        int result{};
        std::wstring text;
    };

    struct Mapping
    {
        UINT virtualKey{};
        UINT scanCode{};
        std::string modifier;
        Translation translation;
    };

    struct SequenceResult
    {
        Translation dead;
        Translation following;
    };

    std::string JsonEscape(const std::wstring_view value)
    {
        static constexpr char digits[]{ "0123456789abcdef" };
        std::string result{ "\"" };
        for (const wchar_t character : value)
        {
            const auto unit = static_cast<uint16_t>(character);
            switch (unit)
            {
            case L'\"': result += "\\\""; break;
            case L'\\': result += "\\\\"; break;
            case L'\b': result += "\\b"; break;
            case L'\f': result += "\\f"; break;
            case L'\n': result += "\\n"; break;
            case L'\r': result += "\\r"; break;
            case L'\t': result += "\\t"; break;
            default:
                if (unit >= 0x20 && unit <= 0x7e)
                {
                    result.push_back(static_cast<char>(unit));
                }
                else
                {
                    result += "\\u";
                    result.push_back(digits[(unit >> 12) & 0xf]);
                    result.push_back(digits[(unit >> 8) & 0xf]);
                    result.push_back(digits[(unit >> 4) & 0xf]);
                    result.push_back(digits[unit & 0xf]);
                }
                break;
            }
        }
        result.push_back('"');
        return result;
    }

    std::string JsonEscape(const std::string_view value)
    {
        std::wstring wide;
        wide.reserve(value.size());
        for (const unsigned char character : value) wide.push_back(character);
        return JsonEscape(wide);
    }

    std::string HexUtf16(const std::wstring_view value)
    {
        std::ostringstream stream;
        stream << std::hex << std::setfill('0');
        for (size_t index = 0; index < value.size(); ++index)
        {
            if (index) stream << ' ';
            stream << std::setw(4) << static_cast<uint16_t>(value[index]);
        }
        return stream.str();
    }

    std::string HexUtf8(const std::wstring_view value)
    {
        if (value.empty()) return {};
        const auto length = WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
        if (length <= 0) throw std::runtime_error("WideCharToMultiByte size failed");
        std::string bytes(static_cast<size_t>(length), '\0');
        if (!WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), bytes.data(), length, nullptr, nullptr))
            throw std::runtime_error("WideCharToMultiByte failed");
        std::ostringstream stream;
        stream << std::hex << std::setfill('0');
        for (size_t index = 0; index < bytes.size(); ++index)
        {
            if (index) stream << ' ';
            stream << std::setw(2) << static_cast<unsigned>(static_cast<unsigned char>(bytes[index]));
        }
        return stream.str();
    }

    std::array<BYTE, 256> KeyState(const std::string_view modifier)
    {
        std::array<BYTE, 256> state{};
        if (modifier == "shift")
        {
            state[VK_SHIFT] = state[VK_LSHIFT] = 0x80;
        }
        else if (modifier == "altgr")
        {
            state[VK_CONTROL] = state[VK_LCONTROL] = 0x80;
            state[VK_MENU] = state[VK_RMENU] = 0x80;
        }
        return state;
    }

    Translation Translate(const UINT virtualKey, const UINT scanCode, const std::string_view modifier, const UINT flags, const HKL layout)
    {
        auto state = KeyState(modifier);
        state[virtualKey & 0xff] = 0x80;
        std::array<wchar_t, 16> buffer{};
        const auto result = ToUnicodeEx(virtualKey, scanCode, state.data(), buffer.data(), static_cast<int>(buffer.size()), flags, layout);
        const auto length = result < 0 ? 1 : std::min<int>(result, static_cast<int>(buffer.size()));
        return { result, length > 0 ? std::wstring(buffer.data(), static_cast<size_t>(length)) : std::wstring{} };
    }

    void ClearDeadState(const HKL layout)
    {
        for (int attempt = 0; attempt < 8; ++attempt)
        {
            const auto value = Translate(VK_SPACE, MapVirtualKeyExW(VK_SPACE, MAPVK_VK_TO_VSC, layout), "none", 1, layout);
            if (value.result >= 0) break;
        }
    }

    std::vector<Mapping> EnumerateMappings(const HKL layout)
    {
        std::vector<Mapping> mappings;
        for (const auto modifier : { "none", "shift", "altgr" })
        {
            for (UINT virtualKey = 8; virtualKey < 255; ++virtualKey)
            {
                ClearDeadState(layout);
                const auto scanCode = MapVirtualKeyExW(virtualKey, MAPVK_VK_TO_VSC, layout);
                const auto translation = Translate(virtualKey, scanCode, modifier, 1, layout);
                if (translation.result != 0)
                {
                    mappings.push_back({ virtualKey, scanCode, modifier, translation });
                }
                ClearDeadState(layout);
            }
        }
        return mappings;
    }

    SequenceResult RunDeadSequence(const Mapping& dead, const UINT flags, const HKL layout)
    {
        SequenceResult result;
        std::thread worker([&] {
            ActivateKeyboardLayout(layout, 0);
            ClearDeadState(layout);
            result.dead = Translate(dead.virtualKey, dead.scanCode, dead.modifier, flags, layout);
            result.following = Translate('A', MapVirtualKeyExW('A', MAPVK_VK_TO_VSC, layout), "none", flags, layout);
            ClearDeadState(layout);
        });
        worker.join();
        return result;
    }

    INPUT_RECORD KeyEvent(const WORD virtualKey, const WORD scanCode, const wchar_t character, const DWORD states, const bool down = true)
    {
        INPUT_RECORD event{};
        event.EventType = KEY_EVENT;
        event.Event.KeyEvent.bKeyDown = down;
        event.Event.KeyEvent.wRepeatCount = 1;
        event.Event.KeyEvent.wVirtualKeyCode = virtualKey;
        event.Event.KeyEvent.wVirtualScanCode = scanCode;
        event.Event.KeyEvent.uChar.UnicodeChar = character;
        event.Event.KeyEvent.dwControlKeyState = states;
        return event;
    }

    struct EncoderCase
    {
        std::string name;
        TerminalInput::OutputType output;
    };

    std::vector<EncoderCase> RunEncoderCases(const std::vector<Mapping>& mappings)
    {
        std::vector<EncoderCase> cases;
        auto invoke = [&](const std::string& name, TerminalInput& input, const INPUT_RECORD& event) {
            cases.push_back({ name, input.HandleKey(event) });
        };

        {
            TerminalInput input;
            invoke("committed-croatian-c", input, KeyEvent(0, 0, L'\u010d', 0));
        }
        {
            TerminalInput input;
            invoke("ctrl-c-committed", input, KeyEvent('C', static_cast<WORD>(MapVirtualKeyExW('C', MAPVK_VK_TO_VSC, requestedLayout)), 3, LEFT_CTRL_PRESSED));
            invoke("ctrl-c-key-up", input, KeyEvent('C', static_cast<WORD>(MapVirtualKeyExW('C', MAPVK_VK_TO_VSC, requestedLayout)), 0, 0, false));
        }
        {
            TerminalInput input;
            invoke("cursor-normal-up", input, KeyEvent(VK_UP, static_cast<WORD>(MapVirtualKeyExW(VK_UP, MAPVK_VK_TO_VSC, requestedLayout)), 0, ENHANCED_KEY));
            input.SetInputMode(TerminalInput::Mode::CursorKey, true);
            invoke("cursor-application-up", input, KeyEvent(VK_UP, static_cast<WORD>(MapVirtualKeyExW(VK_UP, MAPVK_VK_TO_VSC, requestedLayout)), 0, ENHANCED_KEY));
        }
        {
            TerminalInput input;
            input.SetInputMode(TerminalInput::Mode::FocusEvent, true);
            cases.push_back({ "focus-in", input.HandleFocus(true) });
            cases.push_back({ "focus-out", input.HandleFocus(false) });
        }
        {
            TerminalInput input;
            input.SetInputMode(TerminalInput::Mode::AutoRepeat, false);
            const auto a = KeyEvent('A', static_cast<WORD>(MapVirtualKeyExW('A', MAPVK_VK_TO_VSC, requestedLayout)), L'a', 0);
            invoke("repeat-disabled-first", input, a);
            invoke("repeat-disabled-second", input, a);
        }

        size_t altGrIndex{};
        for (const auto& mapping : mappings)
        {
            if (mapping.modifier != "altgr" || mapping.translation.result != 1 || mapping.translation.text.empty()) continue;
            const auto unit = mapping.translation.text[0];
            if (unit <= 0x20 || unit == 0x7f) continue;
            TerminalInput input;
            const auto modifiers = LEFT_CTRL_PRESSED | RIGHT_ALT_PRESSED;
            invoke("altgr-" + std::to_string(altGrIndex) + "-modifier", input, KeyEvent(VK_MENU, static_cast<WORD>(MapVirtualKeyExW(VK_MENU, MAPVK_VK_TO_VSC, requestedLayout)), 0, modifiers | ENHANCED_KEY));
            invoke("altgr-" + std::to_string(altGrIndex) + "-committed", input, KeyEvent(static_cast<WORD>(mapping.virtualKey), static_cast<WORD>(mapping.scanCode), unit, modifiers));
            ++altGrIndex;
            if (altGrIndex == 8) break;
        }
        return cases;
    }

    void WriteTranslation(std::ostream& stream, const Translation& translation)
    {
        stream << "{\"result\":" << translation.result
               << ",\"text\":" << JsonEscape(translation.text)
               << ",\"utf16Hex\":" << JsonEscape(HexUtf16(translation.text))
               << ",\"utf8Hex\":" << JsonEscape(HexUtf8(translation.text)) << '}';
    }

    std::wstring ArgumentValue(const int argc, wchar_t** argv, const std::wstring_view name)
    {
        for (int index = 1; index + 1 < argc; ++index)
        {
            if (argv[index] == name) return argv[index + 1];
        }
        return {};
    }
}

extern "C" HKL TestHook_TerminalInput_KeyboardLayout()
{
    return requestedLayout;
}

int wmain(const int argc, wchar_t** argv)
try
{
    const auto outputPath = ArgumentValue(argc, argv, L"--output");
    if (outputPath.empty()) throw std::runtime_error("Usage: VT7.InputProbe.exe --output <json-path>");

    requestedLayout = LoadKeyboardLayoutW(CroatianKlid, KLF_NOTELLSHELL);
    if (!requestedLayout) throw std::runtime_error("Croatian keyboard layout 0000041A could not be loaded");

    const auto mappings = EnumerateMappings(requestedLayout);
    const auto dead = std::find_if(mappings.begin(), mappings.end(), [](const Mapping& mapping) { return mapping.translation.result < 0; });
    const auto flags1 = dead != mappings.end() ? RunDeadSequence(*dead, 1, requestedLayout) : SequenceResult{};
    const auto flags5 = dead != mappings.end() ? RunDeadSequence(*dead, 5, requestedLayout) : SequenceResult{};
    const auto encoderCases = RunEncoderCases(mappings);

    size_t altGrMappings{};
    for (const auto& mapping : mappings) if (mapping.modifier == "altgr") ++altGrMappings;

    std::ofstream stream(outputPath, std::ios::binary | std::ios::trunc);
    if (!stream) throw std::runtime_error("Unable to create native probe JSON");
    stream << "{\n"
           << "  \"schema\":\"vt7-i01-native-v1\",\n"
           << "  \"requestedKlid\":\"0000041A\",\n"
           << "  \"layoutHandle\":" << JsonEscape([&] { std::wostringstream value; value << L"0x" << std::hex << reinterpret_cast<uintptr_t>(requestedLayout); return value.str(); }()) << ",\n"
           << "  \"mappingCount\":" << mappings.size() << ",\n"
           << "  \"altGrMappingCount\":" << altGrMappings << ",\n"
           << "  \"deadKeyFound\":" << (dead != mappings.end() ? "true" : "false") << ",\n"
           << "  \"deadKey\":";
    if (dead == mappings.end())
    {
        stream << "null,\n";
    }
    else
    {
        stream << "{\"virtualKey\":" << dead->virtualKey << ",\"scanCode\":" << dead->scanCode
               << ",\"modifier\":" << JsonEscape(dead->modifier) << ",\"translation\":";
        WriteTranslation(stream, dead->translation);
        stream << "},\n";
    }
    stream << "  \"deadStateComparison\":{\n    \"flags1\":{\"dead\":";
    WriteTranslation(stream, flags1.dead);
    stream << ",\"following\":";
    WriteTranslation(stream, flags1.following);
    stream << "},\n    \"flags5\":{\"dead\":";
    WriteTranslation(stream, flags5.dead);
    stream << ",\"following\":";
    WriteTranslation(stream, flags5.following);
    stream << "}\n  },\n  \"mappings\":[";
    for (size_t index = 0; index < mappings.size(); ++index)
    {
        const auto& mapping = mappings[index];
        if (index) stream << ',';
        stream << "\n    {\"virtualKey\":" << mapping.virtualKey << ",\"scanCode\":" << mapping.scanCode
               << ",\"modifier\":" << JsonEscape(mapping.modifier) << ",\"translation\":";
        WriteTranslation(stream, mapping.translation);
        stream << '}';
    }
    stream << "\n  ],\n  \"terminalInputCases\":[";
    for (size_t index = 0; index < encoderCases.size(); ++index)
    {
        const auto& test = encoderCases[index];
        if (index) stream << ',';
        stream << "\n    {\"name\":" << JsonEscape(test.name) << ",\"handled\":" << (test.output ? "true" : "false") << ",\"output\":";
        if (test.output)
        {
            stream << JsonEscape(*test.output) << ",\"utf16Hex\":" << JsonEscape(HexUtf16(*test.output))
                   << ",\"utf8Hex\":" << JsonEscape(HexUtf8(*test.output));
        }
        else
        {
            stream << "null,\"utf16Hex\":null,\"utf8Hex\":null";
        }
        stream << '}';
    }
    stream << "\n  ]\n}\n";
    stream.close();
    if (!stream) throw std::runtime_error("Unable to finish native probe JSON");

    std::wprintf(L"VT7 I01 native probe completed: %ls\n", outputPath.c_str());
    std::printf("Mappings: %zu, AltGr: %zu, dead key: %s, encoder cases: %zu\n",
        mappings.size(), altGrMappings, dead != mappings.end() ? "yes" : "no", encoderCases.size());
    return mappings.empty() || altGrMappings == 0 || encoderCases.empty() ? 2 : 0;
}
catch (const std::exception& error)
{
    std::fprintf(stderr, "VT7 I01 native probe failed: %s\n", error.what());
    return 1;
}
