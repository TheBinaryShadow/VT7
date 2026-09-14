// Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows;

namespace VT7.Host
{
    public partial class App
    {
        internal static string ReactivationLogDirectory { get; private set; } = "";
        private void StartReactivation(string[] args)
        {
            // This entry point exists only in the separate diagnostic assembly.
            string? output = null;
            var requested = false;
            var injectWork = false;
            var injectIdle = false;
            try
            {
                for (var i = 0; i < args.Length; ++i)
                {
                    switch (args[i])
                    {
                        case "--resource-reactivation":
                            if (requested) throw new ArgumentException("Duplicate mode.");
                            requested = true; break;
                        case "--diagnostics-output":
                            if (output != null || ++i == args.Length) throw new ArgumentException("Missing or duplicate output.");
                            output = args[i]; break;
                        case "--inject-workload-failure":
                            if (injectWork) throw new ArgumentException("Duplicate injection.");
                            injectWork = true; break;
                        case "--inject-stability-failure":
                            if (injectIdle) throw new ArgumentException("Duplicate injection.");
                            injectIdle = true; break;
                        default: throw new ArgumentException("Unknown diagnostic option.");
                    }
                }
                if (!requested || output == null || !Path.IsPathRooted(output) || (injectWork && injectIdle))
                    throw new ArgumentException("Require --resource-reactivation --diagnostics-output <absolute new file>.");
                output = Path.GetFullPath(output);
                if (File.Exists(output) || !Directory.Exists(Path.GetDirectoryName(output)))
                    throw new ArgumentException("Output must be a new file in an existing directory.");
                ReactivationLogDirectory = output + ".wpf-probes";
                if (Directory.Exists(ReactivationLogDirectory) || File.Exists(ReactivationLogDirectory))
                    throw new ArgumentException("The companion WPF log directory must also be new.");
            }
            catch (Exception ex) when (ex is ArgumentException || ex is IOException || ex is NotSupportedException || ex is System.Security.SecurityException)
            { Shutdown(2); return; }
            RendererMode = 2;
            StabilityTest = true;
            StabilityLifecycle = true;
            CaptureFrames = true;
            SurfaceOptions = 2 | 0x100u;
            InjectStabilityFailure = injectIdle;
            ShutdownMode = ShutdownMode.OnExplicitShutdown;
            RunReactivationChecks(output, injectWork, injectIdle);
        }

        private async void RunReactivationChecks(string output, bool injectWork, bool injectIdle)
        {
            var exit = 1;
            try
            {
                using (var writer = new StreamWriter(new FileStream(output, FileMode.CreateNew, FileAccess.Write, FileShare.Read), new UTF8Encoding(false)) { AutoFlush = true })
                {
                    void Log(string value) => writer.WriteLine(value);
                    Log("VT7 WPF RESOURCE REACTIVATION 0.1");
                    Log(FormattableString.Invariant($"CONFIG rounds=2 warmup=2 cycles_per_round=100 renderer=2 capture=1 baseline=fixed idle_targets_ms=10000,90000,180000 inject_work={(injectWork ? 1 : 0)} inject_idle={(injectIdle ? 1 : 0)}"));
                    using (var process = Process.GetCurrentProcess())
                        Log(FormattableString.Invariant($"PROCESS pid={process.Id} creation={process.StartTime.ToUniversalTime().ToFileTimeUtc()} bits={IntPtr.Size * 8} host_version={Assembly.GetExecutingAssembly().GetName().Version}"));
                    Log("SAMPLING sequential_not_atomic=1 queue_failure_is_unknown=1 not_observed_is_not_exit_proof=1 debugger_required=0");
                    Log("HOST_BEHAVIOR window_loaded_probes=preserved status_refresh_logs=preserved proof_log_directory=" + Uri.EscapeDataString(ReactivationLogDirectory));
                    try
                    {
                        // Exactly the same startup probe suite, once, as the integrated host.
                        var probe = ProbeService.Capture();
                        Log("PROBE platform=" + probe.PlatformDisplay);
                        Log("PROBE native=" + probe.BuildDisplay);
                        Log("PROBE adapter=" + probe.AdapterDisplay);
                        Log("PROBE runtime=" + probe.RuntimeDisplay);
                        Log("PROBE core=" + probe.CoreTests.Replace("\r", "").Replace("\n", " | "));
                        if (!probe.Passed) throw new InvalidOperationException("Core/platform checks failed: " + probe.Error);
                        Log("STARTUP_CHECKS=PASS count=1");
                        var failures = await StabilityWindowChecks.RunReactivation(Log, injectWork);
                        Log(FormattableString.Invariant($"COLLECTION=COMPLETE rounds=2 warmup=2 measured_lifecycles=200 resource_budget_failures={failures}"));
                        Log("C3_RESOURCE_VERDICT=" + (failures == 0 ? "WITHIN_IMMEDIATE_BUDGETS" : "FAIL") + "; INTEGRATED_ACCEPTANCE=OPEN; TIMED_SOAK=NOT_RUN");
                        exit = failures == 0 ? 0 : 3;
                    }
                    catch (Exception ex)
                    {
                        Log("ERROR " + ex.ToString().Replace("\r", "").Replace("\n", " | "));
                        Log("COLLECTION=INCOMPLETE; INTEGRATED_ACCEPTANCE=OPEN");
                    }
                    Log("EXIT code=" + exit.ToString(CultureInfo.InvariantCulture));
                }
            }
            catch (Exception) { exit = 2; }
            Shutdown(exit);
        }
    }
}
