#!/bin/bash
# ROSpider battery from the existing telemetry collector; no extra SSH/ROS poll.
# Formatting probe: ROSPIDER_MV=11500 ~/.config/waybar/rospider.sh
exec python3 - <<'PY'
import json
import math
import os
from pathlib import Path
import time


def hide():
    raise SystemExit(0)


probe = os.environ.get('ROSPIDER_MV')
if probe is not None:
    try:
        volts = float(probe) / 1000
    except ValueError:
        hide()
else:
    metrics_file = Path(os.environ.get('ROSPIDER_PROM_FILE',
                       str(Path.home() / '.local/share/node_exporter/textfile/rospider.prom')))
    wanted = {'rospider_exporter_up', 'rospider_exporter_last_sample_timestamp_seconds',
              'rospider_battery_voltage_volts'}
    try:
        metrics = {}
        for line in metrics_file.read_text().splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[0] in wanted:
                metrics[parts[0]] = float(parts[1])
        now = float(os.environ.get('ROSPIDER_NOW_EPOCH', time.time()))
        age = now - metrics.get('rospider_exporter_last_sample_timestamp_seconds', 0)
    except (OSError, ValueError):
        hide()
    if metrics.get('rospider_exporter_up') != 1 or not 0 <= age <= 10:
        hide()
    volts = metrics.get('rospider_battery_voltage_volts', float('nan'))

if not math.isfinite(volts) or not 5 < volts < 16:
    hide()

# Preserve the existing 3S LiPo voltage estimate; this is not a charge counter.
points = [(12600, 100), (12300, 90), (12000, 75), (11700, 55), (11400, 40),
          (11100, 25), (10800, 15), (10500, 8), (10000, 0)]
millivolts = round(volts * 1000)
percent = 100 if millivolts >= points[0][0] else 0
for (high_v, high_p), (low_v, low_p) in zip(points, points[1:]):
    if low_v <= millivolts <= high_v:
        percent = int(low_p + (high_p - low_p) * (millivolts - low_v) / (high_v - low_v))
        break
state = 'critical' if percent < 20 else 'warning' if percent < 40 else 'ok'
print(json.dumps({
    'text': f'🕷 {percent}% {volts:.2f} V',
    'tooltip': f'ROSpider battery: {percent}% estimated, {volts:.2f} V (3S LiPo).\n'
               'Percentage is estimated from voltage and changes with load.',
    'class': state, 'percentage': percent,
}, ensure_ascii=False))
PY
