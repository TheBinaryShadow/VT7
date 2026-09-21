# Typed SSH.NET overlay coordinator

Date: 2026-09-21. Status: package 0.1 rejected at worker-thread geometry;
package 0.2 accepts that correction with a real Windows 7 connection but is
rejected at the accepted-session completion lifetime; version 0.9.2/package 0.3
passes locally and on the controlled Windows 7 target and is accepted.

## Implemented boundary

VT7 0.9.0 connects the accepted H01 shim/barrier path to the accepted SSH.NET
transport. Each local WinPTY profile receives a session-scoped authenticated
broker and a private shim-first `PATH`. Eligible interactive `ssh` invocations
retain their originating shell process while a structured WPF dialog owns
destination confirmation, mandatory SHA256 host-key trust and ephemeral
private-key/passphrase or password input. Credentials never enter the shim pipe
or default diagnostics.

The broker now serves sequential invocations from one root session. It retains
the H01 PID, creation-time, ancestry, console association, HMAC, grammar and
exact hashed-fallback checks. After the unique connecting line has committed
through WinPTY and `SessionOutputPump`, the coordinator starts an SSH.NET
overlay in the existing `TerminalDocument`. Ordinary input moves to the overlay;
authoritative resize reaches both live transports; root output remains drained.
Remote EOF, connection failure or **Disconnect SSH** closes only the overlay,
adds a host-owned result line and returns a fresh input generation to the local
shell. The waiting shim then returns 0 for clean EOF or 255 for failure/cancel.

The eligible grammar remains H01's interactive `-4`, `-6`, `-l`, `-p`, `-i`
and `[user@]host` subset. `-4` and `-6` constrain DNS/address selection before
SSH.NET connects. Unsupported or ambiguous syntax and `ssh-system` use the exact
absolute external client whose SHA256 was captured when the profile started.

## Rejected Windows 7 package 0.1

`VT7-SSHNET-Overlay-0.1-x64.zip`, SHA256
`F53326B898B6544798E10D30E895D1D389BECC1C590C3D1B9961508E51262A5E`,
15,230,388 bytes and 91 verified files passed the complete automated Windows 7
run. That result proves the package identities, session stream/outbound
foundations, SSH.NET offline contract, authenticated H01 request, committed
WinPTY barrier and exact fallback behavior on the target.

The following production check rejected the package. Repeated
`ssh -p 22 sshtest@10.3.3.254` invocations from Windows PowerShell 5.1 opened the
structured dialog, committed the unique H01 connecting line and returned status
255 to the same local prompt. The direct **Start SSH...** profile continued to
connect with the same endpoint and authentication material.

The overlay-only failure occurred before SSH.NET network startup.
`SshOverlayCoordinator` handles an authenticated request on a broker worker,
while `TerminalSession.StartOverlayAsync` directly read the dispatcher-owned
`TerminalDocument` and WPF viewport geometry. The direct-root path starts on the
UI thread, explaining the otherwise identical path's success. Returned logs and
the production-failure screenshot are archived under
`artifacts/vt7/evidence/sshnet-overlay-win7-0.1-rejected`.

## Version 0.9.1 package 0.2: dispatcher accepted, lifetime rejected

`TerminalSession` now creates root and overlay start contexts through the
document dispatcher. This keeps native document reads and the viewport pixel
callback on their owning WPF thread regardless of the transport caller. The
session regression starts an overlay from `Task.Run`, requires the geometry
callback to observe dispatcher access and checks the exact 640 by 384 pixel
geometry delivered to the fake overlay. Connection failures also report a
privacy-safe stage category in the terminal instead of only a generic status.

Debug and Release x64 builds pass. The combined runner passes the session
stream/ownership and native-input corpora, SSH.NET foundation, full H01 corpus,
staged Windows PowerShell launch from a path containing spaces, dependency and
notice checks, per-file hashes and independent ZIP-entry verification. The
session regression includes a split committed marker, overlay resize delivery
to both root and overlay, and worker-thread dispatcher capture.

