VT7 WPF resource reactivation diagnostic 0.1 (x64)

Extract the complete ZIP into a NEW local folder, then double-click
RUN-RESOURCE-REACTIVATION.cmd. Return the entire newly created
Logs\resource-reactivation-<run-id> folder, including any error or partial logs.

Use the same Windows 7 test configuration. This uses .NET Framework 4.8 and
64-bit Windows PowerShell, already present on the test machine. No debugger,
Visual Studio installation, symbol download or additional system change is
needed. Keep the console open and the machine awake on its normal desktop.
Allow up to 40 minutes; do not run another VT7 diagnostic at the same time.
The real WPF windows are transparent and do not take focus, as in the existing
lifecycle test. The console may be quiet while reactivation.log keeps growing.

The diagnostic keeps ONE WPF application process alive. After the original
two warm-up lifetimes, it runs two batches of the existing 100 complete window
lifecycles, including scheduling, exact redraw, resize, tab and shutdown checks.
After each batch it observes closed-window resources at +10, +90 and +180
seconds. These are elapsed targets from final lifecycle completion, not three
additional consecutive delays. All native windows from each batch are disposed.
The ordinary application dispatcher remains active during the waits.

The original post-warm-up baseline is never reset. Each 25-cycle checkpoint
keeps the existing 64 MiB private / 32 handles / 8 threads / 16 GDI / 16 USER
growth limits. A failure is retained through both rounds and all idle samples.
The report also compares late idle against pre-warm-up and round 2 against
round 1. Thread identity uses TID plus creation time, with liveness checks.
Failed queue queries are unavailable evidence. A thread missing from a later
snapshot is not, by itself, proof that it exited or released a particular handle.

Collection complete with resource-budget failures is useful evidence:
  exit 0: collection complete, all eight immediate resource budgets met;
  exit 3: collection complete, one or more resource-budget failures retained;
  exit 1: collection incomplete or failed launcher/validation;
  direct EXE exit 2: invalid arguments or an output-file failure.
Neither collection outcome grants C3 acceptance or qualifies a timed soak.
Workload/render/shutdown failures stop collection; only budget failures allow
it to continue, subject to the unchanged resource safety ceilings.

The new VT7.ResourceReactivation.exe is a separately identified managed WPF
diagnostic. The issued native 0.3.5 DLL, ABI 8, fonts and runtime DLLs are
unchanged. No private WARP hooks are used and no security, input, IME, power or
worker settings are changed. Earlier diagnostic packages remain independent.
WPF probe/status logging is preserved and routed under the run's companion
reactivation.log.wpf-probes directory. Those ordinary host logs use their
original per-second filenames; reactivation.log is the complete checkpoint log.

SHA256SUMS.txt covers every distributed file except itself. PACKAGE-MANIFEST.json
records source/build provenance and the mapping of inherited 0.3.5 files.
Historical host launchers under provenance are evidence, not this diagnostic's
entry point. Sources and matching symbols are supplied for examination.
