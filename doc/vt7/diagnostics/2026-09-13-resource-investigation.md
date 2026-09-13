# Native resource investigation: reproducible documentation snapshot

Recorded: 2026-09-13. This appendix preserves diagnostic material that previously
existed only under ignored `artifacts/` paths. It is source and evidence
documentation, not a new executable, a production component or a new test run.
See the [handoff](../HANDOFF.md) and
[full findings](../validation/2026-09-13-atlas-stability.md) before using it.

## What is preserved and what is not

The code, ABI header and launcher below are copies of the native resource
comparison 0.1 payload. The target log blocks preserve all lines of the three
supplied Windows 7 reports. Text in Markdown is normalized to LF; original-file
hashes identify the retained files, not these normalized blocks.

Original payload SHA256:

- `raw-atlas.cpp`: `F6545200AAECE1AC1161319B28AD8BB08C0C38F4000A5BE18C84CBC095E9C464`.
- `vt7_native.h`: `69CC765000A0575F85586E2FCA8958ABBF9C1CD694901449078F54E4E487C802`.
- Native control executable: `F95C0183979B49488C19BE22C67419A88F9521B2FCCA66B4A02CD117F4C2DD1C`.
- Issued native DLL: `0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49`.
- Complete comparison ZIP: `16A058CE3AA41D9D6829F1ACC357CE0CD4CC9128DE04F12D2F8914B16198118D`.

These snapshots are not added to `VT7.sln`; the application build does not compile
Markdown. A future diagnostic should become an explicitly reviewed source/test
component if retained long term. A new binary has a new hash and compile time,
even if reconstructed from this text. Never substitute it for the issued artifact
when describing historical results.

The original native DLL, MSVC runtime DLLs, fonts, full renderer/core sources,
local PDBs, screenshots and full CDB trace are not embedded here. The DLL source
lives in the repository, but reproducing its historical bytes requires the
matching source/toolchain/build inputs or the exact issued package. Historical
visible logs that were overwritten cannot be recreated from summary counts.

## Reconstructing the native control

Use a fresh, separate reconstruction checkout, not the working checkout holding
the retained evidence. The exact command below uses fixed source/object/output
paths and does not prevent overwriting them. Before saving or compiling, verify
that `artifacts/vt7/diagnostics/raw-atlas.cpp`, `raw-atlas.obj` in that same
directory, and `artifacts/vt7/diagnostics/raw-atlas/VT7.Host.exe` are all absent.
If any exists, stop and choose another reconstruction checkout. Do not overwrite
an issued package or copy this executable over the real WPF `VT7.Host.exe`.

1. Save the source block as `artifacts/vt7/diagnostics/raw-atlas.cpp`, retaining
   its relative include. Save the matching header in a separate reconstruction
   checkout's `src/vt7/VT7.Native/include/vt7_native.h`, or verify that checkout's
   header matches the archived ABI 8 snapshot. Do not overwrite an actively
   edited header to reconstruct history.
2. Use the pinned Visual Studio 2022 MSVC 14.44.35207 x64 toolchain and SDK
   documented in [BUILDING.md](../../../BUILDING.md). Create the output folder
   `artifacts/vt7/diagnostics/raw-atlas` first.
3. From a configured x64 Native Tools command prompt at the repository root:

```text
cl /nologo /EHsc /std:c++20 /MT /D_WIN32_WINNT=0x0601 /Fe:artifacts\vt7\diagnostics\raw-atlas\VT7.Host.exe /Fo:artifacts\vt7\diagnostics\raw-atlas.obj artifacts\vt7\diagnostics\raw-atlas.cpp user32.lib ole32.lib psapi.lib
```

The issued control used the release static CRT (the explicit `/MT` documents
that choice). Do not treat static PE/import verification as Windows 7 execution.

For a paired reproduction, assemble a fresh directory containing the control,
the exact issued 0.3.5 `VT7.Native.dll`, three MSVC runtime DLLs, the complete
`fonts/` and `licenses/` directories, `LICENSE.txt`, `NOTICE.md`,
`CORE-PROVENANCE.md` and `RENDERER-PROVENANCE.md`. Preserve the copied legal
terms and verify payload hashes against the issued manifest. If those exact
bytes are unavailable, label the reconstructed candidate accordingly and do
not claim it reproduces the issued package identity. The native control needs
no WPF/.NET host but does require the native Windows 7 prerequisites.

