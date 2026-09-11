# VT7 Support

VT7 is currently a pre-alpha development project. There is no supported public
release and no finished application to install yet.

The 0.2 engineering proof displays a static TerminalCore-backed viewport and
has been tested on Windows 7 SP1 x64 setups with and without ESU. It does not
run local shells or SSH sessions. See the
[validation record](doc/vt7/validation/2026-09-10-viewport-proof.md) for scope.
The 0.2.1 cleanup corrects the original tab/diagnostic text contrast defect and
passes its Windows 7 runtime and visual recheck. Non-ESU logs and screenshots
are supplied; keyboard navigation/focus and the separate ESU run are
tester-confirmed. See the
[cleanup acceptance record](doc/vt7/validation/2026-09-10-milestone-1-cleanup.md).

The separate Atlas backend proof 0.1 now passes its four automated Windows 7
hardware/WARP modes, with visible Direct3D11 and repeated R-key recreation
checks. It uses fixed glyphs, not the complete terminal font/controller path.
See the [backend acceptance scope](doc/vt7/validation/2026-09-11-atlas-backend-proof.md).

## Questions and help

Current development prioritizes the Windows 7 application port. Non-blocking
ideas are welcome and are collected for Milestone 7 polish/release triage in the
[roadmap](ROADMAP.md); they are not promises for the first release. Report broken
required workflows, text corruption, crashes and security concerns promptly
through the appropriate channels below. Those are not cosmetic backlog items.

Use the [VT7 issue tracker](https://github.com/TheBinaryShadow/VT7/issues) for:

- Build and development questions.
- Windows 7 compatibility findings.
- Reproducible bugs in VT7 code.
- Feature proposals that fit the roadmap.
- Documentation problems.

Search existing issues before opening a new one. Include the requested Windows
7 diagnostics in bug reports, especially the update tier, physical or virtual
machine status, GPU and driver, shell version, and session backend.

For the viewport proof, attach `VT7-diagnostics.log`, `VT7-viewport-test.log`,
and screenshots for visible problems. Shell and session details do not apply
to this static build. For older 0.2.0 builds with the contrast defect, use the
text logs for readable diagnostics. Review logs for private local paths before
sharing.

For the independent capability probe, attach `VT7-renderer-probe.log`.
For the Atlas backend proof, attach its `Logs` folder and visible screenshots.
Identify Direct3D11 versus Direct2D and hardware versus WARP; preserve older
logs before rerunning a launcher, which overwrites its own files. Back-buffer
PNGs are useful diagnostics but are not desktop screenshots. Report hangs and
retain partial logs rather than treating missing completion as success.

Do not report VT7-specific problems to Microsoft. VT7 is independent from
Microsoft Terminal and has no Microsoft support relationship.

## What support means here

Support is provided by the community on a best-effort basis. Response times and
fixes are not guaranteed. A tested compatibility claim in a VT7 release means
that the project tested that configuration. It does not restore Microsoft
support for Windows 7, PowerShell, .NET, or any other retired component.

## Security reports

Do not publish suspected vulnerabilities or exploit details in a normal issue.
Follow [SECURITY.md](SECURITY.md) and use GitHub private vulnerability reporting.

## Unofficial builds

There are no public VT7 terminal releases yet. Local engineering proof packages
are not alpha releases. When releases begin, official artifacts and checksums
will be published only through the
[VT7 releases page](https://github.com/TheBinaryShadow/VT7/releases). Treat
builds from other locations as unofficial unless the project explicitly says
otherwise.
