#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

    enum : uint32_t
    {
        VT7_NATIVE_ABI_VERSION = 1,
        VT7_TEXT_SHORT = 32,
        VT7_TEXT_MEDIUM = 64,
        VT7_TEXT_LONG = 128,
    };

#pragma pack(push, 8)

    typedef struct VT7_BUILD_INFO
    {
        uint32_t struct_size;
        uint32_t abi_version;
        uint16_t version_major;
        uint16_t version_minor;
        uint16_t version_patch;
        uint16_t reserved;
        wchar_t product[VT7_TEXT_SHORT];
        wchar_t compiler[VT7_TEXT_MEDIUM];
        wchar_t configuration[VT7_TEXT_SHORT];
        wchar_t build_timestamp[VT7_TEXT_MEDIUM];
    } VT7_BUILD_INFO;

    typedef struct VT7_PLATFORM_INFO
    {
        uint32_t struct_size;
        uint32_t major_version;
        uint32_t minor_version;
        uint32_t build_number;
        uint32_t service_pack_major;
        uint32_t service_pack_minor;
        uint32_t product_type;
        uint32_t architecture_bits;
        wchar_t service_pack[VT7_TEXT_MEDIUM];
    } VT7_PLATFORM_INFO;

    typedef struct VT7_GRAPHICS_INFO
    {
        uint32_t struct_size;
        int32_t factory_hresult;
        int32_t hardware_hresult;
        int32_t warp_hresult;
        uint32_t hardware_feature_level;
        uint32_t warp_feature_level;
        uint32_t supports_dxgi_1_2;
        uint32_t adapter_is_software;
        uint64_t dedicated_video_memory;
        wchar_t adapter_description[VT7_TEXT_LONG];
    } VT7_GRAPHICS_INFO;

#pragma pack(pop)

    uint32_t __cdecl VT7_GetAbiVersion(void);
    int32_t __cdecl VT7_GetBuildInfo(VT7_BUILD_INFO* info);
    int32_t __cdecl VT7_GetPlatformInfo(VT7_PLATFORM_INFO* info);
    int32_t __cdecl VT7_ProbeGraphics(VT7_GRAPHICS_INFO* info);

#ifdef __cplusplus
}
#endif
