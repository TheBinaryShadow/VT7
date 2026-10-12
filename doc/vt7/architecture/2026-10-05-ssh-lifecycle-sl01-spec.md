# SSH lifecycle SL01: owned startup, failure and shutdown

Status: SL01.1 implemented in managed application 0.14.0/native ABI 11.
Local/target validation and candidate identity belong to the
[SL01.1 validation record](../validation/2026-10-05-ssh-lifecycle-sl01-1.md).
Accepted on LEOPARD, NESSY and TURTLE on 2026-10-05. This is a bounded first slice of Milestone 5's
larger lifecycle gate, following accepted KH01.1-KH01.5.
Successor [SL01.2](2026-10-11-ssh-startup-phase-deadlines-sl01-2.md) adds startup
phase budgets in 0.15.0 and is accepted on all three Windows 7 tiers.
[SL01.3](2026-10-12-ssh-authenticated-startup-stalls-sl01-3.md) adds real
authentication/PTY fault qualification in 0.16.0, with target acceptance pending. The behavior and
acceptance described below retain SL01.1's original scope.

## Library boundary and scope

Keep the accepted publisher-built SSH.NET 2026.0.1-prerelease.6 closure at
commit f099365c9d4cf2ade92b92c203bbb2b345d2cd74. Review of the pinned
[BaseClient](https://github.com/sshnet/SSH.NET/blob/f099365c9d4cf2ade92b92c203bbb2b345d2cd74/src/Renci.SshNet/BaseClient.cs),
[Session](https://github.com/sshnet/SSH.NET/blob/f099365c9d4cf2ade92b92c203bbb2b345d2cd74/src/Renci.SshNet/Session.cs)
and [ShellStream](https://github.com/sshnet/SSH.NET/blob/f099365c9d4cf2ade92b92c203bbb2b345d2cd74/src/Renci.SshNet/ShellStream.cs)
establishes these implementation constraints:

- ConnectAsync accepts cancellation, but startup also contains synchronous
  protocol/authentication waits and synchronous PTY/shell allocation. Caller
  cancellation alone cannot establish immediate, end-to-end startup abortion.
- ShellStream.Read may end when the stream is disposed following a connection
  error. Retain public client/stream ErrorOccurred notifications to distinguish
  an observed connection failure from normal channel EOF. ShellStream.Closed
  is dispatched asynchronously for channel close, so EOF processing allows up
  to five seconds for that notification before declaring connection failure.
- ShellStream write, flush and window-size requests are synchronous operations.
  Execute them off the WPF dispatcher while preserving the single ordered writer.
- The public shell-stream interface does not supply a remote process exit code.
  Do not fabricate nonzero exit-status coverage or add private protocol
  reflection for this slice. The existing 0/255 shim contract remains.

The normal connection operation timeout is 15 seconds and channel-close timeout
is 5 seconds. These apply to library operations, not a single wall-clock deadline
for DNS, all protocol phases, prompts and shutdown combined. Keepalive traffic
does not establish a bounded silent-network-loss detector.

## Ownership and transitions

SshNetTransport records Starting and its generation before queuing an owned
startup worker. Register the caller's cancellation before network startup, and
link it to transport lifetime cancellation. All close callers join one cached
close task. Cancel lifetime, join startup, serialize stream close against outbound
operations and wait up to five seconds for the reader. Report forced termination
if it cannot settle; retain its coordination objects until it finishes. A
cancelled close waiter cannot abandon ownership cleanup.

Check cancellation after connect and before publishing Running. The close reason
also guards publication under the transport gate. A close during startup cannot
publish a later running transport. Register the client error callback before
connecting, retain the first observed error, detach handlers during cleanup and
report bounded categories rather than raw exception text to terminal users.
An observed channel close wins over a subsequent whole-connection disconnect;
this preserves normal remote exit. No channel-close notification after EOF
means failure. Local cancellation interrupts the notification wait. The live
target checks must confirm normal remote exit and detected loss separately.

TerminalSession owns an overlay while it is StartingOverlay, not only after it
becomes RunningOverlay. Session close cancels pending startup and closes both
the pending overlay and root. Startup failure may not resurrect a session that
is Closing/Closed. A failed outbound queue is retired even when its completion
is faulted; submitted bytes are never copied into the recovered root queue.
Startup publication, recovery and the transition to Closing use the same
session gate. Close retains a pending overlay until startup cleanup has settled.

For typed SSH, both successful remote completion and startup failure keep local
input suspended in StoppingOverlay until the broker attempts the authenticated
COMPLETE frame. Its existing finally callback resumes the original root even
when completion delivery loses the shim. Only then allocate a new root outbound
generation. Return failure/cancellation as status 255, without restarting the
root process. Standalone session tests can retain immediate failure recovery.

Startup continuations must await transport close before synchronous Dispose.
Blocking in a startup continuation can prevent another continuation from
finishing the close that is joining that same startup worker.

MainWindow records a pending session during replacement/startup. OnClosing
defers actual window destruction, detaches input and awaits active/pending
session shutdown while the dispatcher continues processing. OnClosed releases
the viewport and document. A pending start checks window closure before any
presentation attachment. Keep current proof UI until UI01/SSHUX01 replaces it;
this slice does not introduce a final SSH shortcut or profile.

## Verification and acceptance

The --ssh-lifecycle-test diagnostic uses actual pinned-library loopback peers
that stop before host-key exchange or authentication. Test a silent banner
deadline, caller cancellation, explicit startup close, stalled KEX, unsupported
protocol, session/window close during startup, faulted outbound retirement, and
real typed-shim recovery after refusal/cancellation. Check original root PID,
new input generation and status 255. Test short operation limits through an
internal diagnostic-only seam; typed tests exercise the normal 15-second limit.

Every asynchronous check has a watchdog. The target runner verifies the complete
package inventory, .NET 4.8 and host identity, records OS/engine hashes and runs
the affected stream/outbound/WinPTY/window/SSH/certificate regressions. It works
on PowerShell 2.0 without system OpenSSH. PS2's interactive editor remains
unqualified; exact PS5.1 and PS7.2.24 are the qualified PowerShell shell corpus.

Accept SL01.1 after complete passing client reports and ordinary live SSH
observations on LEOPARD, NESSY and TURTLE. Use server 10.3.3.2 port 22; KH01.5
certificate listeners are unnecessary. Verify repeated typed connections,
normal exit, explicit disconnect, detected connection loss, input/resize/TUIs,
and window close during startup/active SSH. Record interruption method and
elapsed time. Preserve the already accepted known-host policy and privacy.

## Remaining SL01 work

Keep the broad roadmap lifecycle gate open. Subsequent bounded slices must
design and qualify phase-specific overall deadlines (including DNS/prompts),
partial/stalled I/O and final-output drain, silent loss/keepalive detection,
rekey under sustained output, accurate remote exit-status handling and recovery
UX. Do not infer those results from these loopback checks. Agent and
keyboard-interactive authentication, the broader TUI corpus and terminal-only
SSH prompts remain distinct approved requirements.
