# SSH.NET direct-profile transport

Status date: 2026-09-19.

VT7 0.8.0 implements the first production-session use of the S01-accepted
SSH.NET 2026.0.0 backend. It is deliberately exposed as a separate **Start
SSH...** direct root profile while its Windows 7 network behavior is qualified.
Ordinary typed `ssh` interception remains disabled, so this checkpoint cannot
silently redirect a local shell command to an unqualified backend.

## Implemented boundary

`SshNetTransport` implements the existing ABI 11 `ITerminalTransport` contract.
It creates one SSH.NET `ShellStream` with terminal type `xterm-256color`, the
authoritative TerminalCore columns and rows, and the native viewport's actual
pixel width and height. Resize operations are serialized with input writes and
send both cell and pixel geometry through `ChangeWindowSize`.

The transport has one blocking output reader. Each read becomes an ordered
generation-tagged `TerminalOutputBlock` of at most 64 KiB and enters the same
session decoder, TerminalCore document, Atlas view and scrollback as a local
WinPTY root. Input, control bytes and terminal replies use the existing bounded
outbound queue. No SSH.NET object is owned by the WPF window or native HWND.

The first direct-profile UI collects host, port, username, a mandatory trusted
SHA256 host-key fingerprint, and either a private key with optional passphrase or
a password. `HostKeyReceived` compares the normalized fingerprint in fixed time
and sets `CanTrust` before authentication can complete. No trust-on-first-use or
silent acceptance exists in this slice. Connection errors expose only a bounded
stage/category and do not include the endpoint, username, key path, fingerprint
or credential.

Passwords and passphrases enter through WPF `PasswordBox` and are held by an
owned `SecureString` option. SSH.NET requires a managed string at its
authentication constructor boundary; VT7 creates it only while building the
authentication method, zeroes the intermediate BSTR, drops the string reference,
and disposes the owned secret, private-key object and connection objects during
transport teardown. Secrets and connection fields are not persisted or written
to the default diagnostics.

Shutdown is stream-first. VT7 closes the shell stream, waits up to five seconds
for the sole reader to finish, then disconnects and disposes the client. A reader
that does not finish produces forced termination. Remote EOF is distinguishable
from a connection failure. SSH.NET does not expose a reliable interactive-shell
exit status through this path, so this checkpoint does not invent one.

## Dependency and package boundary

The application and the S01 diagnostic use the same locked net48 closure from
`src/vt7/VT7.SshNetProbe/packages.lock.json`. The host now has an identical lock
file and an exact `[2026.0.0]` SSH.NET reference. Restore verifies the previously
audited NuGet hashes. The package carries every MIT, Apache-2.0, ISC-style and
supplier notice accepted in the project-wide dependency decision and records the
exact component hashes in its manifest.

The issued local candidate is:

- archive: `VT7-SSHNET-Direct-0.1-x64.zip`;
- SHA256: `764840E82E9979A82BC1C58850E0961B14B67556568FA89157BD56540A95724B`;
- size: 14,458,736 bytes;
- verified files: 82;
- application: 0.8.0, native ABI 11, x64;
- backend: SSH.NET 2026.0.0 and the exact accepted thirteen-package closure;
- review copy: `artifacts/VT7-SSHNET-Direct-0.1-x64.zip`.

The package verifier checks the x64 native images and permits an x86 PE machine
field only when the image has a nonzero CLR COM descriptor, which is the normal
AnyCPU encoding used by the managed dependency closure. OS/subsystem version and
forbidden-import checks still apply to every executable and DLL.

## Local result

The following completed on the development host before issuing package 0.1:

- locked SSH.NET restore for Debug and Release host plus diagnostic projects;
- Debug and Release `VT7.sln` builds with no Release warnings;
- Debug and Release SSH.NET foundation checks;
- Release session-outbound, session-stream, WinPTY-session, PowerShell-profile
  and H01 regressions;
- recursive staged PE/import/runtime/license audit;
- staged offline SSH.NET foundation test;
- independent ZIP entry, length and SHA256 verification;
- byte-for-byte hash agreement between the package output and review copy.

The offline foundation test makes no network connection. It verifies exact
runtime closure loading, strict fingerprint validation, a direct-root session,
authoritative cell/pixel start geometry, ordered resize geometry, and transfer
and disposal of the credential owner.

## Required Windows 7 result

Extract the archive into a new writable directory and run
`RUN-SSHNET-FOUNDATION.cmd`. Return its complete `Logs` directory if it fails.
Then run `RUN-VT7-SSHNET-DIRECT.cmd`, press **Start SSH...**, and use the
controlled Debian 12 account with a host-key fingerprint obtained through the
separate administrative path. Prefer the dedicated private key for the first
run; the dialog also supports password authentication for a bounded follow-up.

After the remote prompt appears, run:

```sh
printf 'VT7 SSH ćčžšđ\n'
stty size
python3 -c "print(''.join(str(i)+'\\n' for i in range(1,201)),end='')"
```

Resize the VT7 window and run `stty size` again. Confirm Croatian text, input,
scrollback during and after output, and normal `exit`. The remote root should
close while its scrollback remains visible. Start a local profile afterward to
confirm isolation. Reconnect once and close VT7 while the remote shell is idle
to exercise stream-first shutdown. A separate negative attempt with one changed
fingerprint character must fail before authentication.

Do not return a password, passphrase, private key or unredacted endpoint. The
default logs are designed not to contain them, but review returned material
before preserving it as evidence.

## Acceptance boundary and next work

Package 0.1 proves the source, locked dependency, application integration and
offline lifecycle contracts locally. The direct SSH profile is not Windows 7
accepted until the controlled-server checks above pass on the target. Typed
`ssh` remains disabled until direct trust/authentication, PTY/resize,
input/output, shutdown and local-profile isolation are accepted.

After direct-profile acceptance, implement the overlay coordinator and trust/
authentication prompt ownership defined by the 3A specification. Only then may
the accepted H01 shim reply `USE_EMBEDDED` for eligible typed commands. Persistent
known-host management, keyboard-interactive and agent authentication, reconnect
UX and broader SSH configuration remain later Milestone 5 work.
