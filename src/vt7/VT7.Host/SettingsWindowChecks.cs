// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
using System;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;

namespace VT7.Host
{
    internal static class SettingsWindowChecks
    {
        private static void Require(bool value, string message)
        {
            if (!value) throw new InvalidOperationException(message);
        }

        private static void CheckGeometry(TerminalSurface viewport, bool negative = false)
        {
            var info = viewport.ReadInfo();
            var settings = viewport.ReadSettings();
            var matrix = PresentationSource.FromVisual(viewport)?.CompositionTarget?.TransformToDevice ??
                throw new InvalidOperationException("No WPF device transform.");
            Require(Math.Abs(matrix.M11 * 96 - settings.SystemDpi) <= 1 &&
                Math.Abs(matrix.M22 * 96 - settings.SystemDpi) <= 1, "WPF/native system DPI disagreement.");
            var expectedWidth = viewport.ActualWidth * matrix.M11 + (negative ? 20 : 0);
            Require(Math.Abs(settings.ClientWidth - expectedWidth) <= 1.1 &&
                Math.Abs(settings.ClientHeight - viewport.ActualHeight * matrix.M22) <= 1.1,
                "Settings geometry mismatch: WPF/native client pixels disagree.");
            Require(info.CellWidth > 0 && info.CellHeight > 0 &&
                info.Columns == Math.Max(1u, Math.Min(512u, settings.ClientWidth / info.CellWidth)) &&
                info.Rows == Math.Max(1u, Math.Min(256u, settings.ClientHeight / info.CellHeight)),
                "Settings geometry mismatch: core grid does not fit native pixels.");
            Require(info.RasterWidth == settings.ClientWidth && info.RasterHeight == settings.ClientHeight,
                "Settings geometry mismatch: captured raster does not fit native client pixels.");
        }

