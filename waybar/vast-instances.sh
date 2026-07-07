#!/bin/sh
# Waybar module: running Vast.ai instances with GPU(s) and per-hour cost.
# Key from $VAST_API_KEY, else ~/.config/vastai/vast_api_key.
# Output:  idle -> dim "vast: none";  running -> "vast: 2xRTX4090 $0.60/h  1xH100 $2.10/h = $2.70/h"
#          "VAST ?" no key, "VAST !" API/parse error.

key="${VAST_API_KEY:-}"
key_file="$HOME/.config/vastai/vast_api_key"
[ -z "$key" ] && [ -r "$key_file" ] && key=$(tr -d '\r\n' < "$key_file")
[ -z "$key" ] && { echo "VAST ?"; exit 0; }

resp=$(curl -s -m 8 "https://console.vast.ai/api/v0/instances/?api_key=$key" 2>/dev/null)
export resp
python3 <<'PYEOF'
import os, json
try:
    d = json.loads(os.environ.get("resp") or "{}")
    insts = d.get("instances", [])
    running = [i for i in insts if i.get("actual_status") == "running"]
    if not running:
        print("<span color='#6c7086'>vast: none</span>")
    else:
        parts = []
        for i in running:
            n = int(i.get("num_gpus") or 1)
            gpu = (i.get("gpu_name") or "GPU").replace(" ", "")
            dph = float(i.get("dph_total") or 0)
            parts.append("%dx%s $%.2f/h" % (n, gpu, dph))
        line = "vast: " + "  ".join(parts)
        if len(running) > 1:
            line += " = $%.2f/h" % sum(float(i.get("dph_total") or 0) for i in running)
        print(line)
except Exception:
    print("VAST !")
PYEOF
