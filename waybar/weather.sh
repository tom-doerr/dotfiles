#!/bin/sh
# Waybar module: current weather + temperature for Mering via Open-Meteo (no API key).
# Coordinate-based (48.265N, 10.984E) — more accurate than wttr.in's nearest-station.
# Output: "<icon> <temp>", e.g. "☁️ +23°C".  "wx ?" on fetch/parse failure (not a silent fake).

resp=$(curl -s -m 8 "https://api.open-meteo.com/v1/forecast?latitude=48.265&longitude=10.984&current=temperature_2m,weather_code,is_day&timezone=Europe/Berlin" 2>/dev/null)
export resp
python3 <<'PYEOF'
import os, json
ICONS = {  # WMO weather code -> emoji
    0:"☀️", 1:"\U0001f324️", 2:"⛅", 3:"☁️",
    45:"\U0001f32b️", 48:"\U0001f32b️",
    51:"\U0001f326️", 53:"\U0001f326️", 55:"\U0001f326️", 56:"\U0001f327️", 57:"\U0001f327️",
    61:"\U0001f327️", 63:"\U0001f327️", 65:"\U0001f327️", 66:"\U0001f327️", 67:"\U0001f327️",
    71:"\U0001f328️", 73:"\U0001f328️", 75:"\U0001f328️", 77:"\U0001f328️",
    80:"\U0001f326️", 81:"\U0001f326️", 82:"\U0001f327️",
    85:"\U0001f328️", 86:"\U0001f328️",
    95:"⛈️", 96:"⛈️", 99:"⛈️",
}
try:
    c = json.loads(os.environ.get("resp") or "{}")["current"]
    t = float(c["temperature_2m"])
    code = int(c["weather_code"])
    icon = ICONS.get(code, "\U0001f321️")
    if code in (0, 1) and c.get("is_day") == 0:
        icon = "\U0001f319"  # clear/mainly-clear at night -> moon
    sign = "+" if t >= 0 else ""
    print("%s %s%.1f°C" % (icon, sign, t))
except Exception:
    print("wx ?")
PYEOF
