#!/usr/bin/env python3
"""MIT licensed VT7 fixture audit. Only aggregate counts leave the server."""
import pathlib
import re
import sys


def main():
    root = pathlib.Path(sys.argv[1])
    expected = int(sys.argv[2])
    identity = (root / 'fixture-id').read_text(encoding='ascii').strip()
    if not re.fullmatch('[a-f0-9]{32}', identity) or expected not in (3, 4, 5):
        raise ValueError('Invalid audit inputs')
    cases = ('valid', 'wrong-principal', 'expired', 'not-yet-valid',
             'critical-option', 'untrusted-ca', 'revoked-key', 'revoked-ca',
             'revoked-certificate')
    lines = ['Schema=vt7-kh01-5-server-audit-v1', 'FixtureId=' + identity,
             'ExpectedAcceptedConnections=' + str(expected)]
    passed = True
    for name in cases:
        path = root / 'logs' / (name + '.log')
        text = path.read_text(encoding='utf-8', errors='replace') if path.exists() else ''
        connections = len(re.findall(r'(?m)^Connection from ', text))
        auth_requests = len(re.findall(r'userauth-request for user ', text))
        accepted = len(re.findall(r'(?m)^Accepted publickey for ', text))
        # Every bad-certificate case must reach key exchange, then stop before
        # even the initial SSH user-auth request, rather than just fail to dial.
        if name == 'valid':
            ok = connections == expected and accepted == expected and auth_requests >= expected
        else:
            ok = connections == 1 and auth_requests == 0 and accepted == 0
        passed = passed and ok
        lines.append('Case={} Connections={} AuthRequests={} Accepted={} Passed={}'.format(
            name, connections, auth_requests, accepted, str(ok)))
    lines.append('Passed=' + str(passed))
    result = root / 'server-audit.txt'
    result.write_text('\n'.join(lines) + '\n', encoding='ascii')
    print('\n'.join(lines))
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
