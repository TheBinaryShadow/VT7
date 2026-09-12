[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [ValidateSet('atlas-d3d-hardware','atlas-d3d-warp','atlas-d2d-hardware','atlas-d2d-warp')]
    [string[]]$Renderers = @('atlas-d3d-hardware','atlas-d3d-warp','atlas-d2d-hardware','atlas-d2d-warp')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\Repaint"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$cases = @($Renderers | ForEach-Object { @{ Renderer = $_; Negative = $false } })
$cases += @{ Renderer = 'atlas-d3d-warp'; Negative = $true }
foreach ($case in $cases) {
    $name = $case.Renderer + $(if ($case.Negative) { '-negative' })
    $report = Join-Path $reportRoot ($name + '.log')
    $arguments = '--repaint-test --renderer ' + $case.Renderer + ' --diagnostics-output "' + $report + '"'
    if ($case.Negative) { $arguments += ' --inject-repaint-failure' }
    $started = Get-Date
    $process = Start-Process -FilePath (Join-Path $BinaryDirectory 'VT7.Host.exe') -ArgumentList $arguments -PassThru -WindowStyle Hidden
    try {
        if (!$process.WaitForExit(60000)) { $process.Kill(); throw "Repaint test timed out: $name" }
        if (!(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTime -lt $started.AddSeconds(-2)) { throw "Missing/stale report: $name" }
        $text = [IO.File]::ReadAllText($report)
        if ($case.Negative) {
            if ($process.ExitCode -ne 1 -or $text -notmatch '(?m)^Passed: False\r?$' -or $text -notmatch 'Atlas differential repaint mismatch') { throw "Repaint negative not detected: $name" }
        } else {
            $mode = [array]::IndexOf(@('unused','atlas-d3d-hardware','atlas-d3d-warp','atlas-d2d-hardware','atlas-d2d-warp'), $case.Renderer)
            if ($process.ExitCode -ne 0 -or $text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:' -or
                [regex]::Matches($text, "(?m)^PASS: repaint step \d+, renderer $mode, exact RGB,").Count -ne 32 -or
                $text -notmatch 'PASS: repaint HWND disposed; 32 exact comparisons, 8 cursor-cell checks') { throw "Repaint test failed: $report" }
            foreach ($size in 0,1) { foreach ($step in 4,12) {
                $png = $report + ".size$size.step$step.png"
                if (!(Test-Path -LiteralPath $png) -or (Get-Item -LiteralPath $png).LastWriteTime -lt $started.AddSeconds(-2)) { throw "Missing/stale capture: $png" }
            } }
        }
        Write-Host "PASS: $name ($report)"
    } finally { $process.Dispose() }
}
