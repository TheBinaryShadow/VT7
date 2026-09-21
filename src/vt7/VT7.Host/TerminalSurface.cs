using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Windows.Input;
using System.Windows.Threading;

namespace VT7.Host
{
    internal sealed class TerminalSurface : HwndHost
    {
        private readonly bool _ownsDocument;
        private IntPtr _view;
        private NativeHwndInputAdapter? _input;
        private bool _resizePosted;
        private uint _pendingColumns;
        private uint _pendingRows;
        internal event Action? RecoveryStatusChanged;

        internal TerminalSurface() : this(new TerminalDocument(), true)
        {
        }

        internal TerminalSurface(TerminalDocument document) : this(document, false)
        {
        }

        private TerminalSurface(TerminalDocument document, bool ownsDocument)
        {
            Document = document ?? throw new ArgumentNullException(nameof(document));
            _ownsDocument = ownsDocument;
            Focusable = true;
            KeyboardNavigation.SetIsTabStop(this, true);
        }

        internal TerminalDocument Document { get; }

        internal bool FocusTerminal()
        {
            var window = Handle;
            if (window == IntPtr.Zero) return false;
            NativeMethods.SetFocus(window);
            return NativeMethods.GetFocus() == window;
        }

        protected override bool TabIntoCore(TraversalRequest request) => FocusTerminal();

        protected override bool TranslateAcceleratorCore(ref MSG msg, ModifierKeys modifiers)
        {
            if (_input == null || Handle == IntPtr.Zero || !IsTerminalAccelerator(msg)) return false;
            NativeMethods.SendMessage(Handle, unchecked((uint)msg.message), msg.wParam, msg.lParam);
            return true;
        }

        protected override bool TranslateCharCore(ref MSG msg, ModifierKeys modifiers)
        {
            if (_input == null || Handle == IntPtr.Zero || !IsTerminalCharacterMessage(msg.message)) return false;
            NativeMethods.SendMessage(Handle, unchecked((uint)msg.message), msg.wParam, msg.lParam);
            return true;
        }

        private static bool IsTerminalAccelerator(MSG msg)
        {
            if (msg.message != NativeHwndInputAdapter.WmKeyDown &&
                msg.message != NativeHwndInputAdapter.WmKeyUp &&
                msg.message != NativeHwndInputAdapter.WmSysKeyDown &&
                msg.message != NativeHwndInputAdapter.WmSysKeyUp) return false;
            var key = unchecked((uint)msg.wParam.ToInt64());
            if (key == 0x03 || key == 0x08 || key == 0x09 || key == 0x0C || key == 0x0D || key == 0x13) return true;
            if (key >= 0x10 && key <= 0x12) return true;
            if (key >= 0x21 && key <= 0x28) return true;
            if (key == 0x2D || key == 0x2E) return true;
            if (key >= 0x60 && key <= 0x6F) return true;
            if (key >= 0x70 && key <= 0x87) return true;
            if (key >= 0xA0 && key <= 0xA5) return true;
            if (key >= 0xAD && key <= 0xB3) return true;
            return false;
        }

        private static bool IsTerminalCharacterMessage(int message) =>
            message == NativeHwndInputAdapter.WmChar || message == NativeHwndInputAdapter.WmDeadChar ||
            message == NativeHwndInputAdapter.WmSysChar || message == NativeHwndInputAdapter.WmSysDeadChar;

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
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_CreateTerminalView(hwndParent.Handle, Document.Handle,
                App.SurfaceOptions, out _view, out var window));
            return new HandleRef(this, window);
        }

        protected override void DestroyWindowCore(HandleRef hwnd)
        {
            if (_view != IntPtr.Zero)
            {
                Marshal.ThrowExceptionForHR(NativeMethods.VT7_DestroyTerminalView(_view));
                _view = IntPtr.Zero;
            }
            if (_ownsDocument) Document.Dispose();
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

        internal ulong BeginStream() => Document.BeginStream();

        internal void WriteUtf8(ulong streamGeneration, ulong originGeneration, ulong sequence, byte[] bytes) =>
            Document.WriteUtf8(streamGeneration, originGeneration, sequence, bytes);

        internal void EndStream(ulong streamGeneration) => Document.EndStream(streamGeneration);

        internal NativeMethods.SurfaceStreamInfo ReadStreamInfo()
        {
            return Document.ReadStreamInfo();
        }

        internal NativeInputEncoding EncodeKey(uint virtualKey, uint scanCode, uint controlKeyState, bool keyDown, uint repeatCount)
        {
            return Document.EncodeKey(virtualKey, scanCode, controlKeyState, keyDown, repeatCount);
        }

        internal NativeInputEncoding EncodeCharacter(uint character, uint scanCode, uint controlKeyState, uint repeatCount)
        {
            return Document.EncodeCharacter(character, scanCode, controlKeyState, repeatCount);
        }

        internal NativeInputEncoding EncodeFocus(bool focused)
        {
            return Document.EncodeFocus(focused);
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
