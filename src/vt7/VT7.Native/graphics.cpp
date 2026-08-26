#include "include/vt7_native.h"

#include <Windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>

#include <cwchar>

namespace
{
    template<typename T>
    void release(T*& value) noexcept
    {
        if (value != nullptr)
        {
            value->Release();
            value = nullptr;
        }
    }

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

    HRESULT create_device(
        IDXGIAdapter* adapter,
        const D3D_DRIVER_TYPE driverType,
        uint32_t& featureLevel) noexcept
    {
        static constexpr D3D_FEATURE_LEVEL requestedLevels[]{
            D3D_FEATURE_LEVEL_11_0,
            D3D_FEATURE_LEVEL_10_1,
            D3D_FEATURE_LEVEL_10_0,
            D3D_FEATURE_LEVEL_9_3,
            D3D_FEATURE_LEVEL_9_2,
            D3D_FEATURE_LEVEL_9_1,
        };

        ID3D11Device* device = nullptr;
        ID3D11DeviceContext* context = nullptr;
        D3D_FEATURE_LEVEL selectedLevel{};

        const auto result = D3D11CreateDevice(
            adapter,
            driverType,
            nullptr,
            D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            requestedLevels,
            _countof(requestedLevels),
            D3D11_SDK_VERSION,
            &device,
            &selectedLevel,
            &context);

        if (SUCCEEDED(result))
        {
            featureLevel = static_cast<uint32_t>(selectedLevel);
        }

        release(context);
        release(device);
        return result;
    }
}

int32_t __cdecl VT7_ProbeGraphics(VT7_GRAPHICS_INFO* info)
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
    info->factory_hresult = static_cast<int32_t>(E_FAIL);
    info->hardware_hresult = static_cast<int32_t>(E_FAIL);
    info->warp_hresult = static_cast<int32_t>(E_FAIL);
    copy_text(info->adapter_description, L"No adapter detected");

    IDXGIFactory1* factory = nullptr;
    const auto factoryResult = CreateDXGIFactory1(IID_PPV_ARGS(&factory));
    info->factory_hresult = static_cast<int32_t>(factoryResult);

    if (SUCCEEDED(factoryResult))
    {
        IDXGIFactory2* factory2 = nullptr;
        if (SUCCEEDED(factory->QueryInterface(IID_PPV_ARGS(&factory2))))
        {
            info->supports_dxgi_1_2 = 1;
            release(factory2);
        }

        IDXGIAdapter1* adapter = nullptr;
        if (SUCCEEDED(factory->EnumAdapters1(0, &adapter)))
        {
            DXGI_ADAPTER_DESC1 description{};
            if (SUCCEEDED(adapter->GetDesc1(&description)))
            {
                copy_text(info->adapter_description, description.Description);
                info->dedicated_video_memory = static_cast<uint64_t>(description.DedicatedVideoMemory);
                info->adapter_is_software =
                    (description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0 ? 1u : 0u;
            }

            const auto hardwareResult = create_device(
                adapter,
                D3D_DRIVER_TYPE_UNKNOWN,
                info->hardware_feature_level);
            info->hardware_hresult = static_cast<int32_t>(hardwareResult);
            release(adapter);
        }

        release(factory);
    }

    const auto warpResult = create_device(
        nullptr,
        D3D_DRIVER_TYPE_WARP,
        info->warp_feature_level);
    info->warp_hresult = static_cast<int32_t>(warpResult);

    return static_cast<int32_t>(S_OK);
}
