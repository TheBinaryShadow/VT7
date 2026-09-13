# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Windows PowerShell 2.0 compatible; no system configuration is changed.
param()
$ErrorActionPreference = 'Stop'
$vt7Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$vt7LogRoot = Join-Path $vt7Root 'Logs'
$vt7Run = Join-Path $vt7LogRoot ('resource-lifetime-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$vt7Exit = 0
try {
    # PS2 puts WindowStyle and stream redirection in different Start-Process
    # parameter sets. This wrapper keeps the native child hidden, drains both
    # pipes concurrently, and retains its actual process handle through exit.
    Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
public static class VT7LifetimeProcess
{
    public static int Run(string exe, string arguments, string directory, string stdout, string stderr)
    {
        using (StreamWriter output = new StreamWriter(new FileStream(stdout, FileMode.CreateNew), new UTF8Encoding(false)))
        using (StreamWriter error = new StreamWriter(new FileStream(stderr, FileMode.CreateNew), new UTF8Encoding(false)))
        using (Process child = new Process())
        {
            output.AutoFlush = true;
            error.AutoFlush = true;
            object sync = new object();
            Exception writeError = null;
            child.StartInfo = new ProcessStartInfo(exe, arguments);
            child.StartInfo.WorkingDirectory = directory;
            child.StartInfo.UseShellExecute = false;
            child.StartInfo.CreateNoWindow = true;
            child.StartInfo.RedirectStandardOutput = true;
            child.StartInfo.RedirectStandardError = true;
            child.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) {
                if (e.Data == null) return;
                lock (sync) { try { output.WriteLine(e.Data); } catch (Exception ex) { writeError = ex; } }
            };
            child.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) {
                if (e.Data == null) return;
                lock (sync) { try { error.WriteLine(e.Data); } catch (Exception ex) { writeError = ex; } }
            };
            bool started = false;
            try
            {
                started = child.Start();
                if (!started) throw new InvalidOperationException("Could not start diagnostic child.");
                child.BeginOutputReadLine();
                child.BeginErrorReadLine();
                if (!child.WaitForExit(600000))
                {
                    child.Kill();
                    if (!child.WaitForExit(5000)) throw new TimeoutException("Diagnostic did not exit after termination.");
                    child.WaitForExit();
                    throw new TimeoutException("Diagnostic exceeded 600 seconds; child terminated and partial logs retained.");
                }
                child.WaitForExit();
                lock (sync) { if (writeError != null) throw new IOException("Could not preserve diagnostic output.", writeError); }
                return child.ExitCode;
            }
            finally
            {
                if (started && !child.HasExited)
                {
                    child.Kill();
                    if (!child.WaitForExit(5000)) throw new TimeoutException("Diagnostic cleanup could not terminate its child.");
                    child.WaitForExit();
                }
            }
        }
    }
}
'@
    foreach ($vt7File in @('VT7.ResourceLifetime.exe', 'VT7.Native.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'fonts\unifont-17.0.05.otf', 'fonts\unifont_upper-17.0.05.otf')) {
        if (-not (Test-Path -LiteralPath (Join-Path $vt7Root $vt7File) -PathType Leaf)) { throw "Missing package file: $vt7File" }
    }
    New-Item -ItemType Directory -Path $vt7Run | Out-Null
    $vt7Summary = Join-Path $vt7Run 'summary.txt'
    $vt7SummaryLines = @(
        'VT7 resource lifetime comparison 0.2',
        'Recreate then reuse in separate processes. Forced Atlas D3D11 WARP; power subscriptions off.',
        'Two warm-up and 100 measured iterations in each mode. Timeout: 600 seconds per process.',
        'Exit 0 means complete measurements, not resource-growth acceptance.',
        'Thread snapshots and process counters are sequential. Failed GUI queries do not establish queue absence.'
    )
    [IO.File]::WriteAllLines($vt7Summary, [string[]]$vt7SummaryLines, [Text.Encoding]::UTF8)
    Write-Host 'Running the bounded WARP comparison. No visible application window is expected.'
    Write-Host "Logs: $vt7Run"
    foreach ($vt7Mode in @('recreate', 'reuse')) {
        $vt7Log = Join-Path $vt7Run ($vt7Mode + '.log')
        $vt7ErrorLog = Join-Path $vt7Run ($vt7Mode + '.stderr.log')
        try {
            Write-Host "Running $vt7Mode..."
            $vt7Args = '"' + (Join-Path $vt7Root 'VT7.Native.dll') + '" ' + $vt7Mode
            $vt7ProcessExit = [VT7LifetimeProcess]::Run((Join-Path $vt7Root 'VT7.ResourceLifetime.exe'), $vt7Args, $vt7Root, $vt7Log, $vt7ErrorLog)
            Add-Content -LiteralPath $vt7Summary -Value ("{0}: process_exit={1}" -f $vt7Mode, $vt7ProcessExit)
            if ($vt7ProcessExit -ne 0) { throw "Process exited $vt7ProcessExit." }
            $vt7Text = [IO.File]::ReadAllText($vt7Log)
            if ([IO.File]::ReadAllText($vt7ErrorLog).Trim().Length -ne 0) { throw 'Process wrote unexpected stderr output.' }
            if ($vt7Text -match '(?m)^(FAIL |INCOMPLETE:)') { throw 'Diagnostic reported an incomplete workload.' }
            $vt7ExpectedCreates = 102
            if ($vt7Mode -eq 'reuse') { $vt7ExpectedCreates = 1 }
            $vt7Required = @(
                '(?m)^VT7 RESOURCE LIFETIME 0\.2;',
                ('(?m)^CONFIG mode=' + $vt7Mode + ' renderer=2 capture=1 power=0 probes=0 warmup=2 cycles=100 fail_at_cycle=0\r?$'),
                '(?m)^NATIVE 0\.3\.5 ABI=8 Release ',
                '(?m)^SAMPLING sequential_not_atomic=1 ',
                '(?m)^ATTRIBUTION samples=9 identities=[1-9][0-9]* identity_unavailable=[0-9]+;',
                ('(?m)^WORKLOAD iterations=102 creates=' + $vt7ExpectedCreates + ' destroys=' + $vt7ExpectedCreates + ' resizes=1020 size_resets=102 hide_show=510 power_registrations=0 power_unregistrations=0 power_delivered=0\r?$'),
                '(?m)^COMPLETED: measurement only, not stability acceptance\. No soak performed\.\r?$'
            )
            foreach ($vt7Pattern in $vt7Required) {
                if ([regex]::Matches($vt7Text, $vt7Pattern).Count -ne 1) { throw "Missing or duplicated marker: $vt7Pattern" }
            }
            $vt7Phases = @('pre-warmup iteration=0 live=0', 'warmup-live iteration=0 live=1', 'baseline-live iteration=0 live=1',
                'measured-live iteration=25 live=1', 'measured-live iteration=50 live=1', 'measured-live iteration=75 live=1',
                'measured-live iteration=100 live=1', 'final-closed iteration=100 live=0', 'final-closed-10s iteration=100 live=0')
            if ([regex]::Matches($vt7Text, '(?m)^RESOURCE ').Count -ne 9) { throw 'Expected exactly nine resource samples.' }
            for ($vt7Index = 0; $vt7Index -lt $vt7Phases.Count; ++$vt7Index) {
                $vt7Sample = $vt7Index + 1
                $vt7Pattern = '(?m)^RESOURCE sample=' + $vt7Sample + ' phase=' + [regex]::Escape($vt7Phases[$vt7Index]) + ' private=[0-9]+ handles=[0-9]+ GDI=[0-9]+ USER=[0-9]+ threads=([0-9]+) begin_ms=[0-9]+ end_ms=[0-9]+\r?$'
                $vt7Match = [regex]::Match($vt7Text, $vt7Pattern)
                if (-not $vt7Match.Success) { throw "Missing or malformed resource sample $vt7Sample." }
                $vt7ThreadRows = [regex]::Matches($vt7Text, ('(?m)^THREAD sample=' + $vt7Sample + ' tid=[0-9]+ creation=[0-9A-F]{16} identity_error=[0-9]+ observation=\S+ first_sample=[0-9]+ queue=(observed|unavailable) queue_error=[0-9]+ first_queue_sample=[0-9]+ alive_before=[0-9]+ alive_after=[0-9]+ origin=.+ offset=[0-9A-F]+ start=[0-9A-F]+ origin_status=[0-9A-F]{8} module_error=[0-9]+\r?$'))
                if ($vt7ThreadRows.Count -ne [int]$vt7Match.Groups[1].Value -or $vt7ThreadRows.Count -eq 0) { throw "Incomplete thread rows for sample $vt7Sample." }
            }
            Add-Content -LiteralPath $vt7Summary -Value "$vt7Mode`: measurement_completed=YES; resource_growth_acceptance=NOT_EVALUATED"
            Write-Host "$vt7Mode measurements completed. Resource growth requires review."
        }
        catch {
            $vt7Exit = 1
            Add-Content -LiteralPath $vt7Summary -Value ("{0}: measurement_completed=NO; reason={1}" -f $vt7Mode, $_.Exception.Message)
            Write-Host "$vt7Mode INCOMPLETE: $($_.Exception.Message)"
        }
    }
    Add-Content -LiteralPath $vt7Summary -Value "Launcher exit: $vt7Exit"
    Write-Host "Return the entire log folder: $vt7Run"
}
catch {
    Write-Host "INCOMPLETE: $($_.Exception.Message)"
    $vt7Exit = 1
}
exit $vt7Exit
