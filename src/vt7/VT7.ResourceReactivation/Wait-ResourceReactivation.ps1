# Copyright (c) 2026 VT7 contributors. Licensed under the MIT license.
# Windows PowerShell 2.0 compatible. The caller owns this exact Process object.
function Wait-VT7ReactivationExit {
    param([Diagnostics.Process]$Child, [int]$TimeoutSeconds)
    if ($TimeoutSeconds -lt 1 -or $TimeoutSeconds -gt 2400) { throw 'Invalid collection timeout.' }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while (!$Child.WaitForExit(1000)) {
        if ($clock.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
            $Child.Kill(); $Child.WaitForExit()
            throw 'The collection time limit expired; the owned child was terminated and partial logs retained.'
        }
    }
    return $clock.ElapsedMilliseconds
}
