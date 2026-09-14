using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Windows.Threading;

namespace VT7.Host
{
    internal sealed class TerminalSurface : HwndHost
    {
        private NativeHwndInputAdapter? _input;
        private bool _resizePosted;
        private uint _pendingColumns;
        private uint _pendingRows;
        internal event Action? RecoveryStatusChanged;
        protected override IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == 0x8001)
            {
                RecoveryStatusChanged?.Invoke();
                handled = true;
                return IntPtr.Zero;
            }
            if (msg == NativeHwndInputAdapter.WmAuthoritativeGrid)
            {
                _pendingColumns = unchecked((uint)wParam.ToInt64());
                _pendingRows = unchecked((uint)lParam.ToInt64());
                QueueAuthoritativeResize();
                handled = true;
                return IntPtr.Zero;
            }
            if (_input?.ProcessMessage(msg, wParam, lParam) == true)
            {
                handled = true;
                return IntPtr.Zero;
            }
            return base.WndProc(hwnd, msg, wParam, lParam, ref handled);
        }

        internal void AttachSessionInput(SessionOutboundQueue queue, long generation, Action<string> failure)
        {
            if (_input != null) throw new InvalidOperationException("The terminal input boundary is already attached.");
            _input = new NativeHwndInputAdapter(this, queue, generation, failure);
            QueueAuthoritativeResize();
        }

        internal void DetachSessionInput()
        {
            _input = null;
            _resizePosted = false;
            _pendingColumns = _pendingRows = 0;
        }

        private void QueueAuthoritativeResize()
        {
            if (_resizePosted || _input == null) return;
            _resizePosted = true;
            _ = Dispatcher.BeginInvoke(new Action(() =>
            {
                _resizePosted = false;
                if (_input == null || Handle == IntPtr.Zero) return;
                if (_pendingColumns == 0 || _pendingRows == 0)
                {
                    var info = ReadInfo();
                    _pendingColumns = info.Columns;
                    _pendingRows = info.Rows;
                }
                _input.ObserveAuthoritativeGrid(_pendingColumns, _pendingRows);
                _pendingColumns = _pendingRows = 0;
            }), DispatcherPriority.Background);
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

        internal void BeginStream() =>
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_BeginSurfaceStream(Handle));

        internal void WriteUtf8(byte[] bytes)
        {
            if (bytes == null) throw new ArgumentNullException(nameof(bytes));
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_WriteSurfaceUtf8(Handle, bytes, checked((uint)bytes.Length)));
        }

        internal void EndStream() =>
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_EndSurfaceStream(Handle));

        internal NativeMethods.SurfaceStreamInfo ReadStreamInfo()
        {
            var info = new NativeMethods.SurfaceStreamInfo
            {
                StructSize = (uint)Marshal.SizeOf(typeof(NativeMethods.SurfaceStreamInfo)),
            };
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_GetSurfaceStreamInfo(Handle, ref info));
            return info;
        }

        internal NativeInputEncoding EncodeKey(uint virtualKey, uint scanCode, uint controlKeyState, bool keyDown, uint repeatCount)
        {
            var result = NewInputResult();
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_EncodeSurfaceKey(Handle, virtualKey, scanCode,
                controlKeyState, keyDown ? 1u : 0u, repeatCount, ref result));
            return ReadInputResult(result);
        }

        internal NativeInputEncoding EncodeCharacter(uint character, uint scanCode, uint controlKeyState, uint repeatCount)
        {
            var result = NewInputResult();
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_EncodeSurfaceChar(Handle, character, scanCode,
                controlKeyState, repeatCount, ref result));
            return ReadInputResult(result);
        }

        internal NativeInputEncoding EncodeFocus(bool focused)
        {
            var result = NewInputResult();
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_EncodeSurfaceFocus(Handle, focused ? 1u : 0u, ref result));
            return ReadInputResult(result);
        }

        private static NativeMethods.InputResult NewInputResult() => new NativeMethods.InputResult
        {
            StructSize = checked((uint)Marshal.SizeOf(typeof(NativeMethods.InputResult))),
            Bytes = new byte[256],
        };

        private static NativeInputEncoding ReadInputResult(NativeMethods.InputResult result)
        {
            if (result.ByteCount > result.Bytes.Length) throw new InvalidOperationException("The native input encoder returned an invalid byte count.");
            var bytes = new byte[result.ByteCount];
            Array.Copy(result.Bytes, bytes, bytes.Length);
            return new NativeInputEncoding(result.Handled != 0, bytes);
        }

        internal NativeMethods.SchedulingInfo ReadScheduling()
        {
            var info = new NativeMethods.SchedulingInfo { StructSize = (uint)Marshal.SizeOf(typeof(NativeMethods.SchedulingInfo)) };
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_GetSchedulingInfo(Handle, ref info));
            return info;
        }
        internal void SchedulingCommand(uint operation, uint step = 0) =>
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_SchedulingCommand(Handle, operation, step));

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

    internal readonly struct NativeInputEncoding
    {
        internal NativeInputEncoding(bool handled, byte[] bytes)
        {
            Handled = handled;
            Bytes = bytes;
        }

        internal bool Handled { get; }
        internal byte[] Bytes { get; }
    }
}
