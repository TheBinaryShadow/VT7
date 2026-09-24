VT7 Windows 7 pre-WMF 5.1 candidate 0.2 (application 0.12.5)
===========================================================

Candidate 0.1 established LEOPARD's Windows 7 SP1 x64 / .NET Framework 4.8 /
Windows PowerShell 2.0 baseline. Its manual Command Prompt check revealed that
typed ssh was not recognized when OpenSSH was absent. VT7 had gated its own
bundled shim on discovery of an external ssh.exe. Candidate 0.2 removes that
gate: supported interactive ssh commands use VT7's SSH.NET overlay without
installed OpenSSH. Unsupported options or redirected handles use the external
client only if one is installed. Otherwise they return status 255 with an
explicit external-client-unavailable message. Start SSH... still uses the
same direct SSH.NET transport.

1. Extract the entire ZIP into a new writable folder. Do not mix it with 0.1.
2. Run RUN-VT7-LEGACY-BASELINE.cmd. It uses cmd.exe, records the .NET release
   key and Windows PowerShell version, and runs six built-in checks. The new
   sixth check proves the bundled typed-SSH shim can complete an authenticated
   interactive handoff without external OpenSSH, while unsupported syntax is
   rejected. Return the complete Logs folder if a check fails.
3. Run RUN-VT7-COMMAND-PROMPT.cmd. Type a supported command such as
   ssh sshtest@YOUR_TEST_SERVER (or ssh -p 22 sshtest@YOUR_TEST_SERVER).
   Verify the host fingerprint by a separate trusted method, then check
   connection, remote input, resize, remote exit and return to the local
   prompt. No system ssh.exe installation is needed for this path.
4. Confirm Start SSH... still connects separately. Check the PowerShell 2.0
   profile only as an exploratory, unqualified path.

The existing RUN-KNOWN-HOSTS-KH01-4.cmd and RUN-SSHNET-OVERLAY.cmd are
PowerShell 5.1 test launchers retained for NESSY and TURTLE. Do not run those
scripts on LEOPARD. Do not send credentials, private keys or real known_hosts
contents in returned logs.
