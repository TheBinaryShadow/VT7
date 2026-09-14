[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [string]$BinaryDirectory,
    [string]$OutputDirectory,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Get-Sha256Hex([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binaryRoot = if ($BinaryDirectory) { [IO.Path]::GetFullPath($BinaryDirectory) } else { Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$nativePath = Join-Path $binaryRoot 'VT7.InputProbe.exe'
$focusPath = Join-Path $binaryRoot 'VT7.InputFocusProbe.exe'
foreach ($path in @($nativePath, $focusPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "I01 binary is missing: $path" }
}

if ($OutputDirectory) {
    $runRoot = [IO.Path]::GetFullPath($OutputDirectory)
}
else {
    $logsRoot = Join-Path $binaryRoot 'Logs'
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
    $runRoot = Join-Path $logsRoot ("input-i01-$stamp-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
}
if (Test-Path -LiteralPath $runRoot) { throw "Refusing to replace an existing I01 run: $runRoot" }
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

$nativeOutput = Join-Path $runRoot 'native-probe.json'
& $nativePath --output $nativeOutput
if ($LASTEXITCODE -ne 0) { throw "VT7.InputProbe failed with exit code $LASTEXITCODE. Logs: $runRoot" }
$native = Get-Content -LiteralPath $nativeOutput -Raw | ConvertFrom-Json
if ($native.schema -cne 'vt7-i01-native-v1' -or $native.requestedKlid -cne '0000041A') { throw 'I01 native output schema/layout mismatch.' }
if ([int]$native.mappingCount -le 0 -or [int]$native.altGrMappingCount -le 0) { throw 'I01 native mapping enumeration is incomplete.' }
if (@($native.terminalInputCases).Count -lt 8) { throw 'I01 inherited TerminalInput case set is incomplete.' }

if ($runRoot.Contains('"')) { throw 'I01 output path cannot contain a quotation mark.' }
$focusArgumentLine = '--output "' + $runRoot + '"'
if ($NonInteractive) { $focusArgumentLine += ' --self-test' }
$process = Start-Process -FilePath $focusPath -ArgumentList $focusArgumentLine -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "VT7.InputFocusProbe failed with exit code $($process.ExitCode). Logs: $runRoot" }

$focusSummaryPath = Join-Path $runRoot 'focus-summary.json'
$eventPath = Join-Path $runRoot 'input-events.jsonl'
foreach ($path in @($focusSummaryPath, $eventPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "I01 focus output is missing: $path" }
}
$focus = Get-Content -LiteralPath $focusSummaryPath -Raw | ConvertFrom-Json
if ($focus.schema -cne 'vt7-i01-focus-v1' -or -not $focus.completed) { throw 'I01 focus probe was closed before completion.' }

$issues = New-Object System.Collections.Generic.List[string]
if ($NonInteractive) {
    if (-not $focus.selfTest) { $issues.Add('self-test marker is absent') }
    if ([int]$focus.eventCount -lt 3) { $issues.Add('self-test recorded too few events') }
}
else {
    if ($focus.selfTest) { $issues.Add('interactive run was marked as self-test') }
    if ([string]$focus.layoutKlid -cne '0000041A') { $issues.Add("active layout was $($focus.layoutKlid), expected 0000041A") }
    foreach ($field in @('wpfContainsCroatian', 'nativeContainsCroatian', 'wpfContainsAltGr', 'nativeContainsAltGr')) {
        if (-not $focus.$field) { $issues.Add("$field is false") }
    }
    $events = @(Get-Content -LiteralPath $eventPath | ForEach-Object { $_ | ConvertFrom-Json })
    $nativeCtrlC = @($events | Where-Object { $_.source -ceq 'native' -and $_.event -ceq 'WM_KEYDOWN' -and [int]$_.virtualKey -eq 67 -and [string]$_.modifiers -match 'Ctrl' }).Count
    $nativeBreak = @($events | Where-Object { $_.source -ceq 'native' -and $_.event -ceq 'WM_KEYDOWN' -and [int]$_.virtualKey -eq 3 }).Count
    $nativeSizes = @($events | Where-Object { $_.source -ceq 'native' -and $_.event -ceq 'WM_SIZE' }).Count
    $focusChanges = @($events | Where-Object { $_.event -in @('WM_SETFOCUS', 'WM_KILLFOCUS', 'GotKeyboardFocus', 'LostKeyboardFocus') }).Count
    if ($nativeCtrlC -lt 1) { $issues.Add('native Ctrl+C keydown was not observed') }
    if ($nativeBreak -lt 1) { $issues.Add('native Ctrl+Break/VK_CANCEL was not observed') }
    if ($nativeSizes -lt 3) { $issues.Add("only $nativeSizes native WM_SIZE events were observed") }
    if ($focusChanges -lt 4) { $issues.Add("only $focusChanges focus events were observed") }
}

$utf8 = New-Object Text.UTF8Encoding($false)
$fileHashes = [ordered]@{}
foreach ($path in @($nativeOutput, $focusSummaryPath, $eventPath)) {
    $fileHashes[[IO.Path]::GetFileName($path)] = Get-Sha256Hex $path
}
$manifest = [ordered]@{
    schema = 'vt7-i01-run-v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    mode = if ($NonInteractive) { 'self-test' } else { 'interactive' }
    machine = $env:COMPUTERNAME
    osVersion = [Environment]::OSVersion.VersionString
    osArchitecture = $env:PROCESSOR_ARCHITECTURE
    culture = [Globalization.CultureInfo]::CurrentCulture.Name
    uiCulture = [Globalization.CultureInfo]::CurrentUICulture.Name
    powershell = $PSVersionTable.PSVersion.ToString()
    nativeProbe = $native
    focusSummary = $focus
    issues = $issues.ToArray()
    files = $fileHashes
}
$manifestPath = Join-Path $runRoot 'manifest.json'
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 12), $utf8)

Write-Host "VT7 I01 collection: $runRoot"
Write-Host "  layout: $($focus.layoutKlid)"
Write-Host "  native mappings: $($native.mappingCount), AltGr mappings: $($native.altGrMappingCount), dead key found: $($native.deadKeyFound)"
Write-Host "  focus/input events: $($focus.eventCount)"
if ($issues.Count -gt 0) {
    foreach ($issue in $issues) { Write-Host "  MISSING: $issue" -ForegroundColor Red }
    throw "I01 collection reported $($issues.Count) missing required observation(s). Logs retained: $runRoot"
}
Write-Host "VT7 I01 characterization completed: $manifestPath"
