# VT7 support

VT7 is in pre-alpha development, with no supported public release yet. For the
current candidate and next test, use the [handoff](doc/vt7/HANDOFF.md). For build
instructions, use [BUILDING.md](BUILDING.md).

## Questions and bug reports

Use the [VT7 issue tracker](https://github.com/TheBinaryShadow/VT7/issues) for
build questions, compatibility findings, reproducible bugs, roadmap proposals,
and documentation problems. Search existing issues first.

To help me reproduce a problem, include:

- The package filename and SHA256, or the source commit and build configuration.
- Windows version and update tier, physical or virtual machine, GPU and driver,
  shell version, and whether the session was local or SSH.
- The exact steps, expected result, actual result, exit code, and any interruption.
- The complete requested Logs and progress files. Keep partial and failed runs.
- A screenshot for a visible problem, plus matching server evidence when the
  package's README requires it.

Follow the **specific candidate README** for what to collect. The current
SL01.3 test requires complete client logs and matching server audits even on
success. An older "logs only on failure" instruction does not apply to it.
Review attachments for private paths and secrets before sharing them. Do not
include passwords or private keys.

Expected negative controls must fail for the reason named by their procedure.
A completed measurement is not automatically a passed acceptance check. Keep
hardware/WARP and different machine runs separate.

The [validation index](doc/vt7/validation/README.md) and
[historical reproduction notes](doc/vt7/history/2026-10-12-support-and-reproduction.md)
cover older packages. They do not request a repeat of completed tests or restart
the deferred WARP tracing work.

## Support scope

I review reports as time permits, with community help. I cannot guarantee a
response time or a fix. A tested configuration describes VT7's evidence; it
does not restore vendor support for Windows 7 or its retired components.

VT7-specific problems belong here, not in Microsoft's issue tracker. VT7 is
independent from Microsoft Terminal and has no Microsoft support relationship.

## Security reports

Do not publish suspected vulnerabilities or exploit details in a normal issue.
Follow [SECURITY.md](SECURITY.md) for private reporting.

## Official artifacts

Local engineering candidates are not public alpha releases. When public
releases begin, official artifacts and checksums will be published through the
[VT7 releases page](https://github.com/TheBinaryShadow/VT7/releases). Treat other
builds as unofficial unless I explicitly identify them otherwise.
