VT7 WinPTY P01 characterization 0.2, x64
==========================================

Run RUN-WINPTY-P01.cmd. The launcher creates a timestamped folder under Logs
and leaves all evidence on this computer. It does not change Windows settings.

The eighteen cases compare:

1. exact child console cells and attributes,
2. exact bytes reconstructed by WinPTY, and
3. final VT7 TerminalCore text, cursor, dimensions and legacy color attributes.

Text or cursor differences are measurements and do not abort collection. A run
fails only if the dependency identity, fixture, transport, decoder, final drain
or evidence protocol fails. Keep the complete timestamped folder.

Requested console code pages are target capabilities. If Windows cannot select
one, the case records IsValidCodePage, the actual output code page and the exact
SetConsoleOutputCP error, sends no bytes under the wrong mapping, and continues.

This package pins the official WinPTY 0.4.3 MSVC 2015 x64 bundle. It contains
winpty.dll and winpty-agent.exe, not the Cygwin/MSYS command adapter. The
winpty-LICENSE.txt file contains WinPTY's MIT license. VT7 source is MIT licensed.
VT7's license and inherited third-party notices are in LICENSE.txt and NOTICE.md.

The package contains a diagnostic, not an interactive VT7 application. It does
not send logs or terminal content over the network.
