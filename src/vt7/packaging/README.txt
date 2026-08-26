VT7 proof of life
=================

This is an engineering diagnostic build, not a usable terminal release.

Target system
-------------

- Windows 7 SP1 x64
- Windows 7 Platform Update, KB2670838
- .NET Framework 4.8
- A Direct3D 11 driver, or a system capable of using the Direct3D WARP device

The Visual C++ runtime DLLs required by this build are included beside the
program. No system DLL replacement or global compatibility layer is required.

Test procedure
--------------

1. Extract every file to a normal local folder.
2. Run RUN-DIAGNOSTICS.cmd.
3. Confirm that the script reports a passing result.
4. Keep VT7-diagnostics.log, especially if a probe fails.
5. Run RUN-VT7.cmd and confirm that the VT7 proof window opens.

What this proves
----------------

- The .NET Framework 4.8 WPF host can start.
- The x64 managed host can load the pinned VT7 native ABI.
- Windows version detection works without a post-Windows 7 static import.
- A Windows 7-compatible DXGI factory can be created.
- The Direct3D 11 hardware and WARP device paths can be probed.

It does not yet contain TerminalCore, an HWND terminal surface, text rendering,
local sessions, SSH, tabs, panes, profiles, or settings.

Diagnostics are written locally. This build does not upload telemetry.

License
-------

VT7 is MIT licensed. See LICENSE.txt. The bundled Visual C++ runtime DLLs are
Microsoft components redistributed under the applicable Visual Studio license
terms and are not covered by the VT7 MIT License.
