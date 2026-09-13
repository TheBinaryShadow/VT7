# SSH connection architecture and remote PTY behavior

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P1. No SSH implementation has been selected or integrated by this research.

**Reassessment:** Microsoft's Win32-OpenSSH installation instructions explicitly include Windows 7. Its current listed release brings a modern OpenSSH/LibreSSL stack. Evaluate that maintained client first as an external-process backend; modern SSH cryptography is substantially less uncertain than the original shortlist implied. Raw terminal I/O, authentication prompts and remote resize still require a proven integration boundary. See the [OpenSSH reassessment](22-win32-openssh-reassessment.md). [12][13]

## Direct channel architecture

VT7 requires direct SSH with host-key verification, authentication, remote PTY allocation and live resize. [1] This transport avoids the Windows 7 console-buffer reconstruction path, but it introduces protocol, cryptographic and asynchronous-I/O responsibilities.

Recommended connection state machine:

    Resolve -> Connect -> SSH handshake -> Verify host key -> Authenticate
    -> Open session channel -> Request PTY -> Start shell -> Stream
    -> Drain/close -> Release

Each state needs cancellation, a deadline and a specific error. Authentication must not continue through an unapproved host-key mismatch. Reconnection creates a new session and must not silently replay already-submitted input.

## Remote PTY request and resize

RFC 4254 defines pty-req with terminal type, columns, rows, pixel dimensions and encoded terminal modes. Nonzero character dimensions take precedence over pixels; zero dimensions are ignored. window-change carries updated dimensions and does not solicit a reply. EOF, channel close and exit status are distinct protocol events. [2]

**Recommendation:** derive columns/rows from the same grid used by the core. Coalesce rapid resizes but send the latest size even when the pane is temporarily hidden. Do not equate a successful local write with proof that the remote application processed the resize.

Choose a terminal type matching tested behavior and the remote terminfo environment. Test stty-reported dimensions and full-screen redraw after repeated resize. A direct SSH shell must be allocated a PTY; a line-oriented exec stream is a different connection mode.

## Dependency candidates

| Candidate | Why investigate | What remains unproven |
| --- | --- | --- |
| Microsoft Win32-OpenSSH | Official project documentation includes Windows 7; available client with modern SSH and LibreSSL. [12][13] | Direct byte transport, initial/live PTY sizing, prompt handling and lifecycle integration without legacy screen reconstruction |
| libssh2 | Native C library; explicit PTY/resize APIs, host-key helpers and nonblocking control; selectable crypto backends. [3] | Exact Windows 7 build, algorithm coverage, runtime closure and update process |
| SSH.NET | Managed SSH library with its own implementation and package surface. [4] | Exact release's target frameworks, transitive/native dependencies, PTY resize, cancellation and Windows 7 execution |

A README saying “Windows” or a compatible managed target framework is not a Windows 7 runtime test. Select a concrete release only after reviewing its security advisories, crypto backend, build artifacts and licensing. This table is an evaluation shortlist, not a recommendation to ship current master.

## libssh2 API details worth preserving

libssh2_channel_request_pty_ex specifies terminal identity, modes and dimensions; EAGAIN means the operation would block rather than permanent failure. [5] The library has request_pty_size / request_pty_size_ex resize entry points. [6]

libssh2_session_block_directions tells the caller whether to wait for socket readability, writability or both after EAGAIN. [7] Do not spin on EAGAIN or assume a read operation only needs readability.

libssh2_channel_read_ex returning zero does not itself mean EOF. [8] Channel write can partially consume data; after EAGAIN the original buffer/size must be respected on retry. [9]

**Recommended implementation:** one serialized state machine per SSH session, immutable in-flight write storage, explicit retry state, bounded queues, and independent EOF/close/exit-status tracking. Keep channel draining active even when the pane is not being rendered.

## Host identity and credentials

RFC 4253's host-key verification authenticates the server; accepting a key without verification leaves active-attack exposure. [10] libssh2_knownhost_checkp distinguishes match, mismatch, not found and check failure, and supports a host-plus-port lookup. [11]

Proposed UI/storage policy:

- Known matching key: proceed.
- Unknown key: show host, port, algorithm and fingerprint for an explicit trust decision.
- Changed key: stop authentication and show the mismatch; do not replace it automatically.
- Check/parsing/storage failure: report failure rather than treating it as first use.
- Persist known-host changes atomically and handle concurrent app instances.

Password, keyboard-interactive, private-key/passphrase and agent authentication need separate tests. Agent integration is backend-specific; do not assume the protocol/path used by one Windows agent is universal.

## Acceptance

Test vim, less, tmux, htop and another mouse-driven TUI; alternate-screen exit; Unicode; wide prompts; bracketed paste; mouse; rapid resize; server disconnect; network stall; rekey under output; unknown/changed host keys; cancellation during each connection state; and closing while output is pending.

The byte stream remains untrusted terminal content even after the SSH server is authenticated. See [VT protocol boundaries](19-vt-protocol-and-security.md).

## Sources

- [1] [VT7 SSH milestone](../../../ROADMAP.md).
- [2] IETF, [RFC 4254, sections 5, 6.2, 6.7 and 6.10](https://www.rfc-editor.org/rfc/rfc4254).
- [3] libssh2 project, [capabilities and crypto backends](https://libssh2.org/).
- [4] SSH.NET project, [source, package and license references](https://github.com/sshnet/SSH.NET).
- [5] libssh2, [channel_request_pty_ex](https://libssh2.org/libssh2_channel_request_pty_ex.html).
- [6] libssh2, [channel_request_pty_size](https://libssh2.org/libssh2_channel_request_pty_size.html) and [extended variant](https://libssh2.org/libssh2_channel_request_pty_size_ex.html).
- [7] libssh2, [session_block_directions](https://libssh2.org/libssh2_session_block_directions.html).
- [8] libssh2, [channel_read_ex](https://libssh2.org/libssh2_channel_read_ex.html).
- [9] libssh2, [channel_write_ex](https://libssh2.org/libssh2_channel_write_ex.html).
- [10] IETF, [RFC 4253, server authentication](https://www.rfc-editor.org/rfc/rfc4253).
- [11] libssh2, [knownhost_checkp](https://libssh2.org/libssh2_knownhost_checkp.html).
- [12] Microsoft Win32-OpenSSH project, [Windows 7 installation compatibility](https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH).
- [13] Microsoft Win32-OpenSSH project, [10.0.0.0p2-Preview release](https://github.com/PowerShell/Win32-OpenSSH/releases/tag/10.0.0.0p2-Preview).
