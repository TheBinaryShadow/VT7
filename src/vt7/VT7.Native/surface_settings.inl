// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
// UI-thread settings boundary, with rendering parked before font/metric mutation.
void SetFont(uint32_t family, uint32_t points, uint32_t weight, uint32_t diagnosticDpi)
{
    THROW_HR_IF(E_NOTIMPL, !atlas);
    THROW_HR_IF(E_INVALIDARG, family < 1 || family > 2 || points < 6 || points > 32 ||
        (weight != FW_NORMAL && weight != FW_BOLD) ||
        (diagnosticDpi && (!capture || (diagnosticDpi != 96 && diagnosticDpi != 120 && diagnosticDpi != 144))));
    THROW_IF_FAILED(lastError.load());
    const auto dc = GetDC(window);
    THROW_LAST_ERROR_IF(!dc);
    const auto measuredDpi = static_cast<uint32_t>(GetDeviceCaps(dc, LOGPIXELSY));
    ReleaseDC(window, dc);
    const auto dpi = diagnosticDpi ? diagnosticDpi : measuredDpi;
    if (family == fontFamily && points == fontPoints && weight == fontWeight &&
        dpi == effectiveDpi && diagnosticDpi == dpiOverride) return;

    const auto name = family == 1 ? L"Consolas" : L"Courier New";
    // Do not silently accept an unavailable requested primary family.
    wil::com_ptr<IDWriteFactory> factory;
    THROW_IF_FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory),
        reinterpret_cast<IUnknown**>(factory.put())));
    wil::com_ptr<IDWriteFontCollection> collection;
    THROW_IF_FAILED(factory->GetSystemFontCollection(collection.put(), FALSE));
    UINT32 index = 0; BOOL exists = FALSE;
    THROW_IF_FAILED(collection->FindFamilyName(name, &index, &exists));
    THROW_HR_IF(HRESULT_FROM_WIN32(ERROR_NOT_FOUND), !exists);

    Stop(); // Join outside the core lock; Capture also reads cellHeight.
    try
    {
        {
            const auto guard = terminal.LockForWriting();
            FontInfoDesired desired(name, 0, static_cast<WORD>(weight), static_cast<float>(points), CP_UTF8);
            desired.SetEnableColorGlyphs(false);
            auto info = terminal.GetFontInfo();
            THROW_IF_FAILED(atlas->UpdateDpi(dpi));
            THROW_IF_FAILED(atlas->UpdateFont(desired, info));
            THROW_HR_IF(E_UNEXPECTED, info.GetFaceName() != name);
            til::size cells;
            THROW_IF_FAILED(atlas->GetFontSize(&cells));
            THROW_HR_IF(E_UNEXPECTED, cells.width <= 0 || cells.height <= 0);
            terminal.SetFontInfo(info);
            cellWidth = cells.width; cellHeight = cells.height;
        }
        Resize(); // UserResize reflows existing core content. Never reset the sample.
        systemDpi = measuredDpi; effectiveDpi = dpi; dpiOverride = diagnosticDpi;
        fontFamily = family; fontPoints = points; fontWeight = weight;
        ++settingsGeneration;
        RequestPaint();
        Start(); // Hidden surfaces remain parked until shown.
    }
    catch (...)
    {
        // Unexpected allocation/font/reflow failure can leave intermediate state.
        // Fail closed rather than paint with mismatched core and renderer metrics.
        lastError.store(wil::ResultFromCaughtException());
        PostMessageW(window, WM_APP + 1, 0, 0);
        throw;
    }
}
