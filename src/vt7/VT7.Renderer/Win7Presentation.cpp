// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include "../../renderer/atlas/pch.h"
#include "Win7Presentation.hpp"

namespace Microsoft::Console::Render::Atlas::Win7
{
    void CreateDevice(RenderingPayload& p)
    {
        // No adapter enumeration shortcut for WARP on Windows 7. Request it
        // explicitly, and derive the factory from the device actually created.
        const bool warp = p.s->target->useWARP;
        const auto driver = warp ? D3D_DRIVER_TYPE_WARP : D3D_DRIVER_TYPE_HARDWARE;
        UINT flags = D3D11_CREATE_DEVICE_SINGLETHREADED | D3D11_CREATE_DEVICE_BGRA_SUPPORT;
        if (!warp) flags |= D3D11_CREATE_DEVICE_PREVENT_INTERNAL_THREADING_OPTIMIZATIONS;
#ifndef NDEBUG
        flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif
        constexpr D3D_FEATURE_LEVEL levels[]{ D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0 };
        wil::com_ptr<ID3D11Device> device;
        wil::com_ptr<ID3D11DeviceContext> context;
        auto create = [&] {
            return D3D11CreateDevice(nullptr, driver, nullptr, flags, levels, ARRAYSIZE(levels),
                D3D11_SDK_VERSION, device.put(), nullptr, context.put());
        };
        auto hr = create();
#ifndef NDEBUG
        if (hr == DXGI_ERROR_SDK_COMPONENT_MISSING)
        {
            flags &= ~D3D11_CREATE_DEVICE_DEBUG;
            hr = create();
        }
#endif
        THROW_IF_FAILED(hr);
        // Publish only after every required interface query has succeeded.
        auto device1 = device.query<ID3D11Device1>();
        auto context1 = context.query<ID3D11DeviceContext1>();
        const auto dxgiDevice = device.query<IDXGIDevice>();
        wil::com_ptr<IDXGIAdapter> adapter;
        THROW_IF_FAILED(dxgiDevice->GetAdapter(adapter.put()));
        auto adapter1 = adapter.query<IDXGIAdapter1>();
        DXGI_ADAPTER_DESC1 desc{};
        THROW_IF_FAILED(adapter1->GetDesc1(&desc));
        wil::com_ptr<IDXGIFactory2> factory;
        THROW_IF_FAILED(adapter->GetParent(IID_PPV_ARGS(factory.put())));
        p.dxgi.factory = std::move(factory);
        p.dxgi.adapter = std::move(adapter1);
        p.dxgi.adapterLuid = desc.AdapterLuid;
        // WARP's Windows 7 descriptor need not contain SOFTWARE or useful IDs.
        p.dxgi.adapterFlags = warp ? DXGI_ADAPTER_FLAG_SOFTWARE : desc.Flags;
        p.device = std::move(device1);
        p.deviceContext = std::move(context1);
    }

    void DestroySwapChain(RenderingPayload& p) noexcept
    {
        p.swapChain = {};
        if (p.deviceContext)
        {
            p.deviceContext->ClearState();
            p.deviceContext->Flush();
        }
    }

    void CreateSwapChain(RenderingPayload& p)
    {
        THROW_HR_IF(E_INVALIDARG, !p.s->target->hwnd || !p.s->targetSize.x || !p.s->targetSize.y || p.s->target->useAlpha);
        DestroySwapChain(p);
        const DXGI_SWAP_CHAIN_DESC1 desc{
            .Width = p.s->targetSize.x,
            .Height = p.s->targetSize.y,
            .Format = DXGI_FORMAT_B8G8R8A8_UNORM,
            .SampleDesc = { 1, 0 },
            .BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
            .BufferCount = 1,
            .Scaling = DXGI_SCALING_STRETCH,
            .SwapEffect = DXGI_SWAP_EFFECT_DISCARD,
            .AlphaMode = DXGI_ALPHA_MODE_UNSPECIFIED,
            .Flags = 0,
        };
        THROW_IF_FAILED(p.dxgi.factory->CreateSwapChainForHwnd(p.device.get(), p.s->target->hwnd,
            &desc, nullptr, nullptr, p.swapChain.swapChain.put()));
        THROW_IF_FAILED(p.dxgi.factory->MakeWindowAssociation(p.s->target->hwnd, DXGI_MWA_NO_ALT_ENTER));
        p.swapChain.targetGeneration = p.s->target.generation();
        p.swapChain.targetSize = p.s->targetSize;
        p.MarkAllAsDirty();
    }

    void ResizeSwapChain(RenderingPayload& p)
    {
        THROW_HR_IF(E_INVALIDARG, !p.s->targetSize.x || !p.s->targetSize.y);
        p.deviceContext->ClearState();
        p.deviceContext->Flush();
        THROW_IF_FAILED(p.swapChain.swapChain->ResizeBuffers(1, p.s->targetSize.x, p.s->targetSize.y, DXGI_FORMAT_UNKNOWN, 0));
        p.swapChain.targetSize = p.s->targetSize;
        p.MarkAllAsDirty();
    }

    HRESULT Present(RenderingPayload& p) noexcept
    {
        // DISCARD does not preserve the back buffer. Every call must follow a
        // full backend redraw. No Present1 scroll/dirty rectangles or waitable
        // object. The owner schedules invalidations and parks while hidden.
        return p.swapChain.swapChain->Present(1, 0);
    }
}
