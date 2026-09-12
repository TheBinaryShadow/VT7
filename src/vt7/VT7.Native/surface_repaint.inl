// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
// Diagnostic-only members of Surface. UI-thread commands, core-before-raster lock order.
uint32_t repaintStep = 0, repaintPhase = 0;
std::vector<uint32_t> incrementalPixels, previousPixels;
uint32_t incrementalWidth = 0, incrementalHeight = 0;
std::wstring incrementalState;
std::wstring settingsSource;

std::wstring SettingsSourceSnapshot()
{
    // The settings fixture has no spaces. Ignore padding, not authored whitespace.
    const auto view = terminal.GetViewport();
    std::wstring result;
    for (int y = view.Top(); y <= view.BottomInclusive(); ++y)
    {
        const auto& row = terminal.GetTextBuffer().GetRowByOffset(y);
        for (int x = 0; x < view.Width(); ++x)
        {
            if (row.DbcsAttrAt(x) == DbcsAttribute::Trailing) continue;
            const auto glyph = row.GlyphAt(x);
            if (glyph == L" ") continue;
            const auto colors = terminal.GetAttributeColors(row.GetAttrByColumn(x));
            result += fmt::format(L"{}:{}:{},{};", glyph.size(), glyph, colors.first, colors.second);
        }
    }
    return result;
}

std::wstring CoreSnapshot()
{
    const auto viewport = terminal.GetViewport();
    const auto& cursor = terminal.GetTextBuffer().GetCursor();
    const auto position = cursor.GetPosition();
    std::wstring result = fmt::format(L"{},{},{},{},{},{};", viewport.Width(), viewport.Height(),
        viewport.Top(), position.x, position.y, cursor.IsVisible());
    for (int y = viewport.Top(); y <= viewport.BottomInclusive(); ++y)
    {
        const auto& row = terminal.GetTextBuffer().GetRowByOffset(y);
        for (int x = 0; x < viewport.Width(); ++x)
        {
            const auto glyph = row.GlyphAt(x);
            const auto colors = terminal.GetAttributeColors(row.GetAttrByColumn(x));
            result += fmt::format(L"{}:{}:{},{};", glyph.size(), glyph, colors.first, colors.second);
        }
    }
    return result;
}

