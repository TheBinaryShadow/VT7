# VT7 Upstream Policy

VT7 is an independent fork and adaptation of Microsoft's open-source Terminal
repository. Preserving that history is both technically useful and the right
way to respect the people whose work makes VT7 possible.

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
and third-party notices. We will not flatten the repository into an unattributed
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

The 0.2 viewport proof compiles selected inherited sources directly into a
VT7-only static library. Its `VT7_CORE` compatibility branches, dependency pins,
disabled features, and testing limits are recorded in
[the core boundary notes](src/vt7/VT7.Core/README.md). Review those branches when
updating any affected upstream file. The GDI proof surface is VT7-specific and
does not replace the Atlas integration work.

The isolated `VT7.Renderer` target now compiles the inherited Atlas backends,
shaders, and ColorFix, plus VT7's shared Windows 7 presentation helper. The
`VT7_ATLAS` branches select older graphics/font-face interfaces and disable
unsupported optional paths. Backend interface-query fixes also touch the
inherited Atlas sources. Review these changes when updating the affected files;
the [renderer boundary notes](src/vt7/VT7.Renderer/README.md) describe their scope.
The standalone backend proof has passed on the tested Windows 7 machine, but
the full AtlasEngine font mapper and renderer controller remain unported.
This work does not change the recorded upstream baseline or merge policy.

Microsoft Terminal continues to evolve. VT7 should benefit from upstream parser,
TerminalCore, security, correctness, and performance improvements without
blindly importing new platform dependencies.

Our synchronization rules are:

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

## Local remotes

A normal VT7 checkout should use:

```text
origin    https://github.com/TheBinaryShadow/VT7.git
upstream  https://github.com/microsoft/terminal.git
```

Contributors may use different remote names, but pull requests should clearly
state whether a change was authored for VT7, adapted from Microsoft Terminal,
or taken from another source.
