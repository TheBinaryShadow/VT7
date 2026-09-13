# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Windows PowerShell 2.0 compatible. Text-only tests; no target or debugger launch.
[CmdletBinding()]
param([string]$CompleteLog, [string]$PreflightLog, [string]$StartupLog, [string[]]$KnownInvalidLog)
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..'))
. (Join-Path $repositoryRoot 'src\vt7\VT7.ResourceRetirement\Validate-ResourceRetirement.ps1')

function Replace-RetirementFixture {
    param([string]$Text, [string]$Pattern, [string]$Replacement)
    $expression = New-Object Text.RegularExpressions.Regex($Pattern)
    if (-not $expression.IsMatch($Text)) { throw "Fixture mutation did not match: $Pattern" }
    return $expression.Replace($Text, $Replacement, 1)
}

# These small, explicitly synthetic records test format and correlation checks.
# They are not an execution result or evidence about Windows worker retirement.
$modules = @'
0000000140000000 0000000140020000 VT7_ResourceRetirement (private pdb symbols)
0000000180000000 0000000180200000 VT7_Native (private pdb symbols)
000007feaeee0000 000007feaf159000 D3D10Warp (export symbols)
0000000077610000 00000000777af000 ntdll (export symbols)
0000000075000000 0000000075100000 USER32 (export symbols)
0000000074000000 0000000074100000 GDI32 (export symbols)
'@
$inventory = @'
Handle 40
  Type         Event
  Object Specific Information
    Event Type Auto Reset
Handle 44
  Type         Token
  Object Specific Information
    Type       Primary
Handle 48
  Type         TpWorkerFactory
  Object Specific Information
    Thread idle timeout: -670000000 x100ns
    Total workers: 1 thread(s) in the pool
    Pool: !tp pool 0000000000266460
