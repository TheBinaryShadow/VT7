# Winsock, cryptography, credential storage and HTTPS

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P1 for SSH; secondary for downloads/update checks.

## Stream transport semantics

Winsock recv can return fewer bytes than a logical application message; zero on a connection-oriented socket indicates graceful closure after received data is exhausted. A nonblocking socket can return WSAEWOULDBLOCK. [1]

send can consume fewer bytes than requested, and success does not mean the peer has received the data. Concurrent send calls on one stream can interleave in ways the application did not intend. [2]

**Recommendation:** put all writes through one ordered per-session queue and retain unconsumed bytes. Do not bind reads to VT sequence boundaries. Separate socket readiness from SSH-channel progress and from terminal parsing.

DNS/connect cancellation also needs a downlevel design. GetAddrInfoExCancel starts with Windows 8; do not make it a Windows 7 import. [3] A worker doing synchronous name resolution may continue after the UI cancels. Use bounded worker ownership and discard stale results; do not free memory that the resolver still owns.

## SSH crypto backend is an independent dependency

**Revised assessment:** Microsoft Win32-OpenSSH explicitly supports installation on Windows 7, and the latest listed release uses LibreSSL 4.2.0 with modern hybrid key exchanges. This makes modern SSH an available implementation choice rather than an unresolved OS-crypto feasibility question. VT7 can investigate reusing ssh.exe and its cryptographic stack, with the remaining work centered on the process/terminal/control boundary. [10][11] See the [OpenSSH reassessment](22-win32-openssh-reassessment.md).

The lower-level socket/crypto guidance in this file applies when VT7 owns that layer. With an external OpenSSH process, much of it instead belongs to OpenSSH; VT7 chiefly owns its IPC and session lifecycle. OpenSSH's application-level crypto does not alter WinHTTP/.NET Schannel behavior elsewhere.

libssh2 offers several crypto backends, including WinCNG and application-shipped libraries. [4]

**Inference:** an OS-native backend can reduce redistributed binaries but ties some capabilities to the OS/provider. An application-local backend can supply different algorithms but adds its own Windows 7/CPU/toolchain/security-update requirements. Neither choice is automatically better.

Before selection, produce a capability report:

- Library/backend versions and hashes.
- Negotiable KEX, host-key, cipher and MAC algorithms.
- Private-key formats and encrypted-key support.
- Random-source initialization failures.
- Behavior during rekey and malformed handshake.
- Exact native imports and CPU instruction requirements.

Do not derive an acceptable algorithm policy solely from the original 2006 SSH RFC lists. Use the selected implementation's current security guidance and later protocol updates when choosing the release policy. This document does not prescribe a cipher allowlist.

## Randomness and secrets

BCryptGenRandom with BCRYPT_USE_SYSTEM_PREFERRED_RNG uses the system-preferred provider and a NULL algorithm handle; that flag is available on the Windows 7 baseline. [5]

**Recommendation:** use the selected crypto library's supported OS-random integration or this API for VT7-generated cryptographic material. A timestamp, process ID or ordinary PRNG is not a substitute.

CryptProtectData normally binds data to the user's logon credentials and computer, with documented exceptions such as roaming profiles. CRYPTPROTECT_LOCAL_MACHINE instead permits other users on that computer to decrypt the data. [6]

**Proposed credential policy:** user-bound DPAPI may protect remembered secrets, but portable settings should reference credentials rather than assume encrypted blobs can move between machines/users. Report decryption failure and let the user reenter credentials. Do not use machine-wide protection for per-user SSH secrets.

Keep secrets out of general logs, crash metadata, profile exports and clipboard debugging. Managed immutable strings complicate erasure; minimize their lifetime and do not promise perfect removal of every memory copy.

## HTTPS and Schannel are separate from SSH

.NET Framework TLS relies on Schannel, so OS support constrains negotiation. Targeting .NET Framework 4.8 does not add every TLS version to Windows 7. [7] Schannel's protocol support table distinguishes supported/default-enabled behavior; native TLS 1.3 is a later Windows feature. [8]

KB3140245 adds WinHTTP default-protocol configuration support for TLS 1.1/1.2 on Windows 7-era systems. It concerns the WinHTTP/default selection path, not a universal new SSH capability. [9]

**Recommendation:** if VT7 later downloads updates or resources, test the actual HTTP stack, protocol settings, certificate chain, machine clock, proxy and root store. Do not disable certificate verification or silently alter global TLS registry settings to make a request work. A dependency downloader running on the developer PC is not acceptance of on-device HTTPS.

## Experiments

IPv4/IPv6, DNS failure, slow DNS, refused connection, unreachable host, stalled handshake, short writes, network loss during large paste, remote orderly close, remote reset, proxy configuration if supported, and sleep/resume.

For HTTPS, include a trusted endpoint, expired certificate, wrong hostname and unavailable trust chain. For secret storage, test same-user decrypt, another user, moved profile, wrong optional entropy and read-only settings directory.

Log stage-specific errors and durations. Avoid a single generic “connection failed” result that obscures DNS, transport, trust and authentication.

## Sources

- [1] Microsoft, [recv](https://learn.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-recv).
- [2] Microsoft, [send](https://learn.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-send).
- [3] Microsoft, [GetAddrInfoExCancel requirements](https://learn.microsoft.com/en-us/windows/win32/api/ws2tcpip/nf-ws2tcpip-getaddrinfoexcancel).
- [4] libssh2, [crypto backend choices](https://libssh2.org/).
- [5] Microsoft, [BCryptGenRandom](https://learn.microsoft.com/en-us/windows/win32/api/bcrypt/nf-bcrypt-bcryptgenrandom).
- [6] Microsoft, [CryptProtectData](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata).
- [7] Microsoft, [.NET Framework TLS behavior](https://learn.microsoft.com/en-us/dotnet/framework/network-programming/tls).
- [8] Microsoft, [Schannel protocol support](https://learn.microsoft.com/en-us/windows/win32/secauthn/protocols-in-tls-ssl--schannel-ssp-).
- [9] Microsoft, [KB3140245: WinHTTP default secure protocols](https://support.microsoft.com/help/3140245).
- [10] Microsoft Win32-OpenSSH project, [installation compatibility](https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH).
- [11] Microsoft Win32-OpenSSH project, [10.0.0.0p2-Preview release and cryptographic dependencies](https://github.com/PowerShell/Win32-OpenSSH/releases/tag/10.0.0.0p2-Preview).
