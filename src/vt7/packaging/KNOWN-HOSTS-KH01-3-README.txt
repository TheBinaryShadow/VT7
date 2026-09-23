VT7 OpenSSH-compatible first-contact trust KH01.3 package 0.4
================================================================

This candidate adds recoverable first contact to both the direct SSH.NET profile
and the typed `ssh` overlay. VT7 reads the four normal OpenSSH files in order:

  %USERPROFILE%\.ssh\known_hosts
  %USERPROFILE%\.ssh\known_hosts2
  %ProgramData%\ssh\ssh_known_hosts
  %ProgramData%\ssh\ssh_known_hosts2

A stored matching raw key connects without a prompt. For an unknown raw key,
VT7 aborts the discovery connection before authentication and shows the exact
host token, key type and SHA256 fingerprint. Cancel stops. Connect once pins
only those captured key bytes for one fresh connection. Trust and connect adds
one canonical line to the primary user known_hosts file, flushes and reloads it,
requires a matching result, and then makes a fresh connection.

Changed, revoked, unreadable, mismatched-fingerprint and certificate-policy
states remain blocked. A saved decision cannot override a file changed after
the prompt. VT7 serializes its writers, excludes new competing writers while
appending, preserves existing bytes and ACLs, gives newly created paths
owner-only ACLs, and verifies the exact append after flushing it.

AUTOMATED CHECK

1. Extract the complete archive into a new writable directory.
2. Run RUN-KNOWN-HOSTS-KH01-3.cmd without elevation.
3. A successful run prints "VT7 KH01.3 first-contact known-host validation passed."
4. Return the complete Logs directory if this check fails.

The check uses disposable known-host fixtures. It does not inspect or modify
your real known-host files, make a network connection, or request credentials.
It covers exact retry pins, stale decisions, concurrent writers, byte/newline
preservation, owner-only creation ACLs and durable read-back.

CONTROLLED SERVER CHECK

Use the Debian 12 sshtest server and independently verify its current SHA256
host fingerprint before beginning. Use a hostname or address absent from all
four known-host files. If necessary, back up the primary user known_hosts file
and remove only the controlled server's test token with ssh-keygen -R. Retain
that backup until testing is complete.

1. Run RUN-VT7-COMMAND-PROMPT.cmd and type the normal ssh command for the
   controlled server.
2. Enter the connection details. The expected fingerprint field may be empty,
   or may contain the independently verified SHA256 fingerprint.
3. In the unknown-host dialog, compare the displayed fingerprint, choose
   Cancel, and confirm that no authentication or saved record follows.
4. Repeat and choose Connect once. Confirm that the remote session works, exit
   cleanly to the local prompt, and confirm ssh-keygen -F still finds no record
   for that exact host token.
5. Repeat and choose Trust and connect. Confirm that the remote session works,
   exits cleanly, and ssh-keygen -F now finds one record in
   %USERPROFILE%\.ssh\known_hosts.
6. Connect again from the typed prompt. It must use the stored key without a
   trust prompt. Then use Start SSH... and confirm the direct path does likewise.
7. Exercise scrollback, resize, Croatian text input and a full remote exit.

Run the same sequence on NESSY and TURTLE. Return the complete Logs directory
only if an automated check fails. For a live-path failure, report the safe UI
message and the action being tested; do not return credentials, private keys,
host-key blobs, fingerprints or real known-host file contents.

BOUNDARY

KH01.3 adds unknown raw keys only. It does not remove or replace stored keys,
edit ProgramData trust, repair malformed files, enable host certificates, hash
new host tokens, or implement the later known-host management view. Those stay
fail-closed for KH01.4. The package retains publisher-built SSH.NET
2026.0.1-prerelease.6/f099365 for the Windows 7 .NET Framework MAC correction.
