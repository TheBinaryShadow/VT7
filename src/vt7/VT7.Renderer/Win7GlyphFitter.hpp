// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#pragma once
#include "Win7TextMapper.hpp"

namespace VT7::Text
{
    struct Placement
    {
        size_t run, group;
        FLOAT scaleX = 1, offsetX = 0;
        UINT32 halo = 0, retries = 0;
        bool compressed = false;
        RECT naturalInk{}, ink{}; // Relative to the group's cell-left and baseline.
    };
    struct FittedRow
    {
        Snapshot source;
        Microsoft::WRL::ComPtr<IDWriteRenderingParams> parameters;
        std::vector<Placement> placements;
    };

    // Candidate bitmap-raster fitting, not an Atlas cache or GPU implementation.
    // Measurements and drawing use the same retained rendering parameters and
    // integer pixel origin. The original source, glyphs and advances are untouched.
    class GlyphFitter
    {
    public:
        GlyphFitter(IDWriteFactory* factory, IDWriteRenderingParams* parameters);
        FittedRow Prepare(const Snapshot& source, const Key& expected);
        static RECT Draw(const FittedRow& row, size_t placement, IDWriteBitmapRenderTarget* target,
            LONG rowLeft, LONG baseline, COLORREF color);
    private:
        RECT Measure(const DWRITE_GLYPH_RUN& glyphs, const RECT& predicted, FLOAT scale, FLOAT offset);
        Microsoft::WRL::ComPtr<IDWriteFactory> _factory;
        Microsoft::WRL::ComPtr<IDWriteGdiInterop> _interop;
        Microsoft::WRL::ComPtr<IDWriteRenderingParams> _parameters;
        Microsoft::WRL::ComPtr<IDWriteBitmapRenderTarget> _scratch;
    };
}
