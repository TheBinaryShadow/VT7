# SSH.NET direct-profile transport

Status date: 2026-09-21.

VT7 0.8.0 implements the first production-session use of the S01-accepted
SSH.NET 2026.0.0 backend. It is deliberately exposed as a separate **Start
SSH...** direct root profile while its Windows 7 network behavior is qualified.
Ordinary typed `ssh` interception remains disabled, so this checkpoint cannot
silently redirect a local shell command to an unqualified backend.

The complete package 0.2 direct-profile matrix is accepted on Windows 7 as of
2026-09-21. Version 0.8.1/package 0.3 corrected the form labels but its focused
visual check exposed the selected Authentication item as the remaining
light-on-light text. Version 0.8.2/package 0.4 gives the generated selector item
an explicit dark template and tests the rendered selection. Its focused Windows
7 visual check passes; the complete direct-profile checkpoint is accepted.

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

The accepted transport candidate is:

- archive: `VT7-SSHNET-Direct-0.2-x64.zip`;
- SHA256: `5D11B42D94835C946E45D8ED8D9D261B2F3812E49FA293AB7EE9FB9430BB78D5`;
- size: 14,458,800 bytes;
- verified files: 82;
- application: 0.8.0, native ABI 11, x64;
- backend: SSH.NET 2026.0.0 and the exact accepted thirteen-package closure;
- review copy: `artifacts/VT7-SSHNET-Direct-0.2-x64.zip`.

The first UI-only follow-up candidate was:

- archive: `VT7-SSHNET-Direct-0.3-x64.zip`;
- SHA256: `04C56F61FF3A23C52DB89E70A153A61932C37E4C59DE3323B9D2B376E8721D96`;
- size: 14,465,404 bytes;
- verified files: 82;
- application: 0.8.1, native ABI 11, x64;
- change: local black-on-white SSH form text scope plus automated 4.5:1 contrast
  verification;
- review copy: `artifacts/VT7-SSHNET-Direct-0.3-x64.zip`.

Package 0.3 passes its Windows 7 foundation test and fixes the ordinary form
labels, but its visual check rejects the still-light selected Authentication
item. The returned foundation log, environment record, screenshot and archive
metadata are preserved under
`artifacts/vt7/evidence/sshnet-direct-win7-0.3-contrast-rejected`.

The accepted UI-only correction is:

- archive: `VT7-SSHNET-Direct-0.4-x64.zip`;
- SHA256: `FA4B2054EA9B68D4E78EE43FB838F358F2CD87D13F5B06A385ACC497B0D1BD46`;
- size: 14,459,542 bytes;
- verified files: 82;
- application: 0.8.2, native ABI 11, x64;
- change: explicit black authentication-item template plus rendered-selection
  4.5:1 contrast verification;
- review copy: `artifacts/VT7-SSHNET-Direct-0.4-x64.zip`.

The package verifier checks the x64 native images and permits an x86 PE machine
field only when the image has a nonzero CLR COM descriptor, which is the normal
AnyCPU encoding used by the managed dependency closure. OS/subsystem version and
forbidden-import checks still apply to every executable and DLL.

## Local result

The following completed on the development host before issuing package 0.2:

- locked SSH.NET restore for Debug and Release host plus diagnostic projects;
- Debug and Release `VT7.sln` builds with no Release warnings;
- Debug and Release SSH.NET foundation checks;
- Release session-outbound, session-stream, WinPTY-session, PowerShell-profile
  and H01 regressions;
- recursive staged PE/import/runtime/license audit;
- staged offline SSH.NET foundation test through the actual CMD launcher from a
  temporary package path containing spaces;
- independent ZIP entry, length and SHA256 verification;
- byte-for-byte hash agreement between the package output and review copy.

The offline foundation test makes no network connection. It verifies exact
runtime closure loading, strict fingerprint validation, a direct-root session,
authoritative cell/pixel start geometry, ordered resize geometry, and transfer
and disposal of the credential owner.

