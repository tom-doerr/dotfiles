#!/usr/bin/env python3
"""Recover powered-down Spark nodes through two explicitly allowlisted PDU outlets."""

from __future__ import annotations

import argparse
import importlib.util
import json
import logging
import math
import os
import re
import subprocess
import sys
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from types import ModuleType


LOGGER = logging.getLogger("spark-pdu-watchdog")


def load_pdu_module() -> ModuleType:
    path = Path(__file__).with_name("pdu-exporter.py")
    spec = importlib.util.spec_from_file_location("spark_watchdog_pdu", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load PDU support module: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


PDU = load_pdu_module()


class SafetyError(RuntimeError):
    """A required watchdog safety invariant was not satisfied."""


class CycleCancelled(SafetyError):
    """A cycle candidate recovered or changed state during final validation."""


@dataclass(frozen=True)
class Target:
    host: str
    outlet: int
    pdu_name: str


# This is deliberately not configurable. Outlet control is limited in code to
# these two literal host/outlet/name triples.
TARGETS = (
    Target(host="spark-2", outlet=2, pdu_name="Outlet2"),
    Target(host="spark-3", outlet=3, pdu_name="Outlet3"),
)
TARGET_BY_HOST = {target.host: target for target in TARGETS}
ALLOWED_OUTLETS = frozenset({2, 3})
CYCLE_HISTORY_LIMIT = 1024


@dataclass(frozen=True)
class Settings:
    check_interval_seconds: float = 15.0
    startup_grace_seconds: float = 120.0
    failures_required: int = 8
    down_max_watts: float = 5.0
    metric_max_age_seconds: float = 30.0
    host_cycle_cooldown_seconds: float = 1800.0
    global_cycle_gap_seconds: float = 300.0
    ping_count: int = 2
    ping_timeout_seconds: int = 2


@dataclass
class HostState:
    failures: int = 0
    last_cycle: float = 0.0
    cycle_history: list[float] = field(default_factory=list)


@dataclass
class WatchdogState:
    hosts: dict[str, HostState] = field(
        default_factory=lambda: {target.host: HostState() for target in TARGETS}
    )
    last_any_cycle: float = 0.0


@dataclass(frozen=True)
class OutletSample:
    outlet: int
    pdu_name: str
    status: int
    power_watts: float


@dataclass(frozen=True)
class Snapshot:
    up: bool
    last_success: float
    outlets: dict[str, OutletSample]


@dataclass(frozen=True)
class Decision:
    cycle: bool
    reason: str


PROM_FILE = Path(
    os.environ.get(
        "PDU_PROM_FILE",
        os.path.expanduser("~/.local/share/node_exporter/textfile/pdu.prom"),
    )
)
STATE_FILE = Path(
    os.environ.get(
        "SPARK_WATCHDOG_STATE_FILE",
        os.path.expanduser("~/.local/state/spark-pdu-watchdog/state.json"),
    )
)
INHIBIT_FILE = Path(
    os.environ.get(
        "SPARK_WATCHDOG_INHIBIT_FILE",
        os.path.expanduser("~/.config/spark-pdu-watchdog.disabled"),
    )
)

NUMBER = r"[-+]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][-+]?[0-9]+)?"
OUTLET_METRIC_RE = re.compile(
    rf"^pdu_outlet_(status|power_watts)\{{([^}}]+)\}}\s+({NUMBER})$"
)
LABEL_RE = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)="((?:\\.|[^"\\])*)"')


