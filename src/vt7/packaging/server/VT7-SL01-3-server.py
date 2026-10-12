#!/usr/bin/env python3
"""SL01.3 fault peer. No OS shell, password auth, forwarding or service changes.

Blocking Paramiko's protocol callbacks is intentional fault injection here,
contrary to the normal ServerInterface guidance. Never use this as an SSH server.
"""
import argparse
import base64
import datetime as dt
import ipaddress
import json
import logging
import os
from pathlib import Path
import re
import socket
import threading
import time
import uuid

import paramiko

PORTS = {"ready": 0, "auth-timeout": 1, "auth-late": 2, "auth-cancel": 3,
         "pty-timeout": 4, "pty-late": 5, "pty-cancel": 6}
CASES = {"ready-before": "ready", "auth-timeout": "auth-timeout",
         "auth-late": "auth-late", "auth-cancel": "auth-cancel",
         "auth-close": "auth-cancel", "pty-timeout": "pty-timeout",
         "pty-late": "pty-late", "pty-cancel": "pty-cancel",
         "pty-close": "pty-cancel", "typed-auth-timeout": "auth-timeout",
         "typed-pty-timeout": "pty-timeout", "ready-after": "ready"}


class AuditFailure(Exception):
    """Only fixed diagnostic check names; never raw SSH/library messages."""


def fixture(root):
    values = {}
    for line in (root / "client.fixture").read_text(encoding="ascii").splitlines():
        key, value = line.split("=", 1)
        if key in values:
            raise ValueError("Duplicate fixture field")
        values[key] = value
    if set(values) != {"schema", "id", "principal", "basePort", "userPrefix", "hostKey", "expiresUtc"}:
        raise ValueError("Invalid fixture fields")
    if values["schema"] != "vt7-sl01-3-fixture-v1" or not re.fullmatch(r"[a-f0-9]{32}", values["id"]):
        raise ValueError("Invalid fixture identity")
    ipaddress.IPv4Address(values["principal"])
    if not 1024 <= int(values["basePort"]) <= 65529:
        raise ValueError("Invalid fixture port range")
    if not re.fullmatch(r"[A-Za-z0-9_.-]{1,32}", values["userPrefix"]):
        raise ValueError("Invalid fixture user prefix")
    if dt.datetime.now(dt.timezone.utc) >= dt.datetime.fromisoformat(values["expiresUtc"]):
        raise ValueError("Fixture expired; prepare a fresh directory")
    return values


def prepare(args):
    root = Path(args.root).resolve()
    ipaddress.IPv4Address(args.address)
    if not 1024 <= args.port <= 65529 or not re.fullmatch(r"[A-Za-z0-9_.-]{1,32}", args.user):
        raise ValueError("Invalid address, port range or user prefix")
    key_text = Path(args.client_key).read_text(encoding="ascii")
    fields = key_text.split()
    if len(fields) < 2 or not fields[0].startswith("ssh-") or len(key_text) > 16384:
        raise ValueError("Supply one OpenSSH client PUBLIC key, not authorized_keys or a private key")
    base64.b64decode(fields[1], validate=True)
    root.mkdir(mode=0o700, parents=False, exist_ok=False)
    host = paramiko.RSAKey.generate(3072)
    host.write_private_key_file(str(root / "host-key"))
    os.chmod(root / "host-key", 0o600)
    (root / "client-key.pub").write_text(fields[0] + " " + fields[1] + "\n", encoding="ascii")
    identity = uuid.uuid4().hex
    expires = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=7)).isoformat()
    values = {"schema": "vt7-sl01-3-fixture-v1", "id": identity, "principal": args.address,
              "basePort": str(args.port), "userPrefix": args.user,
              "hostKey": host.get_name() + " " + host.get_base64(), "expiresUtc": expires}
    (root / "client.fixture").write_text("".join(k + "=" + v + "\n" for k, v in values.items()), encoding="ascii")
    print("Prepared " + identity + ". Transfer only client.fixture to Windows. Private host key stays here.")


class Audit:
    def __init__(self, path, values):
        self.stream = path.open("x", encoding="ascii")
        self.lock = threading.Lock()
        self.emit("fixture", fixtureId=values["id"], paramiko=paramiko.__version__)

    def emit(self, event, **values):
        with self.lock:
            self.stream.write(json.dumps({"event": event, "monotonic": time.monotonic(), **values}) + "\n")
            self.stream.flush()


