VT7 SSH lifecycle SL01.2 candidate 0.4, application 0.15.0, native ABI 11

Requires Windows 7 SP1 x64 and .NET Framework 4.8. WMF 5.1 and installed
OpenSSH are not prerequisites. Extract into a fresh folder. Do not overlay an
older candidate. The original Windows PowerShell 2.0 can run this gate.

1. Run RUN-SSH-LIFECYCLE-SL01-2.cmd on LEOPARD, NESSY and TURTLE.
   Eight automated stages cover new startup phase deadlines and the previous
   cancellation, window, stream, outbound, shim and certificate regressions.
   No client.fixture or Debian fixture listeners are needed. Network tests use
   disposable loopback peers, without credentials or host-key acceptance.
   A hidden window can briefly appear. Allow up to two minutes per stage.
   Return the complete Logs directory from EACH machine, even if all pass.
   --verify-only checks package integrity and prerequisites without tests.

2. Run RUN-VT7-COMMAND-PROMPT.cmd. Test the ordinary server on port 22:
       ssh sshtest@10.3.3.2
   Repeat typed SSH in qualified Windows PowerShell 5.1 and PowerShell 7.2.24
   profiles where installed. LEOPARD's PowerShell 2.0 editor remains outside
   the qualified interactive corpus. Repeat with Start SSH... as well.
   Use the existing dedicated account and trusted host-key procedure.
   Current dialogs are temporary; approved final SSH interaction is in-terminal.

3. Verify normal remote exit, two sequential connections, Disconnect SSH,
   htop/nano, input, resize and scrollback. Check the original local shell returns
   without old remote input being replayed. Normal exit returns 0; cancellation
   and timeout return 255. Check echo %ERRORLEVEL% (CMD), or $LASTEXITCODE (PS).
   Close the window during connecting and during an active session. It must
   remain responsive during cleanup and close without a later session appearing.

4. If a host-key decision is presented naturally for this dedicated test host,
   leave it open for at least 20 seconds. There must be no network timeout while
   you decide. Cancel and confirm recovery, then retry and verify/connect using
   the trusted key. Do not remove trusted records merely to force this test.
   Report whether this check was exercised or skipped because the host is known.

Production phase budgets are 15 seconds: address-family resolution, known-host
loading, local credential setup, DNS/TCP/SSH identification, key exchange/trust
verification, post-verification authentication, PTY/shell allocation and durable
trust update. The pinned SSH.NET ConnectAsync retains its existing 15-second
connection cancellation budget, which can expire before a restarted phase budget.
Trust/change-review human decisions pause network clocks but remain cancellable.
An active session has no startup timer. Timeout errors identify a bounded phase;
they must not expose credentials, raw server text or local exception details.

Expiry cancels token-aware work and rejects late results before proceeding.
Synchronous SSH.NET, Windows 7 DNS and local file operations are still joined.
Consequently, 15 seconds is NOT a hard end-to-end return/shutdown guarantee.
Do not infer real DNS completion limits or stalled authenticated-server coverage
from the diagnostic's injected resolver and deadline-policy checks.

This slice does not change the accepted native/font/shim/SSH.NET closure.
Silent network-loss detection, stalled authenticated PTY qualification, rekey
under output, final-output drain, remote nonzero exit status, agent support and
terminal-only prompts remain later work. No Debian certificate fixture needed.

Do not send credentials, private keys or ordinary terminal contents. Return the
complete Logs directories plus the live observations, even on a clean run.
