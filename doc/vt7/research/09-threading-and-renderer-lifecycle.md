# Synchronization, timers, COM and renderer lifetime

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P0.

## Two different wait adaptations

Observed in repository: the proof replaces the core ticket-lock wait with SRW locking, but the upstream renderer controller still contains address-based waits for redraw and synchronized output. The proof renderer merely records invalidation. [1]

WaitOnAddress is a Windows 8 API. An event/condition-variable replacement must preserve the state predicate and deadlines; replacing the call with Sleep changes semantics. [2]

Windows condition variables atomically release their associated lock while sleeping, then reacquire it. Spurious and stolen wakeups are allowed, so callers must recheck a predicate in a loop. [3]

**Proposed render-state model:** under one state lock, maintain desired generation, completed generation, stop flag, visibility, recovery state and next deadline. Producers update state before signaling. The render worker waits while no work/deadline/stop condition is satisfied. Rendering completion advances only the generation actually drawn.

This is an algorithm proposal, not a drop-in patch for til::atomic_wait. The upstream callers and synchronized-output timeout must be reviewed together.

## Locking hazards

SRW locks are neither fair nor FIFO, do not support exclusive recursive acquisition, and cannot upgrade shared ownership to exclusive ownership. [4] The core's wrapper preserves its own recursive ownership handling; that does not make arbitrary raw SRW calls recursive. [1]

Recommended lock rules:

- Hold the core lock while obtaining a consistent render snapshot or traversing data that requires it.
- Do not hold it while waiting on network/pipe I/O, UI callbacks, frame pacing or potentially blocking presentation.
- Define a single lock order across session, core, renderer and diagnostics.
- Never call a managed callback under a native lock if it may reenter the native API.
- Stop admitting callbacks before destruction, then wait for in-flight callbacks to finish.

Stress with output, resize, font changes, diagnostics and close happening concurrently. A seven-check proof is not evidence that this expanded lock graph is safe.

## Graphics and COM ownership

A D3D11 device context needs application synchronization if accessed concurrently. [5] **Recommendation:** use one render owner for the immediate context, swap chain and dependent Direct2D resources, especially when the device was created SINGLETHREADED.

CoInitializeEx initializes COM per thread. S_FALSE is still successful initialization and must be balanced with CoUninitialize; RPC_E_CHANGED_MODE is a failure to establish the requested apartment. [6]

Do not mechanically call CoInitializeEx around every DirectWrite call: distinguish APIs that can be used directly from components that require COM apartment initialization, such as other interop/UIA/WIC paths. Where a worker needs COM, give it a documented apartment and release apartment-bound objects before teardown.

## Deadlines and power transitions

WaitForSingleObject timeouts on Windows 7 count time spent in low-power states; Windows 8 changed that behavior. Threads that own windows must continue pumping messages rather than blocking indefinitely. [7]

QueryPerformanceCounter is the appropriate high-resolution interval measurement source; wall-clock time is a separate concept. [8]

**Recommendation:** define whether each deadline includes sleep: cursor blink can be reset on resume, but a connection attempt may need to expire. Record durations using a monotonic interval clock and report timestamps separately. Do not import GetSystemTimePreciseAsFileTime merely for logs.

timeBeginPeriod affects the global timer setting on Windows 7 and must be paired with timeEndPeriod. Increased resolution has scheduling/power costs. [9] Avoid enabling 1 ms timers for the entire application lifetime as an initial pacing solution.

## Teardown protocol

Later implementation clarification, 2026-09-13: the sequence below is the
original proposal, not the current VT7 surface teardown order. The
[0.3.5 lifetime correction](../validation/2026-09-13-atlas-stability.md)
pauses/acknowledges rendering, destroys the HWND on its owner while the worker
remains alive, then releases graphics on the worker and joins before deleting
the surface. Worker exit before HWND destruction reproduced retained DXGI
events on the development setup. This correction does not resolve the separate
WARP resource-growth gate. Preserve the old proposal as history, not a template
for reversing the corrected order.

Proposed order:

1. Mark the surface/session closing and reject new work.
2. Unregister producers and prevent new callbacks.
3. Signal stop and cancel pending I/O.
4. Let the worker release graphics resources on its owning thread.
5. Confirm completion without blocking a message pump the worker depends on.
6. Release callback roots and COM objects.
7. Destroy the HWND/core only after no worker can access them.

Present may itself wait on the message-pump thread. A UI-thread join while the render thread is stuck in Present can deadlock, even if the rendering code never explicitly calls Dispatcher.Invoke. [10]

The current native state is destroyed during WM_NCDESTROY and currently assumes UI-thread surface calls. Asynchronous integration must preserve or explicitly redesign that contract. [11]

## Acceptance experiments

Use barriers to force: signal immediately before sleep; resize during paint; close during synchronized output; missing end-of-synchronization timeout; stop during device recovery; stale completion from an older generation; and UI close during Present.

Observe no lost invalidation, no post-destroy callback, bounded stop time, stable idle CPU, and no continuous redraw for unchanged content. Test visible, hidden and minimized independently.

## Sources

- [1] [Core boundary](../../../src/vt7/VT7.Core/README.md), [controller](../../../src/renderer/base/renderer.cpp), [atomic waits](../../../src/inc/til/atomic.h).
- [2] Microsoft, [WaitOnAddress](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitonaddress).
- [3] Microsoft, [Condition Variables](https://learn.microsoft.com/en-us/windows/win32/sync/condition-variables).
- [4] Microsoft, [SRW locks](https://learn.microsoft.com/en-us/windows/win32/sync/slim-reader-writer--srw--locks).
- [5] Microsoft, [D3D11 multithreading](https://learn.microsoft.com/en-us/windows/win32/direct3d11/overviews-direct3d-11-render-multi-thread-intro).
- [6] Microsoft, [CoInitializeEx](https://learn.microsoft.com/en-us/windows/win32/api/combaseapi/nf-combaseapi-coinitializeex).
- [7] Microsoft, [WaitForSingleObject](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitforsingleobject).
- [8] Microsoft, [Acquiring high-resolution timestamps](https://learn.microsoft.com/en-us/windows/win32/sysinfo/acquiring-high-resolution-time-stamps).
- [9] Microsoft, [timeBeginPeriod](https://learn.microsoft.com/en-us/windows/win32/api/timeapi/nf-timeapi-timebeginperiod).
- [10] Microsoft, [Present threading remarks](https://learn.microsoft.com/en-us/windows/win32/api/dxgi/nf-dxgi-idxgiswapchain-present).
- [11] [surface.cpp](../../../src/vt7/VT7.Native/surface.cpp), [native ABI](../../../src/vt7/VT7.Native/include/vt7_native.h).
