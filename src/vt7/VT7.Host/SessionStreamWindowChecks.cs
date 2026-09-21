using System;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Threading;

namespace VT7.Host
{
    internal static class SessionStreamWindowChecks
    {
        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }

        internal static async Task Run(StringBuilder report)
        {
            var window = new MainWindow { Opacity = 0, ShowActivated = false, ShowInTaskbar = false };
            IntPtr handle = IntPtr.Zero;
            try
            {
                window.Show();
                await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                var surface = window.Viewport ?? throw new InvalidOperationException("The session-stream viewport was not created.");
                handle = surface.Handle;

                var payload = SessionStreamFixture.Bytes;
                await SessionStreamFixture.StreamAsync(surface, new[] { payload.Length });
                await surface.PaintAndWaitAsync();
                var baseline = surface.ReadInfo();
                var baselineStream = surface.ReadStreamInfo();
                Require(baselineStream.ReceivedBytes == (ulong)payload.Length && baselineStream.WriteCount == 1 &&
                    baselineStream.PendingUtf8Bytes == 0 && baselineStream.Ended == 1 && baselineStream.LastHResult >= 0,
                    "Single-chunk stream counters differ.");
                report.AppendLine($"PASS: single-chunk stream, {baselineStream.ReceivedBytes} bytes, {baselineStream.DecodedUtf16Units} UTF-16 units, raster {baseline.RasterHash:X16}.");

                await SessionStreamFixture.StreamAsync(surface, new[] { 1 });
                await surface.PaintAndWaitAsync();
                var split = surface.ReadInfo();
                var splitStream = surface.ReadStreamInfo();
                Require(splitStream.ReceivedBytes == (ulong)payload.Length && splitStream.WriteCount == (uint)payload.Length &&
                    splitStream.PendingUtf8Bytes == 0 && splitStream.Ended == 1 && splitStream.LastHResult >= 0,
                    "Byte-at-a-time stream counters differ.");
                Require(split.RasterHash == baseline.RasterHash && split.FrameInkPixels == baseline.FrameInkPixels,
                    "Byte-at-a-time streaming changed the rendered frame.");
                report.AppendLine($"PASS: byte-at-a-time UTF-8 and VT stream produced the exact baseline raster across {splitStream.WriteCount} writes.");

                using (var incomplete = new SessionOutputPump(surface))
                {
                    await incomplete.WriteAsync(new byte[] { 0xc4 });
                    try
                    {
                        await incomplete.CompleteAsync();
                        throw new InvalidOperationException("Incomplete UTF-8 EOF was accepted.");
                    }
                    catch (Exception ex) when (ex.HResult == unchecked((int)0x80070459))
                    {
                    }
                }
                var failed = surface.ReadStreamInfo();
                Require(failed.Ended == 1 && failed.PendingUtf8Bytes == 0 && failed.LastHResult == unchecked((int)0x80070459),
                    "Incomplete UTF-8 EOF state differs.");
                report.AppendLine("PASS: incomplete UTF-8 at EOF returned ERROR_NO_UNICODE_TRANSLATION and discarded the partial code point.");

                await SessionStreamFixture.StreamAsync(surface, new[] { 1, 2, 3, 5, 8, 13 });
                await surface.PaintAndWaitAsync();
                var recovered = surface.ReadInfo();
                var recoveredStream = surface.ReadStreamInfo();
                Require(recoveredStream.Generation == failed.Generation + 1 && recoveredStream.LastHResult >= 0 &&
                    recoveredStream.Ended == 1 && recoveredStream.PendingUtf8Bytes == 0,
                    "A new stream generation did not recover after the EOF failure.");
                Require(recovered.RasterHash == baseline.RasterHash && recovered.FrameInkPixels == baseline.FrameInkPixels,
                    "Recovered streaming changed the rendered frame.");
                report.AppendLine($"PASS: generation {recoveredStream.Generation} recovered with irregular chunks and exact raster {recovered.RasterHash:X16}.");

                var document = surface.Document;
                var attachedInfo = document.ReadInfo();
                Require(attachedInfo.Attached == 1 && attachedInfo.AttachmentGeneration != 0,
                    "The ABI 11 document did not report its attached view.");
                var busy = NativeMethods.VT7_DestroyTerminalDocument(document.Handle);
                Require(busy == unchecked((int)0x800700AA),
                    $"Destroying an attached document returned 0x{unchecked((uint)busy):X8}, expected ERROR_BUSY.");

                using (var detachedPump = new SessionOutputPump(document))
                {
                    var splitAt = payload.Length / 3;
                    var prefix = new byte[splitAt];
                    Array.Copy(payload, 0, prefix, 0, prefix.Length);
                    await detachedPump.WriteAsync(prefix);

                    var originalHandle = surface.Handle;
                    document = window.DetachViewportForTest();
                    Require(!NativeMethods.IsWindow(originalHandle), "Detaching the ABI 11 view left its child HWND alive.");
                    var detachedInfo = document.ReadInfo();
                    Require(detachedInfo.Attached == 0 && detachedInfo.ReceivedBytes == (ulong)prefix.Length,
                        "The document did not remain live after view detachment.");

                    var suffix = new byte[payload.Length - splitAt];
                    Array.Copy(payload, splitAt, suffix, 0, suffix.Length);
                    await detachedPump.WriteAsync(suffix);
                    var hiddenInfo = document.ReadInfo();
                    Require(hiddenInfo.Attached == 0 && hiddenInfo.ReceivedBytes == (ulong)payload.Length,
                        "Output did not drain into the detached document.");

                    surface = window.AttachViewportForTest(document);
                    await window.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
                    await detachedPump.CompleteAsync();
                    await surface.PaintAndWaitAsync();
                    var reattached = surface.ReadInfo();
                    var reattachedDocument = document.ReadInfo();
                    Require(reattachedDocument.Attached == 1 &&
                        reattachedDocument.AttachmentGeneration > attachedInfo.AttachmentGeneration,
                        "The replacement view did not advance the attachment generation.");
                    Require(reattached.RasterHash == baseline.RasterHash && reattached.FrameInkPixels == baseline.FrameInkPixels,
                        "Detach, hidden drain and reattach changed the deterministic terminal frame.");
                    handle = surface.Handle;
                    report.AppendLine($"PASS: ABI 11 detached HWND {originalHandle}, drained {hiddenInfo.ReceivedBytes} bytes headlessly, and reattached generation {reattachedDocument.AttachmentGeneration} with exact raster {reattached.RasterHash:X16}.");
                }
            }
            finally
            {
                window.Close();
            }
            await System.Windows.Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
            Require(!NativeMethods.IsWindow(handle), "The session-stream child HWND survived host disposal.");
            report.AppendLine("PASS: session owner disposed the native surface with no surviving HWND.");
            await CheckManagedSessionContract(report);
        }

