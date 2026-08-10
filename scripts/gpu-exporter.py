#!/usr/bin/env python3
"""NVIDIA GPU -> Prometheus textfile exporter (nvidia-smi based).

Uses nvidia-smi rather than DCGM (spotty on GB10). Writes a node_exporter
textfile; runs on each Spark as a user service. Skips fields nvidia-smi reports
as N/A (genuinely unavailable, not hidden). Fails loud: gpu_up 0 on smi failure.
"""
import os
import subprocess
import sys
import tempfile
import time

OUT = os.environ.get(
    "GPU_PROM_FILE",
    os.path.expanduser("~/.local/share/node_exporter/textfile/gpu.prom"),
)
INTERVAL = float(os.environ.get("GPU_INTERVAL", "5"))

FIELDS = [
    ("utilization.gpu", "gpu_utilization_percent", "GPU compute utilization %.", 1),
    ("utilization.memory", "gpu_memory_bus_percent", "GPU memory-bus utilization %.", 1),
    ("memory.used", "gpu_memory_used_bytes", "GPU memory used.", 1024 * 1024),
    ("memory.total", "gpu_memory_total_bytes", "GPU memory total.", 1024 * 1024),
    ("temperature.gpu", "gpu_temperature_celsius", "GPU temperature.", 1),
    ("power.draw", "gpu_power_watts", "GPU power draw.", 1),
    ("clocks.sm", "gpu_clock_sm_mhz", "GPU SM clock.", 1),
    ("clocks.mem", "gpu_clock_mem_mhz", "GPU memory clock.", 1),
]
QUERY = "index,name," + ",".join(f[0] for f in FIELDS)


def build():
    lines = []
    for _f, name, help_, _s in FIELDS:
        lines.append("# HELP %s %s" % (name, help_))
        lines.append("# TYPE %s gauge" % name)
    lines.append("# HELP gpu_up 1 if nvidia-smi succeeded.")
    lines.append("# TYPE gpu_up gauge")
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=" + QUERY, "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=8, check=True,
        ).stdout
        for row in out.strip().splitlines():
            cols = [c.strip() for c in row.split(",")]
            lab = 'gpu="%s",name="%s"' % (cols[0], cols[1].replace('"', ""))
            for i, (_f, name, _h, scale) in enumerate(FIELDS):
                raw = cols[2 + i]
                if raw in ("[N/A]", "N/A", ""):
                    continue
                try:
                    lines.append("%s{%s} %g" % (name, lab, float(raw) * scale))
                except ValueError:
                    continue
        lines.append("gpu_up 1")
    except (subprocess.SubprocessError, OSError) as exc:
        sys.stderr.write("gpu-exporter: %s\n" % exc)
        lines.append("gpu_up 0")
    return "\n".join(lines) + "\n"


def write():
    body = build()
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(OUT))
    os.write(fd, body.encode())
    os.close(fd)
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    if os.environ.get("GPU_ONESHOT"):
        write()
    else:
        while True:
            write()
            time.sleep(INTERVAL)
