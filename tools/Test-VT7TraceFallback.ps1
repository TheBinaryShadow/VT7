# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Deliberately stops this test's own child at the initial debugger breakpoint.
param([Parameter(Mandatory = $true)][string]$CdbPath)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..'))
$runnerPath = Join-Path $root 'src\vt7\VT7.ResourceTrace\Run-ResourceTrace.ps1'
$runner = [IO.File]::ReadAllText($runnerPath)
$source = [regex]::Match($runner, "(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
$fallback = [regex]::Match($runner, "\`$vt7Fallback = '([^']+)' \}").Groups[1].Value
if (-not $source -or -not $fallback) { throw 'Current process helper or unexpected-stop command was not found.' }
$run = Join-Path $root ('artifacts\vt7\diagnostics\trace-fallback-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $run | Out-Null
Copy-Item -LiteralPath $runnerPath -Destination $run
[IO.File]::WriteAllText((Join-Path $run 'fallback.txt'), $fallback, [Text.Encoding]::ASCII)
Add-Type -TypeDefinition $source
$binaryRoot = Join-Path $root 'artifacts\resource-lifetime-0.2'
$exe = Join-Path $binaryRoot 'VT7.ResourceLifetime.exe'
if ((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ne '438FC74130CE3D7A255BEDF368FEA1371778CB0A85CF9D5EBCF1A295C246F71F') { throw 'Issued fixture binary mismatch.' }
$arguments = '-G -y "' + (Join-Path $binaryRoot 'symbols') + '" -c ".echo VT7_EXPECTED_INTERACTIVE_STOP" "' + $exe + '"'
$combinedPath = Join-Path $run 'combined.log'
$stderrPath = Join-Path $run 'stderr.log'
$timer = [Diagnostics.Stopwatch]::StartNew()
$exitCode = [VT7TraceProcess]::Run($CdbPath, $arguments, $binaryRoot, $combinedPath, $stderrPath, 15000, $fallback)
$timer.Stop()
$text = [IO.File]::ReadAllText($combinedPath)
if ($exitCode -ne 0 -or [regex]::Matches($text, '(?m)^VT7_TRACE_ABORT_UNEXPECTED_STOP\r?$').Count -ne 1 -or
    $text -match '(?m)^VT7 RESOURCE LIFETIME' -or [IO.File]::ReadAllText($stderrPath).Trim()) {
    throw "Unexpected-stop fallback failed. Preserve $run"
}
foreach ($pattern in @('(?m)^Last event:', 'ExceptionCode:\s+80000003', '(?m)^Child-SP\s+RetAddr\s+Call Site', '(?m)^quit:')) {
    if ($text -notmatch $pattern) { throw "Fallback did not capture context or terminate: $pattern" }
}
. (Join-Path $root 'src\vt7\VT7.ResourceTrace\Validate-ResourceTrace.ps1')
$rejected = $false
try { Assert-VT7ResourceTrace $text } catch { $rejected = $_.Exception.Message -match 'VT7_TRACE_ABORT_UNEXPECTED_STOP' }
if (-not $rejected) { throw 'Validator did not reject the explicit unexpected-stop marker.' }
$result = 'UNEXPECTED_STOP_FALLBACK=PASS; elapsed_ms=' + $timer.ElapsedMilliseconds + '; CDB_exit=' + $exitCode + '; application_workload_entered=NO; collection_rejected=YES'
[IO.File]::WriteAllText((Join-Path $run 'result.txt'), $result, [Text.Encoding]::ASCII)
Write-Host $result
Write-Host "Evidence: $run"
