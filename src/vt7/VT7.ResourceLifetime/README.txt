VT7 resource lifetime comparison 0.2 (x64)

This is a separate native diagnostic. It uses the exact issued VT7 0.3.5
Release ABI 8 native DLL, runtime DLLs and fonts. It is not a new application
release, a WPF host, a shell, or a fix for the remaining WARP growth.

WINDOWS 7 COMPARISON

Extract the entire archive into a new writable LOCAL folder. Keep all files
together. Use the same Windows 7 setup and normal input/security settings as
the previous comparison. Run RUN-RESOURCE-LIFETIME.cmd once. No visible
application window is expected. Leave the test running without changing DPI,
display settings, remote-session state or the desktop's input configuration.
The runner reports progress between the two processes; each has a ten-minute
timeout. It terminates only its own timed-out diagnostic child.

Return the entire new Logs/resource-lifetime-<run-id> folder, including both
stdout logs, both stderr logs and summary.txt. Note any environment changes,
interruption or timeout. The launcher always uses a fresh log directory.
Exit 0 means the measurements completed. It does NOT accept resource growth.
No timed soak, security exclusions or system-setting changes are requested.
The PowerShell execution-policy switch affects only this launcher process.

WHAT IS COMPARED

Each mode runs in a fresh process, recreate first then reuse, with explicit
Atlas Direct3D11 WARP and capture diagnostics. Power subscriptions and extra
graphics probes are off in both. One shown, fully transparent native parent
exists throughout each measurement process; no WPF is loaded by this host.

Both modes perform two warm-up plus 100 measured iterations of the same
fixture reset, starting size, ten resizes, five hide/show trips and message
pumping. Recreate makes and destroys 102 surfaces; reuse keeps one surface
through all 102 iterations and destroys it at the end. Each fixture and size
are reset even when the surface is reused. The worker must start only once
per surface, and completed frames must report nonblank forced-WARP rendering.
Device recreation/recovery makes the comparison incomplete, even if drawing
recovers, because it changes the intended lifetime of the reused device.

Nine checkpoints: before warm-up with no surface; after warm-up iteration one
with a live surface; baseline after warm-up iteration two with a live surface;
live after 25/50/75/100 measured iterations; then after final destruction and
another ten seconds of message pumping. The same parent remains during all
samples. The first closed sample follows the same 20 ms pumping delay in
both modes. Warm-up is retained in the logs rather than discarded.

INTERPRETING THREAD AND RESOURCE LOGS

Process private bytes, handle count, GDI, USER and enumerated thread counts
are sequential samples, not one atomic snapshot. Temporary sampling handles
are closed before process counters are read. Fixed sampler storage is touched
before the first sample; capacity overflow is an explicit failure. Sampling
and logging still affect timing and memory. This is a paired diagnostic,
not an allocation trace and not the unchanged integrated stability gate.

Thread identity is TID plus creation FILETIME (hexadecimal Windows epoch).
The same identity at successive samples is marked surviving. Newly observed
does not prove creation happened at that instant. A different creation time
for a previously observed TID is marked new-identity-reused-tid. NOT_OBSERVED
means absent from the next snapshot, not a complete exit history. Threads
that are born and exit between checkpoints can be missed.

queue=observed means GetGUIThreadInfo succeeded with the identified thread
alive before and after the query. queue=unavailable preserves the error;
it does NOT mean definitely no queue. first_queue_sample identifies the
first positive observation, not the exact instant a queue was acquired.
alive_before/after are WaitForSingleObject results: 258 is still running,
0 is terminated, 4294967295 is query failure. Numeric ID reuse is guarded by
creation time and liveness checks. identity_error and origin_status preserve
unavailable attribution. Some thread exits can race snapshot inspection.

origin is the module containing the queried Win32 start address, plus offset.
It is NOT proof that the module owns the thread or its retained resources.
An ntdll address is not a WARP ownership attribution. Unknown module/queue
information is explicitly retained rather than invented. Identity failures
are counted in ATTRIBUTION even if all workload measurements complete.

A flat reuse case would implicate repeated lifetimes collectively. It also
removes HWND, device, swap-chain and worker churn, so it cannot by itself
establish harmless initialization, a fixed pool, or a specific leaking owner.
The original stability budgets remain unchanged and are not evaluated here.

DEVELOPMENT / PROVENANCE

provenance/BUILD-MANIFEST.json, PACKAGE-MANIFEST.json and SHA256SUMS.txt identify
this candidate. provenance/source/ preserves diagnostic and header inputs.
The copied native CORE/RENDERER-PROVENANCE files describe the issued DLL;
they are historical snapshots, not this diagnostic's new source identity.
Static PE/import checks and Windows 10 operation do not qualify Windows 7.

Developer-only CLI:
  VT7.ResourceLifetime.exe <absolute-native-DLL-path> recreate|reuse
Optional --cycles N (1..100) shortens measured iterations. Optional
--fail-at-cycle N injects an explicit workload failure for runner validation.
The supplied comparison launcher uses neither option. Preserve partial logs
after failures. Build and packaging helpers refuse to overwrite issued output.
