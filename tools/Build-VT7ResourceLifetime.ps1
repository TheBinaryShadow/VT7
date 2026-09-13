[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$msvcVersion = '14.44.35207'
$sdkVersion = '10.0.26100.0'
$vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswherePath -PathType Leaf)) {
    throw "Visual Studio Installer's vswhere.exe was not found: $vswherePath"
}
$installationPaths = @(& $vswherePath -latest -products * -version '[17.0,18.0)' `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
if ($LASTEXITCODE -ne 0 -or $installationPaths.Count -ne 1) {
    throw 'Visual Studio 2022 with the x64/x86 C++ tools was not found.'
}
$installationPath = $installationPaths[0].Trim()
$compilerRoot = Join-Path $installationPath "VC\Tools\MSVC\$msvcVersion"
$compilerPath = Join-Path $compilerRoot 'bin\Hostx64\x64\cl.exe'
$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'
$includeDirectories = @(
    (Join-Path $compilerRoot 'include'),
    (Join-Path $sdkRoot "Include\$sdkVersion\ucrt"),
    (Join-Path $sdkRoot "Include\$sdkVersion\shared"),
    (Join-Path $sdkRoot "Include\$sdkVersion\um")
)
$libraryDirectories = @(
    (Join-Path $compilerRoot 'lib\x64'),
    (Join-Path $sdkRoot "Lib\$sdkVersion\ucrt\x64"),
    (Join-Path $sdkRoot "Lib\$sdkVersion\um\x64")
)
$sourcePaths = @(
    'src/vt7/VT7.ResourceLifetime/resource-lifetime.cpp',
    'src/vt7/VT7.Native/include/vt7_native.h',
    'tools/Build-VT7ResourceLifetime.ps1'
)
foreach ($requiredPath in (@($compilerPath) + $includeDirectories + $libraryDirectories)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) { throw "Required pinned build component is missing: $requiredPath" }
}
foreach ($relativePath in $sourcePaths) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath) -PathType Leaf)) {
        throw "Required diagnostic source is missing: $relativePath"
    }
}
$sourceHead = (& git -C $repositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not read the source Git HEAD.' }
$sourceStatus = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Could not read the source Git status.' }

# A fresh directory preserves every earlier candidate, object, log and manifest.
$buildId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff') + '-' + [Guid]::NewGuid().ToString('N')
$outputDirectory = Join-Path $repositoryRoot "artifacts\vt7\diagnostics\resource-lifetime-build-$buildId"
if (Test-Path -LiteralPath $outputDirectory) { throw "Refusing to replace existing build output: $outputDirectory" }
New-Item -ItemType Directory -Path $outputDirectory | Out-Null
$snapshotRoot = Join-Path $outputDirectory 'source'
$sourceFiles = @()
foreach ($relativePath in $sourcePaths) {
    $originalPath = Join-Path $repositoryRoot $relativePath
    $snapshotPath = Join-Path $snapshotRoot $relativePath
    $beforeHash = (Get-FileHash -LiteralPath $originalPath -Algorithm SHA256).Hash
    New-Item -ItemType Directory -Path (Split-Path -Parent $snapshotPath) -Force | Out-Null
    Copy-Item -LiteralPath $originalPath -Destination $snapshotPath
    $snapshotHash = (Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash
    if ($snapshotHash -ne $beforeHash) { throw "Source changed while snapshotting: $relativePath. Partial output retained at $outputDirectory" }
    $sourceFiles += [ordered]@{ Path = $relativePath; SHA256 = $snapshotHash }
}
$executablePath = Join-Path $outputDirectory 'VT7.ResourceLifetime.exe'
$symbolPath = Join-Path $outputDirectory 'VT7.ResourceLifetime.pdb'
$arguments = @(
    '/nologo', '/Bv', '/EHsc', '/std:c++20', '/permissive-', '/utf-8', '/MT', '/O2', '/W4', '/WX', '/Zi', '/X',
    '/D_WIN32_WINNT=0x0601', '/DWINVER=0x0601', '/DNTDDI_VERSION=0x06010100',
    '/DUNICODE', '/D_UNICODE', '/DNDEBUG', '/DPSAPI_VERSION=1',
    "/Fe$executablePath", "/Fo$(Join-Path $outputDirectory 'resource-lifetime.obj')",
    "/Fd$(Join-Path $outputDirectory 'compiler.pdb')"
)
foreach ($includeDirectory in $includeDirectories) { $arguments += "/I$includeDirectory" }
$arguments += @(
    (Join-Path $snapshotRoot $sourcePaths[0]),
    '/link', '/MACHINE:X64', '/SUBSYSTEM:CONSOLE,6.01', '/OSVERSION:6.1',
    '/INCREMENTAL:NO', '/DEBUG', '/OPT:REF', '/OPT:ICF', "/PDB:$symbolPath",
    'kernel32.lib', 'user32.lib', 'gdi32.lib', 'ole32.lib', 'psapi.lib', 'advapi32.lib'
)
foreach ($libraryDirectory in $libraryDirectories) { $arguments += "/LIBPATH:$libraryDirectory" }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$buildManifest = [ordered]@{
    Diagnostic = 'VT7.ResourceLifetime'
    DiagnosticVersion = '0.2'
    BuildStatus = 'Started'
    StartedUtc = [DateTime]::UtcNow.ToString('o')
    SourceGitHead = $sourceHead
    SourceGitDirty = ($sourceStatus.Count -gt 0)
    SourceGitStatus = $sourceStatus
    SourceFiles = $sourceFiles
    Configuration = 'Release'
    Architecture = 'x64'
    Runtime = 'Static release CRT (/MT)'
    VisualStudioInstallation = $installationPath
    MSVCToolset = $msvcVersion
    WindowsSDK = $sdkVersion
    CompilerPath = $compilerPath
    CompilerFileVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($compilerPath).FileVersion
    CompilerSHA256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
    CompilerArguments = $arguments
    NativeDLL = 'Not rebuilt or linked. Loaded dynamically by the diagnostic at runtime.'
    Validation = 'Build only. Runtime measurement completion and Windows 7 execution are separate checks.'
}
[IO.File]::WriteAllText((Join-Path $outputDirectory 'BUILD-INPUTS.json'), ($buildManifest | ConvertTo-Json -Depth 8), $utf8)

Write-Host "Building standalone VT7 resource lifetime diagnostic 0.2: $outputDirectory"
$environmentNames = @('CL', '_CL_', 'LINK', 'LIB', 'LIBPATH', 'INCLUDE', 'PATH')
$savedEnvironment = @{}
foreach ($name in $environmentNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    foreach ($name in $environmentNames) {
        if ($name -ne 'PATH') { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
    }
    [Environment]::SetEnvironmentVariable('PATH', ((Split-Path -Parent $compilerPath) + ';' + $savedEnvironment['PATH']), 'Process')
    $responsePath = Join-Path $outputDirectory 'compiler.rsp'
    # CL forwards only the remainder of /link's response-file line to LINK.
    # Keep all arguments on one line; Windows paths cannot contain quotes.
    $responseLine = (@($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' ')
    [IO.File]::WriteAllText($responsePath, $responseLine, [Text.Encoding]::Unicode)
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $compilerPath
    $startInfo.Arguments = '@"' + $responsePath + '"'
    $startInfo.WorkingDirectory = $outputDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $compilerProcess = New-Object Diagnostics.Process
    $compilerProcess.StartInfo = $startInfo
    try {
        if (-not $compilerProcess.Start()) { throw 'Could not start the pinned compiler.' }
        $standardOutput = $compilerProcess.StandardOutput.ReadToEndAsync()
        $standardError = $compilerProcess.StandardError.ReadToEndAsync()
        $compilerProcess.WaitForExit()
        $compilerLog = $standardOutput.Result + $standardError.Result
        [IO.File]::WriteAllText((Join-Path $outputDirectory 'build.log'), $compilerLog, $utf8)
        Write-Host $compilerLog
        if ($compilerProcess.ExitCode -ne 0) {
            throw "Diagnostic compilation failed with exit code $($compilerProcess.ExitCode). Partial output retained: $outputDirectory"
        }
    }
    finally { $compilerProcess.Dispose() }
}
finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
}
foreach ($requiredOutput in @($executablePath, $symbolPath)) {
    if (-not (Test-Path -LiteralPath $requiredOutput -PathType Leaf)) { throw "Expected build output is missing: $requiredOutput" }
}
$buildManifest.BuildStatus = 'Completed'
$buildManifest.CompletedUtc = [DateTime]::UtcNow.ToString('o')
$buildManifest.ExecutableSHA256 = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash
$buildManifest.SymbolSHA256 = (Get-FileHash -LiteralPath $symbolPath -Algorithm SHA256).Hash
$manifestPath = Join-Path $outputDirectory 'BUILD-MANIFEST.json'
[IO.File]::WriteAllText($manifestPath, ($buildManifest | ConvertTo-Json -Depth 8), $utf8)
Write-Host "Diagnostic build completed: $executablePath"
[pscustomobject]@{ OutputDirectory = $outputDirectory; ExecutablePath = $executablePath; ManifestPath = $manifestPath }
