using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;

namespace VT7.Host
{
    internal sealed class TerminalSurface : HwndHost
    {
        protected override HandleRef BuildWindowCore(HandleRef hwndParent)
        {
            if (NativeMethods.VT7_GetAbiVersion() != NativeMethods.ExpectedAbiVersion)
                throw new InvalidOperationException("The VT7 native bridge ABI does not match this host.");
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_CreateSurface(hwndParent.Handle, out var window));
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

        internal void PaintNow()
        {
            // RDW_INVALIDATE | RDW_UPDATENOW: exercises WM_PAINT even in the hidden test window.
            if (!NativeMethods.RedrawWindow(Handle, IntPtr.Zero, IntPtr.Zero, 0x101))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
    }
}
