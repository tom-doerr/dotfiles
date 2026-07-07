#!/bin/sh
# Waybar module: current Vast.ai account credit balance.
# Key from $VAST_API_KEY, else ~/.config/vastai/vast_api_key (the vastai CLI's key file).
# Output: "VAST $<credit>" e.g. "VAST $16.37".  "VAST ?" = no key, "VAST !" = API/parse error.

key="${VAST_API_KEY:-}"
key_file="$HOME/.config/vastai/vast_api_key"
[ -z "$key" ] && [ -r "$key_file" ] && key=$(tr -d '\r\n' < "$key_file")

if [ -z "$key" ]; then
    echo "VAST ?"
    exit 0
fi

curl -s -m 8 "https://console.vast.ai/api/v0/users/current/?api_key=$key" 2>/dev/null | python3 -c '
import sys, json
try:
    print("VAST $%.2f" % float(json.load(sys.stdin)["credit"]))
except Exception:
    print("VAST !")
'