def load_settings() -> Settings:
    settings = Settings(
        check_interval_seconds=float(
            os.environ.get("SPARK_WATCHDOG_CHECK_INTERVAL", "15")
        ),
        startup_grace_seconds=float(
            os.environ.get("SPARK_WATCHDOG_STARTUP_GRACE", "120")
        ),
        failures_required=int(
            os.environ.get("SPARK_WATCHDOG_FAILURES_REQUIRED", "8")
        ),
        down_max_watts=float(
            os.environ.get("SPARK_WATCHDOG_DOWN_MAX_WATTS", "5")
        ),
        metric_max_age_seconds=float(
            os.environ.get("SPARK_WATCHDOG_METRIC_MAX_AGE", "30")
        ),
        host_cycle_cooldown_seconds=float(
            os.environ.get("SPARK_WATCHDOG_HOST_COOLDOWN", "1800")
        ),
        global_cycle_gap_seconds=float(
            os.environ.get("SPARK_WATCHDOG_GLOBAL_GAP", "300")
        ),
        ping_count=int(os.environ.get("SPARK_WATCHDOG_PING_COUNT", "2")),
        ping_timeout_seconds=int(
            os.environ.get("SPARK_WATCHDOG_PING_TIMEOUT", "2")
        ),
    )
    positive_values = (
        settings.check_interval_seconds,
        settings.failures_required,
        settings.down_max_watts,
        settings.metric_max_age_seconds,
        settings.host_cycle_cooldown_seconds,
        settings.global_cycle_gap_seconds,
        settings.ping_count,
        settings.ping_timeout_seconds,
    )
    if any(value <= 0 for value in positive_values):
        raise ValueError("watchdog timing, threshold, and count settings must be positive")
    if settings.startup_grace_seconds < 0:
        raise ValueError("watchdog startup grace must not be negative")
    return settings


def _scalar(text: str, metric: str) -> float:
    values = []
    prefix = metric + " "
    for line in text.splitlines():
        if line.startswith(prefix):
            values.append(float(line[len(prefix) :]))
    if len(values) != 1 or not math.isfinite(values[0]):
        raise SafetyError(f"expected exactly one finite {metric} sample")
    return values[0]


def _unescape_label(value: str) -> str:
    return value.replace(r"\n", "\n").replace(r'\"', '"').replace(r"\\", "\\")


def parse_snapshot(text: str) -> Snapshot:
    up = _scalar(text, "pdu_up") == 1.0
    last_success = _scalar(text, "pdu_last_success_unixtime_seconds")
    records: dict[str, dict[str, object]] = {}
    for line in text.splitlines():
        match = OUTLET_METRIC_RE.match(line)
        if not match:
            continue
        metric, raw_labels, raw_value = match.groups()
        labels = {
            key: _unescape_label(value) for key, value in LABEL_RE.findall(raw_labels)
        }
        host = labels.get("name")
        if host not in TARGET_BY_HOST:
            continue
        try:
            outlet = int(labels["outlet"])
            pdu_name = labels["pdu_name"]
            value = float(raw_value)
        except (KeyError, ValueError) as exc:
            raise SafetyError(f"invalid outlet labels for {host}") from exc
        if not math.isfinite(value):
            raise SafetyError(f"non-finite outlet metric for {host}")
        identity = (outlet, pdu_name)
        record = records.setdefault(host, {"identity": identity})
        if record["identity"] != identity or metric in record:
            raise SafetyError(f"conflicting outlet metrics for {host}")
        record[metric] = value

    outlets: dict[str, OutletSample] = {}
    for host, record in records.items():
        if "status" not in record or "power_watts" not in record:
            continue
        outlet, pdu_name = record["identity"]
        outlets[host] = OutletSample(
            outlet=int(outlet),
            pdu_name=str(pdu_name),
            status=int(float(record["status"])),
            power_watts=float(record["power_watts"]),
        )
    return Snapshot(up=up, last_success=last_success, outlets=outlets)


def snapshot_is_fresh(snapshot: Snapshot, now: float, max_age: float) -> bool:
    age = now - snapshot.last_success
    return snapshot.up and -5.0 <= age <= max_age


def normalize_cycle_history(raw: object) -> list[float]:
    if not isinstance(raw, list):
        return []
    timestamps = [
        float(value)
        for value in raw
        if isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
        and float(value) >= 0
    ]
    return sorted(timestamps)[-CYCLE_HISTORY_LIMIT:]


def load_state(path: Path = STATE_FILE) -> WatchdogState:
    state = WatchdogState()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return state
    try:
        state.last_any_cycle = max(0.0, float(raw.get("last_any_cycle", 0)))
        raw_hosts = raw.get("hosts", {})
        for target in TARGETS:
            raw_host = raw_hosts.get(target.host, {})
            state.hosts[target.host] = HostState(
                failures=max(0, int(raw_host.get("failures", 0))),
                last_cycle=max(0.0, float(raw_host.get("last_cycle", 0))),
                cycle_history=normalize_cycle_history(
                    raw_host.get("cycle_history", [])
                ),
            )
    except (AttributeError, TypeError, ValueError):
        return WatchdogState()
    return state