        internal static async Task Run(string[] args, StringBuilder report)
        {
            var window = new MainWindow { FitStartupToWorkArea = false, Width = 1100, Height = 1040, Opacity = 0, ShowActivated = false, ShowInTaskbar = false };
            IntPtr handle = IntPtr.Zero;
            try
            {
                window.Show();
                await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                var viewport = window.Viewport ?? throw new InvalidOperationException("No settings viewport.");
                handle = viewport.Handle;
                await viewport.PaintAndWaitAsync();
                var initial = viewport.ReadSettings();
                report.AppendLine($"Settings test: requested renderer {App.RendererMode}, measured system DPI {initial.SystemDpi}; renderer overrides are SIMULATED, not system scaling");
                Require(App.ExpectedSystemDpi == 0 || App.ExpectedSystemDpi == initial.SystemDpi,
                    $"Expected system DPI {App.ExpectedSystemDpi}, measured {initial.SystemDpi}. Change Windows scaling and sign out/in before retesting.");
                CheckGeometry(viewport, App.InjectSettingsFailure);
                viewport.RepaintCheck(6, 0);
                await viewport.WaitForRequestedFrameAsync();
                var baseline = viewport.ReadInfo();
                // Family, points, weight, diagnostic DPI (zero means actual system DPI).
                var cases = new uint[][] {
                    new uint[] {1,12,400,0}, new uint[] {1,14,400,0}, new uint[] {1,18,700,0},
                    new uint[] {2,12,400,0}, new uint[] {2,14,700,0}, new uint[] {1,12,400,96},
                    new uint[] {1,12,400,120}, new uint[] {1,12,400,144}, new uint[] {2,14,700,144},
                    new uint[] {1,12,400,0}
                };
                var output = Array.IndexOf(args, "--diagnostics-output");
                uint at96Width = 0, at96Height = 0;
                var previousHash = baseline.RasterHash;
                for (var step = 0; step < cases.Length; ++step)
                {
                    var c = cases[step];
                    viewport.SetFont(c[0], c[1], c[2], c[3]);
                    await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                    await viewport.WaitForRequestedFrameAsync();
                    CheckGeometry(viewport);
                    viewport.RepaintCheck(7, 0);
                    var settings = viewport.ReadSettings();
                    var info = viewport.ReadInfo();
                    Require(step == 0 || info.RasterHash != previousHash, "A changed font/DPI setting produced unchanged pixels.");
                    previousHash = info.RasterHash;
                    Require(settings.FontFamily == c[0] && settings.FontPoints == c[1] && settings.FontWeight == c[2] &&
                        settings.DpiOverride == c[3] && settings.EffectiveDpi == (c[3] == 0 ? initial.SystemDpi : c[3]), "Requested font/settings were not applied.");
                    Require(info.DeviceGeneration == baseline.DeviceGeneration && info.FallbackCount == baseline.FallbackCount,
                        "Font/settings change unexpectedly replaced the device.");
                    viewport.SetFont(c[0], c[1], c[2], c[3]);
                    Require(viewport.ReadSettings().Generation == settings.Generation && viewport.ReadInfo().RequestedFrame == info.RequestedFrame,
                        "Identical font settings did not remain a no-op.");
                    if (step == 5) { at96Width = info.CellWidth; at96Height = info.CellHeight; }
                    if (step == 6 || step == 7)
                        Require(info.CellWidth > at96Width && info.CellHeight > at96Height, "Simulated DPI did not increase font cell metrics.");
                    viewport.RepaintCheck(8, 0);
                    viewport.RepaintCheck(2, 0);
                    await viewport.WaitForRequestedFrameAsync();
                    viewport.RepaintCheck(3, 0);
                    report.AppendLine($"PASS: settings step {step}, family {c[0]}, points {c[1]}, weight {c[2]}, effective DPI {settings.EffectiveDpi}, override {c[3]}, generation {settings.Generation}, {info.CellWidth}x{info.CellHeight} px, {info.Columns}x{info.Rows} cells; source/colors, geometry, no-op and exact RGB passed");
                    if (output >= 0 && output + 1 < args.Length && (step == 0 || step == 3 || step == 7 || step == 9))
                        viewport.SaveCapture(args[output + 1] + $".step{step}.png");
                }
                var restored = viewport.ReadInfo();
                Require(restored.CellWidth == baseline.CellWidth && restored.CellHeight == baseline.CellHeight &&
                    restored.Columns == baseline.Columns && restored.Rows == baseline.Rows && restored.RasterHash == baseline.RasterHash,
                    "Restoring baseline settings did not restore the same grid and pixels.");
                var invalid = new uint[][] {
                    new uint[] {0,12,400,0}, new uint[] {3,12,400,0}, new uint[] {1,5,400,0}, new uint[] {1,33,400,0},
                    new uint[] {1,12,0,0}, new uint[] {1,12,900,0}, new uint[] {1,12,400,97}, new uint[] {1,12,400,uint.MaxValue}
                };
                var unchanged = viewport.ReadSettings();
                foreach (var c in invalid)
                {
                    var hr = NativeMethods.VT7_SetSurfaceFont(handle, c[0], c[1], c[2], c[3]);
                    Require(hr == unchecked((int)0x80070057), "Invalid setting was not rejected with E_INVALIDARG.");
                    Require(viewport.ReadSettings().Generation == unchanged.Generation && viewport.ReadInfo().LastHResult >= 0 &&
                        viewport.ReadInfo().RequestedFrame == restored.RequestedFrame, "Rejected settings changed the surface.");
                }
                report.AppendLine("PASS: eight invalid settings rejected without mutation; baseline grid/pixels restored");

                window.ProofTabs.SelectedIndex = 1;
                await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                var hiddenFrames = viewport.ReadInfo().PaintCount;
                viewport.SetFont(2, 14, 400);
                await Task.Delay(100);
                Require(!NativeMethods.IsWindowVisible(handle) && viewport.ReadInfo().PaintCount == hiddenFrames,
                    "Hidden settings change presented a frame.");
                window.ProofTabs.SelectedIndex = 0;
                await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                await viewport.PaintAndWaitAsync();
                CheckGeometry(viewport);
                viewport.RepaintCheck(7, 0);
                viewport.SetFont(1, 12, 400);
                await viewport.WaitForRequestedFrameAsync();
                report.AppendLine("PASS: hidden font change stayed parked and resumed with preserved fixture");
                report.AppendLine(await ProofWindowChecks.CheckTabRoundTrip(window, viewport));
            }
            finally { window.Close(); }
            await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
            Require(!NativeMethods.IsWindow(handle), "Settings HWND survived disposal.");
            report.AppendLine("PASS: settings HWND disposed; 10 settings cases, 8 invalid inputs, hidden update");
        }
    }
}
