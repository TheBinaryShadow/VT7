VT7 typed SSH.NET overlay 0.3
================================

This package integrates the accepted native typed-ssh shim, committed WinPTY
barrier and SSH.NET 2026.0.0 transport in VT7 0.9.2. An eligible interactive
ssh command typed in Command Prompt, Windows PowerShell 5.1 or PowerShell 7.2.24
opens a structured VT7 trust/authentication dialog. The remote PTY then owns the
existing viewport. Exiting or disconnecting returns to the original local shell.

Package 0.2 fixed the Windows 7 failure found in package 0.1: a typed request
arrives on the authenticated broker's worker thread, so VT7 now captures native
document and WPF viewport geometry through the document dispatcher before
starting SSH.NET. The direct Start SSH path was not affected. Package 0.3 fixes
the next accepted-session boundary found on Windows 7: the shim now waits for
the full remote-session lifetime after the authenticated barrier instead of
applying its five-second handshake timeout, and root input recovery runs even
if a shim disconnects before receiving completion.

PREREQUISITE

The controlled Windows 7 machine must retain its reviewed external OpenSSH
client. The accepted location is C:\Program Files\OpenSSH\ssh.exe. VT7 hashes
that exact client when the local profile starts and uses it for unsupported ssh
syntax and the explicit ssh-system escape hatch.

AUTOMATED CHECK

1. Extract the complete archive into a new writable directory.
2. Run RUN-SSHNET-OVERLAY.cmd without elevation.
3. If it fails, return the complete Logs directory.

The automated run makes no network connection and handles no credentials. It
runs the session ownership/input corpus, SSH.NET foundation and full H01 shim,
fallback and committed-barrier corpus.

CONTROLLED SERVER CHECK

1. Run RUN-VT7-SSHNET-OVERLAY.cmd and keep the Command Prompt profile active.
2. Type: ssh -p 22 sshtest@SERVER
3. Confirm that Host, Port and Username are prefilled. Supply the trusted
   SHA256 fingerprint and dedicated private key, then press Connect.
4. Verify Croatian text, resize, scrollback, htop and nano as before.
5. Run exit. VT7 must print its return line and the original local prompt must
   resume in the same terminal document.
6. Run the same ssh command a second time to prove sequential handoffs.
7. During a third connection press Disconnect SSH. The local shell must resume
   and receive status 255.
8. Repeat one normal connect/exit from Windows PowerShell 5.1 and PowerShell
   7.2.24.
9. Run ssh -V. Unsupported syntax must use the installed external OpenSSH.
10. Run ssh-system -V. The explicit escape hatch must do the same.

Eligible embedded grammar is interactive only: -4, -6, -l user, -p port,
-i key and [user@]host. Remote commands, redirection and unsupported options go
to the exact hashed external client. Credentials stay in the WPF dialog and are
never sent through the shim or written to default diagnostics.
