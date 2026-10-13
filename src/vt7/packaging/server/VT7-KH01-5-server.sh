#!/usr/bin/env bash
# VT7 MIT-licensed controlled host-certificate fixture. No normal sshd changes.
set -euo pipefail
umask 077
fail() { printf '%s\n' "KH01.5: $*" >&2; exit 1; }
[[ $EUID == 0 ]] || fail 'Run this fixture with sudo.'
[[ $# -ge 2 ]] || fail 'Usage: prepare ROOT IPV4 USER [BASE_PORT] | start/stop/reset ROOT | audit ROOT EXPECTED_ACCEPTED'
action=$1
root=$2
[[ $root =~ ^/var/tmp/vt7-kh01-5-[A-Za-z0-9_-]+$ ]] || fail 'ROOT must be /var/tmp/vt7-kh01-5-NAME (no trailing slash).'
[[ ! -L $root && $(realpath -m -- "$root") == "$root" ]] || fail 'Unsafe fixture path.'
sshd=/usr/sbin/sshd
cases=(valid wrong-principal expired not-yet-valid critical-option untrusted-ca revoked-key revoked-ca revoked-certificate)
if [[ $action == prepare ]]; then
    [[ $# == 4 || $# == 5 ]] || fail 'prepare requires ROOT IPV4 USER [BASE_PORT].'
    [[ ! -e $root ]] || fail 'Fixture already exists; use a fresh name.'
    host=$3; user=$4; base=${5:-22350}
    [[ $user =~ ^[A-Za-z0-9_.-]{1,64}$ ]] || fail 'Invalid dedicated test account.'
    [[ $base =~ ^[0-9]{4,5}$ && $base -ge 1024 && $base -le 65527 ]] || fail 'Invalid nine-port range.'
    python3 -c 'import ipaddress,sys; assert str(ipaddress.IPv4Address(sys.argv[1])) == sys.argv[1]' "$host"
    getent passwd "$user" >/dev/null || fail 'Dedicated test account does not exist.'
    [[ -x $sshd && -d /run/sshd ]] || fail 'OpenSSH server and /run/sshd are required.'
    command -v ssh-keygen >/dev/null; command -v stty >/dev/null
    mkdir -m 755 -- "$root"
    mkdir -- "$root/keys" "$root/configs" "$root/logs"
    id=$(python3 -c 'import uuid; print(uuid.uuid4().hex)')
    printf '%s\n' "$id" >"$root/fixture-id"
    for key in ca other-ca host; do ssh-keygen -q -t ed25519 -N '' -f "$root/keys/$key"; done
    {
        printf 'schema=vt7-kh01-5-fixture-v1\nid=%s\nprincipal=%s\nbasePort=%s\n' "$id" "$host" "$base"
        awk '{print "ca=" $1 " " $2}' "$root/keys/ca.pub"
        awk '{print "hostKey=" $1 " " $2}' "$root/keys/host.pub"
    } >"$root/client.fixture"
    for name in "${cases[@]:0:6}"; do
        cp -- "$root/keys/host.pub" "$root/keys/$name.pub"
        principal=$host; validity='-5m:+7d'; authority=ca
        extra=()
        case $name in
            wrong-principal) principal=192.0.2.123; [[ $principal != "$host" ]] || principal=192.0.2.124 ;;
            expired) validity='-2d:-1d' ;;
            not-yet-valid) validity='+1d:+2d' ;;
            critical-option) extra=(-O critical:vt7-test=deny) ;;
            untrusted-ca) authority=other-ca ;;
        esac
        ssh-keygen -q -s "$root/keys/$authority" -I "vt7-$id-$name" -h -n "$principal" -V "$validity" "${extra[@]}" "$root/keys/$name.pub"
        awk -v name="$name" '{print "cert." name "=" $1 " " $2}' "$root/keys/$name-cert.pub" >>"$root/client.fixture"
    done
    chmod 644 -- "$root/client.fixture"
    cat >"$root/session.sh" <<EOF
#!/bin/sh
printf 'VT7-KH01-5-READY %s\n' '$id'
while IFS= read -r line; do
    line=\$(printf '%s' "\$line" | tr -d '\r')
    case "\$line" in
        size) printf 'VT7-KH01-5-SIZE '; stty size ;;
        exit) exit 0 ;;
        *) printf 'VT7-KH01-5-UNKNOWN\n' ;;
    esac
