[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ReportPath, [int]$ExitCode = 3)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $root 'src/vt7/VT7.ResourceReactivation/Validate-ResourceReactivation.ps1')
$original = [IO.File]::ReadAllText($ReportPath)
$output = Join-Path $root ('artifacts/vt7/diagnostics/reactivation-validator-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff') + '-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output | Out-Null
$result = Test-VT7ReactivationReport $ReportPath $ExitCode
$cases = [ordered]@{
    'truncated-tail' = $original.Substring(0, $original.LastIndexOf('EXIT code='))
    'duplicate-complete' = $original.Replace('C3_RESOURCE_VERDICT=', "COLLECTION=COMPLETE rounds=9`nC3_RESOURCE_VERDICT=")
    'missing-second-round-scheduling' = $original.Replace('WORK round=2 PASS: hidden output consumed', 'REMOVED hidden output consumed')
    'injection-enabled' = $original.Replace('inject_work=0', 'inject_work=1')
    'baseline-reset' = $original.Replace('ROUND_BEGIN round=2 baseline_sample=2', 'ROUND_BEGIN round=2 baseline_sample=9')
    'budget-cleared' = $original.Replace('resource_budget_failures=' + $result.BudgetFailures, 'resource_budget_failures=0')
    'missing-sample' = [regex]::Replace($original, '(?m)^RESOURCE sample=10 .+\r?\n', '')
    'duplicate-sample' = [regex]::Replace($original, '(?m)^(RESOURCE sample=10 .+)$', '$1' + "`n" + '$1')
    'changed-sample-phase' = $original.Replace('sample=16 phase=closed-180s', 'sample=16 phase=closed-90s')
    'missing-idle' = [regex]::Replace($original, '(?m)^IDLE_END round=2 target_ms=180000 .+\r?\n', '')
    'shortened-idle' = $original.Replace('target_ms=180000', 'target_ms=180001')
    'wrong-delta' = [regex]::Replace($original, '(?m)^(DELTA sample=16 reference=previous_idle reference_sample=9 private=)-?\d+', '${1}99999999')
    'wrong-thread-creation' = [regex]::Replace($original, '(?m)^(THREAD sample=2 tid=\d+ creation=)[0-9A-F]+', '${1}0000000000000000')
    'missing-liveness-guard' = $original.Replace('alive_after=258', 'alive_after=0')
    'unknown-queue-as-absence' = $original.Replace('queue=unavailable', 'queue=absent')
    'thread-identity-reset' = [regex]::Replace($original, '(?m)^(THREAD sample=16 .+ first_sample=)\d+', '${1}16')
    'wrong-thread-totals' = [regex]::Replace($original, '(?m)^(THREADS_END sample=16 rows=)\d+', '${1}9999')
    'unstable-thread-reused' = $original.Replace('status=live', 'status=changed')
    'idle-redraw' = $original.Replace('presents +0, renderer calls +0', 'presents +1, renderer calls +0')
    'wrong-operation-count' = $original.Replace('measured_resizes=2000', 'measured_resizes=1000')
    'wrong-workload-order' = $original.Replace('ROUND_BEGIN round=2 baseline_sample=2', '').Replace('ROUND_END round=2 baseline_sample=2', "ROUND_BEGIN round=2 baseline_sample=2`nROUND_END round=2 baseline_sample=2")
}
$records = @()
foreach ($case in $cases.Keys) {
    if ($cases[$case] -eq $original) { throw "Mutation did not change evidence: $case" }
    $path = Join-Path $output ($case + '.log')
    [IO.File]::WriteAllText($path, $cases[$case], (New-Object Text.UTF8Encoding($false)))
    $errorText = $null
    try { [void](Test-VT7ReactivationReport $path $ExitCode) } catch { $errorText = $_.Exception.Message }
    if ($null -eq $errorText) { throw "Validator accepted invalid evidence: $case" }
    $records += [ordered]@{ Case = $case; Rejected = $true; Reason = $errorText }
}
try { [void](Test-VT7ReactivationReport $ReportPath 1); throw 'Wrong exit code was accepted.' }
catch { if ($_.Exception.Message -eq 'Wrong exit code was accepted.') { throw } }
$records += [ordered]@{ Case = 'wrong-process-exit'; Rejected = $true }
$summary = [ordered]@{ ValidReport = [IO.Path]::GetFullPath($ReportPath); ReportSHA256 = (Get-FileHash -LiteralPath $ReportPath).Hash;
    ValidatorSHA256 = (Get-FileHash -LiteralPath (Join-Path $root 'src/vt7/VT7.ResourceReactivation/Validate-ResourceReactivation.ps1')).Hash;
    TestSourceSHA256 = (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path).Hash; AcceptedCompleteReport = $true; RejectedControls = $records }
[IO.File]::WriteAllText((Join-Path $output 'RESULT.json'), ($summary | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
Write-Host "Accepted complete report; rejected $($records.Count) altered/failed controls. $output"
