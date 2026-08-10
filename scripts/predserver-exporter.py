#!/usr/bin/env python3
"""prediction-server /stats -> Prometheus textfile exporter.

Scrapes the intervention prediction server (int serve, :8765) /stats endpoint
and exports every numeric field as predserver_<field>. Generic: new numeric
fields appear automatically. Fails loud: predserver_up 0 on fetch failure.
"""
import json
import os
import re
import sys
import tempfile
import time
import urllib.request

URL = os.environ.get("PREDSERVER_STATS_URL", "http://localhost:8765/stats")
OUT = os.environ.get(
    "PREDSERVER_PROM_FILE",
    os.path.expanduser("~/.local/share/node_exporter/textfile/predserver.prom"),
)
INTERVAL = float(os.environ.get("PREDSERVER_INTERVAL", "15"))
_SAFE = re.compile(r"[^a-zA-Z0-9_]")


def build():
    lines = ["# HELP predserver_up 1 if the /stats scrape succeeded.",
             "# TYPE predserver_up gauge"]
    try:
        with urllib.request.urlopen(URL, timeout=6) as resp:
            d = json.loads(resp.read().decode("utf-8"))
        for k, v in d.items():
            if isinstance(v, bool) or not isinstance(v, (int, float)):
                continue
            name = "predserver_" + _SAFE.sub("_", k)
            lines.append("%s %s" % (name, v))
        lines.append("predserver_up 1")
    except (OSError, ValueError) as exc:
        sys.stderr.write("predserver-exporter: %s\n" % exc)
        lines.append("predserver_up 0")
    return "\n".join(lines) + "\n"


def write():
    body = build()
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(OUT))
    os.write(fd, body.encode())
    os.close(fd)
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    if os.environ.get("PREDSERVER_ONESHOT"):
        write()
    else:
        while True:
            write()
            time.sleep(INTERVAL)
