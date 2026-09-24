# OpenSSH-compatible read-only production trust KH01.2

Date: 2026-09-22. Status: target accepted on 2026-09-23. Package 0.2 passes
TURTLE but is rejected for SSH on the NESSY non-ESU machine. Package 0.3 replaces
the affected dependency with the publisher-built upstream correction; its
automated corpus and both stored-key live SSH paths pass on NESSY and TURTLE.

## Scope

VT7 0.10.1 connects the accepted KH01.1 parser and raw-key resolver to both
production SSH.NET entry paths. Before `SshClient.Connect`, `SshNetTransport`
resolves and loads an immutable snapshot of these sources in order:

1. `%USERPROFILE%\.ssh\known_hosts`;
2. `%USERPROFILE%\.ssh\known_hosts2`;
3. `%ProgramData%\ssh\ssh_known_hosts`; and
4. `%ProgramData%\ssh\ssh_known_hosts2`.

The callback performs bounded in-memory evaluation only. It does no filesystem
I/O, UI work or persistence. The exact presented RFC 4253 key blob is accepted
when an ordinary stored key matches. An unknown host is accepted only when the
optional dialog fingerprint exactly pins that callback key for the current
attempt. A supplied fingerprint mismatch remains a block even if the store has
a matching key. Changed, revoked, unreadable and policy-rejected states cannot
be overridden by a fingerprint.

The connection dialog now labels the field **SHA256 fingerprint (if unknown)**.
A stored match can leave it empty; malformed non-empty values are rejected
before connection. This behavior is shared automatically by **Start SSH...** and
the typed `ssh` overlay because both construct the same `SshNetTransport`.

## Loader and failure boundary

Default paths are resolved to absolute paths once from the connection owner's
Windows profile and ProgramData roots. A missing optional source contributes no
records. An existing directory, inaccessible source, over-limit file, read
failure, parse failure or metadata change during loading becomes an unreadable
snapshot and fails closed.

Each readable source retains its length, last-write time, SHA256 content identity
and parsed document. The snapshot owns the decision for that connection attempt;
later file changes do not mutate it. Source IDs in trust results are generic and
do not expose the Windows user name or absolute path through default status text.
KH01.2 never writes, creates, removes or repairs a known-host file.

## Automated evidence

Both Debug and Release builds pass. In both configurations,
`Test-VT7KnownHosts.ps1` passes the accepted KH01.1 parser/oracle corpus and the
new four-source loader and authorization policy cases, while
`Test-VT7SshNetFoundation.ps1` passes the optional-fallback input contract,
exact SSH.NET closure, dialog contrast, transport ownership and geometry. The
Release combined typed-overlay corpus also passes session stream, outbound,
SSH.NET, delayed H01 shim and exact external-fallback checks.

The new corpus uses disposable sources and proves:

- all four user/system source locations and their evaluation order;
- stable absolute source paths, content hashes and immutable connection snapshots;
- optional missing files and fail-closed existing unreadable sources;
- a stored match with no fingerprint;
- unknown rejection without a fingerprint and acceptance with the exact pin;
- rejection of a wrong explicit pin; and
- changed and revoked records overriding an otherwise exact pin.

The local OpenSSH differential oracle remains `ssh-keygen.exe` file version
`9.5.5.2`, SHA256
`2A0D971F935813E324519BCE64E7EB5AF85A5F91517C916270A4368E0786F588`.
The Windows 7 launcher retains the required 10.0p2 file-version gate
`10.0.0.0`.

## Rejected package 0.2

| Property | Value |
| --- | --- |
| Archive | `VT7-KnownHosts-KH01-0.2-x64.zip` |
| Review copy | `artifacts/VT7-KnownHosts-KH01-0.2-x64.zip` |
| SHA256 | `D55AEA3B7572D8177524D62FC113A385AF8DB7DB6B5083FAA0E132C8D1E562A6` |
| Bytes | 15,258,892 |
| Files | 94 verified files |
| Application | VT7 0.10.0, native ABI 11, x64, .NET Framework 4.8 |
| SSH.NET | 2026.0.0 audited net48 closure |
| Production reads | Enabled for the four default OpenSSH sources |
| Known-host writes | Disabled |
| Credentials retained | No |

