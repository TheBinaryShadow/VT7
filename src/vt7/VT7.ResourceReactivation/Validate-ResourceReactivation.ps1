# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Windows PowerShell 2.0 compatible. Recompute verdicts from the captured series.
function Test-VT7ReactivationReport {
    param([string]$Path, [int]$ExitCode)
    function Require-Reactivation { param([bool]$Condition, [string]$Reason) if (!$Condition) { throw "Invalid reactivation report: $Reason" } }
    function Number-Reactivation {
        param($Row, [string]$Key)
        Require-Reactivation ($Row.ContainsKey($Key) -and $Row[$Key] -match '^-?\d+$') "missing/nonnumeric $Key"
        return [long]::Parse($Row[$Key], [Globalization.CultureInfo]::InvariantCulture)
    }
    $lines = [IO.File]::ReadAllLines($Path)
    Require-Reactivation ($lines.Count -gt 20 -and $lines[0] -eq 'VT7 WPF RESOURCE REACTIVATION 0.1') 'header'
    $groups = @{}
    for ($i = 1; $i -lt $lines.Count; ++$i) {
        $line = $lines[$i]
        Require-Reactivation (!$line.StartsWith('ERROR ') -and !$line.StartsWith('COLLECTION=INCOMPLETE')) 'aborted collection'
        if ($line -match '^(CONFIG|PROCESS|RESOURCE|DELTA|THREAD|NOT_OBSERVED|THREADS_END|BASELINE_FIXED|WARMUP_BEGIN|ROUND_BEGIN|BUDGET|ROUND_WORK_COMPLETE|IDLE_BEGIN|IDLE_END|ROUND_END|WORKLOAD|EXIT) (.+)$') {
            $kind = $Matches[1]; $fields = $Matches[2]; $row = @{ _line = $i }
            foreach ($field in $fields.Split(' ')) {
                Require-Reactivation ($field -match '^([a-zA-Z_]+)=([^= ]+)$') "malformed $kind field"
                $key = $Matches[1]; $value = $Matches[2]
                Require-Reactivation (!$row.ContainsKey($key)) "duplicate $kind/$key"
                $row[$key] = $value
            }
            if (!$groups.ContainsKey($kind)) { $groups[$kind] = New-Object Collections.ArrayList }
            [void]$groups[$kind].Add($row)
        }
    }
    function Rows-Reactivation { param([string]$Kind, [int]$Count)
        Require-Reactivation ($groups.ContainsKey($Kind) -and $groups[$Kind].Count -eq $Count) "$Kind count"
        return ,$groups[$Kind]
    }
    function Exact-Reactivation { param([string]$Line, [int]$Count)
        Require-Reactivation (@($lines | Where-Object { $_ -ceq $Line }).Count -eq $Count) $Line
    }
    Exact-Reactivation 'CONFIG rounds=2 warmup=2 cycles_per_round=100 renderer=2 capture=1 baseline=fixed idle_targets_ms=10000,90000,180000 inject_work=0 inject_idle=0' 1
    [void](Rows-Reactivation CONFIG 1)
    Exact-Reactivation 'SAMPLING sequential_not_atomic=1 queue_failure_is_unknown=1 not_observed_is_not_exit_proof=1 debugger_required=0' 1
    Exact-Reactivation 'STARTUP_CHECKS=PASS count=1' 1
    Exact-Reactivation 'WARMUP_BEGIN lifecycles=2' 1
    Exact-Reactivation 'BASELINE_FIXED sample=2' 1
    Require-Reactivation (@($lines | Where-Object { $_.StartsWith('COLLECTION=') }).Count -eq 1 -and @($lines | Where-Object { $_.StartsWith('C3_RESOURCE_VERDICT=') }).Count -eq 1) 'duplicate/conflicting completion'
    [void](Rows-Reactivation WARMUP_BEGIN 1); [void](Rows-Reactivation BASELINE_FIXED 1)
    $process = (Rows-Reactivation PROCESS 1)[0]
    Require-Reactivation ((Number-Reactivation $process pid) -gt 0 -and (Number-Reactivation $process creation) -gt 0 -and $process.bits -eq '64' -and $process.host_version -eq '0.1.0.0') 'process identity'
    $resources = Rows-Reactivation RESOURCE 16
    $ends = Rows-Reactivation THREADS_END 16
    $begins = Rows-Reactivation ROUND_BEGIN 2
    $workEnds = Rows-Reactivation ROUND_WORK_COMPLETE 2
    $roundEnds = Rows-Reactivation ROUND_END 2
    $budgets = Rows-Reactivation BUDGET 8
    $idleBegins = Rows-Reactivation IDLE_BEGIN 6
    $idleEnds = Rows-Reactivation IDLE_END 6
    $deltas = Rows-Reactivation DELTA 30
    $baseline = $resources[1]
    $failures = 0; $lastEnd = 0L; $order = New-Object Collections.ArrayList
    $identities = @{}; $baselineIdentities = @{}; $queueBaseline = @{}; $inventorySummary = @()
    for ($index = 0; $index -lt 16; ++$index) {
        $sample = $index + 1; $row = $resources[$index]
        $round = 0; $cycle = 0; $phase = 'pre-warmup'; $baseId = 0
        if ($sample -eq 2) { $phase = 'baseline-closed' }
        if ($sample -gt 2) {
            $round = 1 + [int][Math]::Floor(($sample - 3) / 7.0); $slot = ($sample - 3) % 7; $baseId = 2
            if ($slot -lt 4) { $cycle = ($slot + 1) * 25; $phase = 'cycle-' + $cycle }
            else { $cycle = 100; $phase = 'closed-' + @('10s','90s','180s')[$slot - 4] }
        }
        Require-Reactivation ($row.sample -eq "$sample" -and $row.phase -eq $phase -and $row.round -eq "$round" -and $row.cycle -eq "$cycle" -and $row.baseline_sample -eq "$baseId") "sample $sample identity/baseline"
        foreach ($key in @('private','handles','threads','GDI','USER','closed_elapsed_ms')) { Require-Reactivation ((Number-Reactivation $row $key) -ge 0) "sample $sample/$key" }
        $begin = Number-Reactivation $row begin_ms; $end = Number-Reactivation $row end_ms
        Require-Reactivation ($begin -ge $lastEnd -and $end -ge $begin) "sample $sample chronology"
        $lastEnd = $end
        [void]$order.Add($row._line)
        if ($sample -eq 1) { [void]$order.Add($groups.WARMUP_BEGIN[0]._line) }
        if ($sample -eq 2) { [void]$order.Add($groups.BASELINE_FIXED[0]._line); [void]$order.Add($begins[0]._line) }
        $referenceNames = @(); $referenceRows = @()
        if ($sample -gt 1) { $referenceNames += 'startup'; $referenceRows += $resources[0] }
        if ($sample -gt 2) { $referenceNames += 'baseline'; $referenceRows += $baseline }
        if ($sample -eq 16) { $referenceNames += 'previous_idle'; $referenceRows += $resources[8] }
        $sampleDeltas = @($deltas | Where-Object { $_.sample -eq "$sample" })
        Require-Reactivation ($sampleDeltas.Count -eq $referenceNames.Count) "sample $sample delta count"
        for ($d = 0; $d -lt $referenceNames.Count; ++$d) {
            $delta = @($sampleDeltas | Where-Object { $_.reference -eq $referenceNames[$d] })
            Require-Reactivation ($delta.Count -eq 1 -and $delta[0].reference_sample -eq $referenceRows[$d].sample) "sample $sample delta reference"
            foreach ($key in @('private','handles','threads','GDI','USER')) {
                Require-Reactivation ((Number-Reactivation $delta[0] $key) -eq ((Number-Reactivation $row $key) - (Number-Reactivation $referenceRows[$d] $key))) "sample $sample delta $key"
            }
        }
        if ($round -gt 0) {
            Require-Reactivation (((Number-Reactivation $row private) - (Number-Reactivation $baseline private)) -lt 536870912 -and ((Number-Reactivation $row handles) - (Number-Reactivation $baseline handles)) -lt 2048) 'safety ceiling'
            if ($slot -lt 4) {
                $budget = $budgets[($round - 1) * 4 + $slot]
                $pass = $true
                $limits = @{ private = 67108864L; handles = 32; threads = 8; GDI = 16; USER = 16 }
                foreach ($key in $limits.Keys) { if ((Number-Reactivation $row $key) - (Number-Reactivation $baseline $key) -gt $limits[$key]) { $pass = $false } }
                $verdict = 'PASS'; if (!$pass) { ++$failures; $verdict = 'FAIL' }
                Require-Reactivation ($budget.sample -eq "$sample" -and $budget.round -eq "$round" -and $budget.cycle -eq "$cycle" -and $budget.baseline_sample -eq '2' -and $budget.verdict -eq $verdict -and $budget.cumulative_failures -eq "$failures") "sample $sample budget/carry"
                [void]$order.Add($budget._line)
                if ($slot -eq 3) { [void]$order.Add($workEnds[$round - 1]._line) }
            }
            if ($slot -eq 6) {
                Require-Reactivation ($roundEnds[$round - 1].cumulative_failures -eq "$failures") "round $round budget carry"
                [void]$order.Add($roundEnds[$round - 1]._line)
                if ($round -eq 1) { [void]$order.Add($begins[1]._line) }
            }
        }
        $seen = @{}; $tids = @{}; $unknown = 0; $queues = 0; $survivors = 0; $queueSurvivors = 0
        $threadRows = @($groups.THREAD | Where-Object { $_.sample -eq "$sample" })
        Require-Reactivation ($threadRows.Count -gt 0 -and $threadRows.Count -le 4096) "sample $sample thread count"
        foreach ($thread in $threadRows) {
            Require-Reactivation ((Number-Reactivation $thread tid) -gt 0 -and !$tids.ContainsKey($thread.tid) -and $thread.creation -match '^[0-9A-F]{16}$') 'thread identity syntax/duplicate TID'
            $tids[$thread.tid] = $true
            Require-Reactivation ($thread._line -gt $row._line -and $thread._line -lt $ends[$index]._line) 'thread ordering'
            Require-Reactivation ($thread.queue -eq 'observed' -or $thread.queue -eq 'unavailable') 'queue state'
            if ($thread.status -eq 'live') {
                Require-Reactivation ($thread.creation -ne '0000000000000000' -and $thread.alive_before -eq '258' -and $thread.alive_after -eq '258') 'thread liveness guards'
                $key = $thread.tid + ':' + $thread.creation; $seen[$key] = $true
                if (!$identities.ContainsKey($key)) { $identities[$key] = @{ first = $sample; last = $sample; queue = 0 } }
                $identity = $identities[$key]; $identity.last = $sample
                if ($thread.queue -eq 'observed') { ++$queues; if ($identity.queue -eq 0) { $identity.queue = $sample }; Require-Reactivation ($thread.queue_error -eq '0') 'positive queue error' }
                Require-Reactivation ($thread.first_sample -eq "$($identity.first)" -and $thread.first_queue_sample -eq "$($identity.queue)") 'thread identity history'
                if ($sample -eq 2) { $baselineIdentities[$key] = $true; if ($thread.queue -eq 'observed') { $queueBaseline[$key] = $true } }
                if ($baselineIdentities.ContainsKey($key)) { ++$survivors }
                if ($queueBaseline.ContainsKey($key)) { ++$queueSurvivors }
            } else {
                ++$unknown
                Require-Reactivation (@('unavailable','owner-mismatch','changed','not-live') -contains $thread.status) 'unknown thread status'
                Require-Reactivation ($thread.queue -eq 'unavailable' -and $thread.first_sample -eq '0' -and $thread.first_queue_sample -eq '0') 'unstable identity used as evidence'
            }
        }
        $absent = @(); if ($groups.ContainsKey('NOT_OBSERVED')) { $absent = @($groups.NOT_OBSERVED | Where-Object { $_.sample -eq "$sample" }) }
        Require-Reactivation ($absent.Count -eq $identities.Count - $seen.Count) 'not-observed coverage'
        $absentSeen = @{}
        foreach ($thread in $absent) {
            $key = $thread.tid + ':' + $thread.creation
            Require-Reactivation ($identities.ContainsKey($key) -and !$seen.ContainsKey($key) -and !$absentSeen.ContainsKey($key)) 'not-observed identity'
            $identity = $identities[$key]; $absentSeen[$key] = $true
            Require-Reactivation ($thread.first_sample -eq "$($identity.first)" -and $thread.last_sample -eq "$($identity.last)" -and $thread.first_queue_sample -eq "$($identity.queue)" -and $thread._line -gt $row._line -and $thread._line -lt $ends[$index]._line) 'not-observed history/order'
        }
        $tail = $ends[$index]
        Require-Reactivation ($tail.sample -eq "$sample" -and (Number-Reactivation $tail rows) -eq $threadRows.Count -and (Number-Reactivation $tail unavailable) -eq $unknown -and (Number-Reactivation $tail identities) -eq $identities.Count -and (Number-Reactivation $tail not_observed) -eq $absent.Count) 'thread inventory totals'
        Require-Reactivation ((Number-Reactivation $tail begin_ms) -ge $end -and (Number-Reactivation $tail end_ms) -ge (Number-Reactivation $tail begin_ms)) 'thread snapshot timing'
        $inventorySummary += "sample=$sample phase=$phase round=$round handles=$($row.handles) USER=$($row.USER) threads=$($row.threads) private=$($row.private) queue_positive=$queues live_baseline_identities=$survivors live_baseline_queue_identities=$queueSurvivors unavailable=$unknown"
    }
    for ($round = 1; $round -le 2; ++$round) {
        $b = $begins[$round - 1]; $w = $workEnds[$round - 1]; $e = $roundEnds[$round - 1]
        Require-Reactivation ($b.round -eq "$round" -and $b.baseline_sample -eq '2' -and $e.round -eq "$round" -and $e.baseline_sample -eq '2') 'round identity'
        Require-Reactivation ($w.round -eq "$round" -and $w.lifecycles -eq '100' -and $w.resizes -eq '1000' -and $w.tab_trips -eq '500' -and (Number-Reactivation $w worst_close_ms) -le 2000) 'round workload'
        $closed = Number-Reactivation $w close_origin_ms
        $lastCycle = $resources[5 + ($round - 1) * 7]
        Require-Reactivation ((Number-Reactivation $lastCycle end_ms) - $closed -eq (Number-Reactivation $lastCycle closed_elapsed_ms)) 'close origin'
        $previousLine = $w._line
        for ($j = 0; $j -lt 3; ++$j) {
            $target = @(10000,90000,180000)[$j]; $ib = $idleBegins[($round - 1) * 3 + $j]; $ie = $idleEnds[($round - 1) * 3 + $j]
            $state = $resources[6 + ($round - 1) * 7 + $j]
            $begin = Number-Reactivation $ib begin_ms; $end = Number-Reactivation $ie end_ms
            Require-Reactivation ($ib.round -eq "$round" -and $ie.round -eq "$round" -and $ib.target_ms -eq "$target" -and $ie.target_ms -eq "$target" -and (Number-Reactivation $ib closed_ms) -eq $closed -and (Number-Reactivation $ie closed_ms) -eq $closed) 'idle identity'
            Require-Reactivation ((Number-Reactivation $ib requested_ms) -eq [Math]::Max(0L, $closed + $target - $begin) -and $end -ge $begin -and $end -ge $closed + $target -and (Number-Reactivation $ie elapsed_ms) -eq $end - $begin) 'idle timing'
            Require-Reactivation ($previousLine -lt $ib._line -and $ib._line -lt $ie._line -and $ie._line -lt $state._line -and (Number-Reactivation $state begin_ms) -ge $end -and (Number-Reactivation $state closed_elapsed_ms) -eq (Number-Reactivation $state end_ms) - $closed) 'idle sample timing/order'
            $previousLine = $state._line
        }
        foreach ($prefix in @('PASS: parked one-shot timer wake','PASS: explicit synchronized-output end','PASS: split DECSET 2026 missing-end timeout','PASS: 64 parked wake generations','PASS: hidden output consumed','MEASURE: visible idle','MEASURE: hidden with pending output idle')) {
            $matching = @($lines | Where-Object { $_.StartsWith("WORK round=$round $prefix") })
            Require-Reactivation ($matching.Count -eq 1) "round $round scheduling evidence: $prefix"
            if ($prefix.StartsWith('MEASURE:')) {
                Require-Reactivation ($matching[0] -match ' idle (\d+) ms, CPU (\d+(?:[.,]\d+)?)% of one logical CPU, presents \+0, renderer calls \+0, waits \+([01])$') 'idle scheduling counters'
                Require-Reactivation ([long]$Matches[1] -ge 2000 -and [double]::Parse($Matches[2].Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture) -le 5) 'idle scheduling time/CPU'
            }
        }
    }
    $workload = (Rows-Reactivation WORKLOAD 1)[0]
    Require-Reactivation ($workload.warmup -eq '2' -and $workload.rounds -eq '2' -and $workload.measured_lifecycles -eq '200' -and $workload.total_lifecycles -eq '202' -and $workload.measured_resizes -eq '2000' -and $workload.measured_tab_trips -eq '1000' -and $workload.samples -eq '16' -and (Number-Reactivation $workload worst_close_ms) -le 2000) 'final workload'
    [void]$order.Add($workload._line)
    for ($i = 1; $i -lt $order.Count; ++$i) { Require-Reactivation ($order[$i] -gt $order[$i - 1]) 'work/sample ordering' }
    $expectedExit = 0; $verdict = 'WITHIN_IMMEDIATE_BUDGETS'
    if ($failures -gt 0) { $expectedExit = 3; $verdict = 'FAIL' }
    Require-Reactivation ($ExitCode -eq $expectedExit) 'process exit contradicts budget verdict'
    Exact-Reactivation "COLLECTION=COMPLETE rounds=2 warmup=2 measured_lifecycles=200 resource_budget_failures=$failures" 1
    Exact-Reactivation "C3_RESOURCE_VERDICT=$verdict; INTEGRATED_ACCEPTANCE=OPEN; TIMED_SOAK=NOT_RUN" 1
    [void](Rows-Reactivation EXIT 1)
    Require-Reactivation ($lines[$lines.Count - 1] -eq "EXIT code=$expectedExit" -and $lines[$lines.Count - 2] -eq "C3_RESOURCE_VERDICT=$verdict; INTEGRATED_ACCEPTANCE=OPEN; TIMED_SOAK=NOT_RUN" -and $lines[$lines.Count - 3] -eq "COLLECTION=COMPLETE rounds=2 warmup=2 measured_lifecycles=200 resource_budget_failures=$failures") 'completion tail'
    return New-Object PSObject -Property @{ Complete = $true; BudgetFailures = $failures; Verdict = $verdict; ExitCode = $expectedExit; Samples = $inventorySummary; ProcessId = $process.pid }
}
