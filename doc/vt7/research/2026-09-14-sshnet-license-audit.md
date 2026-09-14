# SSH.NET 2026.0.0 dependency and license audit

Audit date: 2026-09-14. Status: license policy approved for S01 evaluation. No
audited package has yet been added to VT7 source, restored by the VT7 build,
executed by the application or accepted for product distribution.

## Candidate fit

SSH.NET 2026.0.0 is the leading S01 candidate after
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
MIT-only dependency and notice set. A final S01 package must retain the exact
supplier notices and generate an artifact-level license inventory.

Removing BouncyCastle is not a small adaptation. SSH.NET uses it across modern
key exchange, Ed25519/curve operations, ChaCha20-Poly1305, key parsing and other
cryptographic paths. A strict MIT-only fork would carry meaningful security and
maintenance responsibility and could lose modern algorithms.

## Owner decision

On 2026-09-14 the owner approved this exact permissive closure and made the
decision project-wide and long-term. VT7 may include compatible permissive
Apache-2.0, ISC-style, BSD-style and other supplier terms when all required
licenses, copyright notices and acknowledgements are preserved. VT7-authored
source remains MIT. Licenses with source-sharing, network-use, proprietary
redistribution or other material conditions still receive a separate
compatibility review because they can change the distribution model.

The approval authorizes a bounded S01 Windows 7 diagnostic. It does not by
itself claim runtime acceptance or add the packages to the current application.

The S01 probe still must prove Windows 7 loads, negotiated modern
algorithms, host trust, password/encrypted-key prompts, initial and live PTY
resize, raw byte fidelity, final drain and cancellation. Audit success alone is
not runtime acceptance.

## Primary references

- [SSH.NET 2026.0.0 package](https://www.nuget.org/packages/SSH.NET/2026.0.0)
  and [exact source](https://github.com/sshnet/SSH.NET/tree/2026.0.0).
- [SSH.NET ShellStream API](https://sshnet.github.io/SSH.NET/api/Renci.SshNet.ShellStream.html)
  and [ISshClient API](https://sshnet.github.io/SSH.NET/api/Renci.SshNet.ISshClient.html).
- [BouncyCastle C# project](https://github.com/bcgit/bc-csharp), whose packaged
  README records the modified BZip2 license.