Save the launcher below beside those files. It runs power then plain, with two
warm-up plus 100 measured surface lifetimes in each fresh process. It creates a
fresh Logs subdirectory and validates markers, counts and process exits.
It defines no resource-growth acceptance budget. Exit 0 means measurements
completed. Keep partial logs after a failure or interruption.

This is a reproduction recipe, not a request to rerun the completed comparison.
The next proposed recreate/reuse control is described in the handoff and is not
implemented by these snapshots.

## Archived raw-atlas.cpp

```cpp
// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license. Standalone diagnostic, not the VT7 WPF host.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <objbase.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <cstdio>
#include <map>
#include <string>
#include "../../../src/vt7/VT7.Native/include/vt7_native.h"

static DWORD powerEvents = 0;
LRESULT CALLBACK rawWindowProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam)
{
    if (message == WM_POWERBROADCAST && wparam == PBT_POWERSETTINGCHANGE) { ++powerEvents; return TRUE; }
    return DefWindowProcW(window, message, wparam, lparam);
}

void check(HRESULT hr) { if (FAILED(hr)) { printf("FAIL %08x\n", unsigned(hr)); fflush(stdout); ExitProcess(1); } }
void pump(DWORD milliseconds = 0)
{
    auto start = GetTickCount64();
    do { MSG msg; while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessageW(&msg); } Sleep(1); }
    while (GetTickCount64() - start < milliseconds);
}
void resources(int cycle)
{
    PROCESS_MEMORY_COUNTERS_EX memory{}; memory.cb = sizeof(memory);
    if (!GetProcessMemoryInfo(GetCurrentProcess(), reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory), sizeof(memory))) check(E_FAIL);
    DWORD handles = 0; if (!GetProcessHandleCount(GetCurrentProcess(), &handles)) check(E_FAIL);
    printf("RESOURCE %d private=%zu handles=%lu GDI=%lu USER=%lu\n", cycle, memory.PrivateUsage, handles,
        GetGuiResources(GetCurrentProcess(), 0), GetGuiResources(GetCurrentProcess(), 1));
    using Query = LONG(NTAPI*)(HANDLE, ULONG, PVOID, ULONG, PULONG);
    auto query = reinterpret_cast<Query>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtQueryInformationThread"));
    std::map<std::wstring, int> threads;
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    THREADENTRY32 entry{ sizeof(entry) };
    if (snapshot != INVALID_HANDLE_VALUE && Thread32First(snapshot, &entry)) do
    {
        if (entry.th32OwnerProcessID != GetCurrentProcessId()) continue;
        std::wstring name = L"unknown";
        HANDLE thread = OpenThread(THREAD_QUERY_INFORMATION, FALSE, entry.th32ThreadID);
        void* address{}; HMODULE module{};
        if (thread && query && query(thread, 9, &address, sizeof(address), nullptr) >= 0 &&
            GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                reinterpret_cast<LPCWSTR>(address), &module))
        {
            wchar_t path[MAX_PATH]{}; GetModuleFileNameW(module, path, MAX_PATH);
            name = path; name = name.substr(name.find_last_of(L"\\/") + 1);
            wchar_t offset[32]; swprintf_s(offset, L"+%zx", reinterpret_cast<size_t>(address) - reinterpret_cast<size_t>(module));
            name += offset;
        }
        GUITHREADINFO gui{ sizeof(gui) };
        if (thread && GetProcessIdOfThread(thread) == GetCurrentProcessId() && GetGUIThreadInfo(entry.th32ThreadID, &gui))
            name += L"/input-queue";
        if (thread) CloseHandle(thread);
        ++threads[name];
    } while (Thread32Next(snapshot, &entry));
    if (snapshot != INVALID_HANDLE_VALUE) CloseHandle(snapshot);
    for (const auto& item : threads) printf("  THREAD %ls count=%d\n", item.first.c_str(), item.second);
    fflush(stdout);
}
int wmain(int argc, wchar_t** argv)
{
    if (argc < 2 || argc > 4) return 2;
    check(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED));
    auto module = LoadLibraryW(argv[1]); if (!module) return 3;
    auto create = reinterpret_cast<decltype(&VT7_CreateSurface)>(GetProcAddress(module, "VT7_CreateSurface"));
    auto destroy = reinterpret_cast<decltype(&VT7_DestroySurface)>(GetProcAddress(module, "VT7_DestroySurface"));
    auto info = reinterpret_cast<decltype(&VT7_GetSurfaceInfo)>(GetProcAddress(module, "VT7_GetSurfaceInfo"));
    auto command = reinterpret_cast<decltype(&VT7_SchedulingCommand)>(GetProcAddress(module, "VT7_SchedulingCommand"));
    auto probe = reinterpret_cast<decltype(&VT7_ProbeGraphics)>(GetProcAddress(module, "VT7_ProbeGraphics"));
    auto abi = reinterpret_cast<decltype(&VT7_GetAbiVersion)>(GetProcAddress(module, "VT7_GetAbiVersion"));
    auto build = reinterpret_cast<decltype(&VT7_GetBuildInfo)>(GetProcAddress(module, "VT7_GetBuildInfo"));
    auto platform = reinterpret_cast<decltype(&VT7_GetPlatformInfo)>(GetProcAddress(module, "VT7_GetPlatformInfo"));
    auto mode = argc > 2 ? _wtoi(argv[2]) : 2;
    if (mode != 1 && mode != 2) return 2;
    const auto withProbe = argc > 3 && wcscmp(argv[3], L"probes") == 0;
    const auto withPower = argc > 3 && wcscmp(argv[3], L"power") == 0;
    if (argc > 3 && !withProbe && !withPower) return 2;
    if (!create || !destroy || !info || !command || !probe || !abi || !build || !platform) return 4;
    if (abi() != VT7_NATIVE_ABI_VERSION) return 4;
    VT7_BUILD_INFO buildInfo{ sizeof(buildInfo) }; check(build(&buildInfo));
    VT7_PLATFORM_INFO platformInfo{ sizeof(platformInfo) }; check(platform(&platformInfo));
    printf("VT7 NATIVE RESOURCE COMPARISON 0.1; compiled %s %s\n", __DATE__, __TIME__);
    printf("NATIVE %u.%u.%u ABI=%u %ls %ls\n", buildInfo.version_major, buildInfo.version_minor, buildInfo.version_patch,
        buildInfo.abi_version, buildInfo.configuration, buildInfo.build_timestamp);
    printf("OS %u.%u.%u SP=%u.%u bits=%u\n", platformInfo.major_version, platformInfo.minor_version,
        platformInfo.build_number, platformInfo.service_pack_major, platformInfo.service_pack_minor, platformInfo.architecture_bits);
    WNDCLASSW wc{}; wc.hInstance = GetModuleHandleW(nullptr); wc.lpfnWndProc = rawWindowProc; wc.lpszClassName = L"VT7RawLifetime";
    RegisterClassW(&wc);
    auto parent = CreateWindowExW(WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TRANSPARENT,
        wc.lpszClassName, L"Diagnostic", WS_POPUP, 0, 0, 1000, 800, nullptr, nullptr, wc.hInstance, nullptr);
    if (!parent || !SetLayeredWindowAttributes(parent, 0, 0, LWA_ALPHA)) return 5;
    ShowWindow(parent, SW_SHOWNOACTIVATE);
    const GUID monitorPowerOn{ 0x02731015, 0x4510, 0x4526, { 0x99, 0xe6, 0xe5, 0xa1, 0x7e, 0xbd, 0x1a, 0xea } };
    DWORD registrations = 0, unregistrations = 0;
    printf("RAW ATLAS mode=%d probes=%d power=%d; one persistent native parent, 2 warm-up + 100 surfaces\n", mode, withProbe, withPower);
    resources(-2);
    for (int cycle = -2; cycle < 100; ++cycle)
    {
        if (withProbe) { VT7_GRAPHICS_INFO graphics{ sizeof(graphics) }; check(probe(&graphics)); }
        HPOWERNOTIFY notification{};
        if (withPower)
        {
            notification = RegisterPowerSettingNotification(parent, &monitorPowerOn, DEVICE_NOTIFY_WINDOW_HANDLE);
            if (!notification) check(HRESULT_FROM_WIN32(GetLastError()));
            if (!notification) return 6;
            ++registrations;
        }
        void* surface{}; check(create(parent, mode | 0x100, &surface)); auto hwnd = static_cast<HWND>(surface);
        auto waitFrame = [&] {
            if (!RedrawWindow(hwnd, nullptr, nullptr, RDW_INVALIDATE | RDW_UPDATENOW)) check(E_FAIL);
            auto start = GetTickCount64();
            for (;;) {
                VT7_SURFACE_INFO state{ sizeof(state) }; check(info(surface, &state)); check(state.last_hresult);
                if (state.paint_count && state.completed_request >= state.requested_frame) break;
                if (GetTickCount64() - start > 3000) check(E_PENDING);
                pump();
            }
        };
        check(command(surface, 0, 0)); waitFrame();
        for (int step = 0; step < 10; ++step)
        {
            if (!SetWindowPos(hwnd, nullptr, 0, 0, 700 + step % 5 * 40, 500 + step % 3 * 30, SWP_NOZORDER | SWP_NOACTIVATE)) check(E_FAIL);
            check(command(surface, 3, step)); waitFrame(); check(command(surface, 4, step));
            if (step % 2 == 0) { ShowWindow(hwnd, SW_HIDE); pump(); ShowWindow(hwnd, SW_SHOWNOACTIVATE); waitFrame(); }
        }
        check(destroy(surface));
        if (IsWindow(hwnd)) check(E_FAIL);
        if (notification)
        {
            if (!UnregisterPowerSettingNotification(notification)) return 7;
            ++unregistrations;
        }
        pump(20);
        if (cycle == -1 || (cycle >= 0 && (cycle + 1) % 25 == 0)) { pump(250); resources(cycle + 1); }
    }
    pump(10000); resources(110);
    printf("POWER registrations=%lu unregistrations=%lu delivered=%lu\n", registrations, unregistrations, powerEvents);
    if (!DestroyWindow(parent)) return 8;
    CoUninitialize();
    printf("COMPLETED: measurement only, not stability acceptance. No soak performed.\n");
    return 0;
}
```

