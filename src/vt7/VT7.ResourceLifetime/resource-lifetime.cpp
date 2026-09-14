// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license. Standalone measurement, not the VT7 WPF host.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#define PSAPI_VERSION 1
#include <windows.h>
#include <objbase.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <cstdio>
#include <cwchar>
#include <cstdint>
#include "../VT7.Native/include/vt7_native.h"

namespace
{
    constexpr unsigned Warmup = 2;
    constexpr unsigned MaxThreads = 2048;
    constexpr unsigned MaxIdentities = 16384;
    constexpr DWORD FrameTimeout = 5000;
    bool cancelled = false;
    unsigned powerMessages = 0;

    struct Failure { const char* operation; HRESULT hr; };
    void check(HRESULT hr, const char* operation)
    {
        if (FAILED(hr)) throw Failure{ operation, hr };
    }
    void require(bool success, const char* operation)
    {
        if (!success)
        {
            const auto error = GetLastError();
            throw Failure{ operation, error ? HRESULT_FROM_WIN32(error) : E_FAIL };
        }
    }
    struct Handle
    {
        HANDLE value = nullptr;
        ~Handle() { if (value && value != INVALID_HANDLE_VALUE) CloseHandle(value); }
    };
    uint64_t ticks(FILETIME value) { return (uint64_t(value.dwHighDateTime) << 32) | value.dwLowDateTime; }

