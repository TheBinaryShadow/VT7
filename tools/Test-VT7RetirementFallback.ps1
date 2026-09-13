# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Windows PowerShell 2.0 compatible. Stops only this test's own child at entry.
param(
    [Parameter(Mandatory = $true)][string]$CdbPath,
    [Parameter(Mandatory = $true)][string]$BinaryRoot
)
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..'))
$runnerPath = Join-Path $repositoryRoot 'src\vt7\VT7.ResourceRetirement\Run-ResourceRetirement.ps1'
$validatorPath = Join-Path $repositoryRoot 'src\vt7\VT7.ResourceRetirement\Validate-ResourceRetirement.ps1'
$runner = [IO.File]::ReadAllText($runnerPath)
$source = [regex]::Match($runner, "(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
$fallback = [regex]::Match($runner, "\`$vt7Fallback = '([^']+)' \}").Groups[1].Value
if (-not $source -or -not $fallback -or $source -notmatch 'public static class VT7RetirementProcess') { throw 'Current retirement process helper or unexpected-stop command was not found.' }
function Get-VT7RetirementFixtureHash {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $hash = New-Object Security.Cryptography.SHA256CryptoServiceProvider
    try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-', '') }
    finally { $hash.Clear(); $stream.Dispose() }
}
$CdbPath = [IO.Path]::GetFullPath($CdbPath)
$BinaryRoot = [IO.Path]::GetFullPath($BinaryRoot)
$exe = Join-Path $BinaryRoot 'VT7.ResourceRetirement.exe'
if ((Get-VT7RetirementFixtureHash $exe) -ne '9F07A67AC9A4B0226BAFD1E313E47DF2D9D426C5A0555377B6AD647A3F886FD4') { throw 'Pinned retirement fixture executable mismatch.' }
foreach ($path in @($CdbPath, $BinaryRoot)) {
    if ($path -match '["\r\n]' -or $path.EndsWith('\')) { throw 'Unsupported fixture argument path.' }
}
$run = Join-Path $repositoryRoot ('artifacts\vt7\diagnostics\retirement-fallback-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
[void][IO.Directory]::CreateDirectory($run)
foreach ($path in @($runnerPath, $validatorPath, $MyInvocation.MyCommand.Path)) { Copy-Item -LiteralPath $path -Destination $run }
[IO.File]::WriteAllText((Join-Path $run 'fallback.txt'), $fallback, [Text.Encoding]::ASCII)
Add-Type -TypeDefinition $source
$arguments = '-G -y "' + (Join-Path $BinaryRoot 'symbols') + '" -c ".echo VT7_EXPECTED_INTERACTIVE_STOP" "' + $exe + '"'
[IO.File]::WriteAllLines((Join-Path $run 'inputs.txt'), [string[]]@(
    ('PowerShell=' + $PSVersionTable.PSVersion.ToString()),
    ('CDB=' + $CdbPath),
    ('CDB_SHA256=' + (Get-VT7RetirementFixtureHash $CdbPath)),
    ('EXE=' + $exe),
    ('EXE_SHA256=' + (Get-VT7RetirementFixtureHash $exe)),
    ('RUNNER_SHA256=' + (Get-VT7RetirementFixtureHash $runnerPath)),
    ('VALIDATOR_SHA256=' + (Get-VT7RetirementFixtureHash $validatorPath)),
    ('TEST_SHA256=' + (Get-VT7RetirementFixtureHash $MyInvocation.MyCommand.Path)),
    ('Arguments=' + $arguments),
    'Fixture launches its own child only; no attach, detach, resumed application workload or system setting change.'
), [Text.Encoding]::UTF8)
$combinedPath = Join-Path $run 'combined.log'
$stderrPath = Join-Path $run 'stderr.log'
$timer = [Diagnostics.Stopwatch]::StartNew()
$exitCode = [VT7RetirementProcess]::Run($CdbPath, $arguments, $BinaryRoot, $combinedPath, $stderrPath, 15000, $fallback)
$timer.Stop()
$text = [IO.File]::ReadAllText($combinedPath)
if ($exitCode -ne 0 -or $timer.ElapsedMilliseconds -ge 15000 -or
    [regex]::Matches($text, '(?m)^VT7_TRACE_ABORT_UNEXPECTED_STOP\r?$').Count -ne 1 -or
    [regex]::Matches($text, '(?m)^VT7_EXPECTED_INTERACTIVE_STOP\r?$').Count -ne 1 -or
    $text -match '(?m)^(?:VT7 RESOURCE RETIREMENT|CONFIG |NATIVE |RESOURCE |WORKLOAD |IDLE_WAIT)' -or [IO.File]::ReadAllText($stderrPath).Trim()) {
    throw "Unexpected-stop fallback failed. Preserve $run"
}
foreach ($pattern in @('(?m)^Last event:', 'ExceptionCode:\s+80000003', '(?m)^rip=[0-9a-f`]+\s+rsp=', '(?m)^Child-SP\s+RetAddr\s+Call Site', '(?m)^quit:')) {
    if ($text -notmatch $pattern) { throw "Fallback did not capture context or terminate: $pattern" }
}
. $validatorPath
$rejected = $false
try { Assert-VT7ResourceRetirement $text } catch { $rejected = $_.Exception.Message -match 'VT7_TRACE_ABORT_UNEXPECTED_STOP' }
if (-not $rejected) { throw 'Retirement validator did not reject the explicit unexpected-stop marker.' }
$result = 'UNEXPECTED_STOP_FALLBACK=PASS; elapsed_ms=' + $timer.ElapsedMilliseconds + '; CDB_exit=' + $exitCode + '; application_workload_entered=NO; collection_rejected=YES'
[IO.File]::WriteAllText((Join-Path $run 'result.txt'), $result, [Text.Encoding]::ASCII)
Write-Host $result
Write-Host "Evidence: $run"
