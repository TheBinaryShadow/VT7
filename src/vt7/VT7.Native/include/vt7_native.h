#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

    enum : uint32_t
    {
        VT7_NATIVE_ABI_VERSION = 7,
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

    typedef struct VT7_SURFACE_INFO
    {
        uint32_t struct_size;
        uint32_t columns;
        uint32_t rows;
        uint32_t cell_width;
        uint32_t cell_height;
        uint32_t paint_count;
        uint32_t resize_count;
        int32_t last_hresult;
        uint32_t renderer_mode; // Last completed backend: 0 GDI; 1/2 D3D; 3/4 D2D; 6 no completed Atlas frame.
        uint32_t requested_frame;
        uint32_t completed_request;
        uint32_t header_ink_pixels; // First-row diagnostic readback, not a general blank-frame test.
        uint64_t raster_hash;
        uint32_t requested_renderer_mode; // 5 is automatic D3D hardware -> WARP.
        uint32_t device_generation;
        uint32_t device_attempts;
        uint32_t recovery_failures;
        uint32_t fallback_count;
        uint32_t injected_failures;
        int32_t last_render_failure; // Historical transient HRESULT, not fatal status.
        uint32_t frame_ink_pixels; // Pixels differing from the first pixel, entire diagnostic frame.
        uint32_t raster_width;
        uint32_t raster_height;
    } VT7_SURFACE_INFO;

    typedef struct VT7_SURFACE_SETTINGS
    {
        uint32_t struct_size;
        uint32_t system_dpi;
        uint32_t effective_dpi;
        uint32_t dpi_override; // Diagnostic-only renderer DPI. Zero uses real system DPI.
        uint32_t font_family; // Proof boundary: 1 Consolas, 2 Courier New.
        uint32_t font_points;
        uint32_t font_weight;
        uint32_t generation;
        uint32_t client_width;
        uint32_t client_height;
    } VT7_SURFACE_SETTINGS;

    int32_t __cdecl VT7_GetSurfaceSettings(void* window, VT7_SURFACE_SETTINGS* settings);
    int32_t __cdecl VT7_SetSurfaceFont(void* window, uint32_t family, uint32_t points, uint32_t weight, uint32_t diagnostic_dpi);

    // HWND values are opaque at the ABI boundary. Calls belong to the creating UI thread.
    int32_t __cdecl VT7_CreateSurface(void* parent, uint32_t renderer_mode, void** window);
    int32_t __cdecl VT7_DestroySurface(void* window);
    int32_t __cdecl VT7_GetSurfaceInfo(void* window, VT7_SURFACE_INFO* info);
    int32_t __cdecl VT7_ResetSurface(void* window);
    int32_t __cdecl VT7_SaveSurfaceCapture(void* window, const wchar_t* path);
    // Diagnostic sequence: apply(0), retain(1), full redraw(2), compare(3).
    // Operation 4 retains an intentionally altered CPU reference for negative tests.
    // Operation 5 compares sampled core state only, for cross-device recovery.
    // Operations 6/7 initialize/check the nonblank settings/reflow fixture.
    // Operation 8 retains the current settings frame; follow with 2/3, step zero.
    int32_t __cdecl VT7_SurfaceRepaintCheck(void* window, uint32_t operation, uint32_t step, wchar_t* report, uint32_t capacity);
    int32_t __cdecl VT7_RunCoreTests(wchar_t* report, uint32_t report_characters);
    // Capture-only fault seam. 1/2 finite Present removals, 3 persistent removals.
    int32_t __cdecl VT7_InjectSurfaceFailure(void* window, uint32_t fault);

    uint32_t __cdecl VT7_GetAbiVersion(void);
    int32_t __cdecl VT7_GetBuildInfo(VT7_BUILD_INFO* info);
    int32_t __cdecl VT7_GetPlatformInfo(VT7_PLATFORM_INFO* info);
    int32_t __cdecl VT7_ProbeGraphics(VT7_GRAPHICS_INFO* info);

#ifdef __cplusplus
}
#endif
