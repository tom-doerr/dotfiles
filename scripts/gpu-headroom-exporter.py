#!/usr/bin/env python3
"""GPU headroom probe -> Prometheus textfile.

WHY THIS EXISTS: GB10 exposes no usable memory-bandwidth counter --
nvidia-smi `utilization.memory` returns a hard 0 (not N/A), DCGM is
unsupported on GB10, and the Grace nvidia_nvlink_c2c/scf hardware PMUs do
not exist on this SoC. `utilization.gpu` only says "a kernel was resident",
not how much of the machine it used, and power is only good for detecting
throttling.

So instead of READING a counter, MEASURE. Run a small fixed GEMM at a
regular interval and record the throughput it achieves. When the GPU is idle
the probe reaches its ceiling; when another job is using the machine the
probe slows in proportion. The ratio to the uncontended ceiling is the
fraction of GPU still available to a NEW job -- exactly the question
"would a second workload (or MPS) help on this host?".

Derive the ratio in PromQL; no baseline is stored here (a stored baseline
would be a silent default that rots):
    gpu_headroom_probe_gflops
      / max_over_time(gpu_headroom_probe_gflops[7d])

COST: a persistent CUDA context, ~0.3-0.5 GiB of unified memory, plus a
<1% duty cycle. Do NOT run this on a host already at its memory ceiling.
"""
import os
import sys
import tempfile
import time

OUT = os.environ.get(
    "GPU_HEADROOM_PROM_FILE",
    os.path.expanduser("~/.local/share/node_exporter/textfile/gpu_headroom.prom"),
)
INTERVAL = float(os.environ.get("GPU_HEADROOM_INTERVAL", "30"))
N = int(os.environ.get("GPU_HEADROOM_MATRIX", "2048"))
ITERS = int(os.environ.get("GPU_HEADROOM_ITERS", "30"))
DTYPE = os.environ.get("GPU_HEADROOM_DTYPE", "bfloat16")

# 2*N^3 FLOP per matmul (multiply-add counted as 2).
FLOP_PER_ITER = 2.0 * N * N * N


def write_atomic(text):
    d = os.path.dirname(OUT)
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".gpu_headroom.")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(text)
        os.chmod(tmp, 0o644)  # node_exporter must read it; mkstemp gives 0600
        os.replace(tmp, OUT)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def render(gflops, seconds, err):
    L = [
        "# HELP gpu_headroom_probe_gflops Achieved GFLOP/s of a fixed GEMM probe."
        " Falls as other work contends for the GPU.",
        "# TYPE gpu_headroom_probe_gflops gauge",
        "# HELP gpu_headroom_probe_seconds Wall time of the probe.",
        "# TYPE gpu_headroom_probe_seconds gauge",
        "# HELP gpu_headroom_up 1 if the probe ran, 0 on any failure.",
        "# TYPE gpu_headroom_up gauge",
    ]
    lab = 'matrix="%d",iters="%d",dtype="%s"' % (N, ITERS, DTYPE)
    if err is None:
        L.append("gpu_headroom_probe_gflops{%s} %g" % (lab, gflops))
        L.append("gpu_headroom_probe_seconds{%s} %g" % (lab, seconds))
        L.append("gpu_headroom_up 1")
    else:
        # No plausible-looking default: emit up=0 and nothing else, so a
        # broken probe reads as absent rather than as "0 GFLOP/s available".
        sys.stderr.write("gpu-headroom-exporter: %s\n" % err)
        L.append("gpu_headroom_up 0")
    return "\n".join(L) + "\n"


def main():
    import torch  # imported here so --help style failures stay fast

    if not torch.cuda.is_available():
        write_atomic(render(0, 0, "CUDA not available"))
        return 1
    dt = getattr(torch, DTYPE)
    dev = torch.device("cuda")
    ab = None

    while True:
        try:
            # Allocated once then REUSED: the probe must measure contention,
            # not allocator behaviour. But allocation lives inside the loop so
            # a host that currently cannot create a CUDA context (UMA
            # fragmentation, or the GB10 concurrent-context ceiling -- both
            # real here) publishes up=0 and RECOVERS later, instead of the
            # exporter dying once and going silent forever. up=0 on this
            # metric is itself the useful signal "this host cannot accept
            # another GPU job right now".
            if ab is None:
                a = torch.randn(N, N, device=dev, dtype=dt)
                b = torch.randn(N, N, device=dev, dtype=dt)
                for _ in range(3):  # warm cuBLAS autotune / lazy init
                    a @ b
                torch.cuda.synchronize()
                ab = (a, b)
            a, b = ab
            torch.cuda.synchronize()
            t0 = time.perf_counter()
            for _ in range(ITERS):
                c = a @ b
            torch.cuda.synchronize()
            dt_s = time.perf_counter() - t0
            del c
            if dt_s <= 0:
                raise RuntimeError("non-positive probe duration")
            gflops = (FLOP_PER_ITER * ITERS) / dt_s / 1e9
            write_atomic(render(gflops, dt_s, None))
        except Exception as exc:  # noqa: BLE001 - report, never fake a value
            ab = None  # drop the cache so the next cycle retries allocation
            write_atomic(render(0, 0, exc))
        time.sleep(INTERVAL)


if __name__ == "__main__":
    sys.exit(main() or 0)
