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


# Second probe: sysfs values `fs usage` does not expose. journal_flush_write is
# the fsync cost (an fsync IS one journal flush write); btree_cache_size and the
# per-device bucket split are the fragmentation/tier-composition signals.
SYSFS_CMD = r"""set -- /sys/fs/bcachefs/*-*-*-*-*; U=$1
for s in journal_flush_write journal_flush_seq btree_node_write; do
  [ -f "$U/time_stats/$s" ] || continue
  awk -v n=$s '/duration of events/{d=1} d&&/mean:/{print "ts",n,$4,$5;exit}' "$U/time_stats/$s"
done
read c < "$U/btree_cache_size"; echo "cache $c"
for d in "$U"/dev-*; do read l < "$d/label"
  awk -v l="$l" '/^(free|cached|user|btree)[ \t]/{print "bucket",l,$1,$2,$4}' "$d/alloc_debug"
done"""

UNIT_S = {"ns": 1e-9, "us": 1e-6, "ms": 1e-3, "s": 1.0}
UNIT_B = {"k": 1024, "M": 1024 ** 2, "G": 1024 ** 3, "T": 1024 ** 4}


# "hdd.exos1 (device 2):  sdg  rw  27992446201856  24663088046080  88%  [leaving]"
DEV_RE = re.compile(
    r"^(?P<label>\S+)\s+\(device\s+(?P<idx>\d+)\):\s+(?P<dev>\S+)\s+(?P<state>\S+)\s+"
    r"(?P<size>\d+)\s+(?P<used>\d+)\s+(?P<pct>\d+)%\s*(?P<leaving>\d+)?\s*$"
)
KV_RE = re.compile(r"^([A-Za-z_0-9][\w ]*):\s+([\d\s]+)$")


def sysfs_lines():
    """Prometheus lines from the sysfs probe. Raises on SSH/parse failure."""
    text = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", HOST, SYSFS_CMD],
        check=True, timeout=TIMEOUT,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    ).stdout.decode("utf-8", "replace")
    out = []
    for line in text.splitlines():
        f = line.split()
        if f[:1] == ["ts"] and len(f) == 4:
            out.append('%s_time_stat_seconds{fs="pool",stat="%s"} %g'
                       % (P, f[1], float(f[2]) * UNIT_S[f[3]]))
        elif f[:1] == ["cache"] and len(f) == 2:
            out.append('%s_btree_cache_bytes{fs="pool"} %d'
                       % (P, float(f[1][:-1]) * UNIT_B[f[1][-1]]))
        elif f[:1] == ["bucket"] and len(f) == 5:
            lbl = 'fs="pool",label="%s",type="%s"' % (f[1], f[2])
            out.append("%s_device_buckets{%s} %s" % (P, lbl, f[3]))
            out.append("%s_device_fragmented_sectors{%s} %s" % (P, lbl, f[4]))
    if not out:
        raise ValueError("sysfs probe returned nothing parseable")
    return out


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
    (P + "_time_stat_seconds", "bcachefs internal op latency, recent mean "
                               "(journal_flush_write == the fsync cost)."),
    (P + "_btree_cache_bytes", "Resident btree node cache."),
    (P + "_device_buckets", "Per-device buckets by data type."),
    (P + "_device_fragmented_sectors", "Per-device stranded sectors by data type."),
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
        lines.extend(sysfs_lines())
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
