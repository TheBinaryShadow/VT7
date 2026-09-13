# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Own fixture only: mapped Microsoft bytes are PAGE_READWRITE data and never run.
[CmdletBinding()]
param([string]$CdbPath, [ValidateRange(1, 60)][int]$TimeoutSeconds = 30)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$utf8 = New-Object Text.UTF8Encoding($false)
$runId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff') + '-' + [Guid]::NewGuid().ToString('N')
$outputDirectory = Join-Path $repositoryRoot ('artifacts\vt7\diagnostics\retirement-debugger-hooks-' + $runId)
if (Test-Path -LiteralPath $outputDirectory) { throw 'Refusing to replace earlier evidence.' }
[void][IO.Directory]::CreateDirectory($outputDirectory)
Write-Host "Debugger hook fixture evidence: $outputDirectory"
function Invoke-VT7HookChild {
    param([string]$Executable, [string]$Arguments, [string]$Name, [hashtable]$Environment)
    $child = New-Object Diagnostics.Process
    $child.StartInfo = New-Object Diagnostics.ProcessStartInfo($Executable, $Arguments)
    $child.StartInfo.WorkingDirectory = $outputDirectory
    $child.StartInfo.UseShellExecute = $false
    $child.StartInfo.CreateNoWindow = $true
    $child.StartInfo.RedirectStandardOutput = $true
    $child.StartInfo.RedirectStandardError = $true
    foreach ($key in $Environment.Keys) {
        if ($null -eq $Environment[$key]) { $child.StartInfo.EnvironmentVariables.Remove($key) }
        else { $child.StartInfo.EnvironmentVariables[$key] = $Environment[$key] }
    }
    $started = $false
    $stdout = $null
    $stderr = $null
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $started = $child.Start()
        if (-not $started) { throw "Could not start $Name." }
        $stdout = $child.StandardOutput.ReadToEndAsync()
        $stderr = $child.StandardError.ReadToEndAsync()
        if (-not $child.WaitForExit($TimeoutSeconds * 1000)) { throw "$Name exceeded its $TimeoutSeconds-second timeout." }
        $child.WaitForExit()
        $watch.Stop()
        return [pscustomobject]@{ ExitCode = $child.ExitCode; ElapsedMilliseconds = $watch.ElapsedMilliseconds; Text = $stdout.Result; ErrorText = $stderr.Result }
    }
    finally {
        try {
            if ($started -and -not $child.HasExited) {
                # CDB owns only the fixture it launches; debugger termination also
                # terminates that debuggee. No detach or kill-on-exit override.
                $child.Kill()
                if (-not $child.WaitForExit(5000)) { throw "Could not terminate this test's $Name process." }
                $child.WaitForExit()
            }
            if ($null -ne $stdout) { [IO.File]::WriteAllText((Join-Path $outputDirectory ($Name + '-stdout.log')), $stdout.Result, $utf8) }
            if ($null -ne $stderr) { [IO.File]::WriteAllText((Join-Path $outputDirectory ($Name + '-stderr.log')), $stderr.Result, $utf8) }
        }
        finally { $child.Dispose() }
    }
}

function Assert-VT7HookCount {
    param([string]$Text, [string]$Pattern, [int]$Expected)
    $count = [regex]::Matches($Text, $Pattern).Count
    if ($count -ne $Expected) { throw "Expected $Expected records, found $count for $Pattern" }
}


$sourcePaths = @('tools/testdata/VT7RetirementHookFixture.cpp', 'tools/Test-VT7RetirementDebuggerHooks.ps1',
    'src/vt7/VT7.ResourceRetirement/warp-load.cdb', 'src/vt7/VT7.ResourceRetirement/warp-verify.cdb', 'src/vt7/VT7.ResourceRetirement/warp-hooks.cdb',
    'src/vt7/VT7.ResourceRetirement/retirement.cdb')
