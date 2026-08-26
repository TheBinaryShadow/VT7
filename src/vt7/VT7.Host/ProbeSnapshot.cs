using System;
using System.IO;
using System.Runtime.InteropServices;

namespace VT7.Host
{
    internal sealed class ProbeSnapshot
    {
        internal DateTimeOffset CapturedAt { get; set; } = DateTimeOffset.Now;
        internal bool Passed { get; set; }
        internal string Summary { get; set; } = string.Empty;
        internal string BuildDisplay { get; set; } = "Not available";
        internal string NativeDisplay { get; set; } = "Not loaded";
        internal string PlatformDisplay { get; set; } = "Not detected";
        internal string RuntimeDisplay { get; set; } = RuntimeInformation.FrameworkDescription;
        internal string AdapterDisplay { get; set; } = "Not detected";
        internal string HardwareDisplay { get; set; } = "Not tested";
        internal string WarpDisplay { get; set; } = "Not tested";
        internal string DxgiDisplay { get; set; } = "Not tested";
        internal string NativePath { get; set; } = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "VT7.Native.dll");
        internal string? Error { get; set; }
    }

    internal static class ProbeService
    {
        internal static ProbeSnapshot Capture()
        {
            var snapshot = new ProbeSnapshot();

            try
            {
                var abi = NativeMethods.VT7_GetAbiVersion();

                var build = NativeMethods.NewBuildInfo();
                var buildResult = NativeMethods.VT7_GetBuildInfo(ref build);

                var platform = NativeMethods.NewPlatformInfo();
                var platformResult = NativeMethods.VT7_GetPlatformInfo(ref platform);

                var graphics = NativeMethods.NewGraphicsInfo();
                var graphicsResult = NativeMethods.VT7_ProbeGraphics(ref graphics);

                snapshot.BuildDisplay = buildResult >= 0
                    ? $"{build.Product} {build.VersionMajor}.{build.VersionMinor}.{build.VersionPatch}, {build.Configuration}, {build.BuildTimestamp}"
                    : $"Build query failed: {FormatHResult(buildResult)}";

                snapshot.NativeDisplay =
                    $"ABI {abi}, expected {NativeMethods.ExpectedAbiVersion}; {build.Compiler}; {snapshot.NativePath}";

                var servicePack = string.IsNullOrWhiteSpace(platform.ServicePack)
                    ? string.Empty
                    : $", {platform.ServicePack}";
                snapshot.PlatformDisplay = platformResult >= 0
                    ? $"Windows NT {platform.MajorVersion}.{platform.MinorVersion}.{platform.BuildNumber}{servicePack}, {platform.ArchitectureBits}-bit, product type {platform.ProductType}"
                    : $"Platform query failed: {FormatHResult(platformResult)}";

                var memoryGiB = graphics.DedicatedVideoMemory / 1024d / 1024d / 1024d;
                snapshot.AdapterDisplay =
                    $"{graphics.AdapterDescription}; {memoryGiB:0.00} GiB dedicated; software flag {graphics.AdapterIsSoftware}";
                snapshot.HardwareDisplay =
                    $"{FormatHResult(graphics.HardwareHResult)}, feature level {FormatFeatureLevel(graphics.HardwareFeatureLevel)}";
                snapshot.WarpDisplay =
                    $"{FormatHResult(graphics.WarpHResult)}, feature level {FormatFeatureLevel(graphics.WarpFeatureLevel)}";
                snapshot.DxgiDisplay = graphics.SupportsDxgi12 != 0
                    ? "Available through IDXGIFactory2"
                    : "Not available through IDXGIFactory2";

                snapshot.Passed =
                    abi == NativeMethods.ExpectedAbiVersion &&
                    buildResult >= 0 &&
                    platformResult >= 0 &&
                    graphicsResult >= 0 &&
                    graphics.FactoryHResult >= 0 &&
                    graphics.WarpHResult >= 0;

                snapshot.Summary = snapshot.Passed
                    ? "The managed host loaded the pinned native bridge and completed the Windows-compatible graphics probes."
                    : "One or more required probes failed. Review the results and diagnostic log before proceeding.";
            }
            catch (Exception ex) when (
                ex is DllNotFoundException ||
                ex is BadImageFormatException ||
                ex is EntryPointNotFoundException ||
                ex is TypeLoadException)
            {
                snapshot.Passed = false;
                snapshot.Error = ex.ToString();
                snapshot.Summary = "The native bridge could not be loaded or its ABI did not match the host.";
                snapshot.NativeDisplay = ex.GetType().Name + ": " + ex.Message;
            }
            catch (Exception ex)
            {
                snapshot.Passed = false;
                snapshot.Error = ex.ToString();
                snapshot.Summary = "The proof probe failed unexpectedly. Review the diagnostic log.";
                snapshot.NativeDisplay = ex.GetType().Name + ": " + ex.Message;
            }

            return snapshot;
        }

        private static string FormatHResult(int value)
        {
            var status = value >= 0 ? "OK" : "FAILED";
            return $"{status} (0x{unchecked((uint)value):X8})";
        }

        private static string FormatFeatureLevel(uint value)
        {
            switch (value)
            {
                case 0xB100:
                    return "11.1";
                case 0xB000:
                    return "11.0";
                case 0xA100:
                    return "10.1";
                case 0xA000:
                    return "10.0";
                case 0x9300:
                    return "9.3";
                case 0x9200:
                    return "9.2";
                case 0x9100:
                    return "9.1";
                default:
                    return value == 0 ? "none" : $"0x{value:X4}";
            }
        }
    }
}
