# SSH.NET 2026.0.0 dependency and license audit

Audit date: 2026-09-14. Status: license policy approved, exact closure locked,
and corrected package 0.6 accepted by S01 on Windows 7. SSH.NET 2026.0.0 is the
selected embedded interactive transport candidate. The closure is not yet
referenced or executed by the VT7 application; production integration remains
separate work.

## Candidate fit

SSH.NET 2026.0.0 is the S01-selected candidate after
[S00](../validation/2026-09-14-openssh-s00.md) rejected unmodified redirected
Windows OpenSSH for interactive PTY geometry. The package targets .NET Framework
4.6.2 and can be referenced by VT7's .NET Framework 4.8 host. It exposes initial
shell dimensions, `ShellStream.ChangeWindowSize`, host-key trust callbacks,
password and keyboard-interactive authentication, encrypted key handling and
cancelable connection APIs. Its current algorithm set covers the exact
`sntrup761x25519-sha512`, `ssh-ed25519` and
`chacha20-poly1305@openssh.com` combination negotiated in S00.

The exact source is tag `2026.0.0`, commit
`7b2fd3dbf2c86a80a7b06cea020aa5f821c9902e`. The signed SSH.NET package is
1,604,179 bytes with SHA256
`B2515DE616821198F5CF5530F5EA198912730BBE3504EF4C6AEE00A661FECAC2`.

## Exact .NET Framework closure

A clean NuGet restore for a .NET Framework 4.8 audit project resolved these 13
packages. Hashes cover the exact `.nupkg` bytes downloaded from NuGet.

| Package | SHA256 |
| --- | --- |
| SSH.NET 2026.0.0 | `B2515DE616821198F5CF5530F5EA198912730BBE3504EF4C6AEE00A661FECAC2` |
| BouncyCastle.Cryptography 2.7.0 | `F091FFCCAB4D03993E660BACE277659A79DEE0972F54D7F1F4BD46D680966241` |
| Microsoft.Bcl.Cryptography 10.0.10 | `4B8EB4562DDC2066E352C0BE51325D5536DF2EE75A15C76DAF809B0B4B19B22D` |
| Microsoft.Extensions.Logging.Abstractions 8.0.3 | `E4C498D5A13051B4577A148F1D8C3470167215C507E2392069B75DC61322BB74` |
| Microsoft.Bcl.AsyncInterfaces 8.0.0 | `F5A5A68B03092AB2ABF68843D4A4AEA25DFBCBE8DD0F13C625CB779B6FC1927C` |
| Microsoft.Extensions.DependencyInjection.Abstractions 8.0.2 | `51F2DF1100245F10DA54F0BB7E813F277155117777D4FBBAB902214E27372606` |
| System.Buffers 4.6.1 | `B00451E91D016FBEC091AD1E361F3A7015E1D91D4047F7E48A74455B2A673D79` |
| System.Formats.Asn1 10.0.10 | `21963AB1DFEE2B2B87E7B6348A3A23A4772AF500247E4401B0BBE3156CEDB29C` |
| System.Memory 4.6.3 | `26078AEB758C9AE985E8BF851F973026061DA6A5EB4837204D0C2D2204C72955` |
| System.Numerics.Vectors 4.6.1 | `2BC500A86DCB02F2032D6D877F9E2D6E9E4A79080E57239B4198679D4031F2C7` |
| System.Runtime.CompilerServices.Unsafe 6.1.2 | `5F6A7F53AF3465F92BEB6DA873EBE0E496206C313313B98BADEE4355A6B25937` |
| System.Threading.Tasks.Extensions 4.5.4 | `A304A963CC0796C5179F9C6B7D8022BBCE3B2FA7C029EB6196F631F7B462D678` |
| System.ValueTuple 4.6.2 | `76FD0E366A2B90655FD15D557B0B79504197748358CB578FE3193F6D97BDD9AA` |

## License finding

All 13 NuGet entries advertise MIT license metadata, but that is not the whole
distribution record:

