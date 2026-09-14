VT7 OpenSSH S00 controlled-server characterization

This diagnostic uses the exact Microsoft OpenSSH 10.0p2 ssh.exe accepted by the
Windows 7 preflight. It does not contain or redistribute OpenSSH.

Before running:

1. Create a temporary, unprivileged Debian account with no sudo access.
2. Add a dedicated unencrypted public key to that account's authorized_keys.
   Password authentication is not needed by this package. The issued S00 run
   used key-only authentication.
3. On the Debian server, obtain the Ed25519 host-key fingerprint through a
   separate trusted administrative path:

   sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256

4. Extract this package into a fresh writable folder and run
   RUN-OPENSSH-S00-NETWORK.cmd. Supply the server address, port, username,
   private-key path and trusted SHA256 host-key fingerprint when prompted.

The runner never reads a password. It does not copy or hash the private key. It
does not retain the server address, port, username, host key, host-key
fingerprint, or private-key path in the result. The known-host files and raw
trust, PTY, active-cancellation and negotiation diagnostics are temporary. PTY
and cancellation text is redacted before retention, and the temporary files are
deleted before completion.

The accepted cases require strict out-of-band host-key verification, public-key
authentication with password fallback disabled, exact binary stdout/stderr and
remote exit propagation without a PTY, a 131071-byte final drain, forced PTY
allocation and initial dimensions, negotiated algorithms, and cancellation
during active output.

This package does not claim that redirected ssh.exe can receive a VT7 grid
resize as an SSH window-change request. The completed target run reports 0 by 0.
Exact Microsoft 10.0p2 source confirms that redirected pipes cannot supply its
Windows console geometry or resize-event paths, so S00 rejects unmodified
external ssh.exe for interactive VT7 SSH. This package remains available only
to reproduce the accepted command/trust/lifecycle evidence. SSH.NET 2026.0.0 is
approved as the separate S01 embedded candidate.