        private static async Task CheckManagedSessionContract(StringBuilder report)
        {
            var document = new TerminalDocument(false);
            var root = new FakeTerminalTransport("root");
            var overlay = new FakeTerminalTransport("overlay");
            var session = new TerminalSession(document, root);
            try
            {
                await session.StartAsync();
                Require(session.State == TerminalSessionState.RunningRoot && session.Outbound.Generation == 1,
                    "The fake root session did not reach RunningRoot generation 1.");
                await Task.Run(() => root.EmitAsync("root-one\r\n"));
                await Task.Run(() => root.EmitAsync(new byte[] { 0x1B, (byte)'[', (byte)'c' }));
                var rootInput = session.Outbound.TryEnqueue(session.Outbound.Generation,
                    SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, new byte[] { 0x41 }));
                Require(rootInput == SessionEnqueueResult.Accepted, "Root input was not admitted.");
                await WaitForOperations(root, 2);
                Require(Array.Exists(root.Received, item => item.Kind == SessionOutboundKind.TerminalReply && item.Bytes.Length > 0),
                    "The TerminalCore device-attributes reply was not returned to its originating transport.");

                await session.StartOverlayAsync(overlay);
                Require(session.State == TerminalSessionState.RunningOverlay && session.Outbound.Generation == 2,
                    "The fake overlay did not become generation 2.");
                await root.EmitAsync("root-background\r\n");
                await overlay.EmitAsync("overlay\r\n");
                var overlayInput = session.Outbound.TryEnqueue(session.Outbound.Generation,
                    SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, new byte[] { 0x42 }));
                Require(overlayInput == SessionEnqueueResult.Accepted, "Overlay input was not admitted.");
                await WaitForOperations(overlay, 1);

                await session.StopOverlayAsync();
                Require(session.State == TerminalSessionState.RunningRoot && session.Outbound.Generation == 3,
                    "The root transport did not resume under a fresh input generation.");
                await root.EmitAsync("root-two\r\n");
                await session.CloseAsync();
                var info = document.ReadInfo();
                var expected = Encoding.UTF8.GetByteCount("root-one\r\nroot-background\r\noverlay\r\nroot-two\r\n") + 3;
                Require(session.State == TerminalSessionState.Closed && info.ReceivedBytes == (ulong)expected && info.Ended == 1,
                    "The fake root/overlay lifecycle did not drain one continuous document stream.");
                Require(root.Received.Length == 2 && overlay.Received.Length == 1,
                    "Input was not routed exclusively to the active fake transport.");
                report.AppendLine("PASS: TerminalSession switched fake root/overlay input generations 1/2/3, returned TerminalCore replies to their origin, drained both transports into one document stream, and closed exactly once.");
            }
            finally
            {
                session.Dispose();
                document.Dispose();
            }
        }

        private static async Task WaitForOperations(FakeTerminalTransport transport, int count)
        {
            var limit = DateTime.UtcNow.AddSeconds(5);
            while (DateTime.UtcNow < limit)
            {
                if (transport.Received.Length >= count) return;
                await Task.Delay(10);
            }
            throw new TimeoutException("The fake transport did not receive its outbound operation.");
        }
    }
}