- SSH.NET's source third-party notice includes an ISC-style BCrypt notice.
- BouncyCastle.Cryptography describes its main license as MIT-style and states
  that its modified BZip2 library uses Apache License 2.0. Reflection against
  the exact net461 assembly confirms that the BZip2 types are compiled into it.
- Microsoft compatibility-package third-party notice files include additional
  permissive terms and notices, including Apache-2.0, BSD-style, Unicode, zlib,
  W3C, CC0 and public-domain material. These broad supplier notices do not prove
  every named component is reached by VT7, but they must not be discarded when
  the corresponding binaries are distributed.

No copyleft term was found in this exact closure. The practical exception is
therefore permissive, but the shipped product would no longer have a strictly
MIT-only dependency and notice set. Accepted S01 package 0.6 retains the exact
supplier notices and its artifact-level license inventory. A production package
must preserve that closure unless a later audited dependency update replaces it.

Removing BouncyCastle is not a small adaptation. SSH.NET uses it across modern
key exchange, Ed25519/curve operations, ChaCha20-Poly1305, key parsing and other
cryptographic paths. A strict MIT-only fork would carry meaningful security and
maintenance responsibility and could lose modern algorithms.

## Security and update ownership

The exact 2026.0.0 release is the upstream patched version for four advisories
published with that release: pre-authentication identification-banner memory
growth, a zero maximum-packet-size channel loop, recursive SCP path traversal
and SCP command-path injection. The first two affect the connection/channel
boundary exercised by S01. The latter two concern `ScpClient`, which the probe
and planned terminal backend do not use. All four official records list releases
through 2025.1.0 as affected and 2026.0.0 as patched.

The VT7 maintainer owns update review. Before any public package containing
SSH.NET, check the upstream security-advisory list and NuGet vulnerability
metadata, review newer releases against the Windows 7/net462 boundary, update
the lock and hashes deliberately, and rerun S01. The lock must never advance
automatically merely because a newer compatible NuGet version exists.

Official advisory references:

- [identification-banner memory growth](https://github.com/sshnet/SSH.NET/security/advisories/GHSA-h5q6-2gr6-3g3m);
- [zero maximum-packet-size loop](https://github.com/sshnet/SSH.NET/security/advisories/GHSA-vhpg-4g9v-rppq);
- [recursive SCP path traversal](https://github.com/sshnet/SSH.NET/security/advisories/GHSA-q939-rpr3-3284); and
- [SCP command-path injection](https://github.com/sshnet/SSH.NET/security/advisories/GHSA-mggc-4xg6-vcxf).

## Owner decision

On 2026-09-14 the owner approved this exact permissive closure and made the
decision project-wide and long-term. VT7 may include compatible permissive
Apache-2.0, ISC-style, BSD-style and other supplier terms when all required
licenses, copyright notices and acknowledgements are preserved. VT7-authored
source remains MIT. Licenses with source-sharing, network-use, proprietary
redistribution or other material conditions still receive a separate
compatibility review because they can change the distribution model.

The approval authorized the bounded S01 Windows 7 diagnostic. Corrected package
0.6 now supplies runtime acceptance for the tested configuration, including
modern negotiation, trust, public-key/password handling, PTY resize, raw bytes,
drain, cancellation, session isolation and owned shutdown. The packages remain
outside the current application until production integration.

## Primary references

- [SSH.NET 2026.0.0 package](https://www.nuget.org/packages/SSH.NET/2026.0.0)
  and [exact source](https://github.com/sshnet/SSH.NET/tree/2026.0.0).
- [SSH.NET ShellStream API](https://sshnet.github.io/SSH.NET/api/Renci.SshNet.ShellStream.html)
  and [ISshClient API](https://sshnet.github.io/SSH.NET/api/Renci.SshNet.ISshClient.html).
- [BouncyCastle C# project](https://github.com/bcgit/bc-csharp), whose packaged
  README records the modified BZip2 license.
