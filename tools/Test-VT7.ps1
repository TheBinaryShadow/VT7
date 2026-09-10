[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$executable = Join-Path $BinaryDirectory 'VT7.Host.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw "Missing VT7 executable: $executable" }
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null

foreach ($mode in @('diagnostics', 'window-smoke-test')) {
    $reportPath = Join-Path $reportRoot ($mode + '.log')
    $arguments = '--' + $mode + ' --diagnostics-output "' + $reportPath + '"'
    $started = Get-Date
    $testProcess = Start-Process -FilePath $executable -ArgumentList $arguments -PassThru -WindowStyle Hidden
    try {
        if (-not $testProcess.WaitForExit(60000)) {
            $testProcess.Kill()
            throw "VT7 $mode exceeded its 60-second timeout."
        }
        if ($testProcess.ExitCode -ne 0) { throw "VT7 $mode failed ($($testProcess.ExitCode)). See $reportPath" }
        if (-not (Test-Path -LiteralPath $reportPath)) { throw "VT7 $mode did not produce a report." }
        $report = Get-Item -LiteralPath $reportPath
        if ($report.LastWriteTime -lt $started.AddSeconds(-2)) { throw "VT7 $mode left a stale report." }
        $text = [IO.File]::ReadAllText($reportPath)
        if ($text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:') {
            throw "VT7 $mode report did not pass. See $reportPath"
        }
        if ($mode -eq 'window-smoke-test' -and
            ([regex]::Matches($text, '(?m)^(?:Surface: )?PASS: tab round trip,').Count -ne 8 -or
             [regex]::Matches($text, '(?m)^PASS: HWND cycle ').Count -ne 4)) {
            throw "VT7 window report is missing the expected eight tab round trips or four HWND cycles. See $reportPath"
        }
        Write-Host "PASS: $mode ($reportPath)"
    }
    finally { $testProcess.Dispose() }
}
