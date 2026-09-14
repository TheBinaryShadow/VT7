// Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal static partial class StabilityWindowChecks
    {
        internal static async Task<int> RunReactivation(Action<string> log, bool injectWork)
        {
            var threads = new ReactivationThreads();
            var sample = 0;
            var failures = 0;
            Resources? baseline = null;
            Resources? startup = null;
            Resources? previousIdle = null;
            var previousIdleSample = 0;
            var latency = new List<double>(2020);
            long worstClose = 0;

            async Task<Resources> Sample(string phase, int round, int cycle, ulong closedAt = 0)
            {
                var begin = ReactivationThreads.Ticks();
                var state = await Resources.Read();
                var end = ReactivationThreads.Ticks();
                ++sample;
                log(FormattableString.Invariant($"RESOURCE sample={sample} phase={phase} round={round} cycle={cycle} baseline_sample={(baseline == null ? 0 : 2)} private={state.Bytes} handles={state.Handles} threads={state.Threads} GDI={state.Gdi} USER={state.User} begin_ms={begin} end_ms={end} closed_elapsed_ms={(closedAt == 0 ? 0 : end - closedAt)}"));
                log($"HELPERS sample={sample} {state.Windows}");
                log($"THREAD_ORIGINS sample={sample} {state.ThreadOrigins}");
                threads.Read(sample, log);
                void Delta(string reference, Resources other, int otherSample) => log(FormattableString.Invariant(
                    $"DELTA sample={sample} reference={reference} reference_sample={otherSample} private={state.Bytes - other.Bytes} handles={state.Handles - other.Handles} threads={state.Threads - other.Threads} GDI={(long)state.Gdi - other.Gdi} USER={(long)state.User - other.User}"));
                if (startup != null) Delta("startup", startup, 1);
                if (baseline != null)
                {
                    Delta("baseline", baseline, 2);
                    Require(state.Bytes - baseline.Bytes < 512L * 1024 * 1024 && state.Handles - baseline.Handles < 2048,
                        "Resource safety ceiling exceeded; stopping bounded reactivation collection.");
                }
                if (previousIdle != null && phase == "closed-180s") Delta("previous_idle", previousIdle, previousIdleSample);
                return state;
            }

            startup = await Sample("pre-warmup", 0, 0);
            ReactivationThreads.Modules(sample, log);
            log("WARMUP_BEGIN lifecycles=2");
            for (var cycle = -2; cycle < 0; ++cycle)
                worstClose = Math.Max(worstClose, await RunLifecycleCycle(cycle, latency, text => log("WORK round=0 " + text)));
            baseline = await Sample("baseline-closed", 0, 0);
            log("BASELINE_FIXED sample=2");
            for (var round = 1; round <= 2; ++round)
            {
                log(FormattableString.Invariant($"ROUND_BEGIN round={round} baseline_sample=2"));
                ulong closedAt = 0;
                var latencyStart = latency.Count;
                for (var cycle = 0; cycle < 100; ++cycle)
                {
                    if (injectWork && round == 1 && cycle == 0) throw new InvalidOperationException("Injected workload failure before first measured lifecycle.");
                    worstClose = Math.Max(worstClose, await RunLifecycleCycle(cycle, latency, text => log($"WORK round={round} " + text)));
                    closedAt = ReactivationThreads.Ticks();
                    if ((cycle + 1) % 25 != 0) continue;
                    var state = await Sample("cycle-" + (cycle + 1), round, cycle + 1, closedAt);
                    var verdict = "PASS";
                    try { state.CheckGrowth(baseline); }
                    catch (InvalidOperationException) { ++failures; verdict = "FAIL"; }
                    log(FormattableString.Invariant($"BUDGET sample={sample} round={round} cycle={cycle + 1} baseline_sample=2 verdict={verdict} cumulative_failures={failures}"));
                }
                Require(latency.Count - latencyStart == 1000, "Measured resize operation count differs.");
                log(FormattableString.Invariant($"ROUND_WORK_COMPLETE round={round} lifecycles=100 resizes=1000 tab_trips=500 close_origin_ms={closedAt} worst_close_ms={worstClose}"));
                foreach (var target in new[] { 10000, 90000, 180000 })
                {
                    var begin = ReactivationThreads.Ticks();
                    var deadline = closedAt + (ulong)target;
                    var requested = deadline > begin ? checked((int)(deadline - begin)) : 0;
                    log(FormattableString.Invariant($"IDLE_BEGIN round={round} target_ms={target} closed_ms={closedAt} begin_ms={begin} requested_ms={requested}"));
                    // Resume the ordinary WPF dispatcher. No worker handle is held while waiting.
                    while (true)
                    {
                        var now = ReactivationThreads.Ticks();
                        if (now >= deadline) break;
                        await Task.Delay(checked((int)(deadline - now)));
                    }
                    var end = ReactivationThreads.Ticks();
                    log(FormattableString.Invariant($"IDLE_END round={round} target_ms={target} closed_ms={closedAt} end_ms={end} elapsed_ms={end - begin}"));
                    var state = await Sample("closed-" + target / 1000 + "s", round, 100, closedAt);
                    if (target == 180000) { previousIdle = state; previousIdleSample = sample; }
                }
                log(FormattableString.Invariant($"ROUND_END round={round} baseline_sample=2 cumulative_failures={failures}"));
            }
            ReactivationThreads.Modules(sample, log);
            Require(sample == 16 && latency.Count == 2000, "Reactivation sample/workload count differs.");
            log(FormattableString.Invariant($"WORKLOAD warmup=2 rounds=2 measured_lifecycles=200 total_lifecycles=202 measured_resizes=2000 measured_tab_trips=1000 samples={sample} worst_close_ms={worstClose}"));
            return failures;
        }
    }
}
