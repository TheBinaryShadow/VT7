"""Exercise server-audit acceptance, false positives and disclosure boundaries."""
import pathlib
import subprocess
import sys
import tempfile

audit = pathlib.Path(__file__).resolve().parents[1] / 'src/vt7/packaging/server/VT7-KH01-5-audit.py'
cases = ('valid', 'wrong-principal', 'expired', 'not-yet-valid',
         'critical-option', 'untrusted-ca', 'revoked-key', 'revoked-ca',
         'revoked-certificate')
with tempfile.TemporaryDirectory(prefix='vt7-kh01-5-audit-') as directory:
    root = pathlib.Path(directory)
    (root / 'fixture-id').write_text('a' * 32)
    (root / 'logs').mkdir()
    connection = 'Connection from 192.0.2.77 port 12345 on 192.0.2.1 port 22350 rdomain ""\n'
    authenticated = connection + 'debug1: userauth-request for user PRIVATE_USER service ssh-connection method none [preauth]\n' + 'Accepted publickey for PRIVATE_USER from 192.0.2.77 port 12345 ssh2: ED25519 SHA256:PRIVATE_KEY\n'
    for name in cases:
        (root / 'logs' / (name + '.log')).write_text(authenticated * 3 if name == 'valid' else connection)

    def run(expected):
        result = subprocess.run([sys.executable, str(audit), str(root), str(expected)], capture_output=True)
        summary = (root / 'server-audit.txt').read_text()
        for private in ('PRIVATE_USER', 'PRIVATE_KEY', '192.0.2.77', '192.0.2.1'):
            assert private not in summary, 'Server audit leaked raw log material'
        return result.returncode

    assert run(3) == 0, 'Valid fixture counts were rejected'
    assert run(4) == 1, 'Missing valid authentication was accepted'
    rejected = root / 'logs' / 'expired.log'
    rejected.write_text(connection + 'debug1: userauth-request for user PRIVATE_USER service ssh-connection method none [preauth]\n')
    assert run(3) == 1, 'Rejected certificate reached authentication unnoticed'
    rejected.write_text('')
    assert run(3) == 1, 'A failure to reach the certificate server counted as rejection'
    rejected.write_text(connection * 2)
    assert run(3) == 1, 'Contaminated server logs were accepted'
print('PASS: server audit rejects authentication exposure, missing connections and contaminated evidence; raw endpoints/users/keys are excluded.')
