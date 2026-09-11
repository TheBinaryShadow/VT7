// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
// Whole-shape paint experiment. RTL cell strips are not anatomical glyph owners.
namespace
{
    constexpr COLORREF PaintColors[]{RGB(70,220,255),RGB(255,210,70),RGB(235,235,235)};
    constexpr COLORREF PaintBackground=RGB(14,22,32);

    struct PaintCell
    {
        UINT32 start,end,first,last; // Source units, then diagnostic visual columns.
    };

    std::vector<PaintCell> PaintCells(const ArabicSample& sample, const JoinedSpan& span)
    {
        for (const auto& run : span.natural) Check((run.bidi&1)!=0,"Paint fixture is not uniformly RTL");
        const auto core=CoreCells(sample.text);
        std::vector<PaintCell> result;
        for (const auto& cell : core)
            result.push_back({cell.textStart,cell.textEnd,span.columns-cell.cellEnd,span.columns-cell.cellStart});
        UINT32 source=0,column=span.columns;
        for (const auto& cell : result)
        {
            Check(cell.start==source && cell.end>cell.start && cell.last==column && cell.first<cell.last,"Paint source/column partition differs");
            source=cell.end; column=cell.first;
        }
        Check(source==sample.text.size() && column==0,"Paint partition incomplete");
        return result;
    }

    size_t PaintOwner(const std::vector<PaintCell>& cells, UINT32 source)
    {
        for (size_t i=0; i<cells.size(); ++i) if (source>=cells[i].start && source<cells[i].end) return i;
        Check(false,"Paint source offset outside snapshot"); return 0;
    }

    unsigned PaintIndex(size_t cell, unsigned state, size_t selected)
    {
        return state==0 || (state==2 && cell==selected) ? 2u : static_cast<unsigned>(cell%2);
    }

    void PaintBase(IDWriteBitmapRenderTarget* target, IDWriteRenderingParams* params, IDWriteFactory* factory,
        const JoinedSpan& span, const std::vector<PaintCell>& cells, LONG left, LONG top, unsigned state, size_t selected, bool patterned)
    {
        if (patterned) JoinedBackground(target,span,left-static_cast<LONG>(span.grid.width),top);
        if (state==2)
        {
            const auto& cell=cells.at(selected);
            PaintRect(target->GetMemoryDC(),{left+static_cast<LONG>(cell.first*span.grid.width),top,
                left+static_cast<LONG>(cell.last*span.grid.width),top+static_cast<LONG>(span.grid.height)},RGB(95,45,100));
        }
        JoinedNeighbors(target,params,factory,span,left-static_cast<LONG>(span.grid.width),top);
    }

    void PaintComposite(IDWriteBitmapRenderTarget* target, IDWriteBitmapRenderTarget* staging, IDWriteRenderingParams* params,
        const JoinedSpan& span, const std::vector<PaintCell>& cells, LONG left, LONG baseline,
        unsigned state, size_t selected, const VT7::Text::Key& key, bool inject=false)
    {
        Check(key==span.key,"Stale paint snapshot");
        Check(state<=2 && selected<cells.size(),"Invalid paint state");
        SIZE size{}, other{}; Hr(target->GetSize(&size)); Hr(staging->GetSize(&other));
        Check(size.cx==other.cx && size.cy==other.cy && left>=0 && left+static_cast<LONG>(span.columns*span.grid.width)<=size.cx,"Invalid paint target");
        for (unsigned color=0; color<3; ++color)
        {
            Check(BitBlt(staging->GetMemoryDC(),0,0,size.cx,size.cy,target->GetMemoryDC(),0,0,SRCCOPY)!=FALSE,"Paint staging seed failed");
            LigatureDraw(staging,params,span,left,baseline,PaintColors[inject && color<2 ? 1-color : color],key);
            for (size_t c=0; c<cells.size(); ++c)
            {
                if (PaintIndex(c,state,selected)!=color) continue;
                const auto& cell=cells[c];
                const LONG x=left+cell.first*span.grid.width, width=(cell.last-cell.first)*span.grid.width;
                Check(BitBlt(target->GetMemoryDC(),x,0,width,size.cy,staging->GetMemoryDC(),x,0,SRCCOPY)!=FALSE,"Paint strip commit failed");
            }
        }
    }

