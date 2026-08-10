#!/usr/bin/env python3
"""CyberPower PDU CLI -> Prometheus textfile exporter.

Uses short SSH command-shell sessions because this PDU firmware intermittently
closes its CLI session after status commands. A failed poll is retried with a
fresh session. Authentication is read from ~/.config/pdu-admin (username on
line 1, password on line 2).

After all attempts fail, pdu_up is set to 0 while the last successful samples
and timestamp are retained. Safety consumers must require pdu_up 1; display
consumers may explicitly show those samples as briefly stale.
"""

from __future__ import annotations

import argparse
import fcntl
import math
import os
import re
import select
import signal
import stat
import subprocess
import sys
import tempfile
import time
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path


HOST = os.environ.get("PDU_HOST", "192.168.20.177")
AUTH_FILE = Path(
    os.environ.get("PDU_AUTH_FILE", os.path.expanduser("~/.config/pdu-admin"))
)
OUT = Path(
    os.environ.get(
        "PDU_PROM_FILE",
        os.path.expanduser("~/.local/share/node_exporter/textfile/pdu.prom"),
    )
)
INTERVAL = float(os.environ.get("PDU_INTERVAL", "5"))
COMMAND_TIMEOUT = float(os.environ.get("PDU_COMMAND_TIMEOUT", "10"))
POLL_ATTEMPTS = max(1, int(os.environ.get("PDU_POLL_ATTEMPTS", "2")))
RETRY_DELAY = max(0.0, float(os.environ.get("PDU_RETRY_DELAY", "1")))
LOCK_FILE = Path(
    os.environ.get(
        "PDU_LOCK_FILE", os.path.expanduser("~/.local/state/pdu-command.lock")
    )
)
PROMPT = b"CyberPower > "
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

METRIC_HEADER = [
    "# HELP pdu_up 1 when the latest PDU poll completed and parsed successfully.",
    "# TYPE pdu_up gauge",
    "# HELP pdu_last_success_unixtime_seconds Unix time of the latest successful PDU poll.",
    "# TYPE pdu_last_success_unixtime_seconds gauge",
    "# HELP pdu_scrape_duration_seconds Time spent reading the latest PDU sample.",
    "# TYPE pdu_scrape_duration_seconds gauge",
    "# HELP pdu_device_current_amperes Total PDU load current.",
    "# TYPE pdu_device_current_amperes gauge",
    "# HELP pdu_device_power_watts Total PDU real power.",
    "# TYPE pdu_device_power_watts gauge",
    "# HELP pdu_device_apparent_power_volt_amperes Total PDU apparent power.",
    "# TYPE pdu_device_apparent_power_volt_amperes gauge",
    "# HELP pdu_power_factor_ratio Total PDU power factor.",
    "# TYPE pdu_power_factor_ratio gauge",
    "# HELP pdu_peak_current_amperes Peak PDU load current reported by the device.",
    "# TYPE pdu_peak_current_amperes gauge",
    "# HELP pdu_energy_kilowatt_hours Accumulated PDU energy reported by the device.",
    "# TYPE pdu_energy_kilowatt_hours counter",
    "# HELP pdu_voltage_volts PDU input voltage.",
    "# TYPE pdu_voltage_volts gauge",
    "# HELP pdu_frequency_hertz PDU input frequency.",
    "# TYPE pdu_frequency_hertz gauge",
    "# HELP pdu_outlet_status 1 when the outlet is switched on, otherwise 0.",
    "# TYPE pdu_outlet_status gauge",
    "# HELP pdu_outlet_current_amperes Per-outlet load current.",
    "# TYPE pdu_outlet_current_amperes gauge",
    "# HELP pdu_outlet_power_watts Per-outlet real power.",
    "# TYPE pdu_outlet_power_watts gauge",
]


class PduError(RuntimeError):
    """A PDU connection, command, or response error."""


