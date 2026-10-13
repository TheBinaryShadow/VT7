# Milestone 5: First-class SSH

[Roadmap](../../../ROADMAP.md) | [Documentation](../README.md)

These are the detailed requirements and recorded results for this milestone.
An accepted slice does not close an unchecked parent requirement.

## Milestone 5: First-class SSH

Deliver the architecture accepted by 3A/S01. S00 rejected unmodified redirected
OpenSSH for interactive sessions; S01 accepts SSH.NET 2026.0.0 as the embedded
interactive candidate on the tested Windows 7 configuration.
The accepted WPF connection, trust and management dialogs are proof
presentation. Their transport and security behavior remains valuable, but the
finished experience must satisfy SSHUX01 below before Milestone 7 polish.

- [x] Integrate SSH.NET 2026.0.0 behind `ITerminalTransport` and pin its complete
  audited redistributable dependency set. Version 0.8.0 direct-profile package
  0.2 passes local restore, build, offline lifecycle, target-style CMD launch,
  image/import, notice and ZIP verification. Package 0.1 is rejected for its
  PowerShell 5.1 trailing-backslash launcher defect. Package 0.2 passes the
  complete Windows 7 network matrix. Version 0.8.1/package 0.3 corrects the form
  labels but its focused visual check rejects the generated selected
  Authentication text. Version 0.8.2/package 0.4 gives that item an explicit
  dark template, tests the rendered selection at 4.5:1 and passes focused
  Windows 7 visual confirmation.
- [ ] Recheck security advisories, Windows 7 execution, licensing,
  release/support status, and the maintenance/update process before shipping.
- [x] Require and verify a separately obtained SHA256 host-key fingerprint before
  authentication in the direct-profile slice. A mismatch fails closed.
- [x] Implement recoverable known-host management.
  Separate unknown, changed, matching, and unreadable trust records; never
  silently accept a mismatch or continue authentication past a failed decision.
  The [OpenSSH-compatible technical specification](../architecture/2026-09-21-openssh-known-hosts-management-spec.md)
  is complete. It selects the user's default OpenSSH files, pins 10.0p2 as the
  differential oracle, defines raw-key/certificate/revocation precedence,
  fresh-connection first-contact decisions and byte-preserving Windows writes.
  KH01.1 parser/oracle package 0.1 passes Debug, Release, path-with-spaces and
  independent ZIP verification locally against `ssh-keygen.exe` 9.5.5.2. The
  my test reports a clean Windows 7 pass through the launcher's mandatory
  10.0.0.0 file-version gate for the 10.0p2 oracle. KH01.2 is implemented in
  version 0.10.0: both SSH.NET paths load immutable snapshots of the four default
  OpenSSH sources, stored matches skip fingerprint re-entry, unknown hosts retain
  the exact pin, and changed/revoked/unreadable/policy states fail closed. Local
  Debug, Release, overlay, packaged-path and independent ZIP checks pass. Package
  0.2 passes the primary live run but fails both SSH.NET paths on NESSY because
  its 2026.0.0 dependency hits upstream issue 1829. Version 0.10.1/package 0.3
  pins publisher-built SSH.NET `2026.0.1-prerelease.6` from fix commit `f099365`.
  Its automated corpus and direct/typed stored-key paths pass on both NESSY and
  TURTLE, accepting KH01.2 across the two Windows 7 runtime tiers. Version
  0.11.0 implements KH01.3 generation-scoped first-contact UI, exact
  Connect-once retry pins and mutex/exclusive durable addition to the primary
  user file with flush and exact read-back. Package 0.4 passes Debug/Release,
  overlay, path-with-spaces and independent archive verification at SHA256
  `531B4A1D43894408F7AA38AC6E0BC22C6EBA1394519C3A70C1C9A83AA64B2C83`.
  Its automated and controlled live matrix passes on NESSY and TURTLE: Cancel,
  Connect once, durable Trust and connect, prompt-free reconnect through both
  SSH paths and terminal interaction are accepted. Version 0.12.0 implements
  KH01.4 changed-key review, selected primary-user record removal with a
  verified `.old` copy, and CA-signed host-certificate policy. Local regression
  and OpenSSH-generated certificate checks pass. Package 0.5 passed local
  staged and independent ZIP verification but fails ACL read-back in its
  disposable removal check on NESSY and TURTLE. Version 0.12.1 explicitly
  copies and verifies the replacement file's descriptor before mutation.
  Package 0.6 passes the automated corpus on both machines, but manually tested
  live removal stops at `temporary-security` with no file change and exposes
  faint key-row text. Version 0.12.2 compares the actual security components
  and fixes that contrast. Package 0.7 failed the new inherited-ACL test's
  obsolete exact-SDDL assertion on NESSY. Version 0.12.3 aligns that assertion
  with the production security check. Package 0.8 passes the automated and
  manual live known-host matrix on NESSY and TURTLE, including
  selected removal and exact `.old` backup. KH01.4 is accepted. Version
  0.13.0 adds its isolated nine-case live harness, Debian certificate-only
  listeners, server authentication audit and PowerShell 2.0-compatible target
  runner. Candidate 0.1 passes all three machines' self-tests and live valid/
  wrong-principal cases on Debian 13, but fails an incorrect expired-certificate
  callback assertion. Version 0.13.1/candidate 0.2 observes the exact certificate
  at key exchange and requires SSH.NET's pre-callback date rejection. Signed
  signature/date regressions and packaging checks pass locally; the corrected
  complete client matrix now passes on all three machines. LEOPARD's server
  audit passes; NESSY/TURTLE's original audit exports incorrectly expected
  three accepted connections rather than five. Replaying the unchanged helper
  against each matching archived server log set with the client count passes
  all three paired audits, with no authentication attempts for rejected cases.
  KH01.5 and this bounded gate are accepted. NESSY's initial failure corresponds
  to an empty server archive; its exact operational cause remains unproved.
  Broader algorithm/IPv6 qualification remains separate. See the
  [KH01.5 procedure](../validation/2026-10-05-known-hosts-kh01-5.md).
