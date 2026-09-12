// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include <LibraryIncludes.h>
#include "Win7FontFallback.hpp"
#include <wrl/implements.h>
#include <bcrypt.h>

using Microsoft::WRL::ComPtr;
namespace VT7::Text
{
    namespace
    {
        class Capture final : public Microsoft::WRL::RuntimeClass<Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>, IDWriteTextRenderer>
        {
        public:
            std::vector<FaceMapping> ranges;
            HRESULT STDMETHODCALLTYPE IsPixelSnappingDisabled(void*, BOOL* p) noexcept override { if (!p) return E_POINTER; *p = TRUE; return S_OK; }
            HRESULT STDMETHODCALLTYPE GetCurrentTransform(void*, DWRITE_MATRIX* p) noexcept override { if (!p) return E_POINTER; *p = {1,0,0,1,0,0}; return S_OK; }
            HRESULT STDMETHODCALLTYPE GetPixelsPerDip(void*, FLOAT* p) noexcept override { if (!p) return E_POINTER; *p = 1; return S_OK; }
            HRESULT STDMETHODCALLTYPE DrawGlyphRun(void*, FLOAT, FLOAT, DWRITE_MEASURING_MODE,
                const DWRITE_GLYPH_RUN* run, const DWRITE_GLYPH_RUN_DESCRIPTION* desc, IUnknown*) noexcept override
            try
            {
                RETURN_HR_IF(E_INVALIDARG, !run || !desc || !run->fontFace || run->isSideways ||
                    !desc->stringLength || desc->textPosition > UINT32_MAX - desc->stringLength);
                FaceMapping range{desc->textPosition, desc->textPosition + desc->stringLength};
                RETURN_IF_FAILED(run->fontFace->QueryInterface(IID_PPV_ARGS(&range.face)));
                ranges.push_back(std::move(range));
                return S_OK;
            }
            CATCH_RETURN()
            HRESULT STDMETHODCALLTYPE DrawUnderline(void*, FLOAT, FLOAT, const DWRITE_UNDERLINE*, IUnknown*) noexcept override { return E_NOTIMPL; }
            HRESULT STDMETHODCALLTYPE DrawStrikethrough(void*, FLOAT, FLOAT, const DWRITE_STRIKETHROUGH*, IUnknown*) noexcept override { return E_NOTIMPL; }
            HRESULT STDMETHODCALLTYPE DrawInlineObject(void*, FLOAT, FLOAT, IDWriteInlineObject*, BOOL, BOOL, IUnknown*) noexcept override { return E_NOTIMPL; }
        };