$sourceFiles = @()
foreach ($relative in $sourcePaths) {
    $original = Join-Path $repositoryRoot $relative
    $snapshot = Join-Path (Join-Path $outputDirectory 'source') $relative
    $originalHash = (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $snapshot))
    Copy-Item -LiteralPath $original -Destination $snapshot
    if ((Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash -ne $originalHash) { throw "Source changed while snapshotting: $relative" }
    $sourceFiles += [ordered]@{ Path = $relative; SHA256 = $originalHash }
    if ($relative.EndsWith('.cdb')) { Copy-Item -LiteralPath $snapshot -Destination (Join-Path $outputDirectory (Split-Path -Leaf $relative)) }
}
$imagePath = Join-Path $repositoryRoot 'artifacts\vt7\diagnostics\win7-ntdll-symbolication-28116\D3D10Warp.dll'
$imageHash = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash
if ($imageHash -ne '35979BAF3D0538E74EE7E114F96D33A9558C0A4FE06E5A5D6FBFCCFB27794EDB') { throw 'Wrong read-only WARP image data.' }
$loadText = [IO.File]::ReadAllText((Join-Path $outputDirectory 'warp-load.cdb'))
$headerSetup = [regex]::Matches($loadText, '(?m)^r @\$t8 = .+\r?$')
$headerGuard = [regex]::Matches($loadText, '(?m)^\.if \(\(wo\(@\$t3\).+\r?$')
if ($headerSetup.Count -ne 1 -or $headerGuard.Count -ne 1) { throw 'Expected one production PE-header guard.' }
$hooksText = [IO.File]::ReadAllText((Join-Path $outputDirectory 'warp-hooks.cdb'))
$hookMatches = [regex]::Matches($hooksText, '(?m)^bp\[0n(?<id>[0-9]+)\] (?<once>/1 )?@\$t3\+(?<rva>(?:0x)?[0-9a-f]+) "(?<body>.*)"\r?$')
if ($hookMatches.Count -ne 10) { throw "Expected 10 production hooks, found $($hookMatches.Count)." }
$hooks = @{}
foreach ($match in $hookMatches) {
    $id = [int]$match.Groups['id'].Value
    $body = $match.Groups['body'].Value.Replace('\"', '"').Replace('\\n', '\n')
    $hooks[$id] = [pscustomobject]@{ Id = $id; RVA = [Convert]::ToUInt64($match.Groups['rva'].Value, 16); Body = $body; OriginalBody = $match.Groups['body'].Value; Once = $match.Groups['once'].Success }
}
if (-not $hooks[12].Once) { throw 'The callback hook is not one-shot.' }
$retirementText = [IO.File]::ReadAllText((Join-Path $outputDirectory 'retirement.cdb')).Replace('\"', '"')
$idleClear = [regex]::Matches($retirementText, 'sxd -c "" ld:d3d10warp\.dll')
if ($idleClear.Count -ne 1) { throw 'Expected one production idle command that clears the module-load command.' }
$idleBreakpoints = [regex]::Matches($retirementText, 'bc 3-12')
if ($idleBreakpoints.Count -ne 1) { throw 'Expected one production idle breakpoint-range clear.' }
$msvcVersion = '14.44.35207'
$sdkVersion = '10.0.26100.0'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) { throw 'Visual Studio Installer vswhere.exe is missing.' }
$installations = @(& $vswhere -latest -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
if ($LASTEXITCODE -ne 0 -or $installations.Count -ne 1) { throw 'Visual Studio 2022 x64 C++ tools were not found.' }
$compilerRoot = Join-Path $installations[0].Trim() "VC\Tools\MSVC\$msvcVersion"
$compiler = Join-Path $compilerRoot 'bin\Hostx64\x64\cl.exe'
$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'
$includes = @((Join-Path $compilerRoot 'include'), (Join-Path $sdkRoot "Include\$sdkVersion\ucrt"), (Join-Path $sdkRoot "Include\$sdkVersion\shared"), (Join-Path $sdkRoot "Include\$sdkVersion\um"))
$libraries = @((Join-Path $compilerRoot 'lib\x64'), (Join-Path $sdkRoot "Lib\$sdkVersion\ucrt\x64"), (Join-Path $sdkRoot "Lib\$sdkVersion\um\x64"))
if (-not $CdbPath) { $CdbPath = Join-Path $repositoryRoot 'artifacts\vt7\diagnostics\debugger-sdk81-tooling\extracted\Windows Kits\8.1\Debuggers\x64\cdb.exe' }
$CdbPath = [IO.Path]::GetFullPath($CdbPath)
foreach ($required in (@($compiler, $CdbPath) + $includes + $libraries)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Required pinned test component missing: $required" }
}
$fixture = Join-Path $outputDirectory 'VT7RetirementHookFixture.exe'
$compilerArguments = @('/nologo', '/Bv', '/EHsc', '/std:c++20', '/permissive-', '/utf-8', '/MT', '/Od', '/W4', '/WX', '/Zi', '/X', '/D_WIN32_WINNT=0x0601', '/DWINVER=0x0601', '/DNDEBUG', "/Fe$fixture", "/Fo$(Join-Path $outputDirectory 'fixture.obj')", "/Fd$(Join-Path $outputDirectory 'compiler.pdb')")
foreach ($directory in $includes) { $compilerArguments += "/I$directory" }
$compilerArguments += @((Join-Path (Join-Path $outputDirectory 'source') $sourcePaths[0]), '/link', '/MACHINE:X64', '/SUBSYSTEM:CONSOLE,6.01', '/OSVERSION:6.1', '/INCREMENTAL:NO', '/DEBUG', "/PDB:$(Join-Path $outputDirectory 'VT7RetirementHookFixture.pdb')", 'kernel32.lib')
foreach ($directory in $libraries) { $compilerArguments += "/LIBPATH:$directory" }
$responsePath = Join-Path $outputDirectory 'compiler.rsp'
[IO.File]::WriteAllText($responsePath, (@($compilerArguments | ForEach-Object { '"' + $_ + '"' }) -join ' '), [Text.Encoding]::Unicode)
$compilerEnvironment = @{ CL = $null; _CL_ = $null; LINK = $null; LIB = $null; LIBPATH = $null; INCLUDE = $null; PATH = ((Split-Path -Parent $compiler) + ';' + $env:PATH) }
$build = Invoke-VT7HookChild $compiler ('@"' + $responsePath + '"') 'compiler' $compilerEnvironment
if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $fixture -PathType Leaf)) { throw "Fixture compilation failed: $($build.ExitCode). See compiler logs in $outputDirectory" }
$debuggerEnvironment = @{ _NT_SYMBOL_PATH = $null; _NT_ALT_SYMBOL_PATH = $null; _NT_EXECUTABLE_IMAGE_PATH = $null; _NT_SOURCE_PATH = $null }
$manifest = [ordered]@{
    Test = 'VT7 retirement debugger hooks'; Status = 'Started'; SourceFiles = $sourceFiles
    MicrosoftImagePath = $imagePath; MicrosoftImageSHA256 = $imageHash
    MSVC = $msvcVersion; SDK = $sdkVersion; Compiler = $compiler; CompilerArguments = $compilerArguments
    FixtureSHA256 = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
    CdbPath = $CdbPath; CdbVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($CdbPath).FileVersion
    CdbSHA256 = (Get-FileHash -LiteralPath $CdbPath -Algorithm SHA256).Hash
    TimeoutSeconds = $TimeoutSeconds; Cases = @()
    Scope = 'Own development fixture only. Microsoft bytes mapped PAGE_READWRITE, never executed. Exact PE guard and verify/hooks files execute in CDB. Event bodies use synthetic registers and memory, with gc replaced by echo for direct evaluation. Actual one-shot callback uses the unmodified command on an own fixture function.'
}
$manifestPath = Join-Path $outputDirectory 'RESULTS.json'
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $utf8)
try {
    foreach ($case in @('matched', 'bad-opcode', 'bad-codeview', 'unsupported', 'event-limit')) {
        $commands = @('.echo FIXTURE_GATE_BEGIN',
            'r @$t10 = @rcx', 'r @$t11 = @rdx', 'r @$t12 = @r8',
            'r @$t13 = @rbx', 'r @$t14 = @rdi', 'r @$t15 = @rax',
            'r @$t3 = @$t10', 'r @$t0 = 0n4', 'r @$t5 = 0', 'r @$t6 = 0', 'r @$t7 = 0',
            $headerSetup[0].Value.TrimEnd(), $headerGuard[0].Value.TrimEnd(), '.echo FIXTURE_GATE_END')
        if ($case -eq 'matched' -or $case -eq 'event-limit') {
            foreach ($id in 3..12) {
                $commands += '.printf "FIXTURE_EXPECT_BP id=%u address=%p\n", 0n' + $id + ', @$t3+0x' + $hooks[$id].RVA.ToString('x')
            }
            $commands += @($idleBreakpoints[0].Value, '.echo FIXTURE_IDLE_BREAKPOINTS_BEGIN', 'bl', '.echo FIXTURE_IDLE_BREAKPOINTS_END')
            if ($case -eq 'event-limit') {
                $commands += @('r @$t5 = 0n127', 'r rcx = @$t12', 'r edx = 3', 'r r8 = @$t11',
                    $hooks[3].Body.Replace('gc;', '.echo FIXTURE_DIRECT_RESUME;'), '.echo FIXTURE_UNEXPECTED_AFTER_LIMIT', 'q')
            }
            else {
                $commands += @('sxe -c ".echo FIXTURE_UNEXPECTED_LOAD_COMMAND" ld:d3d10warp.dll',
                    '.echo FIXTURE_IDLE_BEFORE_BEGIN', 'sx', '.echo FIXTURE_IDLE_BEFORE_END',
                    $idleClear[0].Value, '.echo FIXTURE_IDLE_AFTER_BEGIN', 'sx', '.echo FIXTURE_IDLE_AFTER_END')
                # Each extractor sees the argument registers used by its production hook.
                foreach ($id in 3..11) {
                    $commands += @('r rcx = @$t12', 'r rbx = @$t12', 'r rdi = @$t11', 'r r8 = @$t11', 'r edx = 3', 'r eax = 1')
                    if ($id -eq 4 -or $id -eq 10) { $commands += 'r rbx = @$t11' }
                    if ($id -eq 8) { $commands += @('eq @$t12+0x30 0x66660000', 'ed @$t12+0x2c 2') }
                    if ($id -eq 9 -or $id -eq 10) { $commands += @('eq @$t12+0x30 0', 'eq @$t12+0x38 0', 'ed @$t12+0x2c 3') }
                    if ($id -eq 11) { $commands += 'r eax = 0x80000000' }
                    $commands += $hooks[$id].Body.Replace('gc;', '.echo FIXTURE_DIRECT_RESUME;').Replace('; gc', '; .echo FIXTURE_DIRECT_RESUME')
                }
                $commands += @('r rcx = @$t10', 'r rdx = @$t11', 'r r8 = @$t12', 'r rbx = @$t13', 'r rdi = @$t14', 'r rax = @$t15')
                $commands += ('bp[0n12] /1 VT7RetirementHookFixture!VT7HookCallback "' + $hooks[12].OriginalBody + '"')
                $commands += @('.echo FIXTURE_CALLBACK_HOOK_ARMED', 'g')
            }
        }
        elseif ($case -eq 'unsupported') { $commands += 'g' }
        else { $commands += @('.echo FIXTURE_UNEXPECTED_AFTER_MISMATCH', 'q') }
        $casePath = Join-Path $outputDirectory ('fixture-' + $case + '.cdb')
        [IO.File]::WriteAllText($casePath, ($commands -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
        $startPath = Join-Path $outputDirectory ('start-' + $case + '.cdb')
        $startCommands = @('.symopt+ 0x80000', '.symopt+ 0x200', '.symopt+ 0x100',
            ('bu VT7RetirementHookFixture!VT7HookReady "$$><' + (Split-Path -Leaf $casePath) + '"'), 'g')
        [IO.File]::WriteAllText($startPath, ($startCommands -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
        $arguments = '-G -y "' + $outputDirectory + '" -cf "' + $startPath + '" "' + $fixture + '" "' + $imagePath + '" ' + $case
        $result = Invoke-VT7HookChild $CdbPath $arguments $case $debuggerEnvironment
        $text = $result.Text.Replace("`r", '')
        if ($result.ErrorText.Trim().Length) { throw "$case wrote debugger stderr." }
        if ($text -match '(?im)^.*(?:Syntax error|Bad register error|Memory access error|Couldn.t resolve error|Unable to insert breakpoint).*$') { throw "$case reported debugger command failure." }
        Assert-VT7HookCount $text '(?m)^FIXTURE_BEGIN case=\S+ image=[0-9A-Fa-f]+ device=[0-9A-Fa-f]+ wrapper=[0-9A-Fa-f]+ work=[0-9A-Fa-f]+ protection=PAGE_READWRITE; microsoft_code_executed=0$' 1
        Assert-VT7HookCount $text '(?m)^FIXTURE_GATE_BEGIN$' 1
        Assert-VT7HookCount $text '(?m)^FIXTURE_UNEXPECTED_' 0
        if ($case -eq 'bad-opcode' -or $case -eq 'bad-codeview') {
            Assert-VT7HookCount $text '(?m)^VT7_TRACE_ABORT_WARP_CODE_MISMATCH$' 1
            Assert-VT7HookCount $text '(?m)^VT7_WARP_HOOKS_ARMED$' 0
            Assert-VT7HookCount $text '(?m)^FIXTURE_GATE_END$' 0
        }
        elseif ($case -eq 'unsupported') {
            Assert-VT7HookCount $text '(?m)^VT7_WARP_PROFILE status=UNSUPPORTED profile=none base=[0-9a-f]+$' 1
            Assert-VT7HookCount $text '(?m)^VT7_WARP_HOOKS_ARMED$' 0
            Assert-VT7HookCount $text '(?m)^FIXTURE_COMPLETE; microsoft_code_executed=0$' 1
        }
        else {
            Assert-VT7HookCount $text '(?m)^VT7_WARP_PROFILE status=MATCHED profile=win7-6\.2\.9200\.22592 base=[0-9a-f]+$' 1
            Assert-VT7HookCount $text '(?m)^VT7_WARP_HOOKS_ARMED$' 1
            $expected = [regex]::Matches($text, '(?m)^FIXTURE_EXPECT_BP id=(?<id>[0-9]+) address=(?<address>[0-9a-f]+)$')
            if ($expected.Count -ne 10) { throw 'Missing expected private breakpoint addresses.' }
            foreach ($entry in $expected) {
                $addressPattern = $entry.Groups['address'].Value.Insert(8, '`?')
                Assert-VT7HookCount $text ('(?m)^\s*' + $entry.Groups['id'].Value + '\s+e\s+' + $addressPattern + '\s+') 1
            }
            $clearedBreakpoints = [regex]::Match($text, '(?ms)^FIXTURE_IDLE_BREAKPOINTS_BEGIN\n(?<body>.*?)^FIXTURE_IDLE_BREAKPOINTS_END$')
            if (-not $clearedBreakpoints.Success -or $clearedBreakpoints.Groups['body'].Value -match '(?m)^\s*(?:[3-9]|1[0-2])\s+[ed]\s+') {
                throw 'The production idle breakpoint-range command did not remove every private hook.'
            }
            if ($case -eq 'event-limit') {
                Assert-VT7HookCount $text '(?m)^VT7_WARP_EVENT seq=128 kind=INIT_ENTRY checkpoint=4 ' 1
                Assert-VT7HookCount $text '(?m)^VT7_TRACE_ABORT_WARP_EVENT_LIMIT$' 1
                Assert-VT7HookCount $text '(?m)^FIXTURE_COMPLETE;' 0
            }
            else {
                $beforeIdle = [regex]::Match($text, '(?ms)^FIXTURE_IDLE_BEFORE_BEGIN\n(?<body>.*?)^FIXTURE_IDLE_BEFORE_END$').Groups['body'].Value
                $afterIdle = [regex]::Match($text, '(?ms)^FIXTURE_IDLE_AFTER_BEGIN\n(?<body>.*?)^FIXTURE_IDLE_AFTER_END$').Groups['body'].Value
                if ($beforeIdle -notmatch 'FIXTURE_UNEXPECTED_LOAD_COMMAND' -or $beforeIdle -notmatch 'Load module - break' -or $beforeIdle -notmatch '\(only break for d3d10warp\.dll\)') {
                    throw 'The fixture did not establish the initial module-load command.'
                }
                if ($afterIdle -match 'FIXTURE_UNEXPECTED_LOAD_COMMAND' -or $afterIdle -notmatch 'Load module - output') {
                    throw 'The production idle command did not clear the module-load action and select output.'
                }
                $kinds = @('INIT_ENTRY', 'INIT_RETURN', 'CLEANUP_ENTRY', 'DRAIN_RETURN', 'WORK_CLOSE_RETURN', 'POOL_CLOSE_RETURN', 'CLEANUP_RETURN', 'CLEANUP_FAILURE_RETURN', 'CALLBACK')
                $fixtureFields = [regex]::Match($text, '(?m)^FIXTURE_BEGIN case=matched image=(?<image>[0-9A-F]+) device=(?<device>[0-9A-F]+) wrapper=(?<wrapper>[0-9A-F]+) work=(?<work>[0-9A-F]+) ')
                if (-not $fixtureFields.Success) { throw 'Missing fixture field identities.' }
                for ($i = 0; $i -lt $kinds.Count; ++$i) {
                    $kind = $kinds[$i]
                    $mode = if ($kind -eq 'POOL_CLOSE_RETURN') { 2 } else { 3 }
                    $pool = if ($kind -eq 'POOL_CLOSE_RETURN') { '0000000066660000' } else { '0000000000000000' }
                    $work = if ($kind -eq 'CLEANUP_RETURN' -or $kind -eq 'CLEANUP_FAILURE_RETURN') { '0000000000000000' } else { $fixtureFields.Groups['work'].Value.ToLowerInvariant() }
                    $pattern = '(?m)^VT7_WARP_EVENT seq=' + ($i + 1) + ' kind=' + $kind + ' checkpoint=4 tid=[0-9]+ wrapper=' + $fixtureFields.Groups['wrapper'].Value.ToLowerInvariant() +
                        ' device=' + $fixtureFields.Groups['device'].Value.ToLowerInvariant() + ' mode=' + $mode + ' work=' + $work + ' pool=' + $pool + '$'
                    Assert-VT7HookCount $text $pattern 1
                }
                Assert-VT7HookCount $text '(?m)^VT7_WARP_EVENT ' 9
                Assert-VT7HookCount $text '(?m)^VT7_WARP_INIT_RESULT success=1 wrapper=[0-9a-f]+$' 1
                Assert-VT7HookCount $text '(?m)^VT7_WARP_FREE_RETURN checkpoint=4 tid=[0-9]+ device=[0-9a-f]+ wrapper=[0-9a-f]+ success=1$' 1
                Assert-VT7HookCount $text '(?m)^FIXTURE_CALLBACK instance=' 2
                Assert-VT7HookCount $text '(?m)^FIXTURE_COMPLETE; microsoft_code_executed=0$' 1
                if ($result.ExitCode -ne 0) { throw 'Matched fixture did not exit normally.' }
            }
        }
        $manifest.Cases += [ordered]@{ Case = $case; Status = 'Passed'; CdbExitCode = $result.ExitCode; ElapsedMilliseconds = $result.ElapsedMilliseconds; Arguments = $arguments; CommandsSHA256 = (Get-FileHash -LiteralPath $casePath -Algorithm SHA256).Hash }
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $utf8)
        Write-Host "PASS $case ($($result.ElapsedMilliseconds) ms)"
    }
    $manifest.Status = 'Passed'
}
catch { $manifest.Status = 'Failed'; $manifest['Failure'] = $_.Exception.Message; throw }
finally { [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $utf8) }
[pscustomobject]@{ OutputDirectory = $outputDirectory; ManifestPath = $manifestPath; CasesPassed = $manifest.Cases.Count }
