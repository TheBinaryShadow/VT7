// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#include <windows.h>
#include <d3d11_2.h>
#include <dxgi1_3.h>
#include <d2d1_1.h>
#include <dwrite_2.h>
#include <wrl/client.h>
#include <wil/resource.h>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>
#include <stdexcept>
#include <cstring>
#include <algorithm>
#include "FontAnalysis.hpp"

using Microsoft::WRL::ComPtr;

namespace
{
    constexpr wchar_t sample[] = L"Latin: cafe\u00e9 e\u0301 ffi | Greek: \u03b1\u03b2\u03b3 | CJK: \u4e2d\u6587 | Supplementary: \U0001F600";

    struct Report
    {
        std::ostringstream text;
        unsigned failures = 0;
        unsigned checks = 0;

        void Result(const std::string& label, HRESULT hr, bool required = true)
        {
            if (required) { ++checks; if (FAILED(hr)) ++failures; }
            text << (required ? (SUCCEEDED(hr) ? "PASS: " : "FAIL: ") : "CAPABILITY: ")
                 << label << " = 0x" << std::hex << std::setw(8) << std::setfill('0')
                 << static_cast<unsigned long>(hr) << std::dec << '\n';
        }
        void Require(const std::string& label, HRESULT hr)
        {
            Result(label, hr);
            if (FAILED(hr)) throw std::runtime_error(label);
        }
        template<typename T, typename U> void Query(const std::string& label, U* source, bool required = false)
        {
            ComPtr<T> result;
            Result(label, source->QueryInterface(IID_PPV_ARGS(&result)), required);
        }
    };

    class GlyphCollector final : public IDWriteTextRenderer
    {
        LONG references = 1;
    public:
        unsigned runs = 0;
        unsigned glyphs = 0;
        unsigned missingGlyphs = 0;
        unsigned textUnits = 0;
        std::vector<ComPtr<IDWriteFontFace>> faces;

        HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** object) noexcept override
        {
            if (!object) return E_POINTER;
            *object = nullptr;
            if (iid == __uuidof(IUnknown) || iid == __uuidof(IDWriteTextRenderer) || iid == __uuidof(IDWritePixelSnapping))
            {
                *object = static_cast<IDWriteTextRenderer*>(this);
                AddRef();
                return S_OK;
            }
            return E_NOINTERFACE;
        }
        ULONG STDMETHODCALLTYPE AddRef() noexcept override { return InterlockedIncrement(&references); }
        ULONG STDMETHODCALLTYPE Release() noexcept override
        {
            const auto remaining = InterlockedDecrement(&references);
            if (!remaining) delete this;
            return remaining;
        }
        HRESULT STDMETHODCALLTYPE IsPixelSnappingDisabled(void*, BOOL* disabled) noexcept override
        { if (!disabled) return E_POINTER; *disabled = FALSE; return S_OK; }
        HRESULT STDMETHODCALLTYPE GetCurrentTransform(void*, DWRITE_MATRIX* transform) noexcept override
        { if (!transform) return E_POINTER; *transform = {1, 0, 0, 1, 0, 0}; return S_OK; }
        HRESULT STDMETHODCALLTYPE GetPixelsPerDip(void*, FLOAT* pixels) noexcept override
        { if (!pixels) return E_POINTER; *pixels = 1; return S_OK; }
        HRESULT STDMETHODCALLTYPE DrawGlyphRun(void*, FLOAT, FLOAT, DWRITE_MEASURING_MODE,
            const DWRITE_GLYPH_RUN* run, const DWRITE_GLYPH_RUN_DESCRIPTION* description, IUnknown*) noexcept override
        {
            try
            {
                if (!run || !run->fontFace || !description || !description->clusterMap) return E_INVALIDARG;
                ++runs;
                glyphs += run->glyphCount;
                textUnits += description->stringLength;
                for (UINT32 i = 0; i < run->glyphCount; ++i) missingGlyphs += run->glyphIndices[i] == 0;
                for (UINT32 i = 0; i < description->stringLength; ++i)
                    if (description->clusterMap[i] >= run->glyphCount) return E_INVALIDARG;
                if (std::none_of(faces.begin(), faces.end(), [&](const auto& face) { return face.Get() == run->fontFace; }))
                    faces.emplace_back(run->fontFace);
                return S_OK;
            }
            catch (...) { return E_OUTOFMEMORY; }
        }
        HRESULT STDMETHODCALLTYPE DrawUnderline(void*, FLOAT, FLOAT, const DWRITE_UNDERLINE*, IUnknown*) noexcept override { return S_OK; }
        HRESULT STDMETHODCALLTYPE DrawStrikethrough(void*, FLOAT, FLOAT, const DWRITE_STRIKETHROUGH*, IUnknown*) noexcept override { return S_OK; }
        HRESULT STDMETHODCALLTYPE DrawInlineObject(void*, FLOAT, FLOAT, IDWriteInlineObject*, BOOL, BOOL, IUnknown*) noexcept override { return E_NOTIMPL; }
    };

    ComPtr<IDWriteTextLayout> ProbeFonts(Report& report, IDWriteFactory* factory)
    {
        report.Query<IDWriteFactory1>("DirectWrite Factory1 (baseline)", factory, true);
        report.Query<IDWriteFactory2>("DirectWrite Factory2 (unported Atlas requirement; absence expected on Windows 7)", factory);
        ComPtr<IDWriteTextAnalyzer> analyzer;
        report.Require("Create text analyzer", factory->CreateTextAnalyzer(&analyzer));
        report.Query<IDWriteTextAnalyzer1>("TextAnalyzer1 (baseline)", analyzer.Get(), true);
        ComPtr<IDWriteTextFormat> format;
        report.Require("Create Consolas text format", factory->CreateTextFormat(L"Consolas", nullptr,
            DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, 16, L"en-US", &format));
        ComPtr<IDWriteTextLayout> layout;
        report.Require("Create mixed-script layout", factory->CreateTextLayout(sample, _countof(sample) - 1, format.Get(), 320, 128, &layout));
        ComPtr<GlyphCollector> collector;
        collector.Attach(new GlyphCollector());
        report.Require("Collect glyph runs and validate cluster indices", layout->Draw(nullptr, collector.Get(), 0, 0));
        report.Result("Glyph callbacks cover sample UTF-16 text", collector->textUnits == _countof(sample) - 1 && collector->glyphs > 0 ? S_OK : E_FAIL);
        report.text << "Font observation: runs=" << collector->runs << ", faces=" << collector->faces.size()
                    << ", glyphs=" << collector->glyphs << ", missingGlyphs=" << collector->missingGlyphs << '\n';
        report.text << "Font observation is not Atlas shaping or terminal-cell acceptance. Missing glyphs depend on installed fonts.\n";
        ComPtr<VT7::FontProbe::Collector> retained;
        retained.Attach(new VT7::FontProbe::Collector());
        report.Require("Retain original sample glyph diagnostics", layout->Draw(nullptr, retained.Get(), 0, 0));
        report.text << "\nOriginal 0.1 sample diagnostics (same text, font, wrapping, and dimensions):\n";
        VT7::FontProbe::Describe(report.text, factory, sample, retained->runs);
        for (size_t i = 0; i < collector->faces.size(); ++i)
        {
            report.Query<IDWriteFontFace1>("Font face " + std::to_string(i) + " / Face1", collector->faces[i].Get(), true);
            report.Query<IDWriteFontFace2>("Font face " + std::to_string(i) + " / Face2 (optional)", collector->faces[i].Get());
        }
        return layout;
    }

    void ProbeDevice(Report& report, D3D_DRIVER_TYPE driver, IDWriteTextLayout* layout)
    {
        const std::string name = driver == D3D_DRIVER_TYPE_WARP ? "WARP" : "Hardware";
        report.text << "\nDevice: " << name << '\n';
        ComPtr<ID3D11Device> device;
        ComPtr<ID3D11DeviceContext> context;
        D3D_FEATURE_LEVEL level{};
        const D3D_FEATURE_LEVEL levels[]{D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0};
        report.Require(name + " D3D11CreateDevice", D3D11CreateDevice(nullptr, driver, nullptr,
            D3D11_CREATE_DEVICE_BGRA_SUPPORT, levels, _countof(levels), D3D11_SDK_VERSION, &device, &level, &context));
        report.text << "Feature level: 0x" << std::hex << level << std::dec << '\n';
        report.Query<ID3D11Device1>(name + " Device1", device.Get());
        report.Query<ID3D11Device2>(name + " Device2 (optional)", device.Get());
        report.Query<ID3D11DeviceContext1>(name + " Context1", context.Get());
        report.Query<ID3D11DeviceContext2>(name + " Context2 (optional)", context.Get());

        ComPtr<IDXGIDevice> dxgiDevice;
        report.Require(name + " DXGI device", device.As(&dxgiDevice));
        ComPtr<IDXGIAdapter> adapter;
        report.Require(name + " adapter", dxgiDevice->GetAdapter(&adapter));
        DXGI_ADAPTER_DESC adapterDescription{};
        report.Require(name + " adapter description", adapter->GetDesc(&adapterDescription));
        report.text << "Adapter vendor/device: " << adapterDescription.VendorId << '/' << adapterDescription.DeviceId << '\n';
        ComPtr<IDXGIFactory2> factory;
        report.Require(name + " adapter parent Factory2", adapter->GetParent(IID_PPV_ARGS(&factory)));

        const auto window = CreateWindowExW(0, L"STATIC", L"VT7 renderer capability probe", WS_POPUP, 0, 0, 320, 128, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
        report.Require(name + " hidden probe HWND", window ? S_OK : HRESULT_FROM_WIN32(GetLastError()));
        const auto destroy = wil::scope_exit([&] { DestroyWindow(window); });
        DXGI_SWAP_CHAIN_DESC1 desc{};
        desc.Width = 320; desc.Height = 128;
        desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        desc.BufferCount = 1;
        desc.Scaling = DXGI_SCALING_STRETCH;
        desc.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
        desc.AlphaMode = DXGI_ALPHA_MODE_UNSPECIFIED;
        ComPtr<IDXGISwapChain1> swapChain;
        report.Require(name + " HWND discard/stretch swap chain", factory->CreateSwapChainForHwnd(device.Get(), window, &desc, nullptr, nullptr, &swapChain));
        report.Query<IDXGISwapChain2>(name + " SwapChain2 (optional)", swapChain.Get());

        {
            ComPtr<ID3D11Texture2D> buffer;
            report.Require(name + " back buffer", swapChain->GetBuffer(0, IID_PPV_ARGS(&buffer)));
            ComPtr<IDXGISurface> surface;
            report.Require(name + " DXGI surface", buffer.As(&surface));
            ComPtr<ID2D1Factory> d2d;
            report.Require(name + " D2D factory", D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, d2d.GetAddressOf()));
            const auto properties = D2D1::RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_DEFAULT,
                D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_IGNORE));
            ComPtr<ID2D1RenderTarget> target;
            report.Require(name + " D2D DXGI render target", d2d->CreateDxgiSurfaceRenderTarget(surface.Get(), &properties, &target));
            report.Query<ID2D1DeviceContext>(name + " D2D DeviceContext (checked, not cast)", target.Get(), true);
            ComPtr<ID2D1SolidColorBrush> brush;
            report.Require(name + " text brush", target->CreateSolidColorBrush(D2D1::ColorF(D2D1::ColorF::White), &brush));
            target->BeginDraw();
            target->Clear(D2D1::ColorF(D2D1::ColorF::Black));
            target->DrawTextLayout(D2D1::Point2F(0, 0), layout, brush.Get());
            report.Require(name + " offscreen glyph rasterization", target->EndDraw());
            D3D11_TEXTURE2D_DESC textureDesc{};
            buffer->GetDesc(&textureDesc);
            textureDesc.Usage = D3D11_USAGE_STAGING;
            textureDesc.BindFlags = 0; textureDesc.MiscFlags = 0;
            textureDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
            ComPtr<ID3D11Texture2D> staging;
            report.Require(name + " readback texture", device->CreateTexture2D(&textureDesc, nullptr, &staging));
            context->CopyResource(staging.Get(), buffer.Get());
            D3D11_MAPPED_SUBRESOURCE mapped{};
            report.Require(name + " map glyph pixels", context->Map(staging.Get(), 0, D3D11_MAP_READ, 0, &mapped));
            const auto unmap = wil::scope_exit([&] { context->Unmap(staging.Get(), 0); });
            unsigned litPixels = 0;
            for (UINT y = 0; y < textureDesc.Height; ++y)
            {
                const auto pixels = reinterpret_cast<const BYTE*>(mapped.pData) + y * mapped.RowPitch;
                for (UINT x = 0; x < textureDesc.Width; ++x)
                    litPixels += pixels[x * 4] != 0 || pixels[x * 4 + 1] != 0 || pixels[x * 4 + 2] != 0;
            }
            report.Result(name + " nonempty glyph pixel readback", litPixels > 0 && litPixels < textureDesc.Width * textureDesc.Height ? S_OK : E_FAIL);
            report.text << "Readback lit pixels: " << litPixels << '\n';
        }
        report.Result(name + " hidden Present (observation, not visible presentation acceptance)", swapChain->Present(0, 0), false);
        context->ClearState(); context->Flush();
        report.Require(name + " resize buffers", swapChain->ResizeBuffers(1, 256, 96, DXGI_FORMAT_UNKNOWN, 0));
        swapChain.Reset();
        context->ClearState(); context->Flush();
    }
}