    LRESULT CALLBACK windowProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam)
    {
        if (message == WM_CLOSE) { cancelled = true; return 0; }
        if (message == WM_POWERBROADCAST && wparam == PBT_POWERSETTINGCHANGE) ++powerMessages;
        return DefWindowProcW(window, message, wparam, lparam);
    }
    void pump(DWORD milliseconds = 0)
    {
        const auto start = GetTickCount64();
        do
        {
            MSG message{};
            while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE))
            {
                if (message.message == WM_QUIT) cancelled = true;
                TranslateMessage(&message);
                DispatchMessageW(&message);
                if (GetTickCount64() - start > milliseconds + FrameTimeout)
                    throw Failure{ "message-pump-timeout", HRESULT_FROM_WIN32(ERROR_TIMEOUT) };
            }
            if (cancelled) throw Failure{ "cancelled", HRESULT_FROM_WIN32(ERROR_CANCELLED) };
            Sleep(1);
        } while (GetTickCount64() - start < milliseconds);
    }

    // Fixed storage, touched before the first measurement. No retained thread handles
    // and no dynamically growing history container contaminate lifecycle deltas.
    struct Identity
    {
        DWORD tid;
        uint64_t creation;
        unsigned firstSample;
        unsigned lastSample;
        unsigned firstQueueSample;
    };
    struct Thread
    {
        DWORD tid;
        uint64_t creation;
        DWORD identityError;
        DWORD aliveBefore;
        DWORD aliveAfter;
        bool queue;
        DWORD queueError;
        LONG originStatus;
        uintptr_t start;
        uintptr_t offset;
        DWORD moduleError;
        wchar_t module[MAX_PATH];
        unsigned firstSample;
        unsigned firstQueueSample;
        const char* observation;
    };
    Identity identities[MaxIdentities];
    Thread threads[MaxThreads];
    unsigned identityCount = 0;
    unsigned sampleCount = 0;
    unsigned identityUnavailable = 0;
    using QueryThread = LONG(NTAPI*)(HANDLE, ULONG, PVOID, ULONG, PULONG);
    QueryThread queryThread = nullptr;

    void initializeSampler()
    {
        auto touch = [](void* address, size_t size) {
            auto bytes = static_cast<volatile unsigned char*>(address);
            for (size_t i = 0; i < size; ++i) bytes[i] = 0;
        };
        touch(identities, sizeof(identities));
        touch(threads, sizeof(threads));
        queryThread = reinterpret_cast<QueryThread>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtQueryInformationThread"));
    }
    void observe(Thread& item)
    {
        if (!item.creation)
        {
            item.observation = "identity-unavailable";
            ++identityUnavailable;
            return;
        }
        bool reusedTid = false;
        for (unsigned i = 0; i < identityCount; ++i)
        {
            auto& identity = identities[i];
            if (identity.tid != item.tid) continue;
            if (identity.creation != item.creation) { reusedTid = true; continue; }
            item.observation = identity.lastSample + 1 == sampleCount ? "surviving" : "seen-earlier";
            identity.lastSample = sampleCount;
            if (item.queue && !identity.firstQueueSample) identity.firstQueueSample = sampleCount;
            item.firstSample = identity.firstSample;
            item.firstQueueSample = identity.firstQueueSample;
            return;
        }
        if (identityCount == MaxIdentities) throw Failure{ "identity-capacity", HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER) };
        identities[identityCount++] = { item.tid, item.creation, sampleCount, sampleCount, item.queue ? sampleCount : 0 };
        item.firstSample = sampleCount;
        item.firstQueueSample = item.queue ? sampleCount : 0;
        item.observation = reusedTid ? "new-identity-reused-tid" : "newly-observed";
    }
    void inspectThread(Thread& item)
    {
        Handle handle{ OpenThread(THREAD_QUERY_INFORMATION | SYNCHRONIZE, FALSE, item.tid) };
        if (!handle.value) handle.value = OpenThread(THREAD_QUERY_LIMITED_INFORMATION | SYNCHRONIZE, FALSE, item.tid);
        if (!handle.value) { item.identityError = GetLastError(); return; }
        // Check ownership after opening: Toolhelp IDs can already have been recycled.
        SetLastError(ERROR_SUCCESS);
        if (GetProcessIdOfThread(handle.value) != GetCurrentProcessId())
        {
            item.identityError = GetLastError();
            if (!item.identityError) item.identityError = ERROR_NOT_FOUND;
            return;
        }
        FILETIME creation{}, exit{}, kernel{}, user{};
        if (!GetThreadTimes(handle.value, &creation, &exit, &kernel, &user))
        {
            item.identityError = GetLastError();
            return;
        }
        item.creation = ticks(creation);
        item.aliveBefore = WaitForSingleObject(handle.value, 0);
        if (queryThread)
        {
            void* address = nullptr;
            item.originStatus = queryThread(handle.value, 9 /* ThreadQuerySetWin32StartAddress */, &address, sizeof(address), nullptr);
            item.start = reinterpret_cast<uintptr_t>(address);
            if (item.originStatus >= 0 && address)
            {
                HMODULE module = nullptr;
                if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                                      reinterpret_cast<LPCWSTR>(address), &module))
                {
                    wchar_t path[MAX_PATH]{};
                    const auto count = GetModuleFileNameW(module, path, MAX_PATH);
                    if (count && count < MAX_PATH)
                    {
                        const auto slash = wcsrchr(path, L'\\');
                        wcscpy_s(item.module, slash ? slash + 1 : path);
                        item.offset = item.start - reinterpret_cast<uintptr_t>(module);
                    }
                    else item.moduleError = count ? ERROR_INSUFFICIENT_BUFFER : GetLastError();
                }
                else item.moduleError = GetLastError();
            }
        }
        // Failure is NOT evidence of queue absence. Even an alive thread can have
        // an unavailable GUI query. Preserve the exact error and liveness bracket.
        GUITHREADINFO gui{ sizeof(gui) };
        SetLastError(ERROR_SUCCESS);
        item.queue = GetGUIThreadInfo(item.tid, &gui) != FALSE;
        item.queueError = item.queue ? 0 : GetLastError();
        item.aliveAfter = WaitForSingleObject(handle.value, 0);
        if (item.aliveBefore != WAIT_TIMEOUT || item.aliveAfter != WAIT_TIMEOUT)
        {
            // A dead thread's TID might resolve to another thread during the GUI query.
            item.queue = false;
            item.queueError = ERROR_RETRY;
        }
    }
    DWORD guiResources(DWORD kind)
    {
        SetLastError(ERROR_SUCCESS);
        const auto result = GetGuiResources(GetCurrentProcess(), kind);
        const auto error = GetLastError();
        if (!result && error) throw Failure{ "GetGuiResources", HRESULT_FROM_WIN32(error) };
        return result;
    }
    void sample(const char* phase, unsigned iteration, bool live)
    {
        ++sampleCount;
        const auto started = GetTickCount64();
        unsigned count = 0;
        {
            Handle snapshot{ CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0) };
            require(snapshot.value != INVALID_HANDLE_VALUE, "thread-snapshot");
            THREADENTRY32 entry{ sizeof(entry) };
            require(Thread32First(snapshot.value, &entry) != FALSE, "thread-first");
            do
            {
                if (entry.th32OwnerProcessID != GetCurrentProcessId()) continue;
                if (count == MaxThreads) throw Failure{ "thread-capacity", HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER) };
                auto& item = threads[count++];
                item = {};
                item.tid = entry.th32ThreadID;
                item.aliveBefore = item.aliveAfter = WAIT_FAILED;
                item.originStatus = static_cast<LONG>(0xC0000002u); // STATUS_NOT_IMPLEMENTED until queried.
                item.queueError = ERROR_NOT_READY;
                inspectThread(item);
                observe(item);
            } while (Thread32Next(snapshot.value, &entry));
            const auto error = GetLastError();
            if (error != ERROR_NO_MORE_FILES) throw Failure{ "thread-next", HRESULT_FROM_WIN32(error ? error : ERROR_INVALID_DATA) };
        }
        // All sampler handles are closed before process resource counters are read.
        PROCESS_MEMORY_COUNTERS_EX memory{};
        memory.cb = sizeof(memory);
        require(GetProcessMemoryInfo(GetCurrentProcess(), reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory), sizeof(memory)) != FALSE, "process-memory");
        DWORD handles = 0;
        require(GetProcessHandleCount(GetCurrentProcess(), &handles) != FALSE, "process-handles");
        const auto gdi = guiResources(GR_GDIOBJECTS);
        const auto user = guiResources(GR_USEROBJECTS);
        const auto ended = GetTickCount64();
        printf("RESOURCE sample=%u phase=%s iteration=%u live=%u private=%zu handles=%lu GDI=%lu USER=%lu threads=%u begin_ms=%llu end_ms=%llu\n",
               sampleCount, phase, iteration, unsigned(live), memory.PrivateUsage, handles, gdi, user, count, started, ended);
        for (unsigned i = 0; i < count; ++i)
        {
            const auto& item = threads[i];
            printf("THREAD sample=%u tid=%lu creation=%016llX identity_error=%lu observation=%s first_sample=%u queue=%s queue_error=%lu first_queue_sample=%u alive_before=%lu alive_after=%lu origin=%ls offset=%llX start=%llX origin_status=%08lX module_error=%lu\n",
                   sampleCount, item.tid, item.creation, item.identityError, item.observation, item.firstSample,
                   item.queue ? "observed" : "unavailable", item.queueError, item.firstQueueSample, item.aliveBefore, item.aliveAfter,
                   item.module[0] ? item.module : L"unavailable", uint64_t(item.offset), uint64_t(item.start), item.originStatus, item.moduleError);
        }
        for (unsigned i = 0; i < identityCount; ++i)
        {
            const auto& identity = identities[i];
            if (identity.lastSample + 1 == sampleCount)
                printf("NOT_OBSERVED sample=%u tid=%lu creation=%016llX previous_sample=%u; absence_from_snapshot_not_complete_exit_history\n",
                       sampleCount, identity.tid, identity.creation, identity.lastSample);
        }
    }

    struct Api
    {
        HMODULE module = nullptr;
        decltype(&VT7_CreateSurface) create = nullptr;
        decltype(&VT7_DestroySurface) destroy = nullptr;
        decltype(&VT7_GetSurfaceInfo) info = nullptr;
        decltype(&VT7_SchedulingCommand) command = nullptr;
        decltype(&VT7_GetSchedulingInfo) scheduling = nullptr;
        decltype(&VT7_GetAbiVersion) abi = nullptr;
        decltype(&VT7_GetBuildInfo) build = nullptr;
        decltype(&VT7_GetPlatformInfo) platform = nullptr;
        HWND parent = nullptr;
        void* surface = nullptr;
        unsigned creates = 0, destroys = 0, iterations = 0, resizes = 0, trips = 0;

        void closeSurface()
        {
            const auto hwnd = static_cast<HWND>(surface);
            check(destroy(surface), "destroy-surface");
            surface = nullptr;
            ++destroys;
            if (IsWindow(hwnd)) throw Failure{ "surface-window-survived", E_FAIL };
        }
        void waitFrame()
        {
            require(RedrawWindow(static_cast<HWND>(surface), nullptr, nullptr, RDW_INVALIDATE | RDW_UPDATENOW) != FALSE, "redraw");
            const auto start = GetTickCount64();
            for (;;)
            {
                VT7_SURFACE_INFO state{ sizeof(state) };
                check(info(surface, &state), "surface-info");
                check(state.last_hresult, "render-result");
                if (state.paint_count && state.completed_request >= state.requested_frame)
                {
                    if (state.renderer_mode != 2 || state.requested_renderer_mode != 2 || !state.frame_ink_pixels)
                        throw Failure{ "nonblank-forced-warp-frame", E_FAIL };
                    if (state.device_generation != 1 || state.device_attempts != 1 || state.recovery_failures ||
                        state.fallback_count || state.injected_failures || FAILED(state.last_render_failure))
                    {
                        printf("DEVICE generation=%u attempts=%u recovery_failures=%u fallback=%u injected=%u last_failure=%08X\n",
                               state.device_generation, state.device_attempts, state.recovery_failures, state.fallback_count,
                               state.injected_failures, unsigned(state.last_render_failure));
                        throw Failure{ "graphics-device-lifetime-changed", E_FAIL };
                    }
                    return;
                }
                if (GetTickCount64() - start > FrameTimeout) throw Failure{ "frame-timeout", HRESULT_FROM_WIN32(ERROR_TIMEOUT) };
                pump();
            }
        }
        void workload()
        {
            const auto hwnd = static_cast<HWND>(surface);
            // The final size of the preceding iteration differs. Restore the same
            // starting client size in both modes before resetting the fixture.
            require(SetWindowPos(hwnd, nullptr, 0, 0, 1000, 800, SWP_NOZORDER | SWP_NOACTIVATE) != FALSE, "reset-size");
            ShowWindow(hwnd, SW_SHOWNOACTIVATE);
            check(command(surface, 0, 0), "reset-fixture");
            waitFrame();
            for (unsigned step = 0; step < 10; ++step)
            {
                require(SetWindowPos(hwnd, nullptr, 0, 0, 700 + step % 5 * 40, 500 + step % 3 * 30, SWP_NOZORDER | SWP_NOACTIVATE) != FALSE, "resize");
                ++resizes;
                check(command(surface, 3, step), "edit-and-wake");
                waitFrame();
                check(command(surface, 4, step), "verify-marker");
                if (step % 2 == 0)
                {
                    ShowWindow(hwnd, SW_HIDE);
                    pump(1);
                    ShowWindow(hwnd, SW_SHOWNOACTIVATE);
                    waitFrame();
                    ++trips;
                }
            }
            VT7_SCHEDULING_INFO state{ sizeof(state) };
            check(scheduling(surface, &state), "scheduling-info");
            if (state.thread_starts != 1) throw Failure{ "unexpected-worker-restart", E_FAIL };
            ++iterations;
        }
    };

    unsigned number(const wchar_t* text)
    {
        wchar_t* end = nullptr;
        const auto value = wcstoul(text, &end, 10);
        if (!text[0] || *end || value < 1 || value > 100) throw Failure{ "argument-range-1-to-100", E_INVALIDARG };
        return static_cast<unsigned>(value);
    }
}

