# Milestone 3: Local interactive sessions

[Roadmap](../../../ROADMAP.md) | [Documentation](../README.md)

These are the detailed requirements and recorded results for this milestone.
An accepted slice does not close an unchecked parent requirement.

## Find a section

- [3A: Session feasibility and contracts](#3a-session-feasibility-and-contracts)
- [3B: Local backend integration](#3b-local-backend-integration)
- [3C: Input and lifecycle acceptance](#3c-input-and-lifecycle-acceptance)

## Milestone 3: Local interactive sessions

### 3A: Session feasibility and contracts

Completed in 0.4.0/ABI 11 and accepted on the Windows 7 SP1 x64 target.
This checkpoint was authorized by the
[September 14 decision](../architecture/2026-09-14-warp-development-deferral.md).
P01, I01, the 0.3.7 outbound slice, S00 and S01 are complete. Corrected SSH.NET
package 0.6 passes both Windows 7 controlled-server runs and selects the
embedded interactive candidate. The session-identity and typed-handoff contract
is implemented through its document/view identity and managed fake-transport
boundary without a new WARP trace prerequisite. The exact 0.4.0 candidate passes
the focused outbound and ownership runners with matching package binaries,
detached drain, generation-2 reattachment and fake transport generations 1/2/3.
Version 0.5.0 implements 3B.1's production WinPTY root transport for one
explicit Command Prompt profile and passes locally in Debug and Release. Its
exact Windows 7 automated run, manual Croatian text, Unicode filename and child
GUI launch pass. This accepts the bounded transport/Unicode/lifecycle slice.
Follow-up confirms Ctrl+C aborts a running command; only empty or partial
prompt-line cancellation fails, matching the documented WinPTY 0.4.3 limit.
Version 0.5.1 adds the missing native mouse-wheel scrollback path. Its Windows 7
run passes movement and retained history, then exposes that printable characters
do not snap to live output although non-text keys do. Version 0.5.2 moves the
snap to the committed-character boundary. The supplied test-machine checks pass
without further issues. Broader local
shells, input/layout and remote transport remain later work under the accepted
boundaries.

Run bounded experiments before committing to transport and input designs. These
do not require daily-driver tabs or a finished SSH interface.

Inbound slice status, 2026-09-14: [0.3.6](../architecture/2026-09-14-session-stream-foundation.md)
implements the shared inbound byte boundary. ABI 9 owns one incremental UTF-8
decoder per surface generation; the managed session pump supplies ordered UI-thread
delivery with a 16 by 64 KiB bounded queue, drain-before-EOF semantics and explicit
incomplete-EOF failure. One-chunk, every-byte-boundary, malformed/incomplete,
recovery and exact-render tests pass locally in Debug and Release. Version 0.4.0
supersedes the per-surface owner with one document pump, explicit session/transport
states, originating replies and detachable presentation. The
[session ownership review](../architecture/2026-09-14-session-ownership-and-source-review.md)
identified the HWND-backed `Surface` as an interim proof boundary; ABI 11 now
separates production session/TerminalCore identity before 3B backend wiring.

P01 implementation status, 2026-09-14: the official WinPTY 0.4.3 MSVC bundle
is pinned by archive and component hashes. A native controlled child and probe
now retain child console cells, reconstructed bytes and final TerminalCore state
for eighteen cases. Debug and Release pass the collection protocol on the development
machine. The [baseline record](../validation/2026-09-14-winpty-p01.md)
documents observed fidelity limits. Package 0.1 exposed a launcher path bug
before probe startup. Package 0.2 passed five Windows 7 cases, then revealed
that CP932 cannot be selected in that console (`ERROR_INVALID_PARAMETER` 87).
Package 0.3 records unavailable code pages as capability evidence and continues.
Its full Windows 7 run completes all eighteen cases with verified lifecycle,
stream, UTF-8, dimension and attribute evidence. Sixteen cases have ordinally
equal text; the two raw-VT cases expose NUL/ESC loss, Windows 7 rejects processed
VT mode, CP932 selection is unavailable in the supplied console, and five cursor
comparisons differ. Resize, alternate-buffer, final rewrite and exit drain pass.
WinPTY 0.4.3 is selected for local legacy-console sessions with these limits;
P01 is closed. The source comparator now uses ordinal equality to correct the
package's embedded-NUL false positive without another target run.

I01 implementation status, 2026-09-14: the separate Release x64 package 0.2
completed on Windows 7 with the Croatian HR Latin layout. Both controls receive
the required Croatian and AltGr text; Ctrl+C, Ctrl+Break, dead-key, focus and
resize ordering are captured. `ToUnicodeEx` flags 1 and 5 both mutate dead state
on the target, so production committed text comes once from the native HWND
character/composition path and no live UI-thread helper translation is allowed.
The native grid supplies one coalesced resize, and handled control keydowns
suppress their paired U+0003 character. See the
[I01 record](../validation/2026-09-14-input-i01.md).

Outbound implementation status, 2026-09-14: [0.3.7](../architecture/2026-09-14-session-outbound-foundation.md)
adds ABI 10 TerminalInput encoding at the native HWND boundary and a 256-operation
generation queue for input bytes, Interrupt, Break, focus, resize, paste and
terminal replies. Committed UTF-16 is not retranslated; handled Enter and Ctrl
actions suppress their correlated character messages; focus loss reconciles
modifiers; the native grid supplies one dispatcher-coalesced resize. Stale,
bounded-full, FIFO/drain, Croatian/AltGr, control, non-text and resize checks pass
locally in Debug and Release. The exact Windows 7 SP1 x64 candidate also passes
with matching package host/native hashes. ABI 11 now moves TerminalCore/session
identity into `TerminalDocument`; the ABI 10 surface calls remain only as a
temporary compatibility facade for established diagnostics.

S00 implementation status, 2026-09-14: the endpoint-independent
[OpenSSH preflight](../validation/2026-09-14-openssh-s00.md) records an
external installed client's exact executable identity, signature availability,
algorithm inventory, effective isolated configuration, raw stdout/stderr and
bounded cancellation against a disposable stalled loopback peer. Package 0.2
passes twice on Windows 7 with the exact Microsoft 10.0p2 x64 `ssh.exe`, SHA256
`6890C128C86CC2C38AAD9FCB32A82B851FF3D38C714A1F656B8E445D7CD5E1C6`.
Both complete runs are archived and repeat byte-for-byte behavior except timing
and run metadata. The package does not bundle OpenSSH.

Controlled-server package status, 2026-09-14: network package 0.1 completes on
my Debian 12 server and dedicated unprivileged account. It pins the
accepted client hash and covers out-of-band Ed25519 trust, strict unknown and
changed-key rejection, key-only authentication, negotiated algorithms, exact
non-PTY channels and remote exit, a 131,071-byte final drain, forced PTY initial
dimensions and active-output cancellation. All behavioral checks pass, but the
forced PTY begins at 0 columns by 0 rows. Package 0.1 retained the public server
host-key fingerprint and temporary profile path in one changed-host diagnostic;
the raw evidence is restricted, a sanitized copy is archived, and corrected
source uses 0.2 for any reissue. It did not retain the endpoint, SSH username,
port, private key, private-key hash or password. Exact 10.0p2 source inspection
shows that Windows `TIOCGWINSZ` reads only the stdout console buffer, falls back
to zero dimensions when stdout is VT7's pipe, and detects resize through console
input events that redirected VT7 input does not produce. Another unchanged
resize run would not alter that control path. S00 is complete: external
`ssh.exe` is accepted for non-PTY command transport and rejected as VT7's
interactive SSH backend.

S01 accepted status, 2026-09-14: SSH.NET 2026.0.0 supplies explicit PTY resize,
structured trust/authentication, .NET Framework 4.6.2 compatibility and the
modern algorithms observed in S00. Its exact 13-package closure is not strictly
MIT-only: package contents include an Apache-2.0 BZip2 portion through
BouncyCastle.Cryptography 2.7.0 and an ISC-style BCrypt notice. Both are
permissive and there is no copyleft. I approved this closure and a
standing policy for compatible permissive dependencies. The exact-notice S01
0.6 diagnostic now passes on Windows 7; production integration must preserve
the accepted dependency and notice closure.

- [x] Characterize a pinned WinPTY native library/agent build (P01). Compare
  child console state, reconstructed bytes, and final core state for W/A console
  APIs, direct buffer writes, raw VT, code pages, colors, Unicode, alternate
  buffers, and resize. Select the local backend from that evidence.
  - [x] Pin official 0.4.3 native artifacts and license; implement the controlled
    eighteen-case comparison and pass Debug/Release locally.
  - [x] Run the issued Release diagnostic on Windows 7, review exact evidence,
    and record the local-backend selection or rejection.
- [x] Evaluate a pinned Microsoft Win32-OpenSSH client first (S00), recording
  exact binaries/runtime hashes, Windows 7 configuration, and negotiated
  algorithms. Compare a known-good local-console run with direct byte I/O.
- [x] Prove strict trust decisions, public-key batch authentication, unmodified
  non-PTY VT/UTF-8 channels, remote exit, final drain, forced PTY allocation and
  active cancellation. Record the initial 0 by 0 PTY result as a failure for
  usable geometry.
- [x] Reject live SSH window-change control through unmodified redirected
  Windows OpenSSH. Exact 10.0p2 source and the target's 0 by 0 PTY result show
  that its geometry path requires Windows console output and input events.
  `SSH_ASKPASS` could structure prompts but cannot repair resize. Never
  substitute commands typed into shell input for SSH window-change messages.
- [x] Accept SSH.NET 2026.0.0 through corrected S01 0.6. Both Windows 7 runs
  pass the exact dependency closure, structured public-key/password handling,
  strict trust, modern AES-CTR/HMAC-SHA2 negotiation, command/PTY fidelity,
  live resize, cancellation, session isolation and
  stream-dispose-before-client-disconnect ownership. Required supplier notices
  and rejected alternatives are documented.
  - [x] Lock and hash the thirteen-package net48 closure; package exact supplier
    notices and the encrypted-key fixture; pass Release/offline, recursive ZIP
    and repeated path-with-spaces launcher checks.
  - [x] Run the issued 0.5 package on Windows 7 against the controlled Debian 12
    account, diagnose its two faulty assertions, correct them in 0.6, and archive
    the sanitized accepted 0.6 manifests with verification metadata.
- [x] Test the inherited `ToUnicodeEx` helpers on Windows 7 (I01), especially
  dead keys and AltGr. Do not assume newer non-mutating flag semantics or merely
  clear the flag without checking keyboard-state effects.
  - [x] Build and locally qualify the native and WPF/native-focus diagnostic,
    including its exact non-overwriting 0.2 package and PowerShell 5.1 launcher.
  - [x] Run package 0.2 interactively on the Windows 7 Croatian HR Latin target,
    archive the complete Logs directory and record the input-owner decision.
- [x] Implement a generation-checked bounded outbound queue and the I01-selected
  native child-HWND adapter. Serialize encoded input/control/focus/resize,
  suppress correlated control characters, reconcile modifiers on focus loss,
  and coalesce the native authoritative grid. The exact 0.3.7 candidate passes
  its Windows 7 target validation.
- [x] Define one session owner and separate session/TerminalCore identity from
  transient HWND and WPF presentation identity. Include per-session decoder/parser/
  input state, ordered writes including terminal replies, bounded queues/backpressure,
  coalesced resize generations, EOF/drain/exit distinctions, cancellation and
  teardown. Reject stale callbacks by generation after close. Hidden panes keep
  consuming output without presenting unnecessary frames; view recreation does
  not implicitly restart or terminate the session.
  - [x] Write the implementation-ready
    [terminal document, transport, and typed-SSH handoff specification](../architecture/2026-09-14-terminal-document-and-ssh-handoff-spec.md).
    It fixes the ABI 11 document/view split, managed transport contract,
    generation/origin rules, bounded lifecycle, exact OpenSSH fallback boundary,
    secured shim IPC, ordering barrier, SSH.NET teardown, exit-status limitation,
    phased delivery, and verification matrix. The 0.4.0/ABI 11 implementation
    passes Debug and Release locally and the exact Windows 7 target candidate.
  - [x] Add typed native document/view handles, attachment and producer
    generations, attached-document `ERROR_BUSY`, bounded originating-transport
    replies, and the temporary legacy facade.
  - [x] Prove view destruction, headless drain and generation-2 reattachment
    against the deterministic 388-byte stream with the exact baseline raster.
  - [x] Add `TerminalSession`, `ITerminalTransport`, explicit state/result/close
    types, fake root/overlay transports and generations 1/2/3; keep one document
    stream across the switch and route a TerminalCore reply to its origin.
  - [x] Run the exact 0.4.0/ABI 11 package on Windows 7 SP1 x64, verify matching
    host/native hashes, and archive both passing focused reports with independent
    package correlation.
- [ ] Separate committed text from non-text key metadata. Choose the IME input
  owner and composition/candidate geometry contract; define accessible text/range
  mapping before the UI depends on it. Implementations follow in 3C and 4.
  - [x] Separate native `WM_CHAR`/`WM_SYSCHAR` committed text from mode-aware
    non-text key encoding without calling layout translation on the live input
    thread; preserve Ctrl+C and Ctrl+Break distinctions.
- [x] Define host-action policies before feeding real session output: bounded
  titles/OSC/DCS, explicit clipboard permissions, user-activated validated links,
  and untrusted working-directory metadata. Scope callbacks/replies to the
  originating session and reject stale work after close. Diagnostic replay must
  not perform desktop actions by default. The
  [3A technical specification](../architecture/2026-09-14-terminal-document-and-ssh-handoff-spec.md#terminal-output-and-host-action-policy)
  fixes the initial deny/allow rules, bounds, generation checks, origin routing,
  and fake replay sink; implementation remains part of session construction.

Gate: evidence-backed backend choices and written session/input/security contracts
exist before 3B or Milestone 4 construction. Record failed experiments and resolve
required capability gaps instead of marking them passed. S00 is architectural
feasibility, not full SSH acceptance or a promise to ship the evaluated release.

### 3B: Local backend integration

- [x] Integrate the selected native local backend behind a replaceable boundary,
  preserving its lifecycle and ownership contracts without requiring Cygwin UI.
  - [x] Implement `WinPtyTransport` behind `ITerminalTransport` for an explicit
    Command Prompt profile. Local Debug/Release checks cover spawn, generation-1
    input, resize, final drain, exit code, cancellation and visible agent cleanup.
  - [x] Accept the exact 0.5.0 package on Windows 7 for the bounded transport,
    Unicode and lifecycle scope. All runners, Croatian text, `ććć.txt` creation
    through Notepad and ordinary interaction pass. Active-command Ctrl+C works;
    prompt-line cancellation is a recorded WinPTY 0.4.3 fidelity limit for 3C.
  - [x] Accept 0.5.1 mouse-wheel movement and retained-position behavior on
    Windows 7. Printable characters fail to snap to live output; Backspace,
    Delete and arrow keys pass that behavior.
  - [x] Accept the 0.5.2 committed-character correction on the supplied test
    machines. Printable input returns to live output without changing the
    accepted wheel and retained-history behavior.
- [x] Launch Command Prompt, Windows PowerShell 5.1, and PowerShell 7.2.24 with
  explicit executable, arguments, environment, working directory, and versions.
  - [x] Implement and target-qualify the explicit Command Prompt profile in
    0.5.0 for the bounded 3B.1 scope.
  - [x] Add explicit Windows PowerShell 5.1 and versioned PowerShell 7 profiles
    in 0.6.0 through 0.6.6, with ordinary user profiles preserved, clean diagnostic variants,
    visible selection and deterministic root replacement.
  - [x] Qualify the corrected 0.6.4 Windows 7 PowerShell 5.1/7.2.24 candidate.
- [x] Validate PSReadLine editing, history, completion, supported prediction,
  multiline prompts, and native children, using clean and ordinary profiles.
  Do not silently alter execution policy, user profiles, or global code pages.
  - [x] Pass the local clean-profile transport contract, accept the 5.1 legacy
    ConsoleHost editor, and reject a local 7.6 preview as 7.2.24 evidence.
  - [x] Pass exact 5.1/7.2.24 automation and ordinary multiline Croatian text,
    resize, scrollback, native-child and lifecycle checks on Windows 7.
  - [x] Confirm 0.6.5 keeps the accepted automated session contract and clean
    startup/replacement/shutdown behavior; record that direct `SetFocus` does not
    keep Tab, Down and End inside the terminal.
  - [x] Confirm the 0.6.6 `HwndHost` keyboard sink keeps Tab, Down and End
    inside the terminal immediately after startup and profile replacement.
- [x] Accept H01, the typed-command shim and committed-output barrier, on the
  exact Windows 7 shell matrix before enabling typed embedded SSH.
  - [x] Build the Windows 7-subsystem native shim, bounded grammar and exact
    hashed external fallback with CRT-compatible quoting and sanitized state.
  - [x] Implement and locally pass the per-session secured pipe, capability/
    HMAC exchange, PID/creation-time/ancestry/console checks, one-shot decision
    and marker commit through `SessionOutputPump`.
  - [x] Pass corrected 0.7.3 package 0.4 through Command Prompt, Windows
    PowerShell 5.1 and exact PowerShell 7.2.24 on Windows 7. Package 0.1 passed
    all embedded paths but failed external fallback with duplicated console
    handles; package 0.2 proves the originals reject `SetHandleInformation` with
    error 87; package 0.3 proves traditional console handles cannot enter the
    explicit handle list. Package 0.4 passes the strict Windows 7 matrix.
    Embedded SSH stays disabled until the Milestone 5 product path is ready.
- [ ] Propagate the authoritative grid to the child console during resize;
  compare results across code pages, long prompts, wide/combining text, and
  full-screen applications.
- [ ] Stream output through a persistent decoder and core (U01). Test every
  boundary of short UTF-8/VT fixtures, malformed/incomplete input, EOF, restart,
  and replies. The 0.3.6 inbound foundation proves decoding, EOF and restart;
  the 0.3.7 outbound foundation proves bounded generation ordering and native
  input/resize admission;
  transport integration and originating-session replies remain to close U01.

Gate: required shells and representative native applications work end to end
with documented fidelity, not merely a visible prompt.

### 3C: Input and lifecycle acceptance

- [ ] Forward text, non-text keys, mouse, paste, focus, and control events once
  and in order through the session, not global keyboard injection. Test terminal
  modes, selection override, large/canceled paste, and Ctrl+C/Ctrl+Break.
- [ ] Implement and test the chosen IME path (I02): preedit stays local, committed
  text is sent once, candidate UI follows the caret, and tab/focus/resize/close
  transitions leave no stale composition. Record Windows 7 IME versions.
- [ ] Test US, Croatian, German, and a non-Latin keyboard layout, including
  AltGr, dead keys, repeats, modifier loss, and WPF/native focus routing (I01).
- [ ] Exercise spawn/read/write/resize cancellation, agent or child failure,
  final-output drain, restart, and forced termination (P02). Include child trees
  and inherited jobs; document Windows 7 containment/breakaway limits explicitly.
- [ ] Prove bounded shutdown and queue growth, no cross-session input/replies,
  no callbacks after destruction, and a responsive dispatcher under output.
- [ ] Add privacy-aware diagnostics and deterministic session/host-action
  regressions with the implementation. Do not log ordinary terminal content or
  credentials by default.

Exit criterion: all required local shells can be used for sustained interactive
work, including child applications, composed input, resize stress, and clean
exit. The 3A SSH decision is recorded; production SSH delivery remains Milestone 5.
Repeat backend-sensitive input and IME tests over direct SSH there.

