# Developer controls; syntax and execution compatible with Windows PowerShell 2.
param([string]$BinaryDirectory, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
trap { [Console]::Error.WriteLine($_.ToString()); exit 1 }
$root = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..'))
. (Join-Path $root 'src/vt7/VT7.ResourceReactivation/Wait-ResourceReactivation.ps1')
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Control output must be new.' }
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
$results = New-Object Collections.Generic.List[string]
$results.Add('PowerShell=' + $PSVersionTable.PSVersion)
function New-ControlProcess { param([string]$File, [string]$Arguments)
    $child = New-Object Diagnostics.Process
    $child.StartInfo.FileName = $File; $child.StartInfo.Arguments = $Arguments
    $child.StartInfo.UseShellExecute = $false; $child.StartInfo.CreateNoWindow = $true; $child.StartInfo.WindowStyle = 'Hidden'
    if (!$child.Start()) { throw 'Control process did not start.' }
    return $child
}
function Hash-Control { param([string]$Path)
    $stream = [IO.File]::OpenRead($Path); $sha = New-Object Security.Cryptography.SHA256CryptoServiceProvider
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') } finally { $sha.Clear(); $stream.Dispose() }
}
$executable = Join-Path $BinaryDirectory 'VT7.ResourceReactivation.exe'
$cases = @('', '--cycles 2', '--idle-seconds 0', '--renderer atlas-d3d-hardware', '--stability-soak', '--resource-reactivation', '--inject-workload-failure --inject-stability-failure')
for ($i = 0; $i -lt $cases.Count; ++$i) {
    $report = Join-Path $OutputDirectory ('cli-' + $i + '.log')
    $arguments = '--resource-reactivation --diagnostics-output "' + $report + '" ' + $cases[$i]
    if ($i -eq 0) { $arguments = '--diagnostics-output "' + $report + '"' }
    $child = New-ControlProcess $executable $arguments
    try {
        [void](Wait-VT7ReactivationExit $child 15)
        if ($child.ExitCode -ne 2 -or (Test-Path -LiteralPath $report)) { throw "CLI control $i was accepted." }
        $results.Add('PASS CLI rejection ' + $i)
    } finally { if (!$child.HasExited) { $child.Kill(); $child.WaitForExit() }; $child.Dispose() }
}
$existing = Join-Path $OutputDirectory 'existing.log'
[IO.File]::WriteAllText($existing, 'preserve original bytes')
$child = New-ControlProcess $executable ('--resource-reactivation --diagnostics-output "' + $existing + '"')
try {
    [void](Wait-VT7ReactivationExit $child 15)
    if ($child.ExitCode -ne 2 -or [IO.File]::ReadAllText($existing) -ne 'preserve original bytes') { throw 'Existing output was not preserved.' }
    $results.Add('PASS existing output preserved')
} finally { if (!$child.HasExited) { $child.Kill(); $child.WaitForExit() }; $child.Dispose() }
foreach ($code in @(0,3)) {
    $child = New-ControlProcess (Join-Path ([Environment]::SystemDirectory) 'cmd.exe') ('/d /c exit /b ' + $code)
    try { [void](Wait-VT7ReactivationExit $child 5); if ($child.ExitCode -ne $code) { throw 'Exit code lost.' }; $results.Add('PASS wait preserves exit ' + $code) }
    finally { if (!$child.HasExited) { $child.Kill(); $child.WaitForExit() }; $child.Dispose() }
}
$shell = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell/v1.0/powershell.exe'
$child = $null; $bystander = $null
try {
    $child = New-ControlProcess $shell '-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 60"'
    $bystander = New-ControlProcess $shell '-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 60"'
    $caught = $false
    try { [void](Wait-VT7ReactivationExit $child 1) } catch { $caught = $_.Exception.Message.Contains('owned child was terminated') }
    if (!$caught -or !$child.HasExited -or $bystander.HasExited) { throw 'Bounded owned-child timeout failed.' }
    $results.Add('PASS timeout terminates only owned child; other fixture remains alive')
} finally {
    foreach ($owned in @($child, $bystander)) { if ($owned -ne $null) { if (!$owned.HasExited) { $owned.Kill(); $owned.WaitForExit() }; $owned.Dispose() } }
}
foreach ($case in @('bad-hash','missing-pins','traversal','duplicate','override')) {
    $stage = Join-Path $OutputDirectory ('package-' + $case)
    New-Item -ItemType Directory -Path $stage | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'src/vt7/VT7.ResourceReactivation/Run-ResourceReactivation.ps1') -Destination $stage
    $probe = Join-Path $stage 'probe.txt'; [IO.File]::WriteAllText($probe, 'fixture')
    $entry = (Hash-Control $probe) + '  probe.txt'
    if ($case -eq 'bad-hash') { $entry = ('0' * 64) + '  probe.txt' }
    if ($case -eq 'traversal') { $entry = ('0' * 64) + '  ../probe.txt' }
    if ($case -eq 'duplicate') { $entry = $entry + "`r`n" + $entry }
    [IO.File]::WriteAllText((Join-Path $stage 'SHA256SUMS.txt'), $entry)
    $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass'
    if ($PSVersionTable.PSVersion.Major -eq 2) { $arguments = '-Version 2 ' + $arguments }
    $arguments += ' -File "' + (Join-Path $stage 'Run-ResourceReactivation.ps1') + '"'
    if ($case -eq 'override') { $arguments += ' --cycles 1' }
    $child = New-ControlProcess $shell $arguments
    try {
        [void](Wait-VT7ReactivationExit $child 15)
        $runs = @(Get-ChildItem -LiteralPath (Join-Path $stage 'Logs'))
        if ($child.ExitCode -ne 1 -or $runs.Count -ne 1 -or !(Test-Path -LiteralPath (Join-Path $runs[0].FullName 'collector-error.txt'))) { throw "Runner did not reject $case." }
        $reason = [IO.File]::ReadAllText((Join-Path $runs[0].FullName 'collector-error.txt'))
        $expected = @{ 'bad-hash' = 'Package checksum mismatch'; 'missing-pins' = 'Pinned package identity mismatch'; 'traversal' = 'Invalid or duplicate checksum path'; 'duplicate' = 'Invalid or duplicate checksum path'; 'override' = 'accepts no protocol overrides' }
        if (!$reason.Contains($expected[$case])) { throw "Wrong rejection reason for $case : $reason" }
        $summary = [IO.File]::ReadAllText((Join-Path $runs[0].FullName 'summary.txt'))
        if ($summary.Contains('PROCESS pid=')) { throw 'Preflight rejection launched the diagnostic.' }
        $results.Add('PASS runner rejects ' + $case + ' before child launch')
    } finally { if (!$child.HasExited) { $child.Kill(); $child.WaitForExit() }; $child.Dispose() }
}
$results.Add('ALL CONTROLS PASSED')
[IO.File]::WriteAllLines((Join-Path $OutputDirectory 'RESULT.txt'), $results.ToArray(), [Text.Encoding]::UTF8)
$results
