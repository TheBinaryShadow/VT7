[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BuildDirectory,
    [Parameter(Mandatory = $true)][string]$NativeDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildRoot = [IO.Path]::GetFullPath($BuildDirectory)
$nativeRoot = [IO.Path]::GetFullPath($NativeDirectory)
$executablePath = Join-Path $buildRoot 'VT7.ResourceRetirement.exe'
$nativePath = Join-Path $nativeRoot 'VT7.Native.dll'
foreach ($path in @($executablePath, $nativePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required binary is missing: $path" }
}
if ((Get-FileHash -LiteralPath $nativePath -Algorithm SHA256).Hash -ne '0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49') {
    throw 'This qualification requires the unchanged issued native 0.3.5 DLL.'
}
$runId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff') + '-' + [Guid]::NewGuid().ToString('N')
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\diagnostics\resource-retirement-sampler-tests-$runId"
if (Test-Path -LiteralPath $reportRoot) { throw "Refusing to replace earlier test evidence: $reportRoot" }
New-Item -ItemType Directory -Path $reportRoot | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $reportRoot 'Test-VT7ResourceRetirementSampler.ps1')
# Native fixture fonts resolve beside the EXE, independently of current directory.
# Stage only a copied EXE and the unchanged assets in this fresh evidence directory.
$sourceExecutable = $executablePath
$executablePath = Join-Path $reportRoot 'VT7.ResourceRetirement.exe'
Copy-Item -LiteralPath $sourceExecutable -Destination $executablePath
if ((Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $sourceExecutable -Algorithm SHA256).Hash) {
    throw 'The staged executable differs from its build input.'
}
$fontRoot = Join-Path $nativeRoot 'fonts'
if (-not (Test-Path -LiteralPath $fontRoot -PathType Container)) { throw "Required native fixture fonts are missing: $fontRoot" }
Copy-Item -LiteralPath $fontRoot -Destination $reportRoot -Recurse
$summaryPath = Join-Path $reportRoot 'summary.txt'
[IO.File]::WriteAllLines($summaryPath, @(
    'VT7 resource retirement 0.1 sampler rejection-path qualification',
    "Executable SHA256: $((Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash)",
    "Native DLL SHA256: $((Get-FileHash -LiteralPath $nativePath -Algorithm SHA256).Hash)",
    'These negative cases do not shorten the issued waits. Successful eight-checkpoint collection is qualified separately with all 180 seconds.',
    'These checks do not establish resource-growth acceptance or Windows 7 execution.'
), $utf8)

function Assert-OneMarker {
    param([string]$Text, [string]$Pattern)
    if ([regex]::Matches($Text, $Pattern).Count -ne 1) { throw "Expected one marker: $Pattern" }
}

$cases = @(
    @{ Name = 'missing-arguments'; Args = @(); Operation = 'usage-native-dll-reuse' },
    @{ Name = 'recreate-rejected'; Args = @($nativePath, 'recreate'); Operation = 'usage-native-dll-reuse' },
    @{ Name = 'cycles-zero'; Args = @($nativePath, 'reuse', '--cycles', '0'); Operation = 'argument-range-1-to-100' },
    @{ Name = 'cycles-one'; Args = @($nativePath, 'reuse', '--cycles', '1'); Operation = 'retirement-requires-25-cycles' },
    @{ Name = 'cycles-26'; Args = @($nativePath, 'reuse', '--cycles', '26'); Operation = 'retirement-requires-25-cycles' },
    @{ Name = 'duplicate-cycles'; Args = @($nativePath, 'reuse', '--cycles', '25', '--cycles', '25'); Operation = 'unknown-or-duplicate-option' },
    @{ Name = 'missing-option-value'; Args = @($nativePath, 'reuse', '--cycles'); Operation = 'missing-option-value' },
    @{ Name = 'timing-override-rejected'; Args = @($nativePath, 'reuse', '--idle-ms', '1'); Operation = 'unknown-or-duplicate-option' },
    @{ Name = 'fail-cycle-out-of-range'; Args = @($nativePath, 'reuse', '--fail-at-cycle', '26'); Operation = 'failure-cycle-outside-workload' },
    @{ Name = 'relative-dll'; Args = @('VT7.Native.dll', 'reuse'); Operation = 'native-dll-must-be-absolute-drive-path' },
    @{ Name = 'missing-dll'; Args = @((Join-Path $reportRoot 'deliberately-missing-native.dll'), 'reuse'); Operation = 'load-native-dll' },
    @{ Name = 'wrong-dll'; Args = @((Join-Path $env:WINDIR 'System32\kernel32.dll'), 'reuse'); Operation = 'VT7_CreateSurface-export' },
    @{ Name = 'reuse-injected'; Args = @($nativePath, 'reuse', '--cycles', '25', '--fail-at-cycle', '1'); Operation = 'injected-workload-failure' }
)
$results = @()
foreach ($case in $cases) {
    $process = $null
    $failure = $null
    $stdoutPath = Join-Path $reportRoot ($case.Name + '.log')
    $stderrPath = Join-Path $reportRoot ($case.Name + '.stderr.log')
    try {
        $arguments = @($case.Args | ForEach-Object { '"' + $_ + '"' }) -join ' '
        $start = @{
            FilePath = $executablePath; WorkingDirectory = $nativeRoot; WindowStyle = 'Hidden'; PassThru = $true
            RedirectStandardOutput = $stdoutPath; RedirectStandardError = $stderrPath
        }
        if ($arguments.Length) { $start.ArgumentList = $arguments }
        $process = Start-Process @start
        $processHandle = $process.Handle
        if (-not $process.WaitForExit(30000)) { throw 'The owned negative-test child exceeded 30 seconds.' }
        $process.WaitForExit()
        $process.Refresh()
        if ($null -eq $process.ExitCode -or $process.ExitCode -ne 1) { throw "Expected rejection exit 1; found $($process.ExitCode)." }
        if ([IO.File]::ReadAllText($stderrPath).Trim().Length) { throw 'Unexpected stderr output.' }
        $text = [IO.File]::ReadAllText($stdoutPath)
        Assert-OneMarker $text ('(?m)^FAIL operation=' + [regex]::Escape($case.Operation) + ' hresult=[0-9A-F]{8}\r?$')
        Assert-OneMarker $text '(?m)^INCOMPLETE: preserve partial measurements; no resource acceptance\.\r?$'
        if ([regex]::Matches($text, '(?m)^FAIL ').Count -ne 1) { throw 'Expected exactly one failure marker.' }
        if ($text -match '(?m)^(COMPLETED:|WORKLOAD |ATTRIBUTION |IDLE_WAIT)') { throw 'Rejected run contains completed or idle-wait output.' }
        if ($case.Name -eq 'reuse-injected') {
            Assert-OneMarker $text '(?m)^VT7 RESOURCE RETIREMENT 0\.1;'
            Assert-OneMarker $text '(?m)^CONFIG mode=reuse renderer=2 capture=1 power=0 probes=0 warmup=2 cycles=25 fail_at_cycle=1\r?$'
            Assert-OneMarker $text '(?m)^NATIVE 0\.3\.5 ABI=8 Release '
            Assert-OneMarker $text '(?m)^CLEANUP destroy_surface_hresult=00000000\r?$'
            $samples = @([regex]::Matches($text, '(?m)^RESOURCE sample=([0-9]+) phase=(\S+) iteration=0 live=([01]) '))
            if ($samples.Count -ne 3 -or [regex]::Matches($text, '(?m)^RESOURCE ').Count -ne 3) { throw 'Expected exactly the three pre-measurement checkpoints before the injected failure.' }
            $phases = @('pre-warmup', 'warmup-live', 'baseline-live')
            $live = @('0', '1', '1')
            for ($i = 0; $i -lt 3; ++$i) {
                if ([int]$samples[$i].Groups[1].Value -ne $i + 1 -or $samples[$i].Groups[2].Value -ne $phases[$i] -or $samples[$i].Groups[3].Value -ne $live[$i]) {
                    throw 'Incorrect pre-measurement phase order or live flag.'
                }
            }
        }
        elseif ($text -match '(?m)^(CLEANUP |RESOURCE )') { throw 'Unexpected live-surface or sampler output in an early rejection.' }
    }
    catch { $failure = $_.Exception.Message }
    finally {
        if ($null -ne $process) {
            try {
                if (-not $process.HasExited) {
                    $process.Kill()
                    if (-not $process.WaitForExit(5000)) { throw 'The owned child did not exit after termination.' }
                    $process.WaitForExit()
                }
            }
            finally { $process.Dispose() }
        }
    }
    $result = [ordered]@{ Name = $case.Name; Arguments = $case.Args; ExpectedOperation = $case.Operation; Passed = ($null -eq $failure); Failure = $failure }
    $results += $result
    $message = if ($failure) { "FAIL $($case.Name): $failure" } else { "PASS $($case.Name)" }
    [IO.File]::AppendAllText($summaryPath, $message + [Environment]::NewLine, $utf8)
    Write-Host $message
}
$failures = @($results | Where-Object { -not $_.Passed }).Count
$record = [ordered]@{
    Diagnostic = 'VT7.ResourceRetirement'; DiagnosticVersion = '0.1'; TestKind = 'Sampler rejection paths'
    ExecutableSHA256 = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash
    NativeSHA256 = (Get-FileHash -LiteralPath $nativePath -Algorithm SHA256).Hash
    TestScriptSHA256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
    Cases = $results; Failures = $failures; ResourceAcceptance = 'NOT_EVALUATED'; TimedSoak = 'NOT_RUN'
}
[IO.File]::WriteAllText((Join-Path $reportRoot 'RESULTS.json'), ($record | ConvertTo-Json -Depth 6), $utf8)
if ($failures) { throw "$failures sampler rejection case(s) failed. Evidence retained at $reportRoot" }
[pscustomobject]@{ ReportDirectory = $reportRoot; Cases = $cases.Count; Failures = $failures }
