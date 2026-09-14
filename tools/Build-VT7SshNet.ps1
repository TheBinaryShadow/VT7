[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    [switch]$NoRestore
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectPath = Join-Path $repositoryRoot 'src\vt7\VT7.SshNetProbe\VT7.SshNetProbe.csproj'

if (-not $NoRestore) { & (Join-Path $PSScriptRoot 'Restore-VT7SshNet.ps1') }
& dotnet build $projectPath --no-restore -c $Configuration -p:Platform=x64 -v:minimal
if ($LASTEXITCODE -ne 0) { throw "S01 $Configuration build failed." }
Write-Host "VT7 S01 build completed: artifacts\vt7\bin\$Configuration\VT7.SshNetProbe.exe"
