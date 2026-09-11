// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include <LibraryIncludes.h>
#include "FontAnalysis.hpp"
#include "../../cascadia/TerminalCore/Terminal.hpp"
#include "../VT7.Core/ProofRenderer.hpp"

std::vector<VT7::FontProbe::CellSpan> VT7::FontProbe::CoreCells(const std::wstring& text)
{
    if (text.empty() || text.size() > 200) throw std::runtime_error("Cell fixture length out of bounds");
    Microsoft::Console::Render::Renderer renderer;
    Microsoft::Terminal::Core::Terminal core;
    const auto guard = core.LockForWriting();
    core.Create({512, 2}, 0, renderer);
    core.Write(text);
    const auto& row = core.GetTextBuffer().GetRowByOffset(0);
    std::vector<CellSpan> result;
    std::wstring restored;
    for (UINT32 cell = 0; restored.size() < text.size() && cell < 512;)
    {
        const auto column = static_cast<til::CoordType>(cell);
        if (row.DbcsAttrAt(column) == DbcsAttribute::Trailing) throw std::runtime_error("Unexpected continuation cell");
        const auto glyph = row.GlyphAt(column);
        const auto start = static_cast<UINT32>(restored.size());
        restored.append(glyph);
        const auto width = row.DbcsAttrAt(column) == DbcsAttribute::Leading ? 2u : 1u;
        result.push_back({start, static_cast<UINT32>(restored.size()), cell, cell + width});
        cell += width;
    }
    if (restored != text) throw std::runtime_error("Core fixture did not preserve original text");
    return result;
}
