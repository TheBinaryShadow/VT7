// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
// Policy comparison only. Spatial slices are not character-owned glyph outlines.
namespace
{
    struct LigatureSample
    {
        const char* name;
        const wchar_t* text;
        const wchar_t* family;
        unsigned style; // 0 paint only, 1 alef bold, 2 lam bold, 3 italic, 4 family.
    };

    ComPtr<IDWriteTextLayout> LigatureLayout(IDWriteFactory* factory, const LigatureSample& sample, FLOAT em)
    {
        auto layout=ArabicLayout(factory,{sample.name,sample.text,sample.family},em);
        if (sample.style==1) Hr(layout->SetFontWeight(DWRITE_FONT_WEIGHT_BOLD,{1,1}));
        if (sample.style==2) Hr(layout->SetFontWeight(DWRITE_FONT_WEIGHT_BOLD,{0,1}));
        if (sample.style==3) Hr(layout->SetFontStyle(DWRITE_FONT_STYLE_ITALIC,{1,1}));
        if (sample.style==4) Hr(layout->SetFontFamilyName(L"Times New Roman",{1,1}));
        return layout;
    }

    // Shape the ORIGINAL two scalars in the exact physical face selected for
    // one source position. Never substitute presentation forms or cut glyph arrays.
    std::vector<Run> LigatureUniform(std::ostream& log, IDWriteFactory* factory, const LigatureSample& sample,
        FLOAT em, IDWriteFontFace* selected)
    {
        ComPtr<IDWriteFontCollection> collection; Hr(factory->GetSystemFontCollection(&collection,FALSE));
        ComPtr<IDWriteFont> font; Hr(collection->GetFontFromFontFace(selected,&font));
        ComPtr<IDWriteFontFamily> family; Hr(font->GetFontFamily(&family));
        ComPtr<IDWriteLocalizedStrings> names; Hr(family->GetFamilyNames(&names));
        const auto name=Name(names.Get());
        auto layout=ArabicLayout(factory,{sample.name,sample.text,name.c_str()},em);
        Hr(layout->SetFontWeight(font->GetWeight(),{0,2}));
        Hr(layout->SetFontStyle(font->GetStyle(),{0,2}));
        Hr(layout->SetFontStretch(font->GetStretch(),{0,2}));
        auto runs=ArabicRetain(layout.Get());
        log << "LIGATURE_UNIFORM: fixture=" << sample.name << " runs=" << runs.size();
        for (const auto& run : runs)
        {
            log << " source=" << run.textStart << ',' << run.text.size() << " sameFace=" << ArabicSameFace(run.face.Get(),selected) << " clusters=";
            for (auto c : run.clusters) log << c << ',';
        }
        log << '\n';
        Check(runs.size()==1 && runs[0].textStart==0 && runs[0].text==sample.text &&
            runs[0].clusters.size()==2 && ArabicSameFace(runs[0].face.Get(),selected),"Ligature whole-source ownership or face differs");
        Check(sample.family==std::wstring(L"Consolas") || runs[0].clusters[0]==runs[0].clusters[1],
            "Ligature explicit-font shared cluster missing");
        return runs;
    }

    JoinedSpan LigatureSpan(IDWriteFactory* factory, const LigatureSample& sample,
        const VT7::Text::Key& key, const std::vector<Run>& runs)
    {
        JoinedSpan span; span.key=key; span.source=L"A"+std::wstring(sample.text)+L"B";
        span.cells=CoreCells(span.source); span.columns=2;
        Check(span.cells.size()==4,"Ligature core source ownership differs");
        for (UINT32 c=0; c<4; ++c)
            Check(span.cells[c].textStart==c && span.cells[c].textEnd==c+1 &&
                span.cells[c].cellStart==c && span.cells[c].cellEnd==c+1,"Ligature core allocation changed");
        VT7::Text::Mapper primary(factory,L"Consolas"); span.grid=primary.Grid(key);
        const auto cells=CoreCells(sample.text);
        span.groups=Map(sample.text,runs,cells);
        span.visual=VisualRuns(runs,span.groups,2);
        span.natural=ArabicNaturalPlacement(runs,span.visual);
        Check(!span.natural.empty(),"Ligature empty retained shape");
        const auto baseline=span.natural.front().y;
        for (auto& run : span.natural)
        {
            run.y-=baseline;
            Check(std::find(run.glyphs.begin(),run.glyphs.end(),0)==run.glyphs.end(),"Ligature missing glyph");
            span.advance+=std::accumulate(run.advances.begin(),run.advances.end(),0.f);
        }
        return span;
    }

