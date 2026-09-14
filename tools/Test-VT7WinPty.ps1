[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [string]$OutputRoot,
    [ValidateRange(10, 120)]
    [int]$CaseTimeoutSeconds = 45,
    [string[]]$Cases = @(
        'write-console-w',
        'write-console-output-w',
        'write-console-a-437',
        'write-console-a-850',
        'write-console-a-852',
        'write-console-a-932',
        'write-console-a-65001',
        'write-file-437',
        'write-file-850',
        'write-file-852',
        'write-file-932',
        'write-file-65001',
        'raw-vt-unprocessed',
        'raw-vt-processed',
        'fast-rewrite',
        'alternate-buffer',
        'resize',
        'exit-drain'
    )
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binaryRoot = if ($BinaryDirectory) { [IO.Path]::GetFullPath($BinaryDirectory) } else { Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$reportParent = if ($OutputRoot) { [IO.Path]::GetFullPath($OutputRoot) } else { Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration" }
$runRoot = Join-Path $reportParent ('winpty-p01-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$probePath = Join-Path $binaryRoot 'VT7.WinPtyProbe.exe'
$fixturePath = Join-Path $binaryRoot 'VT7.WinPtyFixture.exe'
$winPtyPath = Join-Path $binaryRoot 'winpty.dll'
$agentPath = Join-Path $binaryRoot 'winpty-agent.exe'
$licensePath = Join-Path $binaryRoot 'winpty-LICENSE.txt'

$required = @($probePath, $fixturePath, $winPtyPath, $agentPath, $licensePath)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "P01 binary was not found: $path. Build VT7 first."
    }
}

$expectedHashes = @{
    'winpty.dll' = '936F611C2129600D35AB7AAD45546A837F4F3A9CA7F673E5D66B48C313B9CD75'
    'winpty-agent.exe' = '9ADD1A61155EC47CF6F347FAF776B746EEBBDE1DC9360D81B8A909DA34650642'
    'winpty-LICENSE.txt' = 'C39E428064B4F3E4FE81A975BF0FD3B845922B431BC4D9A7FFC8BFB091981836'
}
foreach ($name in $expectedHashes.Keys) {
    $actual = (Get-FileHash -LiteralPath (Join-Path $binaryRoot $name) -Algorithm SHA256).Hash
    if ($actual -ne $expectedHashes[$name]) {
        throw "Pinned WinPTY runtime hash mismatch: $name"
    }
}

function Get-NormalizedConsoleRows {
    param([Parameter(Mandatory=$true)]$Snapshot)
    $rows = New-Object System.Collections.Generic.List[string]
    for ($row = 0; $row -lt [int]$Snapshot.rows; $row++) {
        $text = [string]$Snapshot.text[$row]
        $attributes = [string]$Snapshot.attributesHex[$row]
        $builder = New-Object Text.StringBuilder
        for ($column = 0; $column -lt [int]$Snapshot.columns; $column++) {
            $offset = $column * 4
            $low = [Convert]::ToByte($attributes.Substring($offset, 2), 16)
            $high = [Convert]::ToByte($attributes.Substring($offset + 2, 2), 16)
            $attribute = [int]$low -bor ([int]$high -shl 8)
            if (($attribute -band 0x0200) -eq 0) {
                [void]$builder.Append($text[$column])
            }
        }
        $rows.Add($builder.ToString().TrimEnd())
    }
    return $rows.ToArray()
}

function Get-CoreRows {
    param([Parameter(Mandatory=$true)]$Core)
    $rows = New-Object System.Collections.Generic.List[string]
    foreach ($row in $Core.text) {
        $rows.Add(([string]$row).TrimEnd())
    }
    return $rows.ToArray()
}

function Get-NormalizedConsoleAttributes {
    param([Parameter(Mandatory=$true)]$Snapshot)
    $rows = New-Object System.Collections.Generic.List[string]
    foreach ($encodedRow in $Snapshot.attributesHex) {
        $encoded = [string]$encodedRow
        $builder = New-Object Text.StringBuilder
        for ($column = 0; $column -lt [int]$Snapshot.columns; $column++) {
            $offset = $column * 4
            $low = [Convert]::ToByte($encoded.Substring($offset, 2), 16)
            $high = [Convert]::ToByte($encoded.Substring($offset + 2, 2), 16)
            $attribute = ([int]$low -bor ([int]$high -shl 8)) -band 0xfcff
            [void]$builder.Append(('{0:x2}{1:x2}' -f ($attribute -band 0xff), (($attribute -shr 8) -band 0xff)))
        }
        $rows.Add($builder.ToString())
    }
    return $rows.ToArray()
}

New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$caseResults = New-Object System.Collections.Generic.List[object]

foreach ($caseName in $Cases) {
    if ($caseName -notmatch '^[a-z0-9-]+$') {
        throw "Invalid P01 case name: $caseName"
    }
    $caseRoot = Join-Path $runRoot $caseName
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
    $consoleLog = Join-Path $caseRoot 'probe-console.txt'

    Write-Host "P01 case: $caseName"
    foreach ($argumentPath in @($fixturePath, $caseRoot)) {
        if ($argumentPath.Contains('"')) { throw "P01 path contains an unsupported quote: $argumentPath" }
    }
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $probePath
    $startInfo.Arguments = '--case ' + $caseName + ' --fixture "' + $fixturePath + '" --output "' + $caseRoot + '"'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "P01 probe did not start: $caseName" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($CaseTimeoutSeconds * 1000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "P01 probe timed out after $CaseTimeoutSeconds seconds: $caseName"
    }
    $exitCode = $process.ExitCode
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $process.Dispose()
    $output = ($stdout + $stderr).TrimEnd()
    [IO.File]::WriteAllText($consoleLog, $output + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
    if ($output) { Write-Host $output }
    if ($exitCode -ne 0) {
        throw "P01 probe failed for $caseName with exit code $exitCode. See $consoleLog"
    }

    $childPath = Join-Path $caseRoot 'child.json'
    $probeResultPath = Join-Path $caseRoot 'probe.json'
    $backendPath = Join-Path $caseRoot 'backend.bin'
    foreach ($path in @($childPath, $probeResultPath, $backendPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "P01 case did not produce $path"
        }
    }

    $child = Get-Content -LiteralPath $childPath -Raw | ConvertFrom-Json
    $probe = Get-Content -LiteralPath $probeResultPath -Raw | ConvertFrom-Json
    if ($child.schema -ne 'vt7-p01-child-v2' -or $probe.schema -ne 'vt7-p01-probe-v1') {
        throw "P01 case returned an unknown schema: $caseName"
    }
    if ($child.case -ne $caseName -or $probe.case -ne $caseName) {
        throw "P01 case identity changed: $caseName"
    }
    if ([int64]$probe.backendByteCount -ne (Get-Item -LiteralPath $backendPath).Length) {
        throw "P01 backend byte count differs: $caseName"
    }
    if ([int64]$probe.core.stream.bytes -ne [int64]$probe.backendByteCount -or -not [bool]$probe.core.stream.ended -or [int]$probe.core.stream.pendingBytes -ne 0) {
        throw "P01 incremental decoder did not consume the complete backend stream: $caseName"
    }

    $requestedOutputCodePage = [int]$child.requestedOutputCodePage
    $outputCodePageSet = [bool]$child.outputCodePageSet
    $outputCodePageSetError = [int64]$child.outputCodePageSetError
    if ($requestedOutputCodePage -ne 0) {
        if ($outputCodePageSet) {
            if ([int]$child.outputCodePage -ne $requestedOutputCodePage -or $outputCodePageSetError -ne 0) {
                throw "P01 reported an inconsistent successful code-page request: $caseName"
            }
        }
        elseif ($outputCodePageSetError -eq 0 -or [int64]$child.apiResult -ne 0 -or [string]$child.sourceBytesHex) {
            throw "P01 reported an inconsistent unsupported code-page request: $caseName"
        }
    }

    $finalChild = @($child.snapshots | Where-Object { $_.label -eq 'final' })[-1]
    if ($null -eq $finalChild) {
        throw "P01 child final snapshot is missing: $caseName"
    }
    $childRows = @(Get-NormalizedConsoleRows -Snapshot $finalChild)
    $coreRows = @(Get-CoreRows -Core $probe.core)
    $childAttributes = @(Get-NormalizedConsoleAttributes -Snapshot $finalChild)
    $coreAttributes = @($probe.core.legacyAttributesHex)
    $rowCount = [Math]::Min($childRows.Count, $coreRows.Count)
    $differentRows = New-Object System.Collections.Generic.List[int]
    for ($row = 0; $row -lt $rowCount; $row++) {
        if (-not [string]::Equals($childRows[$row], $coreRows[$row], [StringComparison]::Ordinal)) {
            $differentRows.Add($row)
        }
    }
    for ($row = $rowCount; $row -lt [Math]::Max($childRows.Count, $coreRows.Count); $row++) {
        $differentRows.Add($row)
    }

    $backendBytes = [IO.File]::ReadAllBytes($backendPath)
    $strictUtf8 = New-Object Text.UTF8Encoding($false, $true)
    try {
        $backendText = $strictUtf8.GetString($backendBytes)
        $validUtf8 = $true
    }
    catch {
        $backendText = (New-Object Text.UTF8Encoding($false, $false)).GetString($backendBytes)
        $validUtf8 = $false
    }
    $visible = $backendText.Replace(([char]27).ToString(), '<ESC>').Replace("`r", '<CR>').Replace("`n", "<LF>`r`n")
    [IO.File]::WriteAllText((Join-Path $caseRoot 'backend-visible.txt'), $visible, (New-Object Text.UTF8Encoding($false)))

    $observations = [ordered]@{
        fastRewriteUpdatesSeen = ([regex]::Matches($backendText, 'rewrite [0-9]{3} / 199')).Count
        drainLinesSeen = ([regex]::Matches($backendText, 'drain-[0-9]{3}')).Count
        sawPrimaryMarker = $backendText.Contains('PRIMARY-BEFORE')
        sawAlternateMarker = $backendText.Contains('ALTERNATE-ACTIVE')
        sawResizeReady = $backendText.Contains('RESIZE_READY')
        sawResizeAfter = $backendText.Contains('RESIZE_AFTER 100x30')
    }

    $comparison = [ordered]@{
        schema = 'vt7-p01-comparison-v2'
        case = $caseName
        operation = [string]$child.operation
        requestedOutputCodePage = $requestedOutputCodePage
        requestedCodePageValid = [bool]$child.requestedCodePageValid
        outputCodePageSet = $outputCodePageSet
        outputCodePageSetError = $outputCodePageSetError
        outputCodePage = [int]$child.outputCodePage
        apiResult = [int64]$child.apiResult
        apiError = [int64]$child.apiError
        modeBefore = [int64]$child.modeBefore
        modeAfter = [int64]$child.modeAfter
        sourceBytesHex = [string]$child.sourceBytesHex
        backendByteCount = [int64]$probe.backendByteCount
        backendSha256 = (Get-FileHash -LiteralPath $backendPath -Algorithm SHA256).Hash
        backendValidUtf8 = $validUtf8
        decoderWrites = [int]$probe.core.stream.writes
        childExitCode = [int64]$probe.childExitCode
        agentExitCode = [int64]$probe.agentExitCode
        childColumns = [int]$finalChild.columns
        childRows = [int]$finalChild.rows
        coreColumns = [int]$probe.core.columns
        coreRows = [int]$probe.core.rows
        dimensionsEqual = ([int]$finalChild.columns -eq [int]$probe.core.columns -and [int]$finalChild.rows -eq [int]$probe.core.rows)
        textEqual = ($differentRows.Count -eq 0)
        differentRows = $differentRows.ToArray()
        childCursor = @([int]$finalChild.cursorX, [int]$finalChild.cursorY)
        coreCursor = @([int]$probe.core.cursorX, [int]$probe.core.cursorY)
        cursorEqual = ([int]$finalChild.cursorX -eq [int]$probe.core.cursorX -and [int]$finalChild.cursorY -eq [int]$probe.core.cursorY)
        attributesEqual = (($childAttributes -join '|') -ceq ($coreAttributes -join '|'))
        observations = $observations
        childNormalizedText = $childRows
        coreText = $coreRows
    }
    $comparison | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $caseRoot 'comparison.json') -Encoding UTF8
    $caseResults.Add([pscustomobject]$comparison)
}

$manifest = [ordered]@{
    schema = 'vt7-p01-run-v2'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    configuration = $Configuration
    machine = $env:COMPUTERNAME
    osVersion = [Environment]::OSVersion.VersionString
    osArchitecture = $env:PROCESSOR_ARCHITECTURE
    culture = [Globalization.CultureInfo]::CurrentCulture.Name
    uiCulture = [Globalization.CultureInfo]::CurrentUICulture.Name
    powershell = $PSVersionTable.PSVersion.ToString()
    winpty = [ordered]@{
        version = '0.4.3'
        commit = '3e1ab962d5262dd76159870c6dc0724927ca6a9d'
        releaseArchiveSha256 = '35A48ECE2FF4ACDCBC8299D4920DE53EB86B1FB41E64D2FE5AE7898931BCEE89'
        dllSha256 = $expectedHashes['winpty.dll']
        agentSha256 = $expectedHashes['winpty-agent.exe']
    }
    cases = $caseResults.ToArray()
}
$manifestPath = Join-Path $runRoot 'manifest.json'
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$caseResults | Select-Object case, requestedOutputCodePage, requestedCodePageValid, outputCodePageSet, outputCodePageSetError, outputCodePage, backendByteCount, backendValidUtf8, dimensionsEqual, textEqual, cursorEqual, attributesEqual, @{Name='differentRowCount';Expression={$_.differentRows.Count}} | Format-Table -AutoSize
Write-Host "VT7 P01 characterization completed: $manifestPath"
