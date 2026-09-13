# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Windows PowerShell 2.0 and C# 3 compatible. Debugs only the child it launches.
param([string]$CdbPath, [switch]$PreflightOnly)
$ErrorActionPreference = 'Stop'
$vt7Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$vt7Run = Join-Path (Join-Path $vt7Root 'Logs') ('resource-retirement-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$vt7Exit = 1
function Get-VT7RetirementHash {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $algorithm = New-Object Security.Cryptography.SHA256CryptoServiceProvider
    try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '') }
    finally { $algorithm.Clear(); $stream.Dispose() }
}
function Quote-VT7RetirementArgument {
    param([string]$Value)
    if ($Value -match '["\r\n]' -or $Value.EndsWith('\')) { throw 'Unsupported debugger argument path.' }
    return '"' + $Value + '"'
}
try {
    New-Item -ItemType Directory -Path $vt7Run | Out-Null
    $vt7Summary = Join-Path $vt7Run 'summary.txt'
    [IO.File]::WriteAllLines($vt7Summary, [string[]]@(
        'VT7 resource retirement 0.1: new sampler and unchanged native 0.3.5 DLL.',
        'Stages: debugger preflight; startup control without setup/handle tracing; full trace with handle tracing activated at pre-warmup.',
        'Process-scoped CDB trace; reuse, 2 warm-up + 25 measured iterations, then final close + 10/90/180 seconds.',
        'Collection completion is not ownership attribution or resource acceptance.',
        ('PowerShell=' + $PSVersionTable.PSVersion.ToString()),
        ('OS=' + [Environment]::OSVersion.ToString()),
        ('PointerBytes=' + [IntPtr]::Size.ToString()),
        ('Package=' + $vt7Root)
    ), [Text.Encoding]::UTF8)
    Write-Host "Logs: $vt7Run"
    if ([IntPtr]::Size -ne 8) { throw 'Use 64-bit Windows PowerShell for this x64 diagnostic.' }
    if ($vt7Root -match '[;"\r\n]') { throw 'Extract into a path without semicolons, quotation marks or newlines.' }
    $vt7Manifest = Join-Path $vt7Root 'SHA256SUMS.txt'
    if (-not (Test-Path -LiteralPath $vt7Manifest -PathType Leaf)) { throw 'Package SHA256SUMS.txt is missing.' }
    $vt7Seen = @{}
    foreach ($vt7Line in [IO.File]::ReadAllLines($vt7Manifest)) {
        if ($vt7Line -notmatch '^([A-Fa-f0-9]{64})  (.+)$') { throw 'Malformed package checksum entry.' }
        $vt7Expected = $Matches[1]
        $vt7Relative = $Matches[2]
        if ([IO.Path]::IsPathRooted($vt7Relative) -or $vt7Relative.Contains(':') -or
            $vt7Relative -match '(^|[\\/])\.\.?([\\/]|$)' -or $vt7Seen.ContainsKey($vt7Relative)) {
            throw "Invalid checksum path: $vt7Relative"
        }
        $vt7Seen[$vt7Relative] = $vt7Expected
        if ((Get-VT7RetirementHash (Join-Path $vt7Root $vt7Relative)) -ne $vt7Expected) { throw "Package checksum mismatch: $vt7Relative" }
    }
    # Pin the new exported sampler and unchanged native payload independently.
    $vt7Pinned = @{
        'VT7.ResourceRetirement.exe' = '9F07A67AC9A4B0226BAFD1E313E47DF2D9D426C5A0555377B6AD647A3F886FD4'
        'VT7.Native.dll' = '0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49'
        'symbols/VT7.ResourceRetirement.pdb' = 'CDA8F9C462B0DC89CF2D571B3AC27F4696F31774EEA18E5B9616B140261F97E0'
        'symbols/VT7.Native.pdb' = 'C835ED74D7E119F0601AD1CE1DE8A70349BADD443D041E467756705CC8B6AAEE'
    }
    foreach ($vt7Relative in $vt7Pinned.Keys) {
        if ((Get-VT7RetirementHash (Join-Path $vt7Root $vt7Relative)) -ne $vt7Pinned[$vt7Relative]) { throw "Pinned input mismatch: $vt7Relative" }
    }
    foreach ($vt7Relative in @('preflight.cdb', 'startup.cdb', 'retirement.cdb', 'warp-load.cdb', 'warp-verify.cdb', 'warp-hooks.cdb', 'Validate-ResourceRetirement.ps1', 'Run-ResourceRetirement.ps1')) {
        if (-not $vt7Seen.ContainsKey($vt7Relative)) { throw "Missing trace checksum: $vt7Relative" }
    }
    Copy-Item -LiteralPath $vt7Manifest -Destination (Join-Path $vt7Run 'package-SHA256SUMS.txt')
    foreach ($vt7Relative in @('preflight.cdb', 'startup.cdb', 'retirement.cdb', 'warp-load.cdb', 'warp-verify.cdb', 'warp-hooks.cdb')) {
        Copy-Item -LiteralPath (Join-Path $vt7Root $vt7Relative) -Destination $vt7Run
        if ((Get-VT7RetirementHash (Join-Path $vt7Run $vt7Relative)) -ne $vt7Seen[$vt7Relative]) { throw "Copied command file changed: $vt7Relative" }
    }
    . (Join-Path $vt7Root 'Validate-ResourceRetirement.ps1')
    if (-not $CdbPath) {
        $CdbPath = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\8.1\Debuggers\x64\cdb.exe'
    }
    if (-not (Test-Path -LiteralPath $CdbPath -PathType Leaf)) {
        throw 'Classic x64 CDB is missing. Install only Debugging Tools for Windows from the Windows 8.1 SDK; see README.txt. For a custom location use -CdbPath.'
    }
    $CdbPath = [IO.Path]::GetFullPath($CdbPath)
    $vt7CdbBytes = [IO.File]::ReadAllBytes($CdbPath)
    if ($vt7CdbBytes.Length -lt 64) { throw 'CDB is not a valid x64 executable.' }
    $vt7PeOffset = [BitConverter]::ToInt32($vt7CdbBytes, 60)
    if ($vt7PeOffset -lt 0 -or $vt7PeOffset + 6 -gt $vt7CdbBytes.Length -or
        [BitConverter]::ToUInt32($vt7CdbBytes, $vt7PeOffset) -ne 17744 -or
        [BitConverter]::ToUInt16($vt7CdbBytes, $vt7PeOffset + 4) -ne 34404) { throw 'CDB must be an x64 PE executable.' }
    $vt7CdbRoot = Split-Path -Parent $CdbPath
    foreach ($vt7DebuggerFile in @('cdb.exe', 'dbgeng.dll', 'dbghelp.dll', 'winext\ext.dll', 'winxp\exts.dll')) {
        $vt7DebuggerPath = Join-Path $vt7CdbRoot $vt7DebuggerFile
        if (Test-Path -LiteralPath $vt7DebuggerPath -PathType Leaf) {
            Add-Content -LiteralPath $vt7Summary -Value ('DEBUGGER file=' + $vt7DebuggerPath + ' version=' + [Diagnostics.FileVersionInfo]::GetVersionInfo($vt7DebuggerPath).FileVersion + ' SHA256=' + (Get-VT7RetirementHash $vt7DebuggerPath))
        }
    }
    $vt7SystemWarp = Join-Path ([Environment]::SystemDirectory) 'D3D10Warp.dll'
    if (Test-Path -LiteralPath $vt7SystemWarp -PathType Leaf) {
        Add-Content -LiteralPath $vt7Summary -Value ('SYSTEM_WARP file=' + $vt7SystemWarp + ' version=' + [Diagnostics.FileVersionInfo]::GetVersionInfo($vt7SystemWarp).FileVersion + ' SHA256=' + (Get-VT7RetirementHash $vt7SystemWarp))
    }
    Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
public static class VT7RetirementProcess
{
    public static int Run(string exe, string arguments, string directory, string stdout, string stderr, int timeout, string fallbackCommand)
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
            child.StartInfo.RedirectStandardInput = !String.IsNullOrEmpty(fallbackCommand);
            // Do not inherit a symbol server and stall inside a frame deadline.
            foreach (string name in new string[] { "_NT_SYMBOL_PATH", "_NT_ALT_SYMBOL_PATH", "_NT_EXECUTABLE_IMAGE_PATH", "_NT_SOURCE_PATH" })
                child.StartInfo.EnvironmentVariables.Remove(name);
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
                if (!started) throw new InvalidOperationException("Could not start CDB.");
                child.BeginOutputReadLine();
                child.BeginErrorReadLine();
                if (child.StartInfo.RedirectStandardInput)
                {
                    // -cf handles the initial break. This queued line is read only
                    // if CDB later asks for an interactive command. Record that
                    // unexpected stop and end this run instead of waiting 10 minutes.
                    child.StandardInput.WriteLine(fallbackCommand);
                    child.StandardInput.Flush();
                    child.StandardInput.Close();
                }
                if (!child.WaitForExit(timeout)) throw new TimeoutException("CDB timeout; partial logs retained.");
                child.WaitForExit();
                lock (sync) { if (writeError != null) throw new IOException("Could not preserve trace output.", writeError); }
                return child.ExitCode;
            }
            finally
            {
                // CDB's normal debug-child ownership terminates its debuggee when
                // the debugger exits. No attach, -pd, detach or .detach is used.
                if (started && !child.HasExited)
                {
                    child.Kill();
                    if (!child.WaitForExit(5000)) throw new TimeoutException("Could not terminate this run's CDB.");
                    child.WaitForExit();
                }
            }
        }
    }
}
'@
    foreach ($vt7Stage in @('preflight', 'startup', 'retirement')) {
        $vt7Combined = Join-Path $vt7Run ($vt7Stage + '-combined.log')
        $vt7Stderr = Join-Path $vt7Run ($vt7Stage + '-stderr.log')
        $vt7DebuggerLog = Join-Path $vt7Run ($vt7Stage + '-debugger.log')
        $vt7Arguments = '-G -y ' + (Quote-VT7RetirementArgument (Join-Path $vt7Root 'symbols')) +
            ' -logo ' + (Quote-VT7RetirementArgument $vt7DebuggerLog) +
            ' -cf ' + (Quote-VT7RetirementArgument (Join-Path $vt7Run ($vt7Stage + '.cdb'))) +
            ' ' + (Quote-VT7RetirementArgument (Join-Path $vt7Root 'VT7.ResourceRetirement.exe')) +
            ' ' + (Quote-VT7RetirementArgument (Join-Path $vt7Root 'VT7.Native.dll')) + ' reuse --cycles 25'
        Add-Content -LiteralPath $vt7Summary -Value ('COMMAND ' + (Quote-VT7RetirementArgument $CdbPath) + ' ' + $vt7Arguments)
        Write-Host "Running $vt7Stage..."
        $vt7Timeout = 600000
        $vt7Fallback = ''
        if ($vt7Stage -ne 'retirement') { $vt7Timeout = 60000 }
        if ($vt7Stage -ne 'preflight') { $vt7Fallback = '.echo; .echo VT7_TRACE_ABORT_UNEXPECTED_STOP; .lastevent; .exr -1; r; k 0n24; lmv; q' }
        $vt7Code = [VT7RetirementProcess]::Run($CdbPath, $vt7Arguments, $vt7Run, $vt7Combined, $vt7Stderr, $vt7Timeout, $vt7Fallback)
        Add-Content -LiteralPath $vt7Summary -Value ("$vt7Stage CDB_exit=$vt7Code")
        if ($vt7Code -ne 0) { throw "$vt7Stage debugger exited $vt7Code." }
        if ([IO.File]::ReadAllText($vt7Stderr).Trim().Length -ne 0) { throw "$vt7Stage wrote stderr; preserve logs for review." }
        $vt7Text = [IO.File]::ReadAllText($vt7Combined)
        if ($vt7Stage -eq 'preflight') {
            Assert-VT7RetirementPreflight $vt7Text
            Add-Content -LiteralPath $vt7Summary -Value 'PREFLIGHT=COMPLETE'
            if ($PreflightOnly) {
                Add-Content -LiteralPath $vt7Summary -Value 'COLLECTION=NOT_RUN; requested preflight only'
                break
            }
        }
        elseif ($vt7Stage -eq 'startup') {
            Assert-VT7RetirementStartup $vt7Text
            Add-Content -LiteralPath $vt7Summary -Value 'STARTUP_CONTROL=COMPLETE; stopped at pre-warmup before sampling or surface creation; no USER32 setup or handle tracing'
        }
        else {
            Assert-VT7ResourceRetirement $vt7Text
            Add-Content -LiteralPath $vt7Summary -Value ('TARGET_EVIDENCE=' + (Get-VT7RetirementTargetStatus $vt7Text))
            Add-Content -LiteralPath $vt7Summary -Value 'COLLECTION=COMPLETE; OWNERSHIP=REQUIRES_REVIEW; RESOURCE_ACCEPTANCE=OPEN'
            $vt7InvalidCount = [regex]::Match($vt7Text, '(?m)^VT7_TRACE_EXIT .+ invalid_handles=([0-9]+)\r?$').Groups[1].Value
            Add-Content -LiteralPath $vt7Summary -Value ('FIRST_CHANCE_INVALID_HANDLES=' + $vt7InvalidCount + '; any recorded exception still requires review')
        }
    }
    $vt7Exit = 0
}
catch {
    Write-Host "INCOMPLETE: $($_.Exception.Message)"
    if ($vt7Summary -and (Test-Path -LiteralPath $vt7Summary)) {
        Add-Content -LiteralPath $vt7Summary -Value ('INCOMPLETE: ' + $_.Exception.Message)
    }
}
finally {
    if (Test-Path -LiteralPath $vt7Run) {
        Write-Host "Return the entire log folder: $vt7Run"
        if ($vt7Summary -and (Test-Path -LiteralPath $vt7Summary)) { Add-Content -LiteralPath $vt7Summary -Value "Launcher_exit=$vt7Exit" }
    }
}
exit $vt7Exit
