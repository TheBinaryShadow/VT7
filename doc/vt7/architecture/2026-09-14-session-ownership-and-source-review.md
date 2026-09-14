# Session ownership and external source review

Decision date: 2026-09-14. Status: accepted architecture constraints and
research references. No third-party source was incorporated by this review.

This note evaluates the external `VT7-architecture-review.md` supplied on
2026-09-14 against the current working tree. The supplied file has SHA256
`2F30DA4A9D27057657A89C23A001442A9FC9B429C456C1D9A8757BE0450D54E0`.
It assessed the pushed branch, so its observations are evidence to reconcile,
not instructions or an exact description of the newer local source.

## Disposition

Several recommendations were already implemented or superseded after the
pushed commit:

- Version 0.3.7 / ABI 10 owns incremental UTF-8 decoding across arbitrary read
  boundaries. It tests every fixture byte boundary, malformed and incomplete
  input, EOF, restart and exact rendering.
- `SessionOutputPump` already provides ordered transport-thread delivery,
  bounded backpressure and drain-before-EOF behavior.
- P01 is complete. The official WinPTY 0.4.3 native x64 runtime is selected for
  Windows 7 legacy-console sessions behind a replaceable backend boundary, with
  its observed raw-VT, code-page, cursor-width and intermediate-state limits.
- The renderer teardown order is already explicit and tested. Native HWND
  destruction occurs while the presentation worker still exists, then graphics
  resources are released on that worker before it is joined.
- S00 already requires direct byte and PTY-control evidence before choosing an
  OpenSSH architecture. A successful `ssh -tt` login is insufficient.

The review's main remaining finding is valid. The current native `Surface` owns
`Terminal`, `Utf8TerminalStream`, Atlas, `Renderer` and `HWND` together.
`VT7_CreateSurface` returns the HWND as the ABI handle, and managed
`SessionOutputPump` writes directly to a `TerminalSurface`. This is appropriate
for the viewport proof, but it must remain an interim arrangement. A production
transport must not become another member of `Surface`, and HWND destruction
must not implicitly define process, SSH or terminal-state lifetime.

## Required ownership model

Before 3B connects a real local backend, establish these logical owners even if
the first implementation uses fewer concrete types:

```text
pane or terminal instance
  owns TerminalCore state, decoder generation and one session
  owns ordered inbound and outbound flow

session
  owns process or connection state, transport handles and cancellation
  accepts input and terminal replies in one serialized order
  reports output, exit and diagnostics without touching presentation directly

terminal view
  owns HWND, Atlas renderer and WPF presentation attachment
  converts pixels to the authoritative cell grid
  can detach or be recreated without becoming the session identity
```

The C ABI may continue to use opaque `void*` values, but terminal/session
identity and presentation identity must become distinct. Exact public handle
names are an implementation decision. ABI 10 was widened for the implemented
input encoder, not to rename the current proof handle. Introduce the split when a real owner needs it and test
the transition.

Closing a view and closing a session are separate operations. A tab/pane close
may request both, while transient `HwndHost` teardown or layout reconstruction
must not silently kill a session. A hidden pane continues draining bounded
output and updating TerminalCore while avoiding unnecessary presentation work.

## Shutdown and stale-work contract

One session generation owns its decoder, core callbacks, output pump, outbound
queue and resize state. Teardown follows this contract:

1. Mark the session generation as closing and reject new user input, replies
   and resize requests.
2. Cancel or close transport reads and writes through the backend owner.
3. Decide explicitly whether accepted output drains to EOF or is abandoned.
4. Prevent queued or late callbacks from touching TerminalCore when their
   generation no longer matches.
5. Detach the view, then use the established HWND and renderer teardown order.
6. Release backend handles and publish the final exit reason once.

EOF, clean child exit, transport failure, cancellation and forced termination
remain distinct outcomes. Diagnostic replay must never be able to act on a new
session that happens to reuse an old view or handle value.

## Input and resize consequences

The completed [I01 Windows 7 characterization](../validation/2026-09-14-input-i01.md)
selects the native child HWND as the terminal-focus input boundary. Croatian and
AltGr characters reached the native Unicode control through `WM_CHAR`; dead-key
input produced `WM_DEADCHAR` followed by committed characters. `ToUnicodeEx`
flags 1 and 5 both changed dead state on Windows 7, so bit 2 cannot protect the
live UI translation thread there.

Committed UTF-16, including AltGr and dead-key composition, comes from the OS
character/composition path once. Native key metadata remains separate for
non-text keys and control distinctions. Terminal mode dependent key and mouse
encoding belongs in the inherited TerminalCore input implementation; the host
does not grow a second general-purpose virtual-key-to-escape mapper. Any
TerminalInput layout-helper use must be isolated from the live UI message
thread or pass a later Windows 7 compatibility test.

Windows 7 delivered WPF preview key events for the same physical input that then
reached the hosted native control as key and character messages. WPF preview and
native messages are observations of one input, not two sources to enqueue. The
adapter handles terminal input only at the native child boundary; WPF keeps
application-command routing outside that terminal stream.

