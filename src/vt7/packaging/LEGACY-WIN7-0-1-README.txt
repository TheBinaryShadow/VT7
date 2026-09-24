VT7 Windows 7 pre-WMF 5.1 candidate 0.1 (application 0.12.4)
===========================================================

This candidate checks whether Windows 7 SP1 x64 with .NET Framework 4.8 and
Windows PowerShell 2.0 can run VT7 without KB3191566. It carries the accepted
KH01.4 0.8 dependency and notice set. PowerShell 2.0 has not yet been qualified
as an interactive shell. Its selector entry must say Windows PowerShell 2.0
(unqualified on Windows 7), not Windows PowerShell 5.1.

1. Extract the entire ZIP to a new writable folder. Do not mix it with an
   earlier candidate.
2. Run RUN-VT7-LEGACY-BASELINE.cmd. It uses cmd.exe and VT7's own diagnostics;
   its only PowerShell command is compatible with version 2.0 and records the
   installed engine version. It records the .NET 4.8 registry release key and
   runs window, Command Prompt transport, stream, outbound and SSH.NET
   foundation checks. If it fails, return the complete Logs folder.
3. Run RUN-VT7-COMMAND-PROMPT.cmd. Check ordinary typing, Croatian text,
   resize, scrollback, Ctrl+C on a running command, and clean exit/restart.
   Confirm the profile selector names the installed PowerShell version.
4. Select Windows PowerShell 2.0 as an exploratory check. Try an ordinary
   command, multiline input, a native child, keyboard editing, resize,
   scrollback, and clean exit. Report differences even if the baseline passed.
5. If a controlled SSH test server is available, try Start SSH... and typed
   ssh from Command Prompt. Verify the host key independently, then check
   connect, resize, remote exit and return to the local prompt. Do not send
   credentials or private key material with logs.

RUN-KNOWN-HOSTS-KH01-4.cmd and RUN-SSHNET-OVERLAY.cmd are retained for the
PowerShell 5.1 machines. Do not run them on the PowerShell 2.0 machine: those
automated scripts require 5.1 syntax. The product paths above do not depend
on those scripts.

Passing this candidate on LEOPARD establishes the tested configuration only.
It does not retroactively qualify all Windows 7 prerequisite combinations.
