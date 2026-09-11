// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#pragma once
#include <windows.h>
#include <dwrite_1.h>
#include <wrl/client.h>
#include <cstdint>
#include <string>
#include <vector>

namespace VT7::Text
{
    // Owned, logical-order input. The caller obtains cells from TerminalCore.
    // No font, bidi, or width-detector API is allowed to invent these spans.
    struct Cell { UINT32 textStart, textEnd, cellStart, cellEnd; bool operator==(const Cell&) const = default; };
    struct Style
    {
        UINT32 start, end;
        DWRITE_FONT_WEIGHT weight = DWRITE_FONT_WEIGHT_NORMAL;
        DWRITE_FONT_STYLE style = DWRITE_FONT_STYLE_NORMAL;
    };
    struct Key
    {
        uint64_t buffer = 0, revision = 0, font = 0;
        UINT32 row = 0, columns = 0, dpi = 96;
        FLOAT emDip = 18;
        bool operator==(const Key&) const = default;
    };
    struct Metrics { UINT32 width, height, baseline; FLOAT emPixels; };
    struct Group { UINT32 textStart, textEnd, cellStart, cellEnd, glyphStart, glyphEnd; };
    struct GlyphRun
    {
        Microsoft::WRL::ComPtr<IDWriteFontFace1> face;
        UINT32 textStart = 0, textEnd = 0, layoutBidi = 0;
        FLOAT emPixels = 0;
        bool privateFallback = false;
        std::vector<UINT16> glyphs, clusters;
        std::vector<FLOAT> naturalAdvances, advances;
        std::vector<DWRITE_GLYPH_OFFSET> offsets;
        std::vector<Group> groups;
    };
    struct Snapshot
    {
        Key key;
        Metrics metrics;
        std::wstring text;
        std::vector<Cell> cells;
        std::vector<GlyphRun> runs;
    };

    // Candidate adapter, not connected to AtlasEngine yet. DirectWrite layout
    // chooses faces only; the analyzer shapes source order like upstream Atlas
    // (isRightToLeft=false). There is deliberately no visual paragraph reordering.
    // No callback pointers or layout objects survive Map(). No cache or threading
    // policy is implied: callers currently construct and use this on one thread.
    class Mapper
    {
    public:
        Mapper(IDWriteFactory* factory, std::wstring family,
            std::vector<Microsoft::WRL::ComPtr<IDWriteFontFace>> privateFaces = {});
        Snapshot Map(const Key& key, const std::wstring& text, const std::vector<Cell>& cells,
            const std::vector<Style>& styles = {}, bool forcePrivateForTest = false) const;
        Metrics Grid(const Key& key) const;
        static void ValidateKey(const Snapshot& snapshot, const Key& expected);
    private:
        Microsoft::WRL::ComPtr<IDWriteFactory> _factory;
        Microsoft::WRL::ComPtr<IDWriteTextAnalyzer> _analyzer;
        Microsoft::WRL::ComPtr<IDWriteFontFace> _primary;
        std::wstring _family;
        std::vector<Microsoft::WRL::ComPtr<IDWriteFontFace>> _private;
    };
}
