// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include "Win7TextMapper.hpp"
#include <wrl/implements.h>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <stdexcept>

using Microsoft::WRL::ComPtr;
using Microsoft::WRL::Make;
using Microsoft::WRL::RuntimeClass;
using Microsoft::WRL::RuntimeClassFlags;
using Microsoft::WRL::ClassicCom;

namespace VT7::Text
{
    namespace
    {
        void Require(bool condition, const char* reason) { if (!condition) throw std::runtime_error(reason); }
        void Hr(HRESULT hr) { if (FAILED(hr)) throw std::runtime_error("Windows 7 text mapper DirectWrite failure"); }
        bool Lead(wchar_t c) { return c >= 0xd800 && c <= 0xdbff; }
        bool Trail(wchar_t c) { return c >= 0xdc00 && c <= 0xdfff; }
        bool Boundary(const std::vector<Cell>& cells, UINT32 offset)
        {
            return offset == 0 || std::any_of(cells.begin(), cells.end(), [=](const Cell& c) { return c.textEnd == offset; });
        }
        bool Symbol(const std::wstring& text, UINT32 begin, UINT32 end, UINT32& scalar)
        {
            if (end - begin == 1 && !Lead(text[begin]) && !Trail(text[begin])) scalar = text[begin];
            else if (end - begin == 2 && Lead(text[begin]) && Trail(text[begin + 1]))
                scalar = 0x10000 + ((text[begin] - 0xd800) << 10) + text[begin + 1] - 0xdc00;
            else return false;
            return (scalar >= 0x2190 && scalar <= 0x2bff) || (scalar >= 0x1f000 && scalar <= 0x1faff);
        }
        struct FaceRange
        {
            ComPtr<IDWriteFontFace> face;
            UINT32 start, end, bidi;
            FLOAT emDip;
            bool missing, privateFallback = false;
        };
        class Faces final : public RuntimeClass<RuntimeClassFlags<ClassicCom>, IDWriteTextRenderer>
        {
        public:
            std::vector<FaceRange> ranges;
            HRESULT STDMETHODCALLTYPE IsPixelSnappingDisabled(void*, BOOL* output) noexcept override { if (!output) return E_POINTER; *output = TRUE; return S_OK; }
            HRESULT STDMETHODCALLTYPE GetCurrentTransform(void*, DWRITE_MATRIX* output) noexcept override { if (!output) return E_POINTER; *output = {1,0,0,1,0,0}; return S_OK; }
            HRESULT STDMETHODCALLTYPE GetPixelsPerDip(void*, FLOAT* output) noexcept override { if (!output) return E_POINTER; *output = 1; return S_OK; }
            HRESULT STDMETHODCALLTYPE DrawGlyphRun(void*, FLOAT, FLOAT, DWRITE_MEASURING_MODE,
                const DWRITE_GLYPH_RUN* run, const DWRITE_GLYPH_RUN_DESCRIPTION* desc, IUnknown*) noexcept override
            {
                if (!run || !desc || !run->fontFace || !run->glyphIndices || !run->glyphCount ||
                    !desc->stringLength || !desc->string || run->isSideways ||
                    desc->stringLength > UINT32_MAX - desc->textPosition) return E_INVALIDARG;
                try
                {
                    ranges.push_back({run->fontFace, desc->textPosition, desc->textPosition + desc->stringLength,
                        run->bidiLevel, run->fontEmSize,
                        std::find(run->glyphIndices, run->glyphIndices + run->glyphCount, 0) != run->glyphIndices + run->glyphCount});
                    return S_OK;
                }
                catch (...) { return E_OUTOFMEMORY; }
            }
            HRESULT STDMETHODCALLTYPE DrawUnderline(void*, FLOAT, FLOAT, const DWRITE_UNDERLINE*, IUnknown*) noexcept override { return E_NOTIMPL; }
            HRESULT STDMETHODCALLTYPE DrawStrikethrough(void*, FLOAT, FLOAT, const DWRITE_STRIKETHROUGH*, IUnknown*) noexcept override { return E_NOTIMPL; }
            HRESULT STDMETHODCALLTYPE DrawInlineObject(void*, FLOAT, FLOAT, IDWriteInlineObject*, BOOL, BOOL, IUnknown*) noexcept override { return E_NOTIMPL; }
        };
        struct ScriptRange { UINT32 start, end; DWRITE_SCRIPT_ANALYSIS script; };
        class Analysis final : public RuntimeClass<RuntimeClassFlags<ClassicCom>, IDWriteTextAnalysisSource, IDWriteTextAnalysisSink>
        {
        public:
            std::wstring text;
            std::vector<ScriptRange> scripts;
            HRESULT STDMETHODCALLTYPE GetTextAtPosition(UINT32 pos, const WCHAR** output, UINT32* count) noexcept override
            {
                if (!output || !count) return E_POINTER;
                *count = pos < text.size() ? static_cast<UINT32>(text.size()) - pos : 0;
                *output = *count ? text.data() + pos : nullptr; return S_OK;
            }
            HRESULT STDMETHODCALLTYPE GetTextBeforePosition(UINT32 pos, const WCHAR** output, UINT32* count) noexcept override
            {
                if (!output || !count) return E_POINTER;
                *count = std::min(pos, static_cast<UINT32>(text.size())); *output = *count ? text.data() : nullptr; return S_OK;
            }
            DWRITE_READING_DIRECTION STDMETHODCALLTYPE GetParagraphReadingDirection() noexcept override { return DWRITE_READING_DIRECTION_LEFT_TO_RIGHT; }
            HRESULT STDMETHODCALLTYPE GetLocaleName(UINT32 pos, UINT32* count, const WCHAR** output) noexcept override
            {
                if (!count || !output) return E_POINTER;
                *count = pos < text.size() ? static_cast<UINT32>(text.size()) - pos : 0; *output = L"en-US"; return S_OK;
            }
            HRESULT STDMETHODCALLTYPE GetNumberSubstitution(UINT32 pos, UINT32* count, IDWriteNumberSubstitution** output) noexcept override
            {
                if (!count || !output) return E_POINTER;
                *count = pos < text.size() ? static_cast<UINT32>(text.size()) - pos : 0; *output = nullptr; return S_OK;
            }
            HRESULT STDMETHODCALLTYPE SetScriptAnalysis(UINT32 pos, UINT32 count, const DWRITE_SCRIPT_ANALYSIS* script) noexcept override
            {
                if (!script || !count || pos > text.size() || count > text.size() - pos) return E_INVALIDARG;
                try { scripts.push_back({pos, pos + count, *script}); return S_OK; } catch (...) { return E_OUTOFMEMORY; }
            }
            HRESULT STDMETHODCALLTYPE SetLineBreakpoints(UINT32, UINT32, const DWRITE_LINE_BREAKPOINT*) noexcept override { return E_NOTIMPL; }
            HRESULT STDMETHODCALLTYPE SetBidiLevel(UINT32, UINT32, UINT8, UINT8) noexcept override { return E_NOTIMPL; }
            HRESULT STDMETHODCALLTYPE SetNumberSubstitution(UINT32, UINT32, IDWriteNumberSubstitution*) noexcept override { return E_NOTIMPL; }
        };

