# SSH startup phase budgets: SL01.2

Date: 2026-10-11. Managed application 0.15.0, native ABI 11.
Status: bounded SL01.2 accepted on LEOPARD, NESSY and TURTLE; see the
[validation record](../validation/2026-10-11-ssh-startup-phase-deadlines-sl01-2.md).
Builds on accepted [SL01.1](2026-10-05-ssh-lifecycle-sl01-spec.md).
Evidence and issued candidate identity belong to the
[validation record](../validation/2026-10-11-ssh-startup-phase-deadlines-sl01-2.md).

## Contract

An owned monotonic watchdog records the automatic startup phase, cancels its
operation token on expiry and rejects late results before advancing or
publishing Running. Expiry is ConnectionFailure/status 255, with a fixed phase
category. User/session cancellation remains Cancelled/status 255. Neither
restarts the originating shell or replays submitted input.

The phase budget is 15 seconds in production. Internal diagnostics can shorten
it; there is no production CLI timeout/resolver override. Budgets start anew
only at genuine phase boundaries. Repeated or stale protocol callbacks cannot
reset a later phase's deadline. Once expired, a watchdog cannot be revived.

| Phase | Boundary and coverage |
| --- | --- |
| Address-family resolution | Explicit IPv4/IPv6 lookup; literal family validation bypasses DNS. |
| Known-host loading | Initial snapshot and connect-once snapshot revalidation. |
| Authentication setup | Local password/key/passphrase setup before network startup. |
| DNS, TCP or SSH identification | SSH.NET ConnectAsync until its public ServerIdentificationReceived event. For the Any-family path the library owns DNS; these activities are honestly grouped. |
| Key exchange and host-key verification | Identification event until a successfully verified, policy-authorized HostKeyReceived callback. |
| Authentication | After the trusted callback; includes remaining initial key-exchange completion, authentication-service acceptance and authentication. The public API does not delimit each of these separately. |
| Remote PTY allocation | CreateShellStream, including channel creation, PTY request and shell request. |
| Durable trust update | Existing atomic user-authorized known_hosts addition after the human decision. |

Retain the pinned SSH.NET ConnectAsync 15-second cancellation budget. It spans several
network phases and may expire before a restarted phase's full budget. Retain
the five-second channel-close operation limit and existing keepalive behavior.
No startup timer remains armed once Running is published.

## Human decisions and ownership

Stop phase timing before disposing an unsuccessful connection and presenting
unknown-key trust or changed-key review. No automatic network deadline runs
while the user decides; the caller/session cancellation token remains active.
Validate the response's session/transport/connection/prompt/store identities
before applying it. A cancelled or stale decision cannot connect a later
session. Begin a fresh automatic phase when local validation or reconnection
starts. Initial credential collection remains outside transport startup.

The watchdog itself is an owned task: startup stops and joins it in finally,
then releases its linked cancellation objects. Shutdown still joins startup,
the ordered writer and reader before disposal. Never race a resource-owning
operation against a timeout and abandon the loser. Timer callbacks do not
dispose the client concurrently with connection or PTY creation.
Cache the operation token before teardown so an in-flight public callback can
query cancellation after its source is disposed. Its phase advance still fails
once the watchdog has stopped.

Trust-file mutation retains the accepted atomic transaction semantics. Expiry
does not roll back an already committed, explicitly authorized trust addition.
Reject subsequent connection startup after expiry; a later attempt reloads the
store normally. No trust decision is inferred from arbitrary remote output.

## Limits and follow-up

This is a deadline for accepting a phase result, not a hard deadline for every
operation to return. The .NET Framework 4.8 reference API exposes
GetHostAddressesAsync(String), without a CancellationToken overload; the current
Windows 7 resolver and synchronous local file work are joined until completion.
Pinned SSH.NET also has synchronous KEX/authentication/channel waits. Expiry
cancels token-aware parts immediately, but synchronous work can outlast it.
The WPF dispatcher remains free during this ownership cleanup.

The exact pinned [BaseClient](https://github.com/sshnet/SSH.NET/blob/f099365c9d4cf2ade92b92c203bbb2b345d2cd74/src/Renci.SshNet/BaseClient.cs)
and [Session](https://github.com/sshnet/SSH.NET/blob/f099365c9d4cf2ade92b92c203bbb2b345d2cd74/src/Renci.SshNet/Session.cs)
copies reviewed for SL01.1 remain the implementation evidence. Microsoft's
[cancellation discussion](https://devblogs.microsoft.com/dotnet/how-do-i-cancel-non-cancelable-async-operations/)
also distinguishes cancelling an operation from ceasing to await its result.
The installed net48 reference System.xml was checked directly for the DNS API;
current multi-target API pages must not be mistaken for net48 cancellation support.

Real DNS completion/shutdown bounds and stalled authenticated authentication/PTY
must receive a separate controlled-server qualification and, if necessary, a
different cancellation boundary. Do not mark those gates accepted here.
Partial/stalled I/O, final drain, silent loss/keepalive policy, rekey under output,
remote exit status, agent/keyboard-interactive and terminal-only interaction
remain subsequent SL01/SSHUX01 work. Unicode/font parity remains UT01.

## Verification

The existing --ssh-lifecycle-test includes real pinned-library loopback peers
for silent identification and stalled KEX, shortened phase clocks with longer
library timeouts, safe timeout classification, and owned cleanup. It also runs
a production-limit typed Command Prompt timeout and verifies status 255 and
the original root PID. Previous refusal/cancellation/window/outbound checks stay.

An injected noncancellable resolver checks ownership and late-result rejection
on expiry and caller cancellation. A slow synchronous known-host loader checks
the same rule before networking. Deadline-policy checks cover local/auth/PTY
phases, pause/resume, caller cancellation during pause, and stale callbacks.
These policy seams do not simulate a fully authenticated stalled server or
establish the real OS DNS latency bound.

Run the eight-stage portable runner through PS5.1, PS2, CMD and independently
extracted paths with spaces. Verify inventory, closure hashes and ZIP contents.
Then qualify ordinary typed/direct SSH, normal exit, disconnect, TUIs/resize
and pending/active shutdown on LEOPARD, NESSY and TURTLE. Use 10.3.3.2:22;
the KH01.5 certificate fixture need not run. Return complete logs even on success.