int wmain(int argc, wchar_t** argv)
{
    if ((argc != 3 && argc != 4) || wcscmp(argv[1], L"--output") != 0 || !argv[2][0] ||
        (argc == 4 && wcscmp(argv[3], L"--inject-required-failure") != 0 && wcscmp(argv[3], L"--inject-font-failure") != 0 && wcscmp(argv[3], L"--inject-adapter-failure") != 0 && wcscmp(argv[3], L"--inject-fit-failure") != 0))
    {
        fputs("Usage: VT7.RendererProbe.exe --output <log path> [--inject-required-failure|--inject-font-failure|--inject-adapter-failure|--inject-fit-failure]\n", stderr);
        return 64;
    }
    Report report;
    report.text << "VT7 renderer capability and font probe 0.9\nNot Atlas rendering. GDI proof is unchanged.\n"
                << "Build: " << __DATE__ << ' ' << __TIME__ << "; compiler=" << _MSC_FULL_VER
#ifdef NDEBUG
                << "; Release x64\n";
#else
                << "; Debug x64\n";
#endif
    SYSTEMTIME now{}; GetSystemTime(&now);
    report.text << "Captured UTC: " << now.wYear << '-' << now.wMonth << '-' << now.wDay << ' ' << now.wHour << ':' << now.wMinute << ':' << now.wSecond << '\n';
    // Resolve the accurate OS report without requiring any newer kernel exports.
    using RtlGetVersionFn = LONG (WINAPI*)(OSVERSIONINFOW*);
    const auto rtlGetVersion = reinterpret_cast<RtlGetVersionFn>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"));
    OSVERSIONINFOW version{}; version.dwOSVersionInfoSize = sizeof(version);
    if (rtlGetVersion && rtlGetVersion(&version) == 0)
        report.text << "Windows NT: " << version.dwMajorVersion << '.' << version.dwMinorVersion << '.' << version.dwBuildNumber << '\n';
    const auto com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    report.Result("COM initialization", com);
    if (SUCCEEDED(com))
    {
        const auto uninitialize = wil::scope_exit([] { CoUninitialize(); });
        try
        {
            ComPtr<IDXGIFactory1> factory;
            report.Require("CreateDXGIFactory1", CreateDXGIFactory1(IID_PPV_ARGS(&factory)));
            report.Query<IDXGIFactory2>("DXGI Factory2 (baseline)", factory.Get(), true);
            ComPtr<IDWriteFactory> dwrite;
            report.Require("DWriteCreateFactory baseline", DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown**>(dwrite.GetAddressOf())));
            const auto layout = ProbeFonts(report, dwrite.Get());
            for (const auto driver : {D3D_DRIVER_TYPE_HARDWARE, D3D_DRIVER_TYPE_WARP})
            {
                try { ProbeDevice(report, driver, layout.Get()); }
                catch (const std::exception& ex)
                {
                    report.Result("Device section aborted", E_FAIL);
                    report.text << "Device section stopped: " << ex.what() << '\n';
                }
            }
            VT7::FontProbe::Exercise(report.text, dwrite.Get(), std::wstring(argv[2]) + L".bmp",
                argc == 4 && wcscmp(argv[3], L"--inject-font-failure") == 0,
                argc == 4 && wcscmp(argv[3], L"--inject-adapter-failure") == 0,
                argc == 4 && wcscmp(argv[3], L"--inject-fit-failure") == 0);
            report.Result("Font diagnostic and basic cell-mapping experiment", S_OK);
        }
        catch (const std::exception& ex)
        {
            report.Result("Probe aborted", E_FAIL);
            report.text << "Probe stopped: " << ex.what() << '\n';
        }
    }
    if (argc == 4 && wcscmp(argv[3], L"--inject-required-failure") == 0) report.Result("Injected baseline failure (test harness only)", E_FAIL);
    report.text << "\nRequired checks: " << report.checks << "\nFailed checks: " << report.failures
                << "\nBaseline passed: " << (report.failures == 0 ? "True" : "False") << '\n';
    std::ofstream output(argv[2], std::ios::binary | std::ios::trunc);
    output << report.text.str();
    output.close();
    if (!output) { fputs("Could not write the probe report.\n", stderr); return 2; }
    return report.failures == 0 ? 0 : 1;
}