        GlyphRun Shape(IDWriteTextAnalyzer* analyzer, const FaceRange& face, const ScriptRange& script,
            const Snapshot& snapshot, UINT32 begin, UINT32 end)
        {
            Require(Boundary(snapshot.cells, begin) && Boundary(snapshot.cells, end), "Font/script boundary bisects core cluster");
            GlyphRun result;
            Hr(face.face.As(&result.face)); // Real FontFace1, not a cast to a newer interface.
            result.textStart = begin; result.textEnd = end; result.layoutBidi = face.bidi;
            result.emPixels = face.emDip * snapshot.key.dpi / 96.f;
            result.privateFallback = face.privateFallback;
            Require(std::isfinite(result.emPixels) && result.emPixels > 0, "Invalid mapped em size");
            const auto length = end - begin;
            std::vector<DWRITE_SHAPING_TEXT_PROPERTIES> textProps(length);
            result.clusters.resize(length);
            UINT32 count = 0, capacity = length * 3 / 2 + 16;
            std::vector<DWRITE_SHAPING_GLYPH_PROPERTIES> glyphProps;
            for (;;)
            {
                result.glyphs.resize(capacity); glyphProps.resize(capacity);
                const auto hr = analyzer->GetGlyphs(snapshot.text.data() + begin, length, result.face.Get(), FALSE, FALSE,
                    &script.script, L"en-US", nullptr, nullptr, nullptr, 0, capacity, result.clusters.data(),
                    textProps.data(), result.glyphs.data(), glyphProps.data(), &count);
                if (hr == HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER) && capacity < 65535)
                { capacity = std::min<UINT32>(65535, capacity * 2); continue; }
                Hr(hr); break;
            }
            Require(count > 0 && count <= 65535, "Invalid mapped glyph count");
            result.glyphs.resize(count); result.advances.resize(count); result.offsets.resize(count);
            Require(result.clusters.front() == 0 && std::is_sorted(result.clusters.begin(), result.clusters.end()) &&
                result.clusters.back() < count, "Analyzer did not produce logical-order clusters");
            Hr(analyzer->GetGlyphPlacements(snapshot.text.data() + begin, result.clusters.data(), textProps.data(), length,
                result.glyphs.data(), glyphProps.data(), count, result.face.Get(), result.emPixels, FALSE, FALSE,
                &script.script, L"en-US", nullptr, nullptr, 0, result.advances.data(), result.offsets.data()));
            for (UINT32 g = 0; g < count; ++g)
                Require(std::isfinite(result.advances[g]) && result.advances[g] >= 0 &&
                    std::isfinite(result.offsets[g].advanceOffset) && std::isfinite(result.offsets[g].ascenderOffset), "Invalid analyzer geometry");
            result.naturalAdvances = result.advances;
            // The intersection of shaping and core boundaries owns each group.
            // A ligature may cover several cells; marks may create several glyphs.
            UINT32 first = 0;
            for (UINT32 next = 1; next <= length; ++next)
            {
                if (next < length && (result.clusters[next] == result.clusters[next - 1] || !Boundary(snapshot.cells, begin + next))) continue;
                const auto cell = std::find_if(snapshot.cells.begin(), snapshot.cells.end(), [&](const Cell& c) { return c.textStart == begin + first; });
                const auto last = std::find_if(snapshot.cells.begin(), snapshot.cells.end(), [&](const Cell& c) { return c.textEnd == begin + next; });
                Require(cell != snapshot.cells.end() && last != snapshot.cells.end(), "Missing core group boundary");
                const UINT32 g0 = result.clusters[first], g1 = next == length ? count : result.clusters[next];
                Require(g0 < g1, "Empty logical glyph group");
                result.groups.push_back({begin + first, begin + next, cell->cellStart, last->cellEnd, g0, g1});
                const auto advance = std::accumulate(result.advances.begin() + g0, result.advances.begin() + g1, 0.f);
                const auto expected = static_cast<FLOAT>((last->cellEnd - cell->cellStart) * snapshot.metrics.width);
                // Match Atlas's advance correction, not the earlier probe's ink
                // compression. This preserves glyph proportions and may overhang.
                result.advances[g1 - 1] += expected - advance;
                first = next;
            }
            Require(first == length, "Incomplete logical mapping");
            return result;
        }
    }

    Mapper::Mapper(IDWriteFactory* factory, std::wstring family, std::vector<ComPtr<IDWriteFontFace>> privateFaces) :
        _factory(factory), _family(std::move(family)), _private(std::move(privateFaces))
    {
        Require(factory && !_family.empty(), "Missing mapper factory or family");
        for (const auto& face : _private) Require(face != nullptr, "Null private face");
        Hr(factory->CreateTextAnalyzer(&_analyzer));
        ComPtr<IDWriteFontCollection> collection; Hr(factory->GetSystemFontCollection(&collection, FALSE));
        UINT32 index = 0; BOOL exists = FALSE; Hr(collection->FindFamilyName(_family.c_str(), &index, &exists));
        Require(exists != FALSE, "Mapper primary family unavailable");
        ComPtr<IDWriteFontFamily> familyObject; ComPtr<IDWriteFont> font;
        Hr(collection->GetFontFamily(index, &familyObject));
        Hr(familyObject->GetFirstMatchingFont(DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STRETCH_NORMAL, DWRITE_FONT_STYLE_NORMAL, &font));
        Hr(font->CreateFontFace(&_primary));
    }
    Metrics Mapper::Grid(const Key& key) const
    {
        Require(key.buffer && key.revision && key.font && key.columns && key.columns <= 32767 &&
            key.dpi >= 48 && key.dpi <= 768 && std::isfinite(key.emDip) && key.emDip >= 4 && key.emDip <= 96, "Invalid mapper key");
        DWRITE_FONT_METRICS metrics{}; _primary->GetMetrics(&metrics);
        Require(metrics.designUnitsPerEm > 0, "Invalid primary font metrics");
        const auto em = key.emDip * key.dpi / 96.f;
        const auto unit = em / metrics.designUnitsPerEm;
        const auto ascent = metrics.ascent * unit, gap = metrics.lineGap * unit;
        const auto naturalHeight = ascent + metrics.descent * unit + gap;
        FLOAT advance = em * .5f;
        const UINT32 scalar = L'0'; UINT16 glyph = 0; Hr(_primary->GetGlyphIndices(&scalar, 1, &glyph));
        if (glyph)
        {
            DWRITE_GLYPH_METRICS gm{}; Hr(_primary->GetDesignGlyphMetrics(&glyph, 1, &gm)); advance = gm.advanceWidth * unit;
        }
        const auto height = std::max(1.f, std::round(naturalHeight));
        const auto baseline = std::round(ascent + (gap + height - naturalHeight) / 2.f);
        Require(baseline >= 0 && baseline <= height, "Unusable primary baseline");
        return {static_cast<UINT32>(std::max(1.f, std::round(advance))), static_cast<UINT32>(height), static_cast<UINT32>(baseline), em};
    }
    void Mapper::ValidateKey(const Snapshot& snapshot, const Key& expected)
    {
        Require(snapshot.key == expected, "Stale text mapper snapshot");
    }
    Snapshot Mapper::Map(const Key& key, const std::wstring& text, const std::vector<Cell>& cells,
        const std::vector<Style>& styles, bool forcePrivateForTest) const
    {
        Snapshot result{key, Grid(key), text, cells, {}};
        // A bounded candidate, not a shipping terminal-line length limit.
        Require(!text.empty() && text.size() <= 4096 && !cells.empty(), "Invalid mapper source size");
        for (size_t i = 0; i < text.size(); ++i)
        {
            Require(text[i] >= 0x20 && !(text[i] >= 0x7f && text[i] <= 0x9f) && !Trail(text[i]), "Invalid mapper source character");
            if (Lead(text[i])) { Require(i + 1 < text.size() && Trail(text[i + 1]), "Unpaired mapper surrogate"); ++i; }
        }
        UINT32 end = 0, column = 0;
        for (const auto& cell : cells)
        {
            Require(cell.textStart == end && cell.textEnd > end && cell.textEnd <= text.size() &&
                cell.cellStart == column && cell.cellEnd > column && cell.cellEnd <= key.columns &&
                !Trail(text[cell.textStart]) && !Lead(text[cell.textEnd - 1]), "Invalid mapper core spans");
            end = cell.textEnd; column = cell.cellEnd;
        }
        Require(end == text.size(), "Incomplete mapper source coverage");
        auto styleList = styles;
        if (styleList.empty()) styleList.push_back({0, end});
        end = 0;
        for (const auto& style : styleList)
        {
            Require(style.start == end && style.end > end && style.end <= text.size() && Boundary(cells, style.end) &&
                style.weight >= 1 && style.weight <= 999 && style.style >= DWRITE_FONT_STYLE_NORMAL && style.style <= DWRITE_FONT_STYLE_ITALIC,
                "Invalid mapper style boundary");
            end = style.end;
        }
        Require(end == text.size(), "Incomplete mapper style coverage");
        std::vector<FaceRange> faces;
        {
            ComPtr<IDWriteTextFormat> format;
            Hr(_factory->CreateTextFormat(_family.c_str(), nullptr, DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL,
                DWRITE_FONT_STRETCH_NORMAL, key.emDip, L"en-US", &format));
            Hr(format->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP));
            ComPtr<IDWriteTextLayout> layout;
            Hr(_factory->CreateTextLayout(text.data(), static_cast<UINT32>(text.size()), format.Get(), 1000000, 10000, &layout));
            for (const auto& style : styleList)
            {
                Hr(layout->SetFontWeight(style.weight, {style.start, style.end - style.start}));
                Hr(layout->SetFontStyle(style.style, {style.start, style.end - style.start}));
            }
            auto collector = Make<Faces>(); Require(collector != nullptr, "Mapper collector allocation failed");
            Hr(layout->Draw(nullptr, collector.Get(), 0, 0)); faces = std::move(collector->ranges);
        } // All callback/layout owners are destroyed before analyzer shaping.
        std::sort(faces.begin(), faces.end(), [](const auto& a, const auto& b) { return a.start < b.start; });
        end = 0;
        for (auto& face : faces)
        {
            Require(face.start == end && face.end > end && face.end <= text.size() && Boundary(cells, face.end), "Font boundary bisects core cluster or source coverage");
            end = face.end;
            UINT32 scalar = 0;
            const auto cell = std::find_if(cells.begin(), cells.end(), [&](const Cell& c) { return c.textStart == face.start && c.textEnd == face.end; });
            const auto style = std::find_if(styleList.begin(), styleList.end(), [&](const Style& s) { return s.start <= face.start && s.end >= face.end; });
            // Do not silently discard a requested style by substituting a regular
            // private face. Styled missing symbols remain reported glyph-zero
            // cases until simulation/variant policy has its own acceptance.
            if ((face.missing || forcePrivateForTest) && cell != cells.end() && !(face.bidi & 1) &&
                style != styleList.end() && style->weight == DWRITE_FONT_WEIGHT_NORMAL && style->style == DWRITE_FONT_STYLE_NORMAL &&
                Symbol(text, face.start, face.end, scalar))
            {
                for (const auto& candidate : _private)
                {
                    UINT16 glyph = 0; Hr(candidate->GetGlyphIndices(&scalar, 1, &glyph));
                    if (glyph) { face.face = candidate; face.privateFallback = true; break; }
                }
            }
        }
        Require(end == text.size(), "Incomplete font mapping coverage");
        auto analysis = Make<Analysis>(); Require(analysis != nullptr, "Mapper analysis allocation failed");
        analysis->text = text; Hr(_analyzer->AnalyzeScript(analysis.Get(), 0, end, analysis.Get()));
        std::sort(analysis->scripts.begin(), analysis->scripts.end(), [](const auto& a, const auto& b) { return a.start < b.start; });
        end = 0;
        for (const auto& script : analysis->scripts)
        {
            Require(script.start == end && script.end > end, "Incomplete script analysis"); end = script.end;
            for (const auto& face : faces)
            {
                const auto begin = std::max(script.start, face.start), finish = std::min(script.end, face.end);
                if (begin < finish) result.runs.push_back(Shape(_analyzer.Get(), face, script, result, begin, finish));
            }
        }
        Require(end == text.size(), "Incomplete script coverage");
        return result;
    }
}