Candidate: `VT7-SSHNET-Overlay-0.2-x64.zip`, version 0.9.1, SHA256
`65FF2E09F83758D8E86A78CC08B3409D2D18BE04B85BA901799A318DBE34AD7C`,
15,194,306 bytes, 91 verified files. The review copy is
`artifacts/VT7-SSHNET-Overlay-0.2-x64.zip`.

Its complete automated Windows 7 corpus passes. A production typed connection
then reaches the Debian 12 shell and remains interactive, accepting the package
0.1 dispatcher correction and the actual SSH.NET overlay start. After roughly
five seconds, the shim prints `pipe read timed out (Win32 997)` and returns the
local prompt while VT7 still routes input to the active remote overlay. Remote
`exit` prints VT7's return line but leaves the host indefinitely in the
disconnecting state without reopening root input.

The shim used one five-second timeout for every protocol read, including the
`Complete` frame that intentionally spans the full interactive remote session.
Its early exit closes the pipe. Later, the broker cannot write completion to the
vanished shim, and its root-resume callback was sequenced after that successful
write. Returned logs and four screenshots are archived under
`artifacts/vt7/evidence/sshnet-overlay-win7-0.2-rejected`.

## Version 0.9.2 accepted package 0.3

Connection, challenge, request, response and barrier I/O retain their five-second
bounds. Only the post-acceptance `Complete` read now waits for the embedded
session lifetime. It still wakes immediately when the host closes the pipe. The
broker invokes its embedded-completion/root-resume callback in a `finally` block
around completion delivery, so a missing shim cannot leave root input closed.

H01 now holds a real accepted shim for six seconds before completing. This
crosses the old timeout using the actual native shim, WinPTY root, authenticated
broker and committed barrier. Debug and Release builds pass, as do the combined
session stream/outbound, SSH.NET foundation and H01 corpus, staged PowerShell
batch launch, dependency/notice audit and independent ZIP verification.

Accepted package: `VT7-SSHNET-Overlay-0.3-x64.zip`, version 0.9.2, SHA256
`CAF09834CA1F7F025D96CC07D5F60AF8663C2F2167AA964EAB98D3AF3865B0DB`,
15,196,580 bytes, 91 verified files. The review copy is
`artifacts/VT7-SSHNET-Overlay-0.3-x64.zip`.

## Superseded local verification for package 0.1

Debug and Release x64 builds pass. The combined runner passes the session
stream/ownership and native-input corpora, SSH.NET foundation, full H01 corpus,
staged Windows PowerShell launch from a path containing spaces, dependency and
notice checks, per-file hashes and independent ZIP-entry verification. The
session regression includes a split committed marker and overlay resize delivery
to both root and overlay.

The original local candidate was `VT7-SSHNET-Overlay-0.1-x64.zip`, SHA256
`F53326B898B6544798E10D30E895D1D389BECC1C590C3D1B9961508E51262A5E`,
15,230,388 bytes, 91 verified files. The review copy is
`artifacts/VT7-SSHNET-Overlay-0.1-x64.zip`.

## Accepted Windows 7 result for package 0.3

The owner ran `RUN-SSHNET-OVERLAY.cmd` and the complete controlled-server matrix
from the package `README.txt`. The automated overlay corpus passes. A typed
connection remains active beyond the former five-second boundary without a
timeout or premature local prompt. Normal remote `exit` returns to an immediately
usable originating prompt. The second sequential handoff, explicit disconnect
and status 255, Command Prompt, Windows PowerShell 5.1, PowerShell 7.2.24,
Croatian text, resize and scrollback, `htop`, `nano`, unsupported `ssh -V`, and
explicit `ssh-system -V` fallback all pass without a reported defect.

This accepts the production typed SSH.NET overlay on the controlled Windows 7
configuration. It does not close the broader full-screen application, mouse,
clipboard, reconnection, known-host storage, or release-hardening work in
Milestone 5.
