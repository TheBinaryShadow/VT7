// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
namespace
{
    void HorizontalBackground(IDWriteBitmapRenderTarget* target, const VT7::Text::Snapshot& source, LONG x, LONG top)
    {
        for (UINT32 c = 0; c < source.cells.back().cellEnd; ++c)
            PaintRect(target->GetMemoryDC(),{x+static_cast<LONG>(c*source.metrics.width),top,
                x+static_cast<LONG>((c+1)*source.metrics.width),top+static_cast<LONG>(source.metrics.height)},
                c%2 ? RGB(27,43,57) : RGB(20,32,45));
    }
    void DrawHorizontal(IDWriteBitmapRenderTarget* target, const VT7::Text::FittedRow& row, LONG left, LONG top)
    {
        HorizontalBackground(target,row.source,left,top);
        for (size_t i = 0; i < row.placements.size(); ++i)
            VT7::Text::GlyphFitter::Draw(row,i,target,left,top+row.source.metrics.baseline,RGB(235,235,235));
    }
    unsigned ChangedOutside(const std::vector<unsigned char>& before, const std::vector<unsigned char>& after,
        UINT32 width, LONG left, LONG right, unsigned* changed = nullptr)
    {
        Check(before.size() == after.size(),"Horizontal pixel buffer mismatch");
        unsigned outside = 0, count = 0;
        for (size_t p = 0; p < before.size(); p += 4)
        {
            if (before[p] == after[p] && before[p+1] == after[p+1] && before[p+2] == after[p+2]) continue;
            ++count; const auto x = static_cast<LONG>((p/4)%width);
            if (x < left || x >= right) ++outside;
        }
        if (changed) *changed = count;
        return outside;
    }
    RECT HorizontalDamage(const VT7::Text::FittedRow& row, LONG left, LONG top)
    {
        RECT rect{left,top,left+static_cast<LONG>(row.source.cells.back().cellEnd*row.source.metrics.width),top+static_cast<LONG>(row.source.metrics.height)};
        for (const auto& p : row.placements)
        {
            auto ink = p.ink;
            const auto& group = row.source.runs[p.run].groups[p.group];
            OffsetRect(&ink,left+group.cellStart*row.source.metrics.width,top+row.source.metrics.baseline);
            if (ink.right > ink.left && ink.bottom > ink.top) UnionRect(&rect,&rect,&ink);
        }
        return rect;
    }
    void HorizontalRepaint(std::ostream& log, IDWriteGdiInterop* interop, VT7::Text::Mapper& mapper, VT7::Text::GlyphFitter& fitter,
        VT7::Text::Key key, const std::wstring& path)
    {
        using namespace VT7::Text;
        constexpr UINT32 width = 512, height = 256;
        constexpr LONG left = 48, top = 100;
        ComPtr<IDWriteBitmapRenderTarget> full, incremental, scratch;
        Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,&full)); Hr(full->SetPixelsPerDip(1));
        Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,&incremental)); Hr(incremental->SetPixelsPerDip(1));
        Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,&scratch)); Hr(scratch->SetPixelsPerDip(1));
        auto make = [&](const wchar_t* text)
        {
            ++key.revision; return fitter.Prepare(mapper.Map(key,text,AdapterCells(text)),key);
        };
        auto previous = make(L"A\U0001f469\u200d\U0001f4bbB");
        PaintRect(incremental->GetMemoryDC(),{0,0,width,height},RGB(14,22,32)); DrawHorizontal(incremental.Get(),previous,left,top);
        const auto initial = BitmapBytes(incremental.Get());
        const wchar_t* states[]{L"A  B",L"A\U0001f600B",L"A  B",L"A\U0001f469\u200d\U0001f4bbB",
            L"A\u0301\u0302\u0303  B",L"A\U0001f469\u200d\U0001f4bbB"};
        for (unsigned step = 0; step < ARRAYSIZE(states); ++step)
        {
            auto current = make(states[step]);
            const auto oldDamage = HorizontalDamage(previous,left,top), newDamage = HorizontalDamage(current,left,top);
            RECT damage{}; UnionRect(&damage,&oldDamage,&newDamage);
            Check(damage.left >= 0 && damage.top >= 0 && damage.right <= width && damage.bottom <= height &&
                (damage.right-damage.left)*(damage.bottom-damage.top) < width*height,"Horizontal damage is invalid or full viewport");
            const auto before = BitmapBytes(incremental.Get());
            PaintRect(full->GetMemoryDC(),{0,0,width,height},RGB(14,22,32)); DrawHorizontal(full.Get(),current,left,top);
            Check(BitBlt(scratch->GetMemoryDC(),0,0,width,height,incremental->GetMemoryDC(),0,0,SRCCOPY) != FALSE,"Horizontal scratch seed failed");
            PaintRect(scratch->GetMemoryDC(),damage,RGB(14,22,32)); DrawHorizontal(scratch.Get(),current,left,top);
            Check(BitBlt(incremental->GetMemoryDC(),damage.left,damage.top,damage.right-damage.left,damage.bottom-damage.top,
                scratch->GetMemoryDC(),damage.left,damage.top,SRCCOPY) != FALSE,"Horizontal partial commit failed");
            const auto actual = BitmapBytes(incremental.Get()), expected = BitmapBytes(full.Get());
            if (actual != expected)
            {
                SaveBitmap(full.Get(),path+L".failure-full.bmp"); SaveBitmap(incremental.Get(),path+L".failure-incremental.bmp");
                Check(false,"Horizontal partial repaint differs from fresh full redraw");
            }
            for (size_t p = 0; p < actual.size(); p += 4)
            {
                const LONG x = static_cast<LONG>((p/4)%width), y = static_cast<LONG>((p/4)/width);
                if (x >= damage.left && x < damage.right && y >= damage.top && y < damage.bottom) continue;
                Check(actual[p] == before[p] && actual[p+1] == before[p+1] && actual[p+2] == before[p+2],"Horizontal repaint escaped damage");
            }
            log << "HORIZONTAL_REPAINT: step=" << step << " damage=" << damage.left << ',' << damage.top << ',' << damage.right << ',' << damage.bottom
                << " mismatches=0 outside=0\n";
            previous = std::move(current);
        }
        Check(BitmapBytes(incremental.Get()) == initial,"Horizontal repaint did not restore initial state");
    }
    void ExerciseHorizontal(std::ostream& log, IDWriteFactory* factory, const std::wstring& bitmapPath,
        const std::vector<PrivateFace>& privateFonts, bool injectFailure)
    {
        using namespace VT7::Text;
        std::vector<ComPtr<IDWriteFontFace>> fonts; for (const auto& face : privateFonts) fonts.push_back(face.face);
        Mapper mapper(factory,L"Consolas",fonts);
        ComPtr<IDWriteGdiInterop> interop; Hr(factory->GetGdiInterop(&interop));
        ComPtr<IDWriteRenderingParams> params;
        Hr(factory->CreateCustomRenderingParams(2.2f,1,1,DWRITE_PIXEL_GEOMETRY_RGB,DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC,&params));
        GlyphFitter fitter(factory,params.Get());
        struct Sample { const char* name; const wchar_t* text; bool privateFace = false; unsigned style = 0; };
        const Sample samples[]{
            {"Emoji-neighbor",L"A\U0001f469\u200d\U0001f4bbB"},
            {"Private-BMP",L"\u262f",true}, {"Private-SMP",L"\U0001f600",true},
            {"Latin",L"A e\u0301 cafe\u00e9 ffi \u017e"}, {"Italic",L"Italic fj (ffi) /",false,1},
            {"Bold",L"Bold e\u0301",false,2}, {"CJK-neighbor",L"A\u4e2d\u6587B"},
            {"Stacked-marks",L"A\u0301\u0302\u0303 g\u0323\u0324\u0331B"},
            {"Indic-neighbor",L"A\u0915\u094d\u0937B"}, {"Arabic-mixed",L"A \u0633\u0644\u0627\u0645 123 B"},
            {"Arabic-style",L"\u0633\u0644\u0627\u0645",false,3}, {"Hebrew-mixed",L"A \u05e9\u05dc\u05d5\u05dd 123 B"}
        };
        unsigned fixtureCount = 0, groupCount = 0, compressedCount = 0, negativeCount = 0;
        for (const auto dip : {12u,18u,24u}) for (const auto dpi : {96u,120u,144u,192u})
        {
            Key key{1,1,1,0,80,dpi,static_cast<FLOAT>(dip)}; const auto grid = mapper.Grid(key);
            const UINT32 width = 1000, pitch = grid.height*3+48, height = 48+pitch*ARRAYSIZE(samples);
            ComPtr<IDWriteBitmapRenderTarget> target, guard, natural;
            Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,&target)); Hr(target->SetPixelsPerDip(1));
            Hr(interop->CreateBitmapRenderTarget(nullptr,512,256,&guard)); Hr(guard->SetPixelsPerDip(1));
            Hr(interop->CreateBitmapRenderTarget(nullptr,512,256,&natural)); Hr(natural->SetPixelsPerDip(1));
            PaintRect(target->GetMemoryDC(),{0,0,static_cast<LONG>(width),static_cast<LONG>(height)},RGB(14,22,32));
            SetBkMode(target->GetMemoryDC(),TRANSPARENT); SetTextColor(target->GetMemoryDC(),RGB(120,190,240));
            const wchar_t* title = L"VT7 0.9: R = raw mapper; F = horizontally fitted. Cells and vertical scale unchanged.";
            TextOutW(target->GetMemoryDC(),12,8,title,static_cast<int>(wcslen(title)));
            log << "HORIZONTAL_CASE: dip=" << dip << " dpi=" << dpi << " grid=" << grid.width << ',' << grid.height
                << " baseline=" << grid.baseline << " canvas=" << width << ',' << height << '\n';
            for (unsigned f = 0; f < ARRAYSIZE(samples); ++f)
            {
                const auto& sample = samples[f]; key.row = f;
                const std::wstring text = sample.text; std::vector<Style> styles;
                if (sample.style == 1) styles = {{0,static_cast<UINT32>(text.size()),DWRITE_FONT_WEIGHT_NORMAL,DWRITE_FONT_STYLE_ITALIC}};
                if (sample.style == 2) styles = {{0,static_cast<UINT32>(text.size()),DWRITE_FONT_WEIGHT_BOLD}};
                if (sample.style == 3) styles = {{0,1},{1,4,DWRITE_FONT_WEIGHT_BOLD}};
                const auto source = mapper.Map(key,text,AdapterCells(text),styles,sample.privateFace);
                auto fitted = fitter.Prepare(source,key);
                Check(fitted.source.text == source.text && fitted.source.cells == source.cells,"Fitting changed source/cells");
                for (size_t r = 0; r < source.runs.size(); ++r)
                    Check(source.runs[r].glyphs == fitted.source.runs[r].glyphs && source.runs[r].advances == fitted.source.runs[r].advances &&
                        source.runs[r].naturalAdvances == fitted.source.runs[r].naturalAdvances,"Fitting mutated mapper arrays");
                log << "HORIZONTAL_FIXTURE: index=" << f << " name=" << sample.name << " source=" << text.size()
                    << " cells=" << source.cells.back().cellEnd << " groups=" << fitted.placements.size() << '\n';
                for (size_t i = 0; i < fitted.placements.size(); ++i)
                {
                    auto& p = fitted.placements[i]; const auto& run = source.runs[p.run]; const auto& group = run.groups[p.group];
                    const LONG allocation = (group.cellEnd-group.cellStart)*grid.width;
                    Check(allocation+128+p.halo < 512,"Guard target too small");
                    PaintRect(guard->GetMemoryDC(),{0,0,512,256},RGB(70,20,45));
                    PaintRect(guard->GetMemoryDC(),{128,0,128+allocation,256},RGB(14,22,32));
                    // Contrasting neighbor pixels span the full target height, so
                    // overhang cannot escape above/below a one-row sentinel.
                    const auto before = BitmapBytes(guard.Get());
                    if (injectFailure && f == 1 && i == 0) { p.scaleX = 1; p.offsetX = 0; }
                    const auto actual = GlyphFitter::Draw(fitted,i,guard.Get(),128-static_cast<LONG>(group.cellStart*grid.width),128,RGB(235,235,235));
                    unsigned changed = 0;
                    const auto outside = ChangedOutside(before,BitmapBytes(guard.Get()),512,128-p.halo,128+allocation+p.halo,&changed);
                    Check(outside == 0,"Horizontal neighbor protection failed");
                    auto expected = p.ink; OffsetRect(&expected,128,128);
                    Check(EqualRect(&actual,&expected) != FALSE,"Fitted ink changed between measurement and draw");
                    if (p.naturalInk.right > p.naturalInk.left && p.naturalInk.bottom > p.naturalInk.top) Check(changed > 0,"Fitter erased visible ink");
                    Check(p.scaleX > 0 && p.scaleX <= 1 && (!p.compressed || p.halo == 0),"Invalid horizontal policy");
                    log << "HORIZONTAL_GROUP: text=" << group.textStart << ',' << group.textEnd << " cells=" << group.cellStart << ',' << group.cellEnd
                        << " width=" << allocation << " policy=" << (p.compressed ? "compressed" : "natural") << " scale=" << p.scaleX
                        << " offset=" << p.offsetX << " halo=" << p.halo << " retries=" << p.retries << " scaleY=1 naturalInk="
                        << p.naturalInk.left << ',' << p.naturalInk.top << ',' << p.naturalInk.right << ',' << p.naturalInk.bottom
                        << " ink=" << p.ink.left << ',' << p.ink.top << ',' << p.ink.right << ',' << p.ink.bottom
                        << " changed=" << changed << " outside=" << outside << '\n';
                    ++groupCount; if (p.compressed) ++compressedCount;
                    if (f == 1)
                    {
                        Check(p.compressed && run.privateFallback,"Private BMP did not exercise oversized private fitting");
                        PaintRect(guard->GetMemoryDC(),{0,0,512,256},RGB(70,20,45));
                        PaintRect(guard->GetMemoryDC(),{128,0,128+allocation,256},RGB(14,22,32));
                        const auto negativeBefore = BitmapBytes(guard.Get());
                        const DWRITE_GLYPH_RUN raw{run.face.Get(),run.emPixels,group.glyphEnd-group.glyphStart,
                            run.glyphs.data()+group.glyphStart,run.naturalAdvances.data()+group.glyphStart,run.offsets.data()+group.glyphStart,FALSE,0};
                        Hr(guard->DrawGlyphRun(128,128,DWRITE_MEASURING_MODE_NATURAL,&raw,params.Get(),RGB(235,235,235)));
                        const auto escaped = ChangedOutside(negativeBefore,BitmapBytes(guard.Get()),512,128,128+allocation);
                        Check(escaped > 0,"Horizontal negative control did not detect unfitted overflow"); ++negativeCount;
                        log << "HORIZONTAL_NEGATIVE: unscaled-private escaped=" << escaped << '\n';
                    }
                }
                if (f == 3 || f == 4)
                {
                    Check(std::none_of(fitted.placements.begin(),fitted.placements.end(),[](const auto& p) { return p.compressed; }),"Natural Latin/italic was compressed");
                    PaintRect(guard->GetMemoryDC(),{0,0,512,256},RGB(14,22,32)); PaintRect(natural->GetMemoryDC(),{0,0,512,256},RGB(14,22,32));
                    DrawAdapter(natural.Get(),params.Get(),source,32,100,nullptr); DrawHorizontal(guard.Get(),fitted,32,100);
                    Check(BitmapBytes(natural.Get()) == BitmapBytes(guard.Get()),"Natural Latin/italic pixels changed");
                    log << "HORIZONTAL_NATURAL: index=" << f << " rawPixels=identical\n";
                }
                const LONG rawTop = 48+f*pitch, fitTop = rawTop+grid.height+20;
                const std::wstring label(sample.name,sample.name+strlen(sample.name)); TextOutW(target->GetMemoryDC(),12,rawTop,label.data(),static_cast<int>(label.size()));
                TextOutW(target->GetMemoryDC(),230,rawTop,L"R",1); TextOutW(target->GetMemoryDC(),230,fitTop,L"F",1);
                DrawAdapter(target.Get(),params.Get(),source,270,rawTop,nullptr); DrawHorizontal(target.Get(),fitted,270,fitTop);
                ++fixtureCount; log << "HORIZONTAL_RESULT: index=" << f << " source=unchanged protection=PASS\n";
            }
            const auto path = bitmapPath+L".horizontal-"+std::to_wstring(dip)+L"-"+std::to_wstring(dpi)+L".bmp";
            SaveBitmap(target.Get(),path);
            HorizontalRepaint(log,interop.Get(),mapper,fitter,key,path);
            log << "HORIZONTAL_CASE_END: fixtures=12 repaints=6\n";
        }
        Check(fixtureCount == 144 && negativeCount == 12 && compressedCount >= 12,"Horizontal matrix incomplete");
        log << "HORIZONTAL_SUMMARY: cases=12 fixtures=" << fixtureCount << " groups=" << groupCount << " compressed=" << compressedCount
            << " negatives=" << negativeCount << " repaints=72 outside=0 failures=0\n";
    }
}