        void CheckHash(HANDLE file, std::string_view expected)
        {
            BCRYPT_ALG_HANDLE algorithm{};
            THROW_IF_NTSTATUS_FAILED(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0));
            const auto close = wil::scope_exit([&] { BCryptCloseAlgorithmProvider(algorithm, 0); });
            DWORD size{}, received{};
            THROW_IF_NTSTATUS_FAILED(BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH, reinterpret_cast<PUCHAR>(&size), sizeof(size), &received, 0));
            std::vector<UCHAR> object(size);
            BCRYPT_HASH_HANDLE hash{};
            THROW_IF_NTSTATUS_FAILED(BCryptCreateHash(algorithm, &hash, object.data(), size, nullptr, 0, 0));
            const auto destroy = wil::scope_exit([&] { BCryptDestroyHash(hash); });
            UCHAR buffer[65536]; DWORD bytes{};
            do
            {
                THROW_IF_WIN32_BOOL_FALSE(ReadFile(file, buffer, sizeof(buffer), &bytes, nullptr));
                if (bytes) THROW_IF_NTSTATUS_FAILED(BCryptHashData(hash, buffer, bytes, 0));
            } while (bytes);
            UCHAR digest[32];
            THROW_IF_NTSTATUS_FAILED(BCryptFinishHash(hash, digest, sizeof(digest), 0));
            std::string actual;
            for (auto b : digest) actual += fmt::format("{:02x}", b);
            THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_CRC), actual != expected);
        }

        UINT32 Scalar(std::wstring_view text)
        {
            if (text.size() == 1 && (text[0] < 0xd800 || text[0] > 0xdfff)) return text[0];
            if (text.size() == 2 && text[0] >= 0xd800 && text[0] <= 0xdbff && text[1] >= 0xdc00 && text[1] <= 0xdfff)
                return 0x10000 + ((text[0] - 0xd800) << 10) + text[1] - 0xdc00;
            return 0;
        }
    }

    FontFallback::FontFallback(IDWriteFactory* factory) : _factory(factory)
    {
        THROW_HR_IF(E_INVALIDARG, !factory);
        wchar_t executable[32768];
        const auto length = GetModuleFileNameW(nullptr, executable, ARRAYSIZE(executable));
        THROW_LAST_ERROR_IF(!length);
        THROW_HR_IF(E_FAIL, length == ARRAYSIZE(executable));
        const std::wstring path(executable, length);
        const auto directory = path.substr(0, path.find_last_of(L"\\/") + 1) + L"fonts\\";
        struct Asset { const wchar_t* name; const char* hash; };
        static constexpr Asset assets[]{
            {L"unifont-17.0.05.otf", "85701ab9b1e251ee16f4df00b13f22eac311d72b7dab427a7d975fe7f5064702"},
            {L"unifont_upper-17.0.05.otf", "f4fd6d5d752726d384feef175bb780c9f29382cd4941c9e1e6990d7c3822a090"}
        };
        for (const auto& asset : assets)
        {
            const auto filename = directory + asset.name;
            // Hold a read-only share while hashing and asking DirectWrite to load.
            wil::unique_hfile handle(CreateFileW(filename.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
            THROW_LAST_ERROR_IF(!handle.is_valid());
            CheckHash(handle.get(), asset.hash);
            ComPtr<IDWriteFontFile> file;
            THROW_IF_FAILED(factory->CreateFontFileReference(filename.c_str(), nullptr, &file));
            BOOL supported{}; DWRITE_FONT_FILE_TYPE fileType{}; DWRITE_FONT_FACE_TYPE faceType{}; UINT32 count{};
            THROW_IF_FAILED(file->Analyze(&supported, &fileType, &faceType, &count));
            THROW_HR_IF(DWRITE_E_FILEFORMAT, !supported || count != 1);
            auto raw = file.Get();
            for (size_t style = 0; style < _privateFaces.size(); ++style)
            {
                ComPtr<IDWriteFontFace> face; ComPtr<IDWriteFontFace1> face1;
                const auto simulation = static_cast<DWRITE_FONT_SIMULATIONS>(
                    ((style & 1) ? DWRITE_FONT_SIMULATIONS_BOLD : 0) | ((style & 2) ? DWRITE_FONT_SIMULATIONS_OBLIQUE : 0));
                THROW_IF_FAILED(factory->CreateFontFace(faceType, 1, &raw, 0, simulation, &face));
                THROW_IF_FAILED(face.As(&face1));
                _privateFaces[style].push_back(std::move(face1));
            }
        }
    }

    void FontFallback::Configure(IDWriteFontCollection* collection, const std::wstring& family,
        FLOAT emPixels, DWRITE_FONT_WEIGHT weight, const std::wstring& locale)
    {
        std::array<ComPtr<IDWriteTextFormat>, 4> formats;
        for (size_t i = 0; i < formats.size(); ++i)
        {
            THROW_IF_FAILED(_factory->CreateTextFormat(family.c_str(), collection,
                (i & 1) ? DWRITE_FONT_WEIGHT_BOLD : weight, (i & 2) ? DWRITE_FONT_STYLE_ITALIC : DWRITE_FONT_STYLE_NORMAL,
                DWRITE_FONT_STRETCH_NORMAL, emPixels, locale.c_str(), &formats[i]));
            THROW_IF_FAILED(formats[i]->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP));
        }
        _formats = std::move(formats);
        _cache.clear(); _cachedUnits = 0;
    }

    std::vector<FaceMapping> FontFallback::Map(std::wstring_view text, std::span<const UINT16> columns, size_t attributes)
    {
        THROW_HR_IF(E_INVALIDARG, text.empty() || text.size() > 65535 || columns.size() != text.size() + 1 ||
            attributes >= _formats.size() || !_formats[attributes] || !std::is_sorted(columns.begin(), columns.end()));
        for (const auto& c : _cache)
            if (c.attributes == attributes && c.text == text && std::equal(c.columns.begin(), c.columns.end(), columns.begin(), columns.end())) return c.mappings;

        ComPtr<IDWriteTextLayout> layout;
        THROW_IF_FAILED(_factory->CreateTextLayout(text.data(), static_cast<UINT32>(text.size()), _formats[attributes].Get(), 1000000, 1000000, &layout));
        auto capture = Microsoft::WRL::Make<Capture>();
        THROW_IF_NULL_ALLOC(capture);
        THROW_IF_FAILED(layout->Draw(nullptr, capture.Get(), 0, 0));
        auto ranges = std::move(capture->ranges);
        std::sort(ranges.begin(), ranges.end(), [](const auto& a, const auto& b) { return a.start < b.start; });
        UINT32 covered = 0;
        for (const auto& r : ranges)
        {
            THROW_HR_IF(E_UNEXPECTED, r.start != covered || r.end > text.size());
            covered = r.end;
        }
        THROW_HR_IF(E_UNEXPECTED, covered != text.size());

        // Keep core clusters intact even if OS fallback callbacks divide one.
        // Choose the face at the cluster start and let Atlas shape the full cluster.
        // Only standalone symbol clusters can use the pinned private fonts.
        // Bold/italic use DirectWrite simulations; script sequences stay with OS fallback.
        std::vector<FaceMapping> result;
        size_t rangeIndex = 0;
        for (UINT32 begin = 0, end = 0; begin < text.size(); begin = end)
        {
            end = begin + 1;
            while (end < text.size() && columns[end] == columns[begin]) ++end;
            while (ranges[rangeIndex].end <= begin) ++rangeIndex;
            auto face = ranges[rangeIndex].face;
            const auto scalar = Scalar(text.substr(begin, end - begin));
            if ((scalar >= 0x2190 && scalar <= 0x2bff) || (scalar >= 0x1f000 && scalar <= 0x1faff))
            {
                UINT16 glyph{};
                THROW_IF_FAILED(face->GetGlyphIndicesW(&scalar, 1, &glyph));
                if (!glyph)
                    for (const auto& privateFace : _privateFaces[attributes])
                    {
                        THROW_IF_FAILED(privateFace->GetGlyphIndicesW(&scalar, 1, &glyph));
                        if (glyph) { face = privateFace; break; }
                    }
            }
            if (!result.empty() && result.back().face == face) result.back().end = end;
            else result.push_back({begin, end, std::move(face)});
        }
        // Bound retained text and COM faces; settings changes clear the cache.
        if (_cache.size() >= 32 || _cachedUnits + text.size() > 32768) { _cache.clear(); _cachedUnits = 0; }
        if (text.size() <= 32768)
        {
            _cache.push_back({std::wstring(text), {columns.begin(), columns.end()}, attributes, result});
            _cachedUnits += text.size();
        }
        return result;
    }
}
