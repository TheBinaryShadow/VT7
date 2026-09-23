VT7 OpenSSH-compatible read-only trust KH01.2 package 0.3
========================================================

This candidate integrates the user's normal OpenSSH known-host files into both
the direct SSH.NET profile and the typed `ssh` overlay. It reads, in order:

  %USERPROFILE%\.ssh\known_hosts
  %USERPROFILE%\.ssh\known_hosts2
  %ProgramData%\ssh\ssh_known_hosts
  %ProgramData%\ssh\ssh_known_hosts2

It never writes those files in KH01.2. A missing file is optional. An existing
file that cannot be read or parsed safely blocks the connection. A matching raw
host key can connect with the fingerprint field empty. An unknown host still
requires its exact SHA256 fingerprint from a trusted path. A supplied wrong
fingerprint, changed key, revoked key, unreadable store, or certificate policy
case is rejected before authentication.

Package 0.3 uses the publisher-built SSH.NET 2026.0.1-prerelease.6 package from
upstream commit f099365. That commit resets the receive MAC after each packet on
.NET Framework and is the targeted correction for the connection failure seen
with Windows 7's non-ESU .NET Framework 4.8.4110.0 mscorlib.

AUTOMATED CHECK

1. Extract the complete archive into a new writable directory.
2. Run RUN-KNOWN-HOSTS-KH01-2.cmd without elevation.
3. A successful run prints "VT7 KH01.2 read-only known-host validation passed."
4. Return the complete Logs directory if this check fails.

This check uses disposable known-host fixtures. It does not inspect or modify
the real files above, make a network connection, or request credentials.

CONTROLLED SERVER CHECK

Use the existing Debian 12 sshtest server and private key. Verify beforehand
that its current host key is already present under the exact host spelling and
port you will use in one of the four files above. Obtain and compare that key
through the already trusted administrative path; do not trust an unverified
network scan.

1. Run RUN-VT7-COMMAND-PROMPT.cmd.
2. At the embedded prompt, type the normal ssh command for the server.
3. In VT7's dialog, leave "SHA256 fingerprint (if unknown)" empty, select the
   private key and connect. The stored matching key must connect normally.
4. Exit the remote shell. The original local prompt must return.
5. Click Start SSH..., enter the same endpoint and credentials, leave the
   fingerprint empty, and connect. This direct path must also succeed.
6. Exercise scrollback, resize, input, and remote exit in either connection.

If an alternate hostname or address for the same controlled server resolves and
is absent from all four known-host files, it may be used to check first-contact
fallback: an empty fingerprint must be rejected, while the exact independently
verified fingerprint permits that connection. Do not edit or corrupt a real
trust file merely to manufacture changed, revoked, or unreadable cases; the
automated corpus covers those states with disposable sources.

BOUNDARY

KH01.2 is read only. It does not offer Connect once or Trust and connect, add or
remove entries, replace changed keys, or complete host-certificate trust. Those
remain KH01.3 and KH01.4 work. Values, credentials, endpoints, host keys,
fingerprints, and known-host file contents are excluded from default reports.
