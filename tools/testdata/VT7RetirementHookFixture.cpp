// Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
// Development-only debugger grammar fixture. Microsoft image bytes remain data.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <cstdio>
#include <cwchar>
#include <cstdint>
#include <cstring>
#include <vector>

extern "C" __declspec(dllexport) __declspec(noinline)
void VT7HookReady(void* image, void* device, void* wrapper)
{
    printf("FIXTURE_READY_RETURN image=%p device=%p wrapper=%p\n", image, device, wrapper);
}

extern "C" __declspec(dllexport) __declspec(noinline)
void VT7HookCallback(void* instance, void* wrapper, void* work)
{
    printf("FIXTURE_CALLBACK instance=%p wrapper=%p work=%p\n", instance, wrapper, work);
}

int wmain(int argc, wchar_t** argv)
{
    setvbuf(stdout, nullptr, _IONBF, 0);
    if (argc != 3) return 2;
    const auto file = CreateFileW(argv[1], GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return 3;
    const auto size = GetFileSize(file, nullptr);
    if (size != 2565120) { CloseHandle(file); return 4; }
    std::vector<unsigned char> bytes(size);
    DWORD read = 0;
    const auto readOk = ReadFile(file, bytes.data(), size, &read, nullptr);
    CloseHandle(file);
    if (!readOk || read != size) return 5;
    const auto dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(bytes.data());
    if (dos->e_magic != IMAGE_DOS_SIGNATURE || dos->e_lfanew < 0 || size_t(dos->e_lfanew) + sizeof(IMAGE_NT_HEADERS64) > bytes.size()) return 6;
    const auto nt = reinterpret_cast<const IMAGE_NT_HEADERS64*>(bytes.data() + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE || nt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC ||
        nt->FileHeader.Machine != IMAGE_FILE_MACHINE_AMD64 || nt->OptionalHeader.SizeOfImage != 0x279000 ||
        nt->OptionalHeader.SizeOfHeaders > bytes.size()) return 7;
    auto image = static_cast<unsigned char*>(VirtualAlloc(nullptr, nt->OptionalHeader.SizeOfImage, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE));
    if (!image) return 8;
    memcpy(image, bytes.data(), nt->OptionalHeader.SizeOfHeaders);
    const auto sections = IMAGE_FIRST_SECTION(nt);
    for (unsigned i = 0; i < nt->FileHeader.NumberOfSections; ++i)
    {
        const auto& section = sections[i];
        if (reinterpret_cast<const unsigned char*>(&section + 1) > bytes.data() + bytes.size() ||
            uint64_t(section.PointerToRawData) + section.SizeOfRawData > bytes.size() ||
            uint64_t(section.VirtualAddress) + section.SizeOfRawData > nt->OptionalHeader.SizeOfImage) return 9;
        memcpy(image + section.VirtualAddress, bytes.data() + section.PointerToRawData, section.SizeOfRawData);
    }
    if (!wcscmp(argv[2], L"bad-opcode")) image[0x1649B0] ^= 1;
    else if (!wcscmp(argv[2], L"bad-codeview")) image[0x8E84] ^= 1;
    else if (!wcscmp(argv[2], L"unsupported")) reinterpret_cast<IMAGE_NT_HEADERS64*>(image + dos->e_lfanew)->FileHeader.TimeDateStamp ^= 1;
    else if (wcscmp(argv[2], L"matched") && wcscmp(argv[2], L"event-limit")) return 10;
    alignas(16) unsigned char device[0x1000]{};
    alignas(16) unsigned char wrapper[0xA40]{};
    alignas(16) unsigned char work[0x100]{};
    *reinterpret_cast<void**>(device + 0x7C0) = wrapper;
    *reinterpret_cast<void**>(wrapper) = device;
    *reinterpret_cast<DWORD*>(wrapper + 0x2C) = 3;
    *reinterpret_cast<void**>(wrapper + 0x38) = work;
    MEMORY_BASIC_INFORMATION memory{};
    if (VirtualQuery(image, &memory, sizeof(memory)) != sizeof(memory) || memory.Protect != PAGE_READWRITE) return 11;
    printf("FIXTURE_BEGIN case=%ls image=%p device=%p wrapper=%p work=%p protection=PAGE_READWRITE; microsoft_code_executed=0\n",
           argv[2], image, device, wrapper, work);
    VT7HookReady(image, device, wrapper);
    VT7HookCallback(nullptr, wrapper, work);
    VT7HookCallback(nullptr, wrapper, work);
    VirtualFree(image, 0, MEM_RELEASE);
    printf("FIXTURE_COMPLETE; microsoft_code_executed=0\n");
    return 0;
}