int wmain(int argc, wchar_t** argv)
{
    setvbuf(stdout, nullptr, _IONBF, 0);
    Api api;
    bool com = false;
    try
    {
        if (argc < 3 || (wcscmp(argv[2], L"recreate") && wcscmp(argv[2], L"reuse")))
            throw Failure{ "usage-native-dll-recreate-or-reuse", E_INVALIDARG };
        const bool reuse = wcscmp(argv[2], L"reuse") == 0;
        unsigned cycles = 100, failAt = 0;
        bool cyclesSet = false;
        for (int i = 3; i < argc; i += 2)
        {
            if (i + 1 == argc) throw Failure{ "missing-option-value", E_INVALIDARG };
            if (!wcscmp(argv[i], L"--cycles") && !cyclesSet) { cycles = number(argv[i + 1]); cyclesSet = true; }
            else if (!wcscmp(argv[i], L"--fail-at-cycle") && !failAt) failAt = number(argv[i + 1]);
            else throw Failure{ "unknown-or-duplicate-option", E_INVALIDARG };
        }
        if (failAt > cycles) throw Failure{ "failure-cycle-outside-workload", E_INVALIDARG };
        printf("VT7 RESOURCE LIFETIME 0.2; compiled %s %s; pid=%lu\n", __DATE__, __TIME__, GetCurrentProcessId());
        printf("CONFIG mode=%s renderer=2 capture=1 power=0 probes=0 warmup=2 cycles=%u fail_at_cycle=%u\n", reuse ? "reuse" : "recreate", cycles, failAt);
        printf("SAMPLING sequential_not_atomic=1 fixed_storage_bytes=%zu max_threads=%u max_identities=%u; queue_failure_is_unknown; start_address_is_not_owner; unsampled_threads_may_be_missed\n",
               sizeof(identities) + sizeof(threads), MaxThreads, MaxIdentities);
        initializeSampler();
        check(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED), "COM-initialize");
        com = true;
        // LOAD_WITH_ALTERED_SEARCH_PATH also resolves adjacent issued runtime DLLs.
        // Require an absolute path so the dependency search root is unambiguous.
        if (wcslen(argv[1]) < 3 || argv[1][1] != L':' || (argv[1][2] != L'\\' && argv[1][2] != L'/'))
            throw Failure{ "native-dll-must-be-absolute-drive-path", E_INVALIDARG };
        api.module = LoadLibraryExW(argv[1], nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
        require(api.module != nullptr, "load-native-dll");
#define LOAD(name, member) api.member = reinterpret_cast<decltype(api.member)>(GetProcAddress(api.module, #name)); if (!api.member) throw Failure{ #name "-export", E_NOINTERFACE }
        LOAD(VT7_CreateSurface, create);
        LOAD(VT7_DestroySurface, destroy);
        LOAD(VT7_GetSurfaceInfo, info);
        LOAD(VT7_SchedulingCommand, command);
        LOAD(VT7_GetSchedulingInfo, scheduling);
        LOAD(VT7_GetAbiVersion, abi);
        LOAD(VT7_GetBuildInfo, build);
        LOAD(VT7_GetPlatformInfo, platform);
#undef LOAD
        // This provenance harness intentionally targets the issued ABI 8 DLL,
        // even when compiled from a newer application source tree.
        if (api.abi() != 8) throw Failure{ "native-ABI-8", E_NOINTERFACE };
        VT7_BUILD_INFO build{ sizeof(build) };
        VT7_PLATFORM_INFO platform{ sizeof(platform) };
        check(api.build(&build), "native-build-info");
        check(api.platform(&platform), "native-platform-info");
        printf("NATIVE %u.%u.%u ABI=%u %ls %ls\n", build.version_major, build.version_minor, build.version_patch,
               build.abi_version, build.configuration, build.build_timestamp);
        printf("OS %u.%u.%u SP=%u.%u bits=%u\n", platform.major_version, platform.minor_version, platform.build_number,
               platform.service_pack_major, platform.service_pack_minor, platform.architecture_bits);
        WNDCLASSW windowClass{};
        windowClass.hInstance = GetModuleHandleW(nullptr);
        windowClass.lpfnWndProc = windowProc;
        windowClass.lpszClassName = L"VT7ResourceLifetime02";
        require(RegisterClassW(&windowClass) != 0, "register-parent-class");
        api.parent = CreateWindowExW(WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TRANSPARENT,
                                    windowClass.lpszClassName, L"VT7 resource lifetime diagnostic", WS_POPUP,
                                    0, 0, 1000, 800, nullptr, nullptr, windowClass.hInstance, nullptr);
        require(api.parent != nullptr, "create-parent");
        require(SetLayeredWindowAttributes(api.parent, 0, 0, LWA_ALPHA) != FALSE, "parent-alpha");
        ShowWindow(api.parent, SW_SHOWNOACTIVATE);
        pump(250);
        sample("pre-warmup", 0, false);
        for (unsigned iteration = 0; iteration < Warmup + cycles; ++iteration)
        {
            if (failAt && iteration == Warmup + failAt - 1) throw Failure{ "injected-workload-failure", E_ABORT };
            if (!api.surface)
            {
                check(api.create(api.parent, 2 | 0x100, &api.surface), "create-surface");
                require(api.surface != nullptr, "created-null-surface");
                ++api.creates;
            }
            api.workload();
            pump(20);
            const auto measured = iteration < Warmup ? 0 : iteration + 1 - Warmup;
            if (iteration < Warmup || measured % 25 == 0 || measured == cycles)
            {
                pump(250);
                sample(iteration + 1 < Warmup ? "warmup-live" : (iteration + 1 == Warmup ? "baseline-live" : "measured-live"), measured, true);
            }
            if (!reuse || iteration + 1 == Warmup + cycles) api.closeSurface();
            pump(20);
            if (measured && (measured % 10 == 0 || measured == cycles))
                printf("PROGRESS measured=%u creates=%u destroys=%u\n", measured, api.creates, api.destroys);
        }
        sample("final-closed", cycles, false);
        pump(10000);
        sample("final-closed-10s", cycles, false);
        const auto expectedCreates = reuse ? 1 : Warmup + cycles;
        if (api.creates != expectedCreates || api.destroys != expectedCreates || api.iterations != Warmup + cycles ||
            api.resizes != (Warmup + cycles) * 10 || api.trips != (Warmup + cycles) * 5)
            throw Failure{ "workload-totals", E_FAIL };
        printf("WORKLOAD iterations=%u creates=%u destroys=%u resizes=%u size_resets=%u hide_show=%u power_registrations=0 power_unregistrations=0 power_delivered=%u\n",
               api.iterations, api.creates, api.destroys, api.resizes, api.iterations, api.trips, powerMessages);
        printf("ATTRIBUTION samples=%u identities=%u identity_unavailable=%u; queue_unavailable_is_not_queue_absent\n", sampleCount, identityCount, identityUnavailable);
        require(DestroyWindow(api.parent) != FALSE, "destroy-parent");
        api.parent = nullptr;
        require(FreeLibrary(api.module) != FALSE, "unload-native");
        api.module = nullptr;
        CoUninitialize();
        com = false;
        printf("COMPLETED: measurement only, not stability acceptance. No soak performed.\n");
        return 0;
    }
    catch (const Failure& failure)
    {
        printf("FAIL operation=%s hresult=%08X\n", failure.operation, unsigned(failure.hr));
    }
    catch (...)
    {
        printf("FAIL operation=unexpected-exception\n");
    }
    if (api.surface && api.destroy)
    {
        const auto hr = api.destroy(api.surface);
        printf("CLEANUP destroy_surface_hresult=%08X\n", unsigned(hr));
        api.surface = nullptr;
    }
    if (api.parent) DestroyWindow(api.parent);
    if (api.module) FreeLibrary(api.module);
    if (com) CoUninitialize();
    printf("INCOMPLETE: preserve partial measurements; no resource acceptance.\n");
    return 1;
}
