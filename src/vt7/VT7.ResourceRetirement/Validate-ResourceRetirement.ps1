# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Windows PowerShell 2.0 compatible. Dot-source only; no automatic work or output.
# These checks establish collection completeness, never complete causal attribution.

function Get-VT7RetirementMatch {
    param([string]$Text, [string]$Pattern)
    $found = [regex]::Matches($Text, $Pattern)
    if ($found.Count -ne 1) { throw "Missing, malformed or duplicated trace record: $Pattern" }
    return $found[0]
}

function Assert-VT7RetirementNoErrors {
    param([string]$Text)
    $failures = @(
        '(?m)^(?:FAIL |INCOMPLETE:|VT7_TRACE_TRUNCATED_SETUP|VT7_TRACE_ABORT_|VT7_WARP_ABORT_|VT7_WARP_TRUNCATED)[^\r\n]*$',
        '(?im)^(?:\([0-9a-f]+\.[0-9a-f]+\):|Last event:).+\((?:!!!\s*)?second chance(?:\s*!!!)?\).*$',
        '(?im)^.*\bSyntax error\b.*$',
        '(?im)^\s*(?:\*+\s*)?(?:Could not|Unable to|Couldn''t) (?:find handle|resolve|set breakpoint|insert breakpoint|read memory|load extension).*$',
        '(?im)^.*(?:unresolved breakpoint|breakpoint.*could not be resolved|breakpoint.*failed).*$' ,
        '(?im)^\s*(?:Memory access error|Bad register error|No runnable debuggees|No export .+ found|Extension DLL.+not found).*$',
        '(?im)^.*(?:The difference between the two snapshots is too large|Please start over with "!htrace|Handle tracing is not enabled|Handle tracing information is not available|Failed to (?:enable handle tracing|take.*snapshot)).*$',
        '(?im)^.*(?:trace (?:buffer|history).*(?:overflow|wrapped|lost)|Unable to load.*(?:exts\.dll|dbgeng\.dll|dbghelp\.dll)).*$'
    )
    foreach ($pattern in $failures) {
        if ([regex]::IsMatch($Text, $pattern)) { throw "Trace collection reported an error: $([regex]::Match($Text, $pattern).Value.Trim())" }
    }
    # Missing operating-system PDBs and checksum warnings are not collection errors.
    # Required application private symbols are checked separately in preflight.
}

function Assert-VT7RetirementHandleInventory {
    param([string]$Text, [bool]$Detailed)
    $Text = $Text.Replace("`r", '')
    $total = Get-VT7RetirementMatch $Text '(?m)^(?<count>[1-9][0-9]*) Handles\s*$'
    $table = Get-VT7RetirementMatch $Text '(?m)^Type\s+Count\s*\n(?<rows>(?:[^\n]+[\t ]+[0-9]+[\t ]*\n?)+)'
    $types = @{}
    $sum = 0
    foreach ($row in [regex]::Matches($table.Groups['rows'].Value, '(?m)^(?<type>.+?)[\t ]+(?<count>[0-9]+)[\t ]*$')) {
        $type = $row.Groups['type'].Value
        if ($types.ContainsKey($type)) { throw 'Duplicate type in debugger handle inventory.' }
        $types[$type] = [int]$row.Groups['count'].Value
        $sum += $types[$type]
    }
    if ($sum -ne [int]$total.Groups['count'].Value) { throw 'Debugger handle type totals do not match its inventory total.' }
    if ($Detailed) {
        $handles = [regex]::Matches($Text, '(?im)^Handle (?<handle>[0-9a-f`]+)[\t ]*$')
        if ($handles.Count -ne $sum) { throw 'Debugger handle inventory is incomplete.' }
        $seen = @{}
        $observedTypes = @{}
        for ($index = 0; $index -lt $handles.Count; ++$index) {
            $handle = $handles[$index]
            $key = $handle.Groups['handle'].Value.Replace('`', '').ToLowerInvariant()
            if ($seen.ContainsKey($key)) { throw 'Duplicate handle in debugger inventory.' }
            $seen[$key] = $true
            $end = $total.Index
            if ($index + 1 -lt $handles.Count) { $end = $handles[$index + 1].Index }
            if ($end -le $handle.Index -or $end -gt $total.Index) { throw 'Handle inventory record is outside the detailed listing.' }
            $body = $Text.Substring($handle.Index + $handle.Length, $end - $handle.Index - $handle.Length)
            # !handle object fields have two spaces of indentation. Object-specific
            # token metadata has four, including a separate "Type Primary" field.
            $objectType = Get-VT7RetirementMatch $body '(?m)^  Type[\t ]+(?<type>[^\n]*\S)[\t ]*$'
            $specific = [regex]::Match($body, '(?m)^  (?:No )?Object Specific Information(?: .*)?$')
            if ($specific.Success -and $objectType.Index -ge $specific.Index) { throw 'Handle object type appeared inside object-specific metadata.' }
            $type = $objectType.Groups['type'].Value.Trim()
            $summaryType = $type
            if (-not $types.ContainsKey($summaryType)) {
                # Retained SDK 8.1 traces on Windows 10 list IRTimer in detail
                # but count it under None. Do not generalize to unknown types.
                if ($type -eq 'IRTimer' -and $types.ContainsKey('None')) { $summaryType = 'None' }
                else { throw "Handle object type is absent from the inventory summary: $type" }
            }
            if (-not $observedTypes.ContainsKey($summaryType)) { $observedTypes[$summaryType] = 0 }
            ++$observedTypes[$summaryType]
        }
        foreach ($type in $types.Keys) {
            $actual = 0
            if ($observedTypes.ContainsKey($type)) { $actual = $observedTypes[$type] }
            if ($actual -ne $types[$type]) { throw "Handle object type count disagrees with the inventory summary: $type" }
        }
    }
}

function Assert-VT7RetirementHtraceDiff {
    param([string]$Text)
    [void](Get-VT7RetirementMatch $Text '(?m)^Handle tracing information snapshot successfully taken\.$')
    $newTraces = Get-VT7RetirementMatch $Text '(?m)^0x(?<count>[0-9a-fA-F]+) new stack traces since the previous snapshot\.$'
    if ([Convert]::ToUInt32($newTraces.Groups['count'].Value, 16) -gt 0) {
        [void](Get-VT7RetirementMatch $Text '(?m)^Ignoring handles that were already closed\.\.\.$')
    }
    $empty = [regex]::Matches($Text, '(?m)^No outstanding handles opened since the previous snapshot were detected\.$')
    $displayed = [regex]::Matches($Text, '(?m)^Displayed 0x(?<count>[0-9a-fA-F]+) stack traces for outstanding handles opened since the previous snapshot\.$')
    if ($empty.Count + $displayed.Count -ne 1) { throw 'Missing or duplicated successful handle-trace diff result.' }
    $entries = [regex]::Matches($Text, '(?m)^Handle = 0x[0-9a-fA-F]+ - (?:OPEN|CLOSE|BADREF)\s*$')
    if ($empty.Count -eq 1 -and $entries.Count -ne 0) { throw 'Empty handle diff contains outstanding handle histories.' }
    if ($displayed.Count -eq 1) {
        $count = [Convert]::ToUInt32($displayed[0].Groups['count'].Value, 16)
        if ($count -eq 0 -or $entries.Count -ne $count) { throw 'Displayed handle histories are incomplete.' }
        [void](Get-VT7RetirementMatch $Text '(?m)^Outstanding handles opened since the previous snapshot:$')
        $owners = [regex]::Matches($Text, '(?m)^Thread ID = 0x[0-9a-fA-F]+, Process ID = 0x[0-9a-fA-F]+$')
        if ($owners.Count -ne $entries.Count) { throw 'Handle history is missing its thread/process record.' }
        $histories = [regex]::Matches($Text, '(?ms)^Handle = 0x[0-9a-fA-F]+ - (?:OPEN|CLOSE|BADREF)\s*\n(?<body>.*?)(?=^Handle = |^Displayed )')
        if ($histories.Count -ne $entries.Count) { throw 'Handle history boundaries are incomplete.' }
        foreach ($history in $histories) {
            $owner = Get-VT7RetirementMatch $history.Groups['body'].Value '(?m)^Thread ID = 0x[0-9a-fA-F]+, Process ID = 0x(?<pid>[0-9a-fA-F]+)$'
            # Recorded PID 4 kernel-origin entries can have no user stack. Preserve
            # them as collected histories with unavailable causal attribution.
            if (-not [regex]::IsMatch($history.Groups['body'].Value, '(?m)^0x[0-9a-fA-F]+: .+$') -and
                [Convert]::ToUInt32($owner.Groups['pid'].Value, 16) -ne 4) { throw 'An outstanding user-process handle history is missing its stack frames.' }
        }
    }
}

