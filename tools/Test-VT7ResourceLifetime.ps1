[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BinaryDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binaryRoot = [IO.Path]::GetFullPath($BinaryDirectory)
$executablePath = Join-Path $binaryRoot 'VT7.ResourceLifetime.exe'
$nativePath = Join-Path $binaryRoot 'VT7.Native.dll'
foreach ($path in @($executablePath, $nativePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required diagnostic binary is missing: $path" }
}
$runId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff') + '-' + [Guid]::NewGuid().ToString('N')
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\diagnostics\resource-lifetime-tests-$runId"
if (Test-Path -LiteralPath $reportRoot) { throw "Refusing to replace earlier test evidence: $reportRoot" }
New-Item -ItemType Directory -Path $reportRoot | Out-Null
$summaryPath = Join-Path $reportRoot 'summary.txt'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllLines($summaryPath, @(
    'VT7 resource lifetime 0.2 bounded diagnostic verification',
    "Binary directory: $binaryRoot",
    "Executable SHA256: $((Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash)",
    "Native DLL SHA256: $((Get-FileHash -LiteralPath $nativePath -Algorithm SHA256).Hash)",
    'One measured iteration plus two warm-up iterations; 60-second timeout per child.',
    'These checks validate diagnostic operation and rejection paths, not resource-growth acceptance or Windows 7 execution.'
), $utf8)

function Assert-OneMarker {
    param([string]$Text, [string]$Pattern)
    if ([regex]::Matches($Text, $Pattern).Count -ne 1) { throw "Expected one marker: $Pattern" }
}

function Invoke-Diagnostic {
    param([string]$Name, [string[]]$Arguments)
    $stdoutPath = Join-Path $reportRoot "$Name.log"
    $stderrPath = Join-Path $reportRoot "$Name.stderr.log"
    # Arguments contain controlled options or absolute Windows paths, with no quotes.
    $argumentLine = (@($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' ')
    $process = $null
    try {
        $process = Start-Process -FilePath $executablePath -ArgumentList $argumentLine -WorkingDirectory $binaryRoot `
            -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        # Keep the exact launched process handle, independent of later numeric PID reuse.
        $processHandle = $process.Handle
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            if (-not $process.WaitForExit(5000)) { throw 'The timed-out diagnostic child did not exit after termination.' }
            throw 'Diagnostic child timed out after 60 seconds; partial logs retained.'
        }
        # The bounded wait established process exit; finish redirected output delivery.
        $process.WaitForExit()
        $process.Refresh()
        if ($null -eq $process.ExitCode) { throw 'The launched diagnostic process exit code was unavailable.' }
        $exitCode = $process.ExitCode
        $text = [IO.File]::ReadAllText($stdoutPath)
        if ([IO.File]::ReadAllText($stderrPath).Trim().Length) { throw 'Diagnostic child wrote unexpected stderr output.' }
        [pscustomobject]@{ Name = $Name; ExitCode = $exitCode; Text = $text; LogPath = $stdoutPath }
    }
    finally {
        if ($null -ne $process) {
            try {
                if (-not $process.HasExited) {
                    # Terminate only the exact child still held by this Process instance.
                    $process.Kill()
                    if (-not $process.WaitForExit(5000)) { throw 'The owned diagnostic child did not exit during cleanup; partial logs retained.' }
                    $process.WaitForExit()
                }
            }
            finally { $process.Dispose() }
        }
    }
}

function Assert-ThreadHistory {
    param([string]$Text)
    $resourcePattern = '(?m)^RESOURCE sample=(?<sample>[0-9]+) phase=(?<phase>\S+) iteration=(?<iteration>[0-9]+) live=(?<live>[01]) private=[0-9]+ handles=[0-9]+ GDI=[0-9]+ USER=[0-9]+ threads=(?<threads>[0-9]+) begin_ms=(?<begin>[0-9]+) end_ms=(?<end>[0-9]+)\r?$'
    $threadPattern = '(?m)^THREAD sample=(?<sample>[0-9]+) tid=(?<tid>[0-9]+) creation=(?<creation>[0-9A-F]{16}) identity_error=(?<identity_error>[0-9]+) observation=(?<observation>\S+) first_sample=(?<first>[0-9]+) queue=(?<queue>observed|unavailable) queue_error=(?<queue_error>[0-9]+) first_queue_sample=(?<first_queue>[0-9]+) alive_before=(?<alive_before>[0-9]+) alive_after=(?<alive_after>[0-9]+) origin=.+ offset=[0-9A-F]+ start=[0-9A-F]+ origin_status=[0-9A-F]{8} module_error=[0-9]+\r?$'
    $absencePattern = '(?m)^NOT_OBSERVED sample=(?<sample>[0-9]+) tid=(?<tid>[0-9]+) creation=(?<creation>[0-9A-F]{16}) previous_sample=(?<previous>[0-9]+); absence_from_snapshot_not_complete_exit_history\r?$'
    $resources = [regex]::Matches($Text, $resourcePattern)
    $threadRows = [regex]::Matches($Text, $threadPattern)
    $absenceRows = [regex]::Matches($Text, $absencePattern)
    if ($resources.Count -ne 6 -or [regex]::Matches($Text, '(?m)^RESOURCE ').Count -ne 6) { throw 'Expected six complete resource checkpoints.' }
    if ($threadRows.Count -ne [regex]::Matches($Text, '(?m)^THREAD ').Count) { throw 'Malformed thread record.' }
    if ($absenceRows.Count -ne [regex]::Matches($Text, '(?m)^NOT_OBSERVED ').Count) { throw 'Malformed absence record.' }
    $expectedPhases = @('pre-warmup', 'warmup-live', 'baseline-live', 'measured-live', 'final-closed', 'final-closed-10s')
    $expectedIterations = @(0, 0, 0, 1, 1, 1)
    $expectedLive = @(0, 1, 1, 1, 0, 0)
    $history = @{}
    $seenTids = @{}
    $unavailable = 0
    $countedRows = 0
    $countedAbsences = 0
    [uint64]$previousEnd = 0
    for ($index = 0; $index -lt 6; ++$index) {
        $sample = $index + 1
        $resource = $resources[$index]
        if ([int]$resource.Groups['sample'].Value -ne $sample -or $resource.Groups['phase'].Value -ne $expectedPhases[$index] -or
            [int]$resource.Groups['iteration'].Value -ne $expectedIterations[$index] -or [int]$resource.Groups['live'].Value -ne $expectedLive[$index]) {
            throw "Mismatched resource checkpoint $sample."
        }
        [uint64]$begin = $resource.Groups['begin'].Value
        [uint64]$end = $resource.Groups['end'].Value
        if ($begin -gt $end -or $begin -lt $previousEnd) { throw "Invalid sequential measurement timestamps at sample $sample." }
        $previousEnd = $end
        $rows = @($threadRows | Where-Object { [int]$_.Groups['sample'].Value -eq $sample })
        if (-not $rows.Count -or $rows.Count -ne [int]$resource.Groups['threads'].Value) { throw "Thread row count mismatch at sample $sample." }
        $countedRows += $rows.Count
        $currentIdentities = @{}
        $currentTids = @{}
        foreach ($row in $rows) {
            $tid = $row.Groups['tid'].Value
            $creation = $row.Groups['creation'].Value
            $key = $tid + ':' + $creation
            $observation = $row.Groups['observation'].Value
            $first = [int]$row.Groups['first'].Value
            $firstQueue = [int]$row.Groups['first_queue'].Value
            $queue = $row.Groups['queue'].Value -eq 'observed'
            if ($tid -eq '0' -or $currentTids.ContainsKey($tid) -or $currentIdentities.ContainsKey($key)) { throw "Duplicate or invalid TID/creation identity at sample $sample." }
            $currentTids[$tid] = $true
            $currentIdentities[$key] = $true
            if ($creation -eq '0000000000000000') {
                ++$unavailable
                if ($observation -ne 'identity-unavailable' -or $first -ne 0 -or $firstQueue -ne 0 -or $queue -or
                    [uint32]$row.Groups['identity_error'].Value -eq 0) { throw "Unavailable identity was presented as known at sample $sample." }
                continue
            }
            if ([uint32]$row.Groups['identity_error'].Value -ne 0) { throw "Known identity carries an identity error at sample $sample." }
            if ($queue -and ([uint32]$row.Groups['queue_error'].Value -ne 0 -or
                [uint32]$row.Groups['alive_before'].Value -ne 258 -or [uint32]$row.Groups['alive_after'].Value -ne 258)) {
                throw "Observed queue lacks a valid liveness bracket at sample $sample."
            }
            if ($history.ContainsKey($key)) {
                $entry = $history[$key]
                $expectedObservation = if ($entry.LastSample -eq $sample - 1) { 'surviving' } else { 'seen-earlier' }
                if ($first -ne $entry.FirstSample -or $observation -ne $expectedObservation) { throw "Lost survivor identity continuity at sample $sample for $key." }
                if ($queue -and $entry.FirstQueue -eq 0) { $entry.FirstQueue = $sample }
                if ($firstQueue -ne $entry.FirstQueue) { throw "Changed first queue observation at sample $sample for $key." }
                $entry.LastSample = $sample
            }
            else {
                $expectedObservation = if ($seenTids.ContainsKey($tid)) { 'new-identity-reused-tid' } else { 'newly-observed' }
                $expectedQueue = if ($queue) { $sample } else { 0 }
                if ($first -ne $sample -or $firstQueue -ne $expectedQueue -or $observation -ne $expectedObservation) {
                    throw "Incorrect new identity or numeric TID reuse metadata at sample $sample for $key."
                }
                $history[$key] = [pscustomobject]@{ FirstSample = $sample; LastSample = $sample; FirstQueue = $firstQueue }
                $seenTids[$tid] = $true
            }
        }
        $expectedAbsences = @($history.Keys | Where-Object { $history[$_].LastSample -eq $sample - 1 })
        $absences = @($absenceRows | Where-Object { [int]$_.Groups['sample'].Value -eq $sample })
        $countedAbsences += $absences.Count
        if ($absences.Count -ne $expectedAbsences.Count) { throw "Absence record count mismatch at sample $sample." }
        $absenceKeys = @{}
        foreach ($row in $absences) {
            $key = $row.Groups['tid'].Value + ':' + $row.Groups['creation'].Value
            if ($absenceKeys.ContainsKey($key) -or $expectedAbsences -notcontains $key -or [int]$row.Groups['previous'].Value -ne $sample - 1) {
                throw "Invalid or duplicate absence record at sample $sample."
            }
            $absenceKeys[$key] = $true
        }
    }
    if ($countedRows -ne $threadRows.Count -or $countedAbsences -ne $absenceRows.Count) { throw 'Thread records refer to an unknown resource sample.' }
    Assert-OneMarker $Text ('(?m)^ATTRIBUTION samples=6 identities=' + $history.Count + ' identity_unavailable=' + $unavailable + '; queue_unavailable_is_not_queue_absent\r?$')
}

function Assert-CompletedMeasurement {
    param($Result, [string]$Mode)
    if ($Result.ExitCode -ne 0) { throw "Expected completed measurement exit 0; found $($Result.ExitCode)." }
    if ($Result.Text -match '(?m)^(FAIL |INCOMPLETE:|CLEANUP )') { throw 'Completed measurement contains a failure/cleanup marker.' }
    Assert-OneMarker $Result.Text '(?m)^VT7 RESOURCE LIFETIME 0\.2;'
    Assert-OneMarker $Result.Text ('(?m)^CONFIG mode=' + $Mode + ' renderer=2 capture=1 power=0 probes=0 warmup=2 cycles=1 fail_at_cycle=0\r?$')
    Assert-OneMarker $Result.Text '(?m)^NATIVE 0\.3\.5 ABI=8 Release '
    Assert-OneMarker $Result.Text '(?m)^SAMPLING sequential_not_atomic=1 .+queue_failure_is_unknown; start_address_is_not_owner; unsampled_threads_may_be_missed\r?$'
    $creates = if ($Mode -eq 'recreate') { 3 } else { 1 }
    Assert-OneMarker $Result.Text ('(?m)^WORKLOAD iterations=3 creates=' + $creates + ' destroys=' + $creates + ' resizes=30 size_resets=3 hide_show=15 power_registrations=0 power_unregistrations=0 power_delivered=0\r?$')
    Assert-OneMarker $Result.Text '(?m)^COMPLETED: measurement only, not stability acceptance\. No soak performed\.\r?$'
    Assert-ThreadHistory $Result.Text
}

function Assert-RejectedMeasurement {
    param($Result, [string]$Operation, [bool]$Cleanup = $false)
    if ($Result.ExitCode -ne 1) { throw "Expected rejection exit 1; found $($Result.ExitCode)." }
    Assert-OneMarker $Result.Text ('(?m)^FAIL operation=' + [regex]::Escape($Operation) + ' hresult=[0-9A-F]{8}\r?$')
    if ([regex]::Matches($Result.Text, '(?m)^FAIL ').Count -ne 1) { throw 'Expected exactly one failure marker.' }
    Assert-OneMarker $Result.Text '(?m)^INCOMPLETE: preserve partial measurements; no resource acceptance\.\r?$'
    if ($Result.Text -match '(?m)^(COMPLETED:|WORKLOAD |ATTRIBUTION )') { throw 'Rejected measurement contains a completed workload/attribution marker.' }
    if ($Cleanup) { Assert-OneMarker $Result.Text '(?m)^CLEANUP destroy_surface_hresult=00000000\r?$' }
    elseif ($Result.Text -match '(?m)^CLEANUP ') { throw 'Unexpected live-surface cleanup in an early/recreate rejection.' }
}

$cases = @(
    @{ Name = 'recreate-one'; Args = @($nativePath, 'recreate', '--cycles', '1'); Mode = 'recreate'; Operation = ''; Cleanup = $false },
    @{ Name = 'reuse-one'; Args = @($nativePath, 'reuse', '--cycles', '1'); Mode = 'reuse'; Operation = ''; Cleanup = $false },
    @{ Name = 'recreate-injected'; Args = @($nativePath, 'recreate', '--cycles', '1', '--fail-at-cycle', '1'); Mode = ''; Operation = 'injected-workload-failure'; Cleanup = $false },
    @{ Name = 'reuse-injected'; Args = @($nativePath, 'reuse', '--cycles', '1', '--fail-at-cycle', '1'); Mode = ''; Operation = 'injected-workload-failure'; Cleanup = $true },
    @{ Name = 'cycles-zero'; Args = @($nativePath, 'recreate', '--cycles', '0'); Mode = ''; Operation = 'argument-range-1-to-100'; Cleanup = $false },
    @{ Name = 'cycles-101'; Args = @($nativePath, 'recreate', '--cycles', '101'); Mode = ''; Operation = 'argument-range-1-to-100'; Cleanup = $false },
    @{ Name = 'duplicate-cycles'; Args = @($nativePath, 'recreate', '--cycles', '1', '--cycles', '1'); Mode = ''; Operation = 'unknown-or-duplicate-option'; Cleanup = $false },
    @{ Name = 'missing-dll'; Args = @((Join-Path $reportRoot 'deliberately-missing-native.dll'), 'recreate', '--cycles', '1'); Mode = ''; Operation = 'load-native-dll'; Cleanup = $false },
    @{ Name = 'wrong-dll'; Args = @((Join-Path $env:WINDIR 'System32\kernel32.dll'), 'recreate', '--cycles', '1'); Mode = ''; Operation = 'VT7_CreateSurface-export'; Cleanup = $false }
)
$failed = 0
Write-Host "Diagnostic verification logs: $reportRoot"
foreach ($case in $cases) {
    try {
        Write-Host "Checking $($case.Name)..."
        $result = Invoke-Diagnostic -Name $case.Name -Arguments $case.Args
        if ($case.Mode) { Assert-CompletedMeasurement $result $case.Mode }
        else { Assert-RejectedMeasurement $result $case.Operation $case.Cleanup }
        $message = "PASS $($case.Name) process_exit=$($result.ExitCode); diagnostic semantics verified; resource_growth_acceptance=NOT_EVALUATED"
        [IO.File]::AppendAllText($summaryPath, $message + [Environment]::NewLine, $utf8)
        Write-Host $message
    }
    catch {
        ++$failed
        $message = "FAIL $($case.Name): $($_.Exception.Message)"
        [IO.File]::AppendAllText($summaryPath, $message + [Environment]::NewLine, $utf8)
        Write-Host $message
    }
}
$verdict = "VERIFICATION cases=$($cases.Count) failures=$failed; resource_growth_acceptance=NOT_EVALUATED; no_soak=1"
[IO.File]::AppendAllText($summaryPath, $verdict + [Environment]::NewLine, $utf8)
Write-Host $verdict
if ($failed) { throw "$failed diagnostic verification case(s) failed. Retained evidence: $reportRoot" }
[pscustomobject]@{ ReportDirectory = $reportRoot; SummaryPath = $summaryPath; Cases = $cases.Count; Failures = $failed }
