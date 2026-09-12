using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace VT7.Host
{
    // These checks inspect the real WPF visual tree, not just resource definitions.
    // They deliberately do not claim to replace screenshot or keyboard testing.
    internal static class ProofWindowChecks
    {
        internal static async Task<string> CheckStatusLayout(MainWindow window, TerminalSurface viewport)
        {
            var width = window.Width;
            var saved = window.SurfaceStatus.Text;
            window.TestingStatusLayout = true;
            try
            {
                window.Width = 760;
                await Settle(window);
                await viewport.PaintAndWaitAsync();
                var before = viewport.ReadSettings();
                var raster = viewport.ReadInfo();
                const string longStatus = "TerminalCore | Atlas D3D11 hardware | 108 x 20 cells | 11 x 23 px | frames (snapshot) 123456, resizes 123456 | system DPI 144 | device 123456, failures 123456, WARP fallbacks 123456, last 0x887A0005";
                window.SurfaceStatus.Text = longStatus + " | " + longStatus;
                await Settle(window);
                await viewport.PaintAndWaitAsync();
                var after = viewport.ReadSettings();
                var current = viewport.ReadInfo();
                if (before.ClientWidth != after.ClientWidth || before.ClientHeight != after.ClientHeight ||
                    raster.RasterWidth != current.RasterWidth || raster.RasterHeight != current.RasterHeight)
                    throw new InvalidOperationException($"Status text changed viewport geometry: client {before.ClientWidth}x{before.ClientHeight} -> {after.ClientWidth}x{after.ClientHeight}, raster {raster.RasterWidth}x{raster.RasterHeight} -> {current.RasterWidth}x{current.RasterHeight}");
                // Re-enable the old layout policy in this hidden test only. The
                // control must reproduce a height change, not merely pass vacuously.
                window.SurfaceStatus.TextWrapping = TextWrapping.Wrap;
                window.SurfaceStatus.TextTrimming = TextTrimming.None;
                await Settle(window);
                var wrapped = viewport.ReadSettings();
                if (wrapped.ClientHeight == after.ClientHeight)
                    throw new InvalidOperationException("Old wrapping status control did not change viewport height.");
                return $"PASS: long recovery status at 760 DIPs preserved client/raster dimensions; old-wrap control changed client height {after.ClientHeight} -> {wrapped.ClientHeight}";
            }
            finally
            {
                window.SurfaceStatus.TextWrapping = TextWrapping.NoWrap;
                window.SurfaceStatus.TextTrimming = TextTrimming.CharacterEllipsis;
                window.SurfaceStatus.Text = saved;
                window.Width = width;
                window.TestingStatusLayout = false;
                await Settle(window);
                await viewport.PaintAndWaitAsync();
                window.RefreshSurfaceStatus();
            }
        }

        internal static async Task<string> CheckBlankFirstRow(TerminalSurface viewport)
        {
            viewport.RepaintCheck(9, 0);
            await viewport.WaitForRequestedFrameAsync();
            var info = viewport.ReadInfo();
            if (info.HeaderInkPixels != 0 || info.FrameInkPixels < 10)
                throw new InvalidOperationException("Blank-first-row control did not isolate visible lower-row text.");
            viewport.ResetDemo();
            await viewport.PaintAndWaitAsync();
            return "PASS: blank first row with visible lower-row text accepted; whole-frame pixels checked";
        }

        internal static async Task CheckFirstFrameStatus(MainWindow window)
        {
            for (var attempt = 0; attempt < 100; ++attempt)
            {
                var match = System.Text.RegularExpressions.Regex.Match(window.SurfaceStatus.Text, @"frames \(snapshot\) ([1-9]\d*)");
                if (match.Success) return;
                await Task.Delay(50);
            }
            throw new InvalidOperationException("The visible status did not refresh after the first completed frame.");
        }

        internal static async Task<string> CheckTabRoundTrip(MainWindow window, TerminalSurface viewport)
        {
            var handle = viewport.Handle;
            var before = viewport.ReadInfo();
            if (!NativeMethods.IsWindowVisible(handle))
                throw new InvalidOperationException("The selected terminal child HWND is not visible.");

            window.ProofTabs.SelectedIndex = 1;
            await Settle(window);
            if (!NativeMethods.IsWindow(handle) || NativeMethods.IsWindowVisible(handle))
                throw new InvalidOperationException("The terminal HWND must survive but be hidden on the Diagnostics tab.");
            var hiddenFrames = viewport.ReadInfo().PaintCount;
            await Task.Delay(100);
            if (viewport.ReadInfo().PaintCount != hiddenFrames)
                throw new InvalidOperationException("The hidden terminal continued presenting frames.");

            var diagnosticValues = new[]
            {
                window.VersionValue, window.NativeValue, window.WindowsValue, window.RuntimeValue,
                window.AdapterValue, window.HardwareValue, window.WarpValue, window.DxgiValue,
                window.LastRunValue, window.LogValue,
            };
            var minimumContrast = diagnosticValues.Min(CheckTextContrast);
            minimumContrast = Math.Min(minimumContrast, CheckHeaders(window));

            window.ProofTabs.SelectedIndex = 0;
            await Settle(window);
            minimumContrast = Math.Min(minimumContrast, CheckHeaders(window));
            if (!ReferenceEquals(window.Viewport, viewport) || viewport.Handle != handle ||
                !NativeMethods.IsWindowVisible(handle))
                throw new InvalidOperationException("Returning to the viewport did not restore the same visible child HWND.");

            await viewport.PaintAndWaitAsync();
            var after = viewport.ReadInfo();
            if (after.LastHResult < 0 || after.Columns != before.Columns || after.Rows != before.Rows ||
                after.PaintCount <= before.PaintCount)
                throw new InvalidOperationException("The returned viewport lost its grid or failed to repaint.");

            // Paint counters in the visible status/log must include the return paint.
            window.RefreshSurfaceStatus();
            return string.Format(CultureInfo.InvariantCulture,
                "PASS: tab round trip, same HWND/grid restored, repaint verified; 10 diagnostic values and both header states >= {0:F2}:1 contrast",
                minimumContrast);
        }

        private static async Task Settle(MainWindow window)
        {
            window.UpdateLayout();
            await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
        }

        private static double CheckHeaders(MainWindow window)
        {
            var minimumContrast = double.MaxValue;
            foreach (TabItem tab in window.ProofTabs.Items)
            {
                var text = Descendants<TextBlock>(tab).SingleOrDefault(candidate => candidate.Text == tab.Header.ToString())
                    ?? throw new InvalidOperationException("The tab's rendered header text was not found.");
                minimumContrast = Math.Min(minimumContrast, CheckTextContrast(text));
            }
            return minimumContrast;
        }

        private static double CheckTextContrast(TextBlock text)
        {
            if (!text.IsVisible || string.IsNullOrWhiteSpace(text.Text))
                throw new InvalidOperationException("Expected visible, nonempty proof text: " + text.Name);

            var foreground = OpaqueColor(text.Foreground, "foreground");
            var background = BackgroundBehind(text);
            var first = Luminance(foreground);
            var second = Luminance(background);
            var ratio = (Math.Max(first, second) + 0.05) / (Math.Min(first, second) + 0.05);
            if (ratio < 4.5)
                throw new InvalidOperationException(string.Format(CultureInfo.InvariantCulture,
                    "Low text contrast for {0}: {1:F2}:1 ({2} on {3}); at least 4.5:1 required.",
                    string.IsNullOrEmpty(text.Name) ? text.Text : text.Name, ratio, foreground, background));
            return ratio;
        }

        private static Color BackgroundBehind(DependencyObject element)
        {
            for (var parent = VisualTreeHelper.GetParent(element); parent != null; parent = VisualTreeHelper.GetParent(parent))
            {
                var brush = parent is Border border ? border.Background :
                    parent is Panel panel ? panel.Background : parent is Control control ? control.Background : null;
                if (brush == null || brush.Opacity == 0 || (brush is SolidColorBrush solid && solid.Color.A == 0))
                    continue;
                return OpaqueColor(brush, "background");
            }
            throw new InvalidOperationException("No opaque background found behind proof text.");
        }

        private static Color OpaqueColor(Brush brush, string role)
        {
            if (brush is SolidColorBrush solid && solid.Color.A == 255 && brush.Opacity == 1)
                return solid.Color;
            throw new InvalidOperationException("The proof contrast check requires an opaque solid " + role + ".");
        }

        private static double Luminance(Color color)
        {
            double Linear(byte channel)
            {
                var value = channel / 255.0;
                return value <= 0.04045 ? value / 12.92 : Math.Pow((value + 0.055) / 1.055, 2.4);
            }
            return 0.2126 * Linear(color.R) + 0.7152 * Linear(color.G) + 0.0722 * Linear(color.B);
        }

        private static IEnumerable<T> Descendants<T>(DependencyObject root) where T : DependencyObject
        {
            for (var index = 0; index < VisualTreeHelper.GetChildrenCount(root); ++index)
            {
                var child = VisualTreeHelper.GetChild(root, index);
                if (child is T match) yield return match;
                foreach (var nested in Descendants<T>(child)) yield return nested;
            }
        }
    }
}
