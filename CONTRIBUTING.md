# Contributing to VT7

Thank you for wanting to help build the terminal application Windows 7 always
deserved.

VT7 is in pre-alpha development. The architecture is still being proven, so a
small, focused change with clear Windows 7 reasoning is more useful than a large
rewrite that assumes the destination is already settled.

## Before starting

1. Read the [README](README.md), [development handoff](doc/vt7/HANDOFF.md),
   [roadmap](ROADMAP.md), and [upstream policy](UPSTREAM.md).
2. Search the [issue tracker](https://github.com/TheBinaryShadow/VT7/issues) for
   an existing discussion.
3. Open an issue before beginning a large feature, architectural change,
   dependency addition, renderer rewrite, or compatibility layer.
4. Keep pull requests narrow enough to review and test.

Small documentation corrections, test improvements, and obvious bug fixes do
not need a lengthy design discussion.

## What helps most right now

Follow the [port-first plan](doc/vt7/architecture/2026-09-12-port-first-plan.md):
reuse pinned upstream behavior and focus on Windows 7 adaptation and application
integration. State which current checkpoint or required workflow a change serves.
For a new experiment, name the blocking question, bounded test and decision it
will enable before expanding the probe suite.

Record non-blocking observations in the roadmap's Milestone 7 register, with
user impact, evidence, baseline/workaround, proposed follow-up and a condition
that would make the issue blocking. Optional typography, UI refinements and
optimizations should not interrupt the port. Release triage may defer them to
post-release work. Source loss, unsafe input, security, stability and failures
of required workflows remain immediate concerns, not optional polish.

Start with [BUILDING.md](BUILDING.md) and the current
[stability record](doc/vt7/validation/2026-09-13-atlas-stability.md).
The working source is 0.3.5/ABI 8, with a static Atlas viewport, not sessions.
The earlier 0.2 host/core proof ran on tested Windows 7 non-ESU and ESU setups;
that historical result does not qualify every later build or update tier.

The isolated Atlas backend proof now also has Windows 7 hardware/WARP results,
including visible Direct3D11 and repeated device recreation. Read the
[backend validation record](doc/vt7/validation/2026-09-11-atlas-backend-proof.md)
before renderer changes. Preserve the GDI regressions and keep fixed-glyph
backend evidence separate from full font shaping, controller integration,
automatic recovery, and session acceptance.

- Reproducible Windows 7 build and runtime investigation.
- Hardening the isolated TerminalCore boundary and removing modern renderer
  dependencies.
- Windows 7 Atlas, DXGI, Direct3D 11, and WARP work.
- WPF styling/contrast fixes, visual regression coverage, and native HWND
  lifetime and resize hardening.
- Local PTY fidelity experiments and subsequent WinPTY candidate integration.
- Microsoft Win32-OpenSSH direct-I/O/control-path experiments before selecting
  the SSH implementation.
- Dependency, imported-API, and behavior-level compatibility audits.
- Automated tests that protect Windows 7-specific behavior.
- Physical Windows 7 testing with precise system and driver information.

Follow the [port-first checkpoints](doc/vt7/architecture/2026-09-12-port-first-plan.md)
and link relevant changes to the [experiment IDs](doc/vt7/research/20-validation-and-experiments.md).
The minimum font boundary and integrated Atlas viewport now have local and
supplied Windows 7 C1/C2 acceptance in 0.3.0. C3 renderer gates are next; see the
[integration record](doc/vt7/validation/2026-09-12-atlas-viewport.md).
0.3.1 C3 repaint/cursor and status checks have local and supplied Windows 7
acceptance recorded in the
[repaint record](doc/vt7/validation/2026-09-12-atlas-repaint.md).
0.3.2 automatic fallback and controlled recovery pass supplied target testing;
see the [recovery record](doc/vt7/validation/2026-09-12-atlas-recovery.md). Keep
injected failures distinct from real driver failures and forced renderer modes strict.
0.3.3 font/settings tests passed at actual Windows 7 96/120/144 DPI but exposed
higher-scale viewport/recovery failures. Current 0.3.4 passes all positive suites
at those scales on the supplied setup, accepting the bounded scaling checkpoint.
Build 0.3.5 implements scheduling/idle/resource/shutdown checks, with distinct quick, full-lifecycle
and extended-soak profiles. Follow the [stability record](doc/vt7/validation/2026-09-13-atlas-stability.md),
keep resource-growth failures visible and do not equate a quick pass with target
soak acceptance. Native HWND destruction must finish before its presentation
worker exits; hidden workers park rather than terminate.
Hardware lifecycle passes locally and on the supplied Windows 7 setup, while
integrated WARP growth remains unresolved. The native-only comparison grows in
both modes on Windows 7, unlike the development machine's power/plain contrast.
The next proposed bounded diagnostic is recreate versus reuse with individual
thread identities. It is not implemented or accepted; do not widen budgets,
increase warm-up to hide growth, disable input/security features, or run the
timed soak as a substitute for attribution.
Retain negative controls and exact same-device
comparisons; see the [correction record](doc/vt7/validation/2026-09-12-atlas-scaling-correction.md).
The 3A feasibility gate applies before substantial local
integration or daily-driver UI work. Research priority labels are not new test
results or permission to skip an open acceptance gate.

## Windows 7 compatibility rules

- Do not assume an API exists because the current Windows SDK exposes it.
- Check the documented minimum client and the actual import table.
- Check flags, enum/metric values, required interface methods, and lifetime
  semantics too. A downlevel export can still be used with unsupported behavior.
- Keep compatibility wrappers explicit and close to the platform boundary.
- Prefer runtime feature detection when multiple Windows versions can share a
  safe code path.
- Do not require users to replace system DLLs or install a global compatibility
  layer.
- Do not silently raise the Windows 7 prerequisite floor.
- Test with the hardware Direct3D 11 path and WARP where the change affects
  rendering.
- Record the Windows edition, update tier, architecture, GPU, driver, shell,
  and session backend used for manual tests.
- Keep core/renderer capability separate from end-to-end backend fidelity.
  Include exact dependency/font versions and package hashes where applicable.
- Add cancellation, bounded-resource, callback-ownership, and output-policy
  tests with each session feature. Keep secrets and ordinary terminal content
  out of default logs; replay must not perform desktop actions by default.

Passing on Windows 10 or Windows 11 is useful information, but it is not proof
that a VT7 change works on Windows 7.

## Code and writing style

Follow the established style of the subsystem you are modifying unless VT7 has
documented a deliberate difference.

VT7 does not use em dash characters. Do not add Unicode U+2014 to source,
comments, documentation, tests, resources, commit messages, issue text, or pull
request text. Use a normal hyphen, comma, colon, parentheses, or a new sentence.

Before submitting project-authored text, you can check for the character with a
Unicode-aware search for code point U+2014.

Also:

- Explain why a compatibility workaround exists.
- Include the relevant Windows version or API boundary in the comment when it
  will help future maintainers.
- Avoid broad formatting-only changes mixed with functional changes.
- Prefer names that describe behavior rather than the current workaround.
- Add or update tests when behavior changes.

## Third-party code and provenance

Do not copy code from another project without checking its license or obtaining
clear permission.

When adapting third-party code:

1. Name the source project, file, and commit in the pull request.
2. Preserve copyright and authorship information.
3. Explain what was changed.
4. Update the appropriate notice when the code is actually included.
5. Keep separately licensed code identifiable when its license requires that.

## Pull requests

A useful pull request includes:

- The problem being solved.
- Why the solution is appropriate for Windows 7.
- Any post-Windows 7 APIs or SDK assumptions considered.
- Manual and automated validation performed.
- Exact Windows 7 test configuration when applicable.
- Screenshots or short recordings for visible changes.
- Source and license details for adapted code.

Draft pull requests are welcome for difficult compatibility experiments. Mark
unproven conclusions clearly so that an experiment is not mistaken for a final
implementation.

## Commit history

Write short, descriptive commit subjects. Keep imported upstream changes
traceable to their source commit. Do not rewrite Microsoft Terminal history or
remove existing attribution to make the fork look independent of its roots.

## Keeping the project resumable

For a development or test checkpoint, update the [handoff](doc/vt7/HANDOFF.md),
the relevant validation record and any affected roadmap/build/component notes.
Record source version/ABI, configuration, exact artifact identity, target
environment, complete versus partial execution, expected negative controls,
unresolved failures, and the next bounded decision. Keep dated results intact;
add a follow-up instead of converting old evidence into a new pass.

`artifacts/` is ignored. A local archive, diagnostic source, screenshot or log is
not available to a fresh clone merely because a document links to its path.
Preserve useful source/commands or reviewable transcripts in versioned
documentation, or arrange a separately identified artifact handoff. The
[native investigation appendix](doc/vt7/diagnostics/2026-09-13-resource-investigation.md)
records the current control for that reason. Never claim a rebuild is the
byte-identical issued artifact without a matching hash.

## License of contributions

VT7 is licensed under the [MIT License](LICENSE). By submitting a contribution,
you agree that your contribution may be distributed under that license and
confirm that you have the right to provide it under those terms.

## Community

Be patient, specific, and kind. Windows 7 attracts people with very different
hardware, constraints, languages, and reasons for staying. The project exists
to make their lives better.

The [Code of Conduct](CODE_OF_CONDUCT.md) applies to all project spaces.