## Archived ABI 8 header

This is a diagnostic dependency snapshot, not a second authoritative ABI header
to edit. Product changes belong in the real native header, exports and managed
declarations together.

```cpp
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

    enum : uint32_t
    {
        VT7_NATIVE_ABI_VERSION = 8,
        VT7_TEXT_SHORT = 32,
        VT7_TEXT_MEDIUM = 64,
        VT7_TEXT_LONG = 128,
    };

#pragma pack(push, 8)

    typedef struct VT7_BUILD_INFO
    {
        uint32_t struct_size;
        uint32_t abi_version;
        uint16_t version_major;
        uint16_t version_minor;
        uint16_t version_patch;
        uint16_t reserved;
        wchar_t product[VT7_TEXT_SHORT];
        wchar_t compiler[VT7_TEXT_MEDIUM];
        wchar_t configuration[VT7_TEXT_SHORT];
        wchar_t build_timestamp[VT7_TEXT_MEDIUM];
    } VT7_BUILD_INFO;

    typedef struct VT7_PLATFORM_INFO
    {
        uint32_t struct_size;
        uint32_t major_version;
        uint32_t minor_version;
        uint32_t build_number;
        uint32_t service_pack_major;
        uint32_t service_pack_minor;
        uint32_t product_type;
        uint32_t architecture_bits;
        wchar_t service_pack[VT7_TEXT_MEDIUM];
    } VT7_PLATFORM_INFO;

    typedef struct VT7_GRAPHICS_INFO
    {
        uint32_t struct_size;
        int32_t factory_hresult;
        int32_t hardware_hresult;
        int32_t warp_hresult;
        uint32_t hardware_feature_level;
        uint32_t warp_feature_level;
        uint32_t supports_dxgi_1_2;
        uint32_t adapter_is_software;
        uint64_t dedicated_video_memory;
        wchar_t adapter_description[VT7_TEXT_LONG];
    } VT7_GRAPHICS_INFO;

#pragma pack(pop)

    typedef struct VT7_SURFACE_INFO
    {
        uint32_t struct_size;
        uint32_t columns;
        uint32_t rows;
        uint32_t cell_width;
        uint32_t cell_height;
        uint32_t paint_count;
        uint32_t resize_count;
        int32_t last_hresult;
        uint32_t renderer_mode; // Last completed backend: 0 GDI; 1/2 D3D; 3/4 D2D; 6 no completed Atlas frame.
        uint32_t requested_frame;
        uint32_t completed_request;
        uint32_t header_ink_pixels; // First-row diagnostic readback, not a general blank-frame test.
        uint64_t raster_hash;
        uint32_t requested_renderer_mode; // 5 is automatic D3D hardware -> WARP.
        uint32_t device_generation;
        uint32_t device_attempts;
        uint32_t recovery_failures;
        uint32_t fallback_count;
        uint32_t injected_failures;
        int32_t last_render_failure; // Historical transient HRESULT, not fatal status.
        uint32_t frame_ink_pixels; // Pixels differing from the first pixel, entire diagnostic frame.
        uint32_t raster_width;
        uint32_t raster_height;
    } VT7_SURFACE_INFO;

    typedef struct VT7_SURFACE_SETTINGS
    {
        uint32_t struct_size;
        uint32_t system_dpi;
        uint32_t effective_dpi;
        uint32_t dpi_override; // Diagnostic-only renderer DPI. Zero uses real system DPI.
        uint32_t font_family; // Proof boundary: 1 Consolas, 2 Courier New.
        uint32_t font_points;
        uint32_t font_weight;
        uint32_t generation;
        uint32_t client_width;
        uint32_t client_height;
    } VT7_SURFACE_SETTINGS;

    int32_t __cdecl VT7_GetSurfaceSettings(void* window, VT7_SURFACE_SETTINGS* settings);
    typedef struct VT7_SCHEDULING_INFO
    {
        uint32_t struct_size, waits, frames, sync_waits, sync_timeouts;
        uint32_t waiting, synchronizing, sync_mode, timer_fires, thread_starts;
    } VT7_SCHEDULING_INFO;
    int32_t __cdecl VT7_GetSchedulingInfo(void* window, VT7_SCHEDULING_INFO* info);
    // Diagnostic/capture-only commands: 0 fixture, 1 sync begin+edit, 2 end,
    // 3 edit+concurrent wake burst, 4 verify authored marker, 5 split sync begin,
    // 6 arm one-shot timer, 7 cancel it. step is delay in ms for operation 6.
    int32_t __cdecl VT7_SchedulingCommand(void* window, uint32_t operation, uint32_t step);
    int32_t __cdecl VT7_SetSurfaceFont(void* window, uint32_t family, uint32_t points, uint32_t weight, uint32_t diagnostic_dpi);

    // HWND values are opaque at the ABI boundary. Calls belong to the creating UI thread.
    int32_t __cdecl VT7_CreateSurface(void* parent, uint32_t renderer_mode, void** window);
    int32_t __cdecl VT7_DestroySurface(void* window);
    int32_t __cdecl VT7_GetSurfaceInfo(void* window, VT7_SURFACE_INFO* info);
    int32_t __cdecl VT7_ResetSurface(void* window);
    int32_t __cdecl VT7_SaveSurfaceCapture(void* window, const wchar_t* path);
    // Diagnostic sequence: apply(0), retain(1), full redraw(2), compare(3).
    // Operation 4 retains an intentionally altered CPU reference for negative tests.
    // Operation 5 compares sampled core state only, for cross-device recovery.
    // Operations 6/7 initialize/check the nonblank settings/reflow fixture.
    // Operation 8 retains the current settings frame; follow with 2/3, step zero.
    int32_t __cdecl VT7_SurfaceRepaintCheck(void* window, uint32_t operation, uint32_t step, wchar_t* report, uint32_t capacity);
    int32_t __cdecl VT7_RunCoreTests(wchar_t* report, uint32_t report_characters);
    // Capture-only fault seam. 1/2 finite Present removals, 3 persistent removals.
    int32_t __cdecl VT7_InjectSurfaceFailure(void* window, uint32_t fault);

    uint32_t __cdecl VT7_GetAbiVersion(void);
    int32_t __cdecl VT7_GetBuildInfo(VT7_BUILD_INFO* info);
    int32_t __cdecl VT7_GetPlatformInfo(VT7_PLATFORM_INFO* info);
    int32_t __cdecl VT7_ProbeGraphics(VT7_GRAPHICS_INFO* info);

#ifdef __cplusplus
}
#endif
```

