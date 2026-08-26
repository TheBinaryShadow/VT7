# VT7 Security Policy

VT7 takes security reports seriously, including reports that affect an
unsupported operating-system target.

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability.

Use GitHub's private vulnerability reporting for VT7:

[Report a vulnerability privately](https://github.com/TheBinaryShadow/VT7/security/advisories/new)

If that option is temporarily unavailable, do not publish exploit details.
Contact the repository maintainer through the private contact method listed on
the maintainer's GitHub profile and mention that you have a VT7 security report.

Include as much of the following as you safely can:

- A clear description of the problem and expected impact.
- The affected VT7 commit or release.
- The affected Windows 7 configuration and update tier.
- Reproduction steps or a minimal proof of concept.
- Relevant logs, stack traces, or crash dumps after removing secrets and
  personal data.
- Whether the issue appears inherited from Microsoft Terminal, a third-party
  component, or VT7-specific code.
- Any suggested mitigation.

We will acknowledge reports as time permits, investigate them privately, and
coordinate disclosure when a fix or mitigation is ready. VT7 is currently a
small community project, so no guaranteed response deadline is offered.

## Supported versions

VT7 has not published a supported release.

| Version | Security status |
| --- | --- |
| `main` | Active development, no stability or support guarantee |
| Unofficial builds | Not supported by the VT7 project |

This table will be updated before the first public alpha release.

## Scope notes

A VT7 security fix does not make Windows 7 secure or supported. Reports about
Windows 7 itself should follow the appropriate vendor or researcher disclosure
process. Reports about VT7's own parsing, rendering, session handling, SSH,
settings, update, packaging, or dependency behavior belong here.
