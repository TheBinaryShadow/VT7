VT7 session ownership 0.4.0 / ABI 11
====================================

This engineering candidate validates Milestone 3A's terminal document/view and
managed transport/session lifetime. It does not contain a real shell or SSH
backend and does not connect to a network.

Target: Windows 7 SP1 x64 with the Platform Update, .NET Framework 4.8, UCRT,
and the project's recorded loader/SHA-2 prerequisites. No installation or
system change is performed. Keep every file and directory beside VT7.Host.exe.

Run RUN-SESSION-OWNERSHIP.cmd. The first test verifies all package hashes. Both
tests create collision-resistant folders beneath Logs. Return the entire new
Logs directory whether the run passes or fails.

The tests cover:

- the accepted 0.3.7 bounded outbound/native input behavior;
- distinct ABI 11 document and view handles and ERROR_BUSY destruction order;
- destruction of the first child HWND during an active UTF-8 stream;
- continued headless drain into TerminalCore and generation-2 reattachment;
- an exact deterministic raster before and after view recreation;
- fake root/overlay/root input generations 1/2/3 over one document stream;
- a TerminalCore reply returned to its originating fake transport; and
- ordered, awaited session/transport/document closure.

The tests create only hidden VT7 windows and in-memory fake transports. They do
not launch a child shell, connect to a network, change the keyboard layout,
install fonts, or alter system configuration. Included fonts retain OFL 1.1;
application and incorporated dependencies retain the licenses in this package.