    // Equal scale for both complete variants, individual centering, same primary
    // baseline. This does NOT imply that their outlines agree at the paint seam.
    void LigatureFit(IDWriteBitmapRenderTarget* scratch, IDWriteRenderingParams* params,
        JoinedSpan& a, JoinedSpan& b)
    {
        const auto ai=JoinedMeasure(scratch,params,a), bi=JoinedMeasure(scratch,params,b);
        const FLOAT al=std::min(0.f,static_cast<FLOAT>(ai.left)), bl=std::min(0.f,static_cast<FLOAT>(bi.left));
        const FLOAT aw=std::max(a.advance,static_cast<FLOAT>(ai.right))-al;
        const FLOAT bw=std::max(b.advance,static_cast<FLOAT>(bi.right))-bl;
        const FLOAT allocation=static_cast<FLOAT>(2*a.grid.width);
        Check(aw>0 && bw>0,"Ligature empty natural bounds");
        a.scale=b.scale=std::min(1.f,allocation/std::max(aw,bw));
        for (unsigned retry=0;; ++retry)
        {
            a.offset=(allocation-aw*a.scale)/2-al*a.scale;
            b.offset=(allocation-bw*b.scale)/2-bl*b.scale;
            if (a.scale==1) { a.offset=std::floor(a.offset); b.offset=std::floor(b.offset); }
            a.ink=JoinedMeasure(scratch,params,a); b.ink=JoinedMeasure(scratch,params,b);
            if (a.ink.left>=0 && b.ink.left>=0 && a.ink.right<=allocation && b.ink.right<=allocation) break;
            Check(retry<16,"Ligature fit did not converge"); a.scale*=.95f; b.scale=a.scale;
        }
    }

    void LigatureDraw(IDWriteBitmapRenderTarget* target, IDWriteRenderingParams* params,
        const JoinedSpan& span, LONG left, LONG baseline, COLORREF color, const VT7::Text::Key& key)
    {
        Check(key==span.key,"Stale ligature snapshot");
        const DWRITE_MATRIX transform{span.scale,0,0,1,left+span.offset,static_cast<FLOAT>(baseline)};
        Hr(target->SetCurrentTransform(&transform));
        const auto restore=wil::scope_exit([&] { target->SetCurrentTransform(nullptr); });
        for (const auto& run : span.natural)
        {
            const DWRITE_GLYPH_RUN glyphs{run.face.Get(),run.em,static_cast<UINT32>(run.glyphs.size()),
                run.glyphs.data(),run.advances.data(),run.offsets.data(),run.sideways,run.bidi};
            Hr(target->DrawGlyphRun(run.x,run.y,run.mode,&glyphs,params,color));
        }
    }