class Peer(paramiko.ServerInterface):
    def __init__(self, scenario, public, values, audit, stop):
        self.scenario, self.public, self.values, self.audit, self.stop = scenario, public, values, audit, stop
        self.run, self.case = None, None
        self.shell = threading.Event()
        self.held = False

    def event(self, name):
        self.audit.emit(name, runId=self.run, case=self.case, scenario=self.scenario)

    def get_allowed_auths(self, username):
        return "publickey"

    def check_auth_publickey(self, username, key):
        match = re.fullmatch(re.escape(self.values["userPrefix"]) + r"_([a-f0-9]{32})_([a-z-]+)", username)
        if not match or CASES.get(match[2]) != self.scenario or key.asbytes() != self.public:
            self.audit.emit("authentication-rejected", scenario=self.scenario)
            return paramiko.AUTH_FAILED
        if self.run is None:
            self.run, self.case = match[1], match[2]
            self.event("request")
        elif (self.run, self.case) != (match[1], match[2]):
            return paramiko.AUTH_FAILED
        if self.scenario.startswith("auth-") and not self.held:
            self.hold("authentication")
        return paramiko.AUTH_FAILED if self.stop.is_set() else paramiko.AUTH_SUCCESSFUL

    def hold(self, phase):
        self.held = True
        self.event(phase + "-held")
        stopped = self.stop.wait(18 if self.scenario.endswith("timeout") else 6)
        self.event(phase + ("-aborted" if stopped else "-released"))

    def check_channel_request(self, kind, channel_id):
        return paramiko.OPEN_SUCCEEDED if kind == "session" else paramiko.OPEN_FAILED_ADMINISTRATIVELY_PROHIBITED

    def check_channel_pty_request(self, channel, term, width, height, pixelwidth, pixelheight, modes):
        self.event("pty-request")
        if self.scenario.startswith("pty-") and not self.held:
            self.hold("pty")
        return not self.stop.is_set()

    def check_channel_shell_request(self, channel):
        self.event("shell-request")
        self.shell.set()
        return True


def serve(args):
    root = Path(args.root).resolve()
    values = fixture(root)
    host = paramiko.RSAKey.from_private_key_file(str(root / "host-key"))
    if host.get_name() + " " + host.get_base64() != values["hostKey"]:
        raise ValueError("Host key differs from public fixture")
    public = base64.b64decode((root / "client-key.pub").read_text(encoding="ascii").split()[1], validate=True)
    log = root / ("server-" + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:8] + ".jsonl")
    audit, stop = Audit(log, values), threading.Event()
    listeners, workers, transports = [], [], []
    lock = threading.Lock()
    slots = threading.BoundedSemaphore(24)
    # Suppress third-party exceptions: this fixture emits its own fixed events.
    logging.getLogger("paramiko").addHandler(logging.NullHandler())
    logging.getLogger("paramiko").propagate = False

    def connection(sock, scenario):
        transport = paramiko.Transport(sock)
        peer = Peer(scenario, public, values, audit, stop)
        with lock:
            transports.append(transport)
        authenticated = False
        try:
            transport.add_server_key(host)
            transport.start_server(server=peer)
            deadline = time.monotonic() + 90
            channel = None
            while transport.is_active() and not stop.is_set() and time.monotonic() < deadline:
                if transport.is_authenticated() and not authenticated:
                    peer.event("authenticated")
                    authenticated = True
                if channel is None:
                    channel = transport.accept(0.1)
                if channel is not None and peer.shell.is_set():
                    channel.sendall(("VT7-SL01-3-READY " + values["id"] + "\n").encode("ascii"))
                    channel.settimeout(1)
                    while transport.is_active() and not stop.is_set() and time.monotonic() < deadline:
                        try:
                            data = channel.recv(1024)
                        except socket.timeout:
                            continue
                        if not data:
                            break
                        # No command execution. Accept only the diagnostic exit.
                        if b"exit" in data:
                            channel.send_exit_status(0)
                            channel.close()
                            peer.event("normal-exit")
                            break
                    break
                time.sleep(0.02)
        except (EOFError, OSError, paramiko.SSHException):
            if peer.run is not None:
                peer.event("peer-ended")
        finally:
            transport.close()
            transport.join(20)
            if peer.run is not None:
                peer.event("worker-unsettled" if transport.is_alive() else "closed")
            with lock:
                transports.remove(transport)
            slots.release()

    def accept(listener, scenario):
        while not stop.is_set():
            try:
                sock, _ = listener.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            if not slots.acquire(blocking=False):
                sock.close()
                continue
            worker = threading.Thread(target=connection, args=(sock, scenario), daemon=False)
            with lock:
                workers.append(worker)
            worker.start()

    try:
        # Bind every socket before starting threads; a partial range never claims readiness.
        for scenario, offset in PORTS.items():
            listener = socket.socket()
            listeners.append(listener)
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind((values["principal"], int(values["basePort"]) + offset))
            listener.listen(16)
            listener.settimeout(0.5)
        for (scenario, _), listener in zip(PORTS.items(), listeners):
            worker = threading.Thread(target=accept, args=(listener, scenario), daemon=False)
            workers.append(worker)
            worker.start()
        print("SL01.3 READY. Audit: " + str(log), flush=True)
        print("Run one Windows client matrix, wait five seconds, then Ctrl+C. Normal sshd is unchanged.", flush=True)
        while not stop.wait(0.5):
            request = root / "STOP"
            if request.is_file() and request.read_text(encoding="ascii").strip() == values["id"]:
                break
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        for listener in listeners:
            listener.close()
        with lock:
            active = list(transports)
        for transport in active:
            transport.close()
        for worker in list(workers):
            worker.join(25)
        audit.emit("fixture-unsettled" if any(worker.is_alive() for worker in workers) else "fixture-stopped")
        audit.stream.close()


