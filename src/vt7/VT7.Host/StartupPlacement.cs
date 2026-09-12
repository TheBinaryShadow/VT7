// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace VT7.Host
{
    internal static class StartupPlacement
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct NativeRect { internal int Left, Top, Right, Bottom; }
        [StructLayout(LayoutKind.Sequential)]
        private struct MonitorInfo { internal uint Size; internal NativeRect Monitor, Work; internal uint Flags; }
        [DllImport("user32.dll")]
        private static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetWindowRect(IntPtr window, out NativeRect rect);

        internal static Rect Fit(Rect work, double width, double height)
        {
            width = Math.Min(width, work.Width);
            height = Math.Min(height, work.Height);
            return new Rect(work.Left + (work.Width - width) / 2,
                work.Top + (work.Height - height) / 2, width, height);
        }

        private static Rect WorkArea(Window window)
        {
            var handle = new WindowInteropHelper(window).Handle;
            var monitor = MonitorFromWindow(handle, 2); // MONITOR_DEFAULTTONEAREST, Windows 7 API.
            var info = new MonitorInfo { Size = (uint)Marshal.SizeOf(typeof(MonitorInfo)) };
            if (!GetMonitorInfo(monitor, ref info)) throw new System.ComponentModel.Win32Exception();
            var transform = HwndSource.FromHwnd(handle).CompositionTarget.TransformFromDevice;
            return new Rect(transform.Transform(new Point(info.Work.Left, info.Work.Top)),
                transform.Transform(new Point(info.Work.Right, info.Work.Bottom)));
        }

        internal static void Apply(Window window)
        {
            var work = WorkArea(window);
            var bounds = Fit(work, window.Width, window.Height);
            window.MinWidth = Math.Min(window.MinWidth, bounds.Width);
            window.MinHeight = Math.Min(window.MinHeight, bounds.Height);
            window.WindowStartupLocation = WindowStartupLocation.Manual;
            window.Width = bounds.Width;
            window.Height = bounds.Height;
            window.Left = bounds.Left;
            window.Top = bounds.Top;
        }

        internal static string Check(Window window)
        {
            // Pure geometry controls include nonzero and negative monitor origins.
            foreach (var dpi in new[] { 96, 120, 144 })
            {
                var work = new Rect(-1920 * 96.0 / dpi, 24 * 96.0 / dpi, 1920 * 96.0 / dpi, 1000 * 96.0 / dpi);
                if (!work.Contains(Fit(work, 1040, 800)) || !work.Contains(Fit(work, 4000, 4000)))
                    throw new InvalidOperationException("Startup work-area geometry control failed.");
            }
            var handle = new WindowInteropHelper(window).Handle;
            if (!GetWindowRect(handle, out var rect)) throw new System.ComponentModel.Win32Exception();
            var transform = HwndSource.FromHwnd(handle).CompositionTarget.TransformFromDevice;
            var bounds = new Rect(transform.Transform(new Point(rect.Left, rect.Top)), transform.Transform(new Point(rect.Right, rect.Bottom)));
            var workArea = WorkArea(window);
            workArea.Inflate(1.1, 1.1); // Integer native-pixel placement rounding.
            if (!workArea.Contains(bounds)) throw new InvalidOperationException("Initial native window lies outside the monitor work area.");
            return "PASS: initial native window fits monitor work area; 96/120/144 DPI geometry controls passed (simulated)";
        }
    }
}
