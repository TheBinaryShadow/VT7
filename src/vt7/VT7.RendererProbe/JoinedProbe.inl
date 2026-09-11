// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
// Fixture-declared Arabic spans, not a general Unicode joining segmenter.
namespace
{
    struct JoinedSpan
    {
        VT7::Text::Key key;
        VT7::Text::Metrics grid;
        std::wstring source;
        std::vector<CellSpan> cells;
        std::vector<Run> original, contextual, natural;
        std::vector<Segment> groups;
        std::vector<Placement> visual;
        UINT32 columns=0;
        unsigned reviews=0;
        FLOAT scale=1, offset=0, advance=0;
        RECT ink{}; // Relative to the allocation's left edge and primary baseline.
        unsigned retries=0;
    };

    void JoinedDraw(IDWriteBitmapRenderTarget* target, IDWriteRenderingParams* params,
        const JoinedSpan& span, LONG left, LONG baseline, const VT7::Text::Key& expected)
    {
        Check(span.key == expected,"Stale joined-span snapshot");
        const DWRITE_MATRIX matrix{span.scale,0,0,1,static_cast<FLOAT>(left)+span.offset,static_cast<FLOAT>(baseline)};
        Hr(target->SetCurrentTransform(&matrix));
        const auto restore=wil::scope_exit([&] { target->SetCurrentTransform(nullptr); });
        // Exactly one shared transform, including all relative run origins.
        // Never fit individual glyphs or style runs independently inside a span.
        for (const auto& run : span.natural)
        {
            const DWRITE_GLYPH_RUN glyphs{run.face.Get(),run.em,static_cast<UINT32>(run.glyphs.size()),
                run.glyphs.data(),run.advances.data(),run.offsets.data(),run.sideways,run.bidi};
            Hr(target->DrawGlyphRun(run.x,run.y,run.mode,&glyphs,params,RGB(235,235,235)));
        }
    }

    RECT JoinedMeasure(IDWriteBitmapRenderTarget* scratch, IDWriteRenderingParams* params, const JoinedSpan& span)
    {
        constexpr LONG width=2048,height=512,left=128,baseline=256;
        PaintRect(scratch->GetMemoryDC(),{0,0,width,height},RGB(14,22,32));
        const auto before=BitmapBytes(scratch);
        JoinedDraw(scratch,params,span,left,baseline,span.key);
        const auto after=BitmapBytes(scratch);
        RECT ink{width,height,0,0};
        for (size_t p=0; p<after.size(); p+=4)
        {
            if (before[p]==after[p] && before[p+1]==after[p+1] && before[p+2]==after[p+2]) continue;
            const LONG x=static_cast<LONG>((p/4)%width), y=static_cast<LONG>((p/4)/width);
            ink.left=std::min(ink.left,x); ink.right=std::max(ink.right,x+1);
            ink.top=std::min(ink.top,y); ink.bottom=std::max(ink.bottom,y+1);
        }
        Check(ink.right>ink.left && ink.bottom>ink.top,"Joined span lost all visible ink");
        Check(ink.left>16 && ink.top>16 && ink.right<width-16 && ink.bottom<height-16,"Joined measurement touched scratch boundary");
        OffsetRect(&ink,-left,-baseline); return ink;
    }

