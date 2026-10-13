# VT7 Upstream Policy

VT7 is an independent fork and adaptation of Microsoft's open-source Terminal
repository. Preserving that history is both technically useful and the right
way to respect the people whose work makes VT7 possible.

For the current implementation and next task, use the
[development handoff](doc/vt7/HANDOFF.md). This file owns source provenance and
merge policy, not milestone acceptance. Historical Microsoft Terminal documents
under `doc/`, its samples and original build helpers remain upstream references;
use [BUILDING.md](BUILDING.md) and the [VT7 index](doc/vt7/README.md) for this port.

## Primary upstream

- Project: [Microsoft Terminal](https://github.com/microsoft/terminal)
- License: MIT
- Remote name in this checkout: `upstream`
- VT7 baseline branch: Microsoft Terminal `main`
- Recorded baseline commit:
  `c7572cde0c69733e4511787dc963eb336f17adbf`
- Baseline commit date: 2026-08-25
- Baseline subject: `Pin GitHub Actions to full-length commit SHAs (#20559)`

VT7 retains the upstream Git history, Microsoft copyright notice, MIT license,
and third-party notices. I will not flatten the repository into an unattributed
code dump.

## Relationship to Microsoft Terminal

VT7 is not a Microsoft product and is not supported or endorsed by Microsoft.
Issues caused by VT7 changes belong in the VT7 issue tracker. They should not be
reported to the Microsoft Terminal team unless the issue is independently
reproduced in an unmodified, supported Microsoft Terminal build.

The projects have different platform goals:

| Area | Microsoft Terminal | VT7 direction |
| --- | --- | --- |
| Operating-system floor | Modern supported Windows | Windows 7 SP1 x64 |
| Application shell | Modern Windows application stack | Windows 7-compatible desktop host |
| Local pseudoterminal | ConPTY | WinPTY-first candidate, fidelity-gated behind a replaceable backend |
| Rendering | Current Atlas and modern DXGI paths | Downleveled Atlas path for Windows 7 Direct3D 11 |
| Packaging | MSIX, Store, portable distributions | Portable Windows 7-compatible distribution |
| Composition | Modern Windows composition features | HWND-first Windows 7 presentation |

## Upstream synchronization

The approved [UT01 decision](doc/vt7/architecture/2026-10-05-upstream-text-and-font-parity-plan.md)
requires current-stable upstream Unicode, text rendering and font fallback
support parity before polish and 1.0. Its initial reference is v1.25.2733.0,
commit dc8ae365847d41f62d1ebca93815bb00959bc12f, verified on 2026-10-05.
Review the then-current stable text/font changes again before release freeze.
This behavior target is separate from the c7572cde source pin above. It does
not authorize a wholesale merge or parity for the entire Terminal feature set.
Required UT01 gaps are implementing-milestone work, not optional polish;
the older deferral policy below still applies to improvements beyond that scope.

VT7 follows an upstream-first port policy: preserve the pinned source's terminal
semantics, shaping/cell placement and interaction behavior wherever practical.
Make narrow Windows 7 compatibility adaptations and test their changed boundaries
plus affected regressions. Do not turn improvements beyond upstream into port
prerequisites. Record deliberate behavioral departures with evidence and approval;
optional improvements go to Milestone 7 under the
[port-first plan](doc/vt7/architecture/2026-09-12-port-first-plan.md).
This does not authorize a merge, update the pinned baseline, or waive an inherited
security defect or required-workflow failure.

The [core notes](src/vt7/VT7.Core/README.md) and
[renderer notes](src/vt7/VT7.Renderer/README.md) identify the `VT7_CORE` and
`VT7_ATLAS` branches, source/dependency pins, disabled paths, and interface
adaptations. Review those boundaries when updating affected upstream files.
The [earlier adaptation record](doc/vt7/history/2026-10-12-upstream-adaptation-context.md)
preserves the initial integration history; dated validation records establish
what actually passed. None of those changes silently updates the source pin.

Microsoft Terminal continues to evolve. VT7 should benefit from upstream parser,
TerminalCore, security, correctness, and performance improvements without
blindly importing new platform dependencies.

My synchronization rules are:

1. Fetch upstream regularly, but never merge or rebase it into VT7 without
   review.
2. Prefer focused cherry-picks or carefully reviewed subsystem updates.
3. Examine new Win32, WinRT, DirectX, packaging, and toolchain dependencies
   before accepting a change. Audit flags, metrics, interface methods, and
   behavior on existing exports, not only newly imported API names.
4. Keep Windows 7 compatibility changes narrow and documented when possible.
5. Preserve original authorship and commit references for imported fixes.
6. Add tests for every VT7-specific compatibility behavior that can be tested.
7. Record major upstream reconciliations in release notes or a dedicated merge
   document.

An upstream change being newer does not automatically make it better for VT7.
An older implementation being Windows 7-compatible does not automatically make
it safe. Every import must earn its place.

## Important Microsoft Terminal references

Several upstream branches and historical commits are especially relevant to
VT7 research:

- `dev/duhowett/win7-wpf-termcontrol-squash`
  - Observed tip: `8a5d2ae730666a209ccb5a4ec92c7146d5188429`
  - Contains experimental WPF and flattened control-boundary work for Windows 7.
  - It is reference material, not a finished Windows 7 port.
- `17db409e7ab7869b3757cf911fd1e5d307c9c290`
  - Removed the earlier Atlas Windows 7 support path.
  - Its parent is useful when reconstructing a Windows 7-compatible renderer.
- `bf25595961190d97b6d92bcc23b383713acd1214`
  - Removed the older DxEngine.
  - The removed implementation contains useful Windows 7 HWND and swap-chain
    history.

These references are snapshots. Their ideas must be reconciled with the chosen
VT7 baseline instead of being merged wholesale.

## Secondary source and behavior references

The [2026-09-14 architecture review](doc/vt7/architecture/2026-09-14-session-ownership-and-source-review.md)
records why several outside terminal projects may be useful during session work.
Microsoft Terminal remains the primary upstream. WinPTY 0.4.3 is the only newly
selected runtime among these references; PuTTY and WezTerm are research sources,
and Mintty is a black-box behavioral oracle. No PuTTY, WezTerm or Mintty code or
binary is currently incorporated into VT7.

MIT-licensed source may be considered when it fills an evidenced gap, but every
adoption must retain required copyright and license text and record the exact
upstream revision and local modifications. Do not add a project to `NOTICE.md`
solely because its design was studied. Mintty is GPL version 3 or later; do not
copy or translate its implementation into the MIT application without a
separately reviewed licensing boundary.

For every future upstream or third-party import, record the concrete need, exact
revision, license, obligations, alternatives and distribution effect. My standing 2026-09-14 decision permits compatible permissive
licenses and supplier notice sets when they help deliver the port. Preserve all
required notices and acknowledge the upstream project. Licenses with
source-sharing, network-use, proprietary redistribution or other material
distribution conditions require a separate compatibility review before use.
See the [standing third-party policy](doc/vt7/architecture/2026-09-14-third-party-licensing-policy.md).

## Local remotes

A normal VT7 checkout should use:

```text
origin    https://github.com/TheBinaryShadow/VT7.git
upstream  https://github.com/microsoft/terminal.git
```

Contributors may use different remote names, but pull requests should clearly
state whether a change was authored for VT7, adapted from Microsoft Terminal,
or taken from another source.