- [x] Support ephemeral password, private-key and passphrase authentication in
  the direct-profile dialog without persistence or default-log disclosure.
- [ ] Add agent and keyboard-interactive authentication where
  the selected implementation permits it. Keep prompts/diagnostics distinct
  from remote terminal data; do not infer structured trust decisions from
  arbitrary localized terminal text. Protect secrets and exclude them from logs.
- [x] Allocate `xterm-256color` with the authoritative root session cell and
  native viewport pixel dimensions. Local geometry contracts pass.
- [x] Accept allocation and live `ChangeWindowSize` behavior on Windows 7 against
  the controlled Debian server. Package 0.2 passes initial and resized `stty
  size`, with input serialized against the latest session geometry.
- [ ] Handle stage-specific deadlines/cancellation, stalled peers, partial I/O,
  rekey under output, keepalives, EOF/close/exit status, and reconnection UX (S01).
  Never replay already-submitted input automatically on reconnection.
  - [x] **SL01.1: owned startup cancellation and failure recovery.** Version
    0.14.0 tracks and joins pending SSH startup before transport/session/window
    destruction, retains stream errors, retires faulted outbound queues and
    resumes the original typed shell after the completion-frame handoff.
    Loopback/local regressions and all 24 returned target stages pass. I accept live shutdown and shell recovery on LEOPARD, NESSY and TURTLE.
    A separate U+12032 SSH prompt font-coverage gap also occurs in an older
    package and is now a required UT01.2 fixture. Follow the
    [SL01 design](../architecture/2026-10-05-ssh-lifecycle-sl01-spec.md)
    and [candidate record](../validation/2026-10-05-ssh-lifecycle-sl01-1.md).
    Full staged deadlines, silent-loss bounds, rekey and remote exit status
    remain later slices; the parent gate is not completed by SL01.1.
  - [x] **SL01.2: startup phase budgets and late-result rejection.** Version
    0.15.0 implements owned 15-second phase clocks, bounded timeout categories,
    paused human trust decisions and rejection of late DNS/local/PTY results.
    The existing SSH.NET connection timeout and ownership joins remain. Local
    loopback/policy and production-limit typed timeout checks accompany portable
    candidate 0.4. All 24 returned target stages pass on LEOPARD, NESSY and
    TURTLE; I confirm clean live checks, including the unknown-key
    decision wait. Bounded SL01.2 is accepted. See the
    [design](../architecture/2026-10-11-ssh-startup-phase-deadlines-sl01-2.md)
    and [candidate record](../validation/2026-10-11-ssh-startup-phase-deadlines-sl01-2.md).
    Real OS resolver completion bounds and stalled authenticated-server phases
    remain unqualified; this does not establish a hard overall startup bound.
  - [ ] **SL01.3: real authentication/PTY startup stalls.** Version 0.16.0
    adds an isolated protocol fault peer and twelve client cases: production
    deadlines, late success, cancellation/close, healthy-before/after and
    typed Command Prompt timeout/status-255/original-PID recovery. The production
    transport and exact dependency/native/font/shim closure remain unchanged.
    Paired Debug/Release checks and 32 portable regression stages pass locally;
    paired LEOPARD/NESSY/TURTLE acceptance is pending. Follow the
    [design](../architecture/2026-10-12-ssh-authenticated-startup-stalls-sl01-3.md)
    and [candidate procedure](../validation/2026-10-12-ssh-authenticated-startup-stalls-sl01-3.md).
    Hard real DNS completion/shutdown bounds and remaining I/O/rekey/exit-status
    gates remain open; these checks do not establish immediate cancellation.