function Assert-VT7RetirementHtraceHistory {
    param([string]$Text)
    $parsed = Get-VT7RetirementMatch $Text '(?m)^Parsed 0x(?<count>[0-9a-fA-F]+) stack traces\.$'
    $dumped = Get-VT7RetirementMatch $Text '(?m)^Dumped 0x(?<count>[0-9a-fA-F]+) stack traces\.$'
    $count = [Convert]::ToUInt32($parsed.Groups['count'].Value, 16)
    if ($count -ge 65536 -or $count -ne [Convert]::ToUInt32($dumped.Groups['count'].Value, 16) -or $parsed.Index -ge $dumped.Index) { throw 'Full handle history is truncated, at capacity or has inconsistent footer counts.' }
    $entries = [regex]::Matches($Text, '(?m)^Handle = 0x[0-9a-fA-F]+ - (?:OPEN|CLOSE|BADREF)\s*$')
    $owners = [regex]::Matches($Text, '(?m)^Thread ID = 0x[0-9a-fA-F]+, Process ID = 0x[0-9a-fA-F]+$')
    if ($entries.Count -ne $count -or $owners.Count -ne $count -or [regex]::Matches($Text, '(?m)^Handle = ').Count -ne $count) { throw 'Full handle history entries or ownership records are incomplete.' }
    for ($index = 0; $index -lt $entries.Count; ++$index) {
        $entry = $entries[$index]
        $end = $parsed.Index
        if ($index + 1 -lt $entries.Count) { $end = $entries[$index + 1].Index }
        if ($entry.Index -ge $end -or $end -gt $parsed.Index) { throw 'Full handle history entry is outside its parsed listing.' }
        $body = $Text.Substring($entry.Index + $entry.Length, $end - $entry.Index - $entry.Length)
        $owner = Get-VT7RetirementMatch $body '(?m)^Thread ID = 0x[0-9a-fA-F]+, Process ID = 0x(?<pid>[0-9a-fA-F]+)$'
        if (-not [regex]::IsMatch($body, '(?m)^0x[0-9a-fA-F]+: .+$') -and [Convert]::ToUInt32($owner.Groups['pid'].Value, 16) -ne 4) { throw 'Full user-process handle history lacks its stack frames.' }
    }
}

function Assert-VT7RetirementPreflight {
    param([string]$Text)
    $text = $Text.Replace("`r", '')
    Assert-VT7RetirementNoErrors $text
    $begin = Get-VT7RetirementMatch $text '(?m)^VT7_TRACE_PREFLIGHT_BEGIN$'
    $end = Get-VT7RetirementMatch $text '(?m)^VT7_TRACE_PREFLIGHT_END$'
    if ($end.Index -le $begin.Index) { throw 'Preflight marker order is invalid.' }
    $body = $text.Substring($begin.Index, $end.Index - $begin.Index)
    [void](Get-VT7RetirementMatch $body '(?m)^VT7_TRACE_HTRACE_ENABLE_BEGIN$')
    [void](Get-VT7RetirementMatch $body '(?m)^Handle tracing enabled\.$')
    [void](Get-VT7RetirementMatch $body '(?m)^Handle tracing disabled\.$')
    if ([regex]::Matches($body, '(?m)^Handle tracing information snapshot successfully taken\.$').Count -ne 3) { throw 'Preflight did not enable, snapshot and diff handle tracing successfully.' }
    [void](Get-VT7RetirementMatch $body '(?m)^0x[0-9a-fA-F]+ new stack traces since the previous snapshot\.$')
    if ([regex]::Matches($body, '(?m)^(?:No outstanding handles opened since the previous snapshot were detected\.|Displayed 0x[0-9a-fA-F]+ stack traces for outstanding handles opened since the previous snapshot\.)$').Count -ne 1) { throw 'Preflight handle diff did not complete.' }
    Assert-VT7RetirementHandleInventory $body $false
    $moduleRows = [regex]::Matches($body, '(?im)^(?<base>[0-9a-f`]+)\s+(?<end>[0-9a-f`]+)\s+VT7_ResourceRetirement\s+(?:[A-Z]\s+)?\(private pdb symbols\).*$')
    if ($moduleRows.Count -lt 1) { throw 'Preflight did not establish application private PDB symbols.' }
    $moduleBase = [Convert]::ToUInt64($moduleRows[0].Groups['base'].Value.Replace('`', ''), 16)
    $moduleEnd = [Convert]::ToUInt64($moduleRows[0].Groups['end'].Value.Replace('`', ''), 16)
    $sample = Get-VT7RetirementMatch $body '(?m)^VT7_TRACE_SAMPLE_ADDRESS=(?<address>[0-9a-fA-F`]+)$'
    $hook = Get-VT7RetirementMatch $body '(?m)^VT7_TRACE_HOOK_ADDRESS=(?<address>[0-9a-fA-F`]+)$'
    $sampleAddress = [Convert]::ToUInt64($sample.Groups['address'].Value.Replace('`', ''), 16)
    $hookAddress = [Convert]::ToUInt64($hook.Groups['address'].Value.Replace('`', ''), 16)
    if ($sampleAddress -le $moduleBase -or $sampleAddress -ge $moduleEnd -or $hookAddress -eq 0) { throw 'Preflight checkpoint or hook address is invalid.' }
    $sampleSymbol = [regex]::Matches($body, '(?im)^(?<address>[0-9a-f`]+)\s+VT7_ResourceRetirement!VT7RetirementSample(?:\s+.*)?$')
    if ($sampleSymbol.Count -ne 1 -or [Convert]::ToUInt64($sampleSymbol[0].Groups['address'].Value.Replace('`', ''), 16) -ne $sampleAddress) { throw 'The exported sample symbol does not match the checkpoint address.' }
    $hookSymbol = Get-VT7RetirementMatch $body '(?im)^(?<address>[0-9a-f`]+)\s+USER32!ClientThreadSetup(?:\s+.*)?$'
    if ([Convert]::ToUInt64($hookSymbol.Groups['address'].Value.Replace('`', ''), 16) -ne $hookAddress) { throw 'The USER32 hook symbol does not match its reported address.' }
    [void](Get-VT7RetirementMatch $body '(?im)^USER32!ClientThreadSetup:$')
}

