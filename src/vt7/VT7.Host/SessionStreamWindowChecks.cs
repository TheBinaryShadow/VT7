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
            }
            finally
            {
                window.Close();
            }
            await System.Windows.Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
            Require(!NativeMethods.IsWindow(handle), "The session-stream child HWND survived host disposal.");
            report.AppendLine("PASS: session owner disposed the native surface with no surviving HWND.");
        }
    }
}
