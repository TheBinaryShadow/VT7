// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#pragma once
#include <dwrite_1.h>
#include <wrl/client.h>
#include <array>
#include <span>
#include <string>
#include <vector>

namespace VT7::Text
{
    struct FaceMapping
    {
        UINT32 start = 0, end = 0;
        Microsoft::WRL::ComPtr<IDWriteFontFace1> face;
    };

    // Windows 7 layout is used only to select faces. Atlas retains its own
    // logical-order analyzer, cluster advances, colors and cell geometry.
    // Call under the renderer/core lock. Results own faces, never callback data.
    class FontFallback
    {
    public:
        explicit FontFallback(IDWriteFactory* factory);
        void Configure(IDWriteFontCollection* collection, const std::wstring& family,
            FLOAT emPixels, DWRITE_FONT_WEIGHT weight, const std::wstring& locale);
        std::vector<FaceMapping> Map(std::wstring_view text, std::span<const UINT16> columns, size_t attributes);
    private:
        Microsoft::WRL::ComPtr<IDWriteFactory> _factory;
        std::array<Microsoft::WRL::ComPtr<IDWriteTextFormat>, 4> _formats;
        std::array<std::vector<Microsoft::WRL::ComPtr<IDWriteFontFace1>>, 4> _privateFaces;
        struct Cached
        {
            std::wstring text;
            std::vector<UINT16> columns;
            size_t attributes;
            std::vector<FaceMapping> mappings;
        };
        std::vector<Cached> _cache;
        size_t _cachedUnits = 0;
    };
}
