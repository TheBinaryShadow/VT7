# Win32-OpenSSH: a stronger SSH baseline for VT7

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Added after the user pointed out that current Microsoft Win32-OpenSSH runs successfully on Windows 7. This corrects an omission in the initial dependency shortlist. No binary was downloaded or executed during this reassessment.

## Planning adoption

The [approved plan](../architecture/2026-09-11-research-driven-plan.md) now places
this evaluation in roadmap 3A/S00 before substantial local-session integration
or daily-driver UI construction. OpenSSH is the first candidate to evaluate,
not a selected shipping dependency. Full SSH acceptance remains Milestone 5.
Pin and test the exact release; compatibility documentation and a successful
login do not guarantee future Windows 7 maintenance or complete VT7 integration.

## What is established

Microsoft's project installation wiki explicitly lists Windows 7 and later for its GitHub releases. The release list consulted identifies 10.0.0.0p2-Preview as latest. Its notes name OpenSSH 10.0p2, LibreSSL 4.2.0, and support for mlkem768x25519-sha256 and sntrup761x25519-sha512 key exchange. These are substantial positive evidence for modern SSH on the target platform. [1][2]

The user also reports successful operation on Windows 7. That is useful operational evidence, separate from this research's source inspection; no exact local binary/version, negotiated-algorithm transcript or full VT7 integration test was supplied.

Support terminology needs one distinction: the official project documents Windows 7 compatibility, while the GitHub release is labeled Preview/non-production-ready. A Microsoft contributor explains that GitHub and Windows-delivered releases differ in support channel, rather than inherently in quality. Do not turn the Preview label into a claim that the client is unusable; equally, do not describe it as a new Windows 7 OS support lifecycle. [1][2][3]

## Revised project assessment

**Conclusion:** modern SSH cryptography should be treated as an available dependency capability whose integration must be proven, rather than a fundamental Windows 7 feasibility problem.

The LibreSSL dependency demonstrates that the client carries application-level cryptographic implementations. VT7 therefore need not limit SSH to Windows 7 Schannel's TLS capabilities, nor implement SSH algorithms itself. This conclusion concerns the SSH implementation, not a global upgrade of the OS crypto providers. [2]

Proposed responsibility split when reusing ssh.exe:

| OpenSSH owns | VT7 still owns |
| --- | --- |
| SSH negotiation, encryption, integrity and rekeying | Process/session lifecycle and cancellation |
| Protocol authentication and host-key checks | Correct prompt routing and deliberate trust UX |
| Its configuration, identities and agent integration | Selected executable/configuration and package/update policy |
| Remote session/channel protocol | Lossless terminal bytes, grid/resize integration and input ordering |

This split is a design recommendation. It reduces the amount of security-sensitive protocol code VT7 needs to integrate directly. It does not make every OpenSSH feature automatically available through a new UI or IPC wrapper.

## Three integration choices

### Existing client inside the local-console backend

Running ssh.exe through a WinPTY profile is a useful early interoperability target. However, the project's TTY documentation describes a built-in VT100 interpreter for older Windows. The inspected v10.0.0.0 console implementation still selects custom ANSI parsing when the console cannot enable native VT processing. [4][5]

**Inference:** if remote output travels through that interpreter and the legacy screen buffer before WinPTY reconstructs it, modern cryptography does not remove the terminal-fidelity boundary. Compare colors, Unicode, hyperlinks and full-screen behavior instead of inferring them from a successful SSH login.

### External OpenSSH client feeding VT7 directly

This is the preferred next experiment. Keep the SSH implementation in a separate process while delivering its remote terminal bytes to VT7 without screen-buffer reconstruction.

OpenSSH documents that repeated -t options force remote PTY allocation even without a local terminal. That makes a pipe-based experiment plausible, but does not by itself provide a complete terminal bridge. [6]

The inspected client setup derives initial dimensions through TIOCGWINSZ and sends zero dimensions if that query fails. Runtime resizing follows a separate window-change path. Consequently, redirecting stdin/stdout and adding -tt is not evidence that VT7's pane dimensions or later resizes reach the remote PTY. [7]

Questions to resolve:

