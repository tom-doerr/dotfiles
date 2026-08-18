#!/usr/bin/env python3
"""bcachefs /pool on the NAS -> Prometheus textfile exporter.

Runs on spark-1 (like pdu-exporter and ups-modbus-exporter) and reads the NAS
over the already-warm SSH master, because the metrics we want come from the
bcachefs CLI and installing a system unit on the NAS needs interactive sudo.

The headline series is the "Pending reconcile" backlog, which exists ONLY in the
CLI -- sysfs has no equivalent (reconcile_scan_pending is just the scan queue and
reads 0 while terabytes are still queued). Together with the undegraded 1x/2x/3x
replication table this makes the Aug 2026 3x build and the SSD->HDD destage
visible as trends instead of a single instantaneous number on the waybar.

Fails loud: nas_bcachefs_up 0 and no other series on SSH/parse failure, so a
broken probe reads as missing data rather than a pool that suddenly went quiet.
"""
import os
import re
import subprocess
import sys
import tempfile
import time

HOST = os.environ.get("NAS_BCACHEFS_HOST", "nas")
POOL = os.environ.get("NAS_BCACHEFS_POOL", "/pool")
BIN = os.environ.get("NAS_BCACHEFS_BIN", "~/.local/bin/bcachefs")
OUT = os.environ.get(
    "NAS_BCACHEFS_PROM_FILE",
    os.path.expanduser("~/.local/share/node_exporter/textfile/nas_bcachefs.prom"),
)
INTERVAL = float(os.environ.get("NAS_BCACHEFS_INTERVAL", "60"))
TIMEOUT = float(os.environ.get("NAS_BCACHEFS_TIMEOUT", "55"))


def fetch():
    """Raw `bcachefs fs usage` text from the NAS (bytes, not -h: we format later)."""
    cmd = [
        "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5",
        HOST, "%s fs usage %s" % (BIN, POOL),
    ]
    return subprocess.run(
        cmd, check=True, timeout=TIMEOUT,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    ).stdout.decode("utf-8", "replace")


# "hdd.exos1 (device 2):  sdg  rw  27992446201856  24663088046080  88%  [leaving]"
DEV_RE = re.compile(
    r"^(?P<label>\S+)\s+\(device\s+(?P<idx>\d+)\):\s+(?P<dev>\S+)\s+(?P<state>\S+)\s+"
    r"(?P<size>\d+)\s+(?P<used>\d+)\s+(?P<pct>\d+)%\s*(?P<leaving>\d+)?\s*$"
)
KV_RE = re.compile(r"^([A-Za-z_0-9][\w ]*):\s+([\d\s]+)$")


def parse(text):
    """-> (totals, replication, pending, devices).

    Section-keyed, never positional: `fs usage` prints only NONZERO rows in the
    Pending reconcile block, so a positional read would relabel compression as
    checksum the moment a category appears or drains.
    """
    totals, replication, pending, devices = {}, {}, {}, []
    section = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("Pending reconcile:"):
            section = "pending"
            continue
        if line.startswith("Device label"):
            section = "devices"
            continue
        if section == "devices":
            m = DEV_RE.match(line)
            if m:
                devices.append(m.groupdict())
            continue
        m = KV_RE.match(line)
        if not m:
            continue
        key = m.group(1).strip().lower().replace(" ", "_")
        vals = [int(v) for v in m.group(2).split()]
        if section == "pending":
            pending[key] = vals[:2]          # data column, then metadata column
        elif re.fullmatch(r"\d+x", key):
            replication[key] = vals[0]
        else:
            totals[key] = vals[0]
    return totals, replication, pending, devices


P = "nas_bcachefs"
HELP = [
    (P + "_pending_reconcile_bytes", "Queued reconcile work by category and column."),
    (P + "_replicated_bytes", "Undegraded data by number of durability-weighted copies."),
    (P + "_size_bytes", "Filesystem capacity."),
    (P + "_used_bytes", "Filesystem used."),
    (P + "_cached_bytes", "Data held only as a cached copy."),
    (P + "_reserved_bytes", "Reserved capacity."),
    (P + "_device_size_bytes", "Per-device capacity."),
    (P + "_device_used_bytes", "Per-device used."),
    (P + "_device_leaving_bytes", "Per-device data still to be evacuated."),
]


def render(totals, replication, pending, devices):
    out = []
    for cat, cols in sorted(pending.items()):
        for col, val in zip(("data", "metadata"), cols):
            out.append('%s_pending_reconcile_bytes{fs="pool",category="%s",column="%s"} %d'
                       % (P, cat, col, val))
    for copies, val in sorted(replication.items()):
        out.append('%s_replicated_bytes{fs="pool",copies="%s"} %d' % (P, copies.rstrip("x"), val))
    for key, metric in (("size", "size"), ("used", "used"),
                        ("cached", "cached"), ("reserved", "reserved")):
        if key in totals:
            out.append('%s_%s_bytes{fs="pool"} %d' % (P, metric, totals[key]))
    for d in devices:
        lbl = 'fs="pool",label="%s",device="%s",state="%s"' % (d["label"], d["dev"], d["state"])
        out.append("%s_device_size_bytes{%s} %s" % (P, lbl, d["size"]))
        out.append("%s_device_used_bytes{%s} %s" % (P, lbl, d["used"]))
        out.append("%s_device_leaving_bytes{%s} %s" % (P, lbl, d["leaving"] or 0))
    return out


def build():
    lines = []
    for name, help_ in HELP:
        lines.append("# HELP %s %s" % (name, help_))
        lines.append("# TYPE %s gauge" % name)
    lines.append("# HELP %s_up 1 if the NAS bcachefs probe succeeded." % P)
    lines.append("# TYPE %s_up gauge" % P)
    try:
        totals, replication, pending, devices = parse(fetch())
        if not totals or not devices:
            raise ValueError("no totals/devices parsed - output format changed?")
        lines.extend(render(totals, replication, pending, devices))
        lines.append("%s_up 1" % P)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        sys.stderr.write("nas-bcachefs-exporter: %s\n" % exc)
        lines.append("%s_up 0" % P)
    return "\n".join(lines) + "\n"


def write():
    body = build()
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(OUT))
    os.write(fd, body.encode())
    os.close(fd)
    os.chmod(tmp, 0o644)          # mkstemp is 0600; node_exporter must read it
    os.replace(tmp, OUT)


if __name__ == "__main__":
    if os.environ.get("NAS_BCACHEFS_ONESHOT"):
        sys.stdout.write(build())
    else:
        while True:
            write()
            time.sleep(INTERVAL)
