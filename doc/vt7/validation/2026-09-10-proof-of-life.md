# Windows 7 proof-of-life observations, 2026-09-10

> Historical validation record. Status and next steps below describe this checkpoint.
> For current work, see the [handoff](../HANDOFF.md) and
> [0.3.5 C3 stability investigation](2026-09-13-atlas-stability.md).

The user supplied a screenshot and three diagnostic logs from proof 0.1.0:
`proof-20260910-111631.log`, `proof-20260910-111639.log`, and
`proof-20260910-111640.log`. This record summarizes the observations without
committing private local paths or the original logs.

- All three report `Passed: True` and no probe error. Their contents differ
  only in capture timestamp, over a nine-second interval.
- Native ABI 1 matched the managed host; the build was Release x64 using
  compiler 19.44.35228.
- OS detection reported Windows NT 6.1.7601, SP1, 64-bit, workstation.
- Managed runtime: .NET Framework 4.8.4795.0.
- Graphics adapter: AMD Radeon RX 6800 XT, approximately 16 GiB dedicated memory.
- Hardware D3D11 and WARP creation succeeded at feature level 11.0.
- DXGI 1.2 was available through `IDXGIFactory2`.
- The supplied screenshot shows the WPF diagnostic host running on Windows 7.

This supports proceeding from the host/bridge proof to the native viewport
integration. It does not validate TerminalCore, text rendering, session
backends, extended stability, or clean-machine installation. Those features
were absent from 0.1. The exact installed update set, driver version, and
presence or absence of system modifications were not captured, so these results
do not independently establish the defined Tier A floor.

Proof 0.2 introduces ABI 2 and a much larger native dependency boundary. Its
subsequent Windows 7 tests are recorded separately in
[the viewport validation record](2026-09-10-viewport-proof.md). That record also
includes the tester's clarification of the non-ESU and ESU setups. The later
results do not expand what these earlier 0.1 logs themselves demonstrate.