## Archived RUN-RESOURCE-COMPARISON.cmd

```bat
@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
set "vt7_exit=1"
for %%F in (VT7.Host.exe VT7.Native.dll msvcp140.dll vcruntime140.dll vcruntime140_1.dll fonts\unifont-17.0.05.otf fonts\unifont_upper-17.0.05.otf) do if not exist "%%F" goto :missing
if not exist "Logs\" mkdir "Logs"
if not exist "Logs\" goto :log_error
:new_logs
set "vt7_run=%~dp0Logs\resource-comparison-%RANDOM%-%RANDOM%"
if exist "%vt7_run%" goto :new_logs
mkdir "%vt7_run%"
if not exist "%vt7_run%\" goto :log_error
set "vt7_summary=%vt7_run%\summary.txt"
>"%vt7_summary%" echo VT7 native resource comparison 0.1
>>"%vt7_summary%" echo Power first, then plain. Renderer 2: Atlas Direct3D11 WARP.
>>"%vt7_summary%" echo Exit 0 means measurements completed, not resource-growth acceptance.
echo Native WARP comparison: two warm-up plus 100 surfaces per mode.
echo Power runs first, then plain. Each mode includes a final 10-second sample.
echo Completion does not mean resource-growth acceptance.
echo Logs: "%vt7_run%"
set "vt7_exit=0"
call :test power 1 102
call :test plain 0 0
>>"%vt7_summary%" echo Launcher exit: %vt7_exit%
echo.
if "%vt7_exit%"=="0" (echo Both measurements completed. Resource growth still requires review.) else echo One or both measurements are incomplete. Retain all logs.
echo Return this entire folder: "%vt7_run%"
pause
exit /b %vt7_exit%

:test
set "vt7_log=%vt7_run%\%~1.log"
set "vt7_reason="
echo Running %~1...
if "%~1"=="power" (
    "VT7.Host.exe" "%~dp0VT7.Native.dll" 2 power >"%vt7_log%" 2>&1
) else (
    "VT7.Host.exe" "%~dp0VT7.Native.dll" 2 >"%vt7_log%" 2>&1
)
set "vt7_process_exit=%errorlevel%"
>>"%vt7_log%" echo LAUNCHER process_exit=%vt7_process_exit%
if not "%vt7_process_exit%"=="0" (
    set "vt7_reason=process exit was nonzero"
    goto :test_failed
)
findstr /l /b /c:"FAIL " "%vt7_log%" >nul
if not errorlevel 1 (
    set "vt7_reason=control reported a failure"
    goto :test_failed
)
findstr /l /b /c:"RAW ATLAS mode=2 probes=0 power=%~2;" "%vt7_log%" >nul
if errorlevel 1 (
    set "vt7_reason=missing workload identifier"
    goto :test_failed
)
findstr /l /b /c:"VT7 NATIVE RESOURCE COMPARISON 0.1;" "%vt7_log%" >nul
if errorlevel 1 (
    set "vt7_reason=missing package identity"
    goto :test_failed
)
findstr /l /b /c:"NATIVE 0.3.5 ABI=8 Release " "%vt7_log%" >nul
if errorlevel 1 (
    set "vt7_reason=missing issued native identity"
    goto :test_failed
)
for %%C in (-2 0 25 50 75 100 110) do (
    findstr /l /b /c:"RESOURCE %%C private=" "%vt7_log%" >nul
    if errorlevel 1 (
        set "vt7_reason=missing resource checkpoint %%C"
        goto :test_failed
    )
)
findstr /l /b /c:"POWER registrations=%~3 unregistrations=%~3 delivered=" "%vt7_log%" >nul
if errorlevel 1 (
    set "vt7_reason=missing or mismatched registration totals"
    goto :test_failed
)
findstr /l /x /c:"COMPLETED: measurement only, not stability acceptance. No soak performed." "%vt7_log%" >nul
if errorlevel 1 (
    set "vt7_reason=missing final completion marker"
    goto :test_failed
)
>>"%vt7_log%" echo LAUNCHER measurement_completed=YES; resource_growth_acceptance=NOT_EVALUATED
>>"%vt7_summary%" echo %~1: measurement completed; process exit %vt7_process_exit%; growth not evaluated.
echo %~1 measurement completed. Growth not evaluated.
exit /b 0

:test_failed
set "vt7_exit=1"
>>"%vt7_log%" echo LAUNCHER measurement_completed=NO; reason=%vt7_reason%
>>"%vt7_summary%" echo %~1: INCOMPLETE; process exit %vt7_process_exit%; %vt7_reason%.
echo %~1 INCOMPLETE: %vt7_reason%.
exit /b 0

:missing
echo Required package files are missing. Extract the entire archive together.
pause
exit /b 1

:log_error
echo Could not create the log folder. Extract to a writable local folder.
pause
exit /b 1
```