    JoinedSpan JoinedPrepare(std::ostream& log, IDWriteFactory* factory, IDWriteBitmapRenderTarget* scratch,
        IDWriteRenderingParams* params, const ArabicSample& sample, const VT7::Text::Key& key)
    {
        JoinedSpan span; span.key=key; span.source=L"A"+sample.text+L"B";
        span.cells=CoreCells(span.source);
        const auto wordCells=CoreCells(sample.text);
        span.columns=wordCells.back().cellEnd;
        Check(span.columns+2 == span.cells.back().cellEnd,"Joined span changed neighboring core widths");
        Check(span.cells.front().textStart==0 && span.cells.front().textEnd==1 &&
            span.cells.back().textStart==sample.text.size()+1 && span.cells.back().textEnd==span.source.size(),"Joined neighbor source ownership differs");
        Check(span.cells.size()==wordCells.size()+2,"Joined core clusters changed under neighboring text");
        for (size_t i=0; i<wordCells.size(); ++i)
        {
            const auto& a=wordCells[i]; const auto& b=span.cells[i+1];
            Check(a.textStart+1==b.textStart && a.textEnd+1==b.textEnd && a.cellStart+1==b.cellStart && a.cellEnd+1==b.cellEnd,
                "Joined word/core span offset differs");
        }
        VT7::Text::Mapper primary(factory,L"Consolas"); span.grid=primary.Grid(key);
        auto layout=ArabicLayout(factory,sample,span.grid.emPixels);
        span.original=ArabicRetain(layout.Get()); layout.Reset();
        unsigned repaired=0;
        std::ostringstream context; // Do not add records to the frozen 0.10 namespace.
        span.contextual=ArabicRepair(context,factory,sample,span.original,repaired,span.reviews);
        span.groups=Map(sample.text,span.contextual,wordCells);
        span.visual=VisualRuns(span.original,Map(sample.text,span.original,wordCells),span.columns);
        span.natural=ArabicNaturalPlacement(span.contextual,span.visual);
        Check(!span.natural.empty(),"Empty joined shaping result");
        const FLOAT baseline=span.natural.front().y;
        for (auto& run : span.natural)
        {
            run.y-=baseline;
            Check(std::find(run.glyphs.begin(),run.glyphs.end(),0)==run.glyphs.end(),"Joined span has a missing glyph");
            span.advance+=std::accumulate(run.advances.begin(),run.advances.end(),0.f);
        }
        const auto naturalInk=JoinedMeasure(scratch,params,span);
        const FLOAT lo=std::min(0.f,static_cast<FLOAT>(naturalInk.left));
        const FLOAT hi=std::max(span.advance,static_cast<FLOAT>(naturalInk.right));
        const FLOAT allocation=static_cast<FLOAT>(span.columns*span.grid.width);
        Check(hi>lo && allocation>0,"Invalid joined allocation");
        span.scale=std::min(1.f,allocation/(hi-lo));
        for (;;)
        {
            span.offset=(allocation-(hi-lo)*span.scale)/2-lo*span.scale;
            if (span.scale==1) span.offset=std::floor(span.offset); // Stable natural raster phase.
            span.ink=JoinedMeasure(scratch,params,span);
            if (span.ink.left>=0 && span.ink.right<=allocation) break;
            Check(span.retries<16,"Joined fit did not converge");
            ++span.retries; span.scale*=.95f;
        }
        Check(span.scale>0 && span.scale<=1,"Invalid joined scale");
        log << "JOINED_PREPARE: repaired=" << repaired << " reviews=" << span.reviews << " policy="
            << (span.reviews ? "retain-original-boundary" : "context-preserved") << '\n';
        return span;
    }

    void JoinedBackground(IDWriteBitmapRenderTarget* target, const JoinedSpan& span, LONG left, LONG top)
    {
        for (UINT32 c=0; c<span.columns+2; ++c)
            PaintRect(target->GetMemoryDC(),{left+static_cast<LONG>(c*span.grid.width),top,
                left+static_cast<LONG>((c+1)*span.grid.width),top+static_cast<LONG>(span.grid.height)},c%2 ? RGB(27,43,57) : RGB(20,32,45));
    }

    void JoinedNeighbors(IDWriteBitmapRenderTarget* target, IDWriteRenderingParams* params, IDWriteFactory* factory,
        const JoinedSpan& span, LONG left, LONG top)
    {
        VT7::Text::Mapper mapper(factory,L"Consolas");
        for (unsigned i=0; i<2; ++i)
        {
            const std::wstring text=i ? L"B" : L"A";
            const auto mapped=mapper.Map(span.key,text,AdapterCells(text));
            const auto& run=mapped.runs.front();
            const DWRITE_GLYPH_RUN glyphs{run.face.Get(),run.emPixels,static_cast<UINT32>(run.glyphs.size()),
                run.glyphs.data(),run.advances.data(),run.offsets.data(),FALSE,0};
            Hr(target->DrawGlyphRun(static_cast<FLOAT>(left+(i ? span.columns+1 : 0)*span.grid.width),
                static_cast<FLOAT>(top+span.grid.baseline),DWRITE_MEASURING_MODE_NATURAL,&glyphs,params,RGB(235,235,235)));
        }
    }

    void JoinedRow(IDWriteBitmapRenderTarget* target, IDWriteRenderingParams* params, IDWriteFactory* factory,
        const JoinedSpan& span, LONG left, LONG top)
    {
        JoinedBackground(target,span,left,top); JoinedNeighbors(target,params,factory,span,left,top);
        JoinedDraw(target,params,span,left+span.grid.width,top+span.grid.baseline,span.key);
    }

