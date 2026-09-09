#!/bin/sh
# Waybar module: Vast.ai credit balance + runway.
# Key from $VAST_API_KEY, else ~/.config/vastai/vast_api_key (the vastai CLI's key file).
# Output: "VAST $<credit> <runway>h" e.g. "VAST $16.37 18h".
#   Runway = credit / (sum of dph_total over RUNNING instances). Shown only while
#   something is actually burning; an idle account has no meaningful runway.
#   Colour is driven by runway, NOT by a flat dollar figure: Vast destroys
#   instances when credit hits zero, so $20 is comfortable at $0.10/h and nearly
#   spent at $2/h. Red under RED_H hours, yellow under YELLOW_H, and red below
#   MIN_USD while something burns. An idle account is never coloured: nothing
#   can drain the balance, so a low figure is information, not an alarm.
#   "VAST ?" = no key,  "VAST !" = API/parse error (not a silent fake balance).

key="${VAST_API_KEY:-}"
key_file="$HOME/.config/vastai/vast_api_key"
[ -z "$key" ] && [ -r "$key_file" ] && key=$(tr -d '\r\n' < "$key_file")

if [ -z "$key" ]; then
    echo "VAST ?"
    exit 0
fi

user=$(curl -s -m 8 "https://console.vast.ai/api/v0/users/current/?api_key=$key" 2>/dev/null)
insts=$(curl -s -m 8 "https://console.vast.ai/api/v0/instances/?api_key=$key" 2>/dev/null)
export user insts
python3 <<'PYEOF'
import os, json

RED_H, YELLOW_H, MIN_USD = 12.0, 48.0, 5.0
try:
    credit = float(json.loads(os.environ["user"])["credit"])
    running = [i for i in json.loads(os.environ["insts"]).get("instances", [])
               if i.get("actual_status") == "running"]
    burn = sum(float(i.get("dph_total") or 0) for i in running)
    txt = "VAST $%.2f" % credit
    if burn > 0:
        hours = credit / burn
        txt += " %.0fh" % hours
        if hours < RED_H or credit < MIN_USD:
            txt = "<span color='#ff5555'>%s</span>" % txt
        elif hours < YELLOW_H:
            txt = "<span color='#f1fa8c'>%s</span>" % txt
    # Idle account (nothing running, nothing burning): never coloured. A low
    # balance cannot drain on its own, so red would be a permanent false alarm
    # (user request Sep 9 2026). MIN_USD only matters while something burns.
    print(txt)
except (KeyError, ValueError, TypeError, json.JSONDecodeError):
    print("VAST !")
PYEOF
