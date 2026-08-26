#include "include/vt7_native.h"

#include <Windows.h>

#include <cwchar>

namespace
{
    using RtlGetVersionFunction = LONG(WINAPI*)(OSVERSIONINFOEXW*);

    template<size_t Size>
    void copy_text(wchar_t (&destination)[Size], const wchar_t* source) noexcept
    {
        if (source == nullptr)
        {
            destination[0] = L'\0';
            return;
        }

        wcsncpy_s(destination, Size, source, _TRUNCATE);
    }
}

int32_t __cdecl VT7_GetPlatformInfo(VT7_PLATFORM_INFO* info)
{
    if (info == nullptr)
    {
        return static_cast<int32_t>(E_POINTER);
    }
    if (info->struct_size != sizeof(*info))
    {
        return static_cast<int32_t>(E_INVALIDARG);
    }

    ZeroMemory(info, sizeof(*info));
    info->struct_size = sizeof(*info);
    info->architecture_bits = sizeof(void*) * 8;

    const auto ntdll = GetModuleHandleW(L"ntdll.dll");
    if (ntdll == nullptr)
    {
        return static_cast<int32_t>(HRESULT_FROM_WIN32(GetLastError()));
    }

    const auto address = GetProcAddress(ntdll, "RtlGetVersion");
    if (address == nullptr)
    {
        return static_cast<int32_t>(HRESULT_FROM_WIN32(GetLastError()));
    }

    const auto rtlGetVersion = reinterpret_cast<RtlGetVersionFunction>(address);

    OSVERSIONINFOEXW version{};
    version.dwOSVersionInfoSize = sizeof(version);
    const auto status = rtlGetVersion(&version);
    if (status < 0)
    {
        return static_cast<int32_t>(status);
    }

    info->major_version = version.dwMajorVersion;
    info->minor_version = version.dwMinorVersion;
    info->build_number = version.dwBuildNumber;
    info->service_pack_major = version.wServicePackMajor;
    info->service_pack_minor = version.wServicePackMinor;
    info->product_type = version.wProductType;
    copy_text(info->service_pack, version.szCSDVersion);

    return static_cast<int32_t>(S_OK);
}
