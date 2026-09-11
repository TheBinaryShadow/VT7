// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include "FontAnalysis.hpp"
#include "../VT7.Renderer/Win7TextMapper.hpp"
#include <dwrite_1.h>
#include <bcrypt.h>
#include <wil/resource.h>
#include <algorithm>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <numeric>
#include <set>
#include <sstream>
#include <stdexcept>

using Microsoft::WRL::ComPtr;
namespace VT7::FontProbe
{
    namespace
    {
        struct Fixture { const char* name; const wchar_t* text; const wchar_t* family; DWRITE_FONT_WEIGHT weight; DWRITE_FONT_STYLE style; };
        void Check(bool value, const char* reason) { if (!value) throw std::runtime_error(reason); }
        void Hr(HRESULT value) { if (FAILED(value)) throw std::runtime_error("DirectWrite/font diagnostic operation failed"); }
        std::string Utf8(const std::wstring& text)
        {
            if (text.empty()) return {};
            const auto size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
            Check(size > 0, "Invalid diagnostic UTF-16");
            std::string result(size, '\0');
            Check(WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), result.data(), size, nullptr, nullptr) == size, "UTF-8 conversion failed");
            return result;
        }
        std::string Units(const std::wstring& text, bool scalars = false)
        {
            std::ostringstream out;
            out << std::hex << std::uppercase << std::setfill('0');
            for (size_t i = 0; i < text.size(); ++i)
            {
                UINT32 value = text[i];
                if (scalars && value >= 0xd800 && value <= 0xdbff && i + 1 < text.size() && text[i + 1] >= 0xdc00 && text[i + 1] <= 0xdfff)
                    value = 0x10000 + ((value - 0xd800) << 10) + (text[++i] - 0xdc00);
                out << (scalars ? "U+" : "\\u") << std::setw(value > 0xffff ? 6 : 4) << value << ' ';
            }
            return out.str();
        }
        std::wstring Name(IDWriteLocalizedStrings* names)
        {
            if (!names || !names->GetCount()) return L"unavailable";
            UINT32 index = 0, length = 0; BOOL exists = FALSE;
            Hr(names->FindLocaleName(L"en-US", &index, &exists));
            if (!exists) index = 0;
            Hr(names->GetStringLength(index, &length));
            std::wstring result(length + 1, L'\0');
            Hr(names->GetString(index, result.data(), length + 1));
            result.resize(length);
            return result;
        }
        std::string HashFile(const std::wstring& path)
        {
            BCRYPT_ALG_HANDLE algorithm = nullptr;
            Check(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) >= 0, "SHA256 provider unavailable");
            const auto close = wil::scope_exit([&] { BCryptCloseAlgorithmProvider(algorithm, 0); });
            DWORD objectSize = 0, received = 0;
            Check(BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH, reinterpret_cast<PUCHAR>(&objectSize), sizeof(objectSize), &received, 0) >= 0, "SHA256 object size unavailable");
            std::vector<UCHAR> storage(objectSize);
            BCRYPT_HASH_HANDLE hash = nullptr;
            Check(BCryptCreateHash(algorithm, &hash, storage.data(), objectSize, nullptr, 0, 0) >= 0, "SHA256 creation failed");
            const auto destroy = wil::scope_exit([&] { BCryptDestroyHash(hash); });
            wil::unique_hfile file(CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
            Check(file.is_valid(), "Font file cannot be read");
            UCHAR buffer[65536]; DWORD bytes = 0;
            do
            {
                Check(ReadFile(file.get(), buffer, sizeof(buffer), &bytes, nullptr) != FALSE, "Font hash read failed");
                if (bytes) Check(BCryptHashData(hash, buffer, bytes, 0) >= 0, "Font hash update failed");
            } while (bytes);
            UCHAR digest[32];
            Check(BCryptFinishHash(hash, digest, sizeof(digest), 0) >= 0, "Font hash finish failed");
            std::ostringstream out;
            out << std::hex << std::setfill('0');
            for (const auto byte : digest) out << std::setw(2) << static_cast<unsigned>(byte);
            return out.str();
        }
        void Face(std::ostream& log, IDWriteFactory* factory, IDWriteFontFace* face)
        {
            log << "  faceIndex=" << face->GetIndex() << " simulations=" << face->GetSimulations() << " type=" << face->GetType() << '\n';
            ComPtr<IDWriteFontCollection> collection;
            ComPtr<IDWriteFont> font;
            Hr(factory->GetSystemFontCollection(&collection, FALSE));
            const auto hr = collection->GetFontFromFontFace(face, &font);
            if (SUCCEEDED(hr))
            {
                ComPtr<IDWriteFontFamily> family; ComPtr<IDWriteLocalizedStrings> names;
                Hr(font->GetFontFamily(&family)); Hr(family->GetFamilyNames(&names));
                log << "  family=" << Utf8(Name(names.Get()));
                names.Reset(); Hr(font->GetFaceNames(&names));
                log << " face=" << Utf8(Name(names.Get()));
                names.Reset(); BOOL exists = FALSE;
                Hr(font->GetInformationalStrings(DWRITE_INFORMATIONAL_STRING_VERSION_STRINGS, &names, &exists));
                log << " version=" << (exists ? Utf8(Name(names.Get())) : "unavailable") << '\n';
            }
            else log << "  family/face/version unavailable: HRESULT=" << hr << '\n';
            UINT32 count = 0;
            Hr(face->GetFiles(&count, nullptr));
            std::vector<IDWriteFontFile*> files(count, nullptr);
            const auto release = wil::scope_exit([&] { for (auto* file : files) if (file) file->Release(); });
            Hr(face->GetFiles(&count, files.data()));
            for (auto* file : files)
            {
                ComPtr<IDWriteFontFileLoader> loader; ComPtr<IDWriteLocalFontFileLoader> local;
                Hr(file->GetLoader(&loader));
                if (FAILED(loader.As(&local))) { log << "  file=non-local loader; path/hash unavailable\n"; continue; }
                const void* key = nullptr; UINT32 keySize = 0, length = 0;
                Hr(file->GetReferenceKey(&key, &keySize));
                Hr(local->GetFilePathLengthFromKey(key, keySize, &length));
                std::wstring path(length + 1, L'\0');
                Hr(local->GetFilePathFromKey(key, keySize, path.data(), length + 1));
                path.resize(length);
                log << "  file=" << Utf8(path) << '\n';
                try { const auto hash = HashFile(path); log << "  SHA256=" << hash << '\n'; }
                catch (const std::exception& error) { log << "  SHA256 unavailable: " << error.what() << '\n'; }
            }
        }
        struct Segment { size_t run; UINT32 firstGlyph, endGlyph, textStart, textEnd, firstCell, endCell; };
        std::vector<Segment> Map(const std::wstring& text, const std::vector<Run>& runs, const std::vector<CellSpan>& cells)
        {
            std::vector<Segment> result;
            std::vector<unsigned> covered(text.size());
            for (size_t r = 0; r < runs.size(); ++r)
            {
                const auto& run = runs[r];
                Check(!run.glyphs.empty() && run.clusters.size() == run.text.size() && run.advances.size() == run.glyphs.size() && run.offsets.size() == run.glyphs.size(), "Invalid retained array sizes");
                for (const auto index : run.clusters) Check(index < run.glyphs.size(), "Invalid retained cluster index");
                std::vector<unsigned> glyphCoverage(run.glyphs.size());
                Check(!run.sideways && run.textStart <= text.size() && run.text.size() <= text.size() - run.textStart, "Run range invalid");
                Check(text.substr(run.textStart, run.text.size()) == run.text, "Copied callback text differs");
                // Merge shaping clusters when DirectWrite splits a core cell. Never
                // derive terminal width from glyph count or natural font advances.
                UINT32 begin = 0;
                while (begin < run.text.size())
                {
                    const auto start = run.textStart + begin;
                    auto cell = std::find_if(cells.begin(), cells.end(), [&](const auto& c) { return c.textStart == start; });
                    Check(cell != cells.end(), "Font run bisects core cluster: adapter decision required");
                    UINT32 end = begin + 1;
                    for (; end < run.text.size(); ++end)
                    {
                        if (run.clusters[end] == run.clusters[end - 1]) continue;
                        if (std::any_of(cells.begin(), cells.end(), [&](const auto& c) { return c.textEnd == run.textStart + end; })) break;
                    }
                    const auto lastCell = std::find_if(cells.begin(), cells.end(), [&](const auto& c) { return c.textEnd == run.textStart + end; });
                    Check(lastCell != cells.end(), "Run end bisects core cluster: adapter decision required");
                    UINT32 firstGlyph = *std::min_element(run.clusters.begin() + begin, run.clusters.begin() + end);
                    UINT32 endGlyph = static_cast<UINT32>(run.glyphs.size());
                    const auto maxStart = *std::max_element(run.clusters.begin() + begin, run.clusters.begin() + end);
                    for (const auto index : run.clusters) if (index > maxStart) endGlyph = std::min(endGlyph, static_cast<UINT32>(index));
                    result.push_back({r, firstGlyph, endGlyph, start, run.textStart + end, cell->cellStart, lastCell->cellEnd});
                    for (auto g = firstGlyph; g < endGlyph; ++g) ++glyphCoverage.at(g);
                    for (auto i = start; i < run.textStart + end; ++i) ++covered.at(i);
                    begin = end;
                }
                Check(std::all_of(glyphCoverage.begin(), glyphCoverage.end(), [](auto n) { return n == 1; }), "Mapped glyph coverage differs");
            }
            Check(std::all_of(covered.begin(), covered.end(), [](auto n) { return n == 1; }), "Mapped UTF-16 coverage differs");
            return result;
        }
        struct Coverage { ComPtr<IDWriteFontFace> face; UINT16 glyph = 0; };
        struct PrivateFace { ComPtr<IDWriteFontFace> face; const char* name; };
        std::vector<PrivateFace> LoadPrivateFonts(std::ostream& log, IDWriteFactory* factory)
        {
            std::wstring executable(32768, L'\0');
            const auto length = GetModuleFileNameW(nullptr, executable.data(), static_cast<DWORD>(executable.size()));
            Check(length && length < executable.size(), "Could not resolve executable font directory");
            executable.resize(length);
            const auto slash = executable.find_last_of(L"\\/");
            Check(slash != std::wstring::npos, "Executable path has no directory");
            const auto directory = executable.substr(0, slash + 1) + L"fonts\\";
            struct Asset { const wchar_t* file; const char* name; const char* hash; UINT32 sample; };
            const Asset assets[]{
                {L"unifont-17.0.05.otf", "Unifont", "85701ab9b1e251ee16f4df00b13f22eac311d72b7dab427a7d975fe7f5064702", 0x262f},
                {L"unifont_upper-17.0.05.otf", "Unifont Upper", "f4fd6d5d752726d384feef175bb780c9f29382cd4941c9e1e6990d7c3822a090", 0x1f600}
            };
            std::vector<PrivateFace> result;
            for (const auto& asset : assets)
            {
                const auto path = directory + asset.file;
                Check(HashFile(path) == asset.hash, "Private font SHA256 mismatch");
                ComPtr<IDWriteFontFile> file; Hr(factory->CreateFontFileReference(path.c_str(), nullptr, &file));
                BOOL supported = FALSE; DWRITE_FONT_FILE_TYPE fileType{}; DWRITE_FONT_FACE_TYPE faceType{}; UINT32 count = 0;
                Hr(file->Analyze(&supported, &fileType, &faceType, &count));
                Check(supported && count == 1, "Private font format unsupported");
                auto* raw = file.Get(); ComPtr<IDWriteFontFace> face;
                Hr(factory->CreateFontFace(faceType, 1, &raw, 0, DWRITE_FONT_SIMULATIONS_NONE, &face));
                UINT16 glyph = 0; Hr(face->GetGlyphIndices(&asset.sample, 1, &glyph));
                Check(glyph != 0, "Private font required scalar missing");
                const UINT32 unsupported = 0x10ffff; UINT16 absent = 0;
                Hr(face->GetGlyphIndices(&unsupported, 1, &absent));
                Check(absent == 0, "Private font unsupported-scalar oracle failed");
                log << "PRIVATE_FONT: " << asset.name << " version=17.0.05 type=" << faceType << " sampleGlyph=" << glyph
                    << " file=" << Utf8(path) << " SHA256=" << asset.hash << '\n';
                result.push_back({face, asset.name});
            }
            log << "PASS: Private font loading, pinned hashes, BMP/SMP coverage and absent scalar\n";
            return result;
        }
        bool StandaloneSymbol(const std::wstring& text, UINT32& scalar)
        {
            if (text.size() == 1 && !(text[0] >= 0xd800 && text[0] <= 0xdfff)) scalar = text[0];
            else if (text.size() == 2 && text[0] >= 0xd800 && text[0] <= 0xdbff && text[1] >= 0xdc00 && text[1] <= 0xdfff)
                scalar = 0x10000 + ((text[0] - 0xd800) << 10) + text[1] - 0xdc00;
            else return false;
            // Initial probe scope excludes shaping-dependent scripts and sequences.
            return (scalar >= 0x2190 && scalar <= 0x2bff) || (scalar >= 0x1f000 && scalar <= 0x1faff);
        }
        unsigned ApplyPrivateFallback(std::ostream& log, std::vector<Run>& runs, const std::vector<CellSpan>& cells,
            const std::vector<PrivateFace>& fonts, bool forced)
        {
            unsigned applied = 0;
            for (auto& run : runs)
            {
                if (!forced && std::find(run.glyphs.begin(), run.glyphs.end(), 0) == run.glyphs.end()) continue;
                UINT32 scalar = 0;
                const auto cell = std::find_if(cells.begin(), cells.end(), [&](const auto& c) { return c.textStart == run.textStart && c.textEnd == run.textStart + run.text.size(); });
                if ((run.bidi & 1) || run.sideways || !StandaloneSymbol(run.text, scalar) || cell == cells.end() || run.glyphs.size() != 1)
                { log << "PRIVATE_FALLBACK_DEFERRED: multi-scalar, script, direction, or cross-cell/run boundary\n"; continue; }
                for (const auto& font : fonts)
                {
                    UINT16 glyph = 0; Hr(font.face->GetGlyphIndices(&scalar, 1, &glyph));
                    if (!glyph) continue;
                    DWRITE_FONT_METRICS metrics{}; font.face->GetMetrics(&metrics);
                    Check(metrics.designUnitsPerEm > 0, "Private font has invalid em metrics");
                    DWRITE_GLYPH_METRICS gm{}; Hr(font.face->GetDesignGlyphMetrics(&glyph, 1, &gm, FALSE));
                    run.face = font.face; run.glyphs = {glyph}; run.clusters.assign(run.text.size(), 0);
                    run.advances = {gm.advanceWidth * run.em / metrics.designUnitsPerEm}; run.offsets = {{0,0}};
                    ++applied;
                    log << "PRIVATE_FALLBACK: " << (forced ? "forced-test" : "missing-system-glyph") << " scalars=" << Units(run.text, true)
                        << "face=" << font.name << " glyph=" << glyph << " source/cells preserved\n";
                    break;
                }
            }
            return applied;
        }
        const char* CoverageStatus(UINT32 supporting, UINT32 errors)
        { return supporting ? "FOUND" : errors ? "INDETERMINATE" : "NONE_IN_COLLECTION"; }
        Coverage ScanCoverage(std::ostream& log, IDWriteFactory* factory)
        {
            // Query scalar coverage independently of TextLayout's fallback choices.
            const UINT32 scalar = 0x1f600;
            ComPtr<IDWriteFontCollection> collection;
            Hr(factory->GetSystemFontCollection(&collection, FALSE));
            Coverage result;
            UINT32 fonts = 0, supported = 0, errors = 0;
            log << "\nCOVERAGE_SCAN: U+01F600; DirectWrite system collection snapshot; no installation or refresh\n";
            for (UINT32 f = 0; f < collection->GetFontFamilyCount(); ++f)
            {
                ComPtr<IDWriteFontFamily> family;
                if (FAILED(collection->GetFontFamily(f, &family))) { ++errors; continue; }
                for (UINT32 i = 0; i < family->GetFontCount(); ++i)
                {
                    ++fonts;
                    try
                    {
                        ComPtr<IDWriteFont> font; ComPtr<IDWriteFontFace> face;
                        Hr(family->GetFont(i, &font));
                        BOOL has = FALSE; Hr(font->HasCharacter(scalar, &has));
                        Hr(font->CreateFontFace(&face));
                        UINT16 glyph = 0; Hr(face->GetGlyphIndices(&scalar, 1, &glyph));
                        Check((has != FALSE) == (glyph != 0), "HasCharacter/cmap disagreement");
                        if (!has) continue;
                        ++supported;
                        // Coverage is established even if optional identity collection fails.
                        // First observed face is diagnostic only, not a fallback preference.
                        if (!result.face) { result.face = face; result.glyph = glyph; }
                        log << "COVERAGE_CANDIDATE: familyIndex=" << f << " fontIndex=" << i << " glyph=" << glyph << '\n';
                        Face(log, factory, face.Get());
                    }
                    catch (const std::exception& error)
                    { ++errors; log << "COVERAGE_ERROR: familyIndex=" << f << " fontIndex=" << i << ' ' << error.what() << '\n'; }
                }
            }
            Check(fonts > 0, "Empty system font collection");
            log << "COVERAGE_RESULT: fonts=" << fonts << " supportingFaces=" << supported << " errors=" << errors
                << " status=" << CoverageStatus(supported, errors) << '\n';
            return result;
        }
        struct Fit { FLOAT scale, offset; bool natural = false; };
        Fit FitBounds(FLOAT left, FLOAT right, FLOAT allocated)
        {
            Check(std::isfinite(left) && std::isfinite(right) && right >= left && allocated > 2, "Invalid fitting bounds");
            // One pixel on each side for the transformed rasterizer's edge support.
            const auto scale = right > left ? std::min(1.f, (allocated - 2) / (right - left)) : 1.f;
            return {scale, (allocated - (right - left) * scale) / 2 - left * scale};
        }
        Fit SelectFit(FLOAT left, FLOAT right, FLOAT natural, FLOAT allocated)
        {
            Check(std::isfinite(natural) && natural >= 0, "Invalid natural advance");
            auto fit = FitBounds(left, right, allocated);
            // At the probe's fixed 96 DPI, an integer baseline preserves raster phase.
            // Cell ownership never grows. Only natural ink may use a 2 px damage halo.
            const auto offset = std::floor((allocated - natural) / 2);
            if (natural <= allocated && left + offset >= -2 && right + offset <= allocated + 2)
                fit = {1, offset, true};
            return fit;
        }
        struct FitStats { unsigned natural = 0, compressed = 0; };
        bool DrawFitted(std::ostream& log, IDWriteFactory* factory, IDWriteBitmapRenderTarget* target,
            IDWriteRenderingParams* params, const Run& run, UINT32 first, UINT32 end, FLOAT x, FLOAT y, FLOAT allocated, FitStats& stats)
        {
            const auto natural = std::accumulate(run.advances.begin() + first, run.advances.begin() + end, 0.f);
            Check(natural >= 0 && end > first, "Invalid fitted run");
            const DWRITE_GLYPH_RUN glyphs{run.face.Get(), run.em, end - first, run.glyphs.data() + first,
                run.advances.data() + first, run.offsets.data() + first, run.sideways, run.bidi};
            const auto origin = (run.bidi & 1) ? natural : 0.f;
            ComPtr<IDWriteGlyphRunAnalysis> analysis;
            Hr(factory->CreateGlyphRunAnalysis(&glyphs, 1, nullptr, DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC,
                run.mode, origin, 0, &analysis));
            RECT ink{}; Hr(analysis->GetAlphaTextureBounds(DWRITE_TEXTURE_CLEARTYPE_3x1, &ink));
            const auto left = std::min(0.f, static_cast<FLOAT>(ink.left));
            const auto right = std::max(natural, static_cast<FLOAT>(ink.right));
            const auto fit = SelectFit(left, right, natural, allocated);
            const auto guard = fit.natural ? 2.f : 0.f;
            const DWRITE_MATRIX transform{fit.scale, 0, 0, 1, x + fit.offset, y};
            Hr(target->SetCurrentTransform(&transform));
            const auto restore = wil::scope_exit([&] { target->SetCurrentTransform(nullptr); });
            RECT drawn{};
            Hr(target->DrawGlyphRun(origin, 0, run.mode, &glyphs, params, RGB(235,235,235), &drawn));
            const bool empty = drawn.right <= drawn.left || drawn.bottom <= drawn.top;
            log << "FIT: natural=" << natural << " ink=[" << ink.left << ',' << ink.right << ") allocated=" << allocated
                << " scale=" << fit.scale << " policy=" << (fit.natural ? "natural" : "compressed")
                << " guard=" << guard << " cellPixels=[" << x << ',' << x + allocated << ") drawn=[" << drawn.left << ',' << drawn.right << ")\n";
            Check(empty || (drawn.left >= x - guard && drawn.right <= x + allocated + guard), "Fitted ink escaped declared damage bounds");
            if (fit.natural) ++stats.natural; else ++stats.compressed;
            return !empty;
        }
        struct Placement { size_t run; UINT32 logicalFirst, logicalEnd, visualFirst; };
        std::vector<Placement> VisualRuns(const std::vector<Run>& runs, const std::vector<Segment>& segments, UINT32 totalCells)
        {
            std::vector<Placement> result;
            for (size_t r = 0; r < runs.size(); ++r)
            {
                UINT32 first = totalCells, end = 0;
                for (const auto& span : segments) if (span.run == r) { first = std::min(first, span.firstCell); end = std::max(end, span.endCell); }
                Check(first < end, "Visual run has no core cells");
                result.push_back({r, first, end, 0});
            }
            // DirectWrite has already resolved bidi. Use its physical run order once,
            // never reverse its glyph arrays or run the Unicode bidi algorithm twice.
            const auto left = [&](size_t r) { const auto& run = runs[r]; return run.x - ((run.bidi & 1) ? std::accumulate(run.advances.begin(), run.advances.end(), 0.f) : 0.f); };
            std::stable_sort(result.begin(), result.end(), [&](const auto& a, const auto& b) { return left(a.run) < left(b.run); });
            UINT32 next = 0;
            std::vector<UINT32> logicalToVisual(totalCells, totalCells), visualToLogical(totalCells, totalCells);
            for (auto& place : result)
            {
                place.visualFirst = next;
                for (auto c = place.logicalFirst; c < place.logicalEnd; ++c)
                {
                    const auto v = next + ((runs[place.run].bidi & 1) ? place.logicalEnd - 1 - c : c - place.logicalFirst);
                    Check(v < totalCells && logicalToVisual.at(c) == totalCells && visualToLogical[v] == totalCells, "Visual cell overlap");
                    logicalToVisual[c] = v; visualToLogical[v] = c;
                }
                next += place.logicalEnd - place.logicalFirst;
            }
            Check(next == totalCells, "Visual cell coverage differs");
            for (UINT32 c = 0; c < totalCells; ++c) Check(visualToLogical.at(logicalToVisual[c]) == c, "Visual cell round-trip failed");
            return result;
        }
        void SaveBitmap(IDWriteBitmapRenderTarget* target, const std::wstring& path)
        {
            const auto bitmap = static_cast<HBITMAP>(GetCurrentObject(target->GetMemoryDC(), OBJ_BITMAP));
            DIBSECTION section{};
            Check(GetObjectW(bitmap, sizeof(section), &section) == sizeof(section) && section.dsBm.bmBits && section.dsBm.bmBitsPixel == 32, "Expected 32-bit diagnostic DIB");
            const auto bytes = static_cast<DWORD>(section.dsBm.bmWidthBytes * section.dsBm.bmHeight);
            BITMAPFILEHEADER file{};
            file.bfType = 0x4d42; file.bfOffBits = sizeof(file) + sizeof(BITMAPINFOHEADER); file.bfSize = file.bfOffBits + bytes;
            auto info = section.dsBmih;
            info.biSize = sizeof(info); info.biSizeImage = bytes; info.biCompression = BI_RGB;
            // DirectWrite's memory target is top-down; GetObject's header reports
            // a positive height on this path. Preserve the actual scanline order.
            info.biHeight = -section.dsBm.bmHeight;
            std::ofstream out(path, std::ios::binary | std::ios::trunc);
            out.write(reinterpret_cast<const char*>(&file), sizeof(file));
            out.write(reinterpret_cast<const char*>(&info), sizeof(info));
            out.write(static_cast<const char*>(section.dsBm.bmBits), bytes);
            out.close(); Check(static_cast<bool>(out), "Could not save font diagnostic bitmap");
        }
    }

    HRESULT Collector::QueryInterface(REFIID iid, void** object) noexcept
    {
        if (!object) return E_POINTER;
        *object = nullptr;
        if (iid == __uuidof(IUnknown) || iid == __uuidof(IDWriteTextRenderer) || iid == __uuidof(IDWritePixelSnapping))
        { *object = static_cast<IDWriteTextRenderer*>(this); AddRef(); return S_OK; }
        return E_NOINTERFACE;
    }
    ULONG Collector::AddRef() noexcept { return InterlockedIncrement(&references); }
    ULONG Collector::Release() noexcept { const auto n = InterlockedDecrement(&references); if (!n) delete this; return n; }
    HRESULT Collector::IsPixelSnappingDisabled(void*, BOOL* value) noexcept { if (!value) return E_POINTER; *value = FALSE; return S_OK; }
    HRESULT Collector::GetCurrentTransform(void*, DWRITE_MATRIX* value) noexcept { if (!value) return E_POINTER; *value = {1,0,0,1,0,0}; return S_OK; }
    HRESULT Collector::GetPixelsPerDip(void*, FLOAT* value) noexcept { if (!value) return E_POINTER; *value = 1; return S_OK; }
    HRESULT Collector::DrawGlyphRun(void*, FLOAT x, FLOAT y, DWRITE_MEASURING_MODE mode, const DWRITE_GLYPH_RUN* run,
        const DWRITE_GLYPH_RUN_DESCRIPTION* desc, IUnknown*) noexcept
    {
        try
        {
            if (!run || !desc || !run->fontFace || !run->glyphCount || !run->glyphIndices || !run->glyphAdvances ||
                !desc->string || !desc->stringLength || !desc->clusterMap) return E_INVALIDARG;
            Run owned;
            owned.face = run->fontFace; owned.text.assign(desc->string, desc->stringLength);
            owned.locale = desc->localeName ? desc->localeName : L"";
            owned.textStart = desc->textPosition; owned.bidi = run->bidiLevel; owned.sideways = run->isSideways;
            owned.x = x; owned.y = y; owned.em = run->fontEmSize; owned.mode = mode;
            owned.glyphs.assign(run->glyphIndices, run->glyphIndices + run->glyphCount);
            owned.advances.assign(run->glyphAdvances, run->glyphAdvances + run->glyphCount);
            if (run->glyphOffsets) owned.offsets.assign(run->glyphOffsets, run->glyphOffsets + run->glyphCount);
            else owned.offsets.resize(run->glyphCount); // Optional offsets mean zero displacement.
            owned.clusters.assign(desc->clusterMap, desc->clusterMap + desc->stringLength);
            for (const auto index : owned.clusters) if (index >= run->glyphCount) return E_INVALIDARG;
            runs.push_back(std::move(owned));
            return S_OK;
        }
        catch (...) { return E_OUTOFMEMORY; }
    }

    void Describe(std::ostream& log, IDWriteFactory* factory, const std::wstring& source, const std::vector<Run>& runs)
    {
        log << "Source UTF16: " << Units(source) << "\nSource scalars: " << Units(source, true) << '\n';
        std::vector<IDWriteFontFace*> seen;
        std::vector<unsigned> coverage(source.size());
        for (size_t r = 0; r < runs.size(); ++r)
        {
            const auto& run = runs[r];
            Check(run.textStart <= source.size() && run.text.size() <= source.size() - run.textStart && source.substr(run.textStart, run.text.size()) == run.text, "Retained callback range mismatch");
            for (size_t i = run.textStart; i < run.textStart + run.text.size(); ++i) ++coverage.at(i);
            auto face = std::find(seen.begin(), seen.end(), run.face.Get());
            if (face == seen.end())
            {
                log << "Face " << seen.size() << ":\n";
                seen.push_back(run.face.Get());
                Face(log, factory, run.face.Get());
                face = seen.end() - 1;
            }
            log << "Run " << r << ": text=[" << run.textStart << ',' << run.textStart + run.text.size() << ") face=" << face - seen.begin()
                << " locale=" << Utf8(run.locale) << " bidi=" << run.bidi << " sideways=" << run.sideways << " em=" << run.em
                << " baseline=" << run.x << ',' << run.y << " measuring=" << run.mode << '\n';
            log << "  UTF16=" << Units(run.text) << "\n  clusters=";
            for (const auto c : run.clusters) log << c << ',';
            log << "\n  glyphs=";
            for (size_t g = 0; g < run.glyphs.size(); ++g)
                log << run.glyphs[g] << ':' << run.advances[g] << ':' << run.offsets[g].advanceOffset << ':' << run.offsets[g].ascenderOffset << ' ';
            log << '\n';
            for (UINT32 g = 0; g < run.glyphs.size(); ++g)
            {
                if (run.glyphs[g] != 0) continue;
                UINT16 start = 0;
                for (const auto c : run.clusters) if (c <= g) start = std::max(start, c);
                size_t first = run.text.size(), last = 0;
                for (size_t t = 0; t < run.clusters.size(); ++t) if (run.clusters[t] == start) { first = std::min(first, t); last = t + 1; }
                Check(first < last, "Missing glyph has no source cluster");
                log << "MISSING: run=" << r << " glyph=" << g << " text=[" << run.textStart + first << ',' << run.textStart + last
                    << ") scalars=" << Units(run.text.substr(first, last - first), true) << "(cluster association, not a coverage diagnosis)\n";
            }
        }
        Check(!runs.empty() && std::all_of(coverage.begin(), coverage.end(), [](auto n) { return n == 1; }), "Retained callback coverage invalid");
    }

    // Separate experiment, sharing retained runs and mapping without altering the reference lane.
