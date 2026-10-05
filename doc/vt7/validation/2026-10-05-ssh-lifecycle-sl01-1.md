# SSH lifecycle SL01.1 validation

Date: 2026-10-05. Application 0.14.0, native ABI 11.
Status: bounded SL01.1 accepted on LEOPARD, NESSY and TURTLE on 2026-10-05.
The broader lifecycle gate remains open. The separately reported SSH prompt
symbol is U+12032, a pre-existing font-coverage gap reproduced in an older package.
Design: [SL01 specification](../architecture/2026-10-05-ssh-lifecycle-sl01-spec.md).

## Delivered behavior

Owned startup and cancellation now precede connection/authentication/PTY work.
Close joins startup before resource release. Pending overlays and pending
window sessions participate in shutdown; no late Running state or presentation
attachment is allowed. Synchronous SSH output operations execute off the WPF
dispatcher, with the existing writer ordering.

Public SSH.NET stream/client errors survive stream disposal, so observed
connection loss no longer automatically becomes clean EOF. Failure categories
avoid raw connection/credential exceptions. Failed outbound queues cannot
strand root recovery. Typed startup failure keeps input suspended until the
broker's completion-frame handoff, preserving original shell PID and status 255.

## Findings preserved during implementation

The first loopback run exposed typed cancellation cleanup deadlocking: a
startup continuation synchronously disposed the transport while close awaited
that worker. Await close before Dispose resolves the cycle. The recovery review
also found startup failure resuming root input before broker COMPLETE; both
failure and normal exit now use the same ordering. Phase-specific watchdogs
identify regressions without terminal/credential dumps.
Local-only candidates 0.1-0.3 were superseded before handoff. Pinned-library review
found asynchronous channel-close notification could race a later TCP disconnect.
EOF now waits up to five seconds for that notification, with cancellation
interrupting the wait. Final candidate 0.4 also joins workers after completion
publication and serializes session startup/recovery against close. Actual
authenticated normal exit and connection loss were subsequently exercised on
the Windows 7 targets, as recorded below.

Do not call a 15-second library operation limit an end-to-end startup deadline.
Synchronous pinned-library startup waits may settle at their operation timeout
after cancellation. The larger silent-blackhole, rekey and exit-status gates
are still open.

## Local evidence

Debug and Release builds pass. Real pinned-library loopback checks pass for
silent identification, deadline, caller/explicit cancellation, stalled KEX,
invalid protocol, pending overlay/window close and faulted outbound retirement.
Command Prompt and Windows PowerShell 5.1 typed refusal/cancellation preserve
the original PID and return 255. The development host has PowerShell 7.6.5;
the diagnostic explicitly skips it, since exact 7.2.24 is the target scope.

Final Debug evidence is artifacts/vt7/sl01-issue-debug-lifecycle.log,
sl01-issue-debug-window.log, sl01-issue-debug-settings.log,
sl01-issue-debug-repaint.log and sl01-issue-debug-close-retry.log; all pass.
Earlier failing runs are retained, including sl01-first-run.log and the first
portable stage's failed window-smoke report. The smoke/focused window tests now
await actual Closed before asserting HWND disposal, preserving the existing
disposal check under the new asynchronous shutdown contract.
The Release known-host parser/writer/removal/certificate/oracle regression
passes using ssh-keygen.exe 9.5.5.2, SHA256
2A0D971F935813E324519BCE64E7EB5AF85A5F91517C916270A4368E0786F588.
The H01 authenticated shim, barrier and exact fallback regression also passes.

## Issued candidate

- Archive: artifacts/VT7-SSH-Lifecycle-SL01-1-0.4-x64.zip.
- SHA256: 0942D0DFD3B67570FB4F78CE724A7FD4940736EEDE83819EAE47456833C1FDFC.
- Size: 15,305,461 bytes; 90 files.
- Managed file version: 0.14.0.0; native baseline 0.12.3/ABI 11.
- Native SHA256: E5FFE6399442E1599C59F94FC64A7E063C9A3B78289AAECFD1E8450267B63EB5.
- Baseline: accepted KH01.5 candidate 0.2, archive SHA256
  90F1699C5DAA5388988DCD0241A28E075D4B688E252926948B203A0D26EE7DD6.
- No dependency or license change: retain the accepted thirteen-package SSH.NET
  prerelease.6/f099365 closure, WinPTY, CRT and native/shim binaries.
- The manifest records exact modified source input hashes and unaccepted target
  status. Do not rewrite the immutable issue-time manifest after target testing.

The portable image/import audit passes. All eight diagnostic stages pass on
PowerShell 5.1, PowerShell 2.0, CMD and an independently extracted path with
spaces (32 passing stages). ZIP entries match staging hashes and the review
copy matches the packaged ZIP. Evidence is under
artifacts/vt7/packages/VT7-SSH-Lifecycle-SL01-1-0.4-x64-local-logs:
PS5/ssh-lifecycle-sl01-1-20261005-055636-3b7ebd82,
PS2/ssh-lifecycle-sl01-1-20261005-055656-33d11de8,
CMD/ssh-lifecycle-sl01-1-20261005-055718-33ae8ec4 and
extracted-PS2/ssh-lifecycle-sl01-1-20261005-055740-5592da97.

## Target procedure

Use the new candidate README and RUN-SSH-LIFECYCLE-SL01-1.cmd on all three
Windows 7 tiers. The automated gate needs no Debian listeners or credentials.
Return each complete Logs directory even on success.