function Assert-VT7RetirementThreadSamples {
    param([string]$Text)
    $phases = @('pre-warmup', 'warmup-live', 'baseline-live', 'measured-live', 'final-closed', 'final-closed-10s', 'final-closed-90s', 'final-closed-180s')
    $iterations = @(0, 0, 0, 25, 25, 25, 25, 25)
    $lives = @(0, 1, 1, 1, 0, 0, 0, 0)
    $resources = [regex]::Matches($Text, '(?m)^RESOURCE sample=(?<sample>[0-9]+) phase=(?<phase>\S+) iteration=(?<iteration>[0-9]+) live=(?<live>[01]) private=[0-9]+ handles=[0-9]+ GDI=[0-9]+ USER=[0-9]+ threads=(?<threads>[0-9]+) begin_ms=(?<begin>[0-9]+) end_ms=(?<end>[0-9]+)$')
    $rows = [regex]::Matches($Text, '(?m)^THREAD sample=(?<sample>[0-9]+) tid=(?<tid>[0-9]+) creation=(?<creation>[0-9A-F]{16}) identity_error=(?<error>[0-9]+) observation=(?<observation>\S+) first_sample=(?<first>[0-9]+) queue=(?<queue>observed|unavailable) queue_error=(?<qerror>[0-9]+) first_queue_sample=(?<qfirst>[0-9]+) alive_before=(?<before>[0-9]+) alive_after=(?<after>[0-9]+) origin=.+ offset=[0-9A-F]+ start=[0-9A-F]+ origin_status=[0-9A-F]{8} module_error=[0-9]+$')
    $absences = [regex]::Matches($Text, '(?m)^NOT_OBSERVED sample=(?<sample>[0-9]+) tid=(?<tid>[0-9]+) creation=(?<creation>[0-9A-F]{16}) previous_sample=(?<previous>[0-9]+); absence_from_snapshot_not_complete_exit_history$')
    if ($resources.Count -ne 8 -or [regex]::Matches($Text, '(?m)^RESOURCE ').Count -ne 8 -or
        $rows.Count -ne [regex]::Matches($Text, '(?m)^THREAD ').Count -or $absences.Count -ne [regex]::Matches($Text, '(?m)^NOT_OBSERVED ').Count) { throw 'Malformed or incomplete resource/thread sample records.' }
    $history = @{}
    $tids = @{}
    $unavailable = 0
    $counted = 0
    $absentCount = 0
    [uint64]$lastEnd = 0
    for ($index = 0; $index -lt 8; ++$index) {
        $sample = $index + 1
        $resource = $resources[$index]
        if ([int]$resource.Groups['sample'].Value -ne $sample -or $resource.Groups['phase'].Value -ne $phases[$index] -or
            [int]$resource.Groups['iteration'].Value -ne $iterations[$index] -or [int]$resource.Groups['live'].Value -ne $lives[$index]) { throw "Resource checkpoint $sample is mismatched." }
        [uint64]$begin = $resource.Groups['begin'].Value
        [uint64]$end = $resource.Groups['end'].Value
        if ($begin -lt $lastEnd -or $end -lt $begin) { throw 'Resource sample timestamps are inconsistent.' }
        if ($sample -ge 6) {
            $minimum = @(10000, 80000, 90000)[$sample - 6]
            if ($begin - $lastEnd -lt $minimum) { throw 'Closed resource sample lacks its prescribed idle segment.' }
        }
        $lastEnd = $end
        $current = @($rows | Where-Object { [int]$_.Groups['sample'].Value -eq $sample })
        if ($current.Count -eq 0 -or $current.Count -ne [int]$resource.Groups['threads'].Value) { throw "Thread row count is incomplete at sample $sample." }
        $counted += $current.Count
        $seen = @{}
        foreach ($row in $current) {
            $nextResourceIndex = $Text.Length
            if ($index + 1 -lt $resources.Count) { $nextResourceIndex = $resources[$index + 1].Index }
            if ($row.Index -le $resource.Index -or $row.Index -ge $nextResourceIndex) { throw 'Thread row is outside its resource sample.' }
            $tid = $row.Groups['tid'].Value
            $creation = $row.Groups['creation'].Value
            $key = $tid + ':' + $creation
            $first = [int]$row.Groups['first'].Value
            $qfirst = [int]$row.Groups['qfirst'].Value
            $queue = $row.Groups['queue'].Value -eq 'observed'
            if ($seen.ContainsKey($tid) -or $tid -eq '0') { throw 'Duplicate or invalid thread identity within a sample.' }
            $seen[$tid] = $true
            if ($queue -and ([uint32]$row.Groups['qerror'].Value -ne 0 -or [uint32]$row.Groups['before'].Value -ne 258 -or [uint32]$row.Groups['after'].Value -ne 258)) { throw 'Observed queue lacks successful liveness-bracketed metadata.' }
            if ($creation -eq '0000000000000000') {
                ++$unavailable
                if ($first -ne 0 -or $qfirst -ne 0 -or $queue -or $row.Groups['observation'].Value -ne 'identity-unavailable' -or [uint32]$row.Groups['error'].Value -eq 0) { throw 'Unknown thread identity was presented as known.' }
                continue
            }
            if ([uint32]$row.Groups['error'].Value -ne 0) { throw 'Known thread identity carries an error.' }
            if ($history.ContainsKey($key)) {
                $entry = $history[$key]
                $expected = 'seen-earlier'
                if ($entry.Last -eq $sample - 1) { $expected = 'surviving' }
                if ($first -ne $entry.First -or $row.Groups['observation'].Value -ne $expected) { throw 'Thread identity continuity is inconsistent.' }
                if ($queue -and $entry.Queue -eq 0) { $entry.Queue = $sample }
                if ($qfirst -ne $entry.Queue) { throw 'First queue observation changed for a known thread identity.' }
                $entry.Last = $sample
            }
            else {
                $expected = 'newly-observed'
                if ($tids.ContainsKey($tid)) { $expected = 'new-identity-reused-tid' }
                $expectedQueue = 0
                if ($queue) { $expectedQueue = $sample }
                if ($first -ne $sample -or $qfirst -ne $expectedQueue -or $row.Groups['observation'].Value -ne $expected) { throw 'New thread identity metadata is inconsistent.' }
                $history[$key] = @{ First = $sample; Last = $sample; Queue = $qfirst }
                $tids[$tid] = $true
            }
        }
        $expectedAbsent = @($history.Keys | Where-Object { $history[$_].Last -eq $sample - 1 })
        $currentAbsent = @($absences | Where-Object { [int]$_.Groups['sample'].Value -eq $sample })
        $absentCount += $currentAbsent.Count
        if ($currentAbsent.Count -ne $expectedAbsent.Count) { throw 'Missing or excessive thread absence records.' }
        $seenAbsent = @{}
        foreach ($row in $currentAbsent) {
            $key = $row.Groups['tid'].Value + ':' + $row.Groups['creation'].Value
            if ($seenAbsent.ContainsKey($key) -or $expectedAbsent -notcontains $key -or [int]$row.Groups['previous'].Value -ne $sample - 1) { throw 'Inconsistent thread absence record.' }
            $seenAbsent[$key] = $true
        }
    }
    if ($counted -ne $rows.Count -or $absentCount -ne $absences.Count) { throw 'Thread record references an unknown checkpoint.' }
    [void](Get-VT7RetirementMatch $Text ('(?m)^ATTRIBUTION samples=8 identities=' + $history.Count + ' identity_unavailable=' + $unavailable + '; queue_unavailable_is_not_queue_absent$'))
}

