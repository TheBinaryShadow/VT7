VT7 SSH.NET direct profile 0.4
================================

This package is the first production-session integration of the accepted
SSH.NET 2026.0.0 backend. It adds a direct SSH.NET root transport to VT7 0.8.2.
Ordinary typed ssh interception remains disabled.

AUTOMATED CHECK

1. Extract the complete archive into a new writable directory.
2. Run RUN-SSHNET-FOUNDATION.cmd without elevation.
3. If it fails, return the complete Logs directory.

The automated check makes no network connection and handles no credentials. It
verifies the exact locked runtime closure, strict fingerprint input, root-session
ownership, cell/pixel geometry, resize ordering and secret-owner lifetime.

CONTROLLED SERVER CHECK

1. Run RUN-VT7-SSHNET-DIRECT.cmd.
2. Press Start SSH....
3. Enter the controlled server host, port, username and trusted SHA256 host-key
   fingerprint obtained through the separate administrative path.
4. Select Private key and browse to the dedicated key, entering its passphrase
   only if it is encrypted. Password authentication is also available for the
   controlled account.
5. Press Connect. A mismatched host key must stop before authentication.

Suggested bounded manual checks after the remote prompt appears:

  printf 'VT7 SSH ćčžšđ\n'
  stty size
  python3 -c "print(''.join(str(i)+'\\n' for i in range(1,201)),end='')"

Resize the VT7 window, run stty size again, verify scrollback and Croatian text,
then run exit. The remote root session should close while its scrollback remains.
Start a local profile afterward and verify it opens normally. Also reconnect once
and close VT7 while the remote shell is idle to exercise stream-first shutdown.

SECURITY AND CURRENT SCOPE

The trusted fingerprint is mandatory and compared before authentication. The
dialog values, key path, fingerprint and credentials are not written to default
diagnostics. Passwords and key passphrases are not persisted. The package uses
SSH.NET 2026.0.0 and the exact permissive dependency closure accepted by S01.

This slice is deliberately a direct profile. Persistent known-host management,
agent and keyboard-interactive authentication, reconnect UX, SSH overlay state
normalization, and ordinary typed ssh handoff remain later Milestone 5 work.