3 Handles
Type             Count
Event            1
Token            1
TpWorkerFactory  1
'@
$banner = @'
VT7 RESOURCE RETIREMENT 0.1; compiled synthetic fixture; pid=100
CONFIG mode=reuse renderer=2 capture=1 power=0 probes=0 warmup=2 cycles=25 fail_at_cycle=0
RETIREMENT post_close_targets_ms=10000,90000,180000 wait_segments_ms=10000,80000,90000; wait_timing=wall_clock; debugger_pauses_count_toward_wait=1
ModLoad: 0000000180000000 0000000180200000 C:\fixture\VT7.Native.dll
NATIVE 0.3.5 ABI=8 Release x64 synthetic fixture
OS 6.1.7601 SP=1.0 bits=64
'@
$ownershipStart = @'
VT7_WARP_PROFILE status=MATCHED profile=win7-6.2.9200.22592 base=000007feaeee0000
VT7_WARP_HOOKS_ARMED
VT7_WARP_EVENT seq=1 kind=INIT_ENTRY checkpoint=1 tid=101 wrapper=0000000000300000 device=0000000000400000 mode=3 work=0000000000000000 pool=0000000000000000
VT7_WARP_INIT_RESULT success=1 wrapper=0000000000300000
VT7_WARP_EVENT seq=2 kind=INIT_RETURN checkpoint=1 tid=101 wrapper=0000000000300000 device=0000000000400000 mode=3 work=0000000000500000 pool=0000000000000000
VT7_WARP_EVENT seq=3 kind=CALLBACK checkpoint=1 tid=102 wrapper=0000000000300000 device=0000000000400000 mode=3 work=0000000000500000 pool=0000000000000000
'@
$ownershipEnd = @'
VT7_WARP_EVENT seq=4 kind=CLEANUP_ENTRY checkpoint=4 tid=101 wrapper=0000000000300000 device=0000000000400000 mode=3 work=0000000000500000 pool=0000000000000000
VT7_WARP_EVENT seq=5 kind=DRAIN_RETURN checkpoint=4 tid=101 wrapper=0000000000300000 device=0000000000400000 mode=3 work=0000000000500000 pool=0000000000000000
VT7_WARP_EVENT seq=6 kind=WORK_CLOSE_RETURN checkpoint=4 tid=101 wrapper=0000000000300000 device=0000000000400000 mode=3 work=0000000000500000 pool=0000000000000000
VT7_WARP_EVENT seq=7 kind=CLEANUP_RETURN checkpoint=4 tid=101 wrapper=0000000000300000 device=0000000000400000 mode=3 work=0000000000000000 pool=0000000000000000
VT7_WARP_FREE_RETURN checkpoint=4 tid=101 device=0000000000400000 wrapper=0000000000300000 success=1
'@
$snapshot = 'Handle tracing information snapshot successfully taken.'
$emptyDiff = $snapshot + "`n0x0 new stack traces since the previous snapshot.`nNo outstanding handles opened since the previous snapshot were detected."
$preflight = @"
SYNTHETIC UNIT FIXTURE, NOT TARGET EVIDENCE
VT7_TRACE_PREFLIGHT_BEGIN
$modules
0000000140001470 VT7_ResourceRetirement!VT7RetirementSample
0000000075001234 USER32!ClientThreadSetup
USER32!ClientThreadSetup:
VT7_TRACE_SAMPLE_ADDRESS=0000000140001470
VT7_TRACE_HOOK_ADDRESS=0000000075001234
VT7_TRACE_HTRACE_ENABLE_BEGIN
Handle tracing enabled.
$snapshot
$snapshot
$emptyDiff
3 Handles
Type             Count
Event            1
Token            1
TpWorkerFactory  1
Handle tracing disabled.
VT7_TRACE_PREFLIGHT_END
"@
$startup = @"
SYNTHETIC UNIT FIXTURE, NOT TARGET EVIDENCE
VT7_STARTUP_BEGIN version=0.1
VT7_EXCEPTION_POLICY_BEGIN
VT7_EXCEPTION_POLICY_END
$modules
$banner
VT7_STARTUP_READY phase=pre-warmup iteration=0 live=0 invalid_handles=0
$modules
VT7_STARTUP_END
"@
$builder = New-Object Text.StringBuilder
[void]$builder.AppendLine(@"
SYNTHETIC UNIT FIXTURE, NOT TARGET EVIDENCE
VT7_TRACE_BEGIN version=0.1 cycles=25 offline_symbols=1
VT7_EXCEPTION_POLICY_BEGIN
VT7_EXCEPTION_POLICY_END
$modules
VT7_TRACE_ARMED
VT7_SETUP event=1 checkpoint=0 pid=100 tid=101 teb=0000000000010000 ip=0000000075001234 sp=0000000000100000 return=0000000077001234
0000000000100000 0000000077001234 USER32!ClientThreadSetup
VT7_SETUP_END
$banner
"@)
$phases = @('pre-warmup', 'warmup-live', 'baseline-live', 'measured-live', 'final-closed', 'final-closed-10s', 'final-closed-90s', 'final-closed-180s')
$ticks = @(1000, 2000, 3000, 4000, 5000, 15010, 95020, 185030)
for ($index = 0; $index -lt 8; ++$index) {
    $sample = $index + 1
    $iteration = 0
    if ($sample -ge 4) { $iteration = 25 }
    $live = 0
    if ($sample -ge 2 -and $sample -le 4) { $live = 1 }
    if ($sample -eq 2) { [void]$builder.AppendLine($ownershipStart) }
    if ($sample -eq 5) { [void]$builder.AppendLine($ownershipEnd) }
    if ($sample -ge 6) {
        $target = @(10000, 90000, 180000)[$sample - 6]
        $requested = @(10000, 80000, 90000)[$sample - 6]
        $waitBegin = $ticks[$index - 1] + 10
        $waitEnd = $waitBegin + $requested
        [void]$builder.AppendLine("IDLE_WAIT target_ms=$target requested_ms=$requested begin_ms=$waitBegin")
        [void]$builder.AppendLine("IDLE_WAIT_END target_ms=$target requested_ms=$requested begin_ms=$waitBegin end_ms=$waitEnd elapsed_ms=$requested")
    }
    [void]$builder.AppendLine("VT7_CHECKPOINT sample=$sample phase=$($phases[$index]) iteration=$iteration live=$live")
    if ($sample -eq 1) { [void]$builder.AppendLine("VT7_HTRACE_ACTIVATE_BEGIN`nHandle tracing enabled.`n$snapshot`nVT7_HTRACE_ACTIVATE_END") }
    if ($sample -eq 5) { [void]$builder.AppendLine('VT7_IDLE_TRACE_POLICY active=checkpoint_exit_only') }
    [void]$builder.AppendLine("VT7_HANDLES_BEGIN`n$inventory`nVT7_HANDLES_END")
    if ($sample -eq 3) { [void]$builder.AppendLine("VT7_HTRACE_BASELINE_BEGIN`n$modules`n$snapshot`nVT7_HTRACE_BASELINE_END") }
    if ($sample -ge 4) {
        $name = @('25', 'CLOSED', 'CLOSED10', 'CLOSED90', 'CLOSED180')[$sample - 4]
        [void]$builder.AppendLine("VT7_HTRACE_$($name)_BEGIN`n$emptyDiff`nVT7_HTRACE_$($name)_END")
        if ($sample -lt 8) {
            $postName = @('POST25', 'POSTCLOSE', 'POSTCLOSE10', 'POSTCLOSE90')[$sample - 4]
            [void]$builder.AppendLine("$snapshot`nVT7_HTRACE_$($postName)_SNAPSHOT")
        }
    }
    if ($sample -eq 8) {
        [void]$builder.AppendLine(@'
VT7_HTRACE_HISTORY_BEGIN
Handle = 0x40 - OPEN
Thread ID = 0x65, Process ID = 0x64
0x0000000077611234: ntdll!NtCreateEvent
Handle = 0x40 - CLOSE
Thread ID = 0x65, Process ID = 0x64
0x0000000077615678: ntdll!NtClose
Parsed 0x2 stack traces.
Dumped 0x2 stack traces.
VT7_HTRACE_HISTORY_END
'@)
        [void]$builder.AppendLine("VT7_MODULES_BEGIN`n$modules`nVT7_MODULES_END")
    }
    [void]$builder.AppendLine("RESOURCE sample=$sample phase=$($phases[$index]) iteration=$iteration live=$live private=10000 handles=3 GDI=1 USER=1 threads=1 begin_ms=$($ticks[$index]) end_ms=$($ticks[$index] + 1)")
    $observation = 'surviving'
    if ($sample -eq 1) { $observation = 'newly-observed' }
    [void]$builder.AppendLine("THREAD sample=$sample tid=101 creation=01DD438A92375DE4 identity_error=0 observation=$observation first_sample=1 queue=observed queue_error=0 first_queue_sample=1 alive_before=258 alive_after=258 origin=C:\Windows\System32\ntdll.dll offset=F8DE0 start=77708DE0 origin_status=00000000 module_error=0")
}
[void]$builder.AppendLine(@'
WORKLOAD iterations=27 creates=1 destroys=1 resizes=270 size_resets=27 hide_show=135 power_registrations=0 power_unregistrations=0 power_delivered=0
ATTRIBUTION samples=8 identities=1 identity_unavailable=0; queue_unavailable_is_not_queue_absent
COMPLETED: measurement only, not stability acceptance. No soak performed.
VT7_TRACE_EXIT status=0 checkpoints=8 setup_events=1 invalid_handles=0
Handle tracing disabled.
VT7_TRACE_END
'@)
$complete = $builder.ToString().Replace("`r", '')
$preflight = $preflight.Replace("`r", '') + "`n"
$startup = $startup.Replace("`r", '') + "`n"
$cases = @(
    @{ Name = 'synthetic-complete-preflight'; Kind = 'preflight'; Text = $preflight; Reject = $false },
    @{ Name = 'synthetic-complete-startup'; Kind = 'startup'; Text = $startup; Reject = $false },
    @{ Name = 'synthetic-complete-matched-shared-pool'; Kind = 'trace'; Text = $complete; Reject = $false; Target = 'SUPPORTED' },
    @{ Name = 'synthetic-nested-token-inventory'; Kind = 'inventory'; Text = $inventory; Reject = $false }
)
$unsupported = [regex]::Replace($complete, '(?m)^VT7_WARP_(?:EVENT|INIT_RESULT|FREE_RETURN|HOOKS_ARMED)[^\n]*\n', '')
$unsupported = $unsupported.Replace('status=MATCHED profile=win7-6.2.9200.22592', 'status=UNSUPPORTED profile=none').Replace('OS 6.1.7601 SP=1.0', 'OS 10.0.19045 SP=0.0')
$cases += @{ Name = 'synthetic-unsupported-collector-complete'; Kind = 'trace'; Text = $unsupported; Reject = $false; Target = 'UNSUPPORTED' }
$privatePool = $complete.Replace('mode=3 work=', 'mode=2 work=')
$privatePool = [regex]::Replace($privatePool, '(?m)^(VT7_WARP_EVENT .+ kind=(?:INIT_RETURN|CALLBACK|CLEANUP_ENTRY|DRAIN_RETURN|WORK_CLOSE_RETURN) .+ pool=)0000000000000000$', '${1}0000000000266460')
$privateClose = 'VT7_WARP_EVENT seq=7 kind=POOL_CLOSE_RETURN checkpoint=4 tid=101 wrapper=0000000000300000 device=0000000000400000 mode=2 work=0000000000000000 pool=0000000000266460'
$privatePool = Replace-RetirementFixture $privatePool '(?m)^VT7_WARP_EVENT seq=7 kind=CLEANUP_RETURN ' ($privateClose + "`nVT7_WARP_EVENT seq=8 kind=CLEANUP_RETURN ")
$cases += @{ Name = 'synthetic-complete-matched-private-pool'; Kind = 'trace'; Text = $privatePool; Reject = $false; Target = 'SUPPORTED' }
$cases += @{ Name = 'private-pool-close-missing'; Kind = 'trace'; Text = (Replace-RetirementFixture $privatePool '(?m)^VT7_WARP_EVENT .+ kind=POOL_CLOSE_RETURN .+\n' ''); Reject = $true }
$cases += @{ Name = 'private-pool-close-wrong-owner'; Kind = 'trace'; Text = (Replace-RetirementFixture $privatePool '(?m)^(VT7_WARP_EVENT .+ kind=POOL_CLOSE_RETURN .+ pool=)[0-9a-f]+$' '${1}0000000000266470'); Reject = $true }

$reappeared = Replace-RetirementFixture $complete '(?m)^THREAD sample=2 .+$' 'THREAD sample=2 tid=102 creation=01DD438A92375DE5 identity_error=0 observation=newly-observed first_sample=2 queue=observed queue_error=0 first_queue_sample=2 alive_before=258 alive_after=258 origin=C:\Windows\System32\ntdll.dll offset=F8DE0 start=77708DE0 origin_status=00000000 module_error=0'
$reappeared = Replace-RetirementFixture $reappeared '(?m)^(THREAD sample=2 .+\n)' ('$1' + "NOT_OBSERVED sample=2 tid=101 creation=01DD438A92375DE4 previous_sample=1; absence_from_snapshot_not_complete_exit_history`n")
$reappeared = Replace-RetirementFixture $reappeared '(?m)^(THREAD sample=3 .+) observation=surviving ' '${1} observation=seen-earlier '
$reappeared = Replace-RetirementFixture $reappeared '(?m)^(THREAD sample=3 .+\n)' ('$1' + "NOT_OBSERVED sample=3 tid=102 creation=01DD438A92375DE5 previous_sample=2; absence_from_snapshot_not_complete_exit_history`n")
$reappeared = $reappeared.Replace('ATTRIBUTION samples=8 identities=1 ', 'ATTRIBUTION samples=8 identities=2 ')
$cases += @{ Name = 'identity-absence-and-reappearance'; Kind = 'trace'; Text = $reappeared; Reject = $false }
$cases += @{ Name = 'identity-missing-absence'; Kind = 'trace'; Text = (Replace-RetirementFixture $reappeared '(?m)^NOT_OBSERVED sample=2 .+\n' ''); Reject = $true }
$cases += @{ Name = 'identity-absence-is-not-exit-history'; Kind = 'trace'; Text = (Replace-RetirementFixture $reappeared '(?m)^NOT_OBSERVED sample=2 .+$' 'NOT_OBSERVED sample=2 tid=101 creation=01DD438A92375DE4 previous_sample=1; thread_exited'); Reject = $true }
$cases += @{ Name = 'identity-reappearance-is-not-survival'; Kind = 'trace'; Text = (Replace-RetirementFixture $reappeared '(?m)^(THREAD sample=3 .+) observation=seen-earlier ' '${1} observation=surviving '); Reject = $true }

$exception = @'
VT7_INVALID_HANDLE event=1 checkpoint=0 pid=100 tid=101
Last event: 64.65: Invalid handle - code c0000008 (first chance)
ExceptionAddress: 0000000077611000 (ntdll!KiRaiseUserExceptionDispatcher)
   ExceptionCode: c0000008 (Invalid handle)
  ExceptionFlags: 00000000
NumberParameters: 0
rip=0000000077611000 rsp=000000000012ff00 rbp=000000000012ff80
Child-SP          RetAddr           Call Site
000000000012ff00 0000000140001000 ntdll!KiRaiseUserExceptionDispatcher
0000000140000000 0000000140020000 VT7_ResourceRetirement (private pdb symbols)
0000000077610000 00000000777af000 ntdll (export symbols)
VT7_INVALID_HANDLE_END
VT7_INVALID_HANDLE_DISPATCH
'@
$withException = Replace-RetirementFixture $complete '(?m)^VT7_TRACE_ARMED\n' ("VT7_TRACE_ARMED`n" + $exception + "`n")
$withException = Replace-RetirementFixture $withException '(?m)^(VT7_TRACE_EXIT .+) invalid_handles=0$' '${1} invalid_handles=1'
$cases += @{ Name = 'synthetic-dispatched-first-chance-before-idle'; Kind = 'trace'; Text = $withException; Reject = $false }
foreach ($mutation in @(
    @{ Name = 'missing-dispatch'; Pattern = '(?m)^VT7_INVALID_HANDLE_DISPATCH\n'; Replacement = '' },
    @{ Name = 'missing-context'; Pattern = '(?m)^\s*ExceptionCode:.+\n'; Replacement = '' },
    @{ Name = 'wrong-code'; Pattern = '(?im)^(\s*ExceptionCode:\s*)c0000008'; Replacement = '${1}c0000005' },
    @{ Name = 'second-chance'; Pattern = '(?m)^(Last event:.+)\(first chance\)'; Replacement = '${1}(!!! second chance !!!)' },
    @{ Name = 'wrong-pid'; Pattern = '(?m)^(VT7_INVALID_HANDLE .+) pid=100 '; Replacement = '${1} pid=999 ' },
    @{ Name = 'wrong-tid'; Pattern = '(?m)^(VT7_INVALID_HANDLE .+) tid=101$'; Replacement = '${1} tid=999' },
    @{ Name = 'wrong-sequence'; Pattern = '(?m)^VT7_INVALID_HANDLE event=1 '; Replacement = 'VT7_INVALID_HANDLE event=2 ' },
    @{ Name = 'wrong-checkpoint'; Pattern = '(?m)^(VT7_INVALID_HANDLE .+) checkpoint=0 '; Replacement = '${1} checkpoint=5 ' },
    @{ Name = 'missing-registers'; Pattern = '(?m)^rip=.+\n'; Replacement = '' },
    @{ Name = 'unmatched-exit-counter'; Pattern = '(?m)^(VT7_TRACE_EXIT .+) invalid_handles=1$'; Replacement = '${1} invalid_handles=0' },
    @{ Name = 'limit'; Pattern = '(?m)^(VT7_TRACE_EXIT .+) invalid_handles=1$'; Replacement = '${1} invalid_handles=16' }
)) {
    $cases += @{ Name = ('exception-' + $mutation.Name); Kind = 'trace'; Text = (Replace-RetirementFixture $withException $mutation.Pattern $mutation.Replacement); Reject = $true }
}
$startupException = Replace-RetirementFixture $startup '(?m)^VT7_EXCEPTION_POLICY_END\n' ("VT7_EXCEPTION_POLICY_END`n" + $exception + "`n")
$startupException = Replace-RetirementFixture $startupException '(?m)^(VT7_STARTUP_READY .+) invalid_handles=0$' '${1} invalid_handles=1'
$cases += @{ Name = 'startup-dispatched-first-chance'; Kind = 'startup'; Text = $startupException; Reject = $false }
$cases += @{ Name = 'startup-exception-missing-dispatch'; Kind = 'startup'; Text = (Replace-RetirementFixture $startupException '(?m)^VT7_INVALID_HANDLE_DISPATCH\n' ''); Reject = $true }

$history = @'
Handle tracing information snapshot successfully taken.
0x1 new stack traces since the previous snapshot.
Ignoring handles that were already closed...
Outstanding handles opened since the previous snapshot:
Handle = 0x40 - OPEN
Thread ID = 0x65, Process ID = 0x64
0x0000000077611234: ntdll!NtCreateEvent
Displayed 0x1 stack traces for outstanding handles opened since the previous snapshot.
'@
$cases += @{ Name = 'nonempty-user-history'; Kind = 'diff'; Text = $history; Reject = $false }
$cases += @{ Name = 'nonempty-missing-owner'; Kind = 'diff'; Text = (Replace-RetirementFixture $history '(?m)^Thread ID = .+\n' ''); Reject = $true }
$cases += @{ Name = 'nonempty-missing-stack'; Kind = 'diff'; Text = (Replace-RetirementFixture $history '(?m)^0x[0-9a-f]+: .+\n' ''); Reject = $true }
$cases += @{ Name = 'nonempty-wrong-count'; Kind = 'diff'; Text = ($history.Replace('Displayed 0x1 ', 'Displayed 0x2 ')); Reject = $true }
$kernelHistory = Replace-RetirementFixture $history '(?m)^0x[0-9a-f]+: .+\n' ''
$kernelHistory = $kernelHistory.Replace('Process ID = 0x64', 'Process ID = 0x4')
$cases += @{ Name = 'kernel-history-stack-unavailable'; Kind = 'diff'; Text = $kernelHistory; Reject = $false }
$fullHistory = (Get-VT7RetirementMatch $complete '(?ms)^VT7_HTRACE_HISTORY_BEGIN\n(?<body>.*?)^VT7_HTRACE_HISTORY_END$').Groups['body'].Value
$cases += @{ Name = 'full-history-open-and-close'; Kind = 'history'; Text = $fullHistory; Reject = $false }
$cases += @{ Name = 'full-history-missing-close-entry'; Kind = 'history'; Text = (Replace-RetirementFixture $fullHistory '(?m)^Handle = 0x40 - CLOSE\n' ''); Reject = $true }
$cases += @{ Name = 'full-history-missing-owner'; Kind = 'history'; Text = (Replace-RetirementFixture $fullHistory '(?m)^Thread ID = .+\n' ''); Reject = $true }
$cases += @{ Name = 'full-history-missing-stack'; Kind = 'history'; Text = (Replace-RetirementFixture $fullHistory '(?m)^0x[0-9a-f]+: .+\n' ''); Reject = $true }
$cases += @{ Name = 'full-history-capacity'; Kind = 'history'; Text = ($fullHistory.Replace('0x2 stack traces.', '0x10000 stack traces.')); Reject = $true }
$cases += @{ Name = 'full-history-truncated-dump'; Kind = 'history'; Text = ($fullHistory.Replace('Dumped 0x2 ', 'Dumped 0x1 ')); Reject = $true }
$cases += @{ Name = 'full-history-wrong-footer'; Kind = 'history'; Text = ($fullHistory.Replace('Parsed 0x2 ', 'Parsed 0x1 ')); Reject = $true }

foreach ($entry in @(@{ Path = $CompleteLog; Kind = 'trace' }, @{ Path = $PreflightLog; Kind = 'preflight' }, @{ Path = $StartupLog; Kind = 'startup' })) {
    if ($entry.Path) { $cases += @{ Name = ('supplied-complete-' + $entry.Kind); Kind = $entry.Kind; Text = [IO.File]::ReadAllText([IO.Path]::GetFullPath($entry.Path)); Reject = $false } }
}
if ($KnownInvalidLog) {
    foreach ($path in $KnownInvalidLog) { $cases += @{ Name = ('supplied-invalid-' + $cases.Count); Kind = 'trace'; Text = [IO.File]::ReadAllText([IO.Path]::GetFullPath($path)); Reject = $true } }
}

foreach ($marker in @('VT7_TRACE_ARMED', 'VT7_TRACE_END', 'VT7_EXCEPTION_POLICY_BEGIN', 'VT7_EXCEPTION_POLICY_END', 'VT7_HTRACE_ACTIVATE_BEGIN', 'VT7_HTRACE_ACTIVATE_END',
    'VT7_HTRACE_BASELINE_BEGIN', 'VT7_HTRACE_BASELINE_END', 'VT7_HTRACE_25_BEGIN', 'VT7_HTRACE_25_END', 'VT7_HTRACE_POST25_SNAPSHOT',
    'VT7_HTRACE_CLOSED_BEGIN', 'VT7_HTRACE_CLOSED_END', 'VT7_HTRACE_POSTCLOSE_SNAPSHOT', 'VT7_HTRACE_CLOSED10_BEGIN', 'VT7_HTRACE_CLOSED10_END', 'VT7_HTRACE_POSTCLOSE10_SNAPSHOT',
    'VT7_HTRACE_CLOSED90_BEGIN', 'VT7_HTRACE_CLOSED90_END', 'VT7_HTRACE_POSTCLOSE90_SNAPSHOT', 'VT7_HTRACE_CLOSED180_BEGIN', 'VT7_HTRACE_CLOSED180_END', 'VT7_HTRACE_HISTORY_BEGIN', 'VT7_HTRACE_HISTORY_END', 'VT7_MODULES_BEGIN', 'VT7_MODULES_END', 'VT7_WARP_HOOKS_ARMED')) {
    $cases += @{ Name = ('missing-' + $marker); Kind = 'trace'; Text = (Replace-RetirementFixture $complete ('(?m)^' + $marker + '\n') ''); Reject = $true }
}
foreach ($sample in @(1, 2, 3, 4, 5, 6, 7, 8)) {
    foreach ($prefix in @('VT7_CHECKPOINT', 'RESOURCE', 'THREAD')) {
        $cases += @{ Name = ('missing-' + $prefix + '-' + $sample); Kind = 'trace'; Text = (Replace-RetirementFixture $complete ('(?m)^' + $prefix + ' sample=' + $sample + ' .+\n') ''); Reject = $true }
    }
}
foreach ($mutation in @(
    @{ Name = 'wrong-version'; Pattern = '(?m)^VT7_TRACE_BEGIN version=0\.1 '; Replacement = 'VT7_TRACE_BEGIN version=0.3 ' },
    @{ Name = 'nonzero-exit'; Pattern = '(?m)^VT7_TRACE_EXIT status=0 '; Replacement = 'VT7_TRACE_EXIT status=1 ' },
    @{ Name = 'wrong-exit-checkpoint-count'; Pattern = '(?m)^(VT7_TRACE_EXIT .+) checkpoints=8 '; Replacement = '${1} checkpoints=6 ' },
    @{ Name = 'wrong-workload'; Pattern = '(?m)^(WORKLOAD .+) destroys=1 '; Replacement = '${1} destroys=0 ' },
    @{ Name = 'wrong-native-abi'; Pattern = '(?m)^NATIVE 0\.3\.5 ABI=8 '; Replacement = 'NATIVE 0.3.5 ABI=7 ' },
    @{ Name = 'first-seen-changed'; Pattern = '(?m)^(THREAD sample=2 .+) first_sample=1 '; Replacement = '${1} first_sample=2 ' },
    @{ Name = 'queue-unbracketed'; Pattern = '(?m)^(THREAD sample=3 .+) alive_after=258 '; Replacement = '${1} alive_after=0 ' },
    @{ Name = 'queue-error-hidden'; Pattern = '(?m)^(THREAD sample=3 .+) queue_error=0 '; Replacement = '${1} queue_error=5 ' },
    @{ Name = 'identity-error-hidden'; Pattern = '(?m)^(THREAD sample=3 .+) identity_error=0 '; Replacement = '${1} identity_error=5 ' },
    @{ Name = 'queue-first-sample-changed'; Pattern = '(?m)^(THREAD sample=3 .+) first_queue_sample=1 '; Replacement = '${1} first_queue_sample=3 ' },
    @{ Name = 'wrong-setup-return'; Pattern = '(?m)^(VT7_SETUP .+) return=[0-9a-f]+$'; Replacement = '${1} return=0000000000000000' },
    @{ Name = 'wrong-setup-pid'; Pattern = '(?m)^(VT7_SETUP .+) pid=100 '; Replacement = '${1} pid=999 ' },
    @{ Name = 'missing-snapshot'; Pattern = '(?m)^Handle tracing information snapshot successfully taken\.\n'; Replacement = '' },
    @{ Name = 'missing-diff-result'; Pattern = '(?m)^No outstanding handles opened since the previous snapshot were detected\.\n'; Replacement = '' },
    @{ Name = 'missing-idle-policy'; Pattern = '(?m)^VT7_IDLE_TRACE_POLICY .+\n'; Replacement = '' },
    @{ Name = 'missing-retirement-config'; Pattern = '(?m)^RETIREMENT .+\n'; Replacement = '' },
    @{ Name = 'wrong-matched-os'; Pattern = '(?m)^OS 6\.1\.7601 SP=1\.0 '; Replacement = 'OS 10.0.19045 SP=0.0 ' },
    @{ Name = 'missing-profile'; Pattern = '(?m)^VT7_WARP_PROFILE .+\n'; Replacement = '' },
    @{ Name = 'zero-profile-base'; Pattern = '(?m)^(VT7_WARP_PROFILE .+) base=.+$'; Replacement = '${1} base=0000000000000000' },
    @{ Name = 'profile-contradiction'; Pattern = '(?m)^VT7_WARP_PROFILE status=MATCHED '; Replacement = 'VT7_WARP_PROFILE status=UNSUPPORTED ' }
)) {
    $cases += @{ Name = $mutation.Name; Kind = 'trace'; Text = (Replace-RetirementFixture $complete $mutation.Pattern $mutation.Replacement); Reject = $true }
}
foreach ($kind in @('INIT_ENTRY', 'INIT_RETURN', 'CALLBACK', 'CLEANUP_ENTRY', 'DRAIN_RETURN', 'WORK_CLOSE_RETURN', 'CLEANUP_RETURN')) {
    $cases += @{ Name = ('missing-ownership-' + $kind); Kind = 'trace'; Text = (Replace-RetirementFixture $complete ('(?m)^VT7_WARP_EVENT .+ kind=' + $kind + ' .+\n') ''); Reject = $true }
}
foreach ($mutation in @(
    @{ Name = 'wrong-wrapper'; Pattern = '(?m)^(VT7_WARP_EVENT .+ kind=CALLBACK .+ wrapper=)[0-9a-f]+ '; Replacement = '${1}0000000000300010 ' },
    @{ Name = 'wrong-device'; Pattern = '(?m)^(VT7_WARP_EVENT .+ kind=CALLBACK .+ device=)[0-9a-f]+ '; Replacement = '${1}0000000000400010 ' },
    @{ Name = 'wrong-work'; Pattern = '(?m)^(VT7_WARP_EVENT .+ kind=CALLBACK .+ work=)[0-9a-f]+ '; Replacement = '${1}0000000000500010 ' },
    @{ Name = 'wrong-mode'; Pattern = '(?m)^(VT7_WARP_EVENT .+ kind=CALLBACK .+) mode=3 '; Replacement = '${1} mode=2 ' },
    @{ Name = 'wrong-checkpoint'; Pattern = '(?m)^(VT7_WARP_EVENT .+ kind=CALLBACK) checkpoint=1 '; Replacement = '${1} checkpoint=2 ' },
    @{ Name = 'zero-work'; Pattern = '(?m)^(VT7_WARP_EVENT .+ kind=INIT_RETURN .+ work=)[0-9a-f]+ '; Replacement = '${1}0000000000000000 ' },
    @{ Name = 'uncleared-work'; Pattern = '(?m)^(VT7_WARP_EVENT .+ kind=CLEANUP_RETURN .+ work=)[0-9a-f]+ '; Replacement = '${1}0000000000500000 ' },
    @{ Name = 'unexpected-pool'; Pattern = '(?m)^(VT7_WARP_EVENT .+ kind=INIT_RETURN .+ pool=)[0-9a-f]+$'; Replacement = '${1}0000000000266460' },
    @{ Name = 'failed-initialization'; Pattern = '(?m)^VT7_WARP_INIT_RESULT success=1 '; Replacement = 'VT7_WARP_INIT_RESULT success=0 ' },
    @{ Name = 'missing-init-result'; Pattern = '(?m)^VT7_WARP_INIT_RESULT .+\n'; Replacement = '' },
    @{ Name = 'failed-free'; Pattern = '(?m)^(VT7_WARP_FREE_RETURN .+) success=1$'; Replacement = '${1} success=0' },
    @{ Name = 'wrong-free-owner'; Pattern = '(?m)^(VT7_WARP_FREE_RETURN .+ wrapper=)[0-9a-f]+ '; Replacement = '${1}0000000000300010 ' },
    @{ Name = 'missing-free'; Pattern = '(?m)^VT7_WARP_FREE_RETURN .+\n'; Replacement = '' }
)) {
    $cases += @{ Name = ('ownership-' + $mutation.Name); Kind = 'trace'; Text = (Replace-RetirementFixture $complete $mutation.Pattern $mutation.Replacement); Reject = $true }
}
foreach ($target in @(10000, 90000, 180000)) {
    foreach ($prefix in @('IDLE_WAIT', 'IDLE_WAIT_END')) {
        $cases += @{ Name = ('missing-' + $prefix + '-' + $target); Kind = 'trace'; Text = (Replace-RetirementFixture $complete ('(?m)^' + $prefix + ' target_ms=' + $target + ' .+\n') ''); Reject = $true }
    }
    $cases += @{ Name = ('idle-wrong-elapsed-' + $target); Kind = 'trace'; Text = (Replace-RetirementFixture $complete ('(?m)^(IDLE_WAIT_END target_ms=' + $target + ' .+) elapsed_ms=[0-9]+$') '${1} elapsed_ms=1'); Reject = $true }
    $cases += @{ Name = ('idle-wrong-requested-' + $target); Kind = 'trace'; Text = (Replace-RetirementFixture $complete ('(?m)^(IDLE_WAIT target_ms=' + $target + ') requested_ms=[0-9]+ ') '${1} requested_ms=1 '); Reject = $true }
}
$idleCallback = [regex]::Match($complete, '(?m)^VT7_WARP_EVENT .+ kind=CALLBACK .+$').Value
$cases += @{ Name = 'callback-during-idle'; Kind = 'trace'; Text = (Replace-RetirementFixture $complete '(?m)^(IDLE_WAIT target_ms=90000 .+\n)' ('$1' + $idleCallback + "`n")); Reject = $true }
$cases += @{ Name = 'unsupported-cannot-use-private-offsets'; Kind = 'trace'; Text = ($unsupported + $idleCallback + "`n"); Reject = $true }
foreach ($errorLine in @('FAIL operation=fixture', 'INCOMPLETE: fixture', 'VT7_TRACE_TRUNCATED_SETUP', 'VT7_TRACE_ABORT_WARP_LIMIT', 'VT7_TRACE_ABORT_INVALID_HANDLE_SECOND', 'VT7_TRACE_ABORT_IDLE_EXCEPTION', 'VT7_TRACE_ABORT_UNEXPECTED_STOP',
    'Syntax error in fixture', 'Unable to resolve breakpoint at fixture', 'Could not find handle 0x1234', 'Memory access error at fixture', 'The difference between the two snapshots is too large.',
    'Handle tracing information is not available', '(1234.5678): Invalid handle - code c0000008 (!!! second chance !!!)', '0:000> ')) {
    $cases += @{ Name = ('error-' + $cases.Count); Kind = 'trace'; Text = ($complete + "`n" + $errorLine + "`n"); Reject = $true }
}
foreach ($marker in @('VT7_TRACE_PREFLIGHT_BEGIN', 'VT7_TRACE_PREFLIGHT_END', 'VT7_TRACE_HTRACE_ENABLE_BEGIN', 'VT7_TRACE_SAMPLE_ADDRESS', 'VT7_TRACE_HOOK_ADDRESS')) {
    $cases += @{ Name = ('preflight-missing-' + $marker); Kind = 'preflight'; Text = (Replace-RetirementFixture $preflight ('(?m)^' + $marker + '[^\n]*\n') ''); Reject = $true }
}
$cases += @{ Name = 'preflight-wrong-export-address'; Kind = 'preflight'; Text = (Replace-RetirementFixture $preflight '(?m)^VT7_TRACE_SAMPLE_ADDRESS=.+$' 'VT7_TRACE_SAMPLE_ADDRESS=0000000140001480'); Reject = $true }
$cases += @{ Name = 'preflight-export-outside-module'; Kind = 'preflight'; Text = ($preflight.Replace('0000000140001470', '0000000150001470')); Reject = $true }
foreach ($marker in @('VT7_STARTUP_BEGIN', 'VT7_STARTUP_READY', 'VT7_STARTUP_END', 'VT7_EXCEPTION_POLICY_BEGIN', 'VT7_EXCEPTION_POLICY_END', 'RETIREMENT')) {
    $cases += @{ Name = ('startup-missing-' + $marker); Kind = 'startup'; Text = (Replace-RetirementFixture $startup ('(?m)^' + $marker + '[^\n]*\n') ''); Reject = $true }
}
foreach ($activity in @('VT7_WARP_PROFILE status=UNSUPPORTED profile=none base=1', 'IDLE_WAIT target_ms=10000 requested_ms=10000 begin_ms=1', 'RESOURCE sample=1', 'Handle tracing enabled.', '0:000> ')) {
    $cases += @{ Name = ('startup-forbidden-' + $cases.Count); Kind = 'startup'; Text = ($startup + "`n" + $activity + "`n"); Reject = $true }
}
$cases += @{ Name = 'inventory-nested-type-cannot-replace-object-type'; Kind = 'inventory'; Text = (Replace-RetirementFixture $inventory '(?m)^  Type[ ]+Token\n' ''); Reject = $true }
$cases += @{ Name = 'inventory-duplicate-object-type'; Kind = 'inventory'; Text = (Replace-RetirementFixture $inventory '(?m)^  Type[ ]+Token\n' "  Type Token`n  Type Token`n"); Reject = $true }
$cases += @{ Name = 'inventory-wrong-per-type-counts'; Kind = 'inventory'; Text = ($inventory.Replace('Event            1', 'Event            2').Replace('Token            1', 'Token            0')); Reject = $true }
$cases += @{ Name = 'inventory-unknown-type'; Kind = 'inventory'; Text = (Replace-RetirementFixture $inventory '(?m)^  Type[ ]+Token$' '  Type Unknown'); Reject = $true }
$cases += @{ Name = 'trace-truncated'; Kind = 'trace'; Text = $complete.Substring(0, [int]($complete.Length / 2)); Reject = $true }

$failed = 0
foreach ($case in $cases) {
    $rejected = $false
    $reason = ''
    try {
        $output = @(& {
            if ($case.Kind -eq 'preflight') { Assert-VT7RetirementPreflight $case.Text }
            elseif ($case.Kind -eq 'startup') { Assert-VT7RetirementStartup $case.Text }
            elseif ($case.Kind -eq 'inventory') { Assert-VT7RetirementHandleInventory ($case.Text.Replace("`r", '')) $true }
            elseif ($case.Kind -eq 'diff') { Assert-VT7RetirementNoErrors $case.Text; Assert-VT7RetirementHtraceDiff ($case.Text.Replace("`r", '')) }
            elseif ($case.Kind -eq 'history') { Assert-VT7RetirementNoErrors $case.Text; Assert-VT7RetirementHtraceHistory ($case.Text.Replace("`r", '')) }
            else { Assert-VT7ResourceRetirement $case.Text }
        })
        if ($output.Count -ne 0) { throw 'Validator emitted unexpected output.' }
        if ($case.Target -and (Get-VT7RetirementTargetStatus $case.Text) -ne $case.Target) { throw 'Collection completeness was confused with target evidence qualification.' }
    }
    catch { $rejected = $true; $reason = $_.Exception.Message }
    if ($rejected -ne $case.Reject) { ++$failed; Write-Host "FAIL $($case.Name): expected_rejection=$($case.Reject) actual_rejection=$rejected $reason" }
    else { Write-Host "PASS $($case.Name)" }
}
Write-Host "Retirement validator fixture checks: $($cases.Count) cases, $failed failures. Synthetic fixtures are not target evidence. No diagnostic or debugger process was run."
if ($failed) { throw "$failed retirement validator fixture check(s) failed." }