    // Render each WHOLE ligature against the destination background, then commit
    // disjoint vertical strips. No DC clipping assumptions, alpha/color masks,
    // glyph splitting or row-height clip. RTL lam owns the right spatial strip.
    void LigatureComposite(IDWriteBitmapRenderTarget* target, IDWriteBitmapRenderTarget* staging,
        IDWriteRenderingParams* params, const JoinedSpan& lam, const JoinedSpan& alef,
        LONG left, LONG baseline, COLORREF lamColor, COLORREF alefColor,
        const VT7::Text::Key& key)
    {
        Check(key==lam.key && key==alef.key,"Stale ligature snapshot");
        SIZE size{}, other{}; Hr(target->GetSize(&size)); Hr(staging->GetSize(&other));
        Check(size.cx==other.cx && size.cy==other.cy && left>=0 && left+static_cast<LONG>(2*lam.grid.width)<=size.cx,
            "Ligature staging dimensions differ");
        const LONG seam=left+lam.grid.width;
        for (unsigned side=0; side<2; ++side)
        {
            Check(BitBlt(staging->GetMemoryDC(),0,0,size.cx,size.cy,target->GetMemoryDC(),0,0,SRCCOPY)!=FALSE,"Ligature staging seed failed");
            LigatureDraw(staging,params,side ? lam : alef,left,baseline,side ? lamColor : alefColor,key);
            const LONG x=side ? seam : left;
            const LONG width=static_cast<LONG>(lam.grid.width);
            Check(BitBlt(target->GetMemoryDC(),x,0,width,size.cy,staging->GetMemoryDC(),x,0,SRCCOPY)!=FALSE,"Ligature strip commit failed");
        }
    }

