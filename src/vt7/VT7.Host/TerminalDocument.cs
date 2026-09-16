using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Threading;
using System.Collections.Generic;

namespace VT7.Host
{
    // Managed owner for ABI 11's presentation-independent TerminalCore state.
    // All native document mutations are serialized by this dispatcher.
    internal sealed class TerminalDocument : IDisposable
    {
        private IntPtr _handle;
        private long _nextStreamGeneration;

        internal TerminalDocument(bool loadDemonstration = true)
        {
            Dispatcher = Dispatcher.CurrentDispatcher;
            var settings = new NativeMethods.TerminalDocumentSettings
            {
                StructSize = checked((uint)Marshal.SizeOf(typeof(NativeMethods.TerminalDocumentSettings))),
                Columns = 80,
                Rows = 24,
                ScrollbackLines = 500,
                LoadDemonstration = loadDemonstration ? 1u : 0u,
            };
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_CreateTerminalDocument(ref settings, out _handle));
        }

        internal Dispatcher Dispatcher { get; }
        internal IntPtr Handle => _handle != IntPtr.Zero ? _handle : throw new ObjectDisposedException(nameof(TerminalDocument));

        internal ulong BeginStream()
        {
            VerifyAccess();
            var generation = checked((ulong)Interlocked.Increment(ref _nextStreamGeneration));
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_BeginDocumentStream(Handle, generation));
            return generation;
        }

        internal void WriteUtf8(ulong streamGeneration, ulong originGeneration, ulong sequence, byte[] bytes)
        {
            VerifyAccess();
            if (bytes == null) throw new ArgumentNullException(nameof(bytes));
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_WriteDocumentUtf8(Handle, streamGeneration,
                originGeneration, sequence, bytes, checked((uint)bytes.Length)));
        }

        internal void EndStream(ulong streamGeneration, bool abandoned = false)
        {
            VerifyAccess();
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_EndDocumentStream(Handle, streamGeneration, abandoned ? 1u : 0u));
        }

        internal IReadOnlyList<NativeTerminalReply> DrainReplies()
        {
            VerifyAccess();
            var replies = new List<NativeTerminalReply>();
            while (true)
            {
                var value = new NativeMethods.TerminalReply
                {
                    StructSize = checked((uint)Marshal.SizeOf(typeof(NativeMethods.TerminalReply))),
                    Bytes = new byte[4096],
                };
                var result = NativeMethods.VT7_ReadDocumentReply(Handle, ref value);
                if (result == 1) return replies;
                Marshal.ThrowExceptionForHR(result);
                if (value.ByteCount > value.Bytes.Length) throw new InvalidOperationException("The native reply queue returned an invalid byte count.");
                var bytes = new byte[value.ByteCount];
                Array.Copy(value.Bytes, bytes, bytes.Length);
                replies.Add(new NativeTerminalReply(value.OriginTransportGeneration, value.Sequence, bytes));
            }
        }

        internal NativeMethods.TerminalDocumentInfo ReadInfo()
        {
            VerifyAccess();
            var info = new NativeMethods.TerminalDocumentInfo
            {
                StructSize = checked((uint)Marshal.SizeOf(typeof(NativeMethods.TerminalDocumentInfo))),
            };
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_GetTerminalDocumentInfo(Handle, ref info));
            return info;
        }

        internal NativeMethods.SurfaceStreamInfo ReadStreamInfo()
        {
            var document = ReadInfo();
            return new NativeMethods.SurfaceStreamInfo
            {
                StructSize = checked((uint)Marshal.SizeOf(typeof(NativeMethods.SurfaceStreamInfo))),
                Generation = checked((uint)document.StreamGeneration),
                ReceivedBytes = document.ReceivedBytes,
                DecodedUtf16Units = document.DecodedUtf16Units,
                WriteCount = document.WriteCount,
                PendingUtf8Bytes = document.PendingUtf8Bytes,
                Ended = document.Ended,
                LastHResult = document.LastHResult,
            };
        }

        internal NativeInputEncoding EncodeKey(uint virtualKey, uint scanCode, uint controlKeyState, bool keyDown, uint repeatCount)
        {
            VerifyAccess();
            var result = NewInputResult();
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_EncodeTerminalKey(Handle, virtualKey, scanCode,
                controlKeyState, keyDown ? 1u : 0u, repeatCount, ref result));
            return ReadInputResult(result);
        }

        internal NativeInputEncoding EncodeCharacter(uint character, uint scanCode, uint controlKeyState, uint repeatCount)
        {
            VerifyAccess();
            var result = NewInputResult();
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_EncodeTerminalChar(Handle, character, scanCode,
                controlKeyState, repeatCount, ref result));
            return ReadInputResult(result);
        }

        internal NativeInputEncoding EncodeFocus(bool focused)
        {
            VerifyAccess();
            var result = NewInputResult();
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_EncodeTerminalFocus(Handle, focused ? 1u : 0u, ref result));
            return ReadInputResult(result);
        }

        private void VerifyAccess()
        {
            if (!Dispatcher.CheckAccess()) throw new InvalidOperationException("TerminalDocument calls belong to its dispatcher.");
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

        public void Dispose()
        {
            VerifyAccess();
            if (_handle == IntPtr.Zero) return;
            Marshal.ThrowExceptionForHR(NativeMethods.VT7_DestroyTerminalDocument(_handle));
            _handle = IntPtr.Zero;
        }
    }

    internal readonly struct NativeTerminalReply
    {
        internal NativeTerminalReply(ulong originGeneration, ulong sequence, byte[] bytes)
        {
            OriginGeneration = originGeneration;
            Sequence = sequence;
            Bytes = bytes;
        }
        internal ulong OriginGeneration { get; }
        internal ulong Sequence { get; }
        internal byte[] Bytes { get; }
    }
}