def audit_run(args):
    records = [json.loads(line) for line in Path(args.server_log).read_text(encoding="ascii").splitlines()]
    client = Path(args.client_log).read_text(encoding="utf-8")
    def field(name):
        match = re.search(r"^(?:Surface: )?" + name + r"=([a-f0-9]{32})$", client, re.M)
        if not match:
            raise AuditFailure("Client identity field missing")
        return match[1]
    run_id, fixture_id = field("RunId"), field("FixtureId")
    if (not records or records[0].get("fixtureId") != fixture_id or
            not re.search(r"^Passed: True$", client, re.M) or not re.search(r"^Cases=12$", client, re.M)):
        raise AuditFailure("Client/server identity or client result mismatch")
    for case in CASES:
        if "PASS: SL01.3 " + case + " " not in client:
            raise AuditFailure("Client case assertion missing")
    rows = [r for r in records if r.get("runId") == run_id]
    if any(r["event"] in {"worker-unsettled", "fixture-unsettled"} for r in records):
        raise AuditFailure("Server worker termination was not joined")
    if {r.get("case") for r in rows} != set(CASES):
        raise AuditFailure("Incomplete server case set")
    for case, scenario in CASES.items():
        events = [r["event"] for r in rows if r.get("case") == case]
        if any(r.get("scenario") != scenario for r in rows if r.get("case") == case):
            raise AuditFailure("Server scenario mismatch")
        if events.count("request") != 1 or events.count("closed") != 1:
            raise AuditFailure("Missing/duplicate connection or pending peer; wait five seconds before stopping")
        phase = "authentication" if scenario.startswith("auth-") else "pty"
        if scenario != "ready":
            if events.count(phase + "-held") != 1 or events.count(phase + "-released") != 1:
                raise AuditFailure("Held phase was not naturally released")
            held = next(r["monotonic"] for r in rows if r.get("case") == case and r["event"] == phase + "-held")
            released = next(r["monotonic"] for r in rows if r.get("case") == case and r["event"] == phase + "-released")
            if released - held < (17.5 if scenario.endswith("timeout") else 5.5):
                raise AuditFailure("Server stall was too short")
        if scenario.startswith("pty-") and ("authenticated" not in events or "pty-request" not in events):
            raise AuditFailure("PTY fault did not follow authenticated channel startup")
        if scenario.startswith("auth-") and "pty-request" in events:
            raise AuditFailure("Rejected authentication result reached PTY")
        if scenario == "ready" and "normal-exit" not in events:
            raise AuditFailure("Healthy fixture did not complete")
        print("PASS: server " + case)
    print("PASS: SL01.3 paired server audit; FixtureId=" + fixture_id + " RunId=" + run_id)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("prepare")
    create.add_argument("root")
    create.add_argument("address")
    create.add_argument("client_key", help="Dedicated OpenSSH PUBLIC key path")
    create.add_argument("--user", default="sshtest")
    create.add_argument("--port", type=int, default=22400)
    start = sub.add_parser("serve")
    start.add_argument("root")
    check = sub.add_parser("audit")
    check.add_argument("server_log")
    check.add_argument("client_log")
    args = parser.parse_args()
    {"prepare": prepare, "serve": serve, "audit": audit_run}[args.command](args)


if __name__ == "__main__":
    try:
        main()
    except AuditFailure as error:
        raise SystemExit("SL01.3 audit failed: " + str(error))
    except (OSError, ValueError, KeyError, paramiko.SSHException) as error:
        # Fixed type only: never echo arbitrary network text, key material or paths.
        raise SystemExit("SL01.3 fixture failed (" + type(error).__name__ + "). Check inputs and retained audit.")