def save_state(state: WatchdogState, path: Path = STATE_FILE) -> None:
    body = {
        "version": 2,
        "last_any_cycle": state.last_any_cycle,
        "hosts": {
            host: {
                "failures": host_state.failures,
                "last_cycle": host_state.last_cycle,
                "cycle_history": normalize_cycle_history(
                    host_state.cycle_history
                ),
            }
            for host, host_state in sorted(state.hosts.items())
            if host in TARGET_BY_HOST
        },
    }
    PDU.atomic_write(path, json.dumps(body, sort_keys=True, indent=2) + "\n")


def reset_failures(state: WatchdogState) -> None:
    for host_state in state.hosts.values():
        host_state.failures = 0


def evaluate_target(
    target: Target,
    snapshot: Snapshot,
    ping_ok: bool,
    state: WatchdogState,
    settings: Settings,
    now: float,
    started_at: float,
) -> Decision:
    host_state = state.hosts[target.host]
    sample = snapshot.outlets.get(target.host)
    if ping_ok:
        host_state.failures = 0
        return Decision(False, "ping healthy")
    if sample is None:
        host_state.failures = 0
        return Decision(False, "missing outlet metrics")
    if sample.outlet != target.outlet or sample.pdu_name != target.pdu_name:
        host_state.failures = 0
        return Decision(False, "outlet identity mismatch")
    if sample.status != 1:
        host_state.failures = 0
        return Decision(False, "outlet is not reported on")
    if sample.power_watts < 0 or sample.power_watts > settings.down_max_watts:
        host_state.failures = 0
        return Decision(False, f"power draw {sample.power_watts:g}W is not down")

    if host_state.last_cycle and (
        now - host_state.last_cycle < settings.host_cycle_cooldown_seconds
    ):
        host_state.failures = 0
        return Decision(False, "host cycle cooldown")
    if state.last_any_cycle and (
        now - state.last_any_cycle < settings.global_cycle_gap_seconds
    ):
        host_state.failures = 0
        return Decision(False, "global cycle gap")

    host_state.failures += 1
    if now - started_at < settings.startup_grace_seconds:
        return Decision(False, "startup grace")
    if host_state.failures < settings.failures_required:
        return Decision(
            False,
            f"confirmation {host_state.failures}/{settings.failures_required}",
        )
    return Decision(True, "ping down and outlet at down-power threshold")


