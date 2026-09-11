// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include "Win7GlyphFitter.hpp"
#include <wil/resource.h>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <stdexcept>

namespace VT7::Text
{
    namespace
    {
        void FitCheck(bool good, const char* message) { if (!good) throw std::runtime_error(message); }
        void FitHr(HRESULT hr) { if (FAILED(hr)) throw std::runtime_error("Glyph fitter DirectWrite failure"); }
        bool HasInk(const RECT& ink) { return ink.right > ink.left && ink.bottom > ink.top; }
        DWRITE_GLYPH_RUN Glyphs(const GlyphRun& run, const Group& group)
        {
            FitCheck(run.face && group.glyphStart < group.glyphEnd && group.glyphEnd <= run.glyphs.size() &&
                run.naturalAdvances.size() == run.glyphs.size() && run.offsets.size() == run.glyphs.size(), "Invalid fitter glyph arrays");
            return {run.face.Get(), run.emPixels, group.glyphEnd - group.glyphStart, run.glyphs.data() + group.glyphStart,
                run.naturalAdvances.data() + group.glyphStart, run.offsets.data() + group.glyphStart, FALSE, 0};
        }
    }
    GlyphFitter::GlyphFitter(IDWriteFactory* factory, IDWriteRenderingParams* parameters) : _factory(factory), _parameters(parameters)
    {
        FitCheck(factory && parameters, "Missing fitter factory or parameters");
        FitHr(factory->GetGdiInterop(&_interop));
        FitHr(_interop->CreateBitmapRenderTarget(nullptr, 1, 1, &_scratch));
        FitHr(_scratch->SetPixelsPerDip(1));
    }
    RECT GlyphFitter::Measure(const DWRITE_GLYPH_RUN& glyphs, const RECT& predicted, FLOAT scale, FLOAT offset)
    {
        // Padding accommodates small differences between alpha analysis and the
        // actual bitmap rasterizer. Reject a too-large scratch allocation rather
        // than accepting a clipped measurement as a successful fit.
        const auto left = std::floor(std::min(0.f, predicted.left * scale + offset));
        const auto right = std::ceil(std::max(0.f, predicted.right * scale + offset));
        const auto top = std::min<LONG>(0, predicted.top), bottom = std::max<LONG>(0, predicted.bottom);
        const auto width = right - left + 128;
        const auto height = static_cast<double>(bottom) - top + 128;
        FitCheck(width >= 128 && height >= 128 && width <= 8192 && height <= 8192 && width * height <= 16777216,
            "Glyph fitter scratch bound exceeded");
        FitHr(_scratch->Resize(static_cast<UINT32>(width), static_cast<UINT32>(height)));
        const LONG x = static_cast<LONG>(64 - left), y = 64 - top;
        const DWRITE_MATRIX transform{scale,0,0,1,x + offset,static_cast<FLOAT>(y)};
        FitHr(_scratch->SetCurrentTransform(&transform));
        RECT ink{};
        FitHr(_scratch->DrawGlyphRun(0,0,DWRITE_MEASURING_MODE_NATURAL,&glyphs,_parameters.Get(),RGB(235,235,235),&ink));
        FitCheck(!HasInk(ink) || (ink.left > 0 && ink.top > 0 && ink.right < width && ink.bottom < height), "Fitter measurement touched scratch edge");
        OffsetRect(&ink,-x,-y);
        return ink;
    }
    FittedRow GlyphFitter::Prepare(const Snapshot& source, const Key& expected)
    {
        Mapper::ValidateKey(source,expected);
        FitCheck(source.metrics.width > 0 && source.metrics.width <= 1024 && source.metrics.height > 0 &&
            !source.runs.empty(), "Invalid fitter metrics or empty source");
        FittedRow result{source,_parameters,{}};
        UINT32 sourceEnd = 0, cellEnd = 0;
        for (size_t r = 0; r < source.runs.size(); ++r)
        {
            const auto& run = source.runs[r];
            FitCheck(run.textStart == sourceEnd && std::isfinite(run.emPixels) && run.emPixels > 0 && !run.groups.empty(), "Invalid fitter run");
            UINT32 glyphEnd = 0;
            for (size_t g = 0; g < run.groups.size(); ++g)
            {
                const auto& group = run.groups[g];
                FitCheck(group.textStart == sourceEnd && group.textEnd > sourceEnd && group.textEnd <= source.text.size() &&
                    group.cellStart == cellEnd && group.cellEnd > cellEnd && group.cellEnd <= expected.columns &&
                    group.glyphStart == glyphEnd, "Invalid fitter group coverage");
                const auto glyphs = Glyphs(run,group);
                for (UINT32 i = 0; i < glyphs.glyphCount; ++i)
                    FitCheck(std::isfinite(glyphs.glyphAdvances[i]) && glyphs.glyphAdvances[i] >= 0 &&
                        std::isfinite(glyphs.glyphOffsets[i].advanceOffset) && std::isfinite(glyphs.glyphOffsets[i].ascenderOffset), "Invalid fitter geometry");
                const auto allocated = static_cast<FLOAT>((group.cellEnd-group.cellStart)*source.metrics.width);
                const auto advance = std::accumulate(glyphs.glyphAdvances,glyphs.glyphAdvances+glyphs.glyphCount,0.f);
                Microsoft::WRL::ComPtr<IDWriteGlyphRunAnalysis> analysis;
                FitHr(_factory->CreateGlyphRunAnalysis(&glyphs,1,nullptr,DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC,
                    DWRITE_MEASURING_MODE_NATURAL,0,0,&analysis));
                RECT predicted{}; FitHr(analysis->GetAlphaTextureBounds(DWRITE_TEXTURE_CLEARTYPE_3x1,&predicted));
                Placement p{r,g}; p.naturalInk = Measure(glyphs,predicted,1,0); p.ink = p.naturalInk;
                // Grid-scaled candidate allowance, not a universal shipping
                // constant. At a ten-pixel cell this matches the prior two pixels.
                p.halo = std::max<UINT32>(1,(source.metrics.width+4)/5);
                const auto roundingAllowance = .5f*(group.cellEnd-group.cellStart);
                if (HasInk(p.ink) && (advance > allocated+roundingAllowance || p.ink.left < -static_cast<LONG>(p.halo) ||
                    p.ink.right > allocated+p.halo))
                {
                    p.compressed = true; p.halo = 0;
                    const auto left = std::min(0.f,static_cast<FLOAT>(std::min(predicted.left,p.naturalInk.left)));
                    const auto right = std::max(advance,static_cast<FLOAT>(std::max(predicted.right,p.naturalInk.right)));
                    FitCheck(right > left, "Invalid fitter ink extent");
                    // Start with the full available width. The measured raster
                    // bounds, not a permanent inset, decide whether to shrink.
                    p.scaleX = std::min(1.f,allocated/(right-left));
                    for (;;)
                    {
                        FitCheck(std::isfinite(p.scaleX) && p.scaleX > 0, "Invalid fitter transform");
                        p.offsetX = (allocated-(right-left)*p.scaleX)/2-left*p.scaleX;
                        p.ink = Measure(glyphs,predicted,p.scaleX,p.offsetX);
                        FitCheck(HasInk(p.ink), "Horizontal fitting erased nonempty glyph ink");
                        if (p.ink.left >= 0 && p.ink.right <= allocated) break;
                        FitCheck(p.retries++ < 16, "Horizontal raster fitting failed to converge");
                        p.scaleX *= .95f;
                    }
                }
                result.placements.push_back(p);
                sourceEnd = group.textEnd; cellEnd = group.cellEnd; glyphEnd = group.glyphEnd;
            }
            FitCheck(sourceEnd == run.textEnd && glyphEnd == run.glyphs.size(), "Incomplete fitter run coverage");
        }
        FitCheck(sourceEnd == source.text.size(), "Incomplete fitter source coverage");
        return result;
    }
    RECT GlyphFitter::Draw(const FittedRow& row, size_t placement, IDWriteBitmapRenderTarget* target, LONG rowLeft, LONG baseline, COLORREF color)
    {
        FitCheck(target && row.parameters && placement < row.placements.size() && target->GetPixelsPerDip() == 1, "Invalid fitted draw target");
        const auto& p = row.placements[placement];
        FitCheck(p.run < row.source.runs.size(), "Invalid fitted draw run");
        const auto& run = row.source.runs[p.run];
        FitCheck(p.group < run.groups.size(), "Invalid fitted draw group");
        const auto& group = run.groups[p.group]; const auto glyphs = Glyphs(run,group);
        const auto x = static_cast<double>(rowLeft)+static_cast<double>(group.cellStart)*row.source.metrics.width;
        FitCheck(std::isfinite(p.scaleX) && p.scaleX > 0 && p.scaleX <= 1 && std::isfinite(p.offsetX) &&
            x > -1000000 && x < 1000000 && baseline > -1000000 && baseline < 1000000, "Invalid fitted draw transform");
        DWRITE_MATRIX previous{}; FitHr(target->GetCurrentTransform(&previous));
        const auto restore = wil::scope_exit([&] { target->SetCurrentTransform(&previous); });
        const DWRITE_MATRIX transform{p.scaleX,0,0,1,static_cast<FLOAT>(x)+p.offsetX,static_cast<FLOAT>(baseline)};
        FitHr(target->SetCurrentTransform(&transform));
        RECT ink{}; FitHr(target->DrawGlyphRun(0,0,DWRITE_MEASURING_MODE_NATURAL,&glyphs,row.parameters.Get(),color,&ink));
        const auto allocation = static_cast<double>(group.cellEnd-group.cellStart)*row.source.metrics.width;
        FitCheck(!HasInk(ink) || (ink.left >= x-p.halo && ink.right <= x+allocation+p.halo), "Horizontal neighbor protection failed");
        // Returning actual ink lets callers include legal overhang in damage.
        // Do not impose a row-height clip or change original source/cell ownership.
        return ink;
    }
}