#include "GeometryProbe.inl"
#include "RepaintProbe.inl"
#include "AdapterProbe.inl"

    void Exercise(std::ostream& log, IDWriteFactory* factory, const std::wstring& bitmapPath, bool injectMappingFailure, bool injectAdapterFailure)
    {
        const auto coverage = ScanCoverage(log, factory);
        const auto privateFonts = LoadPrivateFonts(log, factory);
        UINT32 symbol = 0;
        Check(StandaloneSymbol(L"\U0001f600", symbol) && symbol == 0x1f600 && !StandaloneSymbol(L"e\u0301", symbol) &&
            !StandaloneSymbol(L"\u0633", symbol) && !StandaloneSymbol(L"\U0001f469\u200d\U0001f4bb", symbol) &&
            !StandaloneSymbol(std::wstring(1, static_cast<wchar_t>(0xd83d)), symbol), "Private fallback boundary oracle failed");
        log << "PASS: Private fallback rejects combining, scripts, ZWJ sequences and unpaired surrogates\n";
        Check(std::string(CoverageStatus(0, 0)) == "NONE_IN_COLLECTION" && std::string(CoverageStatus(0, 1)) == "INDETERMINATE" &&
            std::string(CoverageStatus(1, 1)) == "FOUND", "Coverage status oracle failed");
        log << "PASS: Coverage status oracles (absent, indeterminate, found with partial errors)\n";
        const auto compressed = FitBounds(-2, 38, 20);
        const auto unexpanded = FitBounds(0, 8, 20);
        Check(std::abs(compressed.scale - 0.45f) < 0.0001f && std::abs(-2 * compressed.scale + compressed.offset - 1) < 0.0001f &&
            unexpanded.scale == 1 && unexpanded.offset == 6, "Whole-ink fitting oracle failed");
        log << "PASS: Whole-ink fitting oracles (overhang, compression, no expansion)\n";
        Check(SelectFit(-1, 11, 9.89648f, 10).natural && SelectFit(-2, 12, 9.89648f, 10).natural &&
            !SelectFit(-3, 13, 10, 10).natural && !SelectFit(0, 36, 36, 20).natural &&
            SelectFit(0, 0, 0, 10).scale == 1, "Natural-size/overhang policy oracle failed");
        bool invalidFitRejected = false;
        try { SelectFit(0, 10, -1, 10); } catch (const std::runtime_error&) { invalidFitRejected = true; }
        Check(invalidFitRejected, "Invalid natural advance accepted");
        log << "PASS: Natural-size and bounded-overhang oracles (regular, italic, excessive overhang, oversized group, empty, invalid)\n";
        FitStats stats;
        // Deterministic mapping oracles independent of installed font coverage.
        Run synthetic;
        synthetic.text = L"ab"; synthetic.glyphs = {1}; synthetic.clusters = {0,0};
        synthetic.advances = {17}; synthetic.offsets = {{0,0}};
        auto mapped = Map(L"ab", {synthetic}, {{0,1,0,1},{1,2,1,2}});
        Check(mapped.size() == 1 && mapped[0].endCell == 2 && mapped[0].endGlyph == 1, "Ligature mapping oracle failed");
        synthetic.text = L"e\u0301"; synthetic.glyphs = {1,2}; synthetic.clusters = {0,1};
        synthetic.advances = {10,0}; synthetic.offsets = {{0,0},{0,0}};
        mapped = Map(synthetic.text, {synthetic}, {{0,2,0,1}});
        Check(mapped.size() == 1 && mapped[0].endCell == 1 && mapped[0].endGlyph == 2, "Split combining mapping oracle failed");
        synthetic.text = L"ab"; synthetic.bidi = 1; synthetic.clusters = {1,0};
        mapped = Map(synthetic.text, {synthetic}, {{0,1,0,1},{1,2,1,2}});
        Check(mapped.size() == 2 && mapped[0].firstGlyph == 1 && mapped[1].firstGlyph == 0 && mapped[0].firstCell == 0, "Descending cluster mapping oracle failed");
        const auto rtlPlaces = VisualRuns({synthetic}, mapped, 2);
        Check(rtlPlaces.size() == 1 && rtlPlaces[0].visualFirst == 0, "RTL placement oracle failed");
        Run latin = synthetic; latin.text = L"c"; latin.textStart = 2; latin.bidi = 2; latin.x = -20;
        latin.glyphs = {1}; latin.advances = {10}; latin.offsets = {{0,0}}; latin.clusters = {0};
        auto mixedSegments = Map(L"abc", {synthetic, latin}, {{0,1,0,1},{1,2,1,2},{2,3,2,3}});
        const auto mixedPlaces = VisualRuns({synthetic, latin}, mixedSegments, 3);
        Check(mixedPlaces[0].run == 1 && mixedPlaces[1].run == 0 && mixedPlaces[1].visualFirst == 1, "Mixed bidi placement oracle failed");
        log << "PASS: Visual-run ordering and logical/visual cell round-trip oracles\n";
        synthetic.clusters = {2,0};
        bool rejected = false;
        try { Map(synthetic.text, {synthetic}, {{0,1,0,1},{1,2,1,2}}); } catch (const std::runtime_error&) { rejected = true; }
        Check(rejected, "Invalid mapping oracle was accepted");
        const auto wideCells = CoreCells(L"A\u4e2dBe\u0301C");
        Check(wideCells.size() == 5 && wideCells[1].cellStart == 1 && wideCells[1].cellEnd == 3 &&
            wideCells[3].textStart == 3 && wideCells[3].textEnd == 5 && wideCells[3].cellEnd - wideCells[3].cellStart == 1,
            "Core cell geometry oracle failed");
        log << "PASS: Mapping oracles (ligature, split combining, descending clusters, invalid index, real core cells)\n";
        const Fixture fixtures[]{
            {"Latin-combining", L"A e\u0301 cafe\u00e9 ffi", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL},
            {"CJK-wide", L"A\u4e2d\u6587B", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL},
            {"Supplementary", L"A\U0001F600B", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL},
            {"Arabic", L"\u0633\u0644\u0627\u0645", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL},
            {"Indic", L"\u0915\u094d\u0937", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL},
            {"Emoji-sequence", L"A\U0001F469\u200d\U0001F4BBB", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL},
            {"Bold", L"Bold e\u0301 \u4e2d", L"Consolas", DWRITE_FONT_WEIGHT_BOLD, DWRITE_FONT_STYLE_NORMAL},
            {"Italic", L"Italic ffi e\u0301", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_ITALIC},
            {"Missing-family", L"Fallback e\u0301 \u4e2d", L"VT7 intentionally absent font 75D99", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL},
            {"Arabic-mixed", L"A \u0633\u0644\u0627\u0645 123 B", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL},
            {"Arabic-marks", L"\u0633\u064e\u0644\u0627\u0645", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL},
            {"Private-BMP (forced C)", L"\u262f", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL},
            {"Private-SMP (forced C)", L"\U0001f600", L"Consolas", DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL}
        };
        ComPtr<IDWriteGdiInterop> interop; Hr(factory->GetGdiInterop(&interop));
        ComPtr<IDWriteBitmapRenderTarget> target; Hr(interop->CreateBitmapRenderTarget(nullptr, 1100, 1400, &target));
        Hr(target->SetPixelsPerDip(1));
        ComPtr<IDWriteRenderingParams> params; Hr(factory->CreateCustomRenderingParams(2.2f, 1, 1, DWRITE_PIXEL_GEOMETRY_RGB, DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC, &params));
        const auto dc = target->GetMemoryDC();
        RECT bounds{0, 0, 1100, 1400};
        const auto brush = CreateSolidBrush(RGB(14,22,32));
        Check(brush != nullptr, "Diagnostic brush creation failed");
        FillRect(dc, &bounds, brush); DeleteObject(brush);
        SetBkMode(dc, TRANSPARENT); SetTextColor(dc, RGB(120,190,240));
        const wchar_t* heading = L"VT7 2C: N = natural; C = fitted visual runs in core-cell allocation. Not terminal bidi acceptance.";
        TextOutW(dc, 12, 8, heading, static_cast<int>(wcslen(heading)));
        unsigned fixtureIndex = 0, mappedCount = 0;
        for (const auto& fixture : fixtures)
        {
            const std::wstring text = fixture.text;
            const auto beforeFit = stats;
            log << "\nFixture: " << fixture.name << "\n";
            const auto cells = CoreCells(text);
            for (const auto& cell : cells) log << "CELL: text=[" << cell.textStart << ',' << cell.textEnd << ") cells=[" << cell.cellStart << ',' << cell.cellEnd << ")\n";
            ComPtr<IDWriteTextFormat> format;
            Hr(factory->CreateTextFormat(fixture.family, nullptr, fixture.weight, fixture.style, DWRITE_FONT_STRETCH_NORMAL, 18, L"en-US", &format));
            Hr(format->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP));
            ComPtr<IDWriteTextLayout> layout;
            Hr(factory->CreateTextLayout(text.data(), static_cast<UINT32>(text.size()), format.Get(), 2000, 100, &layout));
            ComPtr<Collector> collector; collector.Attach(new Collector());
            LARGE_INTEGER frequency{}, start{}, finish{};
            Check(QueryPerformanceFrequency(&frequency) && QueryPerformanceCounter(&start), "Performance counter unavailable");
            Hr(layout->Draw(nullptr, collector.Get(), 0, 0));
            Check(QueryPerformanceCounter(&finish) != FALSE, "Performance counter unavailable");
            log << "Layout Draw/copy microseconds: " << (finish.QuadPart - start.QuadPart) * 1000000.0 / frequency.QuadPart << " (single cold sample, not a benchmark)\n";
            auto runs = std::move(collector->runs);
            collector.Reset(); layout.Reset(); format.Reset();
            // Every subsequent read and draw uses copied callback arrays and retained faces.
            Describe(log, factory, text, runs);
            if (fixtureIndex == 0)
            {
                auto missing = runs.front();
                missing.text = L"A"; missing.textStart = 0; missing.glyphs = {0}; missing.clusters = {0};
                missing.advances = {10}; missing.offsets = {{0,0}};
                std::ostringstream diagnostic;
                Describe(diagnostic, factory, L"A", {missing});
                Check(diagnostic.str().find("MISSING: run=0 glyph=0 text=[0,1) scalars=U+0041") != std::string::npos, "Missing-glyph source diagnostic oracle failed");
                log << "PASS: Synthetic missing-glyph source association (not a coverage observation)\n";
            }
            const auto y = static_cast<FLOAT>(70 + fixtureIndex * 90);
            std::wstring label(fixture.name, fixture.name + strlen(fixture.name));
            TextOutW(dc, 12, static_cast<int>(y - 30), label.data(), static_cast<int>(label.size()));
            TextOutW(dc, 220, static_cast<int>(y - 18), L"N", 1);
            TextOutW(dc, 220, static_cast<int>(y + 12), L"C", 1);
            const auto pen = CreatePen(PS_SOLID, 1, RGB(40,60,75));
            Check(pen != nullptr, "Grid pen creation failed");
            const auto previousPen = SelectObject(dc, pen);
            for (UINT32 c = 0; c <= cells.back().cellEnd; ++c)
            {
                MoveToEx(dc, 250 + static_cast<int>(c * 10), static_cast<int>(y + 10), nullptr);
                LineTo(dc, 250 + static_cast<int>(c * 10), static_cast<int>(y + 35));
            }
            SelectObject(dc, previousPen); DeleteObject(pen);
            for (const auto& run : runs)
            {
                const DWRITE_GLYPH_RUN glyphs{run.face.Get(), run.em, static_cast<UINT32>(run.glyphs.size()), run.glyphs.data(), run.advances.data(), run.offsets.data(), run.sideways, run.bidi};
                Hr(target->DrawGlyphRun(250 + run.x, y + run.y - runs.front().y, run.mode, &glyphs, params.Get(), RGB(235,235,235)));
            }
            std::vector<Segment> segments;
            const auto privateApplied = ApplyPrivateFallback(log, runs, cells, privateFonts, fixtureIndex >= 11);
            if (fixtureIndex >= 11) Check(privateApplied == 1, "Forced private fallback fixture failed");
            try
            {
                if (injectMappingFailure && fixtureIndex == 0) runs.front().clusters.front() = 65535;
                segments = Map(text, runs, cells);
            }
            catch (const std::exception& error)
            {
                log << "MAPPING_UNRESOLVED: " << error.what() << '\n';
                throw;
            }
            if (!segments.empty())
            {
                const auto placements = VisualRuns(runs, segments, cells.back().cellEnd);
                for (const auto& place : placements)
                {
                    const auto& run = runs[place.run];
                    const auto baseline = y + 30 + run.y - runs.front().y;
                    log << "VISUAL_RUN: run=" << place.run << " bidi=" << run.bidi << " logicalCells=[" << place.logicalFirst << ',' << place.logicalEnd
                        << ") visualCells=[" << place.visualFirst << ',' << place.visualFirst + place.logicalEnd - place.logicalFirst << ")\n";
                    if (run.bidi & 1)
                    {
                        // Keep contextual forms and all pen/mark relationships together.
                        DrawFitted(log, factory, target.Get(), params.Get(), run, 0, static_cast<UINT32>(run.glyphs.size()),
                            250.f + place.visualFirst * 10.f, baseline, (place.logicalEnd - place.logicalFirst) * 10.f, stats);
                        log << "RTL_GROUP: original shaped run preserved; cell projection is not glyph hit testing\n";
                    }
                    for (const auto& span : segments) if (span.run == place.run)
                    {
                        const auto visual = place.visualFirst + ((run.bidi & 1) ? place.logicalEnd - span.endCell : span.firstCell - place.logicalFirst);
                        if (!(run.bidi & 1))
                        {
                            const auto ink = DrawFitted(log, factory, target.Get(), params.Get(), run, span.firstGlyph, span.endGlyph,
                                250.f + visual * 10.f, baseline, (span.endCell - span.firstCell) * 10.f, stats);
                            if (std::any_of(privateFonts.begin(), privateFonts.end(), [&](const auto& font) { return font.face.Get() == run.face.Get(); }))
                                Check(ink, "Private fallback glyph has no raster ink");
                        }
                        log << "MAP: text=[" << span.textStart << ',' << span.textEnd << ") cells=[" << span.firstCell << ',' << span.endCell
                            << ") visualCells=[" << visual << ',' << visual + span.endCell - span.firstCell << ") glyphs=[" << span.firstGlyph << ',' << span.endGlyph << ")\n";
                    }
                }
                ++mappedCount;
                log << "MAPPING: complete structural coverage; visual acceptance pending\n";
            }
            log << "FIT_FIXTURE: " << fixture.name << " natural=" << stats.natural - beforeFit.natural
                << " compressed=" << stats.compressed - beforeFit.compressed << '\n';
            if (fixtureIndex == 0 || fixtureIndex == 7)
                Check(stats.natural > beforeFit.natural && stats.compressed == beforeFit.compressed, "Consolas natural-size regression");
            ++fixtureIndex;
        }
        Check(mappedCount == 13, "Mapping fixtures incomplete");
        if (coverage.face)
        {
            Run explicitRun; explicitRun.face = coverage.face; explicitRun.em = 18;
            explicitRun.glyphs = {coverage.glyph}; explicitRun.advances = {18}; explicitRun.offsets = {{0,0}};
            const wchar_t* label = L"Explicit U+1F600: first coverage candidate, no automatic fallback (diagnostic only)";
            TextOutW(dc, 12, 1300, label, static_cast<int>(wcslen(label)));
            Check(DrawFitted(log, factory, target.Get(), params.Get(), explicitRun, 0, 1, 250, 1340, 20, stats), "Explicit coverage glyph has no raster ink");
            log << "EXPLICIT_COVERAGE: drawn nonzero cmap glyph from first candidate without TextLayout fallback\n";
        }
        else
        {
            const wchar_t* label = L"Explicit U+1F600: no confirmed candidate. See coverage result/errors in log.";
            TextOutW(dc, 12, 1300, label, static_cast<int>(wcslen(label)));
            log << "EXPLICIT_COVERAGE: skipped, no confirmed candidate\n";
        }
        SaveBitmap(target.Get(), bitmapPath);
        log << "FIT_SUMMARY: natural=" << stats.natural << " compressed=" << stats.compressed << "; natural ink halo=2 px; compressed halo=0 px; fixed 96 DPI\n";
        log << "Font bitmap: " << Utf8(bitmapPath) << "\nFont fixtures: " << fixtureIndex << "; mapped=" << mappedCount
            << "; unresolved=" << fixtureIndex - mappedCount << '\n';
        log << "PASS: Retained runs survive layout destruction and basic core-cell mapping\n";
        ExerciseGeometry(log, factory, bitmapPath, privateFonts, std::vector<Fixture>(std::begin(fixtures), std::end(fixtures)));
        ExerciseRepaint(log, factory, bitmapPath, privateFonts);
        ExerciseAdapter(log, factory, bitmapPath, privateFonts, injectAdapterFailure);
    }
}
