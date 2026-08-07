#!/usr/bin/env python3
"""Ordered homelab shutdown when the UPS goes on battery.

Managed by Ansible (role: ups-cascade). The state machine, the thresholds and
the reasoning behind both live in that role's README.md - extend the README
rather than commenting this file.
"""

from __future__ import annotations

import argparse
import errno
import json
import os
import socket
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

APID_PORT = 50000
SSH_PORT = 22
EVENT_PREFIX = "@@UPS_EVENT"

IDLE = "idle"
RIDE_THROUGH = "ride_through"
TALOS = "talos"
NODES_DOWN = "nodes_down"
NAS = "nas"
HANDOFF = "handoff"


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def env_str(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def env_int(name: str, default: int) -> int:
    raw = env_str(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def env_bool(name: str, default: bool = False) -> bool:
    raw = env_str(name).lower()
    if not raw:
        return default
    return raw in ("1", "true", "yes", "on")


class Config:
    def __init__(self) -> None:
        self.ups = env_str("UPS_CASCADE_UPS", "server-room-rack")
        self.poll_interval = env_int("UPS_CASCADE_POLL_INTERVAL", 5)
        self.ride_through = env_int("UPS_CASCADE_RIDE_THROUGH", 60)
        self.ol_stable = env_int("UPS_CASCADE_OL_STABLE", 30)
        self.talos_deadline = env_int("UPS_CASCADE_TALOS_DEADLINE", 420)
        self.nodes_down_deadline = env_int("UPS_CASCADE_NODES_DOWN_DEADLINE", 120)
        self.nas_deadline = env_int("UPS_CASCADE_NAS_DEADLINE", 300)
        self.abort_cooldown = env_int("UPS_CASCADE_ABORT_COOLDOWN", 900)
        self.recover_deadline = env_int("UPS_CASCADE_RECOVER_DEADLINE", 1200)
        self.dry_run = env_bool("UPS_CASCADE_DRY_RUN", False)

        self.talos_script = env_str("UPS_CASCADE_TALOS_SCRIPT", "/usr/local/lib/ups-cascade/talos-shutdown.sh")
        self.kubeconfig = env_str("UPS_CASCADE_KUBECONFIG", "/var/lib/ups-cascade/kubeconfig")
        self.talosconfig = env_str("UPS_CASCADE_TALOSCONFIG", "/var/lib/ups-cascade/talosconfig")
        self.ceph_namespace = env_str("UPS_CASCADE_CEPH_NAMESPACE", "rook-ceph")

        self.nas_host = env_str("UPS_CASCADE_NAS_HOST", "nas.internal")
        self.nas_user = env_str("UPS_CASCADE_NAS_USER", "truenas_admin")
        self.nas_key = env_str("UPS_CASCADE_NAS_SSH_KEY", "/var/lib/ups-cascade/.ssh/id_ed25519")
        self.nas_known_hosts = env_str("UPS_CASCADE_NAS_KNOWN_HOSTS", "/var/lib/ups-cascade/.ssh/known_hosts")
        self.nas_shutdown_cmd = env_str("UPS_CASCADE_NAS_SHUTDOWN_CMD", "sudo midclt call system.shutdown")

        self.state_dir = Path(env_str("UPS_CASCADE_DIR", "/var/lib/ups-cascade"))
        self.events_path = self.state_dir / "events.jsonl"
        self.state_path = self.state_dir / "state.json"

        self.nodes = self._parse_nodes(env_str("UPS_CASCADE_NODES"))

    @staticmethod
    def _parse_nodes(raw: str) -> list[tuple[str, str]]:
        nodes = []
        for item in raw.split(","):
            item = item.strip()
            if not item or "=" not in item:
                continue
            name, addr = item.split("=", 1)
            nodes.append((name.strip(), addr.strip()))
        return nodes

    def kube_env(self) -> dict:
        env = dict(os.environ)
        env["KUBECONFIG"] = self.kubeconfig
        env["TALOSCONFIG"] = self.talosconfig
        return env


class Ups:
    def __init__(self, name: str) -> None:
        self.name = name

    def read(self) -> dict | None:
        try:
            proc = subprocess.run(
                ["upsc", self.name],
                capture_output=True,
                text=True,
                timeout=10,
            )
        except (OSError, subprocess.TimeoutExpired):
            return None
        if proc.returncode != 0:
            return None
        data = {}
        for line in proc.stdout.splitlines():
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            data[key.strip()] = value.strip()
        return data


def telemetry(raw: dict | None) -> dict:
    if not raw:
        return {"status": None, "charge": None, "runtime": None, "load": None}

    def num(key):
        try:
            return float(raw[key])
        except (KeyError, TypeError, ValueError):
            return None

    charge = num("battery.charge")
    runtime = num("battery.runtime")
    load = num("ups.load")
    return {
        "status": raw.get("ups.status"),
        "charge": int(charge) if charge is not None else None,
        "runtime": int(runtime) if runtime is not None else None,
        "load": int(load) if load is not None else None,
    }


class EventLog:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def _append(self, record: dict) -> None:
        line = json.dumps(record, separators=(",", ":"), sort_keys=False)
        with open(self.path, "a", encoding="utf-8") as handle:
            handle.write(line + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        print(line, file=sys.stderr, flush=True)

    def event(self, name: str, snap: dict | None = None, phase: str | None = None, **fields) -> None:
        record = {"ts": iso_now(), "type": "event", "event": name}
        if phase:
            record["phase"] = phase
        record.update(fields)
        record.update(telemetry(snap))
        self._append(record)

    def sample(self, snap: dict | None, phase: str) -> None:
        record = {"ts": iso_now(), "type": "sample", "phase": phase}
        record.update(telemetry(snap))
        self._append(record)


class State:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.data = {"cascade_committed": False, "last_abort": 0.0}
        if path.exists():
            try:
                self.data.update(json.loads(path.read_text(encoding="utf-8")))
            except (OSError, ValueError):
                pass

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.data), encoding="utf-8")
        os.replace(tmp, self.path)

    @property
    def committed(self) -> bool:
        return bool(self.data.get("cascade_committed"))

    @committed.setter
    def committed(self, value: bool) -> None:
        self.data["cascade_committed"] = bool(value)
        self.save()

    @property
    def last_abort(self) -> float:
        return float(self.data.get("last_abort") or 0.0)

    @last_abort.setter
    def last_abort(self, value: float) -> None:
        self.data["last_abort"] = float(value)
        self.save()


def tcp_open(host: str, port: int, timeout: float = 2.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def run(argv: list[str], env: dict | None = None, timeout: int = 60) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
        )
    except subprocess.TimeoutExpired:
        return 124, "timeout"
    except OSError as exc:
        return 127, str(exc)
    return proc.returncode, (proc.stdout + proc.stderr).strip()


class Cascade:
    def __init__(self, cfg: Config, log: EventLog, state: State) -> None:
        self.cfg = cfg
        self.log = log
        self.state = state
        self.ups = Ups(cfg.ups)

        self.phase = IDLE
        self.phase_started = time.monotonic()
        self.ol_since: float | None = None
        self.allow_abort = True
        self.committed = False

        self.proc: subprocess.Popen | None = None
        self.proc_buffer = b""
        self.nas_fired = False
        self.handoff_logged = False
        self.ups_unreachable_logged = False

    def set_phase(self, phase: str) -> None:
        self.phase = phase
        self.phase_started = time.monotonic()

    def elapsed(self) -> float:
        return time.monotonic() - self.phase_started

    def run_forever(self) -> None:
        self.log.event(
            "daemon_start",
            self.ups.read(),
            phase=self.phase,
            dry_run=self.cfg.dry_run,
        )
        while True:
            self.drain_script_output()
            snap = self.ups.read()
            if snap is None:
                if not self.ups_unreachable_logged:
                    self.log.event("ups_unreachable", None, phase=self.phase)
                    self.ups_unreachable_logged = True
                time.sleep(self.cfg.poll_interval)
                continue
            if self.ups_unreachable_logged:
                self.log.event("ups_reachable", snap, phase=self.phase)
                self.ups_unreachable_logged = False

            if self.phase != IDLE:
                self.log.sample(snap, self.phase)
            self.tick(snap)
            time.sleep(self.cfg.poll_interval)

    @staticmethod
    def on_battery(snap: dict) -> bool:
        return "OB" in (snap.get("ups.status") or "").split()

    def tick(self, snap: dict) -> None:
        ob = self.on_battery(snap)
        if ob:
            self.ol_since = None
        elif self.ol_since is None:
            self.ol_since = time.monotonic()

        handler = {
            IDLE: self.tick_idle,
            RIDE_THROUGH: self.tick_ride_through,
            TALOS: self.tick_talos,
            NODES_DOWN: self.tick_nodes_down,
            NAS: self.tick_nas,
            HANDOFF: self.tick_handoff,
        }[self.phase]
        handler(snap, ob)

    def tick_idle(self, snap: dict, ob: bool) -> None:
        if not ob:
            return
        in_cooldown = (time.time() - self.state.last_abort) < self.cfg.abort_cooldown
        self.allow_abort = not in_cooldown
        self.log.event("mains_lost", snap, phase=RIDE_THROUGH, cooldown=in_cooldown)
        self.set_phase(RIDE_THROUGH)
        if in_cooldown:
            self.log.event("ride_through_skipped", snap, phase=RIDE_THROUGH)
            self.start_talos(snap)

    def tick_ride_through(self, snap: dict, ob: bool) -> None:
        if not ob:
            self.log.event(
                "mains_restored",
                snap,
                phase=IDLE,
                outage_seconds=round(self.elapsed()),
            )
            self.set_phase(IDLE)
            return
        if self.elapsed() >= self.cfg.ride_through:
            self.log.event("ride_through_expired", snap, phase=TALOS)
            self.start_talos(snap)

    def start_talos(self, snap: dict) -> None:
        self.set_phase(TALOS)
        argv = [self.cfg.talos_script, "--ups"]
        if self.cfg.dry_run:
            argv.append("--dry-run")
        env = self.cfg.kube_env()
        env["UPS_DEADLINE"] = str(self.cfg.talos_deadline)
        env["UPS_NODES"] = ",".join(f"{name}={addr}" for name, addr in self.cfg.nodes)
        self.log.event("talos_begin", snap, phase=TALOS, dry_run=self.cfg.dry_run)
        try:
            self.proc = subprocess.Popen(
                argv,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env=env,
                start_new_session=True,
            )
            os.set_blocking(self.proc.stdout.fileno(), False)
        except OSError as exc:
            self.proc = None
            self.log.event("talos_spawn_failed", snap, phase=TALOS, error=str(exc))
            self.commit(snap)
            self.force_shutdown_nodes(snap)
            self.set_phase(NODES_DOWN)

    def drain_script_output(self) -> None:
        if not self.proc or not self.proc.stdout:
            return
        try:
            chunk = os.read(self.proc.stdout.fileno(), 65536)
        except BlockingIOError:
            return
        except OSError as exc:
            if exc.errno != errno.EAGAIN:
                self.proc_buffer = b""
            return
        if not chunk:
            return
        self.proc_buffer += chunk
        while b"\n" in self.proc_buffer:
            line, self.proc_buffer = self.proc_buffer.split(b"\n", 1)
            self.handle_script_line(line.decode("utf-8", "replace").strip())

    def handle_script_line(self, line: str) -> None:
        if not line.startswith(EVENT_PREFIX):
            if line:
                print(line, file=sys.stderr, flush=True)
            return
        parts = line[len(EVENT_PREFIX):].split()
        if not parts:
            return
        name, fields = parts[0], {}
        for token in parts[1:]:
            if "=" in token:
                key, value = token.split("=", 1)
                fields[key] = value
        snap = self.ups.read()
        self.log.event(name, snap, phase=self.phase, **fields)
        if name == "talos_point_of_no_return":
            self.commit(snap)

    def commit(self, snap: dict | None) -> None:
        if self.committed:
            return
        self.committed = True
        self.allow_abort = False
        if not self.cfg.dry_run:
            self.state.committed = True
        self.log.event("point_of_no_return", snap, phase=self.phase, dry_run=self.cfg.dry_run)

    def tick_talos(self, snap: dict, ob: bool) -> None:
        if self.should_abort(ob):
            self.abort(snap)
            return

        if self.proc and self.proc.poll() is None:
            if self.elapsed() > self.cfg.talos_deadline + 60:
                self.log.event("talos_daemon_deadline", snap, phase=TALOS)
                self.kill_script()
                self.commit(snap)
                self.force_shutdown_nodes(snap)
                self.set_phase(NODES_DOWN)
            return

        rc = self.proc.returncode if self.proc else 127
        self.drain_script_output()
        self.proc = None
        self.log.event("talos_script_exit", snap, phase=TALOS, rc=rc)
        if not self.committed:
            self.commit(snap)
            self.force_shutdown_nodes(snap)
        self.set_phase(NODES_DOWN)

    def should_abort(self, ob: bool) -> bool:
        if ob or not self.allow_abort or self.committed:
            return False
        if self.ol_since is None:
            return False
        return (time.monotonic() - self.ol_since) >= self.cfg.ol_stable

    def kill_script(self) -> None:
        if not self.proc:
            return
        try:
            os.killpg(os.getpgid(self.proc.pid), 15)
            self.proc.wait(timeout=30)
        except (OSError, subprocess.TimeoutExpired):
            try:
                os.killpg(os.getpgid(self.proc.pid), 9)
            except OSError:
                pass
        self.proc = None

    def abort(self, snap: dict) -> None:
        self.log.event("cascade_aborted", snap, phase=TALOS)
        self.kill_script()
        self.uncordon(snap)
        self.state.last_abort = time.time()
        self.set_phase(IDLE)

    def uncordon(self, snap: dict | None) -> bool:
        ok = True
        for name, _ in self.cfg.nodes:
            if self.cfg.dry_run:
                self.log.event("uncordon_skipped", snap, phase=self.phase, node=name, reason="dry_run")
                continue
            rc, out = run(["kubectl", "uncordon", name], env=self.cfg.kube_env(), timeout=60)
            if rc != 0:
                ok = False
            self.log.event("uncordon", snap, phase=self.phase, node=name, rc=rc, output=out[:200])
        self.log.event("uncordon_done", snap, phase=self.phase, ok=ok)
        return ok

    def force_shutdown_nodes(self, snap: dict | None) -> None:
        for name, addr in self.cfg.nodes:
            if self.cfg.dry_run:
                self.log.event("force_shutdown_skipped", snap, phase=self.phase, node=name, reason="dry_run")
                continue
            rc, out = run(
                ["talosctl", "-n", addr, "shutdown", "--force", "--wait=false"],
                env=self.cfg.kube_env(),
                timeout=60,
            )
            self.log.event("force_shutdown", snap, phase=self.phase, node=name, rc=rc, output=out[:200])

    def tick_nodes_down(self, snap: dict, ob: bool) -> None:
        if self.cfg.dry_run:
            self.log.event("talos_nodes_down", snap, phase=NAS, reason="dry_run")
            self.set_phase(NAS)
            return
        pending = [name for name, addr in self.cfg.nodes if tcp_open(addr, APID_PORT)]
        if not pending:
            self.log.event("talos_nodes_down", snap, phase=NAS)
            self.set_phase(NAS)
            return
        if self.elapsed() >= self.cfg.nodes_down_deadline:
            self.log.event("talos_nodes_down_timeout", snap, phase=NAS, pending=",".join(pending))
            self.set_phase(NAS)

    def tick_nas(self, snap: dict, ob: bool) -> None:
        if not self.nas_fired:
            self.nas_fired = True
            self.log.event("nas_begin", snap, phase=NAS, host=self.cfg.nas_host)
            if self.cfg.dry_run:
                self.log.event("nas_shutdown_skipped", snap, phase=NAS, reason="dry_run")
                self.log.event("nas_down", snap, phase=HANDOFF, reason="dry_run")
                self.set_phase(HANDOFF)
                return
            rc, out = run(self.nas_ssh_argv(), timeout=60)
            self.log.event("nas_shutdown_issued", snap, phase=NAS, rc=rc, output=out[:200])
            return

        if not tcp_open(self.cfg.nas_host, SSH_PORT):
            self.log.event("nas_down", snap, phase=HANDOFF)
            self.set_phase(HANDOFF)
            return
        if self.elapsed() >= self.cfg.nas_deadline:
            self.log.event("nas_timeout", snap, phase=HANDOFF)
            self.set_phase(HANDOFF)

    def nas_ssh_argv(self) -> list[str]:
        return [
            "ssh",
            "-i", self.cfg.nas_key,
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", f"UserKnownHostsFile={self.cfg.nas_known_hosts}",
            "-o", "ConnectTimeout=10",
            f"{self.cfg.nas_user}@{self.cfg.nas_host}",
            self.cfg.nas_shutdown_cmd,
        ]

    def tick_handoff(self, snap: dict, ob: bool) -> None:
        if not self.handoff_logged:
            self.handoff_logged = True
            self.log.event("handoff", snap, phase=HANDOFF)


def ceph_pgs_active(cfg: Config) -> tuple[bool, str]:
    rc, out = run(
        [
            "kubectl", "-n", cfg.ceph_namespace, "exec", "deploy/rook-ceph-tools",
            "--", "ceph", "status", "-f", "json",
        ],
        env=cfg.kube_env(),
        timeout=60,
    )
    if rc != 0:
        return False, f"toolbox unreachable (rc={rc})"
    try:
        status = json.loads(out[out.index("{"):out.rindex("}") + 1])
    except (ValueError, KeyError):
        return False, "unparseable ceph status"
    states = status.get("pgmap", {}).get("pgs_by_state", [])
    if not states:
        return False, "no pg state reported"
    inactive = [s.get("state_name", "?") for s in states if "active" not in s.get("state_name", "")]
    if inactive:
        return False, "inactive pgs: " + ",".join(inactive)
    return True, "all pgs active"


def nodes_ready(cfg: Config) -> tuple[bool, str]:
    rc, out = run(["kubectl", "get", "nodes", "-o", "json"], env=cfg.kube_env(), timeout=60)
    if rc != 0:
        return False, f"api unreachable (rc={rc})"
    try:
        payload = json.loads(out[out.index("{"):out.rindex("}") + 1])
    except (ValueError, KeyError):
        return False, "unparseable node list"
    ready = set()
    for item in payload.get("items", []):
        name = item.get("metadata", {}).get("name")
        for cond in item.get("status", {}).get("conditions", []):
            if cond.get("type") == "Ready" and cond.get("status") == "True":
                ready.add(name)
    missing = [name for name, _ in cfg.nodes if name not in ready]
    if missing:
        return False, "not ready: " + ",".join(missing)
    return True, "all nodes ready"


def cmd_recover(cfg: Config, log: EventLog, state: State) -> int:
    ups = Ups(cfg.ups)
    snap = ups.read()
    log.event("boot", snap, phase=IDLE, committed=state.committed)
    if not state.committed:
        log.event("recover_skipped", snap, phase=IDLE, reason="no committed cascade")
        return 0

    log.event("recover_begin", snap, phase=IDLE)
    cascade = Cascade(cfg, log, state)
    deadline = time.monotonic() + cfg.recover_deadline

    last = ""
    while time.monotonic() < deadline:
        ok, detail = nodes_ready(cfg)
        if ok:
            log.event("recover_nodes_ready", ups.read(), phase=IDLE)
            break
        if detail != last:
            log.event("recover_waiting", ups.read(), phase=IDLE, stage="nodes", detail=detail)
            last = detail
        time.sleep(15)
    else:
        log.event("recover_timeout", ups.read(), phase=IDLE, stage="nodes")
        return 1

    last = ""
    while time.monotonic() < deadline:
        ok, detail = ceph_pgs_active(cfg)
        if ok:
            log.event("recover_ceph_active", ups.read(), phase=IDLE)
            break
        if detail != last:
            log.event("recover_waiting", ups.read(), phase=IDLE, stage="ceph", detail=detail)
            last = detail
        time.sleep(15)
    else:
        log.event("recover_timeout", ups.read(), phase=IDLE, stage="ceph")
        return 1

    if cascade.uncordon(ups.read()):
        state.committed = False
        log.event("recover_done", ups.read(), phase=IDLE)
        return 0

    log.event("recover_failed", ups.read(), phase=IDLE, reason="uncordon failed")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="mode", required=True)
    sub.add_parser("monitor")
    sub.add_parser("recover")
    note = sub.add_parser("note")
    note.add_argument("event")
    args = parser.parse_args()

    cfg = Config()
    cfg.state_dir.mkdir(parents=True, exist_ok=True)
    log = EventLog(cfg.events_path)
    state = State(cfg.state_path)

    if args.mode == "note":
        log.event(args.event, Ups(cfg.ups).read())
        return 0
    if args.mode == "recover":
        return cmd_recover(cfg, log, state)

    try:
        Cascade(cfg, log, state).run_forever()
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
