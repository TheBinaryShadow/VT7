# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Text-only fixture tests. No debugger or diagnostic process is launched.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$CompleteLog,
    [Parameter(Mandatory = $true)] [string]$PreflightLog,
    [string[]]$KnownInvalidLog,
    [string]$NonemptyHistoryLog,
    [string]$HandledExceptionLog,
    [string]$StartupLog
)
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..'))
. (Join-Path $repositoryRoot 'src\vt7\VT7.ResourceTrace\Validate-ResourceTrace.ps1')
$complete = [IO.File]::ReadAllText([IO.Path]::GetFullPath($CompleteLog)).Replace("`r", '')
$preflight = [IO.File]::ReadAllText([IO.Path]::GetFullPath($PreflightLog)).Replace("`r", '')
function Replace-TraceFixture {
    param([string]$Text, [string]$Pattern, [string]$Replacement)
    $expression = New-Object Text.RegularExpressions.Regex($Pattern)
    if (-not $expression.IsMatch($Text)) { throw "Fixture mutation did not match: $Pattern" }
    return $expression.Replace($Text, $Replacement, 1)
}
$cases = @(
    @{ Name = 'complete-preflight'; Kind = 'preflight'; Text = $preflight; Reject = $false },
    @{ Name = 'complete-trace'; Kind = 'trace'; Text = $complete; Reject = $false },
    @{ Name = 'expected-symbol-warnings'; Kind = 'trace'; Text = ($complete + "`n*** ERROR: Symbol file could not be found.  Defaulted to export symbols for C:\Windows\System32\USER32.dll - `n*** WARNING: Unable to verify checksum for VT7.ResourceLifetime.exe`n"); Reject = $false }
)
foreach ($marker in @('VT7_TRACE_PREFLIGHT_BEGIN', 'VT7_TRACE_PREFLIGHT_END', 'VT7_TRACE_HTRACE_ENABLE_BEGIN')) {
    $cases += @{ Name = ('preflight-missing-' + $marker); Kind = 'preflight'; Text = (Replace-TraceFixture $preflight ('(?m)^' + $marker + '\n') ''); Reject = $true }
}
$cases += @{ Name = 'preflight-missing-private-pdb'; Kind = 'preflight'; Text = ([regex]::Replace($preflight, '(?im)^.*VT7_ResourceLifetime\s+(?:[A-Z]\s+)?\(private pdb symbols\).*\n', '')); Reject = $true }
$cases += @{ Name = 'preflight-wrong-checkpoint-address'; Kind = 'preflight'; Text = (Replace-TraceFixture $preflight '(?m)^VT7_TRACE_SAMPLE_ADDRESS=.+$' 'VT7_TRACE_SAMPLE_ADDRESS=0000000000000000'); Reject = $true }
$cases += @{ Name = 'preflight-missing-hook-address'; Kind = 'preflight'; Text = (Replace-TraceFixture $preflight '(?m)^VT7_TRACE_HOOK_ADDRESS=.+\n' ''); Reject = $true }
$cases += @{ Name = 'preflight-htrace-enable-failed'; Kind = 'preflight'; Text = (Replace-TraceFixture $preflight '(?m)^Handle tracing enabled\.$' 'Unable to enable handle tracing.'); Reject = $true }
foreach ($marker in @('VT7_TRACE_ARMED', 'VT7_TRACE_END', 'VT7_HTRACE_BASELINE_BEGIN', 'VT7_HTRACE_BASELINE_END',
    'VT7_HTRACE_25_BEGIN', 'VT7_HTRACE_25_END', 'VT7_HTRACE_POST25_SNAPSHOT', 'VT7_HTRACE_CLOSED_BEGIN',
    'VT7_HTRACE_CLOSED_END', 'VT7_HTRACE_POSTCLOSE_SNAPSHOT', 'VT7_HTRACE_CLOSED10_BEGIN', 'VT7_HTRACE_CLOSED10_END',
    'VT7_MODULES_BEGIN', 'VT7_MODULES_END', 'VT7_EXCEPTION_POLICY_BEGIN', 'VT7_EXCEPTION_POLICY_END',
    'VT7_HTRACE_ACTIVATE_BEGIN', 'VT7_HTRACE_ACTIVATE_END')) {
    $cases += @{ Name = ('trace-missing-' + $marker); Kind = 'trace'; Text = (Replace-TraceFixture $complete ('(?m)^' + $marker + '\n?') ''); Reject = $true }
}
foreach ($sample in @(1, 2, 3, 4, 5, 6)) {
    $cases += @{ Name = ('trace-missing-checkpoint-' + $sample); Kind = 'trace'; Text = (Replace-TraceFixture $complete ('(?m)^VT7_CHECKPOINT sample=' + $sample + ' .+\n') ''); Reject = $true }
}
$cases += @{ Name = 'trace-malformed-workload'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^WORKLOAD .+$' 'WORKLOAD iterations=27 creates=1 destroys=0 resizes=270 size_resets=27 hide_show=135 power_registrations=0 power_unregistrations=0 power_delivered=0'); Reject = $true }
$cases += @{ Name = 'trace-nonzero-exit'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^VT7_TRACE_EXIT status=0 ' 'VT7_TRACE_EXIT status=1 '); Reject = $true }
$cases += @{ Name = 'trace-missing-native-output'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^NATIVE .+\n' ''); Reject = $true }
$cases += @{ Name = 'trace-missing-baseline-warp-module'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+D3D10Warp\s+[^\n]+\n' ''); Reject = $true }
$cases += @{ Name = 'trace-missing-resource-row'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^RESOURCE sample=4 .+\n' ''); Reject = $true }
$cases += @{ Name = 'trace-missing-thread-row'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^THREAD sample=3 .+\n' ''); Reject = $true }
$firstThread = [regex]::Match($complete, '(?m)^THREAD sample=1 .+$').Value
$cases += @{ Name = 'trace-duplicated-thread-row'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^THREAD sample=1 .+$' ($firstThread + "`n" + $firstThread)); Reject = $true }
$cases += @{ Name = 'trace-identity-continuity'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^(THREAD sample=2 .+ observation=surviving first_sample=)[0-9]+' '${1}99'); Reject = $true }
$cases += @{ Name = 'trace-missing-handle-entry'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^Handle [0-9a-fA-F`]+\n' ''); Reject = $true }
$cases += @{ Name = 'trace-missing-successful-snapshot'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^Handle tracing information snapshot successfully taken\.\n' ''); Reject = $true }
$cases += @{ Name = 'trace-missing-diff-result'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^(?:No outstanding handles opened since the previous snapshot were detected\.|Displayed 0x[0-9a-fA-F]+ stack traces for outstanding handles opened since the previous snapshot\.)\n' ''); Reject = $true }
$cases += @{ Name = 'trace-missing-setup-event'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^VT7_SETUP event=1 .+\n' ''); Reject = $true }
$cases += @{ Name = 'trace-incorrect-entry-stack'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^(VT7_SETUP event=1 .+ return=)[0-9a-fA-F`]+' '${1}0000000000000000'); Reject = $true }
$cases += @{ Name = 'trace-historic-version-rejected'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^VT7_TRACE_BEGIN version=0\.3 ' 'VT7_TRACE_BEGIN version=0.2 '); Reject = $true }
$activationFixture = (Get-VT7TraceMatch $complete '(?ms)^VT7_HTRACE_ACTIVATE_BEGIN\n.*?^VT7_HTRACE_ACTIVATE_END\n').Value
$withoutActivation = Replace-TraceFixture $complete '(?ms)^VT7_HTRACE_ACTIVATE_BEGIN\n.*?^VT7_HTRACE_ACTIVATE_END\n' ''
$cases += @{ Name = 'trace-activation-before-armed'; Kind = 'trace'; Text = (Replace-TraceFixture $withoutActivation '(?m)^VT7_TRACE_ARMED\n' ($activationFixture + "VT7_TRACE_ARMED`n")); Reject = $true }
$cases += @{ Name = 'trace-activation-at-second-checkpoint'; Kind = 'trace'; Text = (Replace-TraceFixture $withoutActivation '(?m)^(VT7_CHECKPOINT sample=2 .+\n)' ('$1' + $activationFixture)); Reject = $true }
$cases += @{ Name = 'trace-activation-after-first-resource'; Kind = 'trace'; Text = (Replace-TraceFixture $withoutActivation '(?m)^(RESOURCE sample=1 .+\n)' ('$1' + $activationFixture)); Reject = $true }
$cases += @{ Name = 'trace-duplicate-activation'; Kind = 'trace'; Text = ($complete + $activationFixture); Reject = $true }
$cases += @{ Name = 'trace-unexpected-prompt'; Kind = 'trace'; Text = ($complete + "`n0:000> `n"); Reject = $true }
$cases += @{ Name = 'trace-exception-limit'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^(VT7_TRACE_EXIT .+ invalid_handles=)[0-9]+' '${1}16'); Reject = $true }
$cases += @{ Name = 'trace-missing-exception-exit-counter'; Kind = 'trace'; Text = (Replace-TraceFixture $complete '(?m)^(VT7_TRACE_EXIT .+) invalid_handles=[0-9]+' '$1'); Reject = $true }
foreach ($abort in @('VT7_TRACE_ABORT_INVALID_HANDLE_LIMIT', 'VT7_TRACE_ABORT_INVALID_HANDLE_SECOND', 'VT7_TRACE_ABORT_UNEXPECTED_STOP')) {
    $cases += @{ Name = ('trace-abort-' + $abort); Kind = 'trace'; Text = ($complete + "`n" + $abort + "`n"); Reject = $true }
}

# A synthetic, explicitly labelled unit fixture exercises exception validation
# when the supplied real successful run had no invalid-handle notifications.
$episodeFixture = $complete
$invalidCount = [int][regex]::Match($complete, '(?m)^VT7_TRACE_EXIT .+ invalid_handles=([0-9]+)$').Groups[1].Value
if ($invalidCount -eq 0) {
    $pidDecimal = [uint32][regex]::Match($complete, '(?m)^VT7 RESOURCE LIFETIME .+; pid=([0-9]+)$').Groups[1].Value
    $tidDecimal = [uint32][regex]::Match($complete, '(?m)^THREAD sample=1 tid=([0-9]+) ').Groups[1].Value
    $pidHex = $pidDecimal.ToString('x')
    $tidHex = $tidDecimal.ToString('x')
    $synthetic = @"
VT7_INVALID_HANDLE event=1 checkpoint=0 pid=$pidDecimal tid=$tidDecimal
Last event: $pidHex.$tidHex`: Invalid handle - code c0000008 (first chance)
ExceptionAddress: 0000000180001000 (ntdll!KiRaiseUserExceptionDispatcher)
   ExceptionCode: c0000008 (Invalid handle)
  ExceptionFlags: 00000000
NumberParameters: 0
rax=0000000000000000 rbx=0000000000000000 rcx=0000000000000000
rip=0000000180001000 rsp=000000000012ff00 rbp=000000000012ff80
Child-SP          RetAddr           Call Site
000000000012ff00 0000000140001000 ntdll!KiRaiseUserExceptionDispatcher
start             end                 module name
0000000140000000 00000001401d9000 VT7_ResourceLifetime (private pdb symbols)
0000000180000000 0000000180100000 ntdll (export symbols)
VT7_INVALID_HANDLE_END
VT7_INVALID_HANDLE_DISPATCH
"@
    $episodeFixture = Replace-TraceFixture $complete '(?m)^VT7_TRACE_ARMED\n' ("VT7_TRACE_ARMED`n" + $synthetic + "`n")
    $episodeFixture = Replace-TraceFixture $episodeFixture '(?m)^(VT7_TRACE_EXIT .+ invalid_handles=)0$' '${1}1'
    $cases += @{ Name = 'synthetic-first-chance-complete'; Kind = 'trace'; Text = $episodeFixture; Reject = $false }
    if ($HandledExceptionLog) {
        # This is a synthetic combination, never evidence of an exception in VT7.
        # Keep the real fixture's debugger context format; adapt its process ID
        # and executable symbol alias to the enclosing normal VT7 trace.
        $handledText = [IO.File]::ReadAllText([IO.Path]::GetFullPath($HandledExceptionLog)).Replace("`r", '')
        $handled = Get-VT7TraceMatch $handledText '(?ms)^VT7_INVALID_HANDLE event=1 checkpoint=0 pid=[0-9]+ tid=[0-9]+\n.*?^VT7_INVALID_HANDLE_END\nVT7_INVALID_HANDLE_DISPATCH$'
        $context = Replace-TraceFixture $handled.Value '(?m)^(VT7_INVALID_HANDLE event=1 checkpoint=0 pid=)[0-9]+' ('${1}' + $pidDecimal)
        $context = Replace-TraceFixture $context '(?im)^(Last event:\s*)[0-9a-f]+(\.[0-9a-f]+:)' ('${1}' + $pidHex + '${2}')
        $context = $context.Replace('VT7TraceExceptionFixture', 'VT7_ResourceLifetime')
        $episodeFixture = Replace-TraceFixture $complete '(?m)^VT7_TRACE_ARMED\n' ("VT7_TRACE_ARMED`n" + $context + "`n")
        $episodeFixture = Replace-TraceFixture $episodeFixture '(?m)^(VT7_TRACE_EXIT .+ invalid_handles=)0$' '${1}1'
        $cases += @{ Name = 'synthetic-combination-with-real-fixture-exception-context'; Kind = 'trace'; Text = $episodeFixture; Reject = $false }
    }
}
foreach ($marker in @('VT7_INVALID_HANDLE_END', 'VT7_INVALID_HANDLE_DISPATCH')) {
    $cases += @{ Name = ('exception-missing-' + $marker); Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture ('(?m)^' + $marker + '\n') ''); Reject = $true }
}
$cases += @{ Name = 'exception-missing-context'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?m)^\s*ExceptionCode:.+\n' ''); Reject = $true }
$cases += @{ Name = 'exception-wrong-code'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?im)^(\s*ExceptionCode:\s*)c0000008' '${1}c0000005'); Reject = $true }
$cases += @{ Name = 'exception-second-chance'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?m)^(Last event:.+)\(first chance\)' '${1}(second chance)'); Reject = $true }
$cases += @{ Name = 'exception-sdk81-second-chance'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?m)^(Last event:.+)\(first chance\)' '${1}(!!! second chance !!!)'); Reject = $true }
$cases += @{ Name = 'exception-sdk81-raw-second-chance'; Kind = 'trace'; Text = ($complete + "`n(1234.5678): Invalid handle - code c0000008 (!!! second chance !!!)`n"); Reject = $true }
$cases += @{ Name = 'error-detector-sdk81-second-chance'; Kind = 'errors'; Text = '(1234.5678): Invalid handle - code c0000008 (!!! second chance !!!)'; Reject = $true }
$cases += @{ Name = 'error-detector-lastevent-second-chance'; Kind = 'errors'; Text = 'Last event: 1234.5678: Invalid handle - code c0000008 (!!! second chance !!!)'; Reject = $true }
$cases += @{ Name = 'exception-wrong-process'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?m)^(VT7_INVALID_HANDLE event=1 checkpoint=[0-6] pid=)[0-9]+' '${1}4294967295'); Reject = $true }
$cases += @{ Name = 'exception-wrong-thread'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?m)^(VT7_INVALID_HANDLE event=1 .+ tid=)[0-9]+' '${1}4294967295'); Reject = $true }
$cases += @{ Name = 'exception-wrong-event-sequence'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?m)^VT7_INVALID_HANDLE event=1 ' 'VT7_INVALID_HANDLE event=2 '); Reject = $true }
$cases += @{ Name = 'exception-wrong-checkpoint'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?m)^(VT7_INVALID_HANDLE event=1 checkpoint=)[0-6]' '${1}7'); Reject = $true }
$cases += @{ Name = 'exception-missing-registers'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?m)^rip=.+\n' ''); Reject = $true }
$cases += @{ Name = 'exception-missing-module-context'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?ms)(^VT7_INVALID_HANDLE event=1 .+?\n)[0-9a-fA-F`]+\s+[0-9a-fA-F`]+\s+ntdll\s+[^\n]+\n' '$1'); Reject = $true }
$cases += @{ Name = 'exception-unmatched-exit-counter'; Kind = 'trace'; Text = (Replace-TraceFixture $episodeFixture '(?m)^(VT7_TRACE_EXIT .+ invalid_handles=)[0-9]+' '${1}0'); Reject = $true }
$cases += @{ Name = 'exception-unrecorded-notification'; Kind = 'trace'; Text = ($complete + "`n(1234.5678): Invalid handle - code c0000008 (first chance)`n"); Reject = $true }
foreach ($errorLine in @('FAIL operation=fixture', 'INCOMPLETE: fixture', 'VT7_TRACE_TRUNCATED_SETUP',
    "              ^ Syntax error in '.version'", 'Unable to resolve breakpoint at VT7_ResourceLifetime+1470',
    'Could not find handle 0x1234', 'Unable to find handle 0x1234',
    'The difference between the two snapshots is too large.', 'Please start over with "!htrace -snapshot" then "!htrace -diff".')) {
    $cases += @{ Name = ('trace-error-' + $cases.Count); Kind = 'trace'; Text = ($complete + "`n" + $errorLine + "`n"); Reject = $true }
}
$cases += @{ Name = 'trace-truncated-file'; Kind = 'trace'; Text = $complete.Substring(0, [int]($complete.Length / 2)); Reject = $true }
foreach ($invalidLog in $KnownInvalidLog) {
    $cases += @{ Name = ('retained-invalid-actual-log-' + $cases.Count); Kind = 'trace'; Text = [IO.File]::ReadAllText([IO.Path]::GetFullPath($invalidLog)); Reject = $true }
}
$retainedWin7Abort = Join-Path $repositoryRoot 'artifacts\vt7\evidence\resource-trace-win7-0.2\resource-trace-20260913-160144-8a929ea8\trace-combined.log'
if (Test-Path -LiteralPath $retainedWin7Abort -PathType Leaf) {
    $win7Abort = [IO.File]::ReadAllText($retainedWin7Abort).Replace("`r", '')
    $cases += @{ Name = 'retained-win7-trace02-second-chance'; Kind = 'trace'; Text = $win7Abort; Reject = $true }
    $cases += @{ Name = 'retained-win7-trace02-without-abort-marker'; Kind = 'errors'; Text = (Replace-TraceFixture $win7Abort '(?m)^VT7_TRACE_ABORT_INVALID_HANDLE_SECOND\n' ''); Reject = $true }
}
$retainedWin7Inventory = Join-Path $repositoryRoot 'artifacts\vt7\evidence\resource-trace-win7-0.3\resource-trace-20260913-161711-9df20496\trace-combined.log'
if (Test-Path -LiteralPath $retainedWin7Inventory -PathType Leaf) {
    $inventoryText = [IO.File]::ReadAllText($retainedWin7Inventory).Replace("`r", '')
    $inventoryBlocks = [regex]::Matches($inventoryText, '(?ms)^VT7_HANDLES_BEGIN\n(?<body>.*?)^VT7_HANDLES_END$')
    $tokenInventory = $null
    foreach ($block in $inventoryBlocks) {
        if ([regex]::IsMatch($block.Groups['body'].Value, '(?m)^    Type[\t ]+Primary[\t ]*$')) {
            $tokenInventory = $block.Groups['body'].Value
            break
        }
    }
    if (-not $tokenInventory) { throw 'Retained Win7 inventory fixture lacks nested Token type metadata.' }
    $cases += @{ Name = 'real-win7-inventory-nested-token-type'; Kind = 'inventory'; Text = $tokenInventory; Reject = $false }
    $tokenTypePattern = '(?m)^  Type[\t ]+Token[\t ]*\n'
    $tokenTypeLine = (Get-VT7TraceMatch $tokenInventory $tokenTypePattern).Value
    $missingTokenType = Replace-TraceFixture $tokenInventory $tokenTypePattern ''
    $cases += @{ Name = 'inventory-missing-top-level-type-with-nested-type-present'; Kind = 'inventory'; Text = $missingTokenType; Reject = $true }
    $cases += @{ Name = 'inventory-duplicate-top-level-type'; Kind = 'inventory'; Text = (Replace-TraceFixture $tokenInventory $tokenTypePattern ($tokenTypeLine + $tokenTypeLine)); Reject = $true }
    $cases += @{ Name = 'inventory-wrong-known-object-type'; Kind = 'inventory'; Text = (Replace-TraceFixture $tokenInventory $tokenTypePattern "  Type         `tEvent`n"); Reject = $true }
    $cases += @{ Name = 'inventory-unknown-object-type'; Kind = 'inventory'; Text = (Replace-TraceFixture $tokenInventory $tokenTypePattern "  Type         `tNotARecordedType`n"); Reject = $true }
    $firstTypeLine = [regex]::Match($missingTokenType, '(?m)^  Type[\t ]+[^\n]+\n').Value
    $cases += @{ Name = 'inventory-missing-type-compensated-by-duplicate-elsewhere'; Kind = 'inventory'; Text = (Replace-TraceFixture $missingTokenType '(?m)^  Type[\t ]+[^\n]+\n' ($firstTypeLine + $firstTypeLine)); Reject = $true }
    $tableEvent = Get-VT7TraceMatch $tokenInventory '(?m)^Event[\t ]+(?<count>[0-9]+)[\t ]*$'
    $tableToken = Get-VT7TraceMatch $tokenInventory '(?m)^Token[\t ]+(?<count>[0-9]+)[\t ]*$'
    $wrongTotals = Replace-TraceFixture $tokenInventory '(?m)^Event[\t ]+[0-9]+[\t ]*$' ("Event`t" + ([int]$tableEvent.Groups['count'].Value - 1))
    $wrongTotals = Replace-TraceFixture $wrongTotals '(?m)^Token[\t ]+[0-9]+[\t ]*$' ("Token`t" + ([int]$tableToken.Groups['count'].Value + 1))
    $cases += @{ Name = 'inventory-per-type-totals-wrong-with-correct-overall-total'; Kind = 'inventory'; Text = $wrongTotals; Reject = $true }
}
$retainedWin10Inventory = Join-Path $repositoryRoot 'artifacts\resource-trace-0.3\Logs\resource-trace-20260913-161208-c026e689\trace-combined.log'
if (Test-Path -LiteralPath $retainedWin10Inventory -PathType Leaf) {
    $win10Text = [IO.File]::ReadAllText($retainedWin10Inventory).Replace("`r", '')
    $win10Inventory = [regex]::Match($win10Text, '(?ms)^VT7_HANDLES_BEGIN\n(?<body>.*?)^VT7_HANDLES_END$').Groups['body'].Value
    $cases += @{ Name = 'real-win10-old-sdk-irtimer-none-summary'; Kind = 'inventory'; Text = $win10Inventory; Reject = $false }
    $cases += @{ Name = 'inventory-none-bucket-does-not-accept-arbitrary-type'; Kind = 'inventory'; Text = (Replace-TraceFixture $win10Inventory '(?m)^  Type[\t ]+IRTimer[\t ]*$' "  Type`tNotARecordedType"); Reject = $true }
    $cases += @{ Name = 'inventory-none-bucket-does-not-hide-wrong-known-type'; Kind = 'inventory'; Text = (Replace-TraceFixture $win10Inventory '(?m)^  Type[\t ]+IRTimer[\t ]*$' "  Type`tEvent"); Reject = $true }
    $noneTotal = Get-VT7TraceMatch $win10Inventory '(?m)^None[\t ]+(?<count>[0-9]+)[\t ]*$'
    $eventTotal = Get-VT7TraceMatch $win10Inventory '(?m)^Event[\t ]+(?<count>[0-9]+)[\t ]*$'
    $wrongNone = Replace-TraceFixture $win10Inventory '(?m)^None[\t ]+[0-9]+[\t ]*$' ("None`t" + ([int]$noneTotal.Groups['count'].Value - 1))
    $wrongNone = Replace-TraceFixture $wrongNone '(?m)^Event[\t ]+[0-9]+[\t ]*$' ("Event`t" + ([int]$eventTotal.Groups['count'].Value + 1))
    $cases += @{ Name = 'inventory-none-bucket-count-must-match'; Kind = 'inventory'; Text = $wrongNone; Reject = $true }
}
if ($StartupLog) {
    $startup = [IO.File]::ReadAllText([IO.Path]::GetFullPath($StartupLog)).Replace("`r", '')
    $cases += @{ Name = 'complete-startup-control'; Kind = 'startup'; Text = $startup; Reject = $false }
    foreach ($marker in @('VT7_STARTUP_BEGIN', 'VT7_STARTUP_READY', 'VT7_STARTUP_END', 'VT7_EXCEPTION_POLICY_BEGIN', 'VT7_EXCEPTION_POLICY_END')) {
        $cases += @{ Name = ('startup-missing-' + $marker); Kind = 'startup'; Text = (Replace-TraceFixture $startup ('(?m)^' + $marker + '[^\n]*\n') ''); Reject = $true }
    }
    $cases += @{ Name = 'startup-wrong-version'; Kind = 'startup'; Text = (Replace-TraceFixture $startup '(?m)^VT7_STARTUP_BEGIN version=0\.3$' 'VT7_STARTUP_BEGIN version=0.2'); Reject = $true }
    $cases += @{ Name = 'startup-wrong-phase'; Kind = 'startup'; Text = (Replace-TraceFixture $startup '(?m)^VT7_STARTUP_READY phase=pre-warmup ' 'VT7_STARTUP_READY phase=warmup-live '); Reject = $true }
    $cases += @{ Name = 'startup-already-live'; Kind = 'startup'; Text = (Replace-TraceFixture $startup '(?m)^(VT7_STARTUP_READY .+) live=0 ' '${1} live=1 '); Reject = $true }
    $cases += @{ Name = 'startup-wrong-native-abi'; Kind = 'startup'; Text = (Replace-TraceFixture $startup '(?m)^NATIVE 0\.3\.5 ABI=8 ' 'NATIVE 0.3.5 ABI=7 '); Reject = $true }
    $cases += @{ Name = 'startup-missing-native-load'; Kind = 'startup'; Text = (Replace-TraceFixture $startup '(?im)^ModLoad:[^\n]+VT7\.Native\.dll\n' ''); Reject = $true }
    $cases += @{ Name = 'startup-missing-private-symbols'; Kind = 'startup'; Text = ([regex]::Replace($startup, '(?im)^.*VT7_ResourceLifetime\s+(?:[A-Z]\s+)?\(private pdb symbols\).*\n', '')); Reject = $true }
    $cases += @{ Name = 'startup-exception-limit'; Kind = 'startup'; Text = (Replace-TraceFixture $startup '(?m)^(VT7_STARTUP_READY .+ invalid_handles=)[0-9]+' '${1}16'); Reject = $true }
    $cases += @{ Name = 'startup-missing-exception-context'; Kind = 'startup'; Text = (Replace-TraceFixture $startup '(?m)^(VT7_STARTUP_READY .+ invalid_handles=)[0-9]+' '${1}15'); Reject = $true }
    $startupReady = (Get-VT7TraceMatch $startup '(?m)^VT7_STARTUP_READY .+$').Value
    $cases += @{ Name = 'startup-duplicate-ready'; Kind = 'startup'; Text = ($startup + "`n" + $startupReady); Reject = $true }
    foreach ($activity in @('VT7_SETUP event=1 checkpoint=0', 'VT7_CHECKPOINT sample=1', 'RESOURCE sample=1', 'THREAD sample=1', 'WORKLOAD iterations=1', 'Handle tracing enabled.', 'Handle tracing information snapshot successfully taken.', 'VT7_TRACE_ABORT_INVALID_HANDLE_SECOND', 'VT7_TRACE_ABORT_UNEXPECTED_STOP', '(1234.5678): Invalid handle - code c0000008 (!!! second chance !!!)', '0:000> ')) {
        $cases += @{ Name = ('startup-forbidden-activity-' + $cases.Count); Kind = 'startup'; Text = ($startup + "`n" + $activity + "`n"); Reject = $true }
    }
    if ($HandledExceptionLog -and [regex]::IsMatch($startup, '(?m)^VT7_STARTUP_READY .+ invalid_handles=0$')) {
        # Synthetic combination with real debugger context, not a VT7 observation.
        $startupPid = (Get-VT7TraceMatch $startup '(?m)^VT7 RESOURCE LIFETIME .+; pid=(?<pid>[1-9][0-9]*)$').Groups['pid'].Value
        $startupPidHex = ([uint32]$startupPid).ToString('x')
        $handledText = [IO.File]::ReadAllText([IO.Path]::GetFullPath($HandledExceptionLog)).Replace("`r", '')
        $handled = Get-VT7TraceMatch $handledText '(?ms)^VT7_INVALID_HANDLE event=1 checkpoint=0 pid=[0-9]+ tid=[0-9]+\n.*?^VT7_INVALID_HANDLE_END\nVT7_INVALID_HANDLE_DISPATCH$'
        $context = Replace-TraceFixture $handled.Value '(?m)^(VT7_INVALID_HANDLE event=1 checkpoint=0 pid=)[0-9]+' ('${1}' + $startupPid)
        $context = Replace-TraceFixture $context '(?im)^(Last event:\s*)[0-9a-f]+(\.[0-9a-f]+:)' ('${1}' + $startupPidHex + '${2}')
        $context = $context.Replace('VT7TraceExceptionFixture', 'VT7_ResourceLifetime')
        $startupException = Replace-TraceFixture $startup '(?m)^VT7_EXCEPTION_POLICY_END\n' ("VT7_EXCEPTION_POLICY_END`n" + $context + "`n")
        $startupException = Replace-TraceFixture $startupException '(?m)^(VT7_STARTUP_READY .+ invalid_handles=)0$' '${1}1'
        $cases += @{ Name = 'synthetic-startup-with-real-fixture-context'; Kind = 'startup'; Text = $startupException; Reject = $false }
        $cases += @{ Name = 'startup-exception-without-dispatch'; Kind = 'startup'; Text = (Replace-TraceFixture $startupException '(?m)^VT7_INVALID_HANDLE_DISPATCH\n' ''); Reject = $true }
        $cases += @{ Name = 'startup-exception-wrong-checkpoint'; Kind = 'startup'; Text = (Replace-TraceFixture $startupException '(?m)^(VT7_INVALID_HANDLE event=1 checkpoint=)0' '${1}1'); Reject = $true }
    }
}
if ($NonemptyHistoryLog) {
    $historyText = [IO.File]::ReadAllText([IO.Path]::GetFullPath($NonemptyHistoryLog)).Replace("`r", '')
    $historyMatches = [regex]::Matches($historyText, '(?ms)^Handle tracing information snapshot successfully taken\.\n0x[0-9a-fA-F]+ new stack traces since the previous snapshot\.\n.*?^Displayed 0x[0-9a-fA-F]+ stack traces for outstanding handles opened since the previous snapshot\.$')
    if ($historyMatches.Count -ne 1) { throw 'Expected one complete nonempty handle-history diff in the supplied fixture.' }
    $history = $historyMatches[0].Value
    $cases += @{ Name = 'nonempty-real-handle-histories'; Kind = 'diff'; Text = $history; Reject = $false }
    $cases += @{ Name = 'nonempty-missing-handle-entry'; Kind = 'diff'; Text = (Replace-TraceFixture $history '(?m)^Handle = .+\n' ''); Reject = $true }
    $cases += @{ Name = 'nonempty-wrong-displayed-count'; Kind = 'diff'; Text = (Replace-TraceFixture $history '(?m)^Displayed 0x[0-9a-fA-F]+' 'Displayed 0x0'); Reject = $true }
    $cases += @{ Name = 'nonempty-missing-thread-process'; Kind = 'diff'; Text = (Replace-TraceFixture $history '(?m)^Thread ID = .+\n' ''); Reject = $true }
    $cases += @{ Name = 'nonempty-missing-stack'; Kind = 'diff'; Text = (Replace-TraceFixture $history '(?m)(?:^0x[0-9a-fA-F]+: .+\n)+' ''); Reject = $true }
    $cases += @{ Name = 'nonempty-unknown-handle-history'; Kind = 'diff'; Text = ($history + "`nCould not find handle 0x1234`n"); Reject = $true }
}
$failed = 0
foreach ($case in $cases) {
    $rejected = $false
    $reason = ''
    try {
        $output = @(& {
            if ($case.Kind -eq 'preflight') { Assert-VT7TracePreflight $case.Text }
            elseif ($case.Kind -eq 'startup') { Assert-VT7StartupControl $case.Text }
            elseif ($case.Kind -eq 'errors') { Assert-VT7TraceNoErrors $case.Text }
            elseif ($case.Kind -eq 'inventory') { Assert-VT7TraceNoErrors $case.Text; Assert-VT7HandleInventory $case.Text $true }
            elseif ($case.Kind -eq 'diff') { Assert-VT7TraceNoErrors $case.Text; Assert-VT7HtraceDiff $case.Text }
            else { Assert-VT7ResourceTrace $case.Text }
        })
        if ($output.Count -ne 0) { throw 'Validator emitted unexpected output.' }
    }
    catch { $rejected = $true; $reason = $_.Exception.Message }
    if ($rejected -ne $case.Reject) {
        ++$failed
        Write-Host "FAIL $($case.Name): expected_rejection=$($case.Reject) actual_rejection=$rejected $reason"
    }
    else { Write-Host "PASS $($case.Name)" }
}
Write-Host "Trace validator fixture checks: $($cases.Count) cases, $failed failures. No diagnostic or debugger process was run."
if ($failed) { throw "$failed trace validator fixture check(s) failed." }
