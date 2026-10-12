VT7 SSH startup stalls SL01.3 candidate 0.2 (x64, application 0.16.0)
================================================================

This candidate qualifies real SSH authentication and PTY stalls, owned
cancellation/close, late-reply rejection and typed Command Prompt recovery.
SL01.1/SL01.2 and the known-host policy are retained. .NET Framework 4.8 is
required; original Windows 7 PowerShell 2.0 is supported by this test runner.
No system OpenSSH or WMF upgrade is needed on the Windows machines.

1. Extract into a NEW folder on LEOPARD, NESSY and TURTLE. Run:

   RUN-SSH-LIFECYCLE-SL01-3.cmd --self-test

   This verifies all inventory hashes and runs eight disconnected/loopback
   regression stages. No server, fixture or private key is needed for this step.
   Return the complete Logs directory, including on success.

2. Prepare the isolated fault peer on the Debian 13 server (10.3.3.2).
   Install its server-only dependency if absent:

   sudo apt install python3-paramiko
   python3 -c 'import paramiko; print(paramiko.__version__)'

   Debian 13's package is Paramiko 3.5.1. It is NOT a VT7 runtime dependency.
   Copy this package's server/VT7-SL01-3-server.py to Debian. Also copy the
   PUBLIC .pub key matching the dedicated Windows test private key. Never
   transfer that private key to Debian for this test. Supply one public key,
   not an authorized_keys file. Different client keys need separate fixtures.

   Example, from the package directory on Debian:

   python3 server/VT7-SL01-3-server.py prepare /var/tmp/vt7-sl01-3-a 10.3.3.2 /path/to/dedicated-client.pub --port 22400
   python3 server/VT7-SL01-3-server.py serve /var/tmp/vt7-sl01-3-a

   Choose a NEW directory for prepare. It generates a dedicated private host
   key here and a PUBLIC client.fixture valid for seven days. The seven ports
   are 22400-22406; allow the test clients to reach them. The address must be
   an IPv4 address owned by this Debian machine. Wait for SL01.3 READY.

   This runs in the foreground as an ordinary user and never edits normal
   sshd, port 22, users, authorized_keys, known_hosts or the KH01.5 fixture.
   It has no OS shell or command execution. Only the supplied public key can
   authenticate synthetic sshtest_<run-id>_<case> identities. These are protocol
   test names, not Debian accounts. Password, agent, exec and forwarding paths
   are denied. The server deliberately holds its protocol thread at known
   callbacks; it is a fault fixture, not a general-purpose SSH service.

3. Transfer /var/tmp/vt7-sl01-3-a/client.fixture to Windows through your
   trusted file transfer path. Then run (without --self-test):

   RUN-SSH-LIFECYCLE-SL01-3.cmd

   After the eight regression stages, enter that public fixture's full path,
   the matching dedicated PRIVATE key's full path, and its passphrase if any.
   Paths/passphrases go through an anonymous stdin pipe to the owned process;
   no credentials are written to disk, command arguments or environment.
   No host-trust popup is needed: the fresh fixture key is pinned only in a
   generated diagnostic store. Your actual .ssh files remain unchanged.

   The extra stage runs 12 cases: healthy-before/after; authentication and PTY
   production timeouts; deliberately late replies with shorter diagnostic
   phase clocks; cancellation and explicit close while replies are held; and
   production-limit typed Command Prompt timeout/status-255/same-PID recovery.
   Expect about two minutes for this extra stage. A watchdog failure is a
   test failure, not a claimed production shutdown bound. Synchronous work
   remains owned until it settles; cancellation can take several seconds.

4. Run ONE client matrix per foreground serve run. When the Windows runner
   completes, wait five seconds, then press Ctrl+C on Debian. All seven
   listeners stop; normal sshd remains available. Every serve run gets a fresh
   server-<time>-<id>.jsonl audit; none is overwritten. Before testing the next
   Windows machine, run the same serve command again (no prepare needed when
   the public key is the same and client.fixture has not expired).

5. Pair each server audit with its Windows ssh-startup-stall-test.log.
   Copy that LOG (not private credentials) to Debian, then run:

   python3 server/VT7-SL01-3-server.py audit /var/tmp/vt7-sl01-3-a/server-<time>-<id>.jsonl /path/to/ssh-startup-stall-test.log

   The audit requires the same FixtureId/RunId, all 12 connections, natural
   six/eighteen-second holds, authenticated PTY requests, closed workers and
   healthy-before/after completion. Client-only success is not paired
   acceptance. Save audit stdout as server-audit-<machine>.txt and return it,
   the matching complete Windows Logs, and the matching server .jsonl files.
   Preserve failed runs too. No port-22 password/normal login is required.

Leave these fault listeners DOWN after testing. The fixture private key stays
on the server; retain its directory until evidence review is complete.

Scope limits
------------
This is an additional diagnostic mode; production SSH.NET, native rendering,
fonts, shim, trust policy and dependency closure are retained from accepted
SL01.2. Target acceptance remains pending until paired Windows 7 reports pass.
Hard OS DNS completion bounds, partial/stalled I/O, final-output drain,
silent-network-loss detection, rekey and nonzero remote exit status remain
separate. PowerShell 2.0's full interactive editor corpus remains unqualified.
UTF-8/text/font parity, terminal-only SSH prompts and the final tab/title-bar
UI remain required later work before polish/1.0. The KH01.5 listeners stay down.
