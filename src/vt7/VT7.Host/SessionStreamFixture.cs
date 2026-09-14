using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal static class SessionStreamFixture
    {
        internal const string Text =
            "\x1b[1;38;2;101;184;255mVT7 session stream foundation\x1b[0m\r\n" +
            "Ordered process bytes now flow into TerminalCore.\r\n\r\n" +
            "Croatian HR Latin: \x1b[38;2;255;196;96mč ć ž š đ Č Ć Ž Š Đ\x1b[0m\r\n" +
            "UTF-8 and VT state survive arbitrary read boundaries.\r\n" +
            "Transport: deterministic fixture; WinPTY is the next adapter.\r\n\r\n" +
            "\x1b[48;5;24m  \x1b[48;5;31m  \x1b[48;5;38m  \x1b[48;5;45m  \x1b[0m  " +
            "\x1b[1mBold\x1b[0m  \x1b[4mUnderline\x1b[0m\r\n";

        internal static byte[] Bytes => Encoding.UTF8.GetBytes(Text);

        internal static IEnumerable<byte[]> Split(byte[] bytes, int[] pattern)
        {
            if (bytes == null) throw new ArgumentNullException(nameof(bytes));
            if (pattern == null || pattern.Length == 0) throw new ArgumentException("A chunk pattern is required.", nameof(pattern));
            var offset = 0;
            var index = 0;
            while (offset < bytes.Length)
            {
                var requested = pattern[index++ % pattern.Length];
                if (requested <= 0) throw new ArgumentOutOfRangeException(nameof(pattern));
                var length = Math.Min(requested, bytes.Length - offset);
                var chunk = new byte[length];
                Buffer.BlockCopy(bytes, offset, chunk, 0, length);
                offset += length;
                yield return chunk;
            }
        }

        internal static async Task StreamAsync(TerminalSurface surface, int[] pattern)
        {
            using (var pump = new SessionOutputPump(surface))
            {
                await Task.Run(async () =>
                {
                    foreach (var chunk in Split(Bytes, pattern))
                        await pump.WriteAsync(chunk);
                    await pump.CompleteAsync();
                });
            }
        }
    }
}
