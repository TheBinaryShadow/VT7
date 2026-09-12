[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
# Isolated negative copies only. Never rename or corrupt the real package assets.
$testRoot = Join-Path $repositoryRoot ('artifacts\vt7\font-asset-negative-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$assets = @('unifont-17.0.05.otf', 'unifont_upper-17.0.05.otf')
foreach ($asset in $assets) {
    foreach ($failure in @('missing', 'altered')) {
        $stage = Join-Path $testRoot ($asset + '-' + $failure)
        $fonts = Join-Path $stage 'fonts'
        New-Item -ItemType Directory -Path $fonts -Force | Out-Null
        foreach ($name in @('VT7.Host.exe', 'VT7.Host.exe.config', 'VT7.Native.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
            $source = Join-Path $BinaryDirectory $name
            if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $stage }
        }
        foreach ($font in $assets) {
            if ($font -ne $asset -or $failure -ne 'missing') { Copy-Item -LiteralPath (Join-Path $BinaryDirectory ('fonts\' + $font)) -Destination $fonts }
        }
        if ($failure -eq 'altered') {
            $stream = [IO.File]::Open((Join-Path $fonts $asset), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            try { $byte = $stream.ReadByte(); $stream.Position = 0; $stream.WriteByte([byte]($byte -bxor 1)) } finally { $stream.Dispose() }
        }
        $report = Join-Path $stage 'diagnostics.log'
        $process = Start-Process -FilePath (Join-Path $stage 'VT7.Host.exe') -ArgumentList ('--diagnostics --diagnostics-output "' + $report + '"') -PassThru -WindowStyle Hidden
        try {
            if (!$process.WaitForExit(30000)) { $process.Kill(); throw "Font asset negative timed out: $stage" }
            if ($process.ExitCode -ne 1 -or !(Test-Path -LiteralPath $report)) { throw "Font failure was not reported correctly: $stage" }
            $text = [IO.File]::ReadAllText($report)
            if ($text -notmatch '(?m)^Passed: False\r?$' -or $text -notmatch '(?m)^FAIL: Windows 7 Atlas font boundary:') { throw "Missing font failure evidence: $report" }
            Write-Host "PASS: $failure $asset ($report)"
        } finally { $process.Dispose() }
    }
}
