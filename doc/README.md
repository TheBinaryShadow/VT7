# Documentation in the VT7 repository

For this Windows 7 port, start with [VT7 documentation](vt7/README.md) and the
[development handoff](vt7/HANDOFF.md). Current build instructions are in
[BUILDING.md](../BUILDING.md), using `VT7.sln`.

## Current VT7 guidance

- [Project purpose](../README.md), [roadmap](../ROADMAP.md),
  [contribution policy](../CONTRIBUTING.md) and [upstream policy](../UPSTREAM.md).
- [VT7 architecture and current execution plan](vt7/architecture/2026-09-12-port-first-plan.md).
- [Dated VT7 validation](vt7/README.md#evidence-by-stage).
- [Research index](vt7/research/README.md), retained proposals rather than new
  implementation claims or instructions to run every experiment.
- [Support](../SUPPORT.md) and [private security reporting](../SECURITY.md).

## Retained Microsoft Terminal material

Most other files in this directory predate VT7. They document Microsoft's
Terminal/Console architecture, original build and test systems, settings,
features, internal lab processes and historical plans. This includes `specs/`,
`cascadia/`, `user-docs/`, the older Terminal roadmaps and OpenConsole guides.
They remain useful source references; they are not VT7 feature promises,
Windows 7 qualification, active CI, or the supported VT7 build workflow.

In particular:

- [building.md](building.md) concerns OpenConsole, not the VT7 solution.
- [Debugging.md](Debugging.md) includes upstream packaged-app/global-debugger
  material. VT7's present resource investigation uses process-only diagnostics.
- [WindowsTestPasses.md](WindowsTestPasses.md), [UniversalTest.md](UniversalTest.md)
  and [TAEF.md](TAEF.md) describe inherited test infrastructure, not tests run
  for the current VT7 candidate.
- [ORGANIZATION.md](ORGANIZATION.md) maps the inherited tree; the current
  [handoff code map](vt7/HANDOFF.md#code-map-for-that-task) covers the VT7 boundary.
- [submitting_code.md](submitting_code.md) is historical upstream branch/CI
  guidance. Use the root contribution and upstream policies instead.
- [user-docs/index.md](user-docs/index.md) points to Microsoft Terminal user
  documentation, not a finished VT7 terminal's manual.

Preserve upstream history, copyright, licenses, quoted research and dated
findings. Add a clearly scoped follow-up when VT7 behavior differs instead of
rewriting historical material into a claim about the current port.
