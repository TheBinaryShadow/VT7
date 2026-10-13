# Milestone 6: Product qualification and hardening

[Roadmap](../../../ROADMAP.md) | [Documentation](../README.md)

These are the detailed requirements and recorded results for this milestone.
An accepted slice does not close an unchecked parent requirement.

## Milestone 6: Product qualification and hardening

Qualify the assembled port for release readiness, then extend this evidence
through alpha/beta feedback. Milestone 7 makes the public release decision;
hardening and release review repeat as the product approaches 1.0.

- [ ] Qualify the complete product across a repeatable physical/virtual Windows 7
  matrix. Verify a clean minimum Tier A image without developer tools (L01),
  plus separately recorded ESU, WARP, and additional hardware coverage. Recheck
  prerequisite/dependency closure whenever a new runtime is introduced, not
  only at final packaging; shell requirements remain separate from host needs.
- [ ] Consolidate and extend the parser, buffer, renderer, input, settings, PTY,
  SSH, accessibility, and output-policy regression suites developed in each
  milestone. This is not their first implementation stage.
- [ ] Verify opt-in diagnostic privacy, redaction, exact run/package manifests,
  and bounded resource behavior across the assembled product.
- [ ] Add crash reporting artifacts that users can attach manually.
- [ ] Measure startup, memory, active/hidden/minimized CPU, input-to-present
  latency, queue/cache growth, and sustained output against budgets established
  on target hardware. Extend earlier per-milestone measurements.
- [ ] Test long-running sessions and repeated tab and pane creation. Retain
  active and equivalent settled-state resource trends for hardware and WARP;
  use this ordinary product evidence for REL01, without an automatic extra
  attribution campaign or rewriting the earlier investigation-budget failures.
- [ ] Qualify UI01/SSHUX01 together on Windows 7: Aero and Basic/no-glass title
  layouts, high contrast and DPI changes, keyboard/screen-reader focus across
  `HwndHost` and menus, hidden-tab output, pending SSH prompts during tab switch
  and close, cross-tab isolation, secret/log privacy and local-shell recovery.
- [ ] Qualify UT01's complete text/font parity corpus with pinned upstream/font
  evidence and real local/SSH sessions. Resolve required differences and review
  then-current stable text/font changes before the 1.0 reference freeze.
- [ ] Produce signed or checksum-verifiable portable release artifacts.
- [ ] Document installation, prerequisites, recovery, and uninstallation.

