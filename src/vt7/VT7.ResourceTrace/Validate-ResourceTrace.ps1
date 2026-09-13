# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Windows PowerShell 2.0 compatible. Dot-source only; no automatic work or output.
# These checks establish collection completeness, never complete causal attribution.

function Get-VT7TraceMatch {
    param([string]$Text, [string]$Pattern)
    $found = [regex]::Matches($Text, $Pattern)
    if ($found.Count -ne 1) { throw "Missing, malformed or duplicated trace record: $Pattern" }
    return $found[0]
}

function Assert-VT7TraceNoErrors {
    param([string]$Text)
    $failures = @(
        '(?m)^(?:FAIL |INCOMPLETE:|VT7_TRACE_TRUNCATED_SETUP|VT7_TRACE_ABORT_)[^\r\n]*$',
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

function Assert-VT7HandleInventory {
    param([string]$Text, [bool]$Detailed)
    $Text = $Text.Replace("`r", '')
    $total = Get-VT7TraceMatch $Text '(?m)^(?<count>[1-9][0-9]*) Handles\s*$'
    $table = Get-VT7TraceMatch $Text '(?m)^Type\s+Count\s*\n(?<rows>(?:[^\n]+[\t ]+[0-9]+[\t ]*\n?)+)'
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
            $objectType = Get-VT7TraceMatch $body '(?m)^  Type[\t ]+(?<type>[^\n]*\S)[\t ]*$'
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

function Assert-VT7HtraceDiff {
    param([string]$Text)
    [void](Get-VT7TraceMatch $Text '(?m)^Handle tracing information snapshot successfully taken\.$')
    $newTraces = Get-VT7TraceMatch $Text '(?m)^0x(?<count>[0-9a-fA-F]+) new stack traces since the previous snapshot\.$'
    if ([Convert]::ToUInt32($newTraces.Groups['count'].Value, 16) -gt 0) {
        [void](Get-VT7TraceMatch $Text '(?m)^Ignoring handles that were already closed\.\.\.$')
    }
    $empty = [regex]::Matches($Text, '(?m)^No outstanding handles opened since the previous snapshot were detected\.$')
    $displayed = [regex]::Matches($Text, '(?m)^Displayed 0x(?<count>[0-9a-fA-F]+) stack traces for outstanding handles opened since the previous snapshot\.$')
    if ($empty.Count + $displayed.Count -ne 1) { throw 'Missing or duplicated successful handle-trace diff result.' }
    $entries = [regex]::Matches($Text, '(?m)^Handle = 0x[0-9a-fA-F]+ - (?:OPEN|CLOSE|BADREF)\s*$')
    if ($empty.Count -eq 1 -and $entries.Count -ne 0) { throw 'Empty handle diff contains outstanding handle histories.' }
    if ($displayed.Count -eq 1) {
        $count = [Convert]::ToUInt32($displayed[0].Groups['count'].Value, 16)
        if ($count -eq 0 -or $entries.Count -ne $count) { throw 'Displayed handle histories are incomplete.' }
        [void](Get-VT7TraceMatch $Text '(?m)^Outstanding handles opened since the previous snapshot:$')
        $owners = [regex]::Matches($Text, '(?m)^Thread ID = 0x[0-9a-fA-F]+, Process ID = 0x[0-9a-fA-F]+$')
        if ($owners.Count -ne $entries.Count) { throw 'Handle history is missing its thread/process record.' }
        $histories = [regex]::Matches($Text, '(?ms)^Handle = 0x[0-9a-fA-F]+ - (?:OPEN|CLOSE|BADREF)\s*\n(?<body>.*?)(?=^Handle = |^Displayed )')
        if ($histories.Count -ne $entries.Count) { throw 'Handle history boundaries are incomplete.' }
        foreach ($history in $histories) {
            $owner = Get-VT7TraceMatch $history.Groups['body'].Value '(?m)^Thread ID = 0x[0-9a-fA-F]+, Process ID = 0x(?<pid>[0-9a-fA-F]+)$'
            # Recorded PID 4 kernel-origin entries can have no user stack. Preserve
            # them as collected histories with unavailable causal attribution.
            if (-not [regex]::IsMatch($history.Groups['body'].Value, '(?m)^0x[0-9a-fA-F]+: .+$') -and
                [Convert]::ToUInt32($owner.Groups['pid'].Value, 16) -ne 4) { throw 'An outstanding user-process handle history is missing its stack frames.' }
        }
    }
}

function Assert-VT7TracePreflight {
    param([string]$Text)
    $text = $Text.Replace("`r", '')
    Assert-VT7TraceNoErrors $text
    $begin = Get-VT7TraceMatch $text '(?m)^VT7_TRACE_PREFLIGHT_BEGIN$'
    $end = Get-VT7TraceMatch $text '(?m)^VT7_TRACE_PREFLIGHT_END$'
    if ($end.Index -le $begin.Index) { throw 'Preflight marker order is invalid.' }
    $body = $text.Substring($begin.Index, $end.Index - $begin.Index)
    [void](Get-VT7TraceMatch $body '(?m)^VT7_TRACE_HTRACE_ENABLE_BEGIN$')
    [void](Get-VT7TraceMatch $body '(?m)^Handle tracing enabled\.$')
    [void](Get-VT7TraceMatch $body '(?m)^Handle tracing disabled\.$')
    if ([regex]::Matches($body, '(?m)^Handle tracing information snapshot successfully taken\.$').Count -ne 3) { throw 'Preflight did not enable, snapshot and diff handle tracing successfully.' }
    [void](Get-VT7TraceMatch $body '(?m)^0x[0-9a-fA-F]+ new stack traces since the previous snapshot\.$')
    if ([regex]::Matches($body, '(?m)^(?:No outstanding handles opened since the previous snapshot were detected\.|Displayed 0x[0-9a-fA-F]+ stack traces for outstanding handles opened since the previous snapshot\.)$').Count -ne 1) { throw 'Preflight handle diff did not complete.' }
    Assert-VT7HandleInventory $body $false
    $moduleRows = [regex]::Matches($body, '(?im)^(?<base>[0-9a-f`]+)\s+[0-9a-f`]+\s+VT7_ResourceLifetime\s+(?:[A-Z]\s+)?\(private pdb symbols\).*$')
    if ($moduleRows.Count -lt 1) { throw 'Preflight did not establish application private PDB symbols.' }
    $moduleBase = [Convert]::ToUInt64($moduleRows[0].Groups['base'].Value.Replace('`', ''), 16)
    $sample = Get-VT7TraceMatch $body '(?m)^VT7_TRACE_SAMPLE_ADDRESS=(?<address>[0-9a-fA-F`]+)$'
    $hook = Get-VT7TraceMatch $body '(?m)^VT7_TRACE_HOOK_ADDRESS=(?<address>[0-9a-fA-F`]+)$'
    $sampleAddress = [Convert]::ToUInt64($sample.Groups['address'].Value.Replace('`', ''), 16)
    $hookAddress = [Convert]::ToUInt64($hook.Groups['address'].Value.Replace('`', ''), 16)
    if ($sampleAddress -ne $moduleBase + 0x1470 -or $hookAddress -eq 0) { throw 'Preflight checkpoint or hook address is invalid.' }
    $sampleSymbol = [regex]::Matches($body, '(?im)^(?<address>[0-9a-f`]+)\s+VT7_ResourceLifetime!.*::sample(?:\s+.*)?$')
    if ($sampleSymbol.Count -ne 1 -or [Convert]::ToUInt64($sampleSymbol[0].Groups['address'].Value.Replace('`', ''), 16) -ne $sampleAddress) { throw 'The sample PDB symbol does not match the pinned checkpoint RVA.' }
    $hookSymbol = Get-VT7TraceMatch $body '(?im)^(?<address>[0-9a-f`]+)\s+USER32!ClientThreadSetup(?:\s+.*)?$'
    if ([Convert]::ToUInt64($hookSymbol.Groups['address'].Value.Replace('`', ''), 16) -ne $hookAddress) { throw 'The USER32 hook symbol does not match its reported address.' }
    [void](Get-VT7TraceMatch $body '(?im)^USER32!ClientThreadSetup:$')
}

function Assert-VT7TraceThreadSamples {
    param([string]$Text)
    $phases = @('pre-warmup', 'warmup-live', 'baseline-live', 'measured-live', 'final-closed', 'final-closed-10s')
    $iterations = @(0, 0, 0, 25, 25, 25)
    $lives = @(0, 1, 1, 1, 0, 0)
    $resources = [regex]::Matches($Text, '(?m)^RESOURCE sample=(?<sample>[0-9]+) phase=(?<phase>\S+) iteration=(?<iteration>[0-9]+) live=(?<live>[01]) private=[0-9]+ handles=[0-9]+ GDI=[0-9]+ USER=[0-9]+ threads=(?<threads>[0-9]+) begin_ms=(?<begin>[0-9]+) end_ms=(?<end>[0-9]+)$')
    $rows = [regex]::Matches($Text, '(?m)^THREAD sample=(?<sample>[0-9]+) tid=(?<tid>[0-9]+) creation=(?<creation>[0-9A-F]{16}) identity_error=(?<error>[0-9]+) observation=(?<observation>\S+) first_sample=(?<first>[0-9]+) queue=(?<queue>observed|unavailable) queue_error=(?<qerror>[0-9]+) first_queue_sample=(?<qfirst>[0-9]+) alive_before=(?<before>[0-9]+) alive_after=(?<after>[0-9]+) origin=.+ offset=[0-9A-F]+ start=[0-9A-F]+ origin_status=[0-9A-F]{8} module_error=[0-9]+$')
    $absences = [regex]::Matches($Text, '(?m)^NOT_OBSERVED sample=(?<sample>[0-9]+) tid=(?<tid>[0-9]+) creation=(?<creation>[0-9A-F]{16}) previous_sample=(?<previous>[0-9]+); absence_from_snapshot_not_complete_exit_history$')
    if ($resources.Count -ne 6 -or [regex]::Matches($Text, '(?m)^RESOURCE ').Count -ne 6 -or
        $rows.Count -ne [regex]::Matches($Text, '(?m)^THREAD ').Count -or $absences.Count -ne [regex]::Matches($Text, '(?m)^NOT_OBSERVED ').Count) { throw 'Malformed or incomplete resource/thread sample records.' }
    $history = @{}
    $tids = @{}
    $unavailable = 0
    $counted = 0
    $absentCount = 0
    [uint64]$lastEnd = 0
    for ($index = 0; $index -lt 6; ++$index) {
        $sample = $index + 1
        $resource = $resources[$index]
        if ([int]$resource.Groups['sample'].Value -ne $sample -or $resource.Groups['phase'].Value -ne $phases[$index] -or
            [int]$resource.Groups['iteration'].Value -ne $iterations[$index] -or [int]$resource.Groups['live'].Value -ne $lives[$index]) { throw "Resource checkpoint $sample is mismatched." }
        [uint64]$begin = $resource.Groups['begin'].Value
        [uint64]$end = $resource.Groups['end'].Value
        if ($begin -lt $lastEnd -or $end -lt $begin) { throw 'Resource sample timestamps are inconsistent.' }
        if ($sample -eq 6 -and $begin - $lastEnd -lt 10000) { throw 'Final closed resource sample lacks the ten-second wait.' }
        $lastEnd = $end
        $current = @($rows | Where-Object { [int]$_.Groups['sample'].Value -eq $sample })
        if ($current.Count -eq 0 -or $current.Count -ne [int]$resource.Groups['threads'].Value) { throw "Thread row count is incomplete at sample $sample." }
        $counted += $current.Count
        $seen = @{}
        foreach ($row in $current) {
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
    [void](Get-VT7TraceMatch $Text ('(?m)^ATTRIBUTION samples=6 identities=' + $history.Count + ' identity_unavailable=' + $unavailable + '; queue_unavailable_is_not_queue_absent$'))
}

function Assert-VT7InvalidHandleEpisodes {
    param([string]$Text, [int]$ArmedIndex, [int]$ExitIndex, [string]$ProcessId, [int]$ExpectedCount)
    if ($ExpectedCount -lt 0 -or $ExpectedCount -ge 16) { throw 'Invalid-handle exception collection reached or exceeded its bound.' }
    $episodes = [regex]::Matches($Text, '(?ms)^VT7_INVALID_HANDLE event=(?<event>[1-9][0-9]*) checkpoint=(?<sample>[0-6]) pid=(?<pid>[1-9][0-9]*) tid=(?<tid>[1-9][0-9]*)\n(?<body>.*?)^VT7_INVALID_HANDLE_END\nVT7_INVALID_HANDLE_DISPATCH$')
    if ($episodes.Count -ne $ExpectedCount -or $episodes.Count -ne [regex]::Matches($Text, '(?m)^VT7_INVALID_HANDLE ').Count -or
        $episodes.Count -ne [regex]::Matches($Text, '(?m)^VT7_INVALID_HANDLE_END$').Count -or $episodes.Count -ne [regex]::Matches($Text, '(?m)^VT7_INVALID_HANDLE_DISPATCH$').Count) { throw 'Invalid-handle exception context or dispatch record is missing or duplicated.' }
    for ($index = 0; $index -lt $episodes.Count; ++$index) {
        $episode = $episodes[$index]
        if ([int]$episode.Groups['event'].Value -ne $index + 1 -or $episode.Groups['pid'].Value -ne $ProcessId -or
            $episode.Index -le $ArmedIndex -or $episode.Index + $episode.Length -ge $ExitIndex -or
            [int]$episode.Groups['sample'].Value -ne [regex]::Matches($Text.Substring(0, $episode.Index), '(?m)^VT7_CHECKPOINT ').Count) { throw 'Invalid-handle exception event order, process or checkpoint is inconsistent.' }
        $body = $episode.Groups['body'].Value
        $last = Get-VT7TraceMatch $body '(?im)^Last event:\s*(?<pid>[0-9a-f]+)\.(?<tid>[0-9a-f]+):.*\bcode c0000008 \(first chance\)\s*$'
        if ([Convert]::ToUInt32($last.Groups['pid'].Value, 16) -ne [uint32]$ProcessId -or
            [Convert]::ToUInt32($last.Groups['tid'].Value, 16) -ne [uint32]$episode.Groups['tid'].Value) { throw 'Invalid-handle exception debugger event identity does not match its marker.' }
        [void](Get-VT7TraceMatch $body '(?im)^\s*ExceptionCode:\s*c0000008(?:\s+.*)?$')
        [void](Get-VT7TraceMatch $body '(?im)^\s*ExceptionAddress:\s*[0-9a-f`]+(?:\s+.*)?$')
        [void](Get-VT7TraceMatch $body '(?im)^\s*ExceptionFlags:\s*[0-9a-f]{8}\s*$')
        [void](Get-VT7TraceMatch $body '(?im)^\s*NumberParameters:\s*[0-9]+\s*$')
        [void](Get-VT7TraceMatch $body '(?im)^rip=[0-9a-f`]+\s+rsp=[0-9a-f`]+\s+rbp=[0-9a-f`]+\s*$')
        [void](Get-VT7TraceMatch $body '(?im)^Child-SP\s+RetAddr\s+Call Site\s*$')
        if (-not [regex]::IsMatch($body, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+\S+!\S+')) { throw 'Invalid-handle exception lacks stack context.' }
        foreach ($module in @('VT7_ResourceLifetime', 'ntdll')) {
            if (-not [regex]::IsMatch($body, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+' + $module + '\s+(?:[A-Z]\s+)?\(')) { throw "Invalid-handle exception module context lacks $module." }
        }
    }
    $reported = [regex]::Matches($Text, '(?im)^\([0-9a-f]+\.[0-9a-f]+\): Invalid handle - code c0000008 \(first chance\)\s*$')
    if ($reported.Count -gt $episodes.Count) { throw 'A first-chance invalid handle has no corresponding complete dispatch record.' }
}

function Assert-VT7StartupControl {
    param([string]$Text)
    $text = $Text.Replace("`r", '')
    Assert-VT7TraceNoErrors $text
    $begin = Get-VT7TraceMatch $text '(?m)^VT7_STARTUP_BEGIN version=0\.3$'
    $policyBegin = Get-VT7TraceMatch $text '(?m)^VT7_EXCEPTION_POLICY_BEGIN$'
    $policyEnd = Get-VT7TraceMatch $text '(?m)^VT7_EXCEPTION_POLICY_END$'
    $ready = Get-VT7TraceMatch $text '(?m)^VT7_STARTUP_READY phase=pre-warmup iteration=0 live=0 invalid_handles=(?<invalid>[0-9]+)$'
    $end = Get-VT7TraceMatch $text '(?m)^VT7_STARTUP_END$'
    $banner = Get-VT7TraceMatch $text '(?m)^VT7 RESOURCE LIFETIME 0\.2; compiled .+; pid=(?<pid>[1-9][0-9]*)$'
    $config = Get-VT7TraceMatch $text '(?m)^CONFIG mode=reuse renderer=2 capture=1 power=0 probes=0 warmup=2 cycles=25 fail_at_cycle=0$'
    $native = Get-VT7TraceMatch $text '(?m)^NATIVE 0\.3\.5 ABI=8 Release x64 .+$'
    $os = Get-VT7TraceMatch $text '(?m)^OS [0-9]+\.[0-9]+\.[0-9]+ SP=[0-9]+\.[0-9]+ bits=64$'
    $nativeLoad = Get-VT7TraceMatch $text '(?im)^ModLoad:\s+[0-9a-f`]+\s+[0-9a-f`]+\s+[^\n]*VT7\.Native\.dll\s*$'
    if ($begin.Index -ge $policyBegin.Index -or $policyBegin.Index -ge $policyEnd.Index -or
        $policyEnd.Index -ge $banner.Index -or $banner.Index -ge $config.Index -or
        $config.Index -ge $nativeLoad.Index -or $nativeLoad.Index -ge $native.Index -or
        $native.Index -ge $os.Index -or $os.Index -ge $ready.Index -or $ready.Index -ge $end.Index) { throw 'Startup control records are out of order.' }
    if ([regex]::Matches($text, '(?m)^VT7_STARTUP_').Count -ne 3 -or
        [regex]::Matches($text, '(?m)^VT7_EXCEPTION_POLICY_').Count -ne 2) { throw 'Startup control markers are malformed or duplicated.' }
    if ([regex]::IsMatch($text, '(?m)^(?:VT7_(?:SETUP|CHECKPOINT|HTRACE|HANDLES|MODULES|TRACE_)|RESOURCE |THREAD |NOT_OBSERVED |WORKLOAD |ATTRIBUTION |COMPLETED:|Handle tracing |0x[0-9a-fA-F]+ new stack traces|Displayed 0x[0-9a-fA-F]+ stack traces|No outstanding handles)')) { throw 'Startup control contains measurement or handle-tracing activity.' }
    if ([regex]::IsMatch($text.Substring($policyEnd.Index), '(?im)^[0-9a-f]+:[0-9a-f]+>[\t ]*$')) { throw 'Startup control escaped to an unexpected interactive stop.' }
    if (-not [regex]::IsMatch($text.Substring($begin.Index, $ready.Index - $begin.Index), '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+VT7_ResourceLifetime\s+(?:[A-Z]\s+)?\(private pdb symbols\)')) { throw 'Startup control lacks application private PDB confirmation.' }
    $modules = $text.Substring($ready.Index, $end.Index - $ready.Index)
    foreach ($module in @('VT7_ResourceLifetime', 'VT7_Native', 'ntdll')) {
        if (-not [regex]::IsMatch($modules, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+' + $module + '\s+(?:[A-Z]\s+)?\(')) { throw "Startup control module inventory lacks $module." }
    }
    Assert-VT7InvalidHandleEpisodes $text $policyEnd.Index $ready.Index $banner.Groups['pid'].Value ([int]$ready.Groups['invalid'].Value)
}

function Assert-VT7ResourceTrace {
    param([string]$Text)
    $text = $Text.Replace("`r", '')
    Assert-VT7TraceNoErrors $text
    $begin = Get-VT7TraceMatch $text '(?m)^VT7_TRACE_BEGIN version=0\.3 cycles=25 offline_symbols=1$'
    $armed = Get-VT7TraceMatch $text '(?m)^VT7_TRACE_ARMED$'
    $end = Get-VT7TraceMatch $text '(?m)^VT7_TRACE_END$'
    $exit = Get-VT7TraceMatch $text '(?m)^VT7_TRACE_EXIT status=0 checkpoints=6 setup_events=(?<events>[1-9][0-9]*) invalid_handles=(?<invalid>[0-9]+)$'
    $enabled = Get-VT7TraceMatch $text '(?m)^Handle tracing enabled\.$'
    $disabled = Get-VT7TraceMatch $text '(?m)^Handle tracing disabled\.$'
    if ($begin.Index -ge $armed.Index -or $armed.Index -ge $enabled.Index -or $enabled.Index -ge $exit.Index -or $exit.Index -ge $disabled.Index -or $disabled.Index -ge $end.Index) { throw 'Trace lifecycle markers are out of order.' }
    $policyBegin = Get-VT7TraceMatch $text '(?m)^VT7_EXCEPTION_POLICY_BEGIN$'
    $policyEnd = Get-VT7TraceMatch $text '(?m)^VT7_EXCEPTION_POLICY_END$'
    if ($policyBegin.Index -le $begin.Index -or $policyBegin.Index -ge $policyEnd.Index -or $policyEnd.Index -ge $armed.Index) { throw 'Exception policy was not established before arming the trace.' }
    if ([regex]::IsMatch($text.Substring($armed.Index), '(?im)^[0-9a-f]+:[0-9a-f]+>[\t ]*$')) { throw 'Debugger escaped to an unexpected interactive stop.' }
    if ([regex]::Matches($text, '(?m)^Handle tracing information snapshot successfully taken\.$').Count -ne 7) { throw 'Trace is missing a successful enable, baseline, diff or reset snapshot.' }
    $activation = Get-VT7TraceMatch $text '(?ms)^VT7_HTRACE_ACTIVATE_BEGIN\n(?<body>.*?)^VT7_HTRACE_ACTIVATE_END$'
    if ([regex]::Matches($text, '(?m)^VT7_HTRACE_ACTIVATE_').Count -ne 2 -or
        $activation.Index -le $armed.Index -or $enabled.Index -le $activation.Index -or
        $enabled.Index -ge $activation.Index + $activation.Length) { throw 'Handle tracing activation is malformed or out of order.' }
    [void](Get-VT7TraceMatch $activation.Groups['body'].Value '(?m)^Handle tracing enabled\.$')
    $activationSnapshot = Get-VT7TraceMatch $activation.Groups['body'].Value '(?m)^Handle tracing information snapshot successfully taken\.$'
    if ($activationSnapshot.Index -le ([regex]::Match($activation.Groups['body'].Value, '(?m)^Handle tracing enabled\.$')).Index) { throw 'Handle tracing activation snapshot preceded enablement.' }
    [void](Get-VT7TraceMatch $text '(?m)^VT7 RESOURCE LIFETIME 0\.2; compiled .+; pid=[1-9][0-9]*$')
    [void](Get-VT7TraceMatch $text '(?m)^CONFIG mode=reuse renderer=2 capture=1 power=0 probes=0 warmup=2 cycles=25 fail_at_cycle=0$')
    [void](Get-VT7TraceMatch $text '(?m)^NATIVE 0\.3\.5 ABI=8 Release x64 .+$')
    [void](Get-VT7TraceMatch $text '(?m)^OS [0-9]+\.[0-9]+\.[0-9]+ SP=[0-9]+\.[0-9]+ bits=64$')
    [void](Get-VT7TraceMatch $text '(?m)^WORKLOAD iterations=27 creates=1 destroys=1 resizes=270 size_resets=27 hide_show=135 power_registrations=0 power_unregistrations=0 power_delivered=0$')
    $completed = Get-VT7TraceMatch $text '(?m)^COMPLETED: measurement only, not stability acceptance\. No soak performed\.$'
    if ($completed.Index -ge $exit.Index) { throw 'Trace exit preceded workload completion.' }
    if (-not [regex]::IsMatch($text, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+VT7_ResourceLifetime\s+(?:[A-Z]\s+)?\(private pdb symbols\)')) { throw 'Trace lacks application private PDB confirmation.' }
    $setup = [regex]::Matches($text, '(?m)^VT7_SETUP event=(?<event>[1-9][0-9]*) checkpoint=(?<sample>[0-6]) pid=(?<pid>[1-9][0-9]*) tid=[1-9][0-9]* teb=[0-9a-fA-F`]+ ip=[0-9a-fA-F`]+ sp=(?<sp>[0-9a-fA-F`]+) return=(?<return>[0-9a-fA-F`]+)\n(?<stack>.*?)^VT7_SETUP_END$', [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($setup.Count -eq 0 -or $setup.Count -ge 256 -or $setup.Count -ne [int]$exit.Groups['events'].Value -or
        $setup.Count -ne [regex]::Matches($text, '(?m)^VT7_SETUP ').Count -or $setup.Count -ne [regex]::Matches($text, '(?m)^VT7_SETUP_END$').Count) { throw 'Setup hook collection is missing, malformed or truncated.' }
    $workloadPid = (Get-VT7TraceMatch $text '(?m)^VT7 RESOURCE LIFETIME 0\.2; compiled .+; pid=(?<pid>[1-9][0-9]*)$').Groups['pid'].Value
    Assert-VT7InvalidHandleEpisodes $text $armed.Index $exit.Index $workloadPid ([int]$exit.Groups['invalid'].Value)
    for ($index = 0; $index -lt $setup.Count; ++$index) {
        if ([int]$setup[$index].Groups['event'].Value -ne $index + 1 -or $setup[$index].Groups['pid'].Value -ne $workloadPid -or
            $setup[$index].Index -le $armed.Index -or $setup[$index].Index -ge $exit.Index -or
            -not [regex]::IsMatch($setup[$index].Groups['stack'].Value, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+USER32!ClientThreadSetup(?:\s|$)')) { throw 'Setup hook event numbering, process or stack is inconsistent.' }
        $frame = Get-VT7TraceMatch $setup[$index].Groups['stack'].Value '(?im)^(?<sp>[0-9a-f`]+)\s+(?<return>[0-9a-f`]+)\s+USER32!ClientThreadSetup(?:\s.*)?$'
        foreach ($field in @('sp', 'return')) {
            if ($frame.Groups[$field].Value.Replace('`', '') -ne $setup[$index].Groups[$field].Value.Replace('`', '')) { throw 'Setup stack entry disagrees with the captured entry registers.' }
        }
        if ([int]$setup[$index].Groups['sample'].Value -ne [regex]::Matches($text.Substring(0, $setup[$index].Index), '(?m)^VT7_CHECKPOINT ').Count) { throw 'Setup event checkpoint attribution is out of order.' }
    }
    $checkpoints = [regex]::Matches($text, '(?m)^VT7_CHECKPOINT sample=(?<sample>[1-6]) phase=(?<phase>\S+) iteration=(?<iteration>[0-9]+) live=(?<live>[01])$')
    $phases = @('pre-warmup', 'warmup-live', 'baseline-live', 'measured-live', 'final-closed', 'final-closed-10s')
    $iterations = @(0, 0, 0, 25, 25, 25)
    $lives = @(0, 1, 1, 1, 0, 0)
    if ($checkpoints.Count -ne 6 -or [regex]::Matches($text, '(?m)^VT7_CHECKPOINT ').Count -ne 6 -or
        [regex]::Matches($text, '(?m)^VT7_HANDLES_BEGIN$').Count -ne 6 -or [regex]::Matches($text, '(?m)^VT7_HANDLES_END$').Count -ne 6) { throw 'Trace checkpoints or handle inventories are missing or duplicated.' }
    for ($index = 0; $index -lt 6; ++$index) {
        $sample = $index + 1
        $checkpoint = $checkpoints[$index]
        if ([int]$checkpoint.Groups['sample'].Value -ne $sample -or $checkpoint.Groups['phase'].Value -ne $phases[$index] -or
            [int]$checkpoint.Groups['iteration'].Value -ne $iterations[$index] -or [int]$checkpoint.Groups['live'].Value -ne $lives[$index]) { throw 'Debugger checkpoint differs from the planned workload.' }
        $resource = Get-VT7TraceMatch $text ('(?m)^RESOURCE sample=' + $sample + ' .+$')
        if ($checkpoint.Index -le $armed.Index -or $checkpoint.Index -ge $completed.Index -or $checkpoint.Index -ge $resource.Index) { throw 'Resource sample or debugger checkpoint is out of order.' }
        $block = $text.Substring($checkpoint.Index, $resource.Index - $checkpoint.Index)
        $inventory = Get-VT7TraceMatch $block '(?ms)^VT7_HANDLES_BEGIN\n(?<body>.*?)^VT7_HANDLES_END$'
        Assert-VT7HandleInventory $inventory.Groups['body'].Value $true
        if ($sample -eq 1 -and ($activation.Index -le $checkpoint.Index -or
            $activation.Index + $activation.Length -ge $checkpoint.Index + $inventory.Index)) { throw 'Handle tracing was not activated at the first checkpoint before its inventory.' }
        $required = @()
        if ($sample -eq 3) { $required = @('HTRACE_BASELINE_BEGIN', 'HTRACE_BASELINE_END') }
        if ($sample -eq 4) { $required = @('HTRACE_25_BEGIN', 'HTRACE_25_END', 'HTRACE_POST25_SNAPSHOT') }
        if ($sample -eq 5) { $required = @('HTRACE_CLOSED_BEGIN', 'HTRACE_CLOSED_END', 'HTRACE_POSTCLOSE_SNAPSHOT') }
        if ($sample -eq 6) { $required = @('HTRACE_CLOSED10_BEGIN', 'HTRACE_CLOSED10_END', 'MODULES_BEGIN', 'MODULES_END') }
        foreach ($marker in $required) { [void](Get-VT7TraceMatch $block ('(?m)^VT7_' + $marker + '$')) }
    }
    $baseline = Get-VT7TraceMatch $text '(?ms)^VT7_HTRACE_BASELINE_BEGIN\n(?<body>.*?)^VT7_HTRACE_BASELINE_END$'
    [void](Get-VT7TraceMatch $baseline.Groups['body'].Value '(?m)^Handle tracing information snapshot successfully taken\.$')
    foreach ($module in @('VT7_Native', 'D3D10Warp', 'ntdll', 'USER32', 'GDI32')) {
        if (-not [regex]::IsMatch($baseline.Groups['body'].Value, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+' + $module + '\s+(?:[A-Z]\s+)?\(')) { throw "Baseline module inventory is missing $module." }
    }
    foreach ($name in @('25', 'CLOSED', 'CLOSED10')) {
        $diff = Get-VT7TraceMatch $text ('(?ms)^VT7_HTRACE_' + $name + '_BEGIN\n(?<body>.*?)^VT7_HTRACE_' + $name + '_END$')
        Assert-VT7HtraceDiff $diff.Groups['body'].Value
    }
    foreach ($name in @('BASELINE_BEGIN', 'BASELINE_END', '25_BEGIN', '25_END', 'POST25_SNAPSHOT', 'CLOSED_BEGIN', 'CLOSED_END', 'POSTCLOSE_SNAPSHOT', 'CLOSED10_BEGIN', 'CLOSED10_END')) {
        [void](Get-VT7TraceMatch $text ('(?m)^VT7_HTRACE_' + $name + '$'))
    }
    foreach ($name in @('POST25', 'POSTCLOSE')) {
        [void](Get-VT7TraceMatch $text ('(?m)^Handle tracing information snapshot successfully taken\.\nVT7_HTRACE_' + $name + '_SNAPSHOT$'))
    }
    $modules = Get-VT7TraceMatch $text '(?ms)^VT7_MODULES_BEGIN\n(?<body>.*?)^VT7_MODULES_END$'
    foreach ($module in @('VT7_ResourceLifetime', 'VT7_Native', 'ntdll', 'USER32')) {
        if (-not [regex]::IsMatch($modules.Groups['body'].Value, '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+' + $module + '\s+(?:[A-Z]\s+)?\(')) { throw "Final module inventory is missing $module." }
    }
    Assert-VT7TraceThreadSamples $text
}
