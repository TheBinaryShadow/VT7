# Windows 7 SP1 without WMF 5.1: compatibility assessment

Status: corrected candidate 0.2 passes all six LEOPARD baseline stages,
including the bundled typed-SSH handoff without installed OpenSSH. Live server
connection and the interactive PowerShell 2.0 profile remain unqualified.

KB3191566 installs Windows Management Framework (WMF) 5.1, including Windows
PowerShell 5.1. It is **not** .NET Framework 5.1. VT7's x64 WPF host targets
.NET Framework 4.8; WMF 5.1 is not a VT7 runtime dependency. Windows 7 SP1
can have .NET Framework 4.8 and Windows PowerShell 2.0 side by side. The
`CLRVersion` value reported by PowerShell 2.0 describes that process's CLR 2.0,
not all installed .NET Framework versions.

On the new machine, run these in `cmd.exe` and retain the output:

```cmd
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release
powershell.exe -NoLogo -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"
```

For Windows 7, a `Release` DWORD of `0x80eb1` (decimal `528049`) identifies
.NET Framework 4.8. The code should test at least the 4.8 minimum (`528040`),
not equality with one release value. An absent key or lower value means the
current VT7 executable cannot run, regardless of PowerShell version. Do not
infer .NET Framework 4.8 from `$PSVersionTable.CLRVersion`.

The accepted KH01.4 0.8 package has not been qualified on this machine.
Its `RUN-VT7-COMMAND-PROMPT.cmd` launches the host directly and does not use
PowerShell. Its automated `RUN-KNOWN-HOSTS-KH01-4.cmd` invokes a PowerShell
script written for 5.1 and is not a valid test under PowerShell 2.0. Do not
install KB3191566 merely to make that test runner work. Candidate
`VT7-Legacy-Win7-0.1-x64.zip` packages a separate `cmd.exe`-driven baseline
for the new tier, while the existing PowerShell 5.1/7.2.24 regression remains
on NESSY and TURTLE.

The issued candidate should run this matrix on the pre-WMF machine:

1. Verify the 4.8 release key and actual PowerShell engine version, then
   launch the unchanged Command Prompt profile and run ordinary input, Unicode,
   resize, scrollback, process exit and restart checks.
2. Confirm VT7's profile selector reports the installed Windows PowerShell
   version, without calling 2.0 "5.1". Exercise the 2.0 profile as an
   **unqualified** exploratory path; record editing, control keys, multiline,
   native child and exit behavior separately from the accepted 5.1 corpus.
3. Run the existing SSH.NET direct and typed SSH paths from Command Prompt,
   including trust, reconnect, resize and return to the local prompt. This
   isolates product behavior from the 5.1-only automation layer.
4. Use a PowerShell-2-compatible or native diagnostic runner for any automated
   checks added to this tier. Label unsupported or unrun tests as skipped, not
   passed. Retain the package identity and complete logs for failures.

Until the full target matrix passes, the product floor remains Windows 7 SP1 x64
with its existing platform prerequisites and .NET Framework 4.8. WMF 5.1
remains required for the existing 5.1-specific **test scripts and profile
qualification**, not for launching VT7's Command Prompt or SSH sessions.

LEOPARD and NESSY both reported `Release REG_DWORD 0x80eb1` (`528049`),
confirming .NET Framework 4.8 independently of LEOPARD's PowerShell 2.0
process CLR. The registry observation alone was prerequisite evidence; the
candidate 0.1 application run is recorded below.

Candidate 0.1 has application version 0.12.4/ABI 11 and SHA256
`5E94F09166C17683083729BD91B442FF0C407697A45E81B8715889A4E7C864F3`
(15,286,536 bytes; 96 verified files). Its manifest points to clean source
commit `2d18ff3c9` and the accepted KH01.4 package 0.8 closure. The Release
build, PowerShell 5.1 profile and H01 regressions, staged baseline runner,
and independent extracted ZIP verification pass on the development host. The
baseline runner creates `prerequisites.txt` and five VT7 diagnostic logs.
`RUN-KNOWN-HOSTS-KH01-4.cmd` and `RUN-SSHNET-OVERLAY.cmd` still require
PowerShell 5.1 and must not be used as LEOPARD baseline checks.

