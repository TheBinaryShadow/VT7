# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Windows PowerShell 2.0 compatible; fixed protocol, one owned child process.
param()
$ErrorActionPreference = 'Stop'
$vt7Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$vt7Run = Join-Path (Join-Path $vt7Root 'Logs') ('resource-reactivation-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$vt7Exit = 1
$vt7Child = $null
function Get-VT7ReactivationHash {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $algorithm = New-Object Security.Cryptography.SHA256CryptoServiceProvider
    try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '') }
    finally { $algorithm.Clear(); $stream.Dispose() }
}
try {
    New-Item -ItemType Directory -Path $vt7Run | Out-Null
    $vt7Summary = Join-Path $vt7Run 'summary.txt'
    [IO.File]::WriteAllLines($vt7Summary, [string[]]@(
        'VT7 WPF resource reactivation 0.1; unchanged native 0.3.5/ABI 8.',
        'One process; two warm-up lifetimes once; two 100-lifecycle batches with closed+10/90/180s observations after each.',
        'Fixed initial baseline and all eight immediate resource verdicts; collection completion is separate from resource acceptance.',
        ('StartedUtc=' + [DateTime]::UtcNow.ToString('o')),
        ('PowerShell=' + $PSVersionTable.PSVersion.ToString()),
        ('OS=' + [Environment]::OSVersion.ToString()),
        ('Package=' + $vt7Root)
    ), [Text.Encoding]::UTF8)
    Write-Host "Logs: $vt7Run"
    if ($args.Count -ne 0) { throw 'This launcher accepts no protocol overrides.' }
    if ([IntPtr]::Size -ne 8) { throw 'Use 64-bit Windows PowerShell for this x64 diagnostic.' }
    if ($vt7Root -match '["\r\n]') { throw 'Extract into a path without quotation marks or newlines.' }
    $vt7Manifest = Join-Path $vt7Root 'SHA256SUMS.txt'
    $vt7Seen = @{}
    foreach ($vt7Line in [IO.File]::ReadAllLines($vt7Manifest)) {
        if ($vt7Line -notmatch '^([a-fA-F0-9]{64})  (.+)$') { throw 'Malformed package checksum entry.' }
        $vt7Hash = $Matches[1]; $vt7Relative = $Matches[2]
        if ([IO.Path]::IsPathRooted($vt7Relative) -or $vt7Relative.Contains(':') -or $vt7Relative.Contains('\') -or
            $vt7Relative -match '(^|/)\.\.?(/|$)' -or $vt7Relative.Contains('//') -or $vt7Relative.EndsWith('/') -or $vt7Seen.ContainsKey($vt7Relative)) { throw 'Invalid or duplicate checksum path.' }
        $vt7Seen[$vt7Relative] = $vt7Hash
        if ((Get-VT7ReactivationHash (Join-Path $vt7Root $vt7Relative)) -ne $vt7Hash) { throw "Package checksum mismatch: $vt7Relative" }
    }
    $vt7Pinned = @{
        'VT7.ResourceReactivation.exe' = '324D29DE31F3B5A10F802D6C0BEA9603EE07098C61F47996C9398BACEC45F843'
        'VT7.Native.dll' = '0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49'
        'VT7.ResourceReactivation.exe.config' = '051099983B896673909E01A1F631B6652ABB88DA95C9F06F3EFEF4BE033091FA'
    }
    foreach ($vt7Relative in $vt7Pinned.Keys) {
        if (!$vt7Seen.ContainsKey($vt7Relative) -or $vt7Seen[$vt7Relative] -ne $vt7Pinned[$vt7Relative]) { throw "Pinned package identity mismatch: $vt7Relative" }
    }
    foreach ($vt7Relative in @('Run-ResourceReactivation.ps1','Validate-ResourceReactivation.ps1','Wait-ResourceReactivation.ps1','RUN-RESOURCE-REACTIVATION.cmd','README.txt','PACKAGE-MANIFEST.json')) {
        if (!$vt7Seen.ContainsKey($vt7Relative)) { throw "Missing required checksum: $vt7Relative" }
    }
    Copy-Item -LiteralPath $vt7Manifest -Destination (Join-Path $vt7Run 'package-SHA256SUMS.txt')
    Copy-Item -LiteralPath (Join-Path $vt7Root 'PACKAGE-MANIFEST.json') -Destination $vt7Run
    Copy-Item -LiteralPath (Join-Path $vt7Root 'Validate-ResourceReactivation.ps1') -Destination $vt7Run
    . (Join-Path $vt7Run 'Validate-ResourceReactivation.ps1')
    . (Join-Path $vt7Root 'Wait-ResourceReactivation.ps1')
    $vt7Warp = Join-Path ([Environment]::SystemDirectory) 'D3D10Warp.dll'
    Add-Content -LiteralPath $vt7Summary -Value ('SYSTEM_WARP version=' + [Diagnostics.FileVersionInfo]::GetVersionInfo($vt7Warp).FileVersion + ' SHA256=' + (Get-VT7ReactivationHash $vt7Warp))
    $vt7Report = Join-Path $vt7Run 'reactivation.log'
    $vt7Start = New-Object Diagnostics.ProcessStartInfo
    $vt7Start.FileName = Join-Path $vt7Root 'VT7.ResourceReactivation.exe'
    $vt7Start.Arguments = '--resource-reactivation --diagnostics-output "' + $vt7Report + '"'
    $vt7Start.WorkingDirectory = $vt7Root; $vt7Start.UseShellExecute = $false
    $vt7Start.CreateNoWindow = $true; $vt7Start.WindowStyle = 'Hidden'
    $vt7Child = New-Object Diagnostics.Process
    $vt7Child.StartInfo = $vt7Start
    if (!$vt7Child.Start()) { throw 'Could not start the diagnostic.' }
    Add-Content -LiteralPath $vt7Summary -Value ('PROCESS pid=' + $vt7Child.Id + ' creation=' + $vt7Child.StartTime.ToUniversalTime().ToFileTimeUtc())
    Write-Host 'Running both WPF lifecycle batches and idle observations. No debugger is needed.'
    Write-Host 'Allow up to 40 minutes. Leave this window open; progress is written to reactivation.log.'
    $vt7Elapsed = Wait-VT7ReactivationExit $vt7Child 2400
    $vt7ChildExit = $vt7Child.ExitCode
    Add-Content -LiteralPath $vt7Summary -Value ('PROCESS_EXIT code=' + $vt7ChildExit + ' elapsed_ms=' + $vt7Elapsed)
    $vt7Result = Test-VT7ReactivationReport $vt7Report $vt7ChildExit
    if ([int]$vt7Result.ProcessId -ne $vt7Child.Id) { throw 'Report process identity differs from the launched child.' }
    Add-Content -LiteralPath $vt7Summary -Value ('REPORT_SHA256=' + (Get-VT7ReactivationHash $vt7Report))
    Add-Content -LiteralPath $vt7Summary -Value $vt7Result.Samples
    Add-Content -LiteralPath $vt7Summary -Value ('COLLECTION=COMPLETE resource_budget_failures=' + $vt7Result.BudgetFailures + ' resource_verdict=' + $vt7Result.Verdict + '; C3 remains open; timed soak not run.')
    $vt7Exit = $vt7ChildExit
    Write-Host ('Collection complete. Immediate resource-budget failures retained: ' + $vt7Result.BudgetFailures + ' of 8.')
} catch {
    if (Test-Path -LiteralPath $vt7Run) {
        [IO.File]::WriteAllText((Join-Path $vt7Run 'collector-error.txt'), $_.ToString(), [Text.Encoding]::UTF8)
    }
    Write-Host ('INCOMPLETE: ' + $_.Exception.Message)
} finally {
    if ($vt7Child -ne $null) {
        try { if (!$vt7Child.HasExited) { $vt7Child.Kill(); $vt7Child.WaitForExit() } } catch { Write-Host ('Child cleanup: ' + $_.Exception.Message) }
        $vt7Child.Dispose()
    }
}
Write-Host "Return this entire log folder: $vt7Run"
exit $vt7Exit