## Process-only handle tracing recipe, Windows 10 evidence

The completed local trace used installed x64 CDB 10.0.26100.7705, the Debug
0.3.5 WPF host with source-only `native-child` isolation, matching native PDBs,
and public Microsoft symbols. This is not a Windows 7 allocation trace.
No global debugger registration, persistent GFlags setting, security exclusion
or unrelated-process attachment is part of this recipe. Symbol retrieval may
use the network; no symbols were downloaded during this documentation update.

Save the following as a debugger command file in a fresh diagnostic folder.
The correct debugger module alias is `VT7_Native`, not `VT7.Native`.
The first failed trace used the wrong alias and is not allocation evidence.

```text
.symopt+ 0x100
!htrace -enable 0x10000
r @$t0 = 0
bu VT7_Native!VT7_CreateSurface "r @$t0 = @$t0 + 1; .if (@$t0 == 3) { .echo VT7_TRACE_BASELINE_THIRD_PARENT_ALREADY_CREATED; !handle 0 f IoCompletion; !htrace -snapshot; }; .if (@$t0 == 28) { .echo VT7_TRACE_AFTER_25_CYCLES_NEXT_PARENT_ALREADY_CREATED; !handle 0 f IoCompletion; !htrace -diff; }; gc"
bu ntdll!RtlExitUserProcess ".echo VT7_TRACE_AT_PROCESS_EXIT; !handle 0 f IoCompletion; !htrace -diff; lm; !htrace -disable; g"
g
```

