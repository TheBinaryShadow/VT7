// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
// Context/order experiment only. Does not change Mapper or terminal bidi policy.
namespace
{
    struct ArabicSample
    {
        const char* name;
        std::wstring text;
        const wchar_t* family = L"Arial";
        unsigned split = 0; // 1 bold, 2 italic, 3 other family, 4 identical style.
        bool contextOracle = false;
    };

    ComPtr<IDWriteTextLayout> ArabicLayout(IDWriteFactory* factory, const ArabicSample& sample, FLOAT em)
    {
        ComPtr<IDWriteTextFormat> format;
        Hr(factory->CreateTextFormat(sample.family, nullptr, DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL,
            DWRITE_FONT_STRETCH_NORMAL, em, L"en-US", &format));
        Hr(format->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP));
        ComPtr<IDWriteTextLayout> layout;
        Hr(factory->CreateTextLayout(sample.text.data(), static_cast<UINT32>(sample.text.size()), format.Get(), 1200, 256, &layout));
        if (sample.split == 1) Hr(layout->SetFontWeight(DWRITE_FONT_WEIGHT_BOLD, {1,1}));
        if (sample.split == 2) Hr(layout->SetFontStyle(DWRITE_FONT_STYLE_ITALIC, {1,1}));
        if (sample.split == 3) Hr(layout->SetFontFamilyName(L"Times New Roman", {1,1}));
        if (sample.split == 4)
            for (UINT32 c = 0; c < sample.text.size(); ++c) Hr(layout->SetFontWeight(DWRITE_FONT_WEIGHT_NORMAL, {c,1}));
        return layout;
    }

    // Shares the existing callback ownership implementation, not its shaping or
    // cell-placement path. This renderer sends the live callback straight to DWrite.
    class ArabicImmediate final : public IDWriteTextRenderer
    {
        LONG _references = 1;
    public:
        IDWriteBitmapRenderTarget* target;
        IDWriteRenderingParams* params;
        ArabicImmediate(IDWriteBitmapRenderTarget* t, IDWriteRenderingParams* p) : target(t), params(p) {}
        HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** output) noexcept override
        {
            if (!output) return E_POINTER;
            *output = nullptr;
            if (iid != __uuidof(IUnknown) && iid != __uuidof(IDWriteTextRenderer) && iid != __uuidof(IDWritePixelSnapping)) return E_NOINTERFACE;
            *output = static_cast<IDWriteTextRenderer*>(this); AddRef(); return S_OK;
        }
        ULONG STDMETHODCALLTYPE AddRef() noexcept override { return InterlockedIncrement(&_references); }
        ULONG STDMETHODCALLTYPE Release() noexcept override { const auto n = InterlockedDecrement(&_references); if (!n) delete this; return n; }
        HRESULT STDMETHODCALLTYPE IsPixelSnappingDisabled(void*, BOOL* v) noexcept override { if (!v) return E_POINTER; *v=FALSE; return S_OK; }
        HRESULT STDMETHODCALLTYPE GetCurrentTransform(void*, DWRITE_MATRIX* v) noexcept override { if (!v) return E_POINTER; *v={1,0,0,1,0,0}; return S_OK; }
        HRESULT STDMETHODCALLTYPE GetPixelsPerDip(void*, FLOAT* v) noexcept override { if (!v) return E_POINTER; *v=1; return S_OK; }
        HRESULT STDMETHODCALLTYPE DrawGlyphRun(void*, FLOAT x, FLOAT y, DWRITE_MEASURING_MODE mode,
            const DWRITE_GLYPH_RUN* run, const DWRITE_GLYPH_RUN_DESCRIPTION*, IUnknown*) noexcept override
        { return target->DrawGlyphRun(x,y,mode,run,params,RGB(235,235,235)); }
        HRESULT STDMETHODCALLTYPE DrawUnderline(void*, FLOAT, FLOAT, const DWRITE_UNDERLINE*, IUnknown*) noexcept override { return E_NOTIMPL; }
        HRESULT STDMETHODCALLTYPE DrawStrikethrough(void*, FLOAT, FLOAT, const DWRITE_STRIKETHROUGH*, IUnknown*) noexcept override { return E_NOTIMPL; }
        HRESULT STDMETHODCALLTYPE DrawInlineObject(void*, FLOAT, FLOAT, IDWriteInlineObject*, BOOL, BOOL, IUnknown*) noexcept override { return E_NOTIMPL; }
    };

    std::vector<Run> ArabicRetain(IDWriteTextLayout* layout)
    {
        ComPtr<Collector> collector; collector.Attach(new Collector());
        Hr(layout->Draw(nullptr,collector.Get(),0,0));
        return std::move(collector->runs);
    }

    void ArabicNatural(IDWriteBitmapRenderTarget* target, IDWriteRenderingParams* params,
        const std::vector<Run>& runs, FLOAT left, FLOAT top)
    {
        for (const auto& run : runs)
        {
            const DWRITE_GLYPH_RUN glyphs{run.face.Get(),run.em,static_cast<UINT32>(run.glyphs.size()),
                run.glyphs.data(),run.advances.data(),run.offsets.data(),run.sideways,run.bidi};
            Hr(target->DrawGlyphRun(left+run.x,top+run.y,run.mode,&glyphs,params,RGB(235,235,235)));
        }
    }

    std::vector<UINT16> ArabicGlyphsAt(const std::vector<Run>& runs, UINT32 source)
    {
        for (const auto& run : runs)
        {
            if (source < run.textStart || source >= run.textStart+run.text.size()) continue;
            const UINT32 first = run.clusters.at(source-run.textStart);
            UINT32 end = static_cast<UINT32>(run.glyphs.size());
            for (auto g : run.clusters) if (g > first) end=std::min(end,static_cast<UINT32>(g));
            return {run.glyphs.begin()+first,run.glyphs.begin()+end};
        }
        Check(false,"Arabic source glyph association missing"); return {};
    }

    IDWriteFontFace* ArabicFaceAt(const std::vector<Run>& runs, UINT32 source)
    {
        for (const auto& run : runs) if (source >= run.textStart && source < run.textStart+run.text.size()) return run.face.Get();
        Check(false,"Arabic source face missing"); return nullptr;
    }

    bool ArabicSameFace(IDWriteFontFace* a, IDWriteFontFace* b)
    {
        if (a->GetIndex() != b->GetIndex() || a->GetSimulations() != b->GetSimulations()) return false;
        UINT32 na=0, nb=0; Hr(a->GetFiles(&na,nullptr)); Hr(b->GetFiles(&nb,nullptr));
        if (na != nb || na != 1) return false; // Bounded TrueType/OpenType experiment.
        ComPtr<IDWriteFontFile> fa,fb; Hr(a->GetFiles(&na,&fa)); Hr(b->GetFiles(&nb,&fb));
        const void *ka=nullptr,*kb=nullptr; UINT32 sa=0,sb=0;
        Hr(fa->GetReferenceKey(&ka,&sa)); Hr(fb->GetReferenceKey(&kb,&sb));
        ComPtr<IDWriteFontFileLoader> la,lb; Hr(fa->GetLoader(&la)); Hr(fb->GetLoader(&lb));
        ComPtr<IUnknown> ia,ib; Hr(la.As(&ia)); Hr(lb.As(&ib));
        return ia.Get() == ib.Get() && sa == sb && memcmp(ka,kb,sa) == 0;
    }

    std::vector<Run> ArabicRepair(std::ostream& log, IDWriteFactory* factory, const ArabicSample& sample,
        const std::vector<Run>& original, unsigned& repaired, unsigned& blocked)
    {
        auto result=original;
        ComPtr<IDWriteFontCollection> collection; Hr(factory->GetSystemFontCollection(&collection,FALSE));
        // Whole source is shaping context only. We do not insert ZWJ, presentation
        // forms, or fabricated characters. A boundary-spanning shaping cluster
        // is deliberately not split, even when that leaves an unresolved case.
        for (auto& run : result)
        {
            if (!(run.bidi&1) || sample.split == 0) continue;
            ComPtr<IDWriteFont> font; Hr(collection->GetFontFromFontFace(run.face.Get(),&font));
            ComPtr<IDWriteFontFamily> family; Hr(font->GetFontFamily(&family));
            ComPtr<IDWriteLocalizedStrings> names; Hr(family->GetFamilyNames(&names));
            const auto familyName=Name(names.Get());
            auto uniform=sample; uniform.family=familyName.c_str(); uniform.split=0;
            auto layout=ArabicLayout(factory,uniform,run.em);
            const DWRITE_TEXT_RANGE all{0,static_cast<UINT32>(sample.text.size())};
            Hr(layout->SetFontWeight(font->GetWeight(),all)); Hr(layout->SetFontStyle(font->GetStyle(),all));
            Hr(layout->SetFontStretch(font->GetStretch(),all));
            const auto references=ArabicRetain(layout.Get()); layout.Reset();
            const auto end=run.textStart+static_cast<UINT32>(run.text.size());
            const auto ref=std::find_if(references.begin(),references.end(),[&](const auto& r) {
                return r.textStart <= run.textStart && r.textStart+r.text.size() >= end && ArabicSameFace(r.face.Get(),run.face.Get()); });
            bool safe=ref != references.end();
            UINT32 start=0,finish=0,first=0,last=0;
            if (safe)
            {
                start=run.textStart-ref->textStart; finish=end-ref->textStart;
                safe=(!start || ref->clusters[start] != ref->clusters[start-1]) &&
                    (finish == ref->clusters.size() || ref->clusters[finish] != ref->clusters[finish-1]);
            }
            if (safe)
            {
                first=*std::min_element(ref->clusters.begin()+start,ref->clusters.begin()+finish);
                const auto max=*std::max_element(ref->clusters.begin()+start,ref->clusters.begin()+finish);
                last=static_cast<UINT32>(ref->glyphs.size());
                for (auto g : ref->clusters) if (g>max) last=std::min(last,static_cast<UINT32>(g));
                // All selected glyphs must belong only to this source interval.
                for (UINT32 c=0; c<ref->clusters.size(); ++c)
                    if ((c<start || c>=finish) && ref->clusters[c]>=first && ref->clusters[c]<last) safe=false;
            }
            log << "ARABIC_REPAIR: text=" << run.textStart << ',' << end;
            if (!safe)
            {
                ++blocked; log << " status=REVIEW reason=face-or-cluster-boundary\n"; continue;
            }
            Run replacement=run;
            replacement.glyphs.assign(ref->glyphs.begin()+first,ref->glyphs.begin()+last);
            replacement.advances.assign(ref->advances.begin()+first,ref->advances.begin()+last);
            replacement.offsets.assign(ref->offsets.begin()+first,ref->offsets.begin()+last);
            replacement.clusters.assign(ref->clusters.begin()+start,ref->clusters.begin()+finish);
            for (auto& cluster : replacement.clusters) cluster=static_cast<UINT16>(cluster-first);
            const bool changed=replacement.glyphs != run.glyphs;
            if (changed) ++repaired;
            run=std::move(replacement);
            log << " status=" << (changed ? "repaired" : "unchanged") << " face=identical context=whole-source\n";
        }
        return result;
    }

    // Compare the three behs with whole-word shaping in each requested face and
    // style. No font-specific glyph numbers or presentation-form substitutions.
    // Lam-alef boundary behavior is a separate observation, not this oracle.
    unsigned ArabicContext(std::ostream& log, IDWriteFactory* factory, const ArabicSample& sample,
        FLOAT em, const std::vector<Run>& runs, bool injectFailure)
    {
        unsigned changed = 0;
        for (UINT32 c=0; c<3; ++c)
        {
            auto uniform = sample; uniform.split=0;
            if (c == 1 && sample.split == 3) uniform.family=L"Times New Roman";
            auto layout=ArabicLayout(factory,uniform,em);
            const DWRITE_TEXT_RANGE all{0,3};
            if (c == 1 && sample.split == 1) Hr(layout->SetFontWeight(DWRITE_FONT_WEIGHT_BOLD,all));
            if (c == 1 && sample.split == 2) Hr(layout->SetFontStyle(DWRITE_FONT_STYLE_ITALIC,all));
            const auto uniformRuns=ArabicRetain(layout.Get());
            const auto expected=ArabicGlyphsAt(uniformRuns,c);
            Check(ArabicSameFace(ArabicFaceAt(runs,c),ArabicFaceAt(uniformRuns,c)),"Arabic oracle uses different face");
            auto isolated=uniform; isolated.text=L"\u0628";
            auto single=ArabicLayout(factory,isolated,em);
            if (c == 1 && sample.split == 1) Hr(single->SetFontWeight(DWRITE_FONT_WEIGHT_BOLD,{0,1}));
            if (c == 1 && sample.split == 2) Hr(single->SetFontStyle(DWRITE_FONT_STYLE_ITALIC,{0,1}));
            const auto unjoined=ArabicGlyphsAt(ArabicRetain(single.Get()),0);
            const auto actual=injectFailure && unjoined != expected ? unjoined : ArabicGlyphsAt(runs,c);
            Check(actual == expected,"Arabic context differs from whole-word face/style oracle");
            // Font shaping may intentionally reuse an isolated glyph at one
            // position. Require the isolated *word* to differ, not every glyph,
            // and never use presentation-form cmap IDs as a GSUB oracle.
            if (actual != unjoined) ++changed;
            log << "ARABIC_CONTEXT: source=" << c << " glyphs=";
            for (auto glyph : actual) log << glyph << ',';
            log << " wholeWord=identical isolated=" << (actual != unjoined ? "different" : "same") << " face=identical\n";
        }
        Check(changed>0,"Arabic isolated-word negative did not change contextual forms");
        log << "ARABIC_NEGATIVE: isolatedWord=different changed=" << changed << '\n';
        return changed;
    }

    void ArabicGrid(std::ostream& log, IDWriteFactory* factory, IDWriteBitmapRenderTarget* target,
        IDWriteRenderingParams* params, const std::vector<Run>& runs, const std::vector<Segment>& groups,
        const std::vector<Placement>& places, const VT7::Text::Metrics& grid, UINT32 columns,
        LONG left, LONG top, bool visual)
    {
        for (UINT32 c=0; c<columns; ++c)
            PaintRect(target->GetMemoryDC(),{left+static_cast<LONG>(c*grid.width),top,
                left+static_cast<LONG>((c+1)*grid.width),top+static_cast<LONG>(grid.height)},c%2 ? RGB(27,43,57) : RGB(20,32,45));
        std::vector<unsigned> used(columns);
        for (const auto& group : groups)
        {
            const auto& run=runs[group.run];
            const auto place=std::find_if(places.begin(),places.end(),[&](const auto& p) { return p.run == group.run; });
            Check(place != places.end(),"Arabic run projection missing");
            const auto first = visual ? place->visualFirst + ((run.bidi&1) ? place->logicalEnd-group.endCell : group.firstCell-place->logicalFirst) : group.firstCell;
            const auto count=group.endCell-group.firstCell;
            Check(first+count <= columns,"Arabic grid projection overflow");
            for (UINT32 c=first; c<first+count; ++c) ++used[c];
            std::ostringstream fitting; FitStats stats;
            DrawFitted(fitting,factory,target,params,run,group.firstGlyph,group.endGlyph,
                static_cast<FLOAT>(left+first*grid.width),static_cast<FLOAT>(top+grid.baseline),static_cast<FLOAT>(count*grid.width),stats);
            log << "ARABIC_GROUP: mode=" << (visual ? 'V' : 'C') << " text=" << group.textStart << ',' << group.textEnd
                << " logical=" << group.firstCell << ',' << group.endCell << " display=" << first << ',' << first+count
                << " bidi=" << run.bidi << " glyphs=" << group.firstGlyph << ',' << group.endGlyph << '\n';
        }
        Check(std::all_of(used.begin(),used.end(),[](auto n) { return n == 1; }),"Arabic projected cells overlap or disappear");
    }

    std::vector<Run> ArabicNaturalPlacement(const std::vector<Run>& runs, const std::vector<Placement>& places)
    {
        auto result=runs;
        FLOAT x=0;
        for (const auto& place : places)
        {
            auto& run=result.at(place.run);
            const auto advance=std::accumulate(run.advances.begin(),run.advances.end(),0.f);
            Check(std::isfinite(advance) && advance >= 0,"Arabic natural width invalid");
            run.x=x+((run.bidi&1) ? advance : 0); x+=advance;
        }
        return result;
    }

    void ExerciseArabic(std::ostream& log, IDWriteFactory* factory, const std::wstring& bitmapPath, bool injectFailure)
    {
        const ArabicSample samples[]{
            {"Plain",L"\u0633\u0644\u0627\u0645"},
            {"Marks",L"\u0633\u064e\u0644\u064e\u0627\u0645\u064c"},
            {"Mixed",L"A \u0633\u0644\u0627\u0645 123 B"},
            {"Bold-boundary",L"\u0628\u0628\u0628",L"Arial",1,true},
            {"Italic-boundary",L"\u0628\u0628\u0628",L"Arial",2,true},
            {"Face-boundary",L"\u0628\u0628\u0628",L"Arial",3,true},
            {"Same-style",L"\u0628\u0628\u0628",L"Arial",4,true},
            {"Fallback-bold",L"\u0628\u0628\u0628",L"Consolas",1,true},
            {"Lam-alef-split",L"\u0644\u0627",L"Arial",1},
            {"Join-controls",L"\u0628\u200c\u0628\u200d\u0628"},
            {"Arabic-digits",L"(\u0633\u0644\u0627\u0645) \u0661\u0662\u0663"},
            {"Latin-control",L"A e\u0301 ffi \u017e",L"Consolas"},
        };
        ComPtr<IDWriteGdiInterop> interop; Hr(factory->GetGdiInterop(&interop));
        ComPtr<IDWriteRenderingParams> params; Hr(factory->CreateRenderingParams(&params));
        unsigned fixtures=0, contexts=0, negatives=0, rasterControls=0, repaired=0, blocked=0;
        for (UINT32 dip : {12u,18u,24u}) for (UINT32 dpi : {96u,120u,144u,192u})
        {
            const FLOAT em=dip*dpi/96.f;
            const LONG lane=static_cast<LONG>(std::ceil(em*1.8f))+20, block=lane*5+32;
            constexpr UINT32 width=1000;
            const UINT32 height=static_cast<UINT32>(48+6*block);
            log << "ARABIC_CASE: dip=" << dip << " dpi=" << dpi << " canvas=" << width << ',' << height << '\n';
            for (unsigned page=0; page<2; ++page)
            {
                ComPtr<IDWriteBitmapRenderTarget> panel; Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,&panel));
                Hr(panel->SetPixelsPerDip(1));
                const auto dc=panel->GetMemoryDC(); PaintRect(dc,{0,0,width,static_cast<LONG>(height)},RGB(14,22,32));
                SetBkMode(dc,TRANSPARENT); SetTextColor(dc,RGB(105,200,255));
                const wchar_t* title=L"VT7 0.10 Arabic: N native; L legacy; C context logical; V context visual; P repaired natural.";
                TextOutW(dc,12,8,title,static_cast<int>(wcslen(title)));
                for (unsigned i=page*6; i<(page+1)*6; ++i)
                {
                    const auto& sample=samples[i];
                    const auto cells=CoreCells(sample.text);
                    auto layout=ArabicLayout(factory,sample,em);
                    const auto original=ArabicRetain(layout.Get()); layout.Reset();
                    auto runs=ArabicRepair(log,factory,sample,original,repaired,blocked);
                    Check(!runs.empty(),"Arabic retained layout is empty");
                    const auto groups=Map(sample.text,runs,cells);
                    // Repaired advances are not the old layout's x coordinates.
                    // Resolve physical run order from the unmodified layout only.
                    const auto places=VisualRuns(original,Map(sample.text,original,cells),cells.back().cellEnd);
                    VT7::Text::Mapper mapper(factory,sample.family);
                    const VT7::Text::Key key{1,1,1,0,80,dpi,static_cast<FLOAT>(dip)};
                    const auto grid=mapper.Grid(key);
                    log << "ARABIC_FIXTURE: index=" << i << " name=" << sample.name << " source=" << sample.text.size()
                        << " cells=" << cells.back().cellEnd << " runs=" << runs.size() << " groups=" << groups.size() << '\n';
                    Describe(log,factory,sample.text,runs);
                    Check(std::all_of(runs.begin(),runs.end(),[](const auto& run) { return std::find(run.glyphs.begin(),run.glyphs.end(),0) == run.glyphs.end(); }),"Arabic fixture has missing glyphs");
                    if (sample.contextOracle)
                    {
                        ArabicContext(log,factory,sample,em,runs,injectFailure && i == 3);
                        contexts+=3; ++negatives;
                    }
                    // Independent immediate renderer, fresh layout, same target parameters.
                    // The retained side has no layout or callback owner at draw time.
                    ComPtr<IDWriteBitmapRenderTarget> direct, retained;
                    Hr(interop->CreateBitmapRenderTarget(nullptr,1000,256,&direct)); Hr(direct->SetPixelsPerDip(1));
                    Hr(interop->CreateBitmapRenderTarget(nullptr,1000,256,&retained)); Hr(retained->SetPixelsPerDip(1));
                    for (auto t : {direct.Get(),retained.Get()}) PaintRect(t->GetMemoryDC(),{0,0,1000,256},RGB(14,22,32));
                    auto fresh=ArabicLayout(factory,sample,em);
                    ComPtr<ArabicImmediate> renderer; renderer.Attach(new ArabicImmediate(direct.Get(),params.Get()));
                    Hr(fresh->Draw(nullptr,renderer.Get(),32,64)); fresh.Reset(); renderer.Reset();
                    ArabicNatural(retained.Get(),params.Get(),original,32,64);
                    if (BitmapBytes(direct.Get()) != BitmapBytes(retained.Get()))
                    {
                        SaveBitmap(direct.Get(),bitmapPath+L".arabic-failure-direct.bmp");
                        SaveBitmap(retained.Get(),bitmapPath+L".arabic-failure-retained.bmp");
                        Check(false,"Arabic retained pixels differ from immediate layout");
                    }
                    // Mutating retained output must make this oracle fail. Never alter input/core.
                    auto corrupt=original; corrupt.front().x+=7;
                    PaintRect(retained->GetMemoryDC(),{0,0,1000,256},RGB(14,22,32)); ArabicNatural(retained.Get(),params.Get(),corrupt,32,64);
                    Check(BitmapBytes(direct.Get()) != BitmapBytes(retained.Get()),"Arabic raster negative was not detected"); ++rasterControls;
                    log << "ARABIC_RASTER: immediate=identical shifted=different owners=destroyed\n";
                    const LONG top=48+static_cast<LONG>(i%6)*block;
                    std::wstring label(sample.name,sample.name+strlen(sample.name));
                    TextOutW(dc,12,top,label.data(),static_cast<int>(label.size()));
                    for (unsigned row=0; row<5; ++row) TextOutW(dc,220,top+static_cast<LONG>(row)*lane,L"NLCVP"+row,1);
                    ArabicNatural(panel.Get(),params.Get(),original,260,static_cast<FLOAT>(top));
                    if (sample.split != 3)
                    {
                        std::vector<VT7::Text::Style> styles;
                        const auto length=static_cast<UINT32>(sample.text.size());
                        if (sample.split == 1 || sample.split == 2)
                        {
                            styles={{0,1},{1,2,sample.split == 1 ? DWRITE_FONT_WEIGHT_BOLD : DWRITE_FONT_WEIGHT_NORMAL,
                                sample.split == 2 ? DWRITE_FONT_STYLE_ITALIC : DWRITE_FONT_STYLE_NORMAL}};
                            if (length>2) styles.push_back({2,length});
                        }
                        const auto raw=mapper.Map(key,sample.text,AdapterCells(sample.text),styles);
                        VT7::Text::GlyphFitter fitter(factory,params.Get()); const auto fitted=fitter.Prepare(raw,key);
                        DrawHorizontal(panel.Get(),fitted,260,top+lane);
                        log << "ARABIC_LEGACY: drawn\n";
                    }
                    else
                    {
                        const wchar_t* unavailable=L"Legacy mapper has no explicit per-range font-family input.";
                        TextOutW(dc,260,top+lane,unavailable,static_cast<int>(wcslen(unavailable)));
                        log << "ARABIC_LEGACY: unavailable-family-input\n";
                    }
                    ArabicGrid(log,factory,panel.Get(),params.Get(),runs,groups,places,grid,cells.back().cellEnd,260,top+2*lane,false);
                    ArabicGrid(log,factory,panel.Get(),params.Get(),runs,groups,places,grid,cells.back().cellEnd,260,top+3*lane,true);
                    // P isolates contextual letter forms from grid spacing. It is
                    // proportional and explicitly not a terminal placement policy.
                    ArabicNatural(panel.Get(),params.Get(),ArabicNaturalPlacement(runs,places),260,static_cast<FLOAT>(top+4*lane));
                    log << "ARABIC_NATURAL: repaired visual-order proportional diagnostic-only\n";
                    log << "ARABIC_RESULT: index=" << i << " source=unchanged cells=unchanged projection=bijective\n";
                    ++fixtures;
                }
                SaveBitmap(panel.Get(),bitmapPath+L".arabic-"+std::to_wstring(dip)+L"-"+std::to_wstring(dpi)+L"-"+std::to_wstring(page)+L".bmp");
            }
            log << "ARABIC_CASE_END: fixtures=12 pages=2\n";
        }
        Check(fixtures == 144 && contexts == 180 && negatives == 60 && rasterControls == 144,"Arabic matrix incomplete");
        Check(repaired > 0,"Arabic context experiment did not repair any boundary");
        log << "ARABIC_REPAIRS: changed=" << repaired << " review=" << blocked << '\n';
        log << "ARABIC_SUMMARY: cases=12 fixtures=144 context=180 isolatedNegatives=60 raster=144 rasterNegatives=144 pages=24 failures=0\n";
        log << "ARABIC_LIMITS: diagnostic only; no terminal bidi policy, connected grid typography, cursor/selection UI, cache or Atlas acceptance\n";
    }
}
