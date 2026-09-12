using System;
using System.Runtime.InteropServices;
using System.Text;

namespace VT7.Host
{
    internal static class NativeMethods
    {
        internal const uint ExpectedAbiVersion = 7;

        [StructLayout(LayoutKind.Sequential)]
        internal struct SurfaceSettings
        {
            internal uint StructSize, SystemDpi, EffectiveDpi, DpiOverride;
            internal uint FontFamily, FontPoints, FontWeight, Generation;
            internal uint ClientWidth, ClientHeight;
        }

        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern int VT7_GetSurfaceSettings(IntPtr window, ref SurfaceSettings settings);
        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern int VT7_SetSurfaceFont(IntPtr window, uint family, uint points, uint weight, uint diagnosticDpi);

        [StructLayout(LayoutKind.Sequential, Pack = 8)]
        internal struct SurfaceInfo
        {
            internal uint StructSize;
            internal uint Columns;
            internal uint Rows;
            internal uint CellWidth;
            internal uint CellHeight;
            internal uint PaintCount;
            internal uint ResizeCount;
            internal int LastHResult;
            internal uint RendererMode;
            internal uint RequestedFrame;
            internal uint CompletedRequest;
            internal uint HeaderInkPixels;
            internal ulong RasterHash;
            internal uint RequestedRendererMode;
            internal uint DeviceGeneration;
            internal uint DeviceAttempts;
            internal uint RecoveryFailures;
            internal uint FallbackCount;
            internal uint InjectedFailures;
            internal int LastRenderFailure;
            internal uint FrameInkPixels;
            internal uint RasterWidth;
            internal uint RasterHeight;
        }

        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern int VT7_CreateSurface(IntPtr parent, uint rendererMode, out IntPtr window);
        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern int VT7_DestroySurface(IntPtr window);
        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern int VT7_GetSurfaceInfo(IntPtr window, ref SurfaceInfo info);
        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern int VT7_ResetSurface(IntPtr window);
        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern int VT7_InjectSurfaceFailure(IntPtr window, uint fault);
        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true, CharSet = CharSet.Unicode)]
        internal static extern int VT7_SaveSurfaceCapture(IntPtr window, string path);
        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true, CharSet = CharSet.Unicode)]
        internal static extern int VT7_SurfaceRepaintCheck(IntPtr window, uint operation, uint step, [Out] StringBuilder report, uint capacity);
        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true, CharSet = CharSet.Unicode)]
        internal static extern int VT7_RunCoreTests([Out] StringBuilder report, uint reportCharacters);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool RedrawWindow(IntPtr window, IntPtr rectangle, IntPtr region, uint flags);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool IsWindow(IntPtr window);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool IsWindowVisible(IntPtr window);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode, Pack = 8)]
        internal struct BuildInfo
        {
            internal uint StructSize;
            internal uint AbiVersion;
            internal ushort VersionMajor;
            internal ushort VersionMinor;
            internal ushort VersionPatch;
            internal ushort Reserved;

            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            internal string Product;

            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
            internal string Compiler;

            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            internal string Configuration;

            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
            internal string BuildTimestamp;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode, Pack = 8)]
        internal struct PlatformInfo
        {
            internal uint StructSize;
            internal uint MajorVersion;
            internal uint MinorVersion;
            internal uint BuildNumber;
            internal uint ServicePackMajor;
            internal uint ServicePackMinor;
            internal uint ProductType;
            internal uint ArchitectureBits;

            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
            internal string ServicePack;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode, Pack = 8)]
        internal struct GraphicsInfo
        {
            internal uint StructSize;
            internal int FactoryHResult;
            internal int HardwareHResult;
            internal int WarpHResult;
            internal uint HardwareFeatureLevel;
            internal uint WarpFeatureLevel;
            internal uint SupportsDxgi12;
            internal uint AdapterIsSoftware;
            internal ulong DedicatedVideoMemory;

            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            internal string AdapterDescription;
        }

        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern uint VT7_GetAbiVersion();

        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern int VT7_GetBuildInfo(ref BuildInfo info);

        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern int VT7_GetPlatformInfo(ref PlatformInfo info);

        [DllImport("VT7.Native.dll", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        internal static extern int VT7_ProbeGraphics(ref GraphicsInfo info);

        internal static BuildInfo NewBuildInfo()
        {
            return new BuildInfo
            {
                StructSize = checked((uint)Marshal.SizeOf(typeof(BuildInfo))),
                Product = string.Empty,
                Compiler = string.Empty,
                Configuration = string.Empty,
                BuildTimestamp = string.Empty,
            };
        }

        internal static PlatformInfo NewPlatformInfo()
        {
            return new PlatformInfo
            {
                StructSize = checked((uint)Marshal.SizeOf(typeof(PlatformInfo))),
                ServicePack = string.Empty,
            };
        }

        internal static GraphicsInfo NewGraphicsInfo()
        {
            return new GraphicsInfo
            {
                StructSize = checked((uint)Marshal.SizeOf(typeof(GraphicsInfo))),
                AdapterDescription = string.Empty,
            };
        }
    }
}
