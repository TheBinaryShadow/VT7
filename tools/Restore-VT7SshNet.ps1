[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectPath = Join-Path $repositoryRoot 'src\vt7\VT7.SshNetProbe\VT7.SshNetProbe.csproj'
$configPath = Join-Path $repositoryRoot 'NuGet.Config'
$packageRoot = Join-Path $repositoryRoot 'artifacts\vt7\deps\nuget'
$noticeRoot = Join-Path $repositoryRoot 'artifacts\vt7\deps\sshnet-source-notices-7b2fd3dbf2c86a80a7b06cea020aa5f821c9902e'

$packages = @(
    @{ Id = 'ssh.net'; Version = '2026.0.0'; Sha256 = 'B2515DE616821198F5CF5530F5EA198912730BBE3504EF4C6AEE00A661FECAC2' },
    @{ Id = 'bouncycastle.cryptography'; Version = '2.7.0'; Sha256 = 'F091FFCCAB4D03993E660BACE277659A79DEE0972F54D7F1F4BD46D680966241' },
    @{ Id = 'microsoft.bcl.cryptography'; Version = '10.0.10'; Sha256 = '4B8EB4562DDC2066E352C0BE51325D5536DF2EE75A15C76DAF809B0B4B19B22D' },
    @{ Id = 'microsoft.extensions.logging.abstractions'; Version = '8.0.3'; Sha256 = 'E4C498D5A13051B4577A148F1D8C3470167215C507E2392069B75DC61322BB74' },
    @{ Id = 'microsoft.bcl.asyncinterfaces'; Version = '8.0.0'; Sha256 = 'F5A5A68B03092AB2ABF68843D4A4AEA25DFBCBE8DD0F13C625CB779B6FC1927C' },
    @{ Id = 'microsoft.extensions.dependencyinjection.abstractions'; Version = '8.0.2'; Sha256 = '51F2DF1100245F10DA54F0BB7E813F277155117777D4FBBAB902214E27372606' },
    @{ Id = 'system.buffers'; Version = '4.6.1'; Sha256 = 'B00451E91D016FBEC091AD1E361F3A7015E1D91D4047F7E48A74455B2A673D79' },
    @{ Id = 'system.formats.asn1'; Version = '10.0.10'; Sha256 = '21963AB1DFEE2B2B87E7B6348A3A23A4772AF500247E4401B0BBE3156CEDB29C' },
    @{ Id = 'system.memory'; Version = '4.6.3'; Sha256 = '26078AEB758C9AE985E8BF851F973026061DA6A5EB4837204D0C2D2204C72955' },
    @{ Id = 'system.numerics.vectors'; Version = '4.6.1'; Sha256 = '2BC500A86DCB02F2032D6D877F9E2D6E9E4A79080E57239B4198679D4031F2C7' },
    @{ Id = 'system.runtime.compilerservices.unsafe'; Version = '6.1.2'; Sha256 = '5F6A7F53AF3465F92BEB6DA873EBE0E496206C313313B98BADEE4355A6B25937' },
    @{ Id = 'system.threading.tasks.extensions'; Version = '4.5.4'; Sha256 = 'A304A963CC0796C5179F9C6B7D8022BBCE3B2FA7C029EB6196F631F7B462D678' },
    @{ Id = 'system.valuetuple'; Version = '4.6.2'; Sha256 = '76FD0E366A2B90655FD15D557B0B79504197748358CB578FE3193F6D97BDD9AA' }
)

foreach ($configuration in @('Debug', 'Release')) {
    & dotnet restore $projectPath --configfile $configPath --source 'https://api.nuget.org/v3/index.json' --packages $packageRoot --locked-mode -p:Configuration=$configuration
    if ($LASTEXITCODE -ne 0) { throw "S01 locked NuGet restore failed for $configuration." }
}

foreach ($package in $packages) {
    $nupkg = Join-Path $packageRoot ($package.Id + '\' + $package.Version + '\' + $package.Id + '.' + $package.Version + '.nupkg')
    if (-not (Test-Path -LiteralPath $nupkg -PathType Leaf)) { throw "S01 package is missing: $($package.Id) $($package.Version)" }
    if ((Get-FileHash -LiteralPath $nupkg -Algorithm SHA256).Hash -ne $package.Sha256) { throw "S01 package hash mismatch: $($package.Id) $($package.Version)" }
}

$notices = @(
    @{ Name = 'SSH.NET-LICENSE.txt'; Uri = 'https://raw.githubusercontent.com/sshnet/SSH.NET/7b2fd3dbf2c86a80a7b06cea020aa5f821c9902e/LICENSE'; Sha256 = '84C79A38515DE2833A7C353395E04056C0CBD77545D450FE216D569E1570B78E' },
    @{ Name = 'SSH.NET-THIRD-PARTY-NOTICES.txt'; Uri = 'https://raw.githubusercontent.com/sshnet/SSH.NET/7b2fd3dbf2c86a80a7b06cea020aa5f821c9902e/THIRD-PARTY-NOTICES.TXT'; Sha256 = '9CE436C5811F18BA3DEB9442DACDBAD4FADA7923CBA5A582A4250A5E4B195426' }
)
New-Item -ItemType Directory -Path $noticeRoot -Force | Out-Null
foreach ($notice in $notices) {
    $path = Join-Path $noticeRoot $notice.Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Invoke-WebRequest -UseBasicParsing -Uri $notice.Uri -OutFile $path }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $notice.Sha256) { throw "S01 source notice hash mismatch: $($notice.Name)" }
}

Write-Host 'SSH.NET 2026.0.0 locked closure and source notices verified.'
