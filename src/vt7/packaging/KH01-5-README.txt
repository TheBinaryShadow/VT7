VT7 KH01.5 controlled live host-certificate candidate 0.2
Application 0.13.1, x64, .NET Framework 4.8, native ABI 11
SSH.NET 2026.0.1-prerelease.6 / upstream f099365

This candidate adds certificate validation diagnostics. The production UI
remains the proof UI. Real tabs and terminal-only SSH interaction are later
approved work. Native rendering, bundled shim and supplier/license closure
are reused from the accepted Legacy-Win7-0.2 candidate. The native diagnostic
Build line still says 0.12.3; RUN-ENVIRONMENT records the new host version/hash.

1. Extract this complete ZIP into a fresh folder on each Windows 7 machine.
   SP1 x64 and .NET Framework 4.8 are required. WMF 5.1 and system OpenSSH are
   not required. The new runner supports PowerShell 2.0. It tests Command
   Prompt everywhere, Windows PowerShell only at 5.1, and PowerShell only at
   7.2.24 if installed; skipped interactive profiles are explicitly reported.

2. First run:
     RUN-KNOWN-HOSTS-KH01-5.cmd --self-test
   This validates all nine cases using public OpenSSH-signed fixtures through
   the pinned SSH.NET signature/date verification, decoder and VT7 policy.
   Invalid-signature and unrelated-failure controls must also pass. It is OFFLINE.
   It does not prove a network handshake or Windows 7 live acceptance.
   --verify-only verifies the package inventory and prerequisites instead.

3. The existing 0.1 server fixture/client.fixture can be reused for 0.2 while
   its seven-day certificates remain valid. The server files are unchanged.
   Before retrying, run the reset/start commands in step 8. Do not prepare
   over an existing directory. For a NEW fixture, prepare the Debian 13
   fixture ONCE, outside the regular SSH service.
   Copy the complete server directory from this package to your Debian
   account, for example ~/vt7-kh01-5-server. The script and audit.py must stay
   together. Use your dedicated sshtest account and its existing authorized
   key. Choose an unused nine-port range and a fresh fixture directory name.
   Example for the current controlled Debian server:

     cd ~/vt7-kh01-5-server
     sudo bash VT7-KH01-5-server.sh prepare /var/tmp/vt7-kh01-5-b 10.3.3.2 sshtest 22350
     sudo bash VT7-KH01-5-server.sh start /var/tmp/vt7-kh01-5-b

   These listeners use ports 22350 through 22358 on that IPv4 address.
   If a firewall is enabled, allow this range from the test machines only.
   The script does not change /etc/ssh, the normal port-22 service, the test
   account's authorized_keys, or any Windows known_hosts files. It creates
   its own CA and host keys in its root-owned fixture directory. It requires
   installed OpenSSH server/client tools, bash, sh, stty and python3.
   Certificates last seven days; clocks must be correct. For later dates,
   stop this fixture and prepare a fresh directory with a new name.

4. Copy /var/tmp/vt7-kh01-5-b/client.fixture to the Windows machine through
   your trusted admin path. This is PUBLIC CA/key/certificate data only.
   Keep it outside the extracted candidate directory, for example on the
   Desktop. Never copy the fixture's keys directory or private keys.
   Confirm this file came from the fixture you just created: it supplies
   the authority that the isolated test store trusts.

5. Run the Windows matrix:
     RUN-KNOWN-HOSTS-KH01-5.cmd
   Enter the full client.fixture path, sshtest, your dedicated private-key
   path, and its passphrase (Enter if unencrypted). Credentials travel only
   through an anonymous pipe to the host and are not retained in evidence.
   Expect no trust or connection dialogs: the automated harness supplies
   those inputs for this test. A refusal to dial is a failure, not a valid
   certificate rejection. Do not probe these fixture ports with other
   clients between start/reset and audit: that changes the server counts.

   Direct cases: valid, wrong principal, expired, not yet valid, unknown
   critical option, untrusted CA, revoked raw key, revoked CA, revoked exact
   certificate. Expired/future dates are rejected by SSH.NET during key
   exchange before VT7's trust callback. The harness requires the exact
   expected certificate plus a key-exchange rejection, and probes VT7 date
   policy separately. Other cases require the actual trust callback.
   The valid session verifies output, PTY resize to 120x40,
   remote EOF and prompt-free reconnect. Each qualified local shell then
   runs typed ssh, reaches the fixture PTY, exits, and verifies status 0 in
   its original local shell. These sessions run a small forced command,
   not bash/htop/nano: earlier TUI acceptance remains separate.

6. After ONE client matrix, audit the server using AcceptedConnections from
   the client report (3 on a cmd-only machine, 4 or 5 with qualified shells).
   Example:
     sudo bash VT7-KH01-5-server.sh audit /var/tmp/vt7-kh01-5-b 3

   The audit requires every rejected case to have received exactly one
   connection and ZERO user-authentication requests. Valid connections must
   each authenticate by public key. It emits a privacy-safe aggregate
   /var/tmp/vt7-kh01-5-b/server-audit.txt with the same FixtureId as the client.
   Copy that summary out using sudo if required. Raw server logs stay local.

7. Return the COMPLETE Windows Logs folder AND the matching server-audit.txt
   for each machine, including successful runs. Label them NESSY, TURTLE or
   LEOPARD. If something fails, stop and return what exists; don't repeatedly
   run against the same server logs. Do not send private keys, public fixture
   data, raw server logs, credentials or your actual known_hosts files.
   KH01.5 remains unaccepted until these paired target results are reviewed.

8. Before another Windows machine or a retry, preserve and reset the server:
     sudo bash VT7-KH01-5-server.sh reset /var/tmp/vt7-kh01-5-b
     sudo bash VT7-KH01-5-server.sh start /var/tmp/vt7-kh01-5-b
   reset stops only this fixture's identified listeners and archives its
   previous raw logs. Save server-audit.txt before the next audit overwrites it.
   When finished:
     sudo bash VT7-KH01-5-server.sh stop /var/tmp/vt7-kh01-5-b
   All fixture files/evidence remain available; no automatic cleanup occurs.

Other supplied launchers: RUN-VT7-COMMAND-PROMPT.cmd opens the proof UI;
RUN-VT7-LEGACY-BASELINE.cmd repeats the existing six offline baseline stages.
KH01.4 file addition/removal/recovery is already accepted and is not repeated
by this isolated live certificate matrix.

Disclosures: see NOTICE.md, LICENSE.txt, licenses/ and fonts/.
No new runtime dependency, upstream source reuse or license category is added.
