// Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
// Development-only SEH fixture. Never linked into or shipped with VT7.
#include <windows.h>
#include <cstdio>
#include <cstring>

namespace
{
    constexpr DWORD InvalidHandle = 0xC0000008u;

    int handled(const unsigned count)
    {
        for (unsigned ordinal = 1; ordinal <= count; ++ordinal)
        {
            __try
            {
                RaiseException(InvalidHandle, 0, 0, nullptr);
                std::printf("FIXTURE_UNEXPECTED_RETURN ordinal=%u\n", ordinal);
                return 3;
            }
            __except (GetExceptionCode() == InvalidHandle ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH)
            {
                std::printf("FIXTURE_HANDLER ordinal=%u\n", ordinal);
            }
        }
        std::printf("FIXTURE_COMPLETE handlers=%u\n", count);
        return 0;
    }
}

int main(const int argc, const char* const* argv)
{
    std::setvbuf(stdout, nullptr, _IONBF, 0);
    if (argc != 2) return 2;
    std::printf("FIXTURE_BEGIN case=%s pid=%lu\n", argv[1], GetCurrentProcessId());
    if (std::strcmp(argv[1], "handled") == 0) return handled(1);
    if (std::strcmp(argv[1], "repeated") == 0) return handled(16);
    if (std::strcmp(argv[1], "unhandled") != 0) return 2;
    RaiseException(InvalidHandle, 0, 0, nullptr);
    std::puts("FIXTURE_UNEXPECTED_RETURN unhandled=1");
    return 3;
}
