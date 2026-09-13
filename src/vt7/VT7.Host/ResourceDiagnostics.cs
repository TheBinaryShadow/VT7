// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace VT7.Host
{
    // Optional checkpoint-only attribution, never part of the rendering path.
    internal static class ResourceDiagnostics
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct GuiThreadInfo
        {
            internal uint Size, Flags;
            internal IntPtr Active, Focus, Capture, MenuOwner, MoveSize, Caret;
            internal int Left, Top, Right, Bottom;
        }
        [DllImport("user32.dll")]
        private static extern bool GetGUIThreadInfo(uint thread, ref GuiThreadInfo info);
        [UnmanagedFunctionPointer(CallingConvention.Winapi)]
        private delegate int QueryThread(IntPtr thread, uint informationClass, out IntPtr start, uint size, IntPtr returnedSize);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr GetModuleHandle(string name);
        [DllImport("kernel32.dll", CharSet = CharSet.Ansi, ExactSpelling = true)]
        private static extern IntPtr GetProcAddress(IntPtr module, string name);
        [DllImport("kernel32.dll")]
        private static extern IntPtr OpenThread(uint access, bool inherit, uint id);
        [DllImport("kernel32.dll")]
        private static extern uint GetProcessIdOfThread(IntPtr thread);
        [DllImport("kernel32.dll")]
        private static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", EntryPoint = "GetModuleHandleExW")]
        private static extern bool GetModuleHandleEx(uint flags, IntPtr address, out IntPtr module);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        private static extern uint GetModuleFileName(IntPtr module, StringBuilder name, uint size);

        internal static string ReadThreadOrigins()
        {
            // Microsoft documents dynamic linking for this optional diagnostic.
            // Missing exports/access are reported, not a new application dependency.
            var address = GetProcAddress(GetModuleHandle("ntdll.dll"), "NtQueryInformationThread");
            if (address == IntPtr.Zero) return "start-address query unavailable";
            var query = (QueryThread)Marshal.GetDelegateForFunctionPointer(address, typeof(QueryThread));
            var groups = new SortedDictionary<string, int>();
            using (var process = Process.GetCurrentProcess())
            {
                foreach (ProcessThread thread in process.Threads)
                using (thread)
                {
                    var origin = "unavailable/exited";
                    var handle = OpenThread(0x40, false, (uint)thread.Id);
                    try
                    {
                        if (handle != IntPtr.Zero && GetProcessIdOfThread(handle) == process.Id)
                        {
                            if (query(handle, 9, out var start, (uint)IntPtr.Size, IntPtr.Zero) >= 0 &&
                                GetModuleHandleEx(0x6, start, out var module))
                            {
                                var path = new StringBuilder(1024);
                                if (GetModuleFileName(module, path, (uint)path.Capacity) > 0)
                                    origin = System.IO.Path.GetFileName(path.ToString()) + "+" + (start.ToInt64() - module.ToInt64()).ToString("x");
                            }
                            var gui = new GuiThreadInfo { Size = (uint)Marshal.SizeOf(typeof(GuiThreadInfo)) };
                            // Query only our own nonzero thread IDs, never the foreground thread.
                            // Success establishes an input queue, not who allocated its objects.
                            if (GetGUIThreadInfo((uint)thread.Id, ref gui)) origin += "/input-queue";
                        }
                    }
                    finally { if (handle != IntPtr.Zero) CloseHandle(handle); }
                    groups.TryGetValue(origin, out var count); groups[origin] = count + 1;
                }
            }
            var text = new StringBuilder();
            foreach (var group in groups) text.Append($"{group.Key}={group.Value}; ");
            return text.ToString();
        }
    }
}
