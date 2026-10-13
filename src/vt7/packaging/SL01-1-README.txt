VT7 SSH lifecycle SL01.1 candidate 0.4, application 0.14.0, native ABI 11

Requires Windows 7 SP1 x64 and .NET Framework 4.8. WMF 5.1 and installed
OpenSSH are not prerequisites. Extract into a fresh folder; do not overlay
an older candidate. The original Windows PowerShell 2.0 can run this gate.

1. Run RUN-SSH-LIFECYCLE-SL01-1.cmd on LEOPARD, NESSY and TURTLE.
   This is the complete automated check. No client.fixture or Debian fixture
   listeners are needed. Tests use disposable local loopback TCP peers.
   A hidden window can briefly appear. Allow up to two minutes per stage.
   Return the complete Logs folder from each machine, even if everything passes.
   --verify-only checks package integrity and prerequisites without tests.

2. Run RUN-VT7-COMMAND-PROMPT.cmd and use the ordinary server on port 22:
       ssh sshtest@10.3.3.2
   Follow the existing trusted host/key and dedicated-account procedure.
   On the supported PowerShell 5.1/7.2.24 profiles, repeat the same typed path.
   LEOPARD's interactive PowerShell 2.0 remains outside that qualified scope.
   Current connection/trust dialogs are temporary development UI; the approved
   final SSH workflow will move these interactions into the terminal.

3. Check normal remote "exit", explicit Disconnect SSH, and two sequential
   connections. Each must recover the original local prompt, with no replay
   of earlier remote input. Normal exit should report 0, disconnect 255.
   In Command Prompt: echo %ERRORLEVEL%
   In PowerShell: $LASTEXITCODE
   Run htop/nano and resize/scroll/type as usual, then exit both cleanly.
   Repeat a connection through Start SSH... and close its window while active.

4. For connection-loss testing, interrupt only this dedicated client's SSH
   network path after connecting, then restore it. Do not stop the main sshd
   service or kill unrelated sessions. Record exactly how the interruption was
   made and elapsed time. A detected loss must return a failure and local prompt;
   a silent blackhole is NOT guaranteed to be detected within a fixed time in
   SL01.1. The larger keepalive/blackhole work remains pending.
   Close the VT7 window during connection startup and during an active session.
   It must remain responsive while ownership cleanup settles and then close,
   with no later session/window appearing. Record any unusually long shutdown.

SL01.1 joins startup before releasing transport/session/presentation resources,
distinguishes observed SSH errors from clean stream EOF, and preserves typed
failure/cancellation return status. Synchronous SSH.NET startup phases may take
their operation timeout to settle; cancellation is not promised instantaneous.
15 seconds is a library operation timeout, not a whole-session wall-clock limit.
Remote nonzero exit-status propagation, rekey-under-output, full staged deadlines,
silent-network-loss bounds, agent authentication and terminal-only prompts remain
separate work. Automated success does not accept these future requirements.

Do not send credentials, private keys or ordinary terminal contents. Automated
reports retain fixed test markers, bounded failure categories and file hashes.
Return the Logs folders and the live observations above, even on a clean run.
