# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Development-machine regression: builds its own fixture, never issued VT7 binaries.
[CmdletBinding()]
param(
    [string]$CdbPath,
    [ValidateRange(1, 30)] [int]$TimeoutSeconds = 30
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$utf8 = New-Object Text.UTF8Encoding($false)
$runId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff') + '-' + [Guid]::NewGuid().ToString('N')
$outputDirectory = Join-Path $repositoryRoot ('artifacts\vt7\diagnostics\trace-exception-policy-' + $runId)
[void][IO.Directory]::CreateDirectory($outputDirectory)
Write-Host "Exception policy regression evidence: $outputDirectory"

function Invoke-VT7PolicyChild {
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

function Assert-VT7PolicyCount {
    param([string]$Text, [string]$Pattern, [int]$Expected)
    $count = [regex]::Matches($Text, $Pattern).Count
    if ($count -ne $Expected) { throw "Expected $Expected records, found $count for $Pattern" }
}

$sourcePaths = @('tools/testdata/VT7TraceExceptionFixture.cpp', 'tools/Test-VT7TraceExceptionPolicy.ps1', 'src/vt7/VT7.ResourceTrace/trace.cdb', 'src/vt7/VT7.ResourceTrace/startup.cdb')
$sourceFiles = @()
foreach ($relative in $sourcePaths) {
    $original = Join-Path $repositoryRoot $relative
    $snapshot = Join-Path (Join-Path $outputDirectory 'source') $relative
    $originalHash = (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $snapshot))
    Copy-Item -LiteralPath $original -Destination $snapshot
    if ((Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash -ne $originalHash) { throw "Source changed while snapshotting: $relative" }
    $sourceFiles += [ordered]@{ Path = $relative; SHA256 = $originalHash }
}
$traceText = [IO.File]::ReadAllText((Join-Path (Join-Path $outputDirectory 'source') $sourcePaths[2]))
$policyMatches = [regex]::Matches($traceText, '(?m)^\.echo VT7_EXCEPTION_POLICY_BEGIN\r?\n[\s\S]*?^\.echo VT7_EXCEPTION_POLICY_END\r?$')
if ($policyMatches.Count -ne 1) { throw 'Expected exactly one complete exception policy block in trace.cdb.' }
$policy = $policyMatches[0].Value
$startupText = [IO.File]::ReadAllText((Join-Path (Join-Path $outputDirectory 'source') $sourcePaths[3]))
$startupPolicyMatches = [regex]::Matches($startupText, '(?m)^\.echo VT7_EXCEPTION_POLICY_BEGIN\r?\n[\s\S]*?^\.echo VT7_EXCEPTION_POLICY_END\r?$')
if ($startupPolicyMatches.Count -ne 1 -or $startupPolicyMatches[0].Value.Replace("`r", '') -cne $policy.Replace("`r", '')) {
    throw 'Startup control exception policy differs from the production trace policy.'
}
$commandsPath = Join-Path $outputDirectory 'fixture-policy.cdb'
$commands = ".symopt+ 0x80000`r`n.symopt+ 0x200`r`n.symopt+ 0x100`r`nr @`$t0 = 0`r`n" + $policy + "`r`n.echo FIXTURE_DEBUGGER_ARMED`r`ng`r`n"
[IO.File]::WriteAllText($commandsPath, $commands, [Text.Encoding]::ASCII)

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
$fixture = Join-Path $outputDirectory 'VT7TraceExceptionFixture.exe'
$compilerArguments = @('/nologo', '/Bv', '/EHsc', '/std:c++20', '/permissive-', '/utf-8', '/MT', '/Od', '/W4', '/WX', '/Zi', '/X', '/D_WIN32_WINNT=0x0601', '/DWINVER=0x0601', '/DNDEBUG', "/Fe$fixture", "/Fo$(Join-Path $outputDirectory 'fixture.obj')", "/Fd$(Join-Path $outputDirectory 'compiler.pdb')")
foreach ($directory in $includes) { $compilerArguments += "/I$directory" }
$compilerArguments += @((Join-Path (Join-Path $outputDirectory 'source') $sourcePaths[0]), '/link', '/MACHINE:X64', '/SUBSYSTEM:CONSOLE,6.01', '/OSVERSION:6.1', '/INCREMENTAL:NO', '/DEBUG', "/PDB:$(Join-Path $outputDirectory 'VT7TraceExceptionFixture.pdb')", 'kernel32.lib')
foreach ($directory in $libraries) { $compilerArguments += "/LIBPATH:$directory" }
$responsePath = Join-Path $outputDirectory 'compiler.rsp'
[IO.File]::WriteAllText($responsePath, (@($compilerArguments | ForEach-Object { '"' + $_ + '"' }) -join ' '), [Text.Encoding]::Unicode)
$compilerEnvironment = @{ CL = $null; _CL_ = $null; LINK = $null; LIB = $null; LIBPATH = $null; INCLUDE = $null; PATH = ((Split-Path -Parent $compiler) + ';' + $env:PATH) }
$build = Invoke-VT7PolicyChild $compiler ('@"' + $responsePath + '"') 'compiler' $compilerEnvironment
if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $fixture -PathType Leaf)) { throw "Fixture compilation failed: $($build.ExitCode). See compiler logs in $outputDirectory" }
$emptySymbols = Join-Path $outputDirectory 'empty-symbols'
[void][IO.Directory]::CreateDirectory($emptySymbols)
$debuggerEnvironment = @{ _NT_SYMBOL_PATH = $null; _NT_ALT_SYMBOL_PATH = $null; _NT_EXECUTABLE_IMAGE_PATH = $null; _NT_SOURCE_PATH = $null }
$manifest = [ordered]@{
    Test = 'VT7 trace exception policy'; Status = 'Started'; SourceFiles = $sourceFiles
    PolicyCommandsSHA256 = (Get-FileHash -LiteralPath $commandsPath -Algorithm SHA256).Hash
    MSVC = $msvcVersion; SDK = $sdkVersion; Compiler = $compiler; CompilerArguments = $compilerArguments
    FixtureSHA256 = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
    CdbPath = $CdbPath; CdbVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($CdbPath).FileVersion
    CdbSHA256 = (Get-FileHash -LiteralPath $CdbPath -Algorithm SHA256).Hash
    TimeoutSeconds = $TimeoutSeconds; Cases = @()
    Scope = 'Separate development fixture only. No issued VT7 executable or native DLL is run or rebuilt.'
}
$manifestPath = Join-Path $outputDirectory 'RESULTS.json'
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $utf8)
try {
    foreach ($case in @('handled', 'unhandled', 'repeated')) {
        $arguments = '-G -y "' + $emptySymbols + '" -cf "' + $commandsPath + '" "' + $fixture + '" ' + $case
        $result = Invoke-VT7PolicyChild $CdbPath $arguments $case $debuggerEnvironment
        $text = $result.Text.Replace("`r", '')
        if ($result.ErrorText.Trim().Length -ne 0) { throw "$case wrote debugger stderr." }
        if ([regex]::IsMatch($text, '(?im)^.*(?:Syntax error|Bad register error|Memory access error).*$')) { throw "$case reported debugger command failure." }
        Assert-VT7PolicyCount $text '(?m)^VT7_EXCEPTION_POLICY_BEGIN$' 1
        Assert-VT7PolicyCount $text '(?m)^VT7_EXCEPTION_POLICY_END$' 1
        Assert-VT7PolicyCount $text '(?m)^FIXTURE_DEBUGGER_ARMED$' 1
        Assert-VT7PolicyCount $text ('(?m)^FIXTURE_BEGIN case=' + $case + ' pid=[1-9][0-9]*$') 1
        Assert-VT7PolicyCount $text '(?m)^FIXTURE_UNEXPECTED_RETURN' 0
        Assert-VT7PolicyCount $text '(?im)^\s*ch\s+-\s+Invalid handle\s+-\s+break\s*$' 1
        Assert-VT7PolicyCount $text '(?im)^\s*hc\s+-\s+Invalid handle continue\s+-\s+not handled\s*$' 1
        $expectedEvents = 1
        $expectedDispatches = 1
        $expectedSecondChance = 0
        $expectedLimit = 0
        if ($case -eq 'unhandled') { $expectedSecondChance = 1 }
        if ($case -eq 'repeated') { $expectedEvents = 16; $expectedDispatches = 15; $expectedLimit = 1 }
        $events = [regex]::Matches($text, '(?m)^VT7_INVALID_HANDLE event=(?<event>[1-9][0-9]*) checkpoint=0 pid=(?<pid>[1-9][0-9]*) tid=[1-9][0-9]*$')
        $fixturePid = [regex]::Match($text, '(?m)^FIXTURE_BEGIN case=\S+ pid=(?<pid>[1-9][0-9]*)$').Groups['pid'].Value
        if ($events.Count -ne $expectedEvents) { throw "$case has $($events.Count) invalid-handle records; expected $expectedEvents." }
        Assert-VT7PolicyCount $text '(?m)^VT7_INVALID_HANDLE event=' $expectedEvents
        for ($index = 0; $index -lt $events.Count; ++$index) {
            if ([int]$events[$index].Groups['event'].Value -ne $index + 1 -or $events[$index].Groups['pid'].Value -ne $fixturePid) { throw "$case has inconsistent exception numbering or process identity." }
        }
        Assert-VT7PolicyCount $text '(?m)^VT7_INVALID_HANDLE_END$' $expectedEvents
        Assert-VT7PolicyCount $text '(?m)^VT7_INVALID_HANDLE_DISPATCH$' $expectedDispatches
        Assert-VT7PolicyCount $text '(?m)^VT7_TRACE_ABORT_INVALID_HANDLE_SECOND$' $expectedSecondChance
        Assert-VT7PolicyCount $text '(?m)^VT7_TRACE_ABORT_INVALID_HANDLE_LIMIT$' $expectedLimit
        Assert-VT7PolicyCount $text '(?m)^VT7_TRACE_ABORT_' ($expectedSecondChance + $expectedLimit)
        Assert-VT7PolicyCount $text '(?m)^quit:\s*$' ($expectedSecondChance + $expectedLimit)
        Assert-VT7PolicyCount $text '(?im)^Last event: [0-9a-f]+\.[0-9a-f]+: Invalid handle - code c0000008 \(first chance\)$' $expectedEvents
        Assert-VT7PolicyCount $text '(?im)^Last event: [0-9a-f]+\.[0-9a-f]+: Invalid handle - code c0000008 \((?:!!! )?second chance(?: !!!)?\)$' $expectedSecondChance
        Assert-VT7PolicyCount $text '(?im)^\s*ExceptionCode:\s+c0000008\s+\(Invalid handle\)\s*$' ($expectedEvents + $expectedSecondChance)
        Assert-VT7PolicyCount $text '(?im)^[0-9a-f`]+\s+[0-9a-f`]+\s+\S+!RaiseException(?:\+\S+)?\s*$' ($expectedEvents + $expectedSecondChance)
        if ($case -eq 'handled') {
            Assert-VT7PolicyCount $text '(?m)^FIXTURE_HANDLER ordinal=1$' 1
            Assert-VT7PolicyCount $text '(?m)^FIXTURE_COMPLETE handlers=1$' 1
            if ($result.ExitCode -ne 0) { throw 'Handled fixture did not exit normally.' }
        }
        elseif ($case -eq 'unhandled') {
            Assert-VT7PolicyCount $text '(?m)^FIXTURE_HANDLER ' 0
            Assert-VT7PolicyCount $text '(?m)^FIXTURE_COMPLETE ' 0
        }
        else {
            Assert-VT7PolicyCount $text '(?m)^FIXTURE_HANDLER ordinal=[0-9]+$' 15
            for ($ordinal = 1; $ordinal -le 15; ++$ordinal) { Assert-VT7PolicyCount $text ('(?m)^FIXTURE_HANDLER ordinal=' + $ordinal + '$') 1 }
            Assert-VT7PolicyCount $text '(?m)^FIXTURE_COMPLETE ' 0
        }
        $manifest.Cases += [ordered]@{ Case = $case; Status = 'Passed'; CdbExitCode = $result.ExitCode; ElapsedMilliseconds = $result.ElapsedMilliseconds; Arguments = $arguments }
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $utf8)
        Write-Host "PASS $case ($($result.ElapsedMilliseconds) ms)"
    }
    $manifest.Status = 'Passed'
}
catch { $manifest.Status = 'Failed'; $manifest['Failure'] = $_.Exception.Message; throw }
finally { [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $utf8) }
[pscustomobject]@{ OutputDirectory = $outputDirectory; ManifestPath = $manifestPath; CasesPassed = $manifest.Cases.Count }
