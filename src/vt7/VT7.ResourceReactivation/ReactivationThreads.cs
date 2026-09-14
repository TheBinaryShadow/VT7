// Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace VT7.Host
{
    internal sealed class ReactivationThreads
    {
        private sealed class Identity { internal uint Tid; internal ulong Creation; internal int First, Last, FirstQueue; }
        private readonly Dictionary<string, Identity> identities = new Dictionary<string, Identity>(8192);
        [StructLayout(LayoutKind.Sequential)]
        private struct GuiInfo { internal uint Size, Flags; internal IntPtr Active, Focus, Capture, Menu, Move, Caret; internal int Left, Top, Right, Bottom; }
        [DllImport("kernel32.dll", EntryPoint = "GetTickCount64")] internal static extern ulong Ticks();
        [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr OpenThread(uint access, bool inherit, uint tid);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern uint GetProcessIdOfThread(IntPtr thread);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool GetThreadTimes(IntPtr thread, out ulong creation, out ulong exit, out ulong kernel, out ulong user);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern uint WaitForSingleObject(IntPtr thread, uint timeout);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool CloseHandle(IntPtr handle);
        [DllImport("user32.dll", SetLastError = true)] private static extern bool GetGUIThreadInfo(uint tid, ref GuiInfo info);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr GetModuleHandle(string name);
        [DllImport("kernel32.dll", CharSet = CharSet.Ansi, ExactSpelling = true)] private static extern IntPtr GetProcAddress(IntPtr module, string name);
        [DllImport("kernel32.dll", EntryPoint = "GetModuleHandleExW")] private static extern bool GetModuleHandleEx(uint flags, IntPtr address, out IntPtr module);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern uint GetModuleFileName(IntPtr module, StringBuilder name, uint size);
        [UnmanagedFunctionPointer(CallingConvention.Winapi)] private delegate int QueryStart(IntPtr thread, uint info, out IntPtr start, uint size, IntPtr returned);
        private readonly QueryStart? query;
        internal ReactivationThreads()
        {
            var address = GetProcAddress(GetModuleHandle("ntdll.dll"), "NtQueryInformationThread");
            if (address != IntPtr.Zero) query = (QueryStart)Marshal.GetDelegateForFunctionPointer(address, typeof(QueryStart));
        }
        internal void Read(int sample, Action<string> log)
        {
            var rows = 0; var unavailable = 0;
            var begin = Ticks();
            using (var process = Process.GetCurrentProcess())
            {
                var all = process.Threads;
                if (all.Count > 4096) throw new InvalidOperationException("Thread snapshot capacity exceeded.");
                foreach (ProcessThread thread in all)
                using (thread)
                {
                    ++rows;
                    var tid = (uint)thread.Id;
                    ulong creation = 0;
                    uint before = uint.MaxValue, after = uint.MaxValue;
                    var origin = "unavailable"; ulong offset = 0;
                    var queue = false; var queueError = -1; var error = 0;
                    var status = "unavailable";
                    var handle = OpenThread(0x100040, false, tid);
                    if (handle == IntPtr.Zero) error = Marshal.GetLastWin32Error();
                    else
                    {
                        try
                        {
                            if (GetProcessIdOfThread(handle) != process.Id) status = "owner-mismatch";
                            else if (!GetThreadTimes(handle, out creation, out _, out _, out _)) error = Marshal.GetLastWin32Error();
                            else
                            {
                                before = WaitForSingleObject(handle, 0);
                                if (before == 258)
                                {
                                    if (query != null && query(handle, 9, out var start, (uint)IntPtr.Size, IntPtr.Zero) >= 0 && GetModuleHandleEx(0x6, start, out var module))
                                    {
                                        var name = new StringBuilder(1024);
                                        if (GetModuleFileName(module, name, (uint)name.Capacity) > 0)
                                        { origin = Uri.EscapeDataString(Path.GetFileName(name.ToString())); offset = unchecked((ulong)(start.ToInt64() - module.ToInt64())); }
                                    }
                                    var gui = new GuiInfo { Size = (uint)Marshal.SizeOf(typeof(GuiInfo)) };
                                    queue = GetGUIThreadInfo(tid, ref gui);
                                    queueError = queue ? 0 : Marshal.GetLastWin32Error();
                                    after = WaitForSingleObject(handle, 0);
                                    status = after == 258 ? "live" : "changed";
                                    if (status != "live") queue = false;
                                }
                                else status = "not-live";
                            }
                        }
                        finally { if (!CloseHandle(handle)) throw new InvalidOperationException("Cannot close a diagnostic thread handle."); }
                    }
                    var first = 0; var firstQueue = 0;
                    if (status == "live")
                    {
                        var key = tid.ToString(CultureInfo.InvariantCulture) + ":" + creation.ToString("X16", CultureInfo.InvariantCulture);
                        if (!identities.TryGetValue(key, out var identity))
                        {
                            if (identities.Count >= 8192) throw new InvalidOperationException("Thread identity capacity exceeded.");
                            identity = new Identity { Tid = tid, Creation = creation, First = sample };
                            identities.Add(key, identity);
                        }
                        identity.Last = sample;
                        if (queue && identity.FirstQueue == 0) identity.FirstQueue = sample;
                        first = identity.First; firstQueue = identity.FirstQueue;
                    }
                    else ++unavailable;
                    log(FormattableString.Invariant($"THREAD sample={sample} tid={tid} creation={creation:X16} status={status} first_sample={first} first_queue_sample={firstQueue} origin={origin} offset=0x{offset:X} queue={(queue ? "observed" : "unavailable")} queue_error={queueError} alive_before={before} alive_after={after} error={error}"));
                }
            }
            var absent = 0;
            foreach (var identity in identities.Values)
                if (identity.Last != sample)
                {
                    ++absent;
                    log(FormattableString.Invariant($"NOT_OBSERVED sample={sample} tid={identity.Tid} creation={identity.Creation:X16} first_sample={identity.First} last_sample={identity.Last} first_queue_sample={identity.FirstQueue}"));
                }
            log(FormattableString.Invariant($"THREADS_END sample={sample} rows={rows} unavailable={unavailable} identities={identities.Count} not_observed={absent} begin_ms={begin} end_ms={Ticks()}"));
        }
        internal static void Modules(int sample, Action<string> log)
        {
            using (var process = Process.GetCurrentProcess())
                foreach (ProcessModule module in process.Modules)
                using (module)
                    log(FormattableString.Invariant($"MODULE sample={sample} name={Uri.EscapeDataString(module.ModuleName)} base=0x{module.BaseAddress.ToInt64():X} size={module.ModuleMemorySize} path={Uri.EscapeDataString(module.FileName)}"));
        }
    }
}
