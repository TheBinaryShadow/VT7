# VT7 repository workflow notes

This file deliberately is not named `README.md`: GitHub gives a README in
`.github/` precedence over the repository-root README. Keep VT7's project
introduction in the root file. See [GitHub's README selection rules](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes).

This is an independent fork. Use [CONTRIBUTING.md](../CONTRIBUTING.md),
[UPSTREAM.md](../UPSTREAM.md) and the [development handoff](../doc/vt7/HANDOFF.md)
for current work, rather than inherited Microsoft Terminal bot/build policies.

At the 2026-09-13 documentation audit, `.github/workflows/` contains no workflow
files. Retained `actions/`, `policies/` and other upstream configuration do not
by themselves establish an active VT7 workflow. The original automation is not
to be re-enabled without a scoped review of permissions, triggers, prerequisites
and Windows 7 validation. This audit makes no repository-settings or automation
changes and does not verify remote account settings.

The VT7 issue and pull-request templates request actual environment, artifact
identity, test scope and evidence. Current builds are static viewports and
diagnostic controls, not local-shell or SSH releases. Do not enter a planned
session backend as though it was tested. Keep expected negative controls,
unexpected failures and incomplete runs separate.

Security reports follow [SECURITY.md](../SECURITY.md), not public issue templates
or inherited Microsoft reporting instructions. If private vulnerability reporting
is unavailable, use the documented private fallback; do not post exploit details
publicly. Repository description, topics and hosted settings are managed outside
these documentation files.
