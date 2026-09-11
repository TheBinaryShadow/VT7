// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
// Diagnostic consumers of the separate Win7TextMapper candidate.
namespace
{
    std::vector<VT7::Text::Cell> AdapterCells(const std::wstring& text)
    {
        std::vector<VT7::Text::Cell> result;
        for (const auto& c : CoreCells(text)) result.push_back({c.textStart, c.textEnd, c.cellStart, c.cellEnd});
        return result;
    }
    unsigned ValidateAdapter(std::ostream& log, const VT7::Text::Snapshot& snapshot)
    {
        unsigned groups = 0;
        UINT32 text = 0, cell = 0;
        for (const auto& c : snapshot.cells)
            log << "ADAPTER_CELL: text=" << c.textStart << ',' << c.textEnd << " cells=" << c.cellStart << ',' << c.cellEnd << '\n';
        for (const auto& run : snapshot.runs)
        {
            Check(run.textStart == text && run.face && !run.glyphs.empty() &&
                run.advances.size() == run.glyphs.size() && run.naturalAdvances.size() == run.glyphs.size() &&
                run.offsets.size() == run.glyphs.size(), "Adapter owned run arrays invalid");
            UINT32 glyph = 0;
            log << "ADAPTER_RUN: text=" << run.textStart << ',' << run.textEnd << " glyphs=" << run.glyphs.size()
                << " layoutBidi=" << run.layoutBidi << " drawBidi=0 em=" << run.emPixels << " private=" << run.privateFallback
                << " missing=" << std::count(run.glyphs.begin(),run.glyphs.end(),0) << '\n';
            for (const auto& group : run.groups)
            {
                Check(group.textStart == text && group.cellStart == cell && group.glyphStart == glyph &&
                    group.textEnd > text && group.cellEnd > cell && group.glyphEnd > glyph && group.glyphEnd <= run.glyphs.size(),
                    "Adapter group coverage invalid");
                const auto expected = (group.cellEnd - cell) * snapshot.metrics.width;
                const auto advance = std::accumulate(run.advances.begin() + glyph, run.advances.begin() + group.glyphEnd, 0.f);
                Check(std::abs(advance - expected) < .001f, "Adapter advance does not match core allocation");
                log << "ADAPTER_GROUP: text=" << text << ',' << group.textEnd << " cells=" << cell << ',' << group.cellEnd
                    << " glyphs=" << glyph << ',' << group.glyphEnd << " x=" << cell * snapshot.metrics.width
                    << " width=" << expected << " advance=" << advance << '\n';
                text = group.textEnd; cell = group.cellEnd; glyph = group.glyphEnd; ++groups;
            }
            Check(text == run.textEnd && glyph == run.glyphs.size(), "Adapter glyph coverage incomplete");
        }
        Check(text == snapshot.text.size() && cell == snapshot.cells.back().cellEnd, "Adapter row coverage incomplete");
        // Grid hit/copy checks, not a proportional glyph hit test or actual UI.
        std::wstring copied;
        for (const auto& owner : snapshot.cells)
        {
            copied += snapshot.text.substr(owner.textStart,owner.textEnd-owner.textStart);
            for (UINT32 raw = owner.cellStart; raw < owner.cellEnd; ++raw)
            {
                const auto x = (raw + .5) * snapshot.metrics.width;
                const auto hit = static_cast<UINT32>(std::floor(x / snapshot.metrics.width));
                Check(hit == raw && hit >= owner.cellStart && hit < owner.cellEnd, "Adapter raw-column hit changed ownership");
                Check(snapshot.text.substr(owner.textStart, owner.textEnd - owner.textStart).size() == owner.textEnd - owner.textStart,
                    "Adapter source selection coverage invalid");
            }
        }
        Check(copied == snapshot.text,"Adapter logical copy changed source order");
        return groups;
    }
    void DrawAdapter(IDWriteBitmapRenderTarget* target, IDWriteRenderingParams* params,
        const VT7::Text::Snapshot& snapshot, int left, int top, std::ostream* log)
    {
        const auto& grid = snapshot.metrics;
        const auto dc = target->GetMemoryDC();
        for (UINT32 column = 0; column < snapshot.cells.back().cellEnd; ++column)
        {
            const RECT cell{left + static_cast<LONG>(column * grid.width), top,
                left + static_cast<LONG>((column + 1) * grid.width), top + static_cast<LONG>(grid.height)};
            PaintRect(dc, cell, column % 2 ? RGB(27,43,57) : RGB(20,32,45));
        }
        for (const auto& run : snapshot.runs)
        {
            const DWRITE_GLYPH_RUN glyphs{run.face.Get(), run.emPixels, static_cast<UINT32>(run.glyphs.size()),
                run.glyphs.data(), run.advances.data(), run.offsets.data(), FALSE, 0};
            RECT ink{};
            Hr(target->DrawGlyphRun(static_cast<FLOAT>(left + run.groups.front().cellStart * grid.width),
                static_cast<FLOAT>(top + grid.baseline), DWRITE_MEASURING_MODE_NATURAL, &glyphs, params, RGB(235,235,235), &ink));
            if (run.privateFallback) Check(ink.right > ink.left && ink.bottom > ink.top, "Adapter private glyph has no ink");
            if (log) *log << "ADAPTER_INK: text=" << run.textStart << ',' << run.textEnd << " row=" << top << ',' << top + grid.height
                << " ink=" << ink.left << ',' << ink.top << ',' << ink.right << ',' << ink.bottom
                << " vertical=" << ((ink.top < top || ink.bottom > top + static_cast<LONG>(grid.height)) ? "OVERHANG" : "FIT") << '\n';
        }
    }
    void ExerciseAdapter(std::ostream& log, IDWriteFactory* factory, const std::wstring& bitmapPath,
        const std::vector<PrivateFace>& privateFonts, bool injectFailure)
    {
        using namespace VT7::Text;
        std::vector<ComPtr<IDWriteFontFace>> fonts;
        for (const auto& face : privateFonts) fonts.push_back(face.face);
        struct Sample { const char* name; const wchar_t* text; unsigned styleCase = 0; bool forcePrivate = false; };
        const Sample samples[]{
            {"Latin", L"A e\u0301 cafe\u00e9 ffi \u017e"},
            {"CJK", L"A\u4e2d\u6587B"},
            {"Supplementary", L"A\U0001f600B"},
            {"Arabic", L"\u0633\u0644\u0627\u0645"},
            {"Arabic-mixed", L"A \u0633\u0644\u0627\u0645 123 B"},
            {"Arabic-marks", L"\u0633\u064e\u0644\u0627\u0645"},
            {"Indic", L"\u0915\u094d\u0937"},
            {"Emoji-sequence", L"A\U0001f469\u200d\U0001f4bbB"},
            {"Bold-italic-split", L"Bold Italic", 1},
            {"Arabic-style-split", L"\u0633\u0644\u0627\u0645", 2},
            {"Arabic-equal-style", L"\u0633\u0644\u0627\u0645", 3},
            {"Stacked-marks", L"A\u0301\u0302\u0303 g\u0323\u0324\u0331"},
            {"Private-BMP", L"\u262f", 0, true},
            {"Private-SMP", L"\U0001f600", 0, true},
            {"Hebrew-mixed", L"A \u05e9\u05dc\u05d5\u05dd 123 B"},
            {"Missing-scalar", L"A\U0010ffffB"}
        };
        ComPtr<IDWriteGdiInterop> interop; Hr(factory->GetGdiInterop(&interop));
        ComPtr<IDWriteRenderingParams> params;
        Hr(factory->CreateCustomRenderingParams(2.2f, 1, 1, DWRITE_PIXEL_GEOMETRY_RGB, DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC, &params));
        unsigned fixtures = 0, totalGroups = 0, staleChecks = 0, negativeChecks = 0;
        auto reject = [&](auto operation, const char* name)
        {
            bool rejected = false; try { operation(); } catch (const std::runtime_error&) { rejected = true; }
            Check(rejected, "Adapter negative input accepted"); ++negativeChecks;
            log << "ADAPTER_NEGATIVE: " << name << " rejected\n";
        };
        Mapper mapper(factory, L"Consolas", fonts);
        const Key initial{1,1,1,0,80,96,18};
        reject([&] { mapper.Map(initial, L"ab", {{0,1,0,1}}); }, "incomplete-cells");
        reject([&] { mapper.Map(initial, L"ab", {{0,1,0,1},{1,2,2,3}}); }, "cell-gap");
        reject([&] { mapper.Map(initial, L"e\u0301", AdapterCells(L"e\u0301"), {{0,1},{1,2}}); }, "style-bisects-core");
        reject([&] { mapper.Map(initial, L"\U0001f600", {{0,1,0,1},{1,2,1,2}}); }, "split-surrogate");
        reject([&] { mapper.Map(initial, std::wstring(1, static_cast<wchar_t>(0xd800)), {{0,1,0,1}}); }, "unpaired-surrogate");
        reject([&] { auto invalid = initial; invalid.emDip = 0; mapper.Grid(invalid); }, "invalid-metrics");
        reject([&] { mapper.Map(initial, L"a\nb", {{0,3,0,3}}); }, "control-character");
        reject([&] { Mapper missing(factory, L"VT7 intentionally absent font 75D99"); }, "missing-primary");
        LARGE_INTEGER frequency{}; Check(QueryPerformanceFrequency(&frequency) != FALSE, "Adapter timer unavailable");
        for (const auto dip : {12u,18u,24u}) for (const auto dpi : {96u,120u,144u,192u})
        {
            Key key{1,1,1,0,80,dpi,static_cast<FLOAT>(dip)};
            const auto grid = mapper.Grid(key);
            const UINT32 width = 1400, stride = 3 * grid.height + 38, height = 40 + stride * ARRAYSIZE(samples);
            ComPtr<IDWriteBitmapRenderTarget> target, repeat;
            Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,&target)); Hr(target->SetPixelsPerDip(1));
            Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,&repeat)); Hr(repeat->SetPixelsPerDip(1));
            const RECT canvas{0,0,static_cast<LONG>(width),static_cast<LONG>(height)};
            PaintRect(target->GetMemoryDC(),canvas,RGB(14,22,32));
            PaintRect(repeat->GetMemoryDC(),canvas,RGB(14,22,32));
            log << "ADAPTER_CASE: dip=" << dip << " dpi=" << dpi << " grid=" << grid.width << ',' << grid.height
                << " baseline=" << grid.baseline << " em=" << grid.emPixels << " canvas=" << width << ',' << height << '\n';
            SetBkMode(target->GetMemoryDC(),TRANSPARENT); SetTextColor(target->GetMemoryDC(),RGB(120,190,240));
            const wchar_t* title = L"VT7 0.8: N = visual layout; T = logical terminal columns. Arabic/style joins require review. No Atlas yet.";
            TextOutW(target->GetMemoryDC(),12,8,title,static_cast<int>(wcslen(title)));
            Snapshot arabic;
            for (unsigned i = 0; i < ARRAYSIZE(samples); ++i)
            {
                const auto& sample = samples[i]; key.row = i;
                std::wstring source = sample.text; auto cells = AdapterCells(source);
                std::vector<Style> styles;
                if (sample.styleCase == 1) styles = {{0,5,DWRITE_FONT_WEIGHT_BOLD},{5,static_cast<UINT32>(source.size()),DWRITE_FONT_WEIGHT_NORMAL,DWRITE_FONT_STYLE_ITALIC}};
                if (sample.styleCase == 2) styles = {{0,1},{1,4,DWRITE_FONT_WEIGHT_BOLD}};
                if (sample.styleCase == 3) styles = {{0,1},{1,4}};
                Snapshot snapshot;
                LARGE_INTEGER start{}, finish{}; Check(QueryPerformanceCounter(&start) != FALSE, "Adapter timer failed");
                {
                    Mapper transient(factory,L"Consolas",fonts);
                    snapshot = transient.Map(key,source,cells,styles,sample.forcePrivate);
                }
                Check(QueryPerformanceCounter(&finish) != FALSE, "Adapter timer failed");
                source.assign(source.size(),L'Z'); cells.clear();
                Check(snapshot.text == sample.text && snapshot.cells == AdapterCells(sample.text), "Adapter retained caller data");
                Mapper::ValidateKey(snapshot,key);
                if (injectFailure && fixtures == 0) { auto invalid = key; ++invalid.revision; Mapper::ValidateKey(snapshot,invalid); }
                const auto fresh = mapper.Map(key,sample.text,AdapterCells(sample.text),styles,sample.forcePrivate);
                log << "ADAPTER_FIXTURE: index=" << i << " name=" << sample.name << " source=" << snapshot.text.size()
                    << " cells=" << snapshot.cells.back().cellEnd << " runs=" << snapshot.runs.size()
                    << " mapUs=" << (finish.QuadPart-start.QuadPart)*1000000.0/frequency.QuadPart << '\n';
                totalGroups += ValidateAdapter(log,snapshot);
                Check(snapshot.runs.size() == fresh.runs.size(), "Adapter remap run count changed");
                for (size_t r = 0; r < snapshot.runs.size(); ++r)
                {
                    const auto& a = snapshot.runs[r]; const auto& b = fresh.runs[r];
                    Check(a.glyphs == b.glyphs && a.clusters == b.clusters && a.advances == b.advances && a.naturalAdvances == b.naturalAdvances &&
                        a.offsets.size() == b.offsets.size(), "Adapter remap data changed");
                    for (size_t g = 0; g < a.offsets.size(); ++g)
                        Check(a.offsets[g].advanceOffset == b.offsets[g].advanceOffset && a.offsets[g].ascenderOffset == b.offsets[g].ascenderOffset,
                            "Adapter remap offsets changed");
                    if (dip == 12 && dpi == 96) Face(log,factory,a.face.Get());
                }
                for (unsigned field = 0; field < 7; ++field)
                {
                    auto stale = key;
                    switch (field) { case 0: ++stale.buffer; break; case 1: ++stale.revision; break; case 2: ++stale.font; break;
                        case 3: ++stale.row; break; case 4: ++stale.columns; break; case 5: ++stale.dpi; break; default: ++stale.emDip; }
                    bool caught = false; try { Mapper::ValidateKey(snapshot,stale); } catch (const std::runtime_error&) { caught = true; }
                    Check(caught,"Adapter stale snapshot accepted"); ++staleChecks;
                }
                if (sample.forcePrivate) Check(snapshot.runs.size() == 1 && snapshot.runs[0].privateFallback &&
                    std::find(snapshot.runs[0].glyphs.begin(),snapshot.runs[0].glyphs.end(),0) == snapshot.runs[0].glyphs.end(), "Adapter forced private mapping failed");
                if (i == 3) arabic = snapshot;
                if (i == 10)
                {
                    Check(arabic.runs.size() == snapshot.runs.size(), "Redundant Arabic style split changed mapping");
                    for (size_t r = 0; r < arabic.runs.size(); ++r)
                        Check(arabic.runs[r].glyphs == snapshot.runs[r].glyphs && arabic.runs[r].advances == snapshot.runs[r].advances,
                            "Redundant Arabic style split changed shaping");
                }
                const int top = 40 + i * stride, terminalTop = top + grid.height + 16;
                const std::wstring label(sample.name,sample.name+strlen(sample.name));
                TextOutW(target->GetMemoryDC(),12,top,label.data(),static_cast<int>(label.size()));
                TextOutW(target->GetMemoryDC(),235,top,L"N",1); TextOutW(target->GetMemoryDC(),235,terminalTop,L"T",1);
                ComPtr<IDWriteTextFormat> format; ComPtr<IDWriteTextLayout> layout;
                Hr(factory->CreateTextFormat(L"Consolas",nullptr,DWRITE_FONT_WEIGHT_NORMAL,DWRITE_FONT_STYLE_NORMAL,
                    DWRITE_FONT_STRETCH_NORMAL,static_cast<FLOAT>(dip),L"en-US",&format));
                Hr(format->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP));
                Hr(factory->CreateTextLayout(sample.text,static_cast<UINT32>(wcslen(sample.text)),format.Get(),1000000,10000,&layout));
                for (const auto& style : styles) { Hr(layout->SetFontWeight(style.weight,{style.start,style.end-style.start})); Hr(layout->SetFontStyle(style.style,{style.start,style.end-style.start})); }
                ComPtr<Collector> collector; collector.Attach(new Collector()); Hr(layout->Draw(nullptr,collector.Get(),0,0));
                const FLOAT scale = dpi/96.f;
                const DWRITE_MATRIX transform{scale,0,0,scale,270,static_cast<FLOAT>(top)};
                Hr(target->SetCurrentTransform(&transform));
                for (const auto& run : collector->runs)
                {
                    const DWRITE_GLYPH_RUN glyphs{run.face.Get(),run.em,static_cast<UINT32>(run.glyphs.size()),run.glyphs.data(),run.advances.data(),run.offsets.data(),FALSE,run.bidi};
                    Hr(target->DrawGlyphRun(run.x,run.y,run.mode,&glyphs,params.Get(),RGB(235,235,235)));
                }
                Hr(target->SetCurrentTransform(nullptr));
                // Seed only labels, N, and earlier fixtures. The current T row
                // has not been drawn yet in either image. Compare the entire
                // canvas afterward, including every pixel of current overhang.
                Check(BitBlt(repeat->GetMemoryDC(),0,0,width,height,target->GetMemoryDC(),0,0,SRCCOPY) != FALSE, "Adapter comparison seed failed");
                DrawAdapter(target.Get(),params.Get(),snapshot,270,terminalTop,&log);
                DrawAdapter(repeat.Get(),params.Get(),fresh,270,terminalTop,nullptr);
                const auto a = BitmapBytes(target.Get()), b = BitmapBytes(repeat.Get());
                Check(a == b, "Adapter lifetime/fresh RGB mismatch");
                log << "ADAPTER_RESULT: index=" << i << " mapping=PASS lifetime=PASS freshPixels=PASS stale=7 ordering=core-logical\n";
                ++fixtures;
            }
            const auto path = bitmapPath + L".adapter-" + std::to_wstring(dip) + L"-" + std::to_wstring(dpi) + L".bmp";
            SaveBitmap(target.Get(),path);
            log << "ADAPTER_CASE_END: fixtures=16\n";
        }
        Check(fixtures == 192 && staleChecks == 1344 && negativeChecks == 8, "Adapter matrix incomplete");
        log << "ADAPTER_SUMMARY: cases=12 fixtures=" << fixtures << " groups=" << totalGroups << " stale=" << staleChecks
            << " negatives=" << negativeChecks << " failures=0\n";
        log << "ADAPTER_LIMITS: no cache, Atlas integration, visual bidi mode, cross-style/face joining acceptance, horizontal ink fitting, or interactive hit testing\n";
    }
}
