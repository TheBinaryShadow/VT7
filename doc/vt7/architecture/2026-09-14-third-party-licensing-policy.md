# Third-party licensing and acknowledgement policy

Decision date: 2026-09-14. Status: approved, project-wide and long-term.

## Decision

New VT7-authored source remains MIT licensed wherever possible. VT7 may adopt
compatible permissive third-party code, libraries, binaries, fonts, data and
runtime components when they materially help the Windows 7 port. This standing
approval includes Apache License 2.0, ISC-style, BSD-style, zlib, Unicode, W3C,
CC0, public-domain dedications and comparable supplier notice sets. These
components keep their own licenses; distributing them with VT7 does not relicense
them as MIT.

A new permissive component does not need a repeated owner choice when the audit
finds obligations consistent with this policy. It still needs a recorded review
before incorporation. A license with source-sharing, network-use, proprietary
redistribution, field-of-use, noncommercial or other material distribution
conditions receives a separate compatibility and owner review because it can
change how VT7 may be built or shipped.

## Required adoption record

Every included project must have:

1. its exact project name, upstream URL, version or revision, and artifact hashes;
2. the applicable license and every supplier copyright/third-party notice;
3. a record of local modifications and the reason VT7 needs the component;
4. an update/security owner and a clean-package license inventory;
5. the required legal files in source and distribution packages; and
6. a plain-language acknowledgement and thanks to the upstream authors.

`LICENSE` governs VT7-authored code. `NOTICE.md` is the packaged disclosure and
acknowledgement entry point. Component-specific license files remain alongside
the relevant source or binaries where practical. Packaging scripts must retain
`NOTICE.md` and may add exact supplier files under `licenses/`.

Research, source reading and black-box behavioral comparison do not by
themselves incorporate a project. The legal and acknowledgement entry becomes a
distribution requirement when source, binaries, assets or derived material are
actually included.

## Current application and diagnostic inventory

| Component | Relationship | Status |
| --- | --- | --- |
| Microsoft Terminal / OpenConsole | MIT primary inherited upstream for TerminalCore, parser and Atlas work | Included with inherited history and notices. |
| WIL, GSL and {fmt} | MIT source dependencies | Pinned by revision and hash; exact licenses are packaged. |
| Chromium and stb material | Permissive inherited/support source | Included under the retained Microsoft Terminal notices and packaged license files. |
| GNU Unifont and Unifont Upper 17.0.05 | SIL Open Font License 1.1 private fallback assets | Included with pinned hashes, provenance and full font licenses. |
| WinPTY 0.4.3 | MIT Windows 7 local legacy-console runtime | Selected by P01; exact official binaries and license are pinned and packaged. |
| Microsoft Visual C++ runtime 14.44.35112 | Microsoft app-local redistributable code | Included in current packages from the licensed Visual Studio redist directory and disclosed in `NOTICE.md`. |
| SSH.NET 2026.0.0 closure | MIT metadata plus permissive Apache-2.0, ISC-style and supplier notices | Restored under a lock file and accepted by S01 package 0.6 on Windows 7. Production incorporation has not started and must preserve this exact notice closure. |
| Microsoft Win32-OpenSSH 10.0p2 | Mixed permissive external installed executable | Characterized by S00 and retained as a non-PTY command option; not bundled. |

The full inherited component notices and human acknowledgements are in
[`NOTICE.md`](../../../NOTICE.md). The exact accepted SSH.NET closure is in the
[SSH.NET audit](../research/2026-09-14-sshnet-license-audit.md).

## Effect on S01

The SSH.NET 2026.0.0 dependency and notice closure is accepted through the
bounded Windows 7 S01 diagnostic. Corrected package 0.6 preserves the exact
NuGet hashes and supplier license/notice files and proves Windows 7 loading,
modern negotiation, trust and prompt behavior, initial/live PTY resize, byte
fidelity, drain, cancellation, session isolation and owned shutdown. Production
integration may now follow that accepted evidence and must retain the approved
licenses and supplier notices.