function Assert-VT7RetirementIdleWaits {
    param([string]$Text)
    [void](Get-VT7RetirementMatch $Text '(?m)^RETIREMENT post_close_targets_ms=10000,90000,180000 wait_segments_ms=10000,80000,90000; wait_timing=wall_clock; debugger_pauses_count_toward_wait=1$')
    $policy = Get-VT7RetirementMatch $Text '(?m)^VT7_IDLE_TRACE_POLICY active=checkpoint_exit_only$'
    $closed = Get-VT7RetirementMatch $Text '(?m)^VT7_CHECKPOINT sample=5 .+$'
    $closedResource = Get-VT7RetirementMatch $Text '(?m)^RESOURCE sample=5 .+$'
    if ($policy.Index -le $closed.Index -or $policy.Index -ge $closedResource.Index) { throw 'Idle breakpoint policy was not established at the closed checkpoint.' }
    $afterPolicy = $Text.Substring($policy.Index + $policy.Length)
    if ([regex]::IsMatch($afterPolicy, '(?m)^(?:VT7_SETUP |VT7_INVALID_HANDLE |VT7_WARP_(?:EVENT |PROFILE |FREE_RETURN |INIT_RESULT ))')) { throw 'An event breakpoint or exception interrupted the idle observation policy.' }
    $starts = [regex]::Matches($Text, '(?m)^IDLE_WAIT target_ms=(?<target>[0-9]+) requested_ms=(?<requested>[0-9]+) begin_ms=(?<begin>[0-9]+)$')
    $ends = [regex]::Matches($Text, '(?m)^IDLE_WAIT_END target_ms=(?<target>[0-9]+) requested_ms=(?<requested>[0-9]+) begin_ms=(?<begin>[0-9]+) end_ms=(?<end>[0-9]+) elapsed_ms=(?<elapsed>[0-9]+)$')
    if ($starts.Count -ne 3 -or $ends.Count -ne 3 -or [regex]::Matches($Text, '(?m)^IDLE_WAIT(?: |_)').Count -ne 6) { throw 'Idle wait records are missing, malformed or duplicated.' }
    $targets = @(10000, 90000, 180000)
    $segments = @(10000, 80000, 90000)
    for ($index = 0; $index -lt 3; ++$index) {
        $start = $starts[$index]
        $end = $ends[$index]
        $previousSample = $index + 5
        $nextSample = $index + 6
        $previous = Get-VT7RetirementMatch $Text ('(?m)^RESOURCE sample=' + $previousSample + ' .+ end_ms=(?<end>[0-9]+)$')
        $next = Get-VT7RetirementMatch $Text ('(?m)^RESOURCE sample=' + $nextSample + ' .+ begin_ms=(?<begin>[0-9]+) end_ms=[0-9]+$')
        $checkpoint = Get-VT7RetirementMatch $Text ('(?m)^VT7_CHECKPOINT sample=' + $nextSample + ' .+$')
        if ($start.Index -le $previous.Index -or $end.Index -le $start.Index -or $checkpoint.Index -le $end.Index -or $next.Index -le $checkpoint.Index) { throw 'Idle wait markers are outside their planned checkpoint interval.' }
        foreach ($field in @('target', 'requested', 'begin')) {
            if ($start.Groups[$field].Value -ne $end.Groups[$field].Value) { throw 'Idle wait begin/end values disagree.' }
        }
        [uint64]$started = $start.Groups['begin'].Value
        [uint64]$ended = $end.Groups['end'].Value
        [uint64]$elapsed = $end.Groups['elapsed'].Value
        if ([uint64]$start.Groups['target'].Value -ne $targets[$index] -or [uint64]$start.Groups['requested'].Value -ne $segments[$index] -or
            $ended -lt $started -or $elapsed -lt $segments[$index] -or $elapsed -ne $ended - $started -or
            $started -lt [uint64]$previous.Groups['end'].Value -or $ended -gt [uint64]$next.Groups['begin'].Value) { throw 'Idle wait timing does not establish the prescribed wall-clock interval.' }
        $inside = $Text.Substring($start.Index + $start.Length, $end.Index - $start.Index - $start.Length)
        if ([regex]::IsMatch($inside, '(?m)^(?:VT7_|RESOURCE |THREAD |NOT_OBSERVED |WORKLOAD |IDLE_WAIT)')) { throw 'Diagnostic activity interrupted a planned idle wait.' }
    }
}

function Get-VT7RetirementPointer {
    param([string]$Value)
    return [Convert]::ToUInt64($Value.Replace('`', ''), 16)
}

function Get-VT7RetirementTargetStatus {
    param([string]$Text)
    $profiles = [regex]::Matches($Text.Replace("`r", ''), '(?m)^VT7_WARP_PROFILE status=(?<status>MATCHED|UNSUPPORTED) profile=(?<profile>win7-6\.2\.9200\.22592|none) base=(?<base>[0-9a-fA-F`]+)$')
    if ($profiles.Count -eq 0 -or $profiles.Count -ne [regex]::Matches($Text, '(?m)^VT7_WARP_PROFILE ').Count) { throw 'WARP profile qualification is absent, malformed or duplicated.' }
    $status = $profiles[0].Groups['status'].Value
    foreach ($profile in $profiles) {
        if ($profile.Groups['status'].Value -ne $status -or (Get-VT7RetirementPointer $profile.Groups['base'].Value) -eq 0 -or
            ($status -eq 'MATCHED' -and $profile.Groups['profile'].Value -ne 'win7-6.2.9200.22592') -or
            ($status -eq 'UNSUPPORTED' -and $profile.Groups['profile'].Value -ne 'none')) { throw 'WARP profile qualification is inconsistent.' }
    }
    if ($status -eq 'MATCHED') { return 'SUPPORTED' }
    return 'UNSUPPORTED'
}