A configured PowerShell invocation has this form; set the three diagnostic
paths to new absolute paths and preserve old output first. A directory for
symbols can be reused, but it is not provided by Git:

```powershell
$vt7DebugHost = (Resolve-Path '.\artifacts\vt7\bin\Debug\VT7.Host.exe').Path
$vt7TraceCommands = '<absolute path to the debugger command file>'
$vt7TraceLog = '<new absolute trace log path>'
$vt7DiagnosticLog = '<new absolute isolation report path>'
$vt7Symbols = '<absolute matching PDB folder>;srv*<absolute symbol cache>*https://msdl.microsoft.com/download/symbols'
& 'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe' -G -y $vt7Symbols -logo $vt7TraceLog -cf $vt7TraceCommands $vt7DebugHost --stability-test --renderer atlas-d3d-warp --resource-isolation native-child --diagnostics-output $vt7DiagnosticLog
```

Do not add `-g` to skip the initial breakpoint at which these commands are
installed. Verify the actual module alias and matching symbols before trusting
a run. Breakpoints intentionally sample on the third and 28th surface creations,
after the next parent has already been created. They represent the recorded
baseline and completed 25-cycle interval, not arbitrary closed-state samples.

The successful run had nine current IoCompletion handles at baseline and 21
after 25 cycles; all 12 new values had matching outstanding OPEN histories in
the complete interval. Eleven stacks used Windows power-notification delivery;
one used WindowsBase/USER32 message posting. There were 28 current handles at
exit, but the final trace history had wrapped. No complete final allocation
history is claimed. Handle numeric reuse does not prove continuous lifetime.
Tracing changes timing and can change module loading. The workload still failed
its resource budgets, then tracing was disabled and both processes exited.

