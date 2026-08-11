#!/usr/bin/env python3
"""Receive high-rate thermal samples over UDP and persist them.

Runs on spark-1 (the box that stays up) so that samples from a spark that
hangs are already off the dying machine before it stops responding.

The receive loop never blocks on the database: datagrams go into a deque,
a writer thread drains it. If Postgres is slow or down the buffer grows and
old samples are dropped rather than stalling the socket -- losing history is
survivable, losing the seconds around a crash is not.

Env: THERMAL_PORT (5601), THERMAL_DSN, THERMAL_FLUSH_MS (200),
     THERMAL_MAX_BUFFER (200000).
"""
import collections
import datetime
import os
import socket
import threading
import time

import psycopg

PORT = int(os.environ.get("THERMAL_PORT", "5601"))
DSN = os.environ.get("THERMAL_DSN", "dbname=telemetry")
FLUSH = float(os.environ.get("THERMAL_FLUSH_MS", "200")) / 1000.0
MAXBUF = int(os.environ.get("THERMAL_MAX_BUFFER", "200000"))
COLS = ("host", "ts", "zone0", "zone1", "zone2", "zone3", "zone4", "zone5",
        "zone6", "gpu_watts", "gpu_temp", "gpu_clock", "gpu_util",
        "cpu_pct", "load1")
SQL = (f"INSERT INTO thermal_samples ({','.join(COLS)}) "
       f"VALUES ({','.join(['%s'] * len(COLS))}) ON CONFLICT DO NOTHING")

buf = collections.deque(maxlen=MAXBUF)
stats = {"rx": 0, "written": 0, "dropped": 0, "errors": 0}


def parse(raw):
    """b'host,epoch,z0..z6,w,t,c,u,cpu,load' -> tuple for INSERT, or None."""
    parts = raw.decode("utf-8", "replace").split(",")
    if len(parts) != len(COLS):
        return None
    host, ts = parts[0], parts[1]
    if not host:
        return None
    try:
        when = datetime.datetime.fromtimestamp(
            float(ts), datetime.timezone.utc)
    except ValueError:
        return None
    vals = []
    for p in parts[2:]:
        if p == "":
            vals.append(None)
        else:
            try:
                vals.append(float(p))
            except ValueError:
                vals.append(None)
    return (host, when, *vals)


def writer():
    conn = None
    while True:
        time.sleep(FLUSH)
        if not buf:
            continue
        batch = [buf.popleft() for _ in range(len(buf))]
        try:
            if conn is None or conn.closed:
                conn = psycopg.connect(DSN, autocommit=True)
            with conn.cursor() as cur:
                cur.executemany(SQL, batch)
            stats["written"] += len(batch)
        except Exception as exc:
            stats["errors"] += 1
            stats["dropped"] += len(batch)
            if stats["errors"] % 20 == 1:
                print(f"db error ({type(exc).__name__}: {exc}) "
                      f"- dropped {len(batch)} rows", flush=True)
            try:
                if conn is not None:
                    conn.close()
            except Exception:
                pass
            conn = None


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8 << 20)
    sock.bind(("0.0.0.0", PORT))
    threading.Thread(target=writer, daemon=True).start()
    print(f"listening udp/{PORT} -> {DSN}", flush=True)
    last = time.time()
    while True:
        raw, _ = sock.recvfrom(2048)
        stats["rx"] += 1
        row = parse(raw)
        if row is not None:
            if len(buf) == buf.maxlen:
                stats["dropped"] += 1
            buf.append(row)
        if time.time() - last > 300:
            print(f"rx={stats['rx']} written={stats['written']} "
                  f"dropped={stats['dropped']} errors={stats['errors']} "
                  f"queue={len(buf)}", flush=True)
            last = time.time()


if __name__ == "__main__":
    raise SystemExit(main())