    void ExercisePaint(std::ostream& log, IDWriteFactory* factory, const std::wstring& bitmapPath, bool inject)
    {
        const ArabicSample samples[]{
            {"Marked-pair",L"\u0644\u064e\u0627\u0650"},
            {"Joined-pair",L"\u0628\u0644\u0627\u0628"},
            {"Marked-word",L"\u0633\u064e\u0644\u064e\u0627\u0645\u064c"},
            {"Stacked-context",L"\u0628\u0651\u064e\u0644\u0627\u0628"},
            {"Long-joined",L"\u0628\u0628\u0628\u0628\u0628\u0628\u0628\u0628"},
            {"Fallback-marks",L"\u0633\u064e\u0644\u064e\u0627\u0645\u064c",L"Consolas"},
        };
        const UINT32 expectedStart[]{0,1,0,0,1,0}, expectedEnd[]{2,2,2,3,2,2};
        ComPtr<IDWriteGdiInterop> interop; Hr(factory->GetGdiInterop(&interop));
        ComPtr<IDWriteRenderingParams> params; Hr(factory->CreateRenderingParams(&params));
        ComPtr<IDWriteBitmapRenderTarget> measure; Hr(interop->CreateBitmapRenderTarget(nullptr,2048,512,&measure)); Hr(measure->SetPixelsPerDip(1));
        constexpr LONG width=640,height=256,left=96,top=112;
        ComPtr<IDWriteBitmapRenderTarget> test,staging,reference,incremental;
        for (auto output : {test.GetAddressOf(),staging.GetAddressOf(),reference.GetAddressOf(),incremental.GetAddressOf()})
        { Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,output)); Hr((*output)->SetPixelsPerDip(1)); }
        unsigned fixtures=0,sourceChecks=0;
        for (UINT32 dip : {12u,18u,24u}) for (UINT32 dpi : {96u,120u,144u,192u})
        {
            const VT7::Text::Key key{1,1,1,0,80,dpi,static_cast<FLOAT>(dip)};
            const LONG lane=static_cast<LONG>(std::ceil(dip*dpi/96.f*1.8f))+20, block=3*lane+32;
            constexpr LONG pw=1000; const LONG ph=48+6*block;
            ComPtr<IDWriteBitmapRenderTarget> panel,panelStage;
            for (auto output : {panel.GetAddressOf(),panelStage.GetAddressOf()})
            { Hr(interop->CreateBitmapRenderTarget(nullptr,pw,ph,output)); Hr((*output)->SetPixelsPerDip(1)); }
            PaintRect(panel->GetMemoryDC(),{0,0,pw,ph},PaintBackground);
            SetBkMode(panel->GetMemoryDC(),TRANSPARENT); SetTextColor(panel->GetMemoryDC(),RGB(105,200,255));
            const wchar_t* title=L"VT7 0.13: U uniform; C source-cell colors; S source query [1,2) snapped to core cluster. Diagnostic RTL.";
            TextOutW(panel->GetMemoryDC(),12,8,title,static_cast<int>(wcslen(title)));
            log << "PAINT_CASE: dip=" << dip << " dpi=" << dpi << " canvas=" << pw << ',' << ph << '\n';
            for (unsigned i=0; i<6; ++i)
            {
                const auto& sample=samples[i]; std::ostringstream preparation;
                const auto span=JoinedPrepare(preparation,factory,measure.Get(),params.Get(),sample,key);
                const auto cells=PaintCells(sample,span); const auto selected=PaintOwner(cells,1);
                Check(cells[selected].start==expectedStart[i] && cells[selected].end==expectedEnd[i],"Paint mark-selection oracle differs");
                const auto copied=sample.text.substr(cells[selected].start,cells[selected].end-cells[selected].start);
                Check(copied==sample.text.substr(expectedStart[i],expectedEnd[i]-expectedStart[i]),"Paint logical copy oracle differs");
                log << "PAINT_FIXTURE: index=" << i << " name=" << sample.name << " source=" << sample.text.size() << " columns=" << span.columns
                    << " grid=" << span.grid.width << ',' << span.grid.height << " scale=" << span.scale << " scaleY=1\n";
                for (size_t c=0; c<cells.size(); ++c)
                {
                    const auto& cell=cells[c];
                    log << "PAINT_CELL: text=" << cell.start << ',' << cell.end << " visual=" << cell.first << ',' << cell.last << '\n';
                    for (UINT32 s=cell.start; s<cell.end; ++s) { Check(PaintOwner(cells,s)==c,"Paint source round trip differs"); ++sourceChecks; }
                }
                bool invalid=false; try { PaintOwner(cells,static_cast<UINT32>(sample.text.size())); } catch (const std::runtime_error&) { invalid=true; }
                Check(invalid,"Paint invalid source accepted");
                log << "PAINT_SELECTION: query=1,2 snapped=" << cells[selected].start << ',' << cells[selected].end
                    << " visual=" << cells[selected].first << ',' << cells[selected].last << " copy=logical-complete invalid=rejected\n";
                // Direct full-raster draws for each color are selected pixel by pixel,
                // independently of the compositor's BitBlt strips and color passes.
                for (unsigned patterned=0; patterned<2; ++patterned) for (unsigned state=0; state<3; ++state)
                {
                    PaintRect(test->GetMemoryDC(),{0,0,width,height},PaintBackground);
                    PaintBase(test.Get(),params.Get(),factory,span,cells,left,top,state,selected,patterned!=0);
                    const auto before=BitmapBytes(test.Get());
                    std::vector<std::vector<BYTE>> refs;
                    for (unsigned color=0; color<3; ++color)
                    {
                        Check(BitBlt(reference->GetMemoryDC(),0,0,width,height,test->GetMemoryDC(),0,0,SRCCOPY)!=FALSE,"Paint reference seed failed");
                        LigatureDraw(reference.Get(),params.Get(),span,left,top+span.grid.baseline,PaintColors[color],key);
                        refs.push_back(BitmapBytes(reference.Get()));
                    }
                    PaintComposite(test.Get(),staging.Get(),params.Get(),span,cells,left,top+span.grid.baseline,state,selected,key,inject && i==0);
                    const auto actual=BitmapBytes(test.Get());
                    unsigned visible=0;
                    for (size_t p=0; p<actual.size(); p+=4)
                    {
                        const LONG x=static_cast<LONG>((p/4)%width)-left;
                        const std::vector<BYTE>* expected=&before;
                        if (x>=0 && x<static_cast<LONG>(span.columns*span.grid.width))
                        {
                            // Independent source/core lookup from the reversed column.
                            const UINT32 logical=span.columns-1-static_cast<UINT32>(x)/span.grid.width;
                            const auto core=std::find_if(span.cells.begin()+1,span.cells.end()-1,[&](const auto& c){return logical+1>=c.cellStart && logical+1<c.cellEnd;});
                            Check(core!=span.cells.end()-1,"Paint reference column missing");
                            const size_t index=static_cast<size_t>(core-(span.cells.begin()+1));
                            const unsigned color=state==0 || (state==2 && index==selected) ? 2u : static_cast<unsigned>(index%2);
                            expected=&refs[color];
                        }
                        for (unsigned c=0; c<3; ++c) Check(actual[p+c]==(*expected)[p+c],"Paint raster reference differs");
                        if (actual[p]!=before[p] || actual[p+1]!=before[p+1] || actual[p+2]!=before[p+2]) ++visible;
                    }
                    Check(visible>0,"Paint lost all ink");
                    if (state==0) Check(actual==refs[2],"Paint uniform recombination differs");
                    if (state==1) Check(actual!=refs[2],"Paint dropped-color control not detected");
                }
                const auto beforeStale=BitmapBytes(test.Get()); auto stale=key; ++stale.revision; bool rejected=false;
                try { PaintComposite(test.Get(),staging.Get(),params.Get(),span,cells,left,top,1,selected,stale); } catch (const std::runtime_error&) { rejected=true; }
                Check(rejected && beforeStale==BitmapBytes(test.Get()),"Paint stale snapshot touched pixels");
                // Color/selection-only partial damage. Geometry is immutable here.
                const auto damage=JoinedDamage(span,left-span.grid.width,top);
                Check(damage.left>=0 && damage.right<=width && damage.top>=0 && damage.bottom<=height &&
                    (damage.right-damage.left)*(damage.bottom-damage.top)<width*height,"Paint damage invalid");
                std::vector<BYTE> initial;
                const unsigned states[]{0,1,2,1,0};
                for (unsigned step=0; step<5; ++step)
                {
                    PaintRect(test->GetMemoryDC(),{0,0,width,height},PaintBackground);
                    PaintBase(test.Get(),params.Get(),factory,span,cells,left,top,states[step],selected,true);
                    PaintComposite(test.Get(),staging.Get(),params.Get(),span,cells,left,top+span.grid.baseline,states[step],selected,key);
                    if (!step)
                    {
                        Check(BitBlt(incremental->GetMemoryDC(),0,0,width,height,test->GetMemoryDC(),0,0,SRCCOPY)!=FALSE,"Paint initial copy failed");
                        initial=BitmapBytes(incremental.Get()); continue;
                    }
                    const auto before=BitmapBytes(incremental.Get());
                    Check(BitBlt(reference->GetMemoryDC(),0,0,width,height,incremental->GetMemoryDC(),0,0,SRCCOPY)!=FALSE,"Paint repaint seed failed");
                    PaintRect(reference->GetMemoryDC(),damage,PaintBackground);
                    PaintBase(reference.Get(),params.Get(),factory,span,cells,left,top,states[step],selected,true);
                    PaintComposite(reference.Get(),staging.Get(),params.Get(),span,cells,left,top+span.grid.baseline,states[step],selected,key);
                    Check(BitBlt(incremental->GetMemoryDC(),damage.left,damage.top,damage.right-damage.left,damage.bottom-damage.top,
                        reference->GetMemoryDC(),damage.left,damage.top,SRCCOPY)!=FALSE,"Paint partial commit failed");
                    const auto actual=BitmapBytes(incremental.Get());
                    Check(actual==BitmapBytes(test.Get()),"Paint partial repaint differs");
                    for (size_t p=0;p<actual.size();p+=4)
                    {
                        const LONG x=static_cast<LONG>((p/4)%width),y=static_cast<LONG>((p/4)/width);
                        if (x>=damage.left && x<damage.right && y>=damage.top && y<damage.bottom) continue;
                        for (unsigned c=0;c<3;++c) Check(actual[p+c]==before[p+c],"Paint escaped partial damage");
                    }
                }
                Check(BitmapBytes(incremental.Get())==initial,"Paint edit cycle did not restore pixels");
                const LONG y=48+i*block;
                std::wstring label(sample.name,sample.name+strlen(sample.name)); TextOutW(panel->GetMemoryDC(),12,y,label.data(),static_cast<int>(label.size()));
                for (unsigned state=0;state<3;++state)
                {
                    TextOutW(panel->GetMemoryDC(),220,y+state*lane,L"UCS"+state,1);
                    PaintBase(panel.Get(),params.Get(),factory,span,cells,280,y+state*lane,state,selected,true);
                }
                const auto beforePanel=BitmapBytes(panel.Get());
                for (unsigned state=0;state<3;++state)
                    PaintComposite(panel.Get(),panelStage.Get(),params.Get(),span,cells,280,y+state*lane+span.grid.baseline,state,selected,key);
                Check(ChangedOutside(beforePanel,BitmapBytes(panel.Get()),pw,280,280+span.columns*span.grid.width)==0,"Paint panel escaped allocation");
                log << "PAINT_RESULT: index=" << i << " references=6 uniform=2 droppedColor=2 stale=rejected repaints=4 outside=0 cycle=identical selection=spatial-review\n";
                ++fixtures;
            }
            SaveBitmap(panel.Get(),bitmapPath+L".paint-"+std::to_wstring(dip)+L"-"+std::to_wstring(dpi)+L".bmp");
            log << "PAINT_CASE_END: fixtures=6\n";
        }
        Check(fixtures==72,"Paint matrix incomplete");
        log << "PAINT_SUMMARY: cases=12 fixtures=72 sourceChecks=" << sourceChecks
            << " references=432 uniform=144 droppedColor=144 stale=72 repaints=288 images=12 failures=0\n";
    }
}
