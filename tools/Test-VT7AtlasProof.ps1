[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$executable = Join-Path $BinaryDirectory 'VT7.AtlasProof.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw "Missing Atlas proof: $executable" }
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\Atlas"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null

function Invoke-Atlas([string]$Arguments, [int]$ExpectedExit) {
    $process = Start-Process -FilePath $executable -ArgumentList $Arguments -PassThru -WindowStyle Hidden
    try {
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            throw 'Atlas proof exceeded its 60-second timeout.'
        }
        if ($process.ExitCode -ne $ExpectedExit) { throw "Atlas proof exit $($process.ExitCode), expected $ExpectedExit. See $reportRoot" }
    }
    finally { $process.Dispose() }
}

foreach ($backend in @('Direct3D11', 'Direct2D')) {
    foreach ($device in @('hardware', 'WARP')) {
        $reportPath = Join-Path $reportRoot "$backend-$device.log"
        $arguments = '--self-test --output "' + $reportPath + '"'
        $capturePath = Join-Path $reportRoot "$backend-$device.png"
        $arguments += ' --capture "' + $capturePath + '"'
        if ($backend -eq 'Direct2D') { $arguments += ' --d2d' }
        if ($device -eq 'WARP') { $arguments += ' --warp' }
        $started = Get-Date
        Invoke-Atlas $arguments 0
        if (-not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTime -lt $started.AddSeconds(-2)) {
            throw "Missing fresh report: $reportPath"
        }
        $text = [IO.File]::ReadAllText($reportPath)
        if (-not (Test-Path -LiteralPath $capturePath) -or (Get-Item -LiteralPath $capturePath).LastWriteTime -lt $started.AddSeconds(-2)) {
            throw "Missing fresh capture: $capturePath"
        }
        if ($text -match '(?m)^FAIL:' -or $text -notmatch '(?m)^Automated backend checks passed: True\r?$' -or
            $text -notmatch '(?m)^Failed: False; frames=19\r?$' -or
            $text -notmatch [regex]::Escape("Backend: Atlas $backend; forced $device; mode=hidden automated checks")) {
            throw "Atlas report did not pass with the requested backend: $reportPath"
        }
        if ([regex]::Matches($text, '(?m)^PASS: full redraw after discard is pixel-identical\r?$').Count -ne 4) {
            throw "Missing resize/redraw coverage: $reportPath"
        }
        Write-Host "PASS: Atlas $backend / $device, 19 frames and exact pixel checks."
    }
}
Invoke-Atlas '--invalid-option' 64
Invoke-Atlas ('--self-test --output "' + $reportRoot + '"') 2
$negativePath = Join-Path $reportRoot 'injected-render-failure.log'
$negativeStarted = Get-Date
Invoke-Atlas ('--self-test --warp --inject-render-failure --output "' + $negativePath + '"') 1
if (-not (Test-Path -LiteralPath $negativePath) -or (Get-Item -LiteralPath $negativePath).LastWriteTime -lt $negativeStarted.AddSeconds(-2)) {
    throw 'Missing fresh negative-test report.'
}
$negativeText = [IO.File]::ReadAllText($negativePath)
if ($negativeText -notmatch '(?m)^FAIL: HRESULT=' -or $negativeText -notmatch '(?m)^Failed: True; frames=0\r?$' -or
    $negativeText -match '(?m)^Automated backend checks passed: True') { throw 'Render failure did not fail the test.' }
Write-Host "Atlas backend checks passed. Reports: $reportRoot"
