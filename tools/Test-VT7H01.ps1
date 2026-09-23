[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [string]$OutputDirectory,
    [switch]$AllowMissingPowerShell7
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Get-VT7Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$binaryRoot = [IO.Path]::GetFullPath($BinaryDirectory)
$hostPath = Join-Path $binaryRoot 'VT7.Host.exe'
$native = Join-Path $binaryRoot 'VT7.Native.dll'
$shim = Join-Path $binaryRoot 'shim\ssh.exe'
$bypass = Join-Path $binaryRoot 'shim\ssh-system.exe'
$fixture = Join-Path $binaryRoot 'VT7.WinPtyFixture.exe'
$winPty = Join-Path $binaryRoot 'winpty.dll'
$agent = Join-Path $binaryRoot 'winpty-agent.exe'
foreach ($path in @($hostPath, $native, $shim, $bypass, $fixture, $winPty, $agent)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing H01 runtime file: $path" }
}
if ((Get-VT7Sha256 -Path $shim) -ne (Get-VT7Sha256 -Path $bypass)) { throw 'ssh.exe and ssh-system.exe are not the same reviewed shim binary.' }
$sumPath = Join-Path $binaryRoot 'SHA256SUMS.txt'
if (Test-Path -LiteralPath $sumPath -PathType Leaf) {
    foreach ($line in [IO.File]::ReadAllLines($sumPath)) {
        if (-not $line.Trim()) { continue }
        if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { throw "Malformed package hash line: $line" }
        $file = Join-Path $binaryRoot $Matches[2].Replace('/', '\')
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Package file is missing: $($Matches[2])" }
        if ((Get-VT7Sha256 -Path $file) -ne $Matches[1]) { throw "Package hash mismatch: $($Matches[2])" }
    }
}

$reportRoot = if ($OutputDirectory) {
    $parent = [IO.Path]::GetFullPath($OutputDirectory)
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $identity = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    Join-Path $parent ('h01-' + $identity)
} else { Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\H01" }
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$reportPath = Join-Path $reportRoot 'h01.log'
$environmentPath = Join-Path $reportRoot 'RUN-ENVIRONMENT.txt'
$started = Get-Date

$environment = @(
    'CapturedUtc=' + [DateTime]::UtcNow.ToString('o')
    'OSVersion=' + [Environment]::OSVersion.VersionString
    'Is64BitOperatingSystem=' + [Environment]::Is64BitOperatingSystem
    'Is64BitProcess=' + [Environment]::Is64BitProcess
    'Culture=' + [Globalization.CultureInfo]::CurrentCulture.Name
    'UICulture=' + [Globalization.CultureInfo]::CurrentUICulture.Name
    'PowerShell=' + $PSVersionTable.PSVersion.ToString()
    'HostSHA256=' + (Get-VT7Sha256 -Path $hostPath)
    'NativeSHA256=' + (Get-VT7Sha256 -Path $native)
    'ShimSHA256=' + (Get-VT7Sha256 -Path $shim)
    'FixtureSHA256=' + (Get-VT7Sha256 -Path $fixture)
    'WinPtySHA256=' + (Get-VT7Sha256 -Path $winPty)
    'WinPtyAgentSHA256=' + (Get-VT7Sha256 -Path $agent)
)
$powerShell7 = @(
    (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
    (Join-Path $env:ProgramFiles 'PowerShell\7-preview\pwsh.exe')
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
$environment += if ($powerShell7) {
    'PowerShell7=' + $powerShell7 + ' | ' + [Diagnostics.FileVersionInfo]::GetVersionInfo($powerShell7).ProductVersion
} else { 'PowerShell7=NOT INSTALLED' }
[IO.File]::WriteAllLines($environmentPath, $environment, (New-Object Text.UTF8Encoding($false)))

$arguments = @('--h01-test', '--renderer', 'atlas-d3d-hardware', '--diagnostics-output', $reportPath)
if ($AllowMissingPowerShell7) { $arguments += '--allow-missing-powershell-7' }
$process = Start-Process -FilePath $hostPath -ArgumentList $arguments -PassThru -WindowStyle Hidden
try {
    if (-not $process.WaitForExit(120000)) { $process.Kill(); throw 'VT7 H01 test exceeded its 120-second timeout.' }
    if ($process.ExitCode -ne 0) { throw "VT7 H01 test failed ($($process.ExitCode)). See $reportPath" }
}
finally { $process.Dispose() }

if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'VT7 H01 test did not produce a report.' }
$report = Get-Item -LiteralPath $reportPath
if ($report.LastWriteTime -lt $started.AddSeconds(-2)) { throw 'VT7 H01 test left a stale report.' }
$text = [IO.File]::ReadAllText($reportPath)
$required = @(
    'Build: VT7 0.10.1',
    'Native: ABI 11, expected 11',
    'PASS: H01 grammar admits only interactive -4/-6/-l/-p/-i forms and sends ambiguous or unsupported syntax to exact fallback.',
    'PASS: Command Prompt resolved ordinary ssh through the authenticated shim, committed the visible WinPTY barrier in order, and kept the accepted shim waiting beyond the five-second handshake timeout until embedded completion.',
    'PASS: Windows PowerShell 5.1 preserved Croatian HR Latin input, command precedence and the authenticated WinPTY barrier.',
    'PASS: unsupported syntax selected the exact absolute fallback, preserved quoted argv and exit 37, and removed capability, pipe and shim PATH state.',
    'PASS: a wrong session capability was denied before embedded acceptance and fell back once without a duplicate connection.',
    'Error: None'
)
foreach ($line in $required) { if (-not $text.Contains($line)) { throw "H01 report is missing: $line" } }
if ($AllowMissingPowerShell7) {
    $accepted = $text.Contains('PASS: PowerShell 7.2.24 preserved Croatian HR Latin input') -or
        $text.Contains('SKIP: PowerShell 7 is not installed locally') -or
        $text.Contains('outside the Windows 7 H01 qualification target 7.2.24')
    if (-not $accepted) { throw 'PowerShell 7 was neither qualified nor explicitly skipped.' }
} else {
    if (-not $text.Contains('PASS: PowerShell 7.2.24 preserved Croatian HR Latin input, command precedence and the authenticated WinPTY barrier.')) {
        throw 'Strict H01 target validation did not qualify PowerShell 7.2.24.'
    }
    if ($text -match '(?m)^SKIP:') { throw 'Strict H01 target validation cannot contain a skip.' }
}
if ($text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:') { throw "VT7 H01 report did not pass. See $reportPath" }
Write-Host "PASS: H01 typed-command shim and barrier ($reportPath)"
if ($OutputDirectory) { Write-Host "Return this entire log folder: $reportRoot" }