LEOPARD ran candidate 0.1. Its `prerequisites.txt` confirms Windows
`6.1.7601`, .NET Framework release `0x80eb1` and Windows PowerShell `2.0`.
All five built-in baseline logs report success: window smoke, Command Prompt
WinPTY, session stream, session outbound and SSH.NET foundation. The owner
also reports ordinary operation works, but typed `ssh` in Command Prompt
returns Windows' "not recognized" message because LEOPARD has no system
OpenSSH client. Source inspection found that `SshOverlayCoordinator.TryCreate`
returned null whenever it could not find an external `ssh.exe`; the bundled
shim was then never prepended to `PATH`. That is a VT7 product defect, not a
PowerShell 2.0 or .NET Framework incompatibility.

Version 0.12.5 removes the external-client gate for the bundled interactive
shim. It still uses an installed external client for unsupported options or
redirected standard handles when available. Without one, the broker returns
an explicit status-255 rejection. A separate built-in no-external check now
covers both authenticated embedded handoff and unsupported-syntax rejection
through Command Prompt. LEOPARD's live network result remains pending.

Candidate 0.2 has application version 0.12.5/ABI 11 and SHA256
`5DB55BB730A242958FDB32EF0DC6F47702BFF43883142435B2E78C27CE9E1450`
(15,289,723 bytes; 97 verified files). Its manifest points to clean source
commit `1baf3c595` and the exact candidate 0.1 archive. Local Debug/Release
H01 runs pass, including the new no-external embedded and fail-closed cases.
The staged six-stage baseline and independent ZIP extraction from a path with
spaces both pass. This does not yet prove LEOPARD's actual SSH connection.
The seven supplied LEOPARD 0.1 baseline files, including the startup capture,
are hash-verified under `artifacts/vt7/evidence/legacy-win7-0.1-leopard`;
they contain no SSH session credentials or trust records.

LEOPARD ran candidate 0.2 on 2026-09-24. Its prerequisite record again shows
Windows `6.1.7601`, .NET Framework release `0x80eb1` and Windows PowerShell
`2.0`. All six built-in logs report `Passed: True`: window smoke, Command
Prompt WinPTY, session stream, session outbound, SSH.NET foundation, and the
new no-external typed-SSH overlay. That last check completed an authenticated
local shim handoff without an external `ssh.exe` and rejected unsupported
syntax with status 255. It is an offline diagnostic, not a live connection to
the owner's Debian server. The logs' `Build: VT7 0.12.3` line comes from the
unchanged native component; the candidate's managed host file version and
manifest identify application 0.12.5. The eight supplied files, including
the startup capture, were reviewed for credentials and trust material and
hash-verified under `artifacts/vt7/evidence/legacy-win7-0.2-leopard`.

The owner initially ran `RUN-KNOWN-HOSTS-KH01-4.cmd` on PowerShell 2.0. That
incompatible launcher printed `passed` after PowerShell rejected
`Set-StrictMode -Version 3.0`, so its output is **not** a KH01.4 result.
The source launchers and scripts now explicitly reject PowerShell older than
5.1 with exit code 2 and point to `RUN-VT7-LEGACY-BASELINE.cmd`. Candidate 0.2
predates that guard and retains the misleading KH01.4 launcher; its six-stage
legacy baseline result is unaffected. The guard will ship with the next
package. LEOPARD's live typed SSH, remote input/resize/exit and direct SSH.NET
connection still require a controlled server run before the full pre-WMF
runtime tier is accepted.

Sources: [Microsoft's WMF 5.1 KB3191566 description](https://support.microsoft.com/en-au/topic/update-for-windows-management-framework-5-1-for-windows-7-and-windows-server-2008-r2-918077a1-ebc1-289f-bc04-8cc4546eafd0),
[.NET Framework version detection](https://learn.microsoft.com/en-us/dotnet/framework/install/how-to-determine-which-versions-are-installed),
[.NET Framework/Windows version matrix](https://learn.microsoft.com/en-us/dotnet/framework/get-started/system-requirements),
and [CLR side-by-side behavior](https://learn.microsoft.com/en-us/dotnet/framework/install/versions-and-dependencies).
