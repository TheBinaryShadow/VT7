[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [ValidateSet('gdi', 'atlas-d3d-hardware', 'atlas-d3d-warp', 'atlas-d2d-hardware', 'atlas-d2d-warp', 'atlas-auto')]
    [string[]]$Renderers = @('gdi', 'atlas-d3d-hardware', 'atlas-d3d-warp', 'atlas-d2d-hardware', 'atlas-d2d-warp', 'atlas-auto'),
    [switch]$SkipNegative
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$executable = Join-Path $BinaryDirectory 'VT7.Host.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw "Missing VT7 executable: $executable" }
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null

$cases = @(@{ Mode = 'diagnostics'; Renderer = 'gdi'; Negative = $false })
foreach ($renderer in $Renderers) { $cases += @{ Mode = 'window-smoke-test'; Renderer = $renderer; Negative = $false } }
if (!$SkipNegative) { $cases += @{ Mode = 'window-smoke-test'; Renderer = 'atlas-d3d-warp'; Negative = $true } }
foreach ($case in $cases) {
    $mode = $case.Mode
    $label = $mode + '-' + $case.Renderer + $(if ($case.Negative) { '-blank-negative' })
    $reportPath = Join-Path $reportRoot ($label + '.log')
    $arguments = '--' + $mode + ' --renderer ' + $case.Renderer + ' --diagnostics-output "' + $reportPath + '"'
    if ($case.Negative) { $arguments += ' --inject-blank-frame' }
    $started = Get-Date
    $testProcess = Start-Process -FilePath $executable -ArgumentList $arguments -PassThru -WindowStyle Hidden
    try {
        if (-not $testProcess.WaitForExit(60000)) {
            $testProcess.Kill()
            throw "VT7 $mode exceeded its 60-second timeout."
        }
        if (!$case.Negative -and $testProcess.ExitCode -ne 0) { throw "VT7 $label failed ($($testProcess.ExitCode)). See $reportPath" }
        if (-not (Test-Path -LiteralPath $reportPath)) { throw "VT7 $mode did not produce a report." }
        $report = Get-Item -LiteralPath $reportPath
        if ($report.LastWriteTime -lt $started.AddSeconds(-2)) { throw "VT7 $mode left a stale report." }
        $text = [IO.File]::ReadAllText($reportPath)
        if ($case.Negative) {
            if ($testProcess.ExitCode -ne 1 -or $text -notmatch 'Atlas frame has no nonbackground pixels' -or $text -notmatch '(?m)^Passed: False\r?$') {
                throw "VT7 did not detect the injected blank Atlas frame. See $reportPath"
            }
            Write-Host "PASS: blank-frame negative ($reportPath)"
            continue
        }
        if ($text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:') {
            throw "VT7 $mode report did not pass. See $reportPath"
        }
        if ($mode -eq 'window-smoke-test' -and
            ([regex]::Matches($text, '(?m)^(?:Surface: )?PASS: tab round trip,').Count -ne 8 -or
             [regex]::Matches($text, '(?m)^PASS: HWND cycle ').Count -ne 4)) {
            throw "VT7 window report is missing the expected eight tab round trips or four HWND cycles. See $reportPath"
        }
        if ($mode -eq 'window-smoke-test') {
            if ([regex]::Matches($text, 'PASS: initial native window fits monitor work area').Count -ne 4 -or
                [regex]::Matches($text, 'PASS: long recovery status at 760 DIPs preserved client/raster dimensions; old-wrap control changed client height').Count -ne 4) {
                throw "Missing scaling correction controls: $reportPath"
            }
            if ($case.Renderer -ne 'gdi' -and [regex]::Matches($text, 'PASS: blank first row with visible lower-row text accepted').Count -ne 4) {
                throw "Missing blank-first-row controls: $reportPath"
            }
            if ([regex]::Matches($text, 'PASS: first-frame status refreshed with a completed-frame snapshot').Count -ne 4) { throw "Missing first-frame status checks: $reportPath" }
            $expectedRenderer = [Array]::IndexOf(@('gdi', 'atlas-d3d-hardware', 'atlas-d3d-warp', 'atlas-d2d-hardware', 'atlas-d2d-warp'), $case.Renderer)
            if ($case.Renderer -eq 'atlas-auto') { $expectedRenderer = '[12]' }
            if ([regex]::Matches($text, "(?m)^PASS: HWND cycle .*renderer $expectedRenderer,").Count -ne 4) { throw "Missing requested backend evidence: $reportPath" }
            if ($expectedRenderer -ne 0 -and (!(Test-Path -LiteralPath ($reportPath + '.png')) -or
                (Get-Item -LiteralPath ($reportPath + '.png')).LastWriteTime -lt $started.AddSeconds(-2))) { throw "Missing or stale Atlas capture: $reportPath.png" }
        }
        Write-Host "PASS: $label ($reportPath)"
    }
    finally { $testProcess.Dispose() }
}
