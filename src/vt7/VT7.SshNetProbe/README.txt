VT7 SSH.NET S01 controlled-server diagnostic

This probe currently contains the exact SSH.NET 2026.0.1-prerelease.6 .NET
Framework closure from upstream fix commit f099365 for evaluation. The original
S01 acceptance used SSH.NET 2026.0.0; the prerelease replaces it for the Windows
7 receive-MAC correction. It is a diagnostic and does not install or modify VT7.

Server prerequisites:

1. Controlled Debian 12 host with bash, /usr/bin/python3, sh and stty.
2. Temporary unprivileged account, normally sshtest, with the dedicated public
   key already in authorized_keys.
3. The Ed25519 host-key SHA256 fingerprint obtained through a separate trusted
   administrative path:

   sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256

Extract into a fresh writable folder and run RUN-SSHNET-S01.cmd. Enter the
endpoint, port, username, private-key path and trusted fingerprint when asked.
The private-key passphrase prompt accepts an empty value for an unencrypted key.
The optional password case exercises keyboard-interactive/password ownership if
the controlled account permits it.

RUN-SSHNET-S01.cmd --self-test verifies the complete package and exercises its
offline assembly load, modern algorithm inventory, encrypted OpenSSH Ed25519
key parsing and credential-redaction paths without asking for server or
credential values. The packaged encrypted key is a public diagnostic fixture,
uses the documented non-secret passphrase vt7-s01-fixture, and must never be
authorized on a server.

The probe retains no endpoint, username, fingerprint, key path, password,
passphrase, command text, prompt text or raw server output. Secrets are read in
the probe process, are never command-line arguments, and are not written to the
Logs directory. The retained manifest contains platform and exact assembly
identity, redacted error categories, negotiated protocol names, byte counts and
hashes, PTY geometry observations, lifecycle outcomes and session-isolation
results.

Acceptance covers strict out-of-band host trust and a changed-key rejection;
key authentication; post-quantum hybrid KEX, Ed25519 host trust and modern
AEAD or AES-CTR/HMAC-SHA2 transport protection; binary stdout/stderr
and exit status; xterm-256color PTY allocation at 80 by 24; live and burst resize;
embedded NUL, UTF-8 and escape byte fidelity; 131071-byte final drain; shell EOF;
active command cancellation; owner-ordered stream disposal and client disconnect;
and two-session routing.

The package includes VT7's license and notice entry point plus component-specific
license, supplier notice and NuGet metadata under licenses/. DEPENDENCIES.json
records the 13 exact .nupkg hashes used to produce the runtime closure.
