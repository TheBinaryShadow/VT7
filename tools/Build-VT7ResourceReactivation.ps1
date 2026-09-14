[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installations = @(& $vswhere -latest -products * -version '[17.0,18.0)' -requires Microsoft.Component.MSBuild -property installationPath)
if ($LASTEXITCODE -ne 0 -or $installations.Count -ne 1) { throw 'Visual Studio 2022 MSBuild is required.' }
$msbuild = Join-Path $installations[0].Trim() 'MSBuild\Current\Bin\MSBuild.exe'
$sdkVersion = '9.0.318'
$sdkRoot = Join-Path $env:ProgramFiles "dotnet\sdk\$sdkVersion"
$frameworkRoot = Join-Path ${env:ProgramFiles(x86)} 'Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8'
foreach ($path in @($msbuild, $sdkRoot, $frameworkRoot)) {
    if (!(Test-Path -LiteralPath $path)) { throw "Required build input missing: $path" }
}
$id = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff') + '-' + [Guid]::NewGuid().ToString('N')
$output = Join-Path $repositoryRoot "artifacts\vt7\diagnostics\resource-reactivation-build-$id"
if (Test-Path -LiteralPath $output) { throw 'Refusing to replace build output.' }
New-Item -ItemType Directory -Path $output | Out-Null
$snapshot = Join-Path $output 'source'
$utf8 = New-Object Text.UTF8Encoding($false)
$paths = @('src/vt7/Directory.Build.props', 'src/vt7/Directory.Build.targets', 'tools/Build-VT7ResourceReactivation.ps1')
foreach ($directory in @('VT7.Host', 'VT7.ResourceReactivation')) {
    $paths += @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot "src/vt7/$directory") -File |
        Where-Object { $_.Extension -in @('.cs', '.csproj', '.xaml', '.manifest') } |
        ForEach-Object { "src/vt7/$directory/" + $_.Name })
}
$sources = @()
foreach ($relative in ($paths | Sort-Object)) {
    $original = Join-Path $repositoryRoot $relative
    $copy = Join-Path $snapshot $relative
    $hash = (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
    New-Item -ItemType Directory -Path (Split-Path -Parent $copy) -Force | Out-Null
    Copy-Item -LiteralPath $original -Destination $copy
    if ((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash -ne $hash) { throw "Source changed while snapshotting: $relative" }
    $sources += [ordered]@{ Path = $relative; SHA256 = $hash }
}
# Pin the SDK resolver as well as the net48 reference assemblies. No native build.
$globalPath = Join-Path $snapshot 'global.json'
[IO.File]::WriteAllText($globalPath, ('{"sdk":{"version":"' + $sdkVersion + '","rollForward":"disable","allowPrerelease":false}}'), $utf8)
$sources += [ordered]@{ Path = 'global.json'; SHA256 = (Get-FileHash -LiteralPath $globalPath).Hash }
$head = (& git -C $repositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot read source HEAD.' }
$status = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Cannot read source status.' }
$arguments = @((Join-Path $snapshot 'src/vt7/VT7.ResourceReactivation/VT7.ResourceReactivation.csproj'),
    '/restore', '/t:Build', '/nologo', '/m:1', '/nr:false', '/p:Configuration=Release', '/p:Platform=x64',
    "/p:ReactivationOutputRoot=$output", "/p:BaseIntermediateOutputPath=$output/obj/",
    "/p:IntermediateOutputPath=$output/obj/Release/", "/p:MSBuildProjectExtensionsPath=$output/obj/",
    '/p:UseSharedCompilation=false', '/p:RestoreIgnoreFailedSources=true',
    "/bl:$output\build.binlog", '/verbosity:diagnostic')
$inputs = [ordered]@{
    Diagnostic = 'VT7.ResourceReactivation'; DiagnosticVersion = '0.1'; BuildStatus = 'Started'
    StartedUtc = [DateTime]::UtcNow.ToString('o'); SourceGitHead = $head
    SourceGitDirty = ($status.Count -gt 0); SourceGitStatus = $status; SourceFiles = $sources
    Configuration = 'Release'; Architecture = 'x64'; TargetFramework = 'net48'
    SDKVersion = $sdkVersion; SDKRoot = $sdkRoot; FrameworkReferences = $frameworkRoot
    MSBuildPath = $msbuild; MSBuildVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($msbuild).FileVersion
    MSBuildSHA256 = (Get-FileHash -LiteralPath $msbuild).Hash; Arguments = $arguments
    NativeDLL = 'Not rebuilt. Runtime bytes pinned to the issued Atlas viewport 0.3.5 package.'
    Validation = 'Build only; full protocol and Windows 7 execution are separate checks.'
}
[IO.File]::WriteAllText((Join-Path $output 'BUILD-INPUTS.json'), ($inputs | ConvertTo-Json -Depth 8), $utf8)
$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = $msbuild
$start.Arguments = (@($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' ')
$start.WorkingDirectory = $snapshot
$start.UseShellExecute = $false; $start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
$process = New-Object Diagnostics.Process
$process.StartInfo = $start
Write-Host "Building managed WPF diagnostic in fresh directory: $output"
try {
    if (!$process.Start()) { throw 'Cannot start MSBuild.' }
    $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $buildLog = $stdout.Result + $stderr.Result
    [IO.File]::WriteAllText((Join-Path $output 'build.log'), $buildLog, $utf8)
    if ($process.ExitCode -ne 0) { throw "MSBuild failed ($($process.ExitCode)). Preserve $output\build.log" }
} finally { $process.Dispose() }
$outputs = @()
foreach ($relative in @('bin/VT7.ResourceReactivation.exe', 'bin/VT7.ResourceReactivation.exe.config', 'bin/VT7.ResourceReactivation.pdb')) {
    $outputs += [ordered]@{ Path = $relative; SHA256 = (Get-FileHash -LiteralPath (Join-Path $output $relative)).Hash }
}
$inputs.BuildStatus = 'Completed'; $inputs.CompletedUtc = [DateTime]::UtcNow.ToString('o'); $inputs.OutputFiles = $outputs
[IO.File]::WriteAllText((Join-Path $output 'BUILD-MANIFEST.json'), ($inputs | ConvertTo-Json -Depth 8), $utf8)
Write-Host "Completed: $output"
[pscustomobject]@{ OutputDirectory = $output; ExecutablePath = (Join-Path $output $outputs[0].Path) }
