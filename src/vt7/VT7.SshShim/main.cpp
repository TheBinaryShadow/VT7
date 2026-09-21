// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.

#include <windows.h>
#include <bcrypt.h>
#include <wincrypt.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>
#include <cwctype>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace
{
    constexpr uint16_t ProtocolVersion = 1;
    constexpr DWORD HandshakeIoTimeoutMilliseconds = 5000;
    constexpr uint32_t MaximumFrame = 64 * 1024;
    constexpr uint32_t ConsoleHandleFlag = 0x10000;

    enum class Message : uint8_t { Hello = 1, Challenge = 2, Request = 3, Response = 4, BarrierWritten = 5, Complete = 6 };
    enum class Action : uint8_t { Embedded = 1, System = 2, Reject = 3 };

    class Handle
    {
    public:
        Handle() = default;
        explicit Handle(HANDLE value) : _value(value) {}
        ~Handle() { reset(); }
        Handle(const Handle&) = delete;
        Handle& operator=(const Handle&) = delete;
        Handle(Handle&& other) noexcept : _value(other.release()) {}
        Handle& operator=(Handle&& other) noexcept { if (this != &other) reset(other.release()); return *this; }
        HANDLE get() const { return _value; }
        explicit operator bool() const { return _value && _value != INVALID_HANDLE_VALUE; }
        HANDLE release() { const auto value = _value; _value = nullptr; return value; }
        void reset(HANDLE value = nullptr) { if (*this) CloseHandle(_value); _value = value; }
    private:
        HANDLE _value{};
    };

    [[noreturn]] void Fail(const char* text) { throw std::runtime_error(text); }
    void Check(const bool condition, const char* text) { if (!condition) Fail(text); }

    std::wstring Environment(const wchar_t* name)
    {
        const auto count = GetEnvironmentVariableW(name, nullptr, 0);
        if (!count) return {};
        std::wstring value(count - 1, L'\0');
        Check(GetEnvironmentVariableW(name, value.data(), count) == count - 1, "GetEnvironmentVariableW failed");
        return value;
    }

    void AppendU16(std::vector<uint8_t>& bytes, const uint16_t value)
    {
        bytes.push_back(static_cast<uint8_t>(value));
        bytes.push_back(static_cast<uint8_t>(value >> 8));
    }
    void AppendU32(std::vector<uint8_t>& bytes, const uint32_t value)
    {
        for (unsigned shift = 0; shift != 32; shift += 8) bytes.push_back(static_cast<uint8_t>(value >> shift));
    }
    void AppendU64(std::vector<uint8_t>& bytes, const uint64_t value)
    {
        for (unsigned shift = 0; shift != 64; shift += 8) bytes.push_back(static_cast<uint8_t>(value >> shift));
    }
    void AppendString(std::vector<uint8_t>& bytes, const std::wstring_view value)
    {
        Check(value.size() <= 32767, "string exceeds protocol bound");
        AppendU32(bytes, static_cast<uint32_t>(value.size()));
        const auto* begin = reinterpret_cast<const uint8_t*>(value.data());
        bytes.insert(bytes.end(), begin, begin + value.size() * sizeof(wchar_t));
    }

    class Reader
    {
    public:
        explicit Reader(const std::vector<uint8_t>& bytes) : _bytes(bytes) {}
        uint8_t U8() { Need(1); return _bytes[_offset++]; }
        uint16_t U16() { Need(2); const auto v = static_cast<uint16_t>(_bytes[_offset] | (_bytes[_offset + 1] << 8)); _offset += 2; return v; }
        uint32_t U32() { Need(4); uint32_t v{}; for (unsigned i = 0; i != 4; ++i) v |= static_cast<uint32_t>(_bytes[_offset + i]) << (i * 8); _offset += 4; return v; }
        uint64_t U64() { Need(8); uint64_t v{}; for (unsigned i = 0; i != 8; ++i) v |= static_cast<uint64_t>(_bytes[_offset + i]) << (i * 8); _offset += 8; return v; }
        std::wstring String()
        {
            const auto count = U32();
            Check(count <= 32767, "received string exceeds protocol bound");
            Need(static_cast<size_t>(count) * sizeof(wchar_t));
            std::wstring value(reinterpret_cast<const wchar_t*>(_bytes.data() + _offset), count);
            _offset += static_cast<size_t>(count) * sizeof(wchar_t);
            return value;
        }
        std::vector<uint8_t> Bytes(const size_t count) { Need(count); std::vector<uint8_t> value(_bytes.begin() + _offset, _bytes.begin() + _offset + count); _offset += count; return value; }
        bool Done() const { return _offset == _bytes.size(); }
    private:
        void Need(const size_t count) { Check(count <= _bytes.size() - _offset, "truncated protocol frame"); }
        const std::vector<uint8_t>& _bytes;
        size_t _offset{};
    };

    void Transfer(const HANDLE pipe, void* buffer, const DWORD count, const bool write,
        const DWORD timeout = HandshakeIoTimeoutMilliseconds)
    {
        auto* cursor = static_cast<uint8_t*>(buffer);
        DWORD total{};
        while (total < count)
        {
            Handle event(CreateEventW(nullptr, TRUE, FALSE, nullptr));
            Check(static_cast<bool>(event), "CreateEventW failed");
            OVERLAPPED overlapped{};
            overlapped.hEvent = event.get();
            DWORD transferred{};
            const auto started = write
                ? WriteFile(pipe, cursor + total, count - total, &transferred, &overlapped)
                : ReadFile(pipe, cursor + total, count - total, &transferred, &overlapped);
            if (!started)
            {
                const auto error = GetLastError();
                Check(error == ERROR_IO_PENDING, write ? "pipe WriteFile failed" : "pipe ReadFile failed");
                const auto wait = WaitForSingleObject(event.get(), timeout);
                if (wait != WAIT_OBJECT_0)
                {
                    CancelIo(pipe);
                    Fail(write ? "pipe write timed out" : "pipe read timed out");
                }
                Check(GetOverlappedResult(pipe, &overlapped, &transferred, FALSE) != FALSE,
                    write ? "pipe overlapped write failed" : "pipe overlapped read failed");
            }
            Check(transferred != 0, "pipe closed during frame transfer");
            total += transferred;
        }
    }

    void WriteFrame(const HANDLE pipe, const std::vector<uint8_t>& body)
    {
        Check(!body.empty() && body.size() <= MaximumFrame, "invalid outgoing frame size");
        const auto size = static_cast<uint32_t>(body.size());
        Transfer(pipe, const_cast<uint32_t*>(&size), sizeof(size), true);
        Transfer(pipe, const_cast<uint8_t*>(body.data()), size, true);
    }

    std::vector<uint8_t> ReadFrame(const HANDLE pipe,
        const DWORD timeout = HandshakeIoTimeoutMilliseconds)
    {
        uint32_t size{};
        Transfer(pipe, &size, sizeof(size), false, timeout);
        Check(size != 0 && size <= MaximumFrame, "invalid incoming frame size");
        std::vector<uint8_t> body(size);
        Transfer(pipe, body.data(), size, false, timeout);
        return body;
    }

    std::vector<uint8_t> Base64UrlDecode(std::wstring value)
    {
        std::replace(value.begin(), value.end(), L'-', L'+');
        std::replace(value.begin(), value.end(), L'_', L'/');
        while (value.size() % 4) value.push_back(L'=');
        DWORD size{};
        Check(CryptStringToBinaryW(value.c_str(), static_cast<DWORD>(value.size()), CRYPT_STRING_BASE64,
            nullptr, &size, nullptr, nullptr) != FALSE, "capability base64 sizing failed");
        std::vector<uint8_t> bytes(size);
        Check(CryptStringToBinaryW(value.c_str(), static_cast<DWORD>(value.size()), CRYPT_STRING_BASE64,
            bytes.data(), &size, nullptr, nullptr) != FALSE, "capability base64 decode failed");
        bytes.resize(size);
        return bytes;
    }

    std::vector<uint8_t> HmacSha256(const std::vector<uint8_t>& key, const std::vector<uint8_t>& data)
    {
        BCRYPT_ALG_HANDLE algorithm{};
        Check(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, BCRYPT_ALG_HANDLE_HMAC_FLAG) >= 0,
            "BCryptOpenAlgorithmProvider HMAC failed");
        DWORD objectSize{}, result{};
        Check(BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH, reinterpret_cast<PUCHAR>(&objectSize), sizeof(objectSize), &result, 0) >= 0,
            "BCryptGetProperty HMAC failed");
        std::vector<uint8_t> object(objectSize), hash(32);
        BCRYPT_HASH_HANDLE handle{};
        const auto created = BCryptCreateHash(algorithm, &handle, object.data(), objectSize,
            const_cast<PUCHAR>(key.data()), static_cast<ULONG>(key.size()), 0);
        if (created < 0) { BCryptCloseAlgorithmProvider(algorithm, 0); Fail("BCryptCreateHash HMAC failed"); }
        const auto hashed = BCryptHashData(handle, const_cast<PUCHAR>(data.data()), static_cast<ULONG>(data.size()), 0);
        const auto finished = hashed >= 0 ? BCryptFinishHash(handle, hash.data(), static_cast<ULONG>(hash.size()), 0) : hashed;
        BCryptDestroyHash(handle);
        BCryptCloseAlgorithmProvider(algorithm, 0);
        Check(finished >= 0, "BCrypt HMAC failed");
        return hash;
    }

    std::wstring Sha256File(const std::wstring& path)
    {
        Handle file(CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, nullptr));
        Check(static_cast<bool>(file), "external client open failed");
        BCRYPT_ALG_HANDLE algorithm{};
        Check(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) >= 0,
            "BCryptOpenAlgorithmProvider SHA256 failed");
        DWORD objectSize{}, result{};
        Check(BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH, reinterpret_cast<PUCHAR>(&objectSize), sizeof(objectSize), &result, 0) >= 0,
            "BCryptGetProperty SHA256 failed");
        std::vector<uint8_t> object(objectSize), hash(32), buffer(64 * 1024);
        BCRYPT_HASH_HANDLE handle{};
        Check(BCryptCreateHash(algorithm, &handle, object.data(), objectSize, nullptr, 0, 0) >= 0,
            "BCryptCreateHash SHA256 failed");
        while (true)
        {
            DWORD read{};
            Check(ReadFile(file.get(), buffer.data(), static_cast<DWORD>(buffer.size()), &read, nullptr) != FALSE,
                "external client hash read failed");
            if (!read) break;
            Check(BCryptHashData(handle, buffer.data(), read, 0) >= 0, "BCryptHashData SHA256 failed");
        }
        Check(BCryptFinishHash(handle, hash.data(), static_cast<ULONG>(hash.size()), 0) >= 0, "BCryptFinishHash SHA256 failed");
        BCryptDestroyHash(handle);
        BCryptCloseAlgorithmProvider(algorithm, 0);
        static constexpr wchar_t digits[]{ L"0123456789ABCDEF" };
        std::wstring text;
        text.reserve(64);
        for (const auto byte : hash) { text.push_back(digits[byte >> 4]); text.push_back(digits[byte & 15]); }
        return text;
    }

    std::wstring FullPath(const std::wstring& path)
    {
        const auto size = GetFullPathNameW(path.c_str(), 0, nullptr, nullptr);
        Check(size != 0, "GetFullPathNameW sizing failed");
        std::wstring value(size - 1, L'\0');
        Check(GetFullPathNameW(path.c_str(), size, value.data(), nullptr) == size - 1, "GetFullPathNameW failed");
        while (value.size() > 3 && (value.back() == L'\\' || value.back() == L'/')) value.pop_back();
        return value;
    }

    std::wstring CurrentExecutable()
    {
        std::wstring path(32768, L'\0');
        const auto length = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
        Check(length != 0 && length < path.size(), "GetModuleFileNameW failed");
        path.resize(length);
        return FullPath(path);
    }

    std::wstring Parent(const std::wstring& path)
    {
        const auto offset = path.find_last_of(L"\\/");
        return offset == std::wstring::npos ? L"." : path.substr(0, offset);
    }

    bool EqualPath(const std::wstring& left, const std::wstring& right) { return _wcsicmp(FullPath(left).c_str(), FullPath(right).c_str()) == 0; }

    std::wstring Quote(const std::wstring_view value)
    {
        if (!value.empty() && value.find_first_of(L" \t\n\v\"") == std::wstring_view::npos) return std::wstring(value);
        std::wstring output{ L'"' };
        size_t slashes{};
        for (const auto character : value)
        {
            if (character == L'\\') { ++slashes; continue; }
            if (character == L'"')
            {
                output.append(slashes * 2 + 1, L'\\');
                output.push_back(L'"');
            }
            else
            {
                output.append(slashes, L'\\');
                output.push_back(character);
            }
            slashes = 0;
        }
        output.append(slashes * 2, L'\\');
        output.push_back(L'"');
        return output;
    }

    std::vector<wchar_t> SanitizedEnvironment(const std::wstring& shimDirectory)
    {
        auto block = GetEnvironmentStringsW();
        Check(block != nullptr, "GetEnvironmentStringsW failed");
        std::vector<std::wstring> entries;
        for (auto cursor = block; *cursor; cursor += wcslen(cursor) + 1)
        {
            std::wstring entry(cursor);
            const auto separator = entry[0] == L'=' ? entry.find(L'=', 1) : entry.find(L'=');
            if (separator == std::wstring::npos) continue;
            const auto name = entry.substr(0, separator);
            if (_wcsnicmp(name.c_str(), L"VT7_SSH_", 8) == 0) continue;
            if (_wcsicmp(name.c_str(), L"PATH") == 0)
            {
                std::wstring filtered;
                bool keptAny = false;
                const auto value = entry.substr(separator + 1);
                size_t start{};
                while (start <= value.size())
                {
                    const auto end = value.find(L';', start);
                    const auto part = value.substr(start, end == std::wstring::npos ? value.size() - start : end - start);
                    bool remove = false;
                    try { remove = !part.empty() && EqualPath(part, shimDirectory); } catch (...) { remove = false; }
                    if (!remove)
                    {
                        if (keptAny) filtered.push_back(L';');
                        filtered += part;
                        keptAny = true;
                    }
                    if (end == std::wstring::npos) break;
                    start = end + 1;
                }
                entry = name + L"=" + filtered;
            }
            entries.push_back(std::move(entry));
        }
        FreeEnvironmentStringsW(block);
        std::sort(entries.begin(), entries.end(), [](const auto& left, const auto& right) { return _wcsicmp(left.c_str(), right.c_str()) < 0; });
        size_t units = 1;
        for (const auto& entry : entries) units += entry.size() + 1;
        std::vector<wchar_t> result(units, L'\0');
        auto cursor = result.data();
        for (const auto& entry : entries) { memcpy(cursor, entry.c_str(), (entry.size() + 1) * sizeof(wchar_t)); cursor += entry.size() + 1; }
        return result;
    }

    bool UsesTraditionalConsoleHandles()
    {
        using RtlGetVersionFunction = LONG(WINAPI*)(OSVERSIONINFOW*);
        const auto module = GetModuleHandleW(L"ntdll.dll");
        Check(module != nullptr, "ntdll is unavailable");
        const auto rtlGetVersion = reinterpret_cast<RtlGetVersionFunction>(GetProcAddress(module, "RtlGetVersion"));
        Check(rtlGetVersion != nullptr, "RtlGetVersion is unavailable");
        OSVERSIONINFOW version{ sizeof(OSVERSIONINFOW) };
        Check(rtlGetVersion(&version) >= 0, "RtlGetVersion failed");
        return version.dwMajorVersion < 6 || (version.dwMajorVersion == 6 && version.dwMinorVersion < 2);
    }

    int LaunchSystem(const std::vector<std::wstring>& arguments, const std::wstring& externalPath, const std::wstring& expectedHash)
    {
        Check(!externalPath.empty() && !expectedHash.empty(), "external SSH fallback is unavailable");
        const auto executable = CurrentExecutable();
        Check(!EqualPath(externalPath, executable), "external SSH fallback resolves to the shim");
        Check(_wcsicmp(Sha256File(externalPath).c_str(), expectedHash.c_str()) == 0, "external SSH hash changed");

        std::wstring commandLine = Quote(externalPath);
        for (size_t index = 1; index < arguments.size(); ++index) { commandLine.push_back(L' '); commandLine += Quote(arguments[index]); }
        std::vector<wchar_t> mutableCommand(commandLine.begin(), commandLine.end());
        mutableCommand.push_back(L'\0');
        auto environment = SanitizedEnvironment(Parent(executable));

        PROCESS_INFORMATION process{};
        if (UsesTraditionalConsoleHandles())
        {
            STARTUPINFOW startup{};
            startup.cb = sizeof(startup);
            startup.dwFlags = STARTF_USESTDHANDLES;
            startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
            startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
            startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
            Check(startup.hStdInput && startup.hStdInput != INVALID_HANDLE_VALUE &&
                startup.hStdOutput && startup.hStdOutput != INVALID_HANDLE_VALUE &&
                startup.hStdError && startup.hStdError != INVALID_HANDLE_VALUE,
                "standard handle unavailable for traditional fallback");
            Check(CreateProcessW(externalPath.c_str(), mutableCommand.data(), nullptr, nullptr, FALSE,
                CREATE_UNICODE_ENVIRONMENT, environment.data(), nullptr, &startup, &process) != FALSE,
                "CreateProcessW traditional external SSH failed");
        }
        else
        {

        std::array<HANDLE, 3> inherited{};
        size_t preparedHandles{};
        std::vector<uint8_t> attributeStorage;
        LPPROC_THREAD_ATTRIBUTE_LIST attributes{};
        try
        {
            for (DWORD index = 0; index != inherited.size(); ++index)
            {
                const auto source = GetStdHandle(index == 0 ? STD_INPUT_HANDLE : index == 1 ? STD_OUTPUT_HANDLE : STD_ERROR_HANDLE);
                Check(source && source != INVALID_HANDLE_VALUE, "standard handle unavailable for fallback");
                DWORD consoleMode{};
                if (GetConsoleMode(source, &consoleMode))
                {
                    SECURITY_ATTRIBUTES security{ sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE };
                    inherited[index] = CreateFileW(index == 0 ? L"CONIN$" : L"CONOUT$",
                        GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
                        &security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
                    Check(inherited[index] != INVALID_HANDLE_VALUE, "CreateFileW console handle failed for fallback");
                }
                else
                {
                    Check(DuplicateHandle(GetCurrentProcess(), source, GetCurrentProcess(), &inherited[index], 0, TRUE,
                        DUPLICATE_SAME_ACCESS) != FALSE, "DuplicateHandle redirected handle failed for fallback");
                }
                ++preparedHandles;
            }
            SIZE_T attributeSize{};
            InitializeProcThreadAttributeList(nullptr, 1, 0, &attributeSize);
            Check(attributeSize != 0, "InitializeProcThreadAttributeList sizing failed");
            attributeStorage.resize(attributeSize);
            attributes = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attributeStorage.data());
            Check(InitializeProcThreadAttributeList(attributes, 1, 0, &attributeSize) != FALSE, "InitializeProcThreadAttributeList failed");
            Check(UpdateProcThreadAttribute(attributes, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, inherited.data(),
                inherited.size() * sizeof(HANDLE), nullptr, nullptr) != FALSE, "UpdateProcThreadAttribute failed");
            STARTUPINFOEXW startup{};
            startup.StartupInfo.cb = sizeof(startup);
            startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
            startup.StartupInfo.hStdInput = inherited[0];
            startup.StartupInfo.hStdOutput = inherited[1];
            startup.StartupInfo.hStdError = inherited[2];
            startup.lpAttributeList = attributes;
            Check(CreateProcessW(externalPath.c_str(), mutableCommand.data(), nullptr, nullptr, TRUE,
                EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT, environment.data(), nullptr,
                &startup.StartupInfo, &process) != FALSE, "CreateProcessW external SSH failed");
        }
        catch (...)
        {
            if (attributes) DeleteProcThreadAttributeList(attributes);
            for (size_t index = 0; index != preparedHandles; ++index) CloseHandle(inherited[index]);
            throw;
        }
        DeleteProcThreadAttributeList(attributes);
        for (size_t index = 0; index != preparedHandles; ++index) CloseHandle(inherited[index]);
        }
        Handle processHandle(process.hProcess), threadHandle(process.hThread);
        Check(WaitForSingleObject(processHandle.get(), INFINITE) == WAIT_OBJECT_0, "external SSH wait failed");
        DWORD exitCode{};
        Check(GetExitCodeProcess(processHandle.get(), &exitCode) != FALSE, "external SSH exit query failed");
        return static_cast<int>(exitCode);
    }

    uint64_t ProcessCreationTime()
    {
        FILETIME created{}, exited{}, kernel{}, user{};
        Check(GetProcessTimes(GetCurrentProcess(), &created, &exited, &kernel, &user) != FALSE, "GetProcessTimes failed");
        ULARGE_INTEGER value{};
        value.LowPart = created.dwLowDateTime;
        value.HighPart = created.dwHighDateTime;
        return value.QuadPart;
    }

    uint32_t HandleFlags(const DWORD id)
    {
        const auto handle = GetStdHandle(id);
        if (!handle || handle == INVALID_HANDLE_VALUE) return FILE_TYPE_UNKNOWN;
        DWORD mode{};
        return (GetFileType(handle) & ~FILE_TYPE_REMOTE) | (GetConsoleMode(handle, &mode) ? ConsoleHandleFlag : 0);
    }

    std::vector<DWORD> ConsoleProcesses()
    {
        std::vector<DWORD> values(256);
        const auto count = GetConsoleProcessList(values.data(), static_cast<DWORD>(values.size()));
        Check(count != 0 && count <= values.size(), "GetConsoleProcessList failed or exceeded bound");
        values.resize(count);
        return values;
    }

    int RunShim(const std::vector<std::wstring>& arguments)
    {
        const auto external = Environment(L"VT7_SYSTEM_SSH");
        const auto externalHash = Environment(L"VT7_SYSTEM_SSH_SHA256");
        const auto mode = Environment(L"VT7_SSH_MODE");
        const auto protocol = Environment(L"VT7_SSH_PROTOCOL");
        const auto pipeName = Environment(L"VT7_SSH_PIPE");
        const auto capabilityText = Environment(L"VT7_SSH_CAPABILITY");
        const auto executableName = CurrentExecutable().substr(CurrentExecutable().find_last_of(L"\\/") + 1);
        if (_wcsicmp(executableName.c_str(), L"ssh-system.exe") == 0 || _wcsicmp(mode.c_str(), L"system") == 0 ||
            pipeName.empty() || capabilityText.empty() || protocol != L"1")
            return LaunchSystem(arguments, external, externalHash);

        const auto capability = Base64UrlDecode(capabilityText);
        Check(capability.size() == 32, "invalid capability length");
        if (!WaitNamedPipeW(pipeName.c_str(), HandshakeIoTimeoutMilliseconds)) return LaunchSystem(arguments, external, externalHash);
        Handle pipe(CreateFileW(pipeName.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr));
        if (!pipe) return LaunchSystem(arguments, external, externalHash);

        bool hostDecisionReceived = false;
        try
        {

        std::array<uint8_t, 16> clientNonce{};
        Check(BCryptGenRandom(nullptr, clientNonce.data(), static_cast<ULONG>(clientNonce.size()), BCRYPT_USE_SYSTEM_PREFERRED_RNG) >= 0,
            "BCryptGenRandom failed");
        const auto pid = GetCurrentProcessId();
        const auto creationTime = ProcessCreationTime();
        std::vector<uint8_t> hello{ static_cast<uint8_t>(Message::Hello) };
        AppendU16(hello, ProtocolVersion);
        AppendU32(hello, pid);
        AppendU64(hello, creationTime);
        hello.insert(hello.end(), clientNonce.begin(), clientNonce.end());
        WriteFrame(pipe.get(), hello);

        const auto challengeBody = ReadFrame(pipe.get());
        Reader challenge(challengeBody);
        Check(challenge.U8() == static_cast<uint8_t>(Message::Challenge) && challenge.U16() == ProtocolVersion,
            "invalid host challenge");
        const auto generation = challenge.U64();
        const auto serverNonce = challenge.Bytes(16);
        Check(challenge.Done(), "unexpected host challenge data");

        std::vector<uint8_t> request{ static_cast<uint8_t>(Message::Request) };
        AppendU16(request, ProtocolVersion);
        AppendU32(request, pid);
        AppendU64(request, creationTime);
        request.insert(request.end(), clientNonce.begin(), clientNonce.end());
        request.insert(request.end(), serverNonce.begin(), serverNonce.end());
        AppendU64(request, generation);
        AppendU32(request, HandleFlags(STD_INPUT_HANDLE));
        AppendU32(request, HandleFlags(STD_OUTPUT_HANDLE));
        AppendU32(request, HandleFlags(STD_ERROR_HANDLE));
        const auto consoleProcesses = ConsoleProcesses();
        AppendU32(request, static_cast<uint32_t>(consoleProcesses.size()));
        for (const auto process : consoleProcesses) AppendU32(request, process);
        std::wstring currentDirectory(32768, L'\0');
        const auto currentLength = GetCurrentDirectoryW(static_cast<DWORD>(currentDirectory.size()), currentDirectory.data());
        Check(currentLength != 0 && currentLength < currentDirectory.size(), "GetCurrentDirectoryW failed");
        currentDirectory.resize(currentLength);
        AppendString(request, currentDirectory);
        Check(arguments.size() <= 256, "argument count exceeds protocol bound");
        AppendU32(request, static_cast<uint32_t>(arguments.size()));
        for (const auto& argument : arguments) AppendString(request, argument);
        const auto requestMac = HmacSha256(capability, request);
        request.insert(request.end(), requestMac.begin(), requestMac.end());
        WriteFrame(pipe.get(), request);

        const auto responseBody = ReadFrame(pipe.get());
        Reader response(responseBody);
        Check(response.U8() == static_cast<uint8_t>(Message::Response), "invalid host response");
        const auto action = static_cast<Action>(response.U8());
        const auto exitCode = static_cast<int32_t>(response.U32());
        const auto requestId = response.Bytes(16);
        const auto reason = response.String();
        const auto first = response.String();
        const auto second = response.String();
        Check(response.Done(), "unexpected host response data");
        if (action == Action::System)
        {
            hostDecisionReceived = true;
            return LaunchSystem(arguments, first, second);
        }
        if (action == Action::Reject)
        {
            hostDecisionReceived = true;
            std::fwprintf(stderr, L"VT7 SSH request rejected (%ls).\n", reason.c_str());
            return exitCode;
        }
        Check(action == Action::Embedded, "unknown host action");
        hostDecisionReceived = true;

        DWORD written{};
        const auto output = GetStdHandle(STD_OUTPUT_HANDLE);
        const auto line = first + L"\r\n";
        Check(WriteConsoleW(output, line.data(), static_cast<DWORD>(line.size()), &written, nullptr) != FALSE && written == line.size(),
            "barrier WriteConsoleW failed");
        std::vector<uint8_t> barrier{ static_cast<uint8_t>(Message::BarrierWritten) };
        barrier.insert(barrier.end(), requestId.begin(), requestId.end());
        barrier.insert(barrier.end(), serverNonce.begin(), serverNonce.end());
        const auto barrierMac = HmacSha256(capability, barrier);
        barrier.insert(barrier.end(), barrierMac.begin(), barrierMac.end());
        WriteFrame(pipe.get(), barrier);

        // Once the host accepts an embedded request, this process represents the
        // interactive ssh command in the originating shell. Its completion wait
        // must last for the remote session, while a closed host pipe still wakes
        // the overlapped read immediately.
        const auto completeBody = ReadFrame(pipe.get(), INFINITE);
        Reader complete(completeBody);
        Check(complete.U8() == static_cast<uint8_t>(Message::Complete), "invalid host completion");
        const auto status = static_cast<int32_t>(complete.U32());
        const auto completedId = complete.Bytes(16);
        Check(completedId == requestId && complete.Done(), "host completion request mismatch");
        return status;
        }
        catch (...)
        {
            if (!hostDecisionReceived) return LaunchSystem(arguments, external, externalHash);
            throw;
        }
    }
}

int wmain(const int argc, wchar_t** argv)
{
    try
    {
        std::vector<std::wstring> arguments;
        arguments.reserve(argc);
        for (int index = 0; index < argc; ++index) arguments.emplace_back(argv[index]);
        return RunShim(arguments);
    }
    catch (const std::exception& error)
    {
        std::fprintf(stderr, "VT7 SSH shim failed: %s (Win32 %lu)\n", error.what(), GetLastError());
        return 255;
    }
}
