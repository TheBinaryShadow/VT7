[CmdletBinding()]
param([string]$FontDirectory = (Join-Path $PSScriptRoot '..\oss\unifont'))
$ErrorActionPreference = 'Stop'
$fontHashes = @{
    'unifont-17.0.05.otf' = '85701AB9B1E251EE16F4DF00B13F22EAC311D72B7DAB427A7D975FE7F5064702'
    'unifont_upper-17.0.05.otf' = 'F4FD6D5D752726D384FEEF175BB780C9F29382CD4941C9E1E6990D7C3822A090'
    'OFL-1.1.txt' = '869692AF094C57FB7258C57FE26820C759319603321D0FFEB278DE3651763DED'
    'COPYING' = 'CD2785C2B8E0A01D203560265B2D2D47CDB1401D2707D25918AC5531BCDBA947'
}
foreach ($entry in $fontHashes.GetEnumerator()) {
    $fontAsset = Join-Path $FontDirectory $entry.Key
    if (-not (Test-Path -LiteralPath $fontAsset -PathType Leaf)) { throw "Missing pinned font/license asset: $fontAsset" }
    if ((Get-FileHash -LiteralPath $fontAsset -Algorithm SHA256).Hash -ne $entry.Value) { throw "Pinned font/license checksum mismatch: $fontAsset" }
}
if (-not (Test-Path -LiteralPath (Join-Path $FontDirectory 'README.md') -PathType Leaf)) { throw 'Missing font provenance.' }
Write-Host 'PASS: Unifont 17.0.05 font/license hashes and provenance.'