- Are output bytes delivered intact, with no console interpretation or unwanted conversion?
- How does VT7 supply initial columns/rows and subsequent window-change requests?
- Where do password, passphrase and host-key prompts appear when handles are redirected?
- Can client diagnostics be kept distinct from remote terminal data?
- How do cancellation, pending output and process exit map to session states?
- Can an unmodified client provide the required control path, or is a small maintained helper adaptation needed?

Do not send resize text into shell input as a substitute for SSH window-change messages. Keep authentication prompts intact rather than guessing them from arbitrary localized output.

### Embedded SSH library

libssh2 or SSH.NET remains an option when structured authentication callbacks, explicit channel control and direct resize APIs outweigh the benefits of reusing the OpenSSH executable. The original shortlist was incomplete, not necessarily invalid. Compare actual integration work before committing to an embedded library.

“Direct SSH” describes a lossless path from remote PTY bytes to VT7; it need not require the SSH implementation to run inside VT7's process. The adopted roadmap now uses this interpretation. A proven initial/live PTY control path and deliberate trust/authentication handling remain required; no particular implementation has been selected.

## What this does and does not change elsewhere

The Windows port also contains a compatibility layer and documents a downlevel ssh-shellhost.exe console-to-VT adapter. Those are useful source references for process, console and portability work. The older shell-host documentation does not establish a general ConPTY replacement or superior fidelity on the current VT7 corpus. [4][5]

This finding reduces uncertainty around available SSH implementations and modern cryptography. DirectWrite fallback, font coverage, glyph-to-cell mapping, Atlas presentation, IME, accessibility, and local Windows-console semantics still need their own solutions. HTTPS implemented through WinHTTP/.NET Framework still uses its own stack; installing OpenSSH does not update Schannel. See the [networking distinction](17-networking-and-cryptography.md).

## Recommended next experiment

Run the 3A/S00 OpenSSH comparison before selecting the SSH implementation:

1. Record the exact executable version/hash and Windows 7 test image. Retain a controlled verbose connection log with the negotiated algorithms and secrets removed.
2. Establish a working local-console baseline using the user's known-good configuration.
3. Try direct redirected I/O with forced remote PTY allocation and controlled non-secret credentials.
4. Compare exact VT/UTF-8 bytes with remote output, and verify dimensions remotely before and after pane resize.
5. Exercise authentication prompts, unknown/changed host keys, large paste, alternate screen and close during output.
6. Choose unmodified OpenSSH, a narrow helper adaptation, or an embedded library based on those results.

The release should inherit a maintained cryptographic implementation; VT7's main investigation becomes the terminal/session boundary.

## Sources

- [1] Microsoft Win32-OpenSSH project, [installation instructions explicitly including Windows 7](https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH).
- [2] Microsoft Win32-OpenSSH project, [10.0.0.0p2-Preview release](https://github.com/PowerShell/Win32-OpenSSH/releases/tag/10.0.0.0p2-Preview) and [release list](https://github.com/PowerShell/Win32-OpenSSH/releases).
- [3] Microsoft contributor Danny Maertens, [support-channel explanation in discussion 2136](https://github.com/PowerShell/Win32-OpenSSH/discussions/2136), 2023-09-11; historical explanation rather than an independent current support contract.
- [4] Microsoft Win32-OpenSSH project, [TTY/PTY design and downlevel behavior](https://github.com/PowerShell/Win32-OpenSSH/wiki/TTY-PTY-support-in-Windows-OpenSSH); wiki last edited 2021, checked against the newer source where described above.
- [5] Microsoft OpenSSH port, [v10.0.0.0 console implementation](https://raw.githubusercontent.com/PowerShell/openssh-portable/v10.0.0.0/contrib/win32/win32compat/console.c), including con_enter_raw_mode and parser selection.
- [6] OpenBSD/OpenSSH, [ssh manual, -t option](https://man.openbsd.org/ssh.1); verify platform-specific behavior using the selected Windows build.
- [7] Microsoft OpenSSH port, [v10.0.0.0 clientloop.c](https://raw.githubusercontent.com/PowerShell/openssh-portable/v10.0.0.0/clientloop.c), client_session2_setup and client_check_window_change.
