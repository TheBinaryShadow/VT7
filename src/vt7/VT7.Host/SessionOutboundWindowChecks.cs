using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Threading;

namespace VT7.Host
{
    internal static class SessionOutboundWindowChecks
    {
        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }

        internal static async Task Run(StringBuilder report)
        {
            await CheckQueueContract(report);
            await CheckNativeBoundary(report);
        }

        private static async Task CheckQueueContract(StringBuilder report)
        {
            var sink = new GatedSink();
            using (var queue = new SessionOutboundQueue(41, sink, 1))
            {
                Require(queue.TryEnqueue(41, SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, new byte[] { 1 })) == SessionEnqueueResult.Accepted,
                    "The first bounded queue item was rejected.");
                await sink.Entered;
                Require(queue.TryEnqueue(40, SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, new byte[] { 9 })) == SessionEnqueueResult.StaleGeneration,
                    "A stale session generation was accepted.");
                Require(queue.TryEnqueue(41, SessionOutboundOperation.Input(SessionOutboundKind.TerminalReply, new byte[] { 2 })) == SessionEnqueueResult.Accepted,
                    "The available bounded queue slot was rejected.");
                Require(queue.TryEnqueue(41, SessionOutboundOperation.Input(SessionOutboundKind.Paste, new byte[] { 3 })) == SessionEnqueueResult.Full,
                    "A full bounded queue accepted another item.");
                sink.Release();
                await queue.CompleteAsync();
                Require(sink.Items.Count == 2 && sink.Items[0].Sequence == 1 && sink.Items[1].Sequence == 2,
                    "Queue order or sequence assignment differs.");
                Require(queue.TryEnqueue(41, SessionOutboundOperation.Focus(true, Array.Empty<byte>())) == SessionEnqueueResult.Closed,
                    "A completed queue accepted new input.");
            }

            var resizeSink = new GatedSink();
            using (var queue = new SessionOutboundQueue(42, resizeSink, 2))
            {
                Require(queue.TryEnqueue(42, SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, new byte[] { 1 })) == SessionEnqueueResult.Accepted,
                    "The resize gate item was rejected.");
                await resizeSink.Entered;
                Require(queue.TryEnqueue(42, SessionOutboundOperation.Resize(80, 24)) == SessionEnqueueResult.Accepted,
                    "The first resize was rejected.");
                Require(queue.TryEnqueue(42, SessionOutboundOperation.Resize(100, 30)) == SessionEnqueueResult.Coalesced,
                    "Consecutive pending resizes were not coalesced.");
                resizeSink.Release();
                await queue.CompleteAsync();
                var resize = resizeSink.Items.Single(item => item.Kind == SessionOutboundKind.Resize);
                Require(resize.Columns == 100 && resize.Rows == 30 && resize.Sequence == 3,
                    "The coalesced resize did not keep the newest grid and sequence.");
            }
            report.AppendLine("PASS: outbound queue rejects stale generations, applies bounded backpressure, drains in order, and coalesces only consecutive pending resizes.");
        }

        private static async Task CheckNativeBoundary(StringBuilder report)
        {
            var window = new MainWindow { Opacity = 0, ShowActivated = false, ShowInTaskbar = false };
            try
            {
                window.Show();
                await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                var surface = window.Viewport ?? throw new InvalidOperationException("The outbound-test viewport was not created.");
                var queue = window.SessionOutbound ?? throw new InvalidOperationException("The outbound session owner was not created.");
                var audit = window.OutboundAudit ?? throw new InvalidOperationException("The outbound audit sink was not created.");

                var before = await AddFence(queue, audit, 0xF0);
                Send(surface, NativeHwndInputAdapter.WmSetFocus, 0, 0);
                Send(surface, NativeHwndInputAdapter.WmKeyDown, 0x41, KeyBits(0x1E));
                Send(surface, NativeHwndInputAdapter.WmChar, '\u010D', KeyBits(0x1E));
                Send(surface, NativeHwndInputAdapter.WmDeadChar, '\u00B4', KeyBits(0x0D));
                Send(surface, NativeHwndInputAdapter.WmChar, '\u0107', KeyBits(0x2E));
                Send(surface, NativeHwndInputAdapter.WmKeyDown, 0x0D, KeyBits(0x1C));
                Send(surface, NativeHwndInputAdapter.WmChar, 13, KeyBits(0x1C));
                Send(surface, NativeHwndInputAdapter.WmKeyUp, 0x0D, KeyBits(0x1C, false, true));

                Send(surface, NativeHwndInputAdapter.WmKeyDown, 0x11, KeyBits(0x1D));
                Send(surface, NativeHwndInputAdapter.WmSysKeyDown, 0x12, KeyBits(0x38, true));
                Send(surface, NativeHwndInputAdapter.WmKeyDown, 0x51, KeyBits(0x10));
                Send(surface, NativeHwndInputAdapter.WmChar, '\\', KeyBits(0x10));
                Send(surface, NativeHwndInputAdapter.WmKeyUp, 0x51, KeyBits(0x10, false, true));
                Send(surface, NativeHwndInputAdapter.WmSysKeyUp, 0x12, KeyBits(0x38, true, true));
                Send(surface, NativeHwndInputAdapter.WmKeyUp, 0x11, KeyBits(0x1D, false, true));

                Send(surface, NativeHwndInputAdapter.WmKeyDown, 0x11, KeyBits(0x1D));
                Send(surface, NativeHwndInputAdapter.WmKeyDown, 0x43, KeyBits(0x2E));
                Send(surface, NativeHwndInputAdapter.WmChar, 3, KeyBits(0x2E));
                Send(surface, NativeHwndInputAdapter.WmKeyUp, 0x43, KeyBits(0x2E, false, true));
                Send(surface, NativeHwndInputAdapter.WmKeyUp, 0x11, KeyBits(0x1D, false, true));

                Send(surface, NativeHwndInputAdapter.WmKeyDown, 0x11, KeyBits(0x1D));
                Send(surface, NativeHwndInputAdapter.WmKeyDown, 0x03, KeyBits(0x46));
                Send(surface, NativeHwndInputAdapter.WmChar, 3, KeyBits(0x46));
                Send(surface, NativeHwndInputAdapter.WmKeyUp, 0x03, KeyBits(0x46, false, true));
                Send(surface, NativeHwndInputAdapter.WmKeyUp, 0x11, KeyBits(0x1D, false, true));

                Send(surface, NativeHwndInputAdapter.WmKeyDown, 0x26, KeyBits(0x48, true));
                Send(surface, NativeHwndInputAdapter.WmKeyUp, 0x26, KeyBits(0x48, true, true));
                Send(surface, NativeHwndInputAdapter.WmKeyDown, 0x10, KeyBits(0x2A));
                Send(surface, NativeHwndInputAdapter.WmKillFocus, 0, 0);
                var after = await AddFence(queue, audit, 0xF1);

                var items = audit.Snapshot().Where(item => item.Sequence > before && item.Sequence < after).ToArray();
                Require(items.Count(item => item.Kind == SessionOutboundKind.Interrupt) == 1,
                    "Ctrl+C was not represented by exactly one interrupt operation.");
                Require(items.Count(item => item.Kind == SessionOutboundKind.Break) == 1,
                    "Ctrl+Break was not represented by exactly one break operation.");
                Require(!items.Any(item => item.Kind == SessionOutboundKind.InputBytes && item.Bytes.SequenceEqual(new byte[] { 3 })),
                    "A correlated WM_CHAR duplicated Ctrl+C or Ctrl+Break ETX.");
                var text = items.Where(item => item.Kind == SessionOutboundKind.InputBytes)
                    .SelectMany(item => item.Bytes).ToArray();
                Require(Contains(text, Encoding.UTF8.GetBytes("č")) && Contains(text, Encoding.UTF8.GetBytes("ć")),
                    "Committed Croatian text did not cross the native character encoder.");
                Require(text.Count(value => value == 13) == 1, "Handled Enter was followed by a duplicate committed CR.");
                Require(text.Count(value => value == (byte)'\\') == 1,
                    "AltGr committed text was duplicated or missing (bytes " + BitConverter.ToString(text) + ").");
                Require(Contains(text, new byte[] { 0x1B, 0x5B, 0x41 }), "The native non-text key path did not encode Up as CSI A.");
                Require(items.Count(item => item.Kind == SessionOutboundKind.Focus) == 2 &&
                    items.First(item => item.Kind == SessionOutboundKind.Focus).Focused &&
                    !items.Last(item => item.Kind == SessionOutboundKind.Focus).Focused,
                    "Focus transitions were not serialized around input.");

                NativeMethods.MoveWindow(surface.Handle, 0, 0, 461, 181, false);
                NativeMethods.MoveWindow(surface.Handle, 0, 0, 518, 217, false);
                var info = surface.ReadInfo();
                Send(surface, NativeHwndInputAdapter.WmAuthoritativeGrid, checked((int)info.Columns), checked((int)info.Rows));
                Send(surface, NativeHwndInputAdapter.WmAuthoritativeGrid, checked((int)info.Columns), checked((int)info.Rows));
                await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                var resizeAfter = await AddFence(queue, audit, 0xF2);
                var resizeItems = audit.Snapshot().Where(item => item.Sequence > after && item.Sequence < resizeAfter &&
                    item.Kind == SessionOutboundKind.Resize).ToArray();
                Require(resizeItems.Length == 1 && resizeItems[0].Columns == info.Columns && resizeItems[0].Rows == info.Rows,
                    $"The HWND resize path did not emit one coalesced authoritative grid (items {resizeItems.Length}, " +
                    $"grids {string.Join(",", resizeItems.Select(item => item.Columns + "x" + item.Rows))}, native {info.Columns}x{info.Rows}).");

                Require(queue.TryEnqueue(queue.Generation + 1, SessionOutboundOperation.Input(SessionOutboundKind.Paste, new byte[] { 9 })) == SessionEnqueueResult.StaleGeneration,
                    "The live HWND queue accepted a stale generation.");
                report.AppendLine("PASS: native HWND commits Croatian UTF-16 once, keeps Ctrl+C and Ctrl+Break distinct without duplicate ETX, encodes non-text keys through TerminalCore, reconciles focus, and emits one authoritative resize grid.");
            }
            finally
            {
                window.Close();
            }
        }

        private static void Send(TerminalSurface surface, uint message, int wParam, int lParam) =>
            NativeMethods.SendMessage(surface.Handle, message, new IntPtr(wParam), new IntPtr(lParam));

        private static int KeyBits(int scan, bool extended = false, bool released = false)
        {
            uint value = 1u | ((uint)scan << 16);
            if (extended) value |= 0x01000000u;
            if (released) value |= 0xC0000000u;
            return unchecked((int)value);
        }

        private static async Task<long> AddFence(SessionOutboundQueue queue, SessionOutboundAuditSink sink, byte value)
        {
            var result = queue.TryEnqueue(queue.Generation,
                SessionOutboundOperation.Input(SessionOutboundKind.TerminalReply, new[] { value }));
            Require(result == SessionEnqueueResult.Accepted, "The outbound fence was rejected.");
            var limit = DateTime.UtcNow.AddSeconds(5);
            while (DateTime.UtcNow < limit)
            {
                var fence = sink.Snapshot().LastOrDefault(item => item.Kind == SessionOutboundKind.TerminalReply &&
                    item.Bytes.Length == 1 && item.Bytes[0] == value);
                if (fence != null) return fence.Sequence;
                await Task.Delay(10);
            }
            throw new TimeoutException("The outbound queue did not reach its test fence.");
        }

        private static bool Contains(byte[] value, byte[] expected)
        {
            for (var offset = 0; offset <= value.Length - expected.Length; ++offset)
            {
                var matches = true;
                for (var index = 0; index < expected.Length; ++index)
                    matches &= value[offset + index] == expected[index];
                if (matches) return true;
            }
            return false;
        }

        private sealed class GatedSink : ISessionOutboundSink
        {
            private readonly TaskCompletionSource<bool> _entered = new TaskCompletionSource<bool>();
            private readonly TaskCompletionSource<bool> _release = new TaskCompletionSource<bool>();
            internal Task Entered => _entered.Task;
            internal List<SessionOutboundOperation> Items { get; } = new List<SessionOutboundOperation>();

            internal void Release() => _release.TrySetResult(true);

            public async Task WriteAsync(SessionOutboundOperation operation, CancellationToken cancellationToken)
            {
                if (Items.Count == 0)
                {
                    _entered.TrySetResult(true);
                    using (cancellationToken.Register(() => _release.TrySetCanceled()))
                        await _release.Task;
                }
                Items.Add(operation);
            }

            public Task CompleteAsync(CancellationToken cancellationToken) => Task.CompletedTask;
        }
    }
}
