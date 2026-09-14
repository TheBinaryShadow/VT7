using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Interop;

namespace VT7.InputFocusProbe
{
    internal sealed class NativeInputHost : HwndHost
    {
        private const int WsChild = 0x40000000;
        private const int WsVisible = 0x10000000;
        private const int WsTabStop = 0x00010000;
        private const int WsVScroll = 0x00200000;
        private const int EsMultiline = 0x0004;
        private const int EsWantReturn = 0x1000;
        private const int WsExClientEdge = 0x00000200;
        private const int WmSize = 0x0005;
        private const int WmSetFocus = 0x0007;
        private const int WmKillFocus = 0x0008;
        private const int WmKeyDown = 0x0100;
        private const int WmKeyUp = 0x0101;
        private const int WmChar = 0x0102;
        private const int WmDeadChar = 0x0103;
        private const int WmSysKeyDown = 0x0104;
        private const int WmSysKeyUp = 0x0105;
        private const int WmSysChar = 0x0106;
        private const int WmSysDeadChar = 0x0107;

        private readonly JsonEventLog _log;
        private readonly Action<string> _observed;
        private IntPtr _window;

        internal NativeInputHost(JsonEventLog log, Action<string> observed)
        {
            _log = log;
            _observed = observed;
            Focusable = true;
        }

        protected override HandleRef BuildWindowCore(HandleRef hwndParent)
        {
            _window = CreateWindowExW(WsExClientEdge, "EDIT", string.Empty,
                WsChild | WsVisible | WsTabStop | WsVScroll | EsMultiline | EsWantReturn,
                0, 0, 100, 100, hwndParent.Handle, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
            if (_window == IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            _log.Write("native", "created", Pair("hwnd", Hex(_window)));
            return new HandleRef(this, _window);
        }

        protected override void DestroyWindowCore(HandleRef hwnd)
        {
            _log.Write("native", "destroying", Pair("hwnd", Hex(hwnd.Handle)));
            DestroyWindow(hwnd.Handle);
            _window = IntPtr.Zero;
        }

        protected override IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            var name = MessageName(msg);
            if (name != null)
            {
                var fields = new List<KeyValuePair<string, object?>>
                {
                    Pair("message", Hex(new IntPtr(msg))),
                    Pair("wParam", Hex(wParam)),
                    Pair("lParam", Hex(lParam))
                };
                if (msg == WmKeyDown || msg == WmKeyUp || msg == WmSysKeyDown || msg == WmSysKeyUp)
                {
                    var bits = unchecked((long)lParam.ToInt64());
                    fields.Add(Pair("virtualKey", unchecked((int)wParam.ToInt64())));
                    fields.Add(Pair("repeat", unchecked((int)(bits & 0xffff))));
                    fields.Add(Pair("scanCode", unchecked((int)((bits >> 16) & 0xff))));
                    fields.Add(Pair("extended", (bits & (1L << 24)) != 0));
                    fields.Add(Pair("previousDown", (bits & (1L << 30)) != 0));
                    fields.Add(Pair("transitionUp", (bits & (1L << 31)) != 0));
                    fields.Add(Pair("modifiers", ModifierState()));
                }
                else if (msg == WmChar || msg == WmDeadChar || msg == WmSysChar || msg == WmSysDeadChar)
                {
                    fields.Add(Pair("utf16Unit", unchecked((int)wParam.ToInt64())));
                }
                else if (msg == WmSize)
                {
                    var bits = unchecked((long)lParam.ToInt64());
                    fields.Add(Pair("width", unchecked((int)(bits & 0xffff))));
                    fields.Add(Pair("height", unchecked((int)((bits >> 16) & 0xffff))));
                }
                _log.Write("native", name, fields.ToArray());
                _observed(name);
            }
            return base.WndProc(hwnd, msg, wParam, lParam, ref handled);
        }

        internal void FocusNative()
        {
            if (_window != IntPtr.Zero) SetFocus(_window);
        }

        internal string ReadText()
        {
            if (_window == IntPtr.Zero) return string.Empty;
            var length = GetWindowTextLengthW(_window);
            var buffer = new System.Text.StringBuilder(length + 1);
            GetWindowTextW(_window, buffer, buffer.Capacity);
            return buffer.ToString();
        }

        internal void RunSyntheticSelfTest()
        {
            if (_window == IntPtr.Zero) return;
            SendMessageW(_window, WmKeyDown, new IntPtr(0x41), new IntPtr(1 | (0x1e << 16)));
            SendMessageW(_window, WmChar, new IntPtr('a'), new IntPtr(1 | (0x1e << 16)));
            SendMessageW(_window, WmKeyUp, new IntPtr(0x41), new IntPtr(1 | (0x1e << 16) | (1L << 30) | (1L << 31)));
        }

        private static string? MessageName(int message)
        {
            switch (message)
            {
                case WmSize: return "WM_SIZE";
                case WmSetFocus: return "WM_SETFOCUS";
                case WmKillFocus: return "WM_KILLFOCUS";
                case WmKeyDown: return "WM_KEYDOWN";
                case WmKeyUp: return "WM_KEYUP";
                case WmChar: return "WM_CHAR";
                case WmDeadChar: return "WM_DEADCHAR";
                case WmSysKeyDown: return "WM_SYSKEYDOWN";
                case WmSysKeyUp: return "WM_SYSKEYUP";
                case WmSysChar: return "WM_SYSCHAR";
                case WmSysDeadChar: return "WM_SYSDEADCHAR";
                default: return null;
            }
        }

        private static string ModifierState()
        {
            var parts = new List<string>();
            AddIfDown(parts, 0xa0, "LShift");
            AddIfDown(parts, 0xa1, "RShift");
            AddIfDown(parts, 0xa2, "LCtrl");
            AddIfDown(parts, 0xa3, "RCtrl");
            AddIfDown(parts, 0xa4, "LAlt");
            AddIfDown(parts, 0xa5, "RAlt");
            return string.Join("+", parts);
        }

        private static void AddIfDown(List<string> parts, int virtualKey, string name)
        {
            if ((GetKeyState(virtualKey) & 0x8000) != 0) parts.Add(name);
        }

        private static KeyValuePair<string, object?> Pair(string name, object? value) =>
            new KeyValuePair<string, object?>(name, value);

        private static string Hex(IntPtr value) => "0x" + unchecked((ulong)value.ToInt64()).ToString("x");

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateWindowExW(int exStyle, string className, string windowName, int style,
            int x, int y, int width, int height, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr parameter);
        [DllImport("user32.dll", SetLastError = true)] private static extern bool DestroyWindow(IntPtr hwnd);
        [DllImport("user32.dll")] private static extern IntPtr SetFocus(IntPtr hwnd);
        [DllImport("user32.dll")] private static extern short GetKeyState(int virtualKey);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowTextLengthW(IntPtr hwnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowTextW(IntPtr hwnd, System.Text.StringBuilder text, int maximum);
        [DllImport("user32.dll")] private static extern IntPtr SendMessageW(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam);
    }
}
