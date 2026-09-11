// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
// Included inside FontProbe after shared diagnostic helpers, not a production renderer.
namespace
{
    struct GeometryKey
    {
        unsigned dip = 0, dpi = 0, generation = 0;
    };
    struct GeometryState
    {
        GeometryKey current;
        GeometryKey Change(unsigned dip, unsigned dpi)
        {
            Check(dip > 0 && dpi > 0, "Invalid geometry dimensions");
            if (current.dip != dip || current.dpi != dpi) current = {dip, dpi, current.generation + 1};
            return current;
        }
        void Validate(const GeometryKey& snapshot) const
        {
            Check(snapshot.dip == current.dip && snapshot.dpi == current.dpi && snapshot.generation == current.generation,
                "Stale geometry snapshot rejected");
        }
    };
    struct GridMetrics { int width, height, baseline; FLOAT pixelsPerDip; };
    GridMetrics PrimaryMetrics(IDWriteFontFace* face, const GeometryKey& key)
    {
        DWRITE_FONT_METRICS metrics{}; face->GetMetrics(&metrics);
        Check(metrics.designUnitsPerEm != 0, "Invalid primary metrics");
        const UINT32 scalar = L'M'; UINT16 glyph = 0; Hr(face->GetGlyphIndices(&scalar, 1, &glyph));
        Check(glyph != 0, "Primary advance glyph absent");
        DWRITE_GLYPH_METRICS gm{}; Hr(face->GetDesignGlyphMetrics(&glyph, 1, &gm));
        const auto ppd = key.dpi / 96.f;
        const auto unit = key.dip * ppd / metrics.designUnitsPerEm;
        // Fixed policy for this experiment: round advance to nearest pixel, ceil
        // ascent/descent/line gap separately. Fallback metrics never enter here.
        GridMetrics grid{static_cast<int>(std::floor(gm.advanceWidth * unit + .5f)),
            static_cast<int>(std::ceil(metrics.ascent * unit) + std::ceil(metrics.descent * unit) + std::ceil(metrics.lineGap * unit)),
            static_cast<int>(std::ceil(metrics.ascent * unit)), ppd};
        Check(grid.width > 2 && grid.height > grid.baseline && grid.baseline > 0, "Unusable primary grid metrics");
        return grid;
    }
    void PaintRect(HDC dc, const RECT& rect, COLORREF color)
    {
        const auto brush = CreateSolidBrush(color); Check(brush != nullptr, "Geometry brush creation failed");
        const auto cleanup = wil::scope_exit([&] { DeleteObject(brush); });
        Check(FillRect(dc, &rect, brush) != 0, "Geometry fill failed");
    }
    std::vector<unsigned char> BitmapBytes(IDWriteBitmapRenderTarget* target)
    {
        GdiFlush();
        DIBSECTION dib{};
        Check(GetObjectW(GetCurrentObject(target->GetMemoryDC(), OBJ_BITMAP), sizeof(dib), &dib) == sizeof(dib) &&
            dib.dsBm.bmBits && dib.dsBm.bmBitsPixel == 32, "Geometry DIB unavailable");
        const auto begin = static_cast<const unsigned char*>(dib.dsBm.bmBits);
        std::vector<unsigned char> pixels{begin, begin + static_cast<size_t>(dib.dsBm.bmWidthBytes) * dib.dsBm.bmHeight};
        // GDI's unused BGRX byte has no visual meaning and need not be stable.
        for (size_t i = 3; i < pixels.size(); i += 4) pixels[i] = 0;
        return pixels;
    }
    unsigned DrawGeometry(std::ostream& log, IDWriteFactory* factory, IDWriteBitmapRenderTarget* target, IDWriteBitmapRenderTarget* scratch,
        IDWriteRenderingParams* params, const Run& run, UINT32 first, UINT32 end,
        int x, int rowTop, int allocated, const GridMetrics& grid, bool requiredInk,
        RECT* recordedInk = nullptr, COLORREF color = RGB(235,235,235))
    {
        const auto natural = std::accumulate(run.advances.begin() + first, run.advances.begin() + end, 0.f);
        const DWRITE_GLYPH_RUN glyphs{run.face.Get(), run.em, end - first, run.glyphs.data() + first,
            run.advances.data() + first, run.offsets.data() + first, run.sideways, run.bidi};
        const auto origin = (run.bidi & 1) ? natural : 0.f;
        ComPtr<IDWriteGlyphRunAnalysis> analysis;
        Hr(factory->CreateGlyphRunAnalysis(&glyphs, 1, nullptr, DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC,
            run.mode, origin, 0, &analysis));
        RECT original{}; Hr(analysis->GetAlphaTextureBounds(DWRITE_TEXTURE_CLEARTYPE_3x1, &original));
        auto fit = SelectFit(std::min(0.f, static_cast<FLOAT>(original.left)),
            std::max(natural, static_cast<FLOAT>(original.right)), natural, static_cast<FLOAT>(allocated));
        unsigned retries = 0;
        // Preflight the actual rasterizer at an integer-equivalent origin. Small
        // font hinting can change ink extents after a horizontal transform.
        for (;;)
        {
            const DWRITE_MATRIX trial{fit.scale,0,0,1,100 + fit.offset,100};
            Hr(scratch->SetCurrentTransform(&trial));
            RECT measured{};
            Hr(scratch->DrawGlyphRun(origin,0,run.mode,&glyphs,params,RGB(235,235,235),&measured));
            const int trialHalo = fit.natural ? 2 : 0;
            if (measured.right <= measured.left || (measured.left >= 100 - trialHalo && measured.right <= 100 + allocated + trialHalo)) break;
            Check(retries++ < 16, "Geometry raster fit did not converge");
            fit.natural = false;
            fit.scale *= .9f;
            const auto left = std::min(0.f, static_cast<FLOAT>(original.left));
            const auto right = std::max(natural, static_cast<FLOAT>(original.right));
            fit.offset = (allocated - (right - left) * fit.scale) / 2 - left * fit.scale;
        }
        const int halo = fit.natural ? 2 : 0; // Explicit device-pixel experiment, not a DPI policy.
        const DWRITE_MATRIX transform{fit.scale, 0, 0, 1, x + fit.offset, static_cast<FLOAT>(rowTop + grid.baseline)};
        Hr(target->SetCurrentTransform(&transform));
        const auto restore = wil::scope_exit([&] { target->SetCurrentTransform(nullptr); });
        RECT ink{}; Hr(target->DrawGlyphRun(origin, 0, run.mode, &glyphs, params, color, &ink));
        if (recordedInk) *recordedInk = ink;
        const bool nonempty = ink.right > ink.left && ink.bottom > ink.top;
        Check(!requiredInk || nonempty, "Geometry private glyph has no ink");
        Check(!nonempty || (ink.left >= x - halo && ink.right <= x + allocated + halo), "Geometry horizontal bound violation");
        const bool vertical = nonempty && (ink.top < rowTop || ink.bottom > rowTop + grid.height);
        log << "GEOMETRY_INK: x=" << x << " width=" << allocated << " rowTop=" << rowTop << " rowHeight=" << grid.height
            << " baseline=" << rowTop + grid.baseline << " scale=" << fit.scale << " halo=" << halo << " retries=" << retries
            << " original=" << original.left << ',' << original.top << ',' << original.right << ',' << original.bottom
            << " drawn=" << ink.left << ',' << ink.top << ',' << ink.right << ',' << ink.bottom
            << " vertical=" << (vertical ? "REVIEW" : "FIT") << " private=" << requiredInk << '\n';
        return vertical ? 1u : 0u;
    }
    struct GeometryResult { std::vector<unsigned char> pixels; unsigned reviews = 0, fixtures = 0; };
    GeometryResult RenderGeometry(std::ostream& log, IDWriteFactory* factory, IDWriteFontFace* primary,
        const std::vector<PrivateFace>& fonts, const std::vector<Fixture>& fixtures,
        const GeometryState& state, const GeometryKey& key, const std::wstring& path)
    {
        state.Validate(key);
        const auto grid = PrimaryMetrics(primary, key);
        const auto pitch = 2 * grid.height + 64;
        const int width = 1200, height = 70 + pitch * static_cast<int>(fixtures.size());
        ComPtr<IDWriteGdiInterop> interop; Hr(factory->GetGdiInterop(&interop));
        ComPtr<IDWriteBitmapRenderTarget> target; Hr(interop->CreateBitmapRenderTarget(nullptr, width, height, &target));
        ComPtr<IDWriteBitmapRenderTarget> scratch; Hr(interop->CreateBitmapRenderTarget(nullptr, width, 256, &scratch));
        Hr(scratch->SetPixelsPerDip(1));
        Hr(target->SetPixelsPerDip(1)); // All layout quantities below explicitly converted from DIP to pixels once.
        ComPtr<IDWriteRenderingParams> params;
        Hr(factory->CreateCustomRenderingParams(2.2f, 1, 1, DWRITE_PIXEL_GEOMETRY_RGB, DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC, &params));
        const auto dc = target->GetMemoryDC(); PaintRect(dc, {0,0,width,height}, RGB(14,22,32));
        SetBkMode(dc, TRANSPARENT); SetTextColor(dc, RGB(120,190,240));
        const auto title = L"VT7 geometry: " + std::to_wstring(key.dip) + L" DIP / " + std::to_wstring(key.dpi) +
            L" DPI. U: unclipped ink. V: viewport crop copy, not Atlas clipping.";
        TextOutW(dc, 12, 8, title.c_str(), static_cast<int>(title.size()));
        log << "GEOMETRY_CASE: dip=" << key.dip << " dpi=" << key.dpi << " ppd=" << grid.pixelsPerDip
            << " cell=" << grid.width << ',' << grid.height << " baseline=" << grid.baseline << " generation=" << key.generation
            << " bitmap=" << width << ',' << height << '\n';
        GeometryResult result;
        for (size_t index = 0; index < fixtures.size(); ++index)
        {
            state.Validate(key);
            const auto& fixture = fixtures[index]; const std::wstring text = fixture.text;
            const auto cells = CoreCells(text);
            for (size_t c = 0; c < cells.size(); ++c)
            {
                log << "GEOMETRY_CELL: fixture=" << index << " text=" << cells[c].textStart << ',' << cells[c].textEnd
                    << " cells=" << cells[c].cellStart << ',' << cells[c].cellEnd << '\n';
            }
            ComPtr<IDWriteTextFormat> format;
            Hr(factory->CreateTextFormat(fixture.family, nullptr, fixture.weight, fixture.style, DWRITE_FONT_STRETCH_NORMAL,
                static_cast<FLOAT>(key.dip), L"en-US", &format));
            Hr(format->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP));
            ComPtr<IDWriteTextLayout> layout;
            Hr(factory->CreateTextLayout(text.c_str(), static_cast<UINT32>(text.size()), format.Get(), 2000, 200, &layout));
            DWRITE_TEXT_METRICS layoutMetrics{}; Hr(layout->GetMetrics(&layoutMetrics));
            log << "GEOMETRY_LAYOUT: index=" << index << " width=" << layoutMetrics.width << " height=" << layoutMetrics.height << '\n';
            ComPtr<Collector> collector; collector.Attach(new Collector()); Hr(layout->Draw(nullptr, collector.Get(), 0, 0));
            auto runs = std::move(collector->runs); collector.Reset(); layout.Reset(); format.Reset();
            log << "GEOMETRY_FIXTURE: index=" << index << " name=" << fixture.name << '\n';
            Describe(log, factory, text, runs);
            const bool forced = index == 11 || index == 12;
            const auto applied = ApplyPrivateFallback(log, runs, cells, fonts, forced);
            Check(!forced || applied == 1, "Geometry forced private fallback missing");
            const auto segments = Map(text, runs, cells);
            for (auto& run : runs)
            {
                run.em *= grid.pixelsPerDip; run.x *= grid.pixelsPerDip; run.y *= grid.pixelsPerDip;
                for (auto& a : run.advances) a *= grid.pixelsPerDip;
                for (auto& offset : run.offsets) { offset.advanceOffset *= grid.pixelsPerDip; offset.ascenderOffset *= grid.pixelsPerDip; }
            }
            const auto places = VisualRuns(runs, segments, cells.back().cellEnd);
            const int top = 70 + static_cast<int>(index) * pitch;
            const int left = 300, columns = static_cast<int>(cells.back().cellEnd), rowWidth = columns * grid.width;
            Check(left + rowWidth + 10 < width, "Geometry row exceeds diagnostic canvas");
            const std::wstring label(fixture.name, fixture.name + strlen(fixture.name));
            TextOutW(dc, 12, top, label.c_str(), static_cast<int>(label.size()));
            TextOutW(dc, 275, top, L"U", 1); TextOutW(dc, 275, top + grid.height + 20, L"V", 1);
            // Clear every background before drawing any glyph, preserving neighbor overhang.
            for (int c = 0; c < columns; ++c)
                PaintRect(dc, {left + c * grid.width,top,left + (c+1) * grid.width,top + grid.height}, c % 2 ? RGB(34,49,65) : RGB(20,32,44));
            for (const auto& place : places)
            {
                const auto& run = runs[place.run];
                const bool privateFace = std::any_of(fonts.begin(), fonts.end(), [&](const auto& f) { return f.face.Get() == run.face.Get(); });
                if (run.bidi & 1)
                    result.reviews += DrawGeometry(log, factory, target.Get(), scratch.Get(), params.Get(), run, 0, static_cast<UINT32>(run.glyphs.size()),
                        left + static_cast<int>(place.visualFirst) * grid.width, top,
                        static_cast<int>(place.logicalEnd - place.logicalFirst) * grid.width, grid, privateFace);
                else for (const auto& span : segments) if (span.run == place.run)
                    result.reviews += DrawGeometry(log, factory, target.Get(), scratch.Get(), params.Get(), run, span.firstGlyph, span.endGlyph,
                        left + static_cast<int>(place.visualFirst + span.firstCell - place.logicalFirst) * grid.width, top,
                        static_cast<int>(span.endCell - span.firstCell) * grid.width, grid, privateFace);
            }
            if (index == 15)
            {
                DWRITE_FONT_METRICS fm{}; primary->GetMetrics(&fm);
                const auto unit = key.dip * grid.pixelsPerDip / fm.designUnitsPerEm;
                for (const auto decoration : {std::pair<INT16,UINT16>{fm.underlinePosition,fm.underlineThickness},
                    std::pair<INT16,UINT16>{fm.strikethroughPosition,fm.strikethroughThickness}})
                {
                    const int y = top + grid.baseline - static_cast<int>(std::round(decoration.first * unit));
                    const int thick = std::max(1, static_cast<int>(std::ceil(decoration.second * unit)));
                    PaintRect(dc, {left,y,left + rowWidth,y + thick}, RGB(120,190,240));
                    log << "GEOMETRY_DECORATION: y=" << y << " thickness=" << thick << " row=" << top << ',' << top + grid.height << '\n';
                }
            }
            // Explicit diagnostic viewport crop via blit. Do not claim this tests
            // IDWriteBitmapRenderTarget clipping or Atlas invalidation.
            const int destY = top + grid.height + 20;
            const auto before = BitmapBytes(target.Get());
            Check(BitBlt(dc, left, destY, rowWidth, grid.height, dc, left, top, SRCCOPY) != FALSE, "Geometry crop blit failed");
            const auto after = BitmapBytes(target.Get());
            unsigned mismatches = 0;
            for (int y = destY - 2; y < destY + grid.height + 2; ++y)
                for (int x = left - 2; x < left + rowWidth + 2; ++x)
                {
                    const bool inside = x >= left && x < left + rowWidth && y >= destY && y < destY + grid.height;
                    const auto dest = (static_cast<size_t>(y) * width + x) * 4;
                    const auto source = inside ? (static_cast<size_t>(top + y - destY) * width + x) * 4 : dest;
                    // DIB alpha is unused; compare RGB channels only.
                    for (size_t b = 0; b < 3; ++b) if (after[dest+b] != before[source+b]) ++mismatches;
                }
            Check(mismatches == 0, "Geometry crop pixels or outside sentinel differ");
            log << "GEOMETRY_CLIP: fixture=" << index << " rect=" << left << ',' << top << ',' << left + rowWidth << ',' << top + grid.height
                << " destinationY=" << destY << " mismatches=" << mismatches << '\n';
            ++result.fixtures;
        }
        if (!path.empty()) { SaveBitmap(target.Get(), path); log << "GEOMETRY_BITMAP: " << Utf8(path) << '\n'; }
        result.pixels = BitmapBytes(target.Get());
        return result;
    }
    void ExerciseGeometry(std::ostream& log, IDWriteFactory* factory, const std::wstring& referencePath,
        const std::vector<PrivateFace>& fonts, std::vector<Fixture> fixtures)
    {
        fixtures.push_back({"Descenders", L"gjpqy Ag", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL});
        fixtures.push_back({"Stacked-marks", L"A\u0301\u0302\u0308 g\u0323\u0331", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL});
        fixtures.push_back({"Decorations", L"Italic gjpqy", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_ITALIC});
        fixtures.push_back({"Edge-neighbors", L"f\u4e2d\u6587gj", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_ITALIC});
        ComPtr<IDWriteFontCollection> collection; Hr(factory->GetSystemFontCollection(&collection));
        UINT32 familyIndex = 0; BOOL exists = FALSE; Hr(collection->FindFamilyName(L"Consolas", &familyIndex, &exists));
        Check(exists != FALSE, "Primary Consolas family absent");
        ComPtr<IDWriteFontFamily> family; Hr(collection->GetFontFamily(familyIndex, &family));
        ComPtr<IDWriteFont> font; Hr(family->GetFirstMatchingFont(DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STRETCH_NORMAL, DWRITE_FONT_STYLE_NORMAL, &font));
        ComPtr<IDWriteFontFace> primary; Hr(font->CreateFontFace(&primary));
        DWRITE_FONT_METRICS design{}; primary->GetMetrics(&design);
        const UINT32 m = L'M'; UINT16 mGlyph = 0; Hr(primary->GetGlyphIndices(&m, 1, &mGlyph));
        DWRITE_GLYPH_METRICS mMetrics{}; Hr(primary->GetDesignGlyphMetrics(&mGlyph, 1, &mMetrics));
        log << "GEOMETRY_DESIGN: units=" << design.designUnitsPerEm << " ascent=" << design.ascent << " descent=" << design.descent
            << " gap=" << design.lineGap << " advance=" << mMetrics.advanceWidth << '\n';
        // Regression for a valid callback with omitted, zero-valued offsets.
        const FLOAT advance = 10; const UINT16 cluster = 0;
        const DWRITE_GLYPH_RUN simple{primary.Get(),18,1,&mGlyph,&advance,nullptr,FALSE,0};
        const DWRITE_GLYPH_RUN_DESCRIPTION description{L"en-US",L"M",1,&cluster,0};
        ComPtr<Collector> optionalOffsets; optionalOffsets.Attach(new Collector());
        Hr(optionalOffsets->DrawGlyphRun(nullptr,0,0,DWRITE_MEASURING_MODE_NATURAL,&simple,&description,nullptr));
        Check(optionalOffsets->runs.size() == 1 && optionalOffsets->runs[0].offsets.size() == 1 &&
            optionalOffsets->runs[0].offsets[0].advanceOffset == 0 && optionalOffsets->runs[0].offsets[0].ascenderOffset == 0,
            "Optional offset callback regression");
        log << "PASS: Optional glyph offsets retained as zero displacements\n";
        log << "GEOMETRY_PRIMARY: Consolas normal; M advance nearest pixel; ascent/descent/gap ceil separately\n";
        Face(log, factory, primary.Get());
        log << "GEOMETRY_POLICY: explicit DIP-to-pixel conversion; 2 device-pixel natural horizontal halo; no vertical scaling; vertical overflow REVIEW\n";
        GeometryState state; unsigned cases = 0, reviews = 0, mapped = 0;
        for (const unsigned dip : {12u,18u,24u}) for (const unsigned dpi : {96u,120u,144u,192u})
        {
            const auto key = state.Change(dip, dpi);
            const auto path = referencePath + L".geometry-" + std::to_wstring(dip) + L"-" + std::to_wstring(dpi) + L".bmp";
            const auto result = RenderGeometry(log, factory, primary.Get(), fonts, fixtures, state, key, path);
            reviews += result.reviews; mapped += result.fixtures; ++cases;
        }
        // Exercise a retained metrics/snapshot key through repeated transitions.
        // No production cache is claimed; rendering always validates the key.
        const auto first = state.Change(18,96);
        std::ostringstream transitionLog;
        const auto initial = RenderGeometry(transitionLog, factory, primary.Get(), fonts, fixtures, state, first, L"");
        unsigned rejected = 0;
        for (const auto next : {std::pair<unsigned,unsigned>{24,192}, {12,120}, {18,96}, {24,192}})
        {
            const auto old = state.current; const auto key = state.Change(next.first, next.second);
            try { RenderGeometry(transitionLog, factory, primary.Get(), fonts, fixtures, state, old, L""); }
            catch (const std::runtime_error& error) { if (std::string(error.what()) == "Stale geometry snapshot rejected") ++rejected; else throw; }
            RenderGeometry(transitionLog, factory, primary.Get(), fonts, fixtures, state, key, L"");
        }
        const auto restored = RenderGeometry(transitionLog, factory, primary.Get(), fonts, fixtures, state, state.Change(18,96), L"");
        GeometryState fresh;
        const auto cold = RenderGeometry(transitionLog, factory, primary.Get(), fonts, fixtures, fresh, fresh.Change(18,96), L"");
        Check(rejected == 4 && initial.pixels == restored.pixels && restored.pixels == cold.pixels, "Geometry transition or pixel round-trip failed");
        log << "GEOMETRY_TRANSITIONS: changes=4 staleRejected=" << rejected << " restoredEqualsInitial=1 restoredEqualsFresh=1\n";
        Check(cases == 12 && mapped == 204, "Geometry matrix incomplete");
        log << "GEOMETRY_SUMMARY: cases=" << cases << " fixtures=" << mapped << " verticalReviewDraws=" << reviews
            << " structuralFailures=0; production vertical policy and physical DPI acceptance deferred\n";
    }
}
