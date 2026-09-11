// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#pragma once
#include "../../renderer/atlas/common.h"

namespace Microsoft::Console::Render::Atlas::Win7
{
    // All calls and resource destruction belong to one rendering thread.
    // Callers release backend resources before Resize/DestroySwapChain.
    void CreateDevice(RenderingPayload& p);
    void CreateSwapChain(RenderingPayload& p);
    void DestroySwapChain(RenderingPayload& p) noexcept;
    void ResizeSwapChain(RenderingPayload& p);
    HRESULT Present(RenderingPayload& p) noexcept;
}