Then use ordinary SSH on 10.3.3.2:22 for normal exit, sequential connections,
explicit disconnect, htop/nano, resize/scroll/input, pending/active window close
and a client-scoped connection-loss observation. Record how the loss was
introduced and elapsed time. A silent blackhole has no fixed detection guarantee
in this slice. Do not disturb the main sshd or unrelated connections.

LEOPARD does not require WMF 5.1 or system OpenSSH; interactive PowerShell 2.0
remains outside the accepted editor corpus. The larger roadmap checkbox stays
open until its remaining staged-deadline/I/O/rekey/exit-status requirements pass.

## Accepted Windows 7 results

The owner returned three complete Logs directories. All eight stages pass in
each run (24 passing target stages). All three identify Windows 7 SP1 x64,
.NET Framework Release 528049, application 0.14.0 and native ABI 11. Package
inventory verification covers 89 files and matches issued candidate 0.4's
host, native, SSH.NET and manifest hashes.

| Machine | Runner PowerShell | Returned run |
| --- | --- | --- |
| LEOPARD | 2.0 | ssh-lifecycle-sl01-1-20261005-061618-1721e4fc |
| TURTLE | 5.1.14409.1005 | ssh-lifecycle-sl01-1-20261005-062754-5a749768 |
| NESSY | 5.1.14409.1018 | ssh-lifecycle-sl01-1-20261005-062838-697e7f01 |

The reports verify original-shell PID preservation and status 255 for typed
refusal/cancellation in Command Prompt on all three machines, and in Windows
PowerShell 5.1 and exact PowerShell 7.2.24 on NESSY/TURTLE. LEOPARD correctly
skips profiles outside that automated interactive qualification scope.

The owner reports clean live operation in every tested shell, including
PowerShell 2.0 on LEOPARD. Closing while connecting, active or disconnecting
was immediate, with no observed remnants. Explicit disconnect returned 255 to
a usable local shell, and subsequent sessions worked. The owner clarified that
the Disconnect SSH button was used, rather than interrupting the network.
The earlier duration-dependent observation therefore does not qualify network
loss or establish a detection threshold. No new silent-network-loss acceptance
or automatic replay/reconnection contract is claimed. The owner's
PowerShell 2.0 smoke result does not qualify its full interactive editor corpus.

Original evidence is retained under
artifacts/vt7/evidence/ssh-lifecycle-sl01-1-win7-0.4-review/Logs, with
SHA256SUMS.txt and REVIEW.json alongside it. The runner's LiveAccepted=False
and the immutable issue-time manifest describe the automated/issue-time state;
this later record supplies the owner's live acceptance without rewriting them.

## Separate SSH prompt glyph finding

The screenshot codex-clipboard-3889b782-8a89-4642-9960-e4a723ee7b01.png shows
working box-drawing prompt lines and one missing symbol between the prompt's
names. Its exact Unicode scalar is not established from the image. Previously
accepted typed SSH package 0.3 explicitly passed Croatian text; that did not
establish coverage of every script or decorative prompt symbol.

Direct ZIP entry hashing confirms that candidate 0.4 and accepted KH01.5
candidate 0.2 have identical VT7.Native.dll, Renci.SshNet.dll and all five
fonts/ entries. The SSH reader still passes raw bytes to the unchanged output
pump; SL01.1 changes ownership and failure handling. The current private font
fallback intentionally covers uncovered standalone symbols only in
U+2190-U+2BFF and U+1F000-U+1FAFF; other scripts depend on system font coverage.
This narrows the investigation to the specific symbol rather than general SSH
Unicode handling.

The owner subsequently confirmed that Croatian letters display correctly.
The follow-up screenshot codex-clipboard-236c710b-15f4-438f-8c4e-42a8c426ea7d.png
shows printf supplied only the octal byte 304 (hex C4). That byte alone is an
incomplete UTF-8 sequence, so its replacement character is expected; it is not
the complete lower/upper-case Croatian discriminator originally requested.
The subsequent PS1 dump in screenshot
codex-clipboard-f173e86e-9f6c-493c-bfc0-03c8e666fde0.png contains the literal
variable reference ${prompt_symbol}, hex
24 7b 70 72 6f 6d 70 74 5f 73 79 6d 62 6f 6c 7d, rather than the icon's
value. The prompt expands that variable when displayed.

The final screenshot codex-clipboard-95860251-35ce-44b1-9523-bd50e81daa5e.png
dumps prompt_symbol as f0 92 80 b2 20. Strict UTF-8 decoding gives U+12032
followed by U+0020 SPACE. The [Unicode Cuneiform chart](https://www.unicode.org/charts/PDF/U12000.pdf)
identifies U+12032 as CUNEIFORM SIGN ANSHE. This scalar is outside both private
fallback ranges, so the bundled fallback is not consulted for it. The observed
missing-glyph box shows the tested system fallback is not supplying a visible
glyph either. The owner also reports the same issue with an older package;
that comparison does not identify a regression introduced by SL01.1.

Diagnosis: a pre-existing coverage gap for this supplementary Cuneiform symbol,
not a demonstrated general SSH UTF-8 regression. Retain the exact byte sequence
and screenshot as a required UT01.2 font-repertoire/fallback fixture under the
owner-approved [current-upstream parity plan](../architecture/2026-10-05-upstream-text-and-font-parity-plan.md).
That 2026-10-05 scope decision promotes necessary POL04/POL05 capabilities to
required work before polish/1.0; text parity itself remains unaccepted.
No production renderer changes or new candidate are made in this investigation.
The bounded SL01.1 acceptance remains intact.