function Assert-VT7RetirementOwnership {
    param([string]$Text)
    $status = Get-VT7RetirementTargetStatus $Text
    $armed = Get-VT7RetirementMatch $Text '(?m)^VT7_TRACE_ARMED$'
    $closed = Get-VT7RetirementMatch $Text '(?m)^VT7_CHECKPOINT sample=5 .+$'
    $profiles = [regex]::Matches($Text, '(?m)^VT7_WARP_PROFILE .+$')
    foreach ($profile in $profiles) {
        if ($profile.Index -le $armed.Index -or $profile.Index -ge $closed.Index) { throw 'WARP profile was recorded outside the live trace.' }
    }
    if ($status -eq 'UNSUPPORTED') {
        if ([regex]::IsMatch($Text, '(?m)^VT7_WARP_(?:EVENT|INIT_RESULT|FREE_RETURN|HOOKS_ARMED)(?: |$)')) { throw 'Unsupported WARP profile contains private-offset observations.' }
        return
    }
    [void](Get-VT7RetirementMatch $Text '(?m)^OS 6\.1\.7601 SP=1\.0 bits=64$')
    $hooks = [regex]::Matches($Text, '(?m)^VT7_WARP_HOOKS_ARMED$')
    if ($hooks.Count -ne $profiles.Count) { throw 'Matched WARP profile lacks its armed-hook confirmation.' }
    for ($index = 0; $index -lt $hooks.Count; ++$index) {
        if ($hooks[$index].Index -le $profiles[$index].Index -or $hooks[$index].Index -ge $closed.Index) { throw 'WARP hooks were armed outside their qualified profile interval.' }
    }
    $events = [regex]::Matches($Text, '(?m)^VT7_WARP_EVENT seq=(?<seq>[1-9][0-9]*) kind=(?<kind>INIT_ENTRY|INIT_RETURN|CALLBACK|CLEANUP_ENTRY|DRAIN_RETURN|WORK_CLOSE_RETURN|POOL_CLOSE_RETURN|CLEANUP_RETURN|CLEANUP_FAILURE_RETURN) checkpoint=(?<checkpoint>[0-4]) tid=(?<tid>[1-9][0-9]*) wrapper=(?<wrapper>[0-9a-fA-F`]+) device=(?<device>[0-9a-fA-F`]+) mode=(?<mode>[23]) work=(?<work>[0-9a-fA-F`]+) pool=(?<pool>[0-9a-fA-F`]+)$')
    $free = [regex]::Matches($Text, '(?m)^VT7_WARP_FREE_RETURN checkpoint=(?<checkpoint>[0-4]) tid=(?<tid>[1-9][0-9]*) device=(?<device>[0-9a-fA-F`]+) wrapper=(?<wrapper>[0-9a-fA-F`]+) success=(?<success>[0-9]+)$')
    $results = [regex]::Matches($Text, '(?m)^VT7_WARP_INIT_RESULT success=(?<success>[01]) wrapper=(?<wrapper>[0-9a-fA-F`]+)$')
    if ($events.Count -eq 0 -or $events.Count -ge 128 -or $events.Count -ne [regex]::Matches($Text, '(?m)^VT7_WARP_EVENT ').Count -or
        $free.Count -eq 0 -or $free.Count -ne [regex]::Matches($Text, '(?m)^VT7_WARP_FREE_RETURN ').Count -or
        $results.Count -eq 0 -or $results.Count -ne [regex]::Matches($Text, '(?m)^VT7_WARP_INIT_RESULT ').Count) { throw 'WARP lifetime records are absent, malformed or truncated.' }
    $sequence = 0
    $callbacks = 0
    $initializations = 0
    $freed = 0
    $states = @{}
    $records = @($events) + @($free)
    foreach ($record in @($records | Sort-Object -Property Index)) {
        $wrapper = Get-VT7RetirementPointer $record.Groups['wrapper'].Value
        $device = Get-VT7RetirementPointer $record.Groups['device'].Value
        if ($wrapper -eq 0 -or $device -eq 0 -or $record.Index -le $hooks[0].Index -or $record.Index -ge $closed.Index -or
            [int]$record.Groups['checkpoint'].Value -ne [regex]::Matches($Text.Substring(0, $record.Index), '(?m)^VT7_CHECKPOINT ').Count) { throw 'WARP lifetime record has an invalid pointer, checkpoint or collection position.' }
        $key = $wrapper.ToString('X16')
        if ($record.Groups['success'].Success) {
            if (-not $states.ContainsKey($key) -or $states[$key].Stage -ne 'cleaned' -or $states[$key].Device -ne $device -or
                [uint32]$record.Groups['success'].Value -eq 0) { throw 'Wrapper free lacks a successful, matching completed cleanup.' }
            $states[$key].Stage = 'freed'
            ++$freed
            continue
        }
        ++$sequence
        if ([int]$record.Groups['seq'].Value -ne $sequence) { throw 'WARP event sequence is inconsistent.' }
        $kind = $record.Groups['kind'].Value
        $work = Get-VT7RetirementPointer $record.Groups['work'].Value
        $pool = Get-VT7RetirementPointer $record.Groups['pool'].Value
        $mode = [int]$record.Groups['mode'].Value
        if ($kind -eq 'INIT_ENTRY') {
            if (($states.ContainsKey($key) -and $states[$key].Stage -ne 'freed') -or $work -ne 0 -or $pool -ne 0) { throw 'WARP initialization reused an active wrapper or nonempty work/pool slots.' }
            $states[$key] = @{ Device = $device; Mode = $mode; Work = [uint64]0; Pool = [uint64]0; Stage = 'entered'; Entry = $record.Index }
            ++$initializations
            continue
        }
        if (-not $states.ContainsKey($key)) { throw 'WARP event has no matching initialized wrapper.' }
        $state = $states[$key]
        if ($state.Device -ne $device -or $state.Mode -ne $mode) { throw 'WARP wrapper device or mode changed during its lifetime.' }
        if ($kind -eq 'INIT_RETURN') {
            if ($state.Stage -ne 'entered' -or $work -eq 0 -or ($mode -eq 3 -and $pool -ne 0) -or ($mode -eq 2 -and $pool -eq 0)) { throw 'WARP initialization result disagrees with the observed pool mode.' }
            $prefix = $Text.Substring($state.Entry, $record.Index - $state.Entry)
            $result = Get-VT7RetirementMatch $prefix '(?m)^VT7_WARP_INIT_RESULT success=1 wrapper=(?<wrapper>[0-9a-fA-F`]+)$'
            if ((Get-VT7RetirementPointer $result.Groups['wrapper'].Value) -ne $wrapper -or
                -not [regex]::IsMatch($prefix, '(?m)^VT7_WARP_INIT_RESULT success=1 wrapper=[0-9a-fA-F`]+\n\z')) { throw 'WARP initialization return lacks its immediately preceding successful result.' }
            $state.Work = $work
            $state.Pool = $pool
            $state.Stage = 'initialized'
            continue
        }
        if ($kind -eq 'CALLBACK') {
            if ($state.Stage -ne 'initialized' -or $work -ne $state.Work -or $pool -ne $state.Pool) { throw 'WARP callback does not match a live initialized work object.' }
            ++$callbacks
            continue
        }
        if ($kind -eq 'CLEANUP_ENTRY') {
            if ($state.Stage -ne 'initialized' -or $work -ne $state.Work -or $pool -ne $state.Pool) { throw 'WARP cleanup does not match the initialized work and pool.' }
            $state.Stage = 'cleanup'
            continue
        }
        if ($kind -eq 'DRAIN_RETURN') {
            if ($state.Stage -ne 'cleanup' -or $work -ne $state.Work -or $pool -ne $state.Pool) { throw 'Callback drain is missing or disagrees with cleanup ownership.' }
            $state.Stage = 'drained'
            continue
        }
        if ($kind -eq 'WORK_CLOSE_RETURN') {
            if ($state.Stage -ne 'drained' -or $work -ne $state.Work -or $pool -ne $state.Pool) { throw 'Work close did not follow a matching callback drain.' }
            $state.Stage = 'work-closed'
            continue
        }
        if ($kind -eq 'POOL_CLOSE_RETURN') {
            if ($state.Stage -ne 'work-closed' -or $state.Pool -eq 0 -or $pool -ne $state.Pool -or $work -ne 0) { throw 'Private pool close is missing its matching work close or pool ownership.' }
            $state.Stage = 'pool-closed'
            continue
        }
        if ($kind -eq 'CLEANUP_RETURN') {
            $expected = 'work-closed'
            if ($state.Pool -ne 0) { $expected = 'pool-closed' }
            if ($state.Stage -ne $expected -or $work -ne 0 -or $pool -ne 0) { throw 'Cleanup return lacks closed and cleared work/pool ownership.' }
            $state.Stage = 'cleaned'
            continue
        }
        throw 'WARP initialization or cleanup entered a failure path.'
    }
    if ($callbacks -eq 0 -or $freed -ne $initializations -or $results.Count -ne $initializations) { throw 'WARP lifetime coverage lacks callbacks, successful initialization results or wrapper frees.' }
    foreach ($state in $states.Values) {
        if ($state.Stage -ne 'freed') { throw 'WARP wrapper lifetime did not reach its successful free return.' }
    }
}