@contextmanager
def pdu_lock(path: Path = LOCK_FILE) -> Iterator[None]:
    """Serialize access to the PDU's single-session management controller."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+", encoding="utf-8") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def parse_outlet_map(value: str) -> dict[int, str]:
    mapping: dict[int, str] = {}
    for item in filter(None, (part.strip() for part in value.split(","))):
        try:
            outlet, name = item.split("=", 1)
            index = int(outlet)
        except (ValueError, TypeError) as exc:
            raise ValueError(f"invalid PDU_OUTLET_MAP entry: {item!r}") from exc
        if index < 1 or not name.strip():
            raise ValueError(f"invalid PDU_OUTLET_MAP entry: {item!r}")
        mapping[index] = name.strip()
    return mapping


OUTLET_MAP = parse_outlet_map(
    os.environ.get("PDU_OUTLET_MAP", "1=spark-1,2=spark-2,3=spark-3")
)


def _required_float(pattern: str, text: str, field: str) -> float:
    match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
    if not match:
        raise PduError(f"missing {field} in PDU response")
    return float(match.group(1))


def parse_device_status(text: str) -> dict[str, float]:
    load = re.search(
        r"Device\s+Load\s*:\s*([0-9.]+)\s*A\s*/\s*([0-9.]+)\s*W\s*/\s*([0-9.]+)\s*VA",
        text,
        re.IGNORECASE,
    )
    if not load:
        raise PduError("missing device load in PDU response")
    return {
        "current_amperes": float(load.group(1)),
        "power_watts": float(load.group(2)),
        "apparent_power_volt_amperes": float(load.group(3)),
        "power_factor_ratio": _required_float(
            r"Power\s+Factor\s*:\s*([0-9.]+)", text, "power factor"
        ),
        "peak_current_amperes": _required_float(
            r"Peak\s+Load\s*:\s*([0-9.]+)\s*A", text, "peak load"
        ),
        "energy_kilowatt_hours": _required_float(
            r"Energy\s*:\s*([0-9.]+)\s*kWh", text, "energy"
        ),
        "voltage_volts": _required_float(
            r"Voltage\s*:\s*([0-9.]+)\s*V", text, "voltage"
        ),
        "frequency_hertz": _required_float(
            r"Frequency\s*:\s*([0-9.]+)\s*Hz", text, "frequency"
        ),
    }


def parse_outlet_status(text: str) -> list[dict[str, object]]:
    outlets: list[dict[str, object]] = []
    pattern = re.compile(
        r"^\s*(\d+)\s+(.+?)\s{2,}(On|Off)\s+([0-9.]+)\s+([0-9.]+)\s*$",
        re.IGNORECASE | re.MULTILINE,
    )
    for match in pattern.finditer(text):
        outlets.append(
            {
                "outlet": int(match.group(1)),
                "pdu_name": match.group(2).strip(),
                "status": match.group(3).lower() == "on",
                "current_amperes": float(match.group(4)),
                "power_watts": float(match.group(5)),
            }
        )
    if not outlets:
        raise PduError("missing outlet rows in PDU response")
    return outlets


def _label(value: object) -> str:
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def render_success(
    device: dict[str, float],
    outlets: list[dict[str, object]],
    outlet_map: dict[int, str],
    now: float,
    duration: float,
) -> str:
    lines = METRIC_HEADER + [
        "pdu_up 1",
        f"pdu_last_success_unixtime_seconds {now:.3f}",
        f"pdu_scrape_duration_seconds {duration:.6f}",
        f"pdu_device_current_amperes {device['current_amperes']}",
        f"pdu_device_power_watts {device['power_watts']}",
        "pdu_device_apparent_power_volt_amperes "
        f"{device['apparent_power_volt_amperes']}",
        f"pdu_power_factor_ratio {device['power_factor_ratio']}",
        f"pdu_peak_current_amperes {device['peak_current_amperes']}",
        f"pdu_energy_kilowatt_hours {device['energy_kilowatt_hours']}",
        f"pdu_voltage_volts {device['voltage_volts']}",
        f"pdu_frequency_hertz {device['frequency_hertz']}",
    ]
    for outlet in sorted(outlets, key=lambda item: int(item["outlet"])):
        index = int(outlet["outlet"])
        name = outlet_map.get(index, str(outlet["pdu_name"]))
        labels = (
            f'outlet="{index}",name="{_label(name)}",'
            f'pdu_name="{_label(outlet["pdu_name"])}"'
        )
        lines.extend(
            [
                f"pdu_outlet_status{{{labels}}} {1 if outlet['status'] else 0}",
                f"pdu_outlet_current_amperes{{{labels}}} {outlet['current_amperes']}",
                f"pdu_outlet_power_watts{{{labels}}} {outlet['power_watts']}",
            ]
        )
    return "\n".join(lines) + "\n"


def render_failure(
    last_success: float, duration: float, last_good_body: str = ""
) -> str:
    if not last_good_body:
        return (
            "\n".join(
                METRIC_HEADER
                + [
                    "pdu_up 0",
                    f"pdu_last_success_unixtime_seconds {last_success:.3f}",
                    f"pdu_scrape_duration_seconds {duration:.6f}",
                ]
            )
            + "\n"
        )

    replacements = {
        "pdu_up": "pdu_up 0",
        "pdu_last_success_unixtime_seconds": (
            f"pdu_last_success_unixtime_seconds {last_success:.3f}"
        ),
        "pdu_scrape_duration_seconds": (
            f"pdu_scrape_duration_seconds {duration:.6f}"
        ),
    }
    lines = [
        replacements.get(line.split(" ", 1)[0], line)
        for line in last_good_body.splitlines()
    ]
    return "\n".join(lines) + "\n"


def load_last_good(path: Path) -> tuple[str, float]:
    try:
        body = path.read_text(encoding="utf-8")
    except OSError:
        return "", 0.0
    if not re.search(r"^pdu_up [01]$", body, re.MULTILINE):
        return "", 0.0
    if not re.search(r"^pdu_outlet_power_watts\{", body, re.MULTILINE):
        return "", 0.0
    match = re.search(
        r"^pdu_last_success_unixtime_seconds ([0-9]+(?:\.[0-9]+)?)$",
        body,
        re.MULTILINE,
    )
    if not match:
        return "", 0.0
    last_success = float(match.group(1))
    if not math.isfinite(last_success) or last_success < 0:
        return "", 0.0
    return body, last_success


def atomic_write(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(body)
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def load_credentials(path: Path) -> tuple[str, str]:
    mode = stat.S_IMODE(path.stat().st_mode)
    if mode & 0o077:
        raise PduError(f"credential file must not be group/world accessible: {path}")
    lines = path.read_text(encoding="utf-8").splitlines()
    if len(lines) < 2 or not lines[0] or not lines[1]:
        raise PduError(f"credential file must contain username and password: {path}")
    return lines[0], lines[1]


class PduSession:
    def __init__(self, host: str, auth_file: Path, timeout: float = COMMAND_TIMEOUT):
        self.host = host
        self.auth_file = auth_file
        self.timeout = timeout
        self.process: subprocess.Popen[bytes] | None = None
        self.buffer = bytearray()

    def connect(self) -> None:
        username, password = load_credentials(self.auth_file)
        environment = os.environ.copy()
        environment.update(
            {"SSHPASS": password, "LANG": "C", "LC_ALL": "C", "TERM": "dumb"}
        )
        command = [
            "sshpass",
            "-e",
            "ssh",
            "-tt",
            "-o",
            "ControlMaster=no",
            "-o",
            "ControlPath=none",
            "-o",
            "PreferredAuthentications=keyboard-interactive,password",
            "-o",
            "PubkeyAuthentication=no",
            "-o",
            "NumberOfPasswordPrompts=1",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "ConnectTimeout=8",
            f"{username}@{self.host}",
        ]
        self.process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env=environment,
            bufsize=0,
        )
        self._read_until_prompt(self.timeout + 8)

    def _read_until_prompt(self, timeout: float) -> str:
        if self.process is None or self.process.stdout is None:
            raise PduError("PDU SSH session is not running")
        deadline = time.monotonic() + timeout
        descriptor = self.process.stdout.fileno()
        while True:
            prompt_at = self.buffer.find(PROMPT)
            if prompt_at >= 0:
                result = bytes(self.buffer[:prompt_at])
                del self.buffer[: prompt_at + len(PROMPT)]
                return ANSI_RE.sub(
                    "", result.decode("utf-8", errors="replace").replace("\r", "")
                )
            if self.process.poll() is not None:
                detail = bytes(self.buffer).decode("utf-8", errors="replace").strip()
                raise PduError(f"PDU SSH session exited: {detail[-240:]}")
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise PduError("timed out waiting for PDU command prompt")
            readable, _, _ = select.select([descriptor], [], [], remaining)
            if not readable:
                raise PduError("timed out waiting for PDU command prompt")
            chunk = os.read(descriptor, 4096)
            if not chunk:
                raise PduError("PDU SSH session closed unexpectedly")
            self.buffer.extend(chunk)

    def command(self, value: str) -> str:
        if "\n" in value or "\r" in value:
            raise ValueError("PDU command must be a single line")
        if self.process is None or self.process.stdin is None:
            raise PduError("PDU SSH session is not running")
        self.process.stdin.write((value + "\r").encode())
        self.process.stdin.flush()
        return self._read_until_prompt(self.timeout)

    def close(self) -> None:
        process = self.process
        self.process = None
        if process is None:
            return
        try:
            if process.poll() is None and process.stdin is not None:
                process.stdin.write(b"exit\r")
                process.stdin.flush()
                process.wait(timeout=2)
        except (BrokenPipeError, subprocess.TimeoutExpired):
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)


def collect(session: PduSession, outlet_map: dict[int, str]) -> tuple[str, float]:
    started = time.monotonic()
    device = parse_device_status(session.command("devsta show"))
    outlets = parse_outlet_status(session.command("oltsta show"))
    finished = time.time()
    return (
        render_success(
            device, outlets, outlet_map, finished, time.monotonic() - started
        ),
        finished,
    )


def collect_with_retries(
    outlet_map: dict[int, str],
    attempts: int = POLL_ATTEMPTS,
    retry_delay: float = RETRY_DELAY,
) -> tuple[str, float]:
    if attempts < 1:
        raise ValueError("PDU poll attempts must be at least one")
    last_error: OSError | PduError | ValueError | None = None
    for attempt in range(1, attempts + 1):
        session = PduSession(HOST, AUTH_FILE)
        try:
            session.connect()
            return collect(session, outlet_map)
        except (OSError, PduError, ValueError) as exc:
            last_error = exc
            if attempt < attempts:
                sys.stderr.write(
                    "pdu-exporter: poll attempt "
                    f"{attempt}/{attempts} failed: {exc}; retrying\n"
                )
                if retry_delay > 0:
                    time.sleep(retry_delay)
        finally:
            session.close()
    raise PduError(
        f"PDU poll failed after {attempts} attempts: {last_error}"
    ) from last_error


def run_once(stdout: bool) -> int:
    attempt_started = time.monotonic()
    last_good_body, last_success = load_last_good(OUT)
    try:
        with pdu_lock():
            body, _ = collect_with_retries(OUTLET_MAP)
        if stdout:
            sys.stdout.write(body)
        else:
            atomic_write(OUT, body)
        return 0
    except (OSError, PduError, ValueError) as exc:
        sys.stderr.write(f"pdu-exporter: {exc}\n")
        if not stdout:
            duration = max(0.0, time.monotonic() - attempt_started)
            atomic_write(
                OUT, render_failure(last_success, duration, last_good_body)
            )
        return 1


def run_forever() -> int:
    last_good_body, last_success = load_last_good(OUT)
    stopping = False

    def stop(_signum: int, _frame: object) -> None:
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    while not stopping:
        attempt_started = time.monotonic()
        try:
            with pdu_lock():
                body, last_success = collect_with_retries(OUTLET_MAP)
                last_good_body = body
                atomic_write(OUT, body)
        except (OSError, PduError, ValueError) as exc:
            duration = max(0.0, time.monotonic() - attempt_started)
            sys.stderr.write(f"pdu-exporter: {exc}\n")
            atomic_write(
                OUT, render_failure(last_success, duration, last_good_body)
            )
        remaining = INTERVAL - (time.monotonic() - attempt_started)
        if not stopping and remaining > 0:
            time.sleep(remaining)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true", help="collect one sample and exit")
    parser.add_argument("--stdout", action="store_true", help="print a one-shot sample")
    args = parser.parse_args()
    if args.stdout:
        args.once = True
    return run_once(args.stdout) if args.once else run_forever()


if __name__ == "__main__":
    raise SystemExit(main())