The package builder audits every image and dependency, preserves the complete
license closure, runs the combined typed-overlay and KH01 corpus from a package
path containing spaces, hashes every staged file and verifies every ZIP entry.
The manifest records a dirty source tree because the review archive was built
from the complete KH01.2 working change before commit; its recursive file hashes
and the archive identity above bind the exact candidate under test.
The independent verifier checks the manifest, SHA256 coverage, application
version, binary closure and a fresh extracted KH01 run. Its initial validation
passed but cleanup found a short-lived WPF font-file lock; the verifier now uses
the package builder's bounded retry and its complete rerun passes.

Package 0.2 remains useful evidence for KH01.2 itself, but it is not the current
runtime candidate. Its SSH.NET 2026.0.0 dependency fails on NESSY as described
below.

## Accepted package 0.3

Package 0.3 advances the application to VT7 0.10.1 while retaining native ABI
11 and the complete KH01.2 behavior. It pins the publisher-built SSH.NET
`2026.0.1-prerelease.6` package from the official GitHub Packages feed. The
package nuspec records upstream commit
`f099365c9d4cf2ade92b92c203bbb2b345d2cd74`, and the net462 assembly reports
`2026.0.1-prerelease.6+f099365c9d`. The retained nupkg SHA256 is
`3981BA4F5A36DADFFDAC19BA8B8F207F594F57B3BA043A794277678669FBC35C`.

| Property | Value |
| --- | --- |
| Archive | `VT7-KnownHosts-KH01-0.3-x64.zip` |
| Review copy | `artifacts/VT7-KnownHosts-KH01-0.3-x64.zip` |
| SHA256 | `B046A3CA97D7EE138D59AB1742C964ACC791B501C10AA32DFD045A37429200A4` |
| Bytes | 15,235,578 |
| Files | 94 verified files |
| Application | VT7 0.10.1, native ABI 11, x64, .NET Framework 4.8 |
| SSH.NET | Publisher-built 2026.0.1-prerelease.6, upstream `f099365` |

Debug and Release builds, both SSH.NET foundation runs, both KH01 runs and the
complete Release overlay corpus pass. Packaging passes its path-with-spaces CMD
launches, image/dependency audit and ZIP-entry hash check. The independent
verifier extracts the archive, rechecks its manifest and complete SHA256 list,
audits every binary, and reruns KH01.2 successfully. Package 0.2 is preserved and
never overwritten.

## Windows 7 procedure

Extract the review archive to a new writable directory and first run:

```text
RUN-KNOWN-HOSTS-KH01-2.cmd
```

Run without elevation. A pass proves the exact target oracle and disposable
loader/policy corpus without reading real trust files, contacting a server or
requesting credentials. Return the complete `Logs` directory if this stage
fails.

Then use the existing Debian 12 `sshtest` server and dedicated private key.
Before testing, verify through the trusted administrative path that the server's
current host key is already stored under the exact hostname/address and port to
be used. Run `RUN-VT7-COMMAND-PROMPT.cmd` and perform both paths with the
fingerprint field empty:

1. type the normal `ssh` command at the local prompt, connect, exercise input,
   resize and scrollback, then exit back to the same local prompt;
2. use **Start SSH...** for the same endpoint, connect and exit cleanly.

Both paths must accept the stored key without fingerprint re-entry. If a second
resolvable spelling of the same controlled endpoint is absent from all four
stores, it may exercise the unknown-host fallback: empty fingerprint must fail,
while the exact independently verified fingerprint must connect. Do not modify
or corrupt a real trust file solely to manufacture changed, revoked or unreadable
cases; the disposable corpus owns those policy checks in this slice.

## Rejected package 0.2 two-machine result

The primary machine passes the automated launcher and both live connection
paths. Its diagnostic reports x64 .NET Framework runtime file version
`4.8.4795.0` and an AMD Radeon RX 6800 XT.

The additional NESSY non-ESU VMware machine passes the same package hashes,
`ssh-keygen.exe` 10.0p2 identity, KH01.1/KH01.2 parser and policy corpus,
TerminalCore tests, Direct3D hardware/WARP probes and font checks. Its installed
Win32-OpenSSH client also connects to the same `10.3.3.254` server, and
`ssh-keygen -F` finds Ed25519, RSA and ECDSA records for that exact host token.
Both VT7 typed and direct SSH.NET paths instead fail during the generic SSH
connection stage before VT7 reports host-key or authentication failure.

