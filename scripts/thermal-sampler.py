#!/usr/bin/env python3
"""High-rate SoC thermal sampler -- streams off the box, never buffers.

Why streaming and not a local file: when spark-2 dies, the OS HANGS first
and the hardware keeps drawing 142-170 W for 16-40 s before power collapses
(measured across 6 crashes, Aug 11 2026). A hung kernel cannot flush its
page cache, so anything written locally in the final moments is lost. Each
sample therefore leaves the machine immediately as a UDP datagram -- fire
and forget, ~10 us, no blocking, no retransmit to stall on.

The ACPI zones genuinely update 6-20 times/s (measured), so 1 Hz Prometheus
scraping aliases away ~95% of the thermal dynamics. Each sysfs read costs
19 us, so 100 Hz across 7 zones is ~1.3% of one core.

Env: THERMAL_COLLECTOR (host:port), THERMAL_HZ (default 100).
"""
import glob
import os
import socket
import subprocess
import threading
import time

HZ = float(os.environ.get("THERMAL_HZ", "100"))
DEST = os.environ.get("THERMAL_COLLECTOR", "spark-1:5601")
HOST = socket.gethostname()
ZONES = sorted(glob.glob("/sys/class/thermal/thermal_zone*/temp"))

# nvidia-smi updates only ~2 Hz no matter how fast it is polled, so it runs
# as one persistent subprocess feeding a shared slot, not once per sample.
_gpu = {"w": None, "t": None, "c": None, "u": None}


def gpu_reader():
    cmd = ["nvidia-smi", "--query-gpu=power.draw,temperature.gpu,clocks.sm,"
           "utilization.gpu", "--format=csv,noheader,nounits", "-lms", "500"]
    while True:
        try:
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True)
            for line in p.stdout:
                parts = [x.strip() for x in line.split(",")]
                if len(parts) == 4:
                    try:
                        _gpu.update(w=float(parts[0]), t=float(parts[1]),
                                    c=float(parts[2]), u=float(parts[3]))
                    except ValueError:
                        pass
        except Exception:
            time.sleep(5)


def read_zones(handles):
    """Reuse open fds: ~19 us/read, and no path lookup per sample."""
    out = []
    for fh in handles:
        try:
            fh.seek(0)
            out.append(int(fh.read().strip()) / 1000.0)
        except Exception:
            out.append(None)
    return out


def load1():
    try:
        return float(open("/proc/loadavg").read().split()[0])
    except Exception:
        return None


def main():
    if not ZONES:
        print("no thermal zones found", flush=True)
        return 1
    host, port = DEST.split(":")
    addr = (socket.gethostbyname(host), int(port))
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    threading.Thread(target=gpu_reader, daemon=True).start()
    handles = [open(z) for z in ZONES]
    print(f"sampling {len(handles)} zones at {HZ:g} Hz -> udp {DEST}",
          flush=True)

    period = 1.0 / HZ
    nxt = time.time()
    load, last_load = None, 0.0
    while True:
        now = time.time()
        if now - last_load > 2.0:          # /proc/loadavg is cheap but not free
            load, last_load = load1(), now
        z = read_zones(handles)
        g = dict(_gpu)
        # host,ts,z0..z6,gpu_w,gpu_t,gpu_c,gpu_u,cpu,load  -- '' for missing
        fields = [HOST, f"{now:.4f}"]
        fields += ["" if v is None else f"{v:.1f}" for v in z[:7]]
        fields += ["" for _ in range(max(0, 7 - len(z)))]
        fields += ["" if g[k] is None else f"{g[k]:.1f}" for k in "wtcu"]
        fields += ["", "" if load is None else f"{load:.2f}"]
        try:
            sock.sendto((",".join(fields)).encode(), addr)
        except OSError:
            pass                            # never let the network stall us
        nxt += period
        delay = nxt - time.time()
        if delay > 0:
            time.sleep(delay)
        else:
            nxt = time.time()               # fell behind: resync, don't spin


if __name__ == "__main__":
    raise SystemExit(main())
