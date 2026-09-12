#include "include/vt7_native.h"

#include <Windows.h>

#include <cwchar>
#include <cstdlib>

namespace
{
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

uint32_t __cdecl VT7_GetAbiVersion(void)
{
    return VT7_NATIVE_ABI_VERSION;
}

int32_t __cdecl VT7_GetBuildInfo(VT7_BUILD_INFO* info)
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
    info->abi_version = VT7_NATIVE_ABI_VERSION;
    info->version_major = 0;
    info->version_minor = 3;
    info->version_patch = 4;

    copy_text(info->product, L"VT7");

    swprintf_s(
        info->compiler,
        _countof(info->compiler),
        L"MSVC %u, full version %u",
        static_cast<unsigned int>(_MSC_VER),
        static_cast<unsigned int>(_MSC_FULL_VER));

#ifdef NDEBUG
    copy_text(info->configuration, L"Release x64");
#else
    copy_text(info->configuration, L"Debug x64");
#endif

    wchar_t timestamp[VT7_TEXT_MEDIUM]{};
    swprintf_s(timestamp, _countof(timestamp), L"%hs %hs", __DATE__, __TIME__);
    copy_text(info->build_timestamp, timestamp);

    return static_cast<int32_t>(S_OK);
}