If a debugger is left paused or the workload hangs, preserve partial evidence
and end only that test/debugger pair after verifying their identities. A missing
marker, incomplete trace or test exit 1 must not be relabeled as a success.
Do not install a global postmortem debugger to reproduce this process-only test.

## Preserved Windows 7 target transcripts

Source directory supplied by the tester:
`K:/VT7_work/resource-comparison-0.1/Logs/resource-comparison-18452-32699/`.
Matched local copies are under
`artifacts/vt7/evidence/resource-comparison-win7-0.1/resource-comparison-18452-32699/`.
The original files were hash-checked before the transcripts were copied here.

These logs establish NT 6.1.7601 SP1 x64 and matching printed build identities.
They do not include a fresh driver, DPI, servicing-tier or loaded-module inventory.
Neither process uses WPF. Both modes grow, so the development machine's
power-specific contrast is not target attribution.

### power.log

Original SHA256: `79BA85A6EC488A948CA2BC900FE4D6D12581029F76DD44B64DBC43DD43BCC7B1`.

```text
VT7 NATIVE RESOURCE COMPARISON 0.1; compiled Sep 13 2026 03:11:38
NATIVE 0.3.5 ABI=8 Release x64 Sep 13 2026 01:18:36
OS 6.1.7601 SP=1.0 bits=64
RAW ATLAS mode=2 probes=0 power=1; one persistent native parent, 2 warm-up + 100 surfaces
RESOURCE -2 private=5959680 handles=48 GDI=9 USER=4
  THREAD VT7.Host.exe+74dc/input-queue count=1
RESOURCE 0 private=11743232 handles=165 GDI=9 USER=31
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0 count=8
  THREAD ntdll.dll+f8de0/input-queue count=27
RESOURCE 25 private=13017088 handles=174 GDI=9 USER=40
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0/input-queue count=36
RESOURCE 50 private=13856768 handles=174 GDI=9 USER=40
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0/input-queue count=36
RESOURCE 75 private=13914112 handles=175 GDI=9 USER=41
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0/input-queue count=37
RESOURCE 100 private=14348288 handles=175 GDI=9 USER=41
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0 count=1
  THREAD ntdll.dll+f8de0/input-queue count=37
RESOURCE 110 private=14401536 handles=177 GDI=9 USER=41
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0 count=3
  THREAD ntdll.dll+f8de0/input-queue count=37
POWER registrations=102 unregistrations=102 delivered=102
COMPLETED: measurement only, not stability acceptance. No soak performed.
LAUNCHER process_exit=0
LAUNCHER measurement_completed=YES; resource_growth_acceptance=NOT_EVALUATED
```

