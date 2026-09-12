[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [ValidateSet(0,96,120,144)][int]$ExpectedSystemDpi = 0
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\Settings"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$cases = @('atlas-auto','atlas-d3d-hardware','atlas-d3d-warp','atlas-d2d-hardware','atlas-d2d-warp')
$cases += 'geometry-negative','dpi-negative'
$measuredDpi = 0
foreach ($case in $cases) {
    $negative = $case.EndsWith('-negative')
    $mode = if ($negative) { 'atlas-d3d-warp' } else { $case }
    $report = Join-Path $reportRoot ($case + '.log')
    $arguments = '--settings-test --renderer ' + $mode + ' --diagnostics-output "' + $report + '"'
    if ($case -eq 'geometry-negative') { $arguments += ' --inject-settings-failure' }
    if ($case -eq 'dpi-negative') {
        $wrongDpi = if ($measuredDpi -eq 96) { 120 } else { 96 }
        $arguments += " --expected-system-dpi $wrongDpi"
    } elseif ($ExpectedSystemDpi) { $arguments += " --expected-system-dpi $ExpectedSystemDpi" }
    $started = Get-Date
    $process = Start-Process -FilePath (Join-Path $BinaryDirectory 'VT7.Host.exe') -ArgumentList $arguments -PassThru -WindowStyle Hidden
    try {
        if (!$process.WaitForExit(60000)) { $process.Kill(); throw "Settings test timed out: $case" }
        if (!(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTime -lt $started.AddSeconds(-2)) { throw "Missing/stale settings report: $case" }
        $text = [IO.File]::ReadAllText($report)
        if ($negative) {
            $marker = if ($case -eq 'geometry-negative') { 'Settings geometry mismatch: WPF/native client pixels disagree' } else { 'Expected system DPI' }
            if ($process.ExitCode -ne 1 -or $text -notmatch '(?m)^Passed: False\r?$' -or !$text.Contains($marker)) { throw "Settings negative not detected: $report" }
        } else {
            if ($process.ExitCode -ne 0 -or $text -notmatch '(?m)^Passed: True\r?$' -or
                [regex]::Matches($text, '(?m)^PASS: settings step \d+,').Count -ne 10 -or
                !$text.Contains('PASS: settings HWND disposed; 10 settings cases, 8 invalid inputs, hidden update') -or
                $text -match '(?m)^FAIL:') { throw "Settings test failed: $report" }
            if ($text -notmatch 'measured system DPI (\d+)') { throw 'System DPI missing from report' }
            $measuredDpi = [int]$Matches[1]
            foreach ($step in 0,3,7,9) {
                $png = $report + ".step$step.png"
                if (!(Test-Path -LiteralPath $png) -or (Get-Item -LiteralPath $png).LastWriteTime -lt $started.AddSeconds(-2)) { throw "Missing/stale settings capture: $png" }
            }
        }
        Write-Host "PASS: $case ($report)"
    } finally { $process.Dispose() }
}
Write-Host "PASS: five settings modes and two negative controls; measured system DPI $measuredDpi. Renderer overrides are simulations."
