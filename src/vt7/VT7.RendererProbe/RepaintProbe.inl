// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
// Diagnostic damage experiment, not Atlas or a terminal session implementation.
namespace
{
    bool HasArea(const RECT& r) { return r.right > r.left && r.bottom > r.top; }
    RECT ClipRect(const RECT& a, const RECT& b) { RECT r{}; IntersectRect(&r,&a,&b); return r; }
    void ExtendRect(RECT& a, const RECT& b) { if (HasArea(b)) { if (HasArea(a)) { RECT r{}; UnionRect(&r,&a,&b); a=r; } else a=b; } }
    bool Touches(const RECT& a, const RECT& b) { return HasArea(ClipRect(a,b)); }
    struct RepaintNode
    {
        unsigned row, column;
        std::wstring text;
        bool italic = false, bold = false, privateFace = false;
        COLORREF color = RGB(235,235,235);
    };
    struct RepaintScene { std::vector<RepaintNode> nodes; bool changedBackground = false; };
    struct RepaintItem { Run run; UINT32 first, end; RECT allocation, ink; bool privateFace; COLORREF color; unsigned owner; };
    struct RepaintFrame { std::vector<RepaintItem> items; std::vector<RECT> owners; bool background; };
    struct RepaintSurface
    {
        GridMetrics grid;
        int width, height;
        RECT viewport;
        ComPtr<IDWriteBitmapRenderTarget> scratch, measure;
        ComPtr<IDWriteRenderingParams> params;
        ComPtr<IDWriteGdiInterop> interop;
        RepaintSurface(IDWriteFactory* factory, IDWriteFontFace* primary, unsigned dip, unsigned dpi) :
            grid(PrimaryMetrics(primary,{dip,dpi,1})), width(64+18*grid.width), height(64+5*grid.height),
            viewport{32,32,width-32,height-32}
        {
            Hr(factory->GetGdiInterop(&interop));
            Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,&scratch));
            Hr(interop->CreateBitmapRenderTarget(nullptr,1200,256,&measure));
            Hr(scratch->SetPixelsPerDip(1)); Hr(measure->SetPixelsPerDip(1));
            Hr(factory->CreateCustomRenderingParams(2.2f,1,1,DWRITE_PIXEL_GEOMETRY_RGB,DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC,&params));
        }
        ComPtr<IDWriteBitmapRenderTarget> Create()
        {
            ComPtr<IDWriteBitmapRenderTarget> target; Hr(interop->CreateBitmapRenderTarget(nullptr,width,height,&target));
            Hr(target->SetPixelsPerDip(1)); PaintRect(target->GetMemoryDC(),{0,0,width,height},RGB(12,65,65)); return target;
        }
        RECT Cell(unsigned row, unsigned column, unsigned count=1) const
        { return {32+static_cast<LONG>(column)*grid.width,32+static_cast<LONG>(row)*grid.height,
            32+static_cast<LONG>(column+count)*grid.width,32+static_cast<LONG>(row+1)*grid.height}; }
    };
    RepaintScene InitialRepaintScene()
    {
        return {{{0,0,L"f",true},{0,7,L"A\u0301\u0302\u0308"},
            {1,4,L"A\u0301\u0302\u0308"},{2,4,L"g\u0323\u0331"},
            {3,4,L"W"},{2,9,L"\U0001f600",false,false,true},
            {2,13,L"A"},{2,15,L"f",true},{4,17,L"g\u0323\u0331"},
            {1,0,L"f",true},{1,1,L"W"},{3,9,L"A"}},false};
    }
    RepaintFrame PrepareRepaint(std::ostream& log, IDWriteFactory* factory, RepaintSurface& surface,
        unsigned dip, const std::vector<PrivateFace>& fonts, const RepaintScene& scene)
    {
        RepaintFrame frame; frame.background=scene.changedBackground;
        std::ostringstream diagnostics;
        for (unsigned owner=0; owner<scene.nodes.size(); ++owner)
        {
            const auto& node=scene.nodes[owner]; const auto cells=CoreCells(node.text);
            Check(!cells.empty() && node.column+cells.back().cellEnd<=18 && node.row<5,"Invalid repaint fixture cell range");
            frame.owners.push_back(surface.Cell(node.row,node.column,cells.back().cellEnd));
            ComPtr<IDWriteTextFormat> format;
            Hr(factory->CreateTextFormat(L"Consolas",nullptr,node.bold?DWRITE_FONT_WEIGHT_BOLD:DWRITE_FONT_WEIGHT_NORMAL,
                node.italic?DWRITE_FONT_STYLE_ITALIC:DWRITE_FONT_STYLE_NORMAL,DWRITE_FONT_STRETCH_NORMAL,static_cast<FLOAT>(dip),L"en-US",&format));
            Hr(format->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP));
            ComPtr<IDWriteTextLayout> layout; Hr(factory->CreateTextLayout(node.text.c_str(),static_cast<UINT32>(node.text.size()),format.Get(),1000,200,&layout));
            ComPtr<Collector> collector; collector.Attach(new Collector()); Hr(layout->Draw(nullptr,collector.Get(),0,0));
            auto runs=std::move(collector->runs); collector.Reset(); layout.Reset(); format.Reset();
            Check(!runs.empty(),"Repaint layout has no retained runs");
            for(const auto& run:runs) Check(run.textStart<=node.text.size() && run.text.size()<=node.text.size()-run.textStart &&
                node.text.substr(run.textStart,run.text.size())==run.text,"Repaint retained source mismatch");
            const auto applied=ApplyPrivateFallback(diagnostics,runs,cells,fonts,node.privateFace);
            Check(!node.privateFace || applied==1,"Repaint private fixture not selected");
            const auto segments=Map(node.text,runs,cells);
            for (auto& run:runs)
            {
                Check(!(run.bidi&1),"Repaint fixture is not an LTR cluster");
                run.em*=surface.grid.pixelsPerDip;
                for(auto& a:run.advances) a*=surface.grid.pixelsPerDip;
                for(auto& o:run.offsets) { o.advanceOffset*=surface.grid.pixelsPerDip; o.ascenderOffset*=surface.grid.pixelsPerDip; }
            }
            for(const auto& segment:segments)
            {
                const auto allocation=surface.Cell(node.row,node.column+segment.firstCell,segment.endCell-segment.firstCell);
                const auto& run=runs[segment.run];
                const bool privateFace=std::any_of(fonts.begin(),fonts.end(),[&](const auto& f){return f.face.Get()==run.face.Get();});
                RepaintItem item{run,segment.firstGlyph,segment.endGlyph,allocation,{},privateFace,node.color,owner};
                DrawGeometry(diagnostics,factory,surface.scratch.Get(),surface.measure.Get(),surface.params.Get(),item.run,item.first,item.end,
                    allocation.left,allocation.top,allocation.right-allocation.left,surface.grid,privateFace,&item.ink,item.color);
                frame.items.push_back(std::move(item));
            }
            log << "REPAINT_SOURCE: owner=" << owner << " row=" << node.row << " column=" << node.column
                << " cells=" << cells.back().cellEnd << " scalars=" << Units(node.text,true) << '\n';
        }
        return frame;
    }
    void DrawRepaintItems(IDWriteFactory* factory, RepaintSurface& surface, const RepaintFrame& frame,
        const RECT& damage, int changedOwner, bool omitNeighbors, unsigned& count)
    {
        std::ostringstream diagnostics;
        for(const auto& item:frame.items)
        {
            if(!Touches(item.ink,damage) || (omitNeighbors && static_cast<int>(item.owner)!=changedOwner)) continue;
            RECT actual{};
            DrawGeometry(diagnostics,factory,surface.scratch.Get(),surface.measure.Get(),surface.params.Get(),item.run,item.first,item.end,
                item.allocation.left,item.allocation.top,item.allocation.right-item.allocation.left,surface.grid,item.privateFace,&actual,item.color);
            Check(EqualRect(&actual,&item.ink)!=FALSE,"Repaint cached ink changed during draw"); ++count;
        }
    }
    void PaintRepaintBackgrounds(RepaintSurface& surface,const RepaintFrame& frame,const RECT& damage)
    {
        for(unsigned row=0;row<5;++row) for(unsigned column=0;column<18;++column)
        {
            const auto area=ClipRect(surface.Cell(row,column),damage);
            if(HasArea(area)) PaintRect(surface.scratch->GetMemoryDC(),area,
                frame.background && row==0 && column==4 ? RGB(110,25,40) : ((row+column)%2?RGB(34,49,65):RGB(20,32,44)));
        }
    }
    void CommitRepaint(RepaintSurface& surface,IDWriteBitmapRenderTarget* target,const RECT& damage)
    {
        Check(BitBlt(target->GetMemoryDC(),damage.left,damage.top,damage.right-damage.left,damage.bottom-damage.top,
            surface.scratch->GetMemoryDC(),damage.left,damage.top,SRCCOPY)!=FALSE,"Repaint damage commit failed");
    }
    void FullRepaint(IDWriteFactory* factory,RepaintSurface& surface,const RepaintFrame& frame,IDWriteBitmapRenderTarget* target)
    {
        PaintRect(surface.scratch->GetMemoryDC(),{0,0,surface.width,surface.height},RGB(12,65,65));
        PaintRepaintBackgrounds(surface,frame,surface.viewport);
        unsigned count=0; DrawRepaintItems(factory,surface,frame,surface.viewport,-1,false,count);
        CommitRepaint(surface,target,surface.viewport);
    }
    RECT RepaintDamage(RepaintSurface& surface,const RepaintFrame& old,const RepaintFrame& next,int owner,bool omitOld)
    {
        RECT damage{};
        if(owner>=0)
        {
            ExtendRect(damage,old.owners.at(owner)); ExtendRect(damage,next.owners.at(owner));
            if(!omitOld) for(const auto& item:old.items) if(static_cast<int>(item.owner)==owner) ExtendRect(damage,item.ink);
            for(const auto& item:next.items) if(static_cast<int>(item.owner)==owner) ExtendRect(damage,item.ink);
        }
        else damage=surface.Cell(0,4);
        return ClipRect(damage,surface.viewport);
    }
    unsigned IncrementalRepaint(IDWriteFactory* factory,RepaintSurface& surface,const RepaintFrame& next,
        IDWriteBitmapRenderTarget* target,const RECT& damage,int changedOwner,bool omitNeighbors)
    {
        Check(HasArea(damage),"Empty repaint damage");
        // The scratch surface starts with the PREVIOUS frame, never the oracle.
        Check(BitBlt(surface.scratch->GetMemoryDC(),0,0,surface.width,surface.height,target->GetMemoryDC(),0,0,SRCCOPY)!=FALSE,"Repaint previous-frame copy failed");
        PaintRepaintBackgrounds(surface,next,damage);
        unsigned count=0; DrawRepaintItems(factory,surface,next,damage,changedOwner,omitNeighbors,count);
        // DrawGlyphRun can touch pixels outside damage on scratch; only damage is
        // committed. This tests a software damage compositor, not DWrite clipping.
        CommitRepaint(surface,target,damage); return count;
    }
    struct RepaintDiff { unsigned mismatch=0,outside=0; int x=-1,y=-1; };
    RepaintDiff CompareRepaint(const std::vector<unsigned char>& expected,const std::vector<unsigned char>& actual,
        const std::vector<unsigned char>& previous,int width,const RECT& damage)
    {
        Check(expected.size()==actual.size() && previous.size()==actual.size(),"Repaint comparison size differs");
        RepaintDiff result;
        for(size_t offset=0;offset<actual.size();offset+=4)
        {
            const int x=static_cast<int>((offset/4)%width),y=static_cast<int>((offset/4)/width);
            const bool changed=actual[offset]!=previous[offset]||actual[offset+1]!=previous[offset+1]||actual[offset+2]!=previous[offset+2];
            const bool differs=actual[offset]!=expected[offset]||actual[offset+1]!=expected[offset+1]||actual[offset+2]!=expected[offset+2];
            if(differs) { if(!result.mismatch) {result.x=x;result.y=y;} ++result.mismatch; }
            if(changed && !(x>=damage.left&&x<damage.right&&y>=damage.top&&y<damage.bottom)) ++result.outside;
        }
        return result;
    }
    void SaveRepaintComparison(RepaintSurface& surface,IDWriteBitmapRenderTarget* reference,IDWriteBitmapRenderTarget* incremental,
        const std::wstring& prefix)
    {
        SaveBitmap(reference,prefix+L".full.bmp"); SaveBitmap(incremental,prefix+L".incremental.bmp");
        auto difference=surface.Create(); const auto a=BitmapBytes(reference),b=BitmapBytes(incremental);
        DIBSECTION dib{}; Check(GetObjectW(GetCurrentObject(difference->GetMemoryDC(),OBJ_BITMAP),sizeof(dib),&dib)==sizeof(dib),"Difference DIB missing");
        auto pixels=static_cast<unsigned char*>(dib.dsBm.bmBits);
        for(size_t i=0;i<a.size();i+=4) { const bool different=a[i]!=b[i]||a[i+1]!=b[i+1]||a[i+2]!=b[i+2]; pixels[i]=0;pixels[i+1]=0;pixels[i+2]=different?255:0;pixels[i+3]=0; }
        SaveBitmap(difference.Get(),prefix+L".difference.bmp");
    }
    void ExerciseRepaint(std::ostream& log,IDWriteFactory* factory,const std::wstring& path,const std::vector<PrivateFace>& fonts)
    {
        ComPtr<IDWriteFontCollection> collection; Hr(factory->GetSystemFontCollection(&collection));
        UINT32 index=0;BOOL exists=FALSE;Hr(collection->FindFamilyName(L"Consolas",&index,&exists));Check(exists!=FALSE,"Repaint primary font absent");
        ComPtr<IDWriteFontFamily> family;Hr(collection->GetFontFamily(index,&family));
        ComPtr<IDWriteFont> font;Hr(family->GetFirstMatchingFont(DWRITE_FONT_WEIGHT_NORMAL,DWRITE_FONT_STRETCH_NORMAL,DWRITE_FONT_STYLE_NORMAL,&font));
        ComPtr<IDWriteFontFace> primary;Hr(font->CreateFontFace(&primary));
        unsigned total=0,negative=0,partial=0;
        const char* names[]{"marks-remove","marks-restore","neighbor-background","background-restore","italic-to-space","italic-restore",
            "narrow-to-wide","wide-to-narrow","combining-add","combining-remove","private-to-normal","private-restore",
            "foreground-change","foreground-restore","style-bold","style-restore","top-marks-remove","top-marks-restore",
            "bottom-marks-remove","bottom-marks-restore"};
        for(const unsigned dip:{12u,18u,24u}) for(const unsigned dpi:{96u,120u,144u,192u})
        {
            RepaintSurface surface(factory,primary.Get(),dip,dpi); auto scene=InitialRepaintScene();
            auto current=PrepareRepaint(log,factory,surface,dip,fonts,scene);
            auto incremental=surface.Create();FullRepaint(factory,surface,current,incremental.Get());
            const auto initial=BitmapBytes(incremental.Get());
            const auto prefix=path+L".repaint-"+std::to_wstring(dip)+L"-"+std::to_wstring(dpi);
            log<<"REPAINT_CASE: dip="<<dip<<" dpi="<<dpi<<" bitmap="<<surface.width<<','<<surface.height<<" viewport="
                <<surface.viewport.left<<','<<surface.viewport.top<<','<<surface.viewport.right<<','<<surface.viewport.bottom<<'\n';
            for(unsigned cycle=0;cycle<2;++cycle) for(unsigned step=0;step<20;++step)
            {
                int owner=-1;
                switch(step)
                {
                case 0:owner=2;scene.nodes[2].text=L"A";break;
                case 1:owner=2;scene.nodes[2].text=L"A\u0301\u0302\u0308";break;
                case 2:scene.changedBackground=true;break;
                case 3:scene.changedBackground=false;break;
                case 4:owner=0;scene.nodes[0].text=L" ";break;
                case 5:owner=0;scene.nodes[0].text=L"f";break;
                case 6:owner=6;scene.nodes[6].text=L"\u4e2d";break;
                case 7:owner=6;scene.nodes[6].text=L"A";break;
                case 8:owner=11;scene.nodes[11].text=L"A\u0301";break;
                case 9:owner=11;scene.nodes[11].text=L"A";break;
                case 10:owner=5;scene.nodes[5].text=L"A";scene.nodes[5].privateFace=false;break;
                case 11:owner=5;scene.nodes[5].text=L"\U0001f600";scene.nodes[5].privateFace=true;break;
                case 12:owner=7;scene.nodes[7].color=RGB(240,140,30);break;
                case 13:owner=7;scene.nodes[7].color=RGB(235,235,235);break;
                case 14:owner=7;scene.nodes[7].bold=true;break;
                case 15:owner=7;scene.nodes[7].bold=false;break;
                case 16:owner=1;scene.nodes[1].text=L"A";break;
                case 17:owner=1;scene.nodes[1].text=L"A\u0301\u0302\u0308";break;
                case 18:owner=8;scene.nodes[8].text=L"g";break;
                case 19:owner=8;scene.nodes[8].text=L"g\u0323\u0331";break;
                }
                const auto next=PrepareRepaint(log,factory,surface,dip,fonts,scene);
                const auto previous=BitmapBytes(incremental.Get());
                auto full=surface.Create();FullRepaint(factory,surface,next,full.Get());const auto expected=BitmapBytes(full.Get());
                if(cycle==0 && (step==0 || step==2))
                {
                    auto broken=surface.Create();Check(BitBlt(broken->GetMemoryDC(),0,0,surface.width,surface.height,incremental->GetMemoryDC(),0,0,SRCCOPY)!=FALSE,"Negative copy failed");
                    const auto badDamage=RepaintDamage(surface,current,next,owner,step==0);
                    IncrementalRepaint(factory,surface,next,broken.Get(),badDamage,owner,step==2);
                    const auto bad=CompareRepaint(expected,BitmapBytes(broken.Get()),previous,surface.width,badDamage);
                    log<<"REPAINT_NEGATIVE: kind="<<(step==0?"omit-old-ink":"omit-neighbors")<<" mismatches="<<bad.mismatch<<" first="<<bad.x<<','<<bad.y<<'\n';
                    if(dip==24 && dpi==192) SaveRepaintComparison(surface,full.Get(),broken.Get(),prefix+(step==0?L".negative-old":L".negative-neighbor"));
                    Check(bad.mismatch>0,"Broken repaint was not detected");++negative;
                }
                const auto damage=RepaintDamage(surface,current,next,owner,false);
                const auto drawn=IncrementalRepaint(factory,surface,next,incremental.Get(),damage,owner,false);
                const auto diff=CompareRepaint(expected,BitmapBytes(incremental.Get()),previous,surface.width,damage);
                log<<"REPAINT_STEP: generation="<<cycle*20+step+1<<" name="<<names[step]<<" damage="<<damage.left<<','<<damage.top<<','<<damage.right<<','<<damage.bottom
                    <<" drawn="<<drawn<<" available="<<next.items.size()<<" mismatch="<<diff.mismatch<<" outside="<<diff.outside<<" first="<<diff.x<<','<<diff.y<<'\n';
                if(diff.mismatch||diff.outside) { SaveRepaintComparison(surface,full.Get(),incremental.Get(),prefix+L".failure-"+std::to_wstring(cycle*20+step+1)); Check(false,"Differential repaint mismatch"); }
                Check(!EqualRect(&damage,&surface.viewport),"Repaint silently used full viewport damage");
                if(drawn<next.items.size()) ++partial;
                current=next;++total;
                if(cycle==0 && step==2) SaveRepaintComparison(surface,full.Get(),incremental.Get(),prefix+L".sample");
            }
            Check(initial==BitmapBytes(incremental.Get()),"Repaint cycle did not restore initial pixels");
            log<<"REPAINT_RESTORED: identical=1\n";
        }
        Check(total==480 && negative==24 && partial==480,"Repaint coverage incomplete");
        log<<"REPAINT_SUMMARY: cases=12 transitions="<<total<<" negativeDetected="<<negative<<" partialDraws="<<partial<<" mismatches=0 outside=0\n";
    }
}
