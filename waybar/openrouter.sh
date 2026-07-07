#!/bin/sh
# Waybar module: current OpenRouter credit balance.
# Key is read from $OPENROUTER_API_KEY, else ~/.config/openrouter/key (chmod 600).
# Output: "OR $<remaining>" (total_credits - total_usage).
#   "OR ?" = no key configured,  "OR !" = API/parse error (not a silent fake balance).

key="${OPENROUTER_API_KEY:-}"
key_file="$HOME/.config/openrouter/key"
[ -z "$key" ] && [ -r "$key_file" ] && key=$(tr -d '\r\n' < "$key_file")

if [ -z "$key" ]; then
    echo "OR ?"
    exit 0
fi

resp=$(curl -s -m 8 -H "Authorization: Bearer $key" https://openrouter.ai/api/v1/credits)
printf '%s' "$resp" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)["data"]
    bal = float(d["total_credits"]) - float(d["total_usage"])
    print(f"OR ${bal:.2f}")
except Exception:
    print("OR !")
'
