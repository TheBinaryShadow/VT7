[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$executable = Join-Path $BinaryDirectory 'VT7.RendererProbe.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw "Missing renderer probe: $executable" }
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null

function Invoke-ProbeTest([string]$Arguments, [int]$ExpectedExit) {
    $process = Start-Process -FilePath $executable -ArgumentList $Arguments -PassThru -WindowStyle Hidden
    try {
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            throw 'Renderer probe exceeded its 60-second timeout.'
        }
        if ($process.ExitCode -ne $ExpectedExit) { throw "Renderer probe exit $($process.ExitCode), expected $ExpectedExit. See $reportRoot" }
    }
    finally { $process.Dispose() }
}

$reportPath = Join-Path $reportRoot 'renderer-probe.log'
$started = Get-Date
Invoke-ProbeTest ('--output "' + $reportPath + '"') 0
if (-not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTime -lt $started.AddSeconds(-2)) {
    throw 'Renderer probe did not produce a fresh report.'
}
$text = [IO.File]::ReadAllText($reportPath)
if ($text -notmatch '(?m)^Baseline passed: True\r?$' -or $text -match '(?m)^FAIL:') { throw 'Renderer baseline did not pass.' }
foreach ($mode in @('Hardware', 'WARP')) {
    foreach ($check in @('HWND discard/stretch swap chain', 'nonempty glyph pixel readback', 'resize buffers')) {
        if ($text -notmatch ('(?m)^PASS: ' + [regex]::Escape("$mode $check") + ' = 0x00000000\r?$')) {
            throw "Renderer report is missing $mode $check."
        }
    }
}
if ($text -notmatch '(?m)^PASS: Glyph callbacks cover sample UTF-16 text = 0x00000000\r?$') { throw 'Font layout check is missing.' }

$negativePath = Join-Path $reportRoot 'renderer-probe-injected-failure.log'
$negativeStarted = Get-Date
Invoke-ProbeTest ('--output "' + $negativePath + '" --inject-required-failure') 1
if (-not (Test-Path -LiteralPath $negativePath) -or (Get-Item -LiteralPath $negativePath).LastWriteTime -lt $negativeStarted.AddSeconds(-2)) {
    throw 'Negative probe did not produce a fresh report.'
}
$negative = [IO.File]::ReadAllText($negativePath)
if ($negative -notmatch '(?m)^Baseline passed: False\r?$' -or $negative -notmatch '(?m)^FAIL: Injected baseline failure') {
    throw 'Required failure was not reflected in the report.'
}
Invoke-ProbeTest '--invalid-option' 64
Invoke-ProbeTest ('--output "' + $reportRoot + '"') 2
Write-Host "PASS: renderer hardware/WARP, font callback, readback, resize, and negative CLI/report checks ($reportPath)"