Ctrl+C and Ctrl+Break each produced a distinct native keydown immediately
followed by the same `WM_CHAR` U+0003. The adapter correlates those events so a
handled control action is not followed by a duplicate ETX, while retaining the
Break distinction for backend policy. Focus loss reconciles tracked modifiers
because the physical key-up can reach another focus owner.

Input bytes, terminal-generated replies and paste share one serialized outbound
session queue so their relative order is defined. Control and resize operations
enter the same generation-checked ordering contract.

A presentation resize produces one authoritative cell grid and then two
effects: `Terminal::UserResize` updates local terminal state, and the session
backend receives the same columns and rows through its PTY/window-change
operation. I01 observed two WPF dimension events around one child `WM_SIZE` for
each resize action, confirming that only one coalesced native grid should reach
the session. Coalescing may skip obsolete intermediate sizes, but each delivered
resize carries a generation and cannot cross session replacement. WinPTY uses
its resize API; direct SSH uses an SSH window-change request. Neither path types
commands into the child shell to simulate resize.

## Open-source reference ledger

Licenses were checked against each project's own repository or official site on
2026-09-14. A permissive license makes code adoption possible under its terms;
it does not remove provenance or notice obligations.

Project-owner direction: keep new VT7-authored code MIT licensed where possible.
The standing 2026-09-14 decision permits compatible permissive dependencies and
assets, including Apache-2.0, ISC-style, BSD-style and broader supplier notice
sets, when they help deliver the port. Every adoption still records exact
provenance, license and distribution obligations, preserves all notices, and
thanks the upstream project. Source-sharing, network-use, proprietary
redistribution or other materially restrictive terms require a separate
compatibility review.

| Project | Verified license | Useful role for VT7 | Current incorporation status |
| --- | --- | --- | --- |
| [Microsoft Terminal / OpenConsole](https://github.com/microsoft/terminal) | [MIT](https://github.com/microsoft/terminal/blob/main/LICENSE) | Primary source for TerminalCore, input, connection/core/presentation separation and resize behavior. | Primary inherited upstream at the pinned commit in `UPSTREAM.md`; existing history, copyright, license and notices are retained. |
| [WinPTY](https://github.com/rprichard/winpty) | [MIT](https://github.com/rprichard/winpty/blob/master/LICENSE) | Selected Windows 7 local legacy-console transport. | Official 0.4.3 binaries are restored to the ignored dependency cache and packaged with the exact license; hashes and provenance are recorded by P01. |
| [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/) | [MIT](https://www.chiark.greenend.org.uk/~sgtatham/putty/licence.html) | Reference for SSH trust, authentication, prompts, cancellation, error routing and protocol edge cases if S00 exposes a gap. | Research only; no PuTTY source or binary is incorporated. |
| [SSH.NET 2026.0.0](../research/2026-09-14-sshnet-license-audit.md) | Package metadata is MIT; exact contents also carry permissive Apache-2.0, ISC-style and broader supplier notices. | S01-accepted candidate for explicit PTY resize, structured trust/authentication and net48-compatible managed integration. | Exact-notice package 0.6 passes on Windows 7; production source and dependencies are not incorporated yet. |
| [WezTerm](https://github.com/wezterm/wezterm) | [MIT](https://github.com/wezterm/wezterm/blob/main/LICENSE.md) | Reference for stable pane/session/domain identities and presentation attachment. Its mux model demonstrates that UI windows need not own pane identity. | Research only; no WezTerm source or binary is incorporated. |
| [Mintty](https://github.com/mintty/mintty) | [GPL version 3 or later](https://mintty.github.io/mintty.1.html#LICENSE) | Behavioral comparison for Windows keyboard layouts, AltGr/dead keys, Unicode, resize and WinPTY-facing behavior. | Behavioral oracle only. Do not copy or translate its implementation into VT7's MIT-licensed application without a separately reviewed licensing design. |

`libvterm` and `xterm.js` were mentioned only as alternative terminal engines.
VT7 already retains TerminalCore as its authoritative parser, buffer, input and
render data source, so replacing or duplicating it with either project has no
current justification.

Study and attribution are different records. A project does not enter
`NOTICE.md` merely because its design or observable behavior informed VT7.
Before copying or adapting code, record the exact upstream URL, revision,
file/function, license and local modifications; preserve required copyright and
license text; then update `NOTICE.md` and packaged licenses as applicable.

## Effect on the active plan

I01 settles the Windows 7 Croatian input boundary described above. The
[0.3.7 outbound foundation](2026-09-14-session-outbound-foundation.md) now
implements its generation-checked queue and native-HWND adapter and passes the
exact Windows 7 target candidate. S00 is complete and rejects unmodified
redirected OpenSSH for interactive PTY sessions after accepting it for non-PTY
command transport. S01 accepts SSH.NET 2026.0.0 and its permissive closure on
Windows 7. The ownership,
stale-callback, input and resize rules remain
prerequisites to production backend wiring in 3B. They also protect the later
tabs and split-pane work, where WPF layout and HWND recreation cannot safely
serve as session identifiers.
