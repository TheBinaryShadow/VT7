VT7 OpenSSH-compatible known-host management KH01.4 package 0.5
================================================================

This candidate extends the accepted KH01.3 first-contact flow on both the
direct SSH.NET path and typed ssh overlay. A changed ordinary host key stops
before authentication and opens a review showing the new fingerprint, matching
primary-user records and relevant source locations. After you independently
verify the server, you may select ordinary records from your own primary
%USERPROFILE%\.ssh\known_hosts file for removal. VT7 saves the exact prior
file as known_hosts.old, verifies the resulting file and requires a fresh
connection. It never automatically accepts the changed key. Other OpenSSH
sources, @cert-authority and @revoked entries cannot be removed in this view.

Host certificates are accepted only when SSH.NET verifies the exchange and
certificate signature and VT7 finds an applicable exact @cert-authority CA.
The certificate must be a valid host certificate with a matching nonempty
principal list and no critical options. An applicable revocation of the
certificate, certified key or CA blocks trust. A raw-key record cannot
authorize a certificate. Unknown or malformed certificate cases fail closed.

AUTOMATED CHECK

1. Extract the complete archive into a new writable directory.
2. Run RUN-KNOWN-HOSTS-KH01-4.cmd without elevation.
3. A successful run prints "VT7 KH01.4 management known-host validation passed."
4. Return the complete Logs directory only if this check fails.

This uses disposable files and generated host-certificate keys. It does not
inspect or modify your real known_hosts files or connect to a server. It
checks selection, stale review, concurrent writers, .old backup, retained
bytes, ACLs, certificate policy and ssh-keygen compatibility.

CONTROLLED LIVE CHECK

Use only a test server whose SHA256 host fingerprint you have independently
verified. Back up your primary known_hosts file before a deliberate changed-key
exercise. Create a *disposable* incorrect ordinary record for that test host
token, or rotate a dedicated test server's key under your control. Keep the
backup until the exercise is complete. Do not use this procedure for a
production host or remove unrelated records.

1. Connect to the controlled host through typed ssh. Confirm the changed-key
   review appears before credentials are sent and shows the expected host and
   new fingerprint. Cancel; the local prompt must return.
2. Repeat, select only the disposable conflicting user record, confirm the
   removal and check known_hosts.old contains the exact prior file. The
   connection must stop; it must not silently reconnect or authenticate.
3. Reconnect and complete the fresh first-contact decision. Exit to the local
   prompt. Repeat through Start SSH... to check the direct path.
4. Repeat on NESSY and TURTLE. If a controlled host-certificate server is
   available, separately test matching CA, wrong principal, revoked CA and
   unsupported critical-option cases. Automated policy checks do not replace
   this future network acceptance gate.

For a live-path failure, report the safe UI message and the action tested.
Do not return credentials, private keys, host-key blobs, fingerprints or real
known_hosts contents in logs. Restore your backed-up trust file after testing
if needed. The package retains publisher-built SSH.NET
2026.0.1-prerelease.6/f099365 and its notices.
