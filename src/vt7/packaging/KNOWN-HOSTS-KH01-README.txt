VT7 OpenSSH-compatible known-host foundation KH01.1 package 0.1
================================================================

This is a disconnected engineering diagnostic for the first implementation
slice of VT7's known-host management specification. It does not read, modify or
trust the current user's real known_hosts files and it does not make a network
connection.

REQUIREMENTS

- Windows 7 SP1 x64 with the existing VT7 prerequisites.
- PowerShell 5.1.
- The previously installed Microsoft Win32-OpenSSH 10.0p2 tools, including
  ssh-keygen.exe under C:\Program Files\OpenSSH or on PATH.

RUN

1. Extract the complete archive into a new writable directory.
2. Run RUN-KNOWN-HOSTS-KH01.cmd without elevation.
3. A successful run prints "VT7 KH01.1 known-host validation passed."
4. Return the complete Logs directory only if the test fails.

The runner records the exact ssh-keygen.exe file version and SHA256. The target
run must identify the installed 10.0p2 generation. It exercises literal,
wildcard, negated, hashed and non-default-port lookup, OpenSSH-generated host
hashes, OpenSSH removal with .old recovery, exact RFC 4253 key-blob identity,
all six VT7 trust outcomes, parser limits and 1,024 deterministic arbitrary-byte
cases.

CURRENT BOUNDARY

KH01.1 is not connected to SshNetTransport. VT7's accepted production SSH path
still requires the separately obtained SHA256 fingerprint. This package never
touches credentials, never contacts the controlled server and never changes a
real OpenSSH trust file. Certificates are deliberately policy-rejected until
their complete KH01.4 validation is implemented.
