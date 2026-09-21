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
$executable = Join-Path $binaryRoot 'VT7.Host.exe'
$native = Join-Path $binaryRoot 'VT7.Native.dll'
$winPty = Join-Path $binaryRoot 'winpty.dll'
$agent = Join-Path $binaryRoot 'winpty-agent.exe'
$license = Join-Path $binaryRoot 'winpty-LICENSE.txt'
$expected = [ordered]@{
    'winpty.dll' = '936F611C2129600D35AB7AAD45546A837F4F3A9CA7F673E5D66B48C313B9CD75'
    'winpty-agent.exe' = '9ADD1A61155EC47CF6F347FAF776B746EEBBDE1DC9360D81B8A909DA34650642'
    'winpty-LICENSE.txt' = 'C39E428064B4F3E4FE81A975BF0FD3B845922B431BC4D9A7FFC8BFB091981836'
}
foreach ($path in @($executable, $native, $winPty, $agent, $license)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing 3B runtime file: $path" }
}
foreach ($name in $expected.Keys) {
    $actual = Get-VT7Sha256 -Path (Join-Path $binaryRoot $name)
    if ($actual -ne $expected[$name]) { throw "Pinned WinPTY identity mismatch for $name. Expected $($expected[$name]); found $actual." }
}
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
    Join-Path $parent ('powershell-profiles-' + $identity)
} else { Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\PowerShellProfiles" }
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$reportPath = Join-Path $reportRoot 'powershell-profiles.log'
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
    'HostSHA256=' + (Get-VT7Sha256 -Path $executable)
    'NativeSHA256=' + (Get-VT7Sha256 -Path $native)
    'WinPtySHA256=' + $expected['winpty.dll']
    'WinPtyAgentSHA256=' + $expected['winpty-agent.exe']
)
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$environment += 'WindowsPowerShellPath=' + $windowsPowerShell
if (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) {
    $environment += 'WindowsPowerShellFileVersion=' + [Diagnostics.FileVersionInfo]::GetVersionInfo($windowsPowerShell).FileVersion
}
$powerShell7Path = $null
foreach ($candidate in @(
    (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
    (Join-Path $env:ProgramFiles 'PowerShell\7-preview\pwsh.exe')
)) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $powerShell7Path = $candidate; break }
}
if ($powerShell7Path) {
    $powerShell7Version = [Diagnostics.FileVersionInfo]::GetVersionInfo($powerShell7Path)
    $environment += 'PowerShell7Path=' + $powerShell7Path
    $environment += 'PowerShell7ProductVersion=' + $powerShell7Version.ProductVersion
} else {
    $environment += 'PowerShell7Path=NOT INSTALLED'
}
[IO.File]::WriteAllLines($environmentPath, $environment, (New-Object Text.UTF8Encoding($false)))

$arguments = @(
    '--powershell-profile-test',
    '--renderer', 'atlas-d3d-hardware',
    '--diagnostics-output', $reportPath
)
if ($AllowMissingPowerShell7) { $arguments += '--allow-missing-powershell-7' }
$process = Start-Process -FilePath $executable -ArgumentList $arguments -PassThru -WindowStyle Hidden
try {
    if (-not $process.WaitForExit(90000)) {
        $process.Kill()
        throw 'VT7 PowerShell profile test exceeded its 90-second timeout.'
    }
    if ($process.ExitCode -ne 0) { throw "VT7 PowerShell profile test failed ($($process.ExitCode)). See $reportPath" }
}
finally { $process.Dispose() }

if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'VT7 PowerShell profile test did not produce a report.' }
$report = Get-Item -LiteralPath $reportPath
if ($report.LastWriteTime -lt $started.AddSeconds(-2)) { throw 'VT7 PowerShell profile test left a stale report.' }
$text = [IO.File]::ReadAllText($reportPath)
$required = @(
    'Build: VT7 0.9.2',
    'Native: ABI 11, expected 11',
    'PASS: Windows PowerShell 5.1 uses an explicit System32 executable, preserves ordinary user profiles, and reserves -NoProfile for controlled diagnostics.',
    'Error: None'
)
foreach ($line in $required) {
    if (-not $text.Contains($line)) { throw "PowerShell profile report is missing: $line" }
}
$acceptedWindowsPowerShellEditor = $text.Contains('PASS: Windows PowerShell 5.1 reported runtime 5.1, loaded PSReadLine') -or
    $text.Contains('PASS: Windows PowerShell 5.1 reported runtime 5.1, used its legacy ConsoleHost editor because PSReadLine was not auto-loaded')
if (-not $acceptedWindowsPowerShellEditor) { throw 'Windows PowerShell 5.1 reported neither a PSReadLine nor legacy editor pass.' }
if ($AllowMissingPowerShell7) {
    $acceptedPowerShell7 = $text.Contains('PASS: PowerShell 7.2.24 reported its exact runtime') -or
        $text.Contains('SKIP: PowerShell 7 is not installed') -or
        $text.Contains('outside the Windows 7 qualification target 7.2.24')
    if (-not $acceptedPowerShell7) { throw 'PowerShell 7 was neither qualified nor explicitly skipped.' }
} else {
    foreach ($line in @(
        'PASS: PowerShell 7.2.24 uses an explicit Program Files executable, preserves ordinary user profiles, and reserves -NoProfile for controlled diagnostics.',
        'PASS: PowerShell 7.2.24 reported its exact runtime, loaded PSReadLine with prediction capability, exposed completion, ran a native child, resized, drained, and exited through WinPTY.'
    )) {
        if (-not $text.Contains($line)) { throw "PowerShell 7.2.24 report is missing: $line" }
    }
    if ($text -match '(?m)^SKIP:') { throw 'Strict target validation cannot contain a skipped PowerShell 7 check.' }
}
if ($text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:') {
    throw "VT7 PowerShell profile report did not pass. See $reportPath"
}
Write-Host "PASS: PowerShell profiles ($reportPath)"
if ($OutputDirectory) { Write-Host "Return this entire log folder: $reportRoot" }