- [x] Accept the bounded 0.8.0 direct-profile trust/authentication, Unicode,
  output/scrollback, resize, EOF, idle-close and local-profile-isolation matrix on
  Windows 7. See the
  [direct-profile record](../validation/2026-09-19-sshnet-direct-profile.md).
- [x] Accept the implemented SSH overlay coordinator on Windows 7. Version 0.9.0
  enables H01 `USE_EMBEDDED`, owns trust/authentication in WPF, keeps the local
  root alive, switches the shared document to SSH.NET after the committed
  barrier, and returns status 0/255 to the originating shell. Package 0.1 passed
  the complete automated Windows 7 corpus and proved the shim/barrier/return
  path, but real typed connections failed before network startup because the
  broker worker directly read dispatcher-owned document/viewport geometry.
  Version 0.9.1/package 0.2 marshals that capture through the document dispatcher
  and connects successfully on Windows 7, accepting that correction. Its shim
  then applies the five-second handshake timeout to the full remote-session
  completion wait, returns the local prompt early and prevents root recovery on
  later remote exit. Version 0.9.2/package 0.3 uses a session-lifetime completion
  wait, guarantees root recovery if completion delivery loses the shim, and
  passes a real delayed-shim regression. Package 0.3 passes the complete target
  corpus: the former timeout boundary, normal exit and local prompt recovery,
  sequential handoff, explicit disconnect/status 255, all three local shells,
  Unicode/resize/scrollback/TUI checks and exact external fallback.
- [ ] **SSHUX01: terminal-only typed SSH workflow.** An eligible `ssh` command
  from any supported local shell starts SSH.NET in its originating tab, including
  on Windows 7 without installed OpenSSH. Remove the **Start SSH...** button,
  direct SSH profile and separate connection/trust/management dialogs from the
  finished interface. Present first-contact and changed-key decisions,
  authentication, progress, failures and cancellation inside the terminal.
  Matching known hosts reconnect without a trust prompt. Preserve structured
  pre-auth trust, fail-closed policy, safe known-host mutation, secret privacy,
  exact fallback and original-shell return/status. Bind every prompt and result
  to the originating tab/generation; never interpret remote text as a trust
  decision. Follow the
  [pre-1.0 UI and SSH contract](../architecture/2026-09-25-pre-1-0-ui-and-terminal-ssh-contract.md).
- [ ] Test `vim`, `htop`, `tmux`, `mc`, `less`, full-screen TUIs, mouse input,
  bracketed paste, Unicode, 256-color/true-color output, alternate-screen
  restoration, and the shared keyboard/IME/clipboard paths on Windows 7.
  Package 0.2 already passes manual `htop` and `nano` runs; the remaining
  applications and interaction paths keep this broader item open.

Exit criterion: SSH is a first-class VT7 connection type with lossless remote
terminal bytes, secure terminal-only trust/authentication handling, initial/live
PTY sizing, originating-tab/local-shell return and bounded lifecycle behavior.
Neither a line-oriented redirected command nor `ssh.exe` through legacy console
reconstruction substitutes for this gate.

