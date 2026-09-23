# Audited static packages

This directory holds exact package inputs that are not available from the
repository's normal NuGet.org source.

`SSH.NET.2026.0.1-prerelease.6.nupkg` is the publisher-built package fetched
from SSH.NET's official GitHub Packages feed. Its nuspec records the official
repository and commit `f099365c9d4cf2ade92b92c203bbb2b345d2cd74`. That commit
is the upstream Windows/.NET Framework receive-MAC reset fix in pull request
1830. The net462 assembly reports informational version
`2026.0.1-prerelease.6+f099365c9d`.

The retained package SHA-256 is:

`3981BA4F5A36DADFFDAC19BA8B8F207F594F57B3BA043A794277678669FBC35C`

The upstream package is MIT licensed and retains its supplier notices. Replace
this static prerelease with the first stable SSH.NET release containing
`f099365` after the stable artifact passes the same two-machine Windows 7
acceptance run.
