using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;
using System.Diagnostics;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal sealed class TerminalSurface : HwndHost
    {
        internal event Action? RecoveryStatusChanged;
        protected override IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == 0x8001)
            {
                RecoveryStatusChanged?.Invoke();
                handled = true;
                return IntPtr.Zero;
            }
            return base.WndProc(hwnd, msg, wParam, lParam, ref handled);
        }

        internal void InjectFailure(uint fault) =>
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_InjectSurfaceFailure(Handle, fault));
        protected override HandleRef BuildWindowCore(HandleRef hwndParent)
        {
            if (NativeMethods.VT7_GetAbiVersion() != NativeMethods.ExpectedAbiVersion)
                throw new InvalidOperationException("The VT7 native bridge ABI does not match this host.");
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_CreateSurface(hwndParent.Handle, App.SurfaceOptions, out var window));
            return new HandleRef(this, window);
        }

        protected override void DestroyWindowCore(HandleRef hwnd)
        {
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_DestroySurface(hwnd.Handle));
        }

        internal NativeMethods.SurfaceInfo ReadInfo()
        {
            var info = new NativeMethods.SurfaceInfo
            {
                StructSize = (uint)Marshal.SizeOf(typeof(NativeMethods.SurfaceInfo)),
            };
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_GetSurfaceInfo(Handle, ref info));
            return info;
        }

        internal void ResetDemo()
        {
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_ResetSurface(Handle));
        }

        internal NativeMethods.SurfaceSettings ReadSettings()
        {
            var settings = new NativeMethods.SurfaceSettings { StructSize = (uint)Marshal.SizeOf(typeof(NativeMethods.SurfaceSettings)) };
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_GetSurfaceSettings(Handle, ref settings));
            return settings;
        }

        internal void SetFont(uint family, uint points, uint weight, uint diagnosticDpi = 0) =>
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_SetSurfaceFont(Handle, family, points, weight, diagnosticDpi));

        internal void PaintNow()
        {
            // RDW_INVALIDATE | RDW_UPDATENOW: exercises WM_PAINT even in the hidden test window.
            if (!NativeMethods.RedrawWindow(Handle, IntPtr.Zero, IntPtr.Zero, 0x101))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }

        internal void SaveCapture(string path)
        {
            var full = System.IO.Path.GetFullPath(path);
            System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(full)!);
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_SaveSurfaceCapture(Handle, full));
        }

        internal async Task PaintAndWaitAsync()
        {
            PaintNow();
            await WaitForRequestedFrameAsync();
        }

        internal string RepaintCheck(uint operation, uint step)
        {
            var report = new System.Text.StringBuilder(2048);
            var hr = NativeMethods.VT7_SurfaceRepaintCheck(Handle, operation, step, report, (uint)report.Capacity);
            if (hr < 0) throw new InvalidOperationException($"Repaint operation {operation}, step {step}: {report} (0x{unchecked((uint)hr):X8})");
            return report.ToString();
        }

        internal async Task WaitForRequestedFrameAsync(bool checkNonblank = true)
        {
            var target = ReadInfo().RequestedFrame;
            var timer = Stopwatch.StartNew();
            while (true)
            {
                var info = ReadInfo();
                Marshal.ThrowExceptionForHR(info.LastHResult);
                if (info.RequestedRendererMode != App.RendererMode ||
                    (info.PaintCount > 0 && (App.RendererMode == 5 ? info.RendererMode != 1 && info.RendererMode != 2 : info.RendererMode != App.RendererMode)))
                    throw new InvalidOperationException("The requested renderer was not used.");
                if (info.CompletedRequest >= Math.Max(target, info.RequestedFrame) && info.PaintCount > 0)
                {
                    // Reflow/scroll can leave row zero blank. This is a whole-frame
                    // nonuniformity check for known fixtures, not a glyph-correctness oracle.
                    if (checkNonblank && info.RendererMode != 0 && App.CaptureFrames && info.FrameInkPixels < 10)
                        throw new InvalidOperationException("Atlas frame has no nonbackground pixels.");
                    return;
                }
                if (timer.ElapsedMilliseconds > 10000)
                    throw new TimeoutException("No completed frame from the requested renderer within 10 seconds.");
                await Task.Delay(15);
            }
        }
    }
}
