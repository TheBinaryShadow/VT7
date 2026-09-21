VT7 H01 typed-command shim and barrier diagnostic 0.4
====================================================

This package tests the boundary required before ordinary typed `ssh` can hand a
local VT7 shell to the later embedded SSH.NET transport. It does not make a
network connection, change SSH configuration, read keys, or enable embedded SSH
in the visible application.

The package contains a VT7-authored Windows 7 x64 shim as shim\ssh.exe and the
identical explicit bypass shim as shim\ssh-system.exe. The test prepends that
private directory only to each temporary WinPTY shell. It never changes the
parent, user or machine PATH.

RUNNING ON WINDOWS 7

1. Extract the complete archive into a new writable directory.
2. Run RUN-H01.cmd normally. Administrator rights are not required.
3. Wait for the runner to report success, then return the complete Logs folder.

The strict runner requires Command Prompt, Windows PowerShell 5.1 and exact
PowerShell 7.2.24. It checks:

- ordinary ssh command resolution through all three shells;
- Croatian HR Latin terminal input in both PowerShell versions;
- PowerShell function precedence before the shim;
- eligible -4/-6/-l/-p/-i grammar and unsupported fallback;
- a per-session 256-bit capability and HMAC-SHA256 challenge/response;
- local-only, first-instance named-pipe creation with an explicit current-user
  and LocalSystem DACL;
- pipe-client PID, process creation time, ancestry and WinPTY console membership;
- an exact visible barrier committed through WinPTY before acceptance completes;
- resize while waiting for the barrier;
- exact quoted external argv, exit-code propagation and removal of capability,
  pipe and shim PATH state;
- denial of a wrong capability before acceptance with one fallback and no
  duplicate connection.

The external fallback target is a packaged VT7 test fixture. The diagnostic does
not invoke the machine's installed OpenSSH client and does not contact a server.
Arguments, destinations, capabilities and terminal content are not written to
the retained report.