### plain.log

Original SHA256: `254BB7F85480D56396C306888BCF3EB732FF33F9E786D683F577BBD3B2370C4B`.

```text
VT7 NATIVE RESOURCE COMPARISON 0.1; compiled Sep 13 2026 03:11:38
NATIVE 0.3.5 ABI=8 Release x64 Sep 13 2026 01:18:36
OS 6.1.7601 SP=1.0 bits=64
RAW ATLAS mode=2 probes=0 power=0; one persistent native parent, 2 warm-up + 100 surfaces
RESOURCE -2 private=5971968 handles=48 GDI=9 USER=4
  THREAD VT7.Host.exe+74dc/input-queue count=1
RESOURCE 0 private=11485184 handles=161 GDI=9 USER=30
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0 count=8
  THREAD ntdll.dll+f8de0/input-queue count=26
RESOURCE 25 private=12800000 handles=172 GDI=9 USER=41
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0 count=1
  THREAD ntdll.dll+f8de0/input-queue count=37
RESOURCE 50 private=13783040 handles=174 GDI=9 USER=43
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0/input-queue count=39
RESOURCE 75 private=12926976 handles=175 GDI=9 USER=44
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0/input-queue count=40
RESOURCE 100 private=12943360 handles=175 GDI=9 USER=44
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0/input-queue count=40
RESOURCE 110 private=13000704 handles=177 GDI=9 USER=44
  THREAD VT7.Host.exe+74dc/input-queue count=1
  THREAD ntdll.dll+13c50 count=1
  THREAD ntdll.dll+f8de0 count=2
  THREAD ntdll.dll+f8de0/input-queue count=40
POWER registrations=0 unregistrations=0 delivered=0
COMPLETED: measurement only, not stability acceptance. No soak performed.
LAUNCHER process_exit=0
LAUNCHER measurement_completed=YES; resource_growth_acceptance=NOT_EVALUATED
```

### summary.txt

Original SHA256: `A7F36C87AB674C9F95CD451785772FB2996CB6D4209A8D46B73DBE64CED4357D`.

```text
VT7 native resource comparison 0.1
Power first, then plain. Renderer 2: Atlas Direct3D11 WARP.
Exit 0 means measurements completed, not resource-growth acceptance.
power: measurement completed; process exit 0; growth not evaluated.
plain: measurement completed; process exit 0; growth not evaluated.
Launcher exit: 0
```
