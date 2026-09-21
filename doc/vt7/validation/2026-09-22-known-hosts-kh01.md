# OpenSSH-compatible known-host foundation KH01.1

Date: 2026-09-22. Status: implemented and accepted on Windows 7 against the
required Win32-OpenSSH 10.0p2 oracle.

## Scope

KH01.1 implements the disconnected foundation defined by the
[known-host management specification](../architecture/2026-09-21-openssh-known-hosts-management-spec.md).
It deliberately does not change `SshNetTransport`, the connection dialog, typed
SSH behavior or the accepted mandatory-fingerprint policy.

The slice adds:

- bounded byte-oriented known-host line parsing with raw-line preservation;
- ordinary, `@revoked` and `@cert-authority` marker recognition;
- literal, wildcard, negated and `|1|` HMAC-SHA1 host matching;
- default and non-default port host-token construction;
- RFC 4253 public-key type extraction, exact key-blob identity and canonical
  SHA256 fingerprints;
- immutable matching, unknown, changed, revoked, unreadable and
  policy-rejected results;
- fail-closed handling for malformed relevant or indeterminate records;
- explicit certificate policy rejection until KH01.4;
- deterministic hash properties and 1,024 arbitrary-byte bounded parser cases;
  and
- a runtime-disconnected differential oracle using `ssh-keygen -F`, `-H` and
  `-R` in a disposable path containing spaces.

No project source was copied or translated from OpenSSH. The implementation is
new VT7 MIT-licensed C# based on the published file behavior and differential
tests. `ssh-keygen.exe` is a diagnostic oracle only and is not called by normal
VT7 startup or a production SSH connection.

## Source boundary

| File | Responsibility |
| --- | --- |
| `src/vt7/VT7.Host/OpenSshKnownHosts.cs` | Parser, models, host tokens, matching, key identity and raw-key trust precedence. |
| `src/vt7/VT7.Host/KnownHostsFoundationChecks.cs` | Deterministic fixtures, trust-state tests, fuzz/property cases and external oracle. |
| `src/vt7/VT7.Host/App.xaml.cs` | Mutually exclusive `--known-hosts-test` diagnostic mode only. |
| `tools/Test-VT7KnownHosts.ps1` | Fresh-report runner, exact oracle identity capture and optional required-version gate. |
| `tools/Package-VT7KnownHosts.ps1` | Refuse-overwrite package construction, dependency/license staging and packaged path-with-spaces run. |
| `tools/Verify-VT7KnownHostsPackage.ps1` | Independent ZIP safety/hash/manifest/binary and extracted-launcher verification. |
| `src/vt7/packaging/RUN-KNOWN-HOSTS-KH01.cmd` | PowerShell 5.1 target launcher pinned to `ssh-keygen.exe` file version 10.0.0.0. |

The models defensively copy public-key and raw-line byte arrays. The parser
limits are 16 MiB per file, 64 KiB per physical line, 16,384 records, 256 host
patterns, 8 KiB per host field and 64 KiB per decoded key blob.

Non-ASCII host tokens are policy-rejected in this slice because the
specification intentionally performs no implicit IDNA conversion. A later
explicit hostname policy can add IDNA behavior without changing stored trust
silently.

## Local results

Both Debug and Release builds complete with the locked SSH.NET closure. Both
focused KH01.1 runs pass. The existing Release SSH.NET foundation also passes,
showing that the new mutually exclusive diagnostic mode did not disturb the
accepted transport foundation.

The development oracle is the installed Windows OpenSSH
`ssh-keygen.exe` file version `9.5.5.2`, SHA256
`2A0D971F935813E324519BCE64E7EB5AF85A5F91517C916270A4368E0786F588`.
This is useful local differential evidence, but it does not replace the exact
10.0p2 Windows 7 result recorded below.

The focused report contains these verdicts:

```text
PASS: OpenSSH host tokens preserve default-port identity and bracket every non-default port.
PASS: presented host keys use the exact RFC 4253 blob type, RSA key identity and canonical SHA256 fingerprint.
PASS: bounded known-host parsing accepts comments, markers, patterns, hashes and byte-preserved lines.
PASS: literal, wildcard, negated and OpenSSH |1| hashed host matching passed.
PASS: raw-key trust resolves matching, unknown, changed, revoked, unreadable and certificate-policy states.
PASS: deterministic hash properties and 1024 bounded arbitrary-byte parser cases passed.
PASS: ssh-keygen differential lookup, host hashing and removal passed.
```

The package builder additionally passes generic PE/import/dependency validation,
a CMD batch launch from a path containing spaces, and exact ZIP-entry hashing.
The independent verifier extracts a fresh copy and repeats the binary and
KH01.1 test successfully. A focused negative control supplies a false expected
oracle version and is rejected before VT7 starts.

## Candidate package

| Property | Value |
| --- | --- |
| Archive | `VT7-KnownHosts-KH01-0.1-x64.zip` |
| Review copy | `artifacts/VT7-KnownHosts-KH01-0.1-x64.zip` |
| SHA256 | `D367B5F7C81304F6FBC9056FD10E501B95EF93FFB5A662E370FCC4ECE16C76A7` |
| Bytes | 14,483,182 |
| Files | 81 verified files |
| Application | VT7 0.9.2, native ABI 11, x64, .NET Framework 4.8 |
| Network | None |
| Credentials | None requested or retained |
| Real trust files | Not read or modified |
| Production integration | Disabled |

The manifest records a dirty source tree because the candidate was built before
these changes were committed. `SHA256SUMS.txt` covers every other archive file.
The package includes the existing audited dependency and license closure. It
does not ship OpenSSH; the target uses its separately installed executable.

## Windows 7 procedure

The target already has Microsoft Win32-OpenSSH 10.0p2 under
`C:\Program Files\OpenSSH`. Copy the review archive to the Windows 7 machine,
extract it into a new writable directory and run:

```text
RUN-KNOWN-HOSTS-KH01.cmd
```

Run without elevation. The launcher requires `ssh-keygen.exe` file version
`10.0.0.0`; a different executable fails before the VT7 diagnostic. It then
uses disposable fixtures only. It makes no network connection, asks for no
credential and does not inspect or modify `%USERPROFILE%\.ssh\known_hosts`.

Success prints the passing verdict and the oracle file version/SHA256. Return
the complete `Logs` directory only if the test fails. Do not perform direct SSH,
server-key rotation or real trust-file tests for KH01.1.

## Supplied Windows 7 result

The owner reports that all package tests passed on the Windows 7 target on
2026-09-22. The launcher permits the diagnostic to start only after resolving
`ssh-keygen.exe` and verifying file version `10.0.0.0`, so the pass satisfies the
specified Microsoft Win32-OpenSSH 10.0p2 oracle boundary.

No target `Logs` directory is archived. This is expected: the supplied procedure
requested the complete directory only if the test failed. The accepted evidence
is therefore the owner's clean-result report together with the package's enforced
version gate; this record does not claim a preserved target manifest, transcript
or target executable hash.

## Acceptance boundary and next step

The clean target result accepts only KH01.1's parser, matcher, raw-key resolver
and 10.0p2 differential behavior on the supplied Windows 7 configuration. It does
not complete recoverable known-host management and does not justify removing
the current fingerprint requirement.

KH01.2 may now load the four default user/system sources
before connecting and apply matching, changed, revoked and unreadable results in
the production callback while keeping mandatory fingerprint verification for
unknown hosts. KH01.3 writes first-contact decisions; KH01.4 adds deliberate
management and complete certificate trust; KH01.5 owns the final target matrix.
