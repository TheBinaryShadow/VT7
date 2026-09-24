# Windows 7 SP1 without WMF 5.1: compatibility assessment

Status: candidate 0.1 issued; LEOPARD target-machine evidence pending. This
is not an accepted compatibility claim for Windows PowerShell 2.0.

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

Until target evidence passes, the product floor remains Windows 7 SP1 x64
with its existing platform prerequisites and .NET Framework 4.8. WMF 5.1
remains required for the existing 5.1-specific **test scripts and profile
qualification**, not for launching VT7's Command Prompt or SSH sessions.

LEOPARD and NESSY both reported `Release REG_DWORD 0x80eb1` (`528049`),
confirming .NET Framework 4.8 independently of LEOPARD's PowerShell 2.0
process CLR. This is prerequisite evidence only, not an application run.

Candidate 0.1 has application version 0.12.4/ABI 11 and SHA256
`5E94F09166C17683083729BD91B442FF0C407697A45E81B8715889A4E7C864F3`
(15,286,536 bytes; 96 verified files). Its manifest points to clean source
commit `2d18ff3c9` and the accepted KH01.4 package 0.8 closure. The Release
build, PowerShell 5.1 profile and H01 regressions, staged baseline runner,
and independent extracted ZIP verification pass on the development host. The
baseline runner creates `prerequisites.txt` and five VT7 diagnostic logs;
none of these local checks substitutes for LEOPARD's Windows 7/PowerShell 2.0
result. `RUN-KNOWN-HOSTS-KH01-4.cmd` and `RUN-SSHNET-OVERLAY.cmd` still require
PowerShell 5.1 and must not be used as LEOPARD baseline checks.

Sources: [Microsoft's WMF 5.1 KB3191566 description](https://support.microsoft.com/en-au/topic/update-for-windows-management-framework-5-1-for-windows-7-and-windows-server-2008-r2-918077a1-ebc1-289f-bc04-8cc4546eafd0),
[.NET Framework version detection](https://learn.microsoft.com/en-us/dotnet/framework/install/how-to-determine-which-versions-are-installed),
[.NET Framework/Windows version matrix](https://learn.microsoft.com/en-us/dotnet/framework/get-started/system-requirements),
and [CLR side-by-side behavior](https://learn.microsoft.com/en-us/dotnet/framework/install/versions-and-dependencies).