done
EOF
    chmod 755 -- "$root/session.sh"
    for index in "${!cases[@]}"; do
        name=${cases[$index]}; certificate=$name
        [[ $index -lt 6 ]] || certificate=valid
        cat >"$root/configs/$name.conf" <<EOF
Port $((base + index))
ListenAddress $host
HostKey $root/keys/host
HostCertificate $root/keys/$certificate-cert.pub
HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com
PidFile $root/configs/$name.pid
LogLevel DEBUG3
UsePAM no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
AuthorizedKeysFile .ssh/authorized_keys
AllowUsers $user
PermitRootLogin no
PermitTTY yes
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PermitTunnel no
ForceCommand $root/session.sh
EOF
        "$sshd" -t -f "$root/configs/$name.conf"
    done
    printf 'Prepared fixture %s. Public client.fixture expires after seven days. Normal SSH service is unchanged.\n' "$id"
    exit 0
fi
[[ -d $root && ! -L $root/fixture-id && $(stat -c %u "$root") == 0 ]] || fail 'Not a root-owned fixture.'
[[ $(cat "$root/fixture-id") =~ ^[a-f0-9]{32}$ ]] || fail 'Invalid fixture identity.'
stop_fixture() {
    for name in "${cases[@]}"; do
        pidfile="$root/configs/$name.pid"
        [[ -f $pidfile ]] || continue
        pid=$(cat "$pidfile")
        [[ $pid =~ ^[0-9]+$ && $pid -gt 1 ]] || fail 'Invalid fixture PID.'
        if [[ -e /proc/$pid/cmdline ]]; then
            args=$(tr '\0' ' ' </proc/"$pid"/cmdline)
            [[ $args == *sshd* && $args == *"$root/configs/$name.conf"* ]] || fail 'PID belongs to another process; refusing to stop it.'
            kill -TERM "$pid"
        fi
    done
    for attempt in {1..50}; do
        active=false
        for name in "${cases[@]}"; do
            [[ -f $root/configs/$name.pid ]] || continue
            pid=$(cat "$root/configs/$name.pid")
            if [[ -e /proc/$pid/cmdline ]]; then
                args=$(tr '\0' ' ' </proc/"$pid"/cmdline)
                [[ $args != *"$root/configs/$name.conf"* ]] || active=true
            fi
        done
        $active || return 0
        sleep 0.1
    done
    fail 'Fixture listener did not stop; no files were removed.'
}
case $action in
    start)
        for name in "${cases[@]}"; do
            [[ ! -e $root/logs/$name.log ]] || fail 'Existing run logs; audit then reset before another client run.'
            "$sshd" -t -f "$root/configs/$name.conf"
        done
        trap 'stop_fixture' ERR
        for name in "${cases[@]}"; do
            "$sshd" -D -f "$root/configs/$name.conf" -E "$root/logs/$name.log" &
            printf '%s\n' "$!" >"$root/configs/$name.pid"
            ready=false
            for attempt in {1..50}; do
                if [[ -f $root/logs/$name.log ]] && grep -q 'Server listening on ' "$root/logs/$name.log"; then ready=true; break; fi
                sleep 0.1
            done
            if ! $ready; then
                stop_fixture
                fail 'A fixture port could not start; inspect its local server logs, then reset before retrying.'
            fi
        done
        printf 'Nine certificate-only listeners started. Run one client matrix, then audit.\n'
        ;;
    stop) stop_fixture; printf 'Fixture listeners stopped; all evidence preserved.\n' ;;
    reset)
        stop_fixture
        archive="$root/logs-$(date -u +%Y%m%dT%H%M%SZ)-$(python3 -c 'import uuid; print(uuid.uuid4().hex[:8])')"
        mv -- "$root/logs" "$archive"
        mkdir -- "$root/logs"
        printf 'Previous raw logs preserved. Start for the next machine.\n'
        ;;
    audit)
        [[ $# == 3 && $3 =~ ^[3-5]$ ]] || fail 'audit requires AcceptedConnections (3, 4 or 5) from the client report.'
        script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
        python3 "$script_dir/VT7-KH01-5-audit.py" "$root" "$3"
        ;;
    *) fail 'Unknown fixture action.' ;;
esac
