// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#pragma once

#include "../../renderer/inc/IRenderData.hpp"
#include "../../renderer/inc/RenderSettings.hpp"

namespace Microsoft::Console::Render
{
    // The proof paints synchronously on the HWND's UI thread. This adapter
    // translates core invalidations into a dirty generation without a render thread.
    // Atlas, soft fonts, animation, and accessibility notifications are later work.
    class Renderer
    {
    public:
        void NotifyPaintFrame() noexcept { ++_generation; }
        void TriggerRedraw(const Types::Viewport&) noexcept { NotifyPaintFrame(); }
        void TriggerRedrawAll(bool = false, bool = false) noexcept { NotifyPaintFrame(); }
        void TriggerScroll(const til::point* = nullptr) noexcept { NotifyPaintFrame(); }
        void TriggerNewTextNotification(std::wstring_view) noexcept { NotifyPaintFrame(); }
        void TriggerSelection() noexcept { NotifyPaintFrame(); }
        void SynchronizedOutputChanged() noexcept { NotifyPaintFrame(); }
        void UpdateSoftFont(std::span<const uint16_t>, til::size, size_t) noexcept { ++_unsupportedSoftFonts; }
        uint64_t Generation() const noexcept { return _generation; }
    private:
        uint64_t _generation = 0;
        uint64_t _unsupportedSoftFonts = 0;
    };
}