NESSY reports `mscorlib.dll` `4.8.4110.0`; the primary reports `4.8.4795.0`.
This exactly matches [SSH.NET issue 1829](https://github.com/sshnet/SSH.NET/issues/1829):
SSH.NET 2026.0.0 reuses the receive HMAC instance across packets, and the older
.NET Framework HMAC implementation either computes a wrong second SHA-2 MAC or
throws for SHA-1. The issue's confirmed working build is `4.8.4739.0`.

Upstream commit [`f099365`](https://github.com/sshnet/SSH.NET/commit/f099365c9d4cf2ade92b92c203bbb2b345d2cd74)
calls `Initialize()` after both receive-MAC finalization paths on .NET Framework.
SSH.NET's version height maps that commit to `2026.0.1-prerelease.6`; `.5`
predates the fix. The successful upstream workflow for `f099365` published `.6`
on 2026-09-01. VT7 0.10.1/package 0.3 pins that exact publisher-built package.

The `4.8.4739.0` servicing level remains diagnostic evidence for the rejected
2026.0.0 package, not a VT7 runtime requirement. Package 0.3 restores the stated
Windows 7 floor to ordinary .NET Framework 4.8 and proves that boundary by
connecting on NESSY's genuine non-ESU `4.8.4110.0` runtime. When the first stable
SSH.NET release containing `f099365` becomes available, replace the prerelease
only after repeating this two-machine acceptance run.

## Accepted package 0.3 two-machine result

The returned automated evidence uses the same package binaries and exact
Win32-OpenSSH 10.0p2 oracle on both machines:

| Property | NESSY | TURTLE |
| --- | --- | --- |
| Automated result | Passed | Passed |
| OS | Windows 7 SP1 x64 | Windows 7 SP1 x64 |
| .NET Framework runtime | `4.8.4110.0` | `4.8.4795.0` |
| Graphics adapter | VMware SVGA 3D | AMD Radeon RX 6800 XT |
| Host SHA256 | `D9B245BCD6C018AC1023FAA15567CA89068E2358D2919DE17937698D32F5F1DC` | Same |
| Native SHA256 | `96D97CF5DCC3218ACD5E2BF2D59350AA2302D87E595133734519276A0FBF1756` | Same |
| `ssh-keygen.exe` | 10.0.0.0, SHA256 `B51FDD26BE0F7C83398D18E5354A0ACB0406A9DE25516791758FE63BBE3AE870` | Same |
| Typed stored-key SSH | Owner-confirmed pass | Owner-confirmed pass |
| Direct **Start SSH...** stored-key session | Owner-confirmed pass | Owner-confirmed pass |

Both `known-hosts.log` files report `Passed: True`. They pass the parser,
four-source immutable loader, read-only policy, 1,024-input bounded byte corpus,
10.0p2 differential oracle, TerminalCore and Atlas font checks. Hardware and
WARP probes also succeed on both machines. The same host/native hashes bind the
reports to package 0.3, while the differing runtime versions prove the intended
servicing-tier comparison.

The four returned files and their verification manifest are preserved under
`artifacts/vt7/evidence/known-hosts-kh01-2-win7-0.3`. Evidence SHA256 values are:

- NESSY `known-hosts.log`:
  `D6DE3D6E22736CEC799E3285468D624052B0BBFA300A4CCD6A755BE24198E1BC`;
- NESSY `RUN-ENVIRONMENT.txt`:
  `F3FCA38A7E99DE85016EB92D281359C4CF1445BCB336260312EC3E22131B9752`;
- TURTLE `known-hosts.log`:
  `95C1494DB04095243C31561BA3BFB3560E6217942089EB20E716658F65A5353E`;
- TURTLE `RUN-ENVIRONMENT.txt`:
  `1929150B86DF56C45848AA3B7359E099AB38D0926C541250894DB7AC77061BB9`.

No credential value appears in this evidence. Package 0.3 accepts the upstream
receive-MAC correction, ordinary .NET Framework 4.8 runtime floor and KH01.2
read-only production trust across the two current Windows 7 tiers.

## Acceptance boundary and next step

Acceptance closes the dependency regression and accepts KH01.2 raw-key read-only
trust across both Windows 7 servicing tiers. It does not enable persistence,
Connect once, Trust and connect, changed-key replacement or host-certificate
trust. KH01.3 is next and owns generation-safe first-contact decisions and
byte-preserving writes. KH01.4 owns management and complete certificate policy;
KH01.5 owns the final target matrix.
