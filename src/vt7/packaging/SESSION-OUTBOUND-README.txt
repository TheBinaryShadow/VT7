VT7 session outbound foundation 0.3.7
=====================================

This engineering candidate validates the generation-checked outbound queue and
the native child-HWND input adapter selected by the completed I01 Windows 7
Croatian HR Latin characterization. It has no shell or SSH backend yet.

Target: Windows 7 SP1 x64 with the Platform Update, .NET Framework 4.8, UCRT,
and the project's recorded loader/SHA-2 prerequisites. No installation or
system change is performed. Keep every file and directory beside VT7.Host.exe.

Run RUN-SESSION-OUTBOUND.cmd. It verifies the package hashes, runs the hidden
ABI 10 test, and writes a new collision-resistant folder beneath Logs. On a
pass, return that entire new folder. Keep any folder produced by a failure too.

The test covers:

- bounded FIFO admission, stale generations, completion and resize coalescing;
- native HWND Croatian and AltGr committed UTF-16 through TerminalCore;
- one output for Enter and for each Ctrl+C or Ctrl+Break action;
- distinct Interrupt and Break operations;
- non-text key encoding without live-thread ToUnicodeEx translation;
- modifier reconciliation on focus loss; and
- one authoritative grid after native resize notification.

The test sends messages only to its own hidden VT7 child window. It does not
launch a child shell, connect to a network, change the keyboard layout, install
fonts, or alter system configuration. The included font assets retain their
OFL 1.1 license; application and incorporated code dependencies retain the
licenses included in this package.