    RECT JoinedDamage(const JoinedSpan& span, LONG left, LONG top)
    {
        RECT result{left-static_cast<LONG>(span.grid.width),top,
            left+static_cast<LONG>((span.columns+3)*span.grid.width),top+static_cast<LONG>(span.grid.height)};
        RECT ink=span.ink; OffsetRect(&ink,left+span.grid.width,top+span.grid.baseline);
        UnionRect(&result,&result,&ink); return result;
    }

    void JoinedRepaint(std::ostream& log, IDWriteFactory* factory, IDWriteGdiInterop* interop,
        IDWriteBitmapRenderTarget* scratch, IDWriteRenderingParams* params, VT7::Text::Key key, const std::wstring& path)
    {
        constexpr LONG width=1024,height=384,left=128,top=160;
        const ArabicSample states[]{
            {"plain",L"\u0633\u0644\u0627\u0645"},
            {"marks",L"\u0633\u064e\u0644\u064e\u0627\u0645\u064c"},
            {"wide",L"\u0633\u200c\u0633\u200c\u0633"},
            {"bold",L"\u0628\u0628\u0628",L"Arial",1},
            {"family",L"\u0628\u0628\u0628",L"Arial",3},
            {"lam-alef",L"\u0644\u0627",L"Arial",1},
            {"plain",L"\u0633\u0644\u0627\u0645"},
        };
        std::ostringstream preparation;
        auto previous=JoinedPrepare(preparation,factory,scratch,params,states[0],key);
        ComPtr<IDWriteBitmapRenderTarget> full,incremental,staging;
        for (auto output : {full.GetAddressOf(),incremental.GetAddressOf(),staging.GetAddressOf()})
        { Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,output)); Hr((*output)->SetPixelsPerDip(1)); }
        PaintRect(incremental->GetMemoryDC(),{0,0,width,height},RGB(14,22,32)); JoinedRow(incremental.Get(),params,factory,previous,left,top);
        const auto initial=BitmapBytes(incremental.Get());
        for (unsigned step=1; step<7; ++step)
        {
            ++key.revision;
            auto current=JoinedPrepare(preparation,factory,scratch,params,states[step],key);
            RECT damage{}, a=JoinedDamage(previous,left,top), b=JoinedDamage(current,left,top); UnionRect(&damage,&a,&b);
            Check(damage.left>=0 && damage.top>=0 && damage.right<=width && damage.bottom<=height &&
                (damage.right-damage.left)*(damage.bottom-damage.top)<width*height,"Joined damage invalid or full viewport");
            const auto before=BitmapBytes(incremental.Get());
            PaintRect(full->GetMemoryDC(),{0,0,width,height},RGB(14,22,32)); JoinedRow(full.Get(),params,factory,current,left,top);
            Check(BitBlt(staging->GetMemoryDC(),0,0,width,height,incremental->GetMemoryDC(),0,0,SRCCOPY)!=FALSE,"Joined staging seed failed");
            PaintRect(staging->GetMemoryDC(),damage,RGB(14,22,32)); JoinedRow(staging.Get(),params,factory,current,left,top);
            Check(BitBlt(incremental->GetMemoryDC(),damage.left,damage.top,damage.right-damage.left,damage.bottom-damage.top,
                staging->GetMemoryDC(),damage.left,damage.top,SRCCOPY)!=FALSE,"Joined partial commit failed");
            const auto actual=BitmapBytes(incremental.Get()), expected=BitmapBytes(full.Get());
            if (actual!=expected)
            {
                SaveBitmap(full.Get(),path+L".failure-full.bmp"); SaveBitmap(incremental.Get(),path+L".failure-incremental.bmp");
                Check(false,"Joined partial repaint differs from fresh full redraw");
            }
            for (size_t p=0; p<actual.size(); p+=4)
            {
                const LONG x=static_cast<LONG>((p/4)%width),y=static_cast<LONG>((p/4)/width);
                if (x>=damage.left && x<damage.right && y>=damage.top && y<damage.bottom) continue;
                Check(actual[p]==before[p] && actual[p+1]==before[p+1] && actual[p+2]==before[p+2],"Joined repaint escaped damage");
            }
            log << "JOINED_REPAINT: step=" << step << " damage=" << damage.left << ',' << damage.top << ',' << damage.right << ',' << damage.bottom
                << " mismatches=0 outside=0\n";
            previous=std::move(current);
        }
        Check(BitmapBytes(incremental.Get())==initial,"Joined edit cycle did not restore initial pixels");
    }

    void ExerciseJoined(std::ostream& log, IDWriteFactory* factory, const std::wstring& bitmapPath, bool injectFailure)
    {
        const ArabicSample samples[]{
            {"Plain",L"\u0633\u0644\u0627\u0645"},
            {"Marks",L"\u0633\u064e\u0644\u064e\u0627\u0645\u064c"},
            {"Bold-boundary",L"\u0628\u0628\u0628",L"Arial",1},
            {"Italic-boundary",L"\u0628\u0628\u0628",L"Arial",2},
            {"Face-boundary",L"\u0628\u0628\u0628",L"Arial",3},
            {"Fallback-bold",L"\u0628\u0628\u0628",L"Consolas",1},
            {"Lam-alef-split",L"\u0644\u0627",L"Arial",1},
            {"Join-controls",L"\u0628\u200c\u0628\u200d\u0628"},
            {"Wide-nonjoining",L"\u0633\u200c\u0633\u200c\u0633"},
            {"Long-joined",L"\u0628\u0628\u0628\u0628\u0628\u0628\u0628\u0628\u0628\u0628\u0628\u0628"},
        };
        ComPtr<IDWriteGdiInterop> interop; Hr(factory->GetGdiInterop(&interop));
        ComPtr<IDWriteRenderingParams> params; Hr(factory->CreateRenderingParams(&params));
        ComPtr<IDWriteBitmapRenderTarget> scratch; Hr(interop->CreateBitmapRenderTarget(nullptr,2048,512,&scratch)); Hr(scratch->SetPixelsPerDip(1));
        unsigned fixtures=0, compressed=0, reviews=0;
        for (UINT32 dip : {12u,18u,24u}) for (UINT32 dpi : {96u,120u,144u,192u})
        {
            const VT7::Text::Key key{1,1,1,0,80,dpi,static_cast<FLOAT>(dip)};
            const LONG lane=static_cast<LONG>(std::ceil(dip*dpi/96.f*1.8f))+20, block=3*lane+32;
            constexpr UINT32 width=1100; const UINT32 height=48+10*block;
            ComPtr<IDWriteBitmapRenderTarget> panel; Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,&panel)); Hr(panel->SetPixelsPerDip(1));
            const auto dc=panel->GetMemoryDC(); PaintRect(dc,{0,0,width,static_cast<LONG>(height)},RGB(14,22,32));
            SetBkMode(dc,TRANSPARENT); SetTextColor(dc,RGB(105,200,255));
            const wchar_t* title=L"VT7 0.11: S separate cells; J shared-span fit between A/B; P natural word. Diagnostic only.";
            TextOutW(dc,12,8,title,static_cast<int>(wcslen(title)));
            log << "JOINED_CASE: dip=" << dip << " dpi=" << dpi << " canvas=" << width << ',' << height << '\n';
            for (unsigned i=0; i<10; ++i)
            {
                const auto& sample=samples[i];
                log << "JOINED_FIXTURE: index=" << i << " name=" << sample.name << '\n';
                auto span=JoinedPrepare(log,factory,scratch.Get(),params.Get(),sample,key);
                reviews+=span.reviews; if (span.scale<1) ++compressed;
                const LONG allocation=span.columns*span.grid.width;
                log << "JOINED_SPAN: source=" << span.source.size() << " columns=" << span.columns+2 << " grid=" << span.grid.width << ',' << span.grid.height
                    << " allocation=" << allocation << " scale=" << span.scale << " offset=" << span.offset << " scaleY=1 retries=" << span.retries
                    << " ink=" << span.ink.left << ',' << span.ink.top << ',' << span.ink.right << ',' << span.ink.bottom << '\n';
                for (const auto& c : span.cells) log << "JOINED_CELL: text=" << c.textStart << ',' << c.textEnd << " cells=" << c.cellStart << ',' << c.cellEnd << '\n';
                for (const auto& g : span.groups) log << "JOINED_OWNER: text=" << g.textStart+1 << ',' << g.textEnd+1 << " cells=" << g.firstCell+1 << ',' << g.endCell+1 << '\n';
                // Compare an independently assembled natural reference under the
                // shared transform with the retained fitted span's draw path.
                PaintRect(scratch->GetMemoryDC(),{0,0,2048,512},RGB(14,22,32));
                const auto before=BitmapBytes(scratch.Get());
                auto tested=span; if (injectFailure && i==0) tested.natural.front().x+=5;
                JoinedDraw(scratch.Get(),params.Get(),tested,128,256,key);
                const auto actual=BitmapBytes(scratch.Get());
                unsigned changed=0;
                Check(ChangedOutside(before,actual,2048,128,128+allocation,&changed)==0 && changed>0,"Joined allocation protection failed");
                PaintRect(scratch->GetMemoryDC(),{0,0,2048,512},RGB(14,22,32));
                const DWRITE_MATRIX matrix{span.scale,0,0,1,128+span.offset,256}; Hr(scratch->SetCurrentTransform(&matrix));
                auto reference=ArabicNaturalPlacement(span.contextual,span.visual); const FLOAT baseline=reference.front().y;
                for (auto& run : reference) run.y-=baseline;
                ArabicNatural(scratch.Get(),params.Get(),reference,0,0); Hr(scratch->SetCurrentTransform(nullptr));
                Check(actual==BitmapBytes(scratch.Get()),"Joined shared-transform reference differs");
                // A displaced piece must differ even when its ink stays in allocation.
                auto broken=span; broken.natural.front().x+=5;
                PaintRect(scratch->GetMemoryDC(),{0,0,2048,512},RGB(14,22,32)); JoinedDraw(scratch.Get(),params.Get(),broken,128,256,key);
                Check(actual!=BitmapBytes(scratch.Get()),"Joined spacing negative not detected");
                auto stale=key; ++stale.revision; bool rejected=false;
                try { JoinedDraw(scratch.Get(),params.Get(),span,128,256,stale); } catch (const std::runtime_error&) { rejected=true; }
                Check(rejected,"Joined stale snapshot accepted");
                log << "JOINED_CHECK: reference=identical displaced=different outside=0 visible=" << changed << " stale=rejected\n";
                if (i==8)
                {
                    auto unfit=span; unfit.scale=1; unfit.offset=0;
                    PaintRect(scratch->GetMemoryDC(),{0,0,2048,512},RGB(14,22,32));
                    JoinedDraw(scratch.Get(),params.Get(),unfit,128,256,key);
                    const auto escaped=ChangedOutside(before,BitmapBytes(scratch.Get()),2048,128,128+allocation);
                    Check(escaped>0,"Joined unfitted overflow negative was not detected");
                    log << "JOINED_OVERFLOW: unfittedOutside=" << escaped << '\n';
                }
                const LONG top=48+i*block;
                std::wstring label(sample.name,sample.name+strlen(sample.name)); TextOutW(dc,12,top,label.data(),static_cast<int>(label.size()));
                for (unsigned row=0; row<3; ++row) TextOutW(dc,220,top+row*lane,L"SJP"+row,1);
                JoinedBackground(panel.Get(),span,260,top); JoinedNeighbors(panel.Get(),params.Get(),factory,span,260,top);
                std::ostringstream separated;
                ArabicGrid(separated,factory,panel.Get(),params.Get(),span.contextual,span.groups,span.visual,span.grid,span.columns,260+span.grid.width,top,true);
                JoinedBackground(panel.Get(),span,260,top+lane); JoinedNeighbors(panel.Get(),params.Get(),factory,span,260,top+lane);
                const auto neighbors=BitmapBytes(panel.Get());
                JoinedDraw(panel.Get(),params.Get(),span,260+span.grid.width,top+lane+span.grid.baseline,key);
                Check(ChangedOutside(neighbors,BitmapBytes(panel.Get()),width,260+span.grid.width,260+span.grid.width+allocation)==0,
                    "Joined final colored row escaped allocation");
                log << "JOINED_PRESENT: outside=0\n";
                ArabicNatural(panel.Get(),params.Get(),span.natural,260+static_cast<FLOAT>(span.grid.width),static_cast<FLOAT>(top+2*lane+span.grid.baseline));
                log << "JOINED_RESULT: index=" << i << " source=unchanged ownership=complete boundary=" << (span.reviews ? "REVIEW" : "preserved") << '\n';
                ++fixtures;
            }
            const auto path=bitmapPath+L".joined-"+std::to_wstring(dip)+L"-"+std::to_wstring(dpi)+L".bmp";
            SaveBitmap(panel.Get(),path);
            JoinedRepaint(log,factory,interop.Get(),scratch.Get(),params.Get(),key,path);
            log << "JOINED_CASE_END: fixtures=10 repaints=6\n";
        }
        Check(fixtures==120 && compressed>=12,"Joined matrix incomplete");
        log << "JOINED_SUMMARY: cases=12 fixtures=120 compressed=" << compressed << " reviews=" << reviews
            << " references=120 spacingNegatives=120 overflowNegatives=12 stale=120 repaints=72 failures=0\n";
    }
}
