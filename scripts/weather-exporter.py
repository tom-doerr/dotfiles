#!/usr/bin/env python3
"""Outdoor weather -> Prometheus textfile exporter (Open-Meteo, no API key).

Coords for Mering (48.265N, 10.984E). Writes a node_exporter textfile so the
outdoor conditions land in Prometheus alongside GB10 temps -> lets us correlate
hot days with the thermal shutdowns. Fails loud: weather_up 0 on fetch/parse
failure (no stale/faked reading).
"""
import json
import os
import tempfile
import time
import urllib.request

URL = ("https://api.open-meteo.com/v1/forecast?latitude=48.265&longitude=10.984"
       "&current=temperature_2m,relative_humidity_2m,apparent_temperature,"
       "weather_code,wind_speed_10m,is_day&timezone=Europe/Berlin")
OUT = os.environ.get(
    "WEATHER_PROM_FILE",
    os.path.expanduser("~/.local/share/node_exporter/textfile/weather.prom"),
)
INTERVAL = float(os.environ.get("WEATHER_INTERVAL", "60"))

FIELDS = {
    "temperature_2m": ("weather_outdoor_temperature_celsius", "Outdoor air temperature."),
    "relative_humidity_2m": ("weather_outdoor_humidity_percent", "Outdoor relative humidity."),
    "apparent_temperature": ("weather_outdoor_apparent_temperature_celsius", "Feels-like temp."),
    "wind_speed_10m": ("weather_outdoor_wind_kmh", "Wind speed."),
    "weather_code": ("weather_outdoor_wmo_code", "WMO weather code."),
    "is_day": ("weather_outdoor_is_day", "1 if daytime."),
}


def build():
    lines = []
    for name, help_ in FIELDS.values():
        lines.append("# HELP %s %s" % (name, help_))
        lines.append("# TYPE %s gauge" % name)
    lines.append("# HELP weather_up 1 if the weather fetch succeeded.")
    lines.append("# TYPE weather_up gauge")
    try:
        with urllib.request.urlopen(URL, timeout=8) as resp:
            cur = json.loads(resp.read().decode("utf-8"))["current"]
        for key, (name, _h) in FIELDS.items():
            lines.append("%s %s" % (name, float(cur[key])))
        lines.append("weather_up 1")
    except (OSError, ValueError, KeyError) as exc:
        import sys
        sys.stderr.write("weather-exporter: %s\n" % exc)
        lines.append("weather_up 0")
    return "\n".join(lines) + "\n"


def write():
    body = build()
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(OUT))
    os.write(fd, body.encode())
    os.close(fd)
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    if os.environ.get("WEATHER_ONESHOT"):
        write()
    else:
        while True:
            write()
            time.sleep(INTERVAL)