def ping_target(host: str, settings: Settings) -> bool:
    timeout = settings.ping_count * (settings.ping_timeout_seconds + 1)
    try:
        result = subprocess.run(
            [
                "ping",
                "-n",
                "-c",
                str(settings.ping_count),
                "-W",
                str(settings.ping_timeout_seconds),
                host,
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0


def build_reboot_command(target: Target) -> str:
    if TARGET_BY_HOST.get(target.host) != target:
        raise SafetyError(f"target is not the canonical allowlisted target: {target}")
    if target.outlet not in ALLOWED_OUTLETS:
        raise SafetyError(f"outlet is not allowlisted: {target.outlet}")
    command = f"oltctrl index {target.outlet} act reboot"
    if not re.fullmatch(r"oltctrl index (2|3) act reboot", command):
        raise SafetyError(f"refusing unsafe PDU command: {command}")
    return command


def validate_live_outlet(
    target: Target,
    outlets: list[dict[str, object]],
    down_max_watts: float,
) -> float:
    matches = [row for row in outlets if int(row["outlet"]) == target.outlet]
    if len(matches) != 1:
        raise CycleCancelled(f"expected one live row for outlet {target.outlet}")
    row = matches[0]
    if str(row["pdu_name"]) != target.pdu_name:
        raise CycleCancelled(
            f"outlet {target.outlet} name changed from {target.pdu_name!r}"
        )
    if row["status"] is not True:
        raise CycleCancelled(f"outlet {target.outlet} is no longer on")
    power = float(row["power_watts"])
    if not math.isfinite(power) or power < 0 or power > down_max_watts:
        raise CycleCancelled(
            f"outlet {target.outlet} live power is {power:g}W, not down"
        )
    return power


def cycle_target(
    target: Target,
    settings: Settings,
    dry_run: bool,
    record_attempt: Callable[[], None],
    record_success: Callable[[], None],
) -> None:
    command = build_reboot_command(target)
    if ping_target(target.host, settings):
        raise CycleCancelled(f"{target.host} answered final confirmation ping")

    with PDU.pdu_lock():
        session = PDU.PduSession(PDU.HOST, PDU.AUTH_FILE)
        try:
            session.connect()
            outlets = PDU.parse_outlet_status(session.command("oltsta show"))
            live_power = validate_live_outlet(
                target, outlets, settings.down_max_watts
            )
            if dry_run:
                LOGGER.warning(
                    "DRY RUN host=%s live_power=%gW would_execute=%r",
                    target.host,
                    live_power,
                    command,
                )
                return
            record_attempt()
            response = session.command(command)
            if re.search(r"error|invalid|denied|failed", response, re.IGNORECASE):
                raise SafetyError(
                    f"PDU rejected reboot command for {target.host}: {response.strip()}"
                )
            record_success()
            LOGGER.warning(
                "CYCLED host=%s outlet=%d live_power=%gW command=%r",
                target.host,
                target.outlet,
                live_power,
                command,
            )
        finally:
            session.close()


def run_check(
    state: WatchdogState,
    settings: Settings,
    started_at: float,
    dry_run: bool,
) -> None:
    if INHIBIT_FILE.exists():
        reset_failures(state)
        save_state(state)
        LOGGER.warning("watchdog inhibited by %s", INHIBIT_FILE)
        return

    now = time.time()
    try:
        snapshot = parse_snapshot(PROM_FILE.read_text(encoding="utf-8"))
    except (OSError, SafetyError, ValueError) as exc:
        reset_failures(state)
        save_state(state)
        LOGGER.warning("no action: cannot read safe PDU snapshot: %s", exc)
        return
    if not snapshot_is_fresh(snapshot, now, settings.metric_max_age_seconds):
        reset_failures(state)
        save_state(state)
        LOGGER.warning("no action: PDU metrics are down or stale")
        return

    for target in TARGETS:
        ping_ok = ping_target(target.host, settings)
        decision = evaluate_target(
            target, snapshot, ping_ok, state, settings, now, started_at
        )
        host_state = state.hosts[target.host]
        if host_state.failures:
            sample = snapshot.outlets.get(target.host)
            power = sample.power_watts if sample is not None else float("nan")
            LOGGER.warning(
                "candidate host=%s outlet=%d ping=down power=%gW failures=%d reason=%s",
                target.host,
                target.outlet,
                power,
                host_state.failures,
                decision.reason,
            )
        if not decision.cycle:
            continue

        def record_attempt(host_state: HostState = host_state) -> None:
            attempted_at = time.time()
            host_state.failures = 0
            host_state.last_cycle = attempted_at
            state.last_any_cycle = attempted_at
            save_state(state)

        def record_success(host_state: HostState = host_state) -> None:
            host_state.cycle_history.append(time.time())
            host_state.cycle_history = normalize_cycle_history(
                host_state.cycle_history
            )
            save_state(state)

        try:
            cycle_target(
                target, settings, dry_run, record_attempt, record_success
            )
        except CycleCancelled as exc:
            host_state.failures = 0
            LOGGER.warning("cycle cancelled for %s: %s", target.host, exc)
        except (OSError, PDU.PduError, SafetyError, ValueError) as exc:
            LOGGER.error("cycle failed for %s: %s", target.host, exc)
    save_state(state)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true", help="perform one check")
    parser.add_argument(
        "--dry-run", action="store_true", help="validate but never send reboot commands"
    )
    args = parser.parse_args()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    try:
        settings = load_settings()
    except ValueError as exc:
        LOGGER.error("invalid settings: %s", exc)
        return 2
    state = load_state()
    started_at = time.time()
    while True:
        check_started = time.monotonic()
        run_check(state, settings, started_at, args.dry_run)
        if args.once:
            return 0
        remaining = settings.check_interval_seconds - (
            time.monotonic() - check_started
        )
        if remaining > 0:
            time.sleep(remaining)


if __name__ == "__main__":
    raise SystemExit(main())