    void ExerciseLigature(std::ostream& log, IDWriteFactory* factory, const std::wstring& bitmapPath, bool inject)
    {
        const LigatureSample samples[]{
            {"Paint-only",L"\u0644\u0627",L"Arial",0},
            {"Alef-bold",L"\u0644\u0627",L"Arial",1},
            {"Lam-bold",L"\u0644\u0627",L"Arial",2},
            {"Alef-italic",L"\u0644\u0627",L"Arial",3},
            {"Alef-family",L"\u0644\u0627",L"Arial",4},
            {"Fallback-bold",L"\u0644\u0627",L"Consolas",1},
            {"Hamza-bold",L"\u0644\u0623",L"Arial",1},
            {"Madda-bold",L"\u0644\u0622",L"Arial",1},
        };
        ComPtr<IDWriteGdiInterop> interop; Hr(factory->GetGdiInterop(&interop));
        ComPtr<IDWriteRenderingParams> params; Hr(factory->CreateRenderingParams(&params));
        ComPtr<IDWriteBitmapRenderTarget> measure; Hr(interop->CreateBitmapRenderTarget(nullptr,2048,512,&measure)); Hr(measure->SetPixelsPerDip(1));
        constexpr LONG tw=256, th=160, left=80, baseline=100;
        constexpr COLORREF white=RGB(235,235,235), cyan=RGB(70,220,255), yellow=RGB(255,210,70), bg=RGB(14,22,32);
        ComPtr<IDWriteBitmapRenderTarget> test, staging, refLam, refAlef;
        for (auto output : {test.GetAddressOf(),staging.GetAddressOf(),refLam.GetAddressOf(),refAlef.GetAddressOf()})
        { Hr(interop->CreateBitmapRenderTarget(nullptr,tw,th,output)); Hr((*output)->SetPixelsPerDip(1)); }
        unsigned fixtures=0, reviews=0, sharedClusters=0;
        for (UINT32 dip : {12u,18u,24u}) for (UINT32 dpi : {96u,120u,144u,192u})
        {
            const VT7::Text::Key key{1,1,1,0,80,dpi,static_cast<FLOAT>(dip)};
            const LONG lane=static_cast<LONG>(std::ceil(dip*dpi/96.f*1.8f))+20, block=5*lane+32;
            constexpr UINT32 width=1100; const UINT32 height=48+4*block;
            log << "LIGATURE_CASE: dip=" << dip << " dpi=" << dpi << " canvas=" << width << ',' << height << '\n';
            for (unsigned page=0; page<2; ++page)
            {
                ComPtr<IDWriteBitmapRenderTarget> panel, panelStaging;
                for (auto output : {panel.GetAddressOf(),panelStaging.GetAddressOf()})
                { Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,output)); Hr((*output)->SetPixelsPerDip(1)); }
                const auto dc=panel->GetMemoryDC(); PaintRect(dc,{0,0,width,static_cast<LONG>(height)},bg);
                SetBkMode(dc,TRANSPARENT); SetTextColor(dc,RGB(105,200,255));
                const wchar_t* title=L"VT7 0.12: N native; L whole lam style; A whole alef style; X spatial hybrid REVIEW; C same-shape color.";
                TextOutW(dc,12,8,title,static_cast<int>(wcslen(title)));
                for (unsigned i=page*4; i<(page+1)*4; ++i)
                {
                    const auto& sample=samples[i];
                    auto layout=LigatureLayout(factory,sample,dip*dpi/96.f);
                    const auto original=ArabicRetain(layout.Get()); layout.Reset();
                    const auto lr=LigatureUniform(log,factory,sample,dip*dpi/96.f,ArabicFaceAt(original,0));
                    const auto ar=LigatureUniform(log,factory,sample,dip*dpi/96.f,ArabicFaceAt(original,1));
                    auto lam=LigatureSpan(factory,sample,key,lr), alef=LigatureSpan(factory,sample,key,ar);
                    auto native=LigatureSpan(factory,sample,key,original), unused=native;
                    LigatureFit(measure.Get(),params.Get(),lam,alef); LigatureFit(measure.Get(),params.Get(),native,unused);
                    const bool same=ArabicSameFace(lr.front().face.Get(),ar.front().face.Get());
                    const bool sharedLam=lr[0].clusters[0]==lr[0].clusters[1], sharedAlef=ar[0].clusters[0]==ar[0].clusters[1];
                    sharedClusters+=static_cast<unsigned>(sharedLam)+static_cast<unsigned>(sharedAlef);
                    Check(same==(sample.style==0),"Ligature requested outline boundary disappeared");
                    log << "LIGATURE_FIXTURE: index=" << i << " name=" << sample.name << '\n';
                    log << "LIGATURE_SOURCE: scalars=" << static_cast<unsigned>(sample.text[0]) << ',' << static_cast<unsigned>(sample.text[1])
                        << " cells=2 sharedLam=" << sharedLam << " sharedAlef=" << sharedAlef << " exactFaces=1 sameFace=" << same << '\n';
                    log << "LIGATURE_FIT: grid=" << lam.grid.width << ',' << lam.grid.height << " scale=" << lam.scale
                        << " scaleY=1 lamInk=" << lam.ink.left << ',' << lam.ink.top << ',' << lam.ink.right << ',' << lam.ink.bottom
                        << " alefInk=" << alef.ink.left << ',' << alef.ink.top << ',' << alef.ink.right << ',' << alef.ink.bottom << '\n';
                    // Independent per-pixel reference selects complete raster variants.
                    // Exercise both uniform and alternating cell backgrounds, and
                    // white hybrid versus paint-only colors on ONE unchanged outline.
                    unsigned checks=0, negatives=0;
                    for (unsigned patterned=0; patterned<2; ++patterned) for (unsigned color=0; color<2; ++color)
                    {
                        const auto& second=color ? lam : alef;
                        const COLORREF lc=color ? cyan : white, ac=color ? yellow : white;
                        for (auto target : {test.Get(),refLam.Get(),refAlef.Get()})
                        {
                            PaintRect(target->GetMemoryDC(),{0,0,tw,th},bg);
                            if (patterned) JoinedBackground(target,lam,left-lam.grid.width,baseline-lam.grid.baseline);
                        }
                        const auto before=BitmapBytes(test.Get());
                        LigatureDraw(refLam.Get(),params.Get(),lam,left,baseline,lc,key);
                        LigatureDraw(refAlef.Get(),params.Get(),second,left,baseline,ac,key);
                        const auto l=BitmapBytes(refLam.Get()), a=BitmapBytes(refAlef.Get());
                        LigatureComposite(test.Get(),staging.Get(),params.Get(),lam,second,left,baseline,lc,
                            inject && i==0 && color ? lc : ac,key);
                        auto actual=BitmapBytes(test.Get());
                        unsigned visibleLeft=0,visibleRight=0;
                        for (size_t p=0; p<actual.size(); p+=4)
                        {
                            const LONG x=static_cast<LONG>((p/4)%tw);
                            const auto& expected=x<left || x>=left+static_cast<LONG>(2*lam.grid.width) ? before : (x<left+static_cast<LONG>(lam.grid.width) ? a : l);
                            for (unsigned c=0; c<3; ++c) Check(actual[p+c]==expected[p+c],"Ligature composite reference differs");
                            if (actual[p]!=before[p] || actual[p+1]!=before[p+1] || actual[p+2]!=before[p+2])
                            { if (x<left+static_cast<LONG>(lam.grid.width)) ++visibleLeft; else ++visibleRight; }
                        }
                        Check(visibleLeft>0 && visibleRight>0,"Ligature spatial style region lost all ink");
                        Check(ChangedOutside(before,actual,tw,left,left+2*lam.grid.width)==0,"Ligature escaped allocation");
                        // A whole-word/one-color shortcut must not pass paint preservation.
                        if (color) { Check(actual!=l && actual!=a,"Ligature dropped-color negative not detected"); ++negatives; }
                        else if (same) Check(actual==l && actual==a,"Ligature identical-style seam changed raster");
                        ++checks;
                    }
                    auto stale=key; ++stale.revision;
                    const auto beforeStale=BitmapBytes(test.Get()); bool rejected=false;
                    try { LigatureComposite(test.Get(),staging.Get(),params.Get(),lam,alef,left,baseline,white,white,stale); }
                    catch (const std::runtime_error&) { rejected=true; }
                    Check(rejected && beforeStale==BitmapBytes(test.Get()),"Ligature stale snapshot touched pixels");
                    log << "LIGATURE_CHECK: references=" << checks << " droppedColor=" << negatives << " outside=0 bothRegions=visible stale=rejected\n";
                    const LONG top=48+(i%4)*block;
                    std::wstring label(sample.name,sample.name+strlen(sample.name)); TextOutW(dc,12,top,label.data(),static_cast<int>(label.size()));
                    for (unsigned row=0; row<5; ++row)
                    {
                        const LONG y=top+row*lane;
                        TextOutW(dc,220,y,L"NLAXC"+row,1);
                        JoinedBackground(panel.Get(),lam,260,y); JoinedNeighbors(panel.Get(),params.Get(),factory,lam,260,y);
                        const auto neighbors=BitmapBytes(panel.Get());
                        if (row<3) JoinedDraw(panel.Get(),params.Get(),row==0 ? native : row==1 ? lam : alef,260+lam.grid.width,y+lam.grid.baseline,key);
                        else LigatureComposite(panel.Get(),panelStaging.Get(),params.Get(),lam,row==3 ? alef : lam,
                            260+lam.grid.width,y+lam.grid.baseline,row==3 ? white : cyan,row==3 ? white : yellow,key);
                        Check(ChangedOutside(neighbors,BitmapBytes(panel.Get()),width,260+lam.grid.width,260+3*lam.grid.width)==0,"Ligature comparison escaped allocation");
                    }
                    log << "LIGATURE_RESULT: index=" << i << " source=unchanged regions=spatial-not-character-owned policy="
                        << (same ? "paint-only" : "REVIEW") << " panelGuards=5\n";
                    if (!same) ++reviews;
                    ++fixtures;
                }
                SaveBitmap(panel.Get(),bitmapPath+L".ligature-"+std::to_wstring(dip)+L"-"+std::to_wstring(dpi)+L"-"+std::to_wstring(page)+L".bmp");
            }
            log << "LIGATURE_CASE_END: fixtures=8\n";
        }
        Check(fixtures==96 && reviews==84,"Ligature matrix incomplete");
        log << "LIGATURE_SUMMARY: cases=12 fixtures=96 sharedClusters=" << sharedClusters
            << " references=384 droppedColor=192 stale=96 reviews=84 images=24 failures=0\n";
    }
}