## Rejected Windows 7 package 0.1

The first Windows 7 attempt stopped before creating `Logs`. The application and
foundation executable did not start. `RUN-SSHNET-FOUNDATION.cmd` passed the
package directory as quoted `%~dp0`, whose final backslash interfered with the
Windows PowerShell 5.1 native argument boundary. `BinaryDirectory` therefore
contained characters from the following switch, and `Path.GetFullPath` rejected
it as an illegal path.

Package 0.2 changes that argument to the established `%~dp0.` form, adds a
test-only no-pause/output override, and makes packaging execute the actual CMD
launcher from a path containing spaces. That batch regression passes before the
archive is created. Application binaries, SSH.NET transport behavior and ABI are
unchanged from package 0.1.

## Accepted Windows 7 package 0.2 result

The owner reports that package 0.2's automated foundation check and full direct
SSH matrix pass on the Windows 7 target. Connection, strict trust and
authentication, PTY allocation, initial/live size, Croatian text, sustained
output, scrollback, normal exit, reconnect, idle-close and local-profile
isolation completed without a transport issue.

The required command checks included:

```sh
printf 'VT7 SSH ćčžšđ\n'
stty size
python3 -c "print(''.join(str(i)+'\\n' for i in range(1,201)),end='')"
```

The owner additionally ran `htop` and `nano` in a separate connection. Both
full-screen applications worked without an observed rendering, input,
alternate-screen, resize or lifecycle defect. This extends the required matrix
but does not replace later broad TUI/mouse/clipboard qualification.

The only reported defect is low text contrast in the **Start SSH session**
dialog. The white dialog inherited VT7's application-wide light-on-dark
`TextBlock` style, producing white text on a white surface. Transport content and
behavior were unaffected. The later package 0.3 foundation log, environment
record and screenshot are hash-archived with the rejected UI result described
above. The earlier package 0.2 network evidence remains recorded from the
owner's explicit report because its raw files were unavailable during that update.

Version 0.8.1 gives the dialog a local black-on-white `TextBlock` style. Its
foundation test walks the logical form text and requires at least 4.5:1 contrast
against the dialog surface. Package 0.3 passes that check on Windows 7 and the
ordinary labels become readable, but the screenshot shows **Private key** in the
closed Authentication selector still using the application light foreground.
WPF creates that selected text inside the `ComboBox` visual template, outside
the logical-label traversal, so the first automated assertion did not cover it.

Version 0.8.2 gives the authentication choices an explicit black item template.
The foundation check now lays out the real selector visual tree, finds the
rendered selected **Private key** text and requires that foreground to meet the
same 4.5:1 threshold. Debug and Release builds, Debug and Release foundation
checks, session-outbound, session-stream, WinPTY, PowerShell, H01, target-style
CMD launch, binary audit and ZIP verification all pass. The owner confirms on
Windows 7 that the closed Authentication selection and the opened choices are
all readable and look correct. Package 0.4 therefore closes the contrast defect.
The accepted SSH network matrix did not need repeating.

Do not return a password, passphrase, private key or unredacted endpoint. The
default logs are designed not to contain them, but review returned material
before preserving it as evidence.

## Acceptance boundary and next work

Package 0.2 accepts the first direct SSH.NET root on Windows 7. Package 0.4 is
the accepted UI-only contrast correction; it does not reopen that transport result.
Typed `ssh` remains disabled because overlay coordination and return-to-local-shell
behavior have not yet been implemented and accepted.

After direct-profile acceptance, implement the overlay coordinator and trust/
authentication prompt ownership defined by the 3A specification. Only then may
the accepted H01 shim reply `USE_EMBEDDED` for eligible typed commands. Persistent
known-host management, keyboard-interactive and agent authentication, reconnect
UX and broader SSH configuration remain later Milestone 5 work.