function Assert-VT7RetirementInvalidHandleEpisodes {
    param([string]$Text, [int]$ArmedIndex, [int]$ExitIndex, [string]$ProcessId, [int]$ExpectedCount)
    if ($ExpectedCount -lt 0 -or $ExpectedCount -ge 16) { throw 'Invalid-handle exception collection reached or exceeded its bound.' }
    $episodes = [regex]::Matches($Text, '(?ms)^VT7_INVALID_HANDLE event=(?<event>[1-9][0-9]*) checkpoint=(?<sample>[0-8]) pid=(?<pid>[1-9][0-9]*) tid=(?<tid>[1-9][0-9]*)\n(?<body>.*?)^VT7_INVALID_HANDLE_END\nVT7_INVALID_HANDLE_DISPATCH$')
    if ($episodes.Count -ne $ExpectedCount -or $episodes.Count -ne [regex]::Matches($Text, '(?m)^VT7_INVALID_HANDLE ').Count -or
        $episodes.Count -ne [regex]::Matches($Text, '(?m)^VT7_INVALID_HANDLE_END$').Count -or $episodes.Count -ne [regex]::Matches($Text, '(?m)^VT7_INVALID_HANDLE_DISPATCH$').Count) { throw 'Invalid-handle exception context or dispatch record is missing or duplicated.' }
    for ($index = 0; $index -lt $episodes.Count; ++$index) {
        $episode = $episodes[$index]
        if ([int]$episode.Groups['event'].Value -ne $index + 1 -or $episode.Groups['pid'].Value -ne $ProcessId -or
            $episode.Index -le $ArmedIndex -or $episode.Index + $episode.Length -ge $ExitIndex -or
            [int]$episode.Groups['sample'].Value -ne [regex]::Matches($Text.Substring(0, $episode.Index), '(?m)^VT7_CHECKPOINT ').Count) { throw 'Invalid-handle exception event order, process or checkpoint is inconsistent.' }
        $body = $episode.Groups['body'].Value
        $last = Get-VT7RetirementMatch $body '(?im)^Last event:\s*(?<pid>[0-9a-f]+)\.(?<tid>[0-9a-f]+):.*\bcode c0000008 \(first chance\)\s*$'
        if ([Convert]::ToUInt32($last.Groups['pid'].Value, 16) -ne [uint32]$ProcessId -or
            [Convert]::ToUInt32($last.Groups['tid'].Value, 16) -ne [uint32]$episode.Groups['tid'].Value) { throw 'Invalid-handle exception debugger event identity does not match its marker.' }
        [void](Get-VT7RetirementMatch $body '(?im)^\s*ExceptionCode:\s*c0000008(?:\s+.*)?$')
        [void](Get-VT7RetirementMatch $body '(?im)^\s*ExceptionAddress:\s*[0-9a-f`]+(?:\s+.*)?$')
        [void](Get-VT7RetirementMatch $body '(?im)^\s*ExceptionFlags:\s*[0-9a-f]{8}\s*$')
        [void](Get-VT7RetirementMatch $body '(?im)^\s*NumberParameters:\s*[0-9]+\s*$')
        [void](Get-VT7RetirementMatch $body '(?im)^rip=[0-9a-f`]+\s+rsp=[0-9a-f`]+\s+rbp=[0-9a-f`]+\s*$')
        [void](Get-VT7RetirementMatch $body '(?im)^Child-SP\s+RetAddr\s+Call Site\s*$')
        if (-not [regex]::IsMatch($body, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+\S+!\S+')) { throw 'Invalid-handle exception lacks stack context.' }
        foreach ($module in @('VT7_ResourceRetirement', 'ntdll')) {
            if (-not [regex]::IsMatch($body, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+' + $module + '\s+(?:[A-Z]\s+)?\(')) { throw "Invalid-handle exception module context lacks $module." }
        }
    }
    $reported = [regex]::Matches($Text, '(?im)^\([0-9a-f]+\.[0-9a-f]+\): Invalid handle - code c0000008 \(first chance\)\s*$')
    if ($reported.Count -gt $episodes.Count) { throw 'A first-chance invalid handle has no corresponding complete dispatch record.' }
}

function Assert-VT7RetirementStartup {
    param([string]$Text)
    $text = $Text.Replace("`r", '')
    Assert-VT7RetirementNoErrors $text
    $begin = Get-VT7RetirementMatch $text '(?m)^VT7_STARTUP_BEGIN version=0\.1$'
    $policyBegin = Get-VT7RetirementMatch $text '(?m)^VT7_EXCEPTION_POLICY_BEGIN$'
    $policyEnd = Get-VT7RetirementMatch $text '(?m)^VT7_EXCEPTION_POLICY_END$'
    $ready = Get-VT7RetirementMatch $text '(?m)^VT7_STARTUP_READY phase=pre-warmup iteration=0 live=0 invalid_handles=(?<invalid>[0-9]+)$'
    $end = Get-VT7RetirementMatch $text '(?m)^VT7_STARTUP_END$'
    $banner = Get-VT7RetirementMatch $text '(?m)^VT7 RESOURCE RETIREMENT 0\.1; compiled .+; pid=(?<pid>[1-9][0-9]*)$'
    $config = Get-VT7RetirementMatch $text '(?m)^CONFIG mode=reuse renderer=2 capture=1 power=0 probes=0 warmup=2 cycles=25 fail_at_cycle=0$'
    $retirement = Get-VT7RetirementMatch $text '(?m)^RETIREMENT post_close_targets_ms=10000,90000,180000 wait_segments_ms=10000,80000,90000; wait_timing=wall_clock; debugger_pauses_count_toward_wait=1$'
    $native = Get-VT7RetirementMatch $text '(?m)^NATIVE 0\.3\.5 ABI=8 Release x64 .+$'
    $os = Get-VT7RetirementMatch $text '(?m)^OS [0-9]+\.[0-9]+\.[0-9]+ SP=[0-9]+\.[0-9]+ bits=64$'
    $nativeLoad = Get-VT7RetirementMatch $text '(?im)^ModLoad:\s+[0-9a-f`]+\s+[0-9a-f`]+\s+[^\n]*VT7\.Native\.dll\s*$'
    if ($begin.Index -ge $policyBegin.Index -or $policyBegin.Index -ge $policyEnd.Index -or
        $policyEnd.Index -ge $banner.Index -or $banner.Index -ge $config.Index -or
        $config.Index -ge $retirement.Index -or $retirement.Index -ge $nativeLoad.Index -or $nativeLoad.Index -ge $native.Index -or
        $native.Index -ge $os.Index -or $os.Index -ge $ready.Index -or $ready.Index -ge $end.Index) { throw 'Startup control records are out of order.' }
    if ([regex]::Matches($text, '(?m)^VT7_STARTUP_').Count -ne 3 -or
        [regex]::Matches($text, '(?m)^VT7_EXCEPTION_POLICY_').Count -ne 2) { throw 'Startup control markers are malformed or duplicated.' }
    if ([regex]::IsMatch($text, '(?m)^(?:VT7_(?:SETUP|CHECKPOINT|HTRACE|HANDLES|MODULES|TRACE_|WARP_|IDLE_)|RESOURCE |THREAD |NOT_OBSERVED |WORKLOAD |ATTRIBUTION |IDLE_WAIT|COMPLETED:|Handle tracing |0x[0-9a-fA-F]+ new stack traces|Displayed 0x[0-9a-fA-F]+ stack traces|No outstanding handles)')) { throw 'Startup control contains measurement or handle-tracing activity.' }
    if ([regex]::IsMatch($text.Substring($policyEnd.Index), '(?im)^[0-9a-f]+:[0-9a-f]+>[\t ]*$')) { throw 'Startup control escaped to an unexpected interactive stop.' }
    if (-not [regex]::IsMatch($text.Substring($begin.Index, $ready.Index - $begin.Index), '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+VT7_ResourceRetirement\s+(?:[A-Z]\s+)?\(private pdb symbols\)')) { throw 'Startup control lacks application private PDB confirmation.' }
    $modules = $text.Substring($ready.Index, $end.Index - $ready.Index)
    foreach ($module in @('VT7_ResourceRetirement', 'VT7_Native', 'ntdll')) {
        if (-not [regex]::IsMatch($modules, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+' + $module + '\s+(?:[A-Z]\s+)?\(')) { throw "Startup control module inventory lacks $module." }
    }
    Assert-VT7RetirementInvalidHandleEpisodes $text $policyEnd.Index $ready.Index $banner.Groups['pid'].Value ([int]$ready.Groups['invalid'].Value)
}

function Assert-VT7ResourceRetirement {
    param([string]$Text)
    $text = $Text.Replace("`r", '')
    Assert-VT7RetirementNoErrors $text
    $begin = Get-VT7RetirementMatch $text '(?m)^VT7_TRACE_BEGIN version=0\.1 cycles=25 offline_symbols=1$'
    $armed = Get-VT7RetirementMatch $text '(?m)^VT7_TRACE_ARMED$'
    $end = Get-VT7RetirementMatch $text '(?m)^VT7_TRACE_END$'
    $exit = Get-VT7RetirementMatch $text '(?m)^VT7_TRACE_EXIT status=0 checkpoints=8 setup_events=(?<events>[1-9][0-9]*) invalid_handles=(?<invalid>[0-9]+)$'
    $enabled = Get-VT7RetirementMatch $text '(?m)^Handle tracing enabled\.$'
    $disabled = Get-VT7RetirementMatch $text '(?m)^Handle tracing disabled\.$'
    if ($begin.Index -ge $armed.Index -or $armed.Index -ge $enabled.Index -or $enabled.Index -ge $exit.Index -or $exit.Index -ge $disabled.Index -or $disabled.Index -ge $end.Index) { throw 'Trace lifecycle markers are out of order.' }
    $policyBegin = Get-VT7RetirementMatch $text '(?m)^VT7_EXCEPTION_POLICY_BEGIN$'
    $policyEnd = Get-VT7RetirementMatch $text '(?m)^VT7_EXCEPTION_POLICY_END$'
    if ($policyBegin.Index -le $begin.Index -or $policyBegin.Index -ge $policyEnd.Index -or $policyEnd.Index -ge $armed.Index) { throw 'Exception policy was not established before arming the trace.' }
    if ([regex]::IsMatch($text.Substring($armed.Index), '(?im)^[0-9a-f]+:[0-9a-f]+>[\t ]*$')) { throw 'Debugger escaped to an unexpected interactive stop.' }
    if ([regex]::Matches($text, '(?m)^Handle tracing information snapshot successfully taken\.$').Count -ne 11) { throw 'Trace is missing a successful enable, baseline, diff or reset snapshot.' }
    $activation = Get-VT7RetirementMatch $text '(?ms)^VT7_HTRACE_ACTIVATE_BEGIN\n(?<body>.*?)^VT7_HTRACE_ACTIVATE_END$'
    if ([regex]::Matches($text, '(?m)^VT7_HTRACE_ACTIVATE_').Count -ne 2 -or
        $activation.Index -le $armed.Index -or $enabled.Index -le $activation.Index -or
        $enabled.Index -ge $activation.Index + $activation.Length) { throw 'Handle tracing activation is malformed or out of order.' }
    [void](Get-VT7RetirementMatch $activation.Groups['body'].Value '(?m)^Handle tracing enabled\.$')
    $activationSnapshot = Get-VT7RetirementMatch $activation.Groups['body'].Value '(?m)^Handle tracing information snapshot successfully taken\.$'
    if ($activationSnapshot.Index -le ([regex]::Match($activation.Groups['body'].Value, '(?m)^Handle tracing enabled\.$')).Index) { throw 'Handle tracing activation snapshot preceded enablement.' }
    [void](Get-VT7RetirementMatch $text '(?m)^VT7 RESOURCE RETIREMENT 0\.1; compiled .+; pid=[1-9][0-9]*$')
    [void](Get-VT7RetirementMatch $text '(?m)^CONFIG mode=reuse renderer=2 capture=1 power=0 probes=0 warmup=2 cycles=25 fail_at_cycle=0$')
    [void](Get-VT7RetirementMatch $text '(?m)^NATIVE 0\.3\.5 ABI=8 Release x64 .+$')
    [void](Get-VT7RetirementMatch $text '(?m)^OS [0-9]+\.[0-9]+\.[0-9]+ SP=[0-9]+\.[0-9]+ bits=64$')
    [void](Get-VT7RetirementMatch $text '(?m)^WORKLOAD iterations=27 creates=1 destroys=1 resizes=270 size_resets=27 hide_show=135 power_registrations=0 power_unregistrations=0 power_delivered=0$')
    $completed = Get-VT7RetirementMatch $text '(?m)^COMPLETED: measurement only, not stability acceptance\. No soak performed\.$'
    if ($completed.Index -ge $exit.Index) { throw 'Trace exit preceded workload completion.' }
    if (-not [regex]::IsMatch($text, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+VT7_ResourceRetirement\s+(?:[A-Z]\s+)?\(private pdb symbols\)')) { throw 'Trace lacks application private PDB confirmation.' }
    $setup = [regex]::Matches($text, '(?m)^VT7_SETUP event=(?<event>[1-9][0-9]*) checkpoint=(?<sample>[0-8]) pid=(?<pid>[1-9][0-9]*) tid=[1-9][0-9]* teb=[0-9a-fA-F`]+ ip=[0-9a-fA-F`]+ sp=(?<sp>[0-9a-fA-F`]+) return=(?<return>[0-9a-fA-F`]+)\n(?<stack>.*?)^VT7_SETUP_END$', [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($setup.Count -eq 0 -or $setup.Count -ge 256 -or $setup.Count -ne [int]$exit.Groups['events'].Value -or
        $setup.Count -ne [regex]::Matches($text, '(?m)^VT7_SETUP ').Count -or $setup.Count -ne [regex]::Matches($text, '(?m)^VT7_SETUP_END$').Count) { throw 'Setup hook collection is missing, malformed or truncated.' }
    $workloadPid = (Get-VT7RetirementMatch $text '(?m)^VT7 RESOURCE RETIREMENT 0\.1; compiled .+; pid=(?<pid>[1-9][0-9]*)$').Groups['pid'].Value
    Assert-VT7RetirementInvalidHandleEpisodes $text $armed.Index $exit.Index $workloadPid ([int]$exit.Groups['invalid'].Value)
    for ($index = 0; $index -lt $setup.Count; ++$index) {
        if ([int]$setup[$index].Groups['event'].Value -ne $index + 1 -or $setup[$index].Groups['pid'].Value -ne $workloadPid -or
            $setup[$index].Index -le $armed.Index -or $setup[$index].Index -ge $exit.Index -or
            -not [regex]::IsMatch($setup[$index].Groups['stack'].Value, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+USER32!ClientThreadSetup(?:\s|$)')) { throw 'Setup hook event numbering, process or stack is inconsistent.' }
        $frame = Get-VT7RetirementMatch $setup[$index].Groups['stack'].Value '(?im)^(?<sp>[0-9a-f`]+)\s+(?<return>[0-9a-f`]+)\s+USER32!ClientThreadSetup(?:\s.*)?$'
        foreach ($field in @('sp', 'return')) {
            if ($frame.Groups[$field].Value.Replace('`', '') -ne $setup[$index].Groups[$field].Value.Replace('`', '')) { throw 'Setup stack entry disagrees with the captured entry registers.' }
        }
        if ([int]$setup[$index].Groups['sample'].Value -ne [regex]::Matches($text.Substring(0, $setup[$index].Index), '(?m)^VT7_CHECKPOINT ').Count) { throw 'Setup event checkpoint attribution is out of order.' }
    }
    $checkpoints = [regex]::Matches($text, '(?m)^VT7_CHECKPOINT sample=(?<sample>[1-8]) phase=(?<phase>\S+) iteration=(?<iteration>[0-9]+) live=(?<live>[01])$')
    $phases = @('pre-warmup', 'warmup-live', 'baseline-live', 'measured-live', 'final-closed', 'final-closed-10s', 'final-closed-90s', 'final-closed-180s')
    $iterations = @(0, 0, 0, 25, 25, 25, 25, 25)
    $lives = @(0, 1, 1, 1, 0, 0, 0, 0)
    if ($checkpoints.Count -ne 8 -or [regex]::Matches($text, '(?m)^VT7_CHECKPOINT ').Count -ne 8 -or
        [regex]::Matches($text, '(?m)^VT7_HANDLES_BEGIN$').Count -ne 8 -or [regex]::Matches($text, '(?m)^VT7_HANDLES_END$').Count -ne 8) { throw 'Trace checkpoints or handle inventories are missing or duplicated.' }
    for ($index = 0; $index -lt 8; ++$index) {
        $sample = $index + 1
        $checkpoint = $checkpoints[$index]
        if ([int]$checkpoint.Groups['sample'].Value -ne $sample -or $checkpoint.Groups['phase'].Value -ne $phases[$index] -or
            [int]$checkpoint.Groups['iteration'].Value -ne $iterations[$index] -or [int]$checkpoint.Groups['live'].Value -ne $lives[$index]) { throw 'Debugger checkpoint differs from the planned workload.' }
        $resource = Get-VT7RetirementMatch $text ('(?m)^RESOURCE sample=' + $sample + ' .+$')
        if ($checkpoint.Index -le $armed.Index -or $checkpoint.Index -ge $completed.Index -or $checkpoint.Index -ge $resource.Index) { throw 'Resource sample or debugger checkpoint is out of order.' }
        $block = $text.Substring($checkpoint.Index, $resource.Index - $checkpoint.Index)
        $inventory = Get-VT7RetirementMatch $block '(?ms)^VT7_HANDLES_BEGIN\n(?<body>.*?)^VT7_HANDLES_END$'
        Assert-VT7RetirementHandleInventory $inventory.Groups['body'].Value $true
        if ($sample -eq 1 -and ($activation.Index -le $checkpoint.Index -or
            $activation.Index + $activation.Length -ge $checkpoint.Index + $inventory.Index)) { throw 'Handle tracing was not activated at the first checkpoint before its inventory.' }
        $required = @()
        if ($sample -eq 3) { $required = @('HTRACE_BASELINE_BEGIN', 'HTRACE_BASELINE_END') }
        if ($sample -eq 4) { $required = @('HTRACE_25_BEGIN', 'HTRACE_25_END', 'HTRACE_POST25_SNAPSHOT') }
        if ($sample -eq 5) { $required = @('HTRACE_CLOSED_BEGIN', 'HTRACE_CLOSED_END', 'HTRACE_POSTCLOSE_SNAPSHOT') }
        if ($sample -eq 6) { $required = @('HTRACE_CLOSED10_BEGIN', 'HTRACE_CLOSED10_END', 'HTRACE_POSTCLOSE10_SNAPSHOT') }
        if ($sample -eq 7) { $required = @('HTRACE_CLOSED90_BEGIN', 'HTRACE_CLOSED90_END', 'HTRACE_POSTCLOSE90_SNAPSHOT') }
        if ($sample -eq 8) { $required = @('HTRACE_CLOSED180_BEGIN', 'HTRACE_CLOSED180_END', 'HTRACE_HISTORY_BEGIN', 'HTRACE_HISTORY_END', 'MODULES_BEGIN', 'MODULES_END') }
        foreach ($marker in $required) { [void](Get-VT7RetirementMatch $block ('(?m)^VT7_' + $marker + '$')) }
    }
    $baseline = Get-VT7RetirementMatch $text '(?ms)^VT7_HTRACE_BASELINE_BEGIN\n(?<body>.*?)^VT7_HTRACE_BASELINE_END$'
    [void](Get-VT7RetirementMatch $baseline.Groups['body'].Value '(?m)^Handle tracing information snapshot successfully taken\.$')
    foreach ($module in @('VT7_Native', 'D3D10Warp', 'ntdll', 'USER32', 'GDI32')) {
        if (-not [regex]::IsMatch($baseline.Groups['body'].Value, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+' + $module + '\s+(?:[A-Z]\s+)?\(')) { throw "Baseline module inventory is missing $module." }
    }
    foreach ($name in @('25', 'CLOSED', 'CLOSED10', 'CLOSED90', 'CLOSED180')) {
        $diff = Get-VT7RetirementMatch $text ('(?ms)^VT7_HTRACE_' + $name + '_BEGIN\n(?<body>.*?)^VT7_HTRACE_' + $name + '_END$')
        Assert-VT7RetirementHtraceDiff $diff.Groups['body'].Value
    }
    foreach ($name in @('BASELINE_BEGIN', 'BASELINE_END', '25_BEGIN', '25_END', 'POST25_SNAPSHOT', 'CLOSED_BEGIN', 'CLOSED_END', 'POSTCLOSE_SNAPSHOT', 'CLOSED10_BEGIN', 'CLOSED10_END', 'POSTCLOSE10_SNAPSHOT', 'CLOSED90_BEGIN', 'CLOSED90_END', 'POSTCLOSE90_SNAPSHOT', 'CLOSED180_BEGIN', 'CLOSED180_END')) {
        [void](Get-VT7RetirementMatch $text ('(?m)^VT7_HTRACE_' + $name + '$'))
    }
    foreach ($name in @('POST25', 'POSTCLOSE', 'POSTCLOSE10', 'POSTCLOSE90')) {
        [void](Get-VT7RetirementMatch $text ('(?m)^Handle tracing information snapshot successfully taken\.\nVT7_HTRACE_' + $name + '_SNAPSHOT$'))
    }
    $history = Get-VT7RetirementMatch $text '(?ms)^VT7_HTRACE_HISTORY_BEGIN\n(?<body>.*?)^VT7_HTRACE_HISTORY_END$'
    if ([regex]::Matches($text, '(?m)^VT7_HTRACE_HISTORY_').Count -ne 2 -or $history.Index -le (Get-VT7RetirementMatch $text '(?m)^VT7_HTRACE_CLOSED180_END$').Index) { throw 'Full handle history was not captured after the final idle diff.' }
    Assert-VT7RetirementHtraceHistory $history.Groups['body'].Value
    $modules = Get-VT7RetirementMatch $text '(?ms)^VT7_MODULES_BEGIN\n(?<body>.*?)^VT7_MODULES_END$'
    foreach ($module in @('VT7_ResourceRetirement', 'VT7_Native', 'ntdll', 'USER32')) {
        if (-not [regex]::IsMatch($modules.Groups['body'].Value, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+' + $module + '\s+(?:[A-Z]\s+)?\(')) { throw "Final module inventory is missing $module." }
    }
    Assert-VT7RetirementThreadSamples $text
    Assert-VT7RetirementIdleWaits $text
    Assert-VT7RetirementOwnership $text
}
