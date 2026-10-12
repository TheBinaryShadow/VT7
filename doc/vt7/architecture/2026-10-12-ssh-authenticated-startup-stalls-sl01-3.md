# SSH protocol startup stalls: SL01.3

Date: 2026-10-12. Managed application 0.16.0, native ABI 11.
Status: implemented; paired Windows 7 target acceptance pending.
Baseline: accepted [SL01.2](../validation/2026-10-11-ssh-startup-phase-deadlines-sl01-2.md).
Evidence: [SL01.3 validation](../validation/2026-10-12-ssh-authenticated-startup-stalls-sl01-3.md).

## Purpose and boundary

Replace SL01.2's authentication/PTY policy-only evidence with controlled, real
SSH protocol exchanges. Authentication stalls happen after key exchange and
host-key verification; PTY stalls happen after authenticated session-channel
opening. Qualify the existing pinned SSH.NET transport without replacing its
library, introducing private protocol reflection or abandoning synchronous work.
This slice adds a diagnostic and its fixture, not a new production transport.

The existing 15-second phase clocks and library operation limits stay intact.
For the late-result cases only, an existing internal diagnostic seam shortens
the phase clock to three seconds while retaining the 15-second library limit.
A reply at six seconds can therefore complete the synchronous operation after
the phase expires. It must be rejected before Running or remote output delivery.
Caller cancellation and explicit close similarly retain ownership until the
held operation settles. No hard 15-second end-to-end return bound is claimed.

## Isolated protocol peer

Use Debian 13's server-only python3-paramiko package (3.5.1), rather than alter
the normal OpenSSH service or run a test account's real shell. The same helper
is exercised locally with Paramiko 3.5.1 and a loopback address. Its seven
unprivileged listeners bind a supplied IPv4 address; the normal service at
10.3.3.2:22 and the stopped KH01.5 fixture remain unchanged.

The [Paramiko ServerInterface documentation](https://docs.paramiko.org/en/3.5/api/server.html)
provides public authentication, PTY and shell-request callbacks. Blocking these
callbacks is expressly unsuitable for normal server operation. Here it is
intentional, bounded fault injection to withhold a specific SSH reply. Paramiko
retains signature verification; the helper only checks the supplied public key.
The [transport API](https://docs.paramiko.org/en/3.5/api/transport.html) supplies
server negotiation, authenticated state, channels and owned shutdown.
Debian's [package record](https://packages.debian.org/trixie/python3-paramiko)
identifies 3.5.1-3. This dependency is neither packaged for Windows nor a new
minimum requirement for VT7.

Preparation creates a new directory, private RSA host key, authorized client
public key and public client.fixture with a random ID, literal address, port
range, synthetic username prefix, host public key and seven-day expiry. No
private client material goes to the server. Transfer client.fixture by a trusted
path. The client pins that key in a temporary diagnostic known-host store;
it never mutates actual .ssh files or requires a trust popup for these cases.

Every connection names a random client RunId and fixed case in its synthetic
username. These are protocol identities, not Linux accounts. Only the dedicated
public key is accepted. Password/none authentication, exec, forwarding and
subsystems remain denied. The sole healthy interaction is a fixed ready marker
and diagnostic exit; there is no OS command execution or real PTY process.
This does not establish compatibility with an additional production server.

## Twelve-case matrix

| Cases | Port offset | Peer hold | Client action and assertion |
| --- | --- | --- | --- |
| ready-before / ready-after | 0 | None | Authentication, PTY/shell, ready marker, normal EOF; healthy connection still works after failures |
| auth-timeout / typed-auth-timeout | 1 | 18 seconds | Production clock; safe authentication timeout, failure, joined cleanup; typed CMD returns 255 to the original PID |
| auth-late | 2 | 6 seconds | Three-second phase budget; late authentication result cannot allocate a PTY or publish Running |
| auth-cancel / auth-close | 3 | 6 seconds | Caller cancellation or explicit close while Starting; shared close remains pending until startup settles, Cancelled result, no terminal bytes |
| pty-timeout / typed-pty-timeout | 4 | 18 seconds | Production clock; safe PTY timeout and joined cleanup; typed CMD returns 255 to the original PID |
| pty-late | 5 | 6 seconds | Three-second phase budget; late PTY/shell result cannot publish Running or emit terminal bytes |
| pty-cancel / pty-close | 6 | 6 seconds | Caller cancellation or explicit close while PTY reply is held; owned join, Cancelled result and no terminal bytes |

The late/cancelled PTY request may be followed by a shell request within the
uncancellable library constructor. The client must reject the resulting stream
before Running; do not claim no remote allocation occurs after cancellation.
The fixture executes no real shell. An authentication public-key probe can be
held before signature completion; the separate PTY cases require actual
authenticated transport state. Do not label the authentication-stall cases
already authenticated.

Each operation has a 40-second diagnostic watchdog; the portable process has
a 240-second watchdog. These are test failure detectors, not production bounds.
Typed tests await committed local readiness before invoking the shim, observe
the coordinator's fixed failure category, and verify status 255 and root PID.
This avoids using wrapped screen text as a structured result or racing root
startup. The existing eight-stage disconnected/loopback suite remains intact.

## Evidence and acceptance

Run the portable self-test under PS5.1, original PS2, CMD and an independently
extracted path with spaces. Run the twelve real cases against the staged Release
candidate and match its server audit. Complete Windows 7 LEOPARD/NESSY/TURTLE
client reports must then pair with independent server logs for acceptance.

Every foreground serve run uses a fresh audit file. One client matrix runs per
serve invocation; wait five seconds after completion before Ctrl+C, then start
a fresh serve invocation for the next machine. No certificate-fixture reset is
needed. The paired audit requires matching fixture/run IDs, twelve client PASS
assertions and server connections, full natural hold durations, authenticated
PTY callbacks, healthy-before/after completion and closed workers. Early server
stop, shortened holds, missing cases and identity mismatch fail qualification.
Keep failures and do not rewrite the immutable issue-time package manifest.

Credentials exist only in memory and the owned anonymous stdin pipe. Reports
exclude passphrases, private paths, remote output and raw SSH/library exceptions.
Server logs contain fixed events, public identities, version and monotonic
times, not addresses, key material or arbitrary usernames. Preserve complete
client Logs, server JSONL and audit stdout, including on clean runs.

Hard OS DNS completion/shutdown bounds remain unqualified. A separately owned
process or supported OS cancellation boundary requires another design; racing
DNS against Task.Delay would abandon work. Partial/stalled I/O, final-output
drain, silent-loss/keepalive policy, sustained rekey and nonzero remote exit
status remain open. UT01/UI01/SSHUX01 remain required before polish and 1.0.
