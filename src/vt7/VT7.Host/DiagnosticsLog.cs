using System;
using System.IO;
using System.Text;

namespace VT7.Host
{
    internal static class DiagnosticsLog
    {
        internal static string? Write(ProbeSnapshot snapshot)
        {
            try
            {
                var root = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                var folder = Path.Combine(root, "VT7", "Logs");
                Directory.CreateDirectory(folder);

                var path = Path.Combine(folder, $"proof-{snapshot.CapturedAt:yyyyMMdd-HHmmss}.log");
                WriteTo(snapshot, path);
                return path;
            }
            catch
            {
                return null;
            }
        }

        internal static void WriteTo(ProbeSnapshot snapshot, string path)
        {
            var parent = Path.GetDirectoryName(Path.GetFullPath(path));
            if (!string.IsNullOrEmpty(parent))
            {
                Directory.CreateDirectory(parent);
            }

            var text = new StringBuilder()
                    .AppendLine("VT7 proof-of-life diagnostics")
                    .AppendLine("Captured: " + snapshot.CapturedAt.ToString("O"))
                    .AppendLine("Passed: " + snapshot.Passed)
                    .AppendLine("Summary: " + snapshot.Summary)
                    .AppendLine("Build: " + snapshot.BuildDisplay)
                    .AppendLine("Native: " + snapshot.NativeDisplay)
                    .AppendLine("Platform: " + snapshot.PlatformDisplay)
                    .AppendLine("Runtime: " + snapshot.RuntimeDisplay)
                    .AppendLine("Adapter: " + snapshot.AdapterDisplay)
                    .AppendLine("Hardware: " + snapshot.HardwareDisplay)
                    .AppendLine("WARP: " + snapshot.WarpDisplay)
                    .AppendLine("DXGI 1.2: " + snapshot.DxgiDisplay)
                    .AppendLine("Surface: " + snapshot.SurfaceDisplay)
                    .AppendLine("TerminalCore checks:")
                    .AppendLine(snapshot.CoreTests)
                    .AppendLine("Native path: " + snapshot.NativePath)
                    .AppendLine("Error: " + (snapshot.Error ?? "None"))
                    .ToString();

            File.WriteAllText(path, text, new UTF8Encoding(false));
        }
    }
}
