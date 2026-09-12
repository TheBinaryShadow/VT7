// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
using System;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Threading;

namespace VT7.Host
{
    internal static class RepaintWindowChecks
    {
        internal static async Task Run(string[] args, StringBuilder report)
        {
            var window = new MainWindow { Opacity = 0, ShowActivated = false, ShowInTaskbar = false };
            IntPtr handle = IntPtr.Zero;
            try
            {
                window.Show();
                await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                var viewport = window.Viewport ?? throw new InvalidOperationException("No repaint viewport.");
                handle = viewport.Handle;
                for (var size = 0; size < 2; ++size)
                {
                    window.Width = size == 0 ? 1040 : 760;
                    window.Height = size == 0 ? 940 : 650;
                    window.UpdateLayout();
                    await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                    await viewport.PaintAndWaitAsync();
                    report.AppendLine($"Repaint size {size}: renderer {App.RendererMode}");
                    for (uint step = 0; step < 16; ++step)
                    {
                        viewport.RepaintCheck(0, step);
                        // No WM_PAINT/full invalidation between the VT edit and its readback.
                        await viewport.WaitForRequestedFrameAsync(false);
                        viewport.RepaintCheck(App.InjectRepaintFailure && step == 1 ? 4u : 1u, step);
                        var output = Array.IndexOf(args, "--diagnostics-output");
                        if (output >= 0 && output + 1 < args.Length && (step == 4 || step == 12))
                            viewport.SaveCapture(args[output + 1] + $".size{size}.step{step}.png");
                        viewport.RepaintCheck(2, step);
                        await viewport.WaitForRequestedFrameAsync(false);
                        report.AppendLine(viewport.RepaintCheck(3, step));
                    }
                }
            }
            finally { window.Close(); }
            await System.Windows.Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
            if (NativeMethods.IsWindow(handle)) throw new InvalidOperationException("Repaint HWND survived disposal.");
            report.AppendLine("PASS: repaint HWND disposed; 32 exact comparisons, 8 cursor-cell checks");
        }
    }
}
