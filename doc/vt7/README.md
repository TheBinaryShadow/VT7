# VT7 documentation

I keep current guidance short and put implementation details and test history
in the linked records. Start with the page that answers the question at hand.

| I need... | Read... |
| --- | --- |
| The current state and next action | [Development handoff](HANDOFF.md) |
| The path to 1.0 | [Roadmap](../../ROADMAP.md) and its milestone checklists |
| Prerequisites and supported test tiers | [Compatibility](plan/compatibility.md) |
| Build and packaging instructions | [Building VT7](../../BUILDING.md) |
| A design or technical contract | [Architecture index](architecture/README.md) |
| What actually passed or failed | [Validation index](validation/README.md) |
| Earlier platform research | [Research index](research/README.md) |
| WARP investigation details | [Diagnostics index](diagnostics/README.md) |
| Documentation conventions | [Writing guide](WRITING.md) |

## Current work and required design

- **SL01.3:** [design](architecture/2026-10-12-ssh-authenticated-startup-stalls-sl01-3.md)
  and [candidate record](validation/2026-10-12-ssh-authenticated-startup-stalls-sl01-3.md).
  Local checks pass; paired Windows 7 acceptance is pending.
- **UT01:** [Unicode, rendering, and font fallback plan](architecture/2026-10-05-upstream-text-and-font-parity-plan.md).
  Required current-upstream capability parity before polish and 1.0.
- **UI01 / SSHUX01:** [final tab, profile, and terminal SSH contract](architecture/2026-09-25-pre-1-0-ui-and-terminal-ssh-contract.md).
  Required final workflows; the present proof UI is temporary.

## Where each kind of information belongs

The handoff records the current task and candidate. The roadmap and milestone
plans define completion requirements. Dated validation records say what was
tested, on which machines, with which binaries, and what remains unproved.
Research supports decisions but does not override the active plan.

When these disagree, check the source and evidence before changing the status.
An implemented feature, a passing local test, and Windows 7 acceptance are
different claims. Historical failures remain part of the record.

## Source boundaries and policies

- [Core boundary](../../src/vt7/VT7.Core/README.md) and
  [renderer boundary](../../src/vt7/VT7.Renderer/README.md).
- [Upstream policy](../../UPSTREAM.md), [contributing](../../CONTRIBUTING.md),
  [support](../../SUPPORT.md), and [security](../../SECURITY.md).
- [Third-party licensing policy](architecture/2026-09-14-third-party-licensing-policy.md)
  and [notices](../../NOTICE.md).

The rest of `doc/` includes inherited Microsoft Terminal material. It describes
upstream behavior and is not automatically a VT7 compatibility claim. I preserve
upstream authorship, quotations, licenses, and raw diagnostic output.

## Historical references and local evidence

The [history index](history/README.md) preserves the former long overview,
handoff, build reference, and documentation map. Use it when investigating an
older checkpoint, not as a second source of current status.

`artifacts/` and supplied test evidence are local, ignored material. A link to
them documents where evidence was reviewed; it does not make those files
available in a fresh clone. Issued ZIPs and manifests remain unchanged when
source documentation is edited.