std::wstring RepaintCheck(uint32_t operation, uint32_t step)
{
    THROW_HR_IF(E_INVALIDARG, !atlas || !capture || injectBlank || step >= 16 || operation > 9);
    const auto guard = terminal.LockForWriting();
    const auto viewport = terminal.GetViewport();
    if (operation == 9)
    {
        terminal.Write(L"\x1b[?1049l");
        terminal.HardResetWithoutErase();
        terminal.Write(L"\x1b[0m\x1b[2J\x1b[H\x1b[?25l\x1b[2;1HVT7 lower-row text");
        requested = atlas->RequestFrame();
        renderer.NotifyPaintFrame();
        return L"";
    }
    if (operation == 6)
    {
        terminal.Write(L"\x1b[?1049l");
        terminal.HardResetWithoutErase();
        terminal.Write(L"\x1b[0m\x1b[2J\x1b[H\x1b[?25lVT7-settings\r\n");
        terminal.Write(std::wstring(120, L'A'));
        terminal.Write(L"\r\nCafe\u0301-\u4e2d\u6587\r\n\u262f\U0001f600\r\n"
            L"\x1b[1;3;4;38;2;230;70;90mStyled\x1b[0m\r\nEND");
        settingsSource = SettingsSourceSnapshot();
        requested = atlas->RequestFrame();
        renderer.NotifyPaintFrame();
        return L"";
    }
    if (operation == 7)
    {
        THROW_HR_IF(E_UNEXPECTED, settingsSource.empty() || SettingsSourceSnapshot() != settingsSource);
        return L"PASS: settings fixture nonblank source and effective colors preserved";
    }
    if (operation == 8)
    {
        repaintStep = 0; repaintPhase = 1; previousPixels.clear();
        operation = 1; // Retain a settings frame for the existing exact full-redraw comparison.
    }
    THROW_HR_IF(E_INVALIDARG, viewport.Width() < 40 || viewport.Height() < 10);
    if (operation == 0)
    {
        THROW_HR_IF(E_UNEXPECTED, repaintPhase != 0 || (step != 0 && step != repaintStep + 1));
        if (step == 0)
        {
            previousPixels.clear();
            terminal.Write(L"\x1b[?1049l");
            terminal.HardResetWithoutErase();
            terminal.Write(L"\x1b[0m\x1b[2J\x1b[H\x1b[?25lVT7 integrated repaint\x1b[3;1H"
                L"ASCII: aaaaaaaaaaaa\r\nStyle: bbbbbbbbbbbb\r\nWide: cccccccccccc\r\n"
                L"Fallback: \u262f \U0001f600\r\nNeighbor: keep these pixels\r\nScroll: last row");
        }
        else
        {
            static constexpr const wchar_t* edits[]{L"",
                L"\x1b[3;8HZ", // ASCII edit
                L"\x1b[4;8H\x1b[1;3;4;38;2;230;70;90;48;5;24mStyle\x1b[0m",
                L"\x1b[4;8He\u0301", // combining overwrite
                L"\x1b[5;8H\u4e2d", // wide cluster
                L"\x1b[5;8Hx ", // remove both halves
                L"\x1b[3;7H\x1b[3@INS", // insertion
                L"\x1b[4;5H\x1b[6X", // erase characters
                L"\x1b[5;5H\x1b[K", // erase to end of row
                L"\x1b[3;8r\x1b[8;1H\r\nscrolled\x1b[r", // bounded region scroll
                L"\x1b[?1049h\x1b[?25l\x1b[HVT7 alternate\x1b[3;1HA\u4e2de\u0301B",
                L"\x1b[?1049l", // restore main
                L"\x1b[9;12H\x1b[2 q\x1b[?25h", // steady block cursor, blank cell
                L"\x1b[9;16H", // move cursor
                L"\x1b[4 q", // steady underline cursor
                L"\x1b[?25l" // hide cursor
            };
            terminal.Write(edits[step]);
        }
        if (step == 1)
            THROW_HR_IF(E_UNEXPECTED, terminal.GetTextBuffer().GetRowByOffset(terminal.GetViewport().Top() + 2).GlyphAt(7) != L"Z");
        if (step >= 12)
        {
            const auto position = terminal.GetTextBuffer().GetCursor().GetPosition();
            THROW_HR_IF(E_UNEXPECTED, position.x != (step == 12 ? 11 : 15) || position.y != terminal.GetViewport().Top() + 8);
        }
        // Do not call TriggerRedrawAll or WM_PAINT here. Only the core's normal
        // invalidation plus a wake may drive this side of the comparison.
        requested = atlas->RequestFrame();
        renderer.NotifyPaintFrame();
        repaintStep = step; repaintPhase = 1;
        return L"";
    }
    THROW_HR_IF(E_UNEXPECTED, step != repaintStep || atlas->CompletedRequest() < requested);
    if (operation == 1 || operation == 4)
    {
        THROW_HR_IF(E_UNEXPECTED, repaintPhase != 1);
        incrementalState = CoreSnapshot();
        const std::lock_guard rasterGuard(rasterMutex);
        THROW_HR_IF(E_PENDING, raster.empty());
        incrementalPixels = raster; incrementalWidth = rasterWidth; incrementalHeight = rasterHeight;
        if (operation == 4) incrementalPixels[0] ^= 0x0000ff; // Negative comparator control, CPU copy only.
        repaintPhase = 2;
        return L"";
    }
    if (operation == 2)
    {
        THROW_HR_IF(E_UNEXPECTED, repaintPhase != 2);
        requested = atlas->RequestFrame();
        renderer.TriggerRedrawAll();
        repaintPhase = 3;
        return L"";
    }
    THROW_HR_IF(E_UNEXPECTED, (operation != 3 && operation != 5) || repaintPhase != 3 || CoreSnapshot() != incrementalState);
    if (operation == 5)
    {
        repaintPhase = 0;
        return L"PASS: recovery sampled core unchanged; cross-device pixels are not required to match";
    }
    const std::lock_guard rasterGuard(rasterMutex);
    if (rasterWidth != incrementalWidth || rasterHeight != incrementalHeight || raster.size() != incrementalPixels.size())
        throw std::runtime_error(fmt::format("Atlas comparison dimensions changed: retained {}x{}, current {}x{}",
            incrementalWidth, incrementalHeight, rasterWidth, rasterHeight));
    size_t different = 0, changed = 0, outsideCursor = 0;
    for (size_t i = 0; i < raster.size(); ++i)
    {
        const auto rgb = raster[i] & 0xffffff;
        different += rgb != (incrementalPixels[i] & 0xffffff);
        if (previousPixels.size() == raster.size() && rgb != (previousPixels[i] & 0xffffff))
        {
            ++changed;
            if (step >= 12)
            {
                const auto x = i % rasterWidth, y = i / rasterWidth;
                const auto inside = [&](size_t column) {
                    return x >= column * cellWidth && x < (column + 1) * cellWidth &&
                        y >= 8u * cellHeight && y < 9u * cellHeight;
                };
                const bool allowed = step == 12 ? inside(11) : step == 13 ? inside(11) || inside(15) : inside(15);
                if (!allowed) ++outsideCursor;
            }
        }
    }
    if (different) throw std::runtime_error("Atlas differential repaint mismatch");
    if (step && !changed) throw std::runtime_error("Atlas edit produced no changed pixels");
    if (outsideCursor) throw std::runtime_error("Atlas cursor pixels escaped expected core cells");
    previousPixels = raster;
    repaintPhase = 0;
    return fmt::format(L"PASS: repaint step {}, renderer {}, exact RGB, changed {}, cursor outside {}, core unchanged, {} x {} cells",
        step, mode, changed, outsideCursor, viewport.Width(), viewport.Height());
}
