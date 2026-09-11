// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#pragma once
#include <windows.h>
#include <dwrite.h>
#include <wrl/client.h>
#include <string>
#include <vector>
#include <ostream>

namespace VT7::FontProbe
{
    struct CellSpan
    {
        UINT32 textStart, textEnd, cellStart, cellEnd;
    };
    // Obtained from the real TerminalCore row, not font advances or wcwidth.
    std::vector<CellSpan> CoreCells(const std::wstring& text);

    struct Run
    {
        Microsoft::WRL::ComPtr<IDWriteFontFace> face;
        std::wstring text, locale;
        UINT32 textStart = 0, bidi = 0;
        BOOL sideways = FALSE;
        FLOAT x = 0, y = 0, em = 0;
        DWRITE_MEASURING_MODE mode{};
        std::vector<UINT16> glyphs, clusters;
        std::vector<FLOAT> advances;
        std::vector<DWRITE_GLYPH_OFFSET> offsets;
    };

    class Collector final : public IDWriteTextRenderer
    {
        LONG references = 1;
    public:
        std::vector<Run> runs;
        HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** object) noexcept override;
        ULONG STDMETHODCALLTYPE AddRef() noexcept override;
        ULONG STDMETHODCALLTYPE Release() noexcept override;
        HRESULT STDMETHODCALLTYPE IsPixelSnappingDisabled(void*, BOOL* value) noexcept override;
        HRESULT STDMETHODCALLTYPE GetCurrentTransform(void*, DWRITE_MATRIX* value) noexcept override;
        HRESULT STDMETHODCALLTYPE GetPixelsPerDip(void*, FLOAT* value) noexcept override;
        HRESULT STDMETHODCALLTYPE DrawGlyphRun(void*, FLOAT, FLOAT, DWRITE_MEASURING_MODE,
            const DWRITE_GLYPH_RUN*, const DWRITE_GLYPH_RUN_DESCRIPTION*, IUnknown*) noexcept override;
        HRESULT STDMETHODCALLTYPE DrawUnderline(void*, FLOAT, FLOAT, const DWRITE_UNDERLINE*, IUnknown*) noexcept override { return S_OK; }
        HRESULT STDMETHODCALLTYPE DrawStrikethrough(void*, FLOAT, FLOAT, const DWRITE_STRIKETHROUGH*, IUnknown*) noexcept override { return S_OK; }
        HRESULT STDMETHODCALLTYPE DrawInlineObject(void*, FLOAT, FLOAT, IDWriteInlineObject*, BOOL, BOOL, IUnknown*) noexcept override { return E_NOTIMPL; }
    };

    void Describe(std::ostream& log, IDWriteFactory* factory, const std::wstring& source, const std::vector<Run>& runs);
    // Throws on structural/ownership/mapping regression. Missing glyphs are observations.
    void Exercise(std::ostream& log, IDWriteFactory* factory, const std::wstring& bitmapPath, bool injectMappingFailure = false, bool injectAdapterFailure = false, bool injectFitFailure = false);
}
