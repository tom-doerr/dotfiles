#!/bin/sh
# Waybar module: OpenRouter credit balance + spend.
# Key is read from $OPENROUTER_API_KEY, else ~/.config/openrouter/key (chmod 600).
# Output: "OR $<balance> d$<day> w$<week> m$<month>"
#   balance = total_credits - total_usage (GET /api/v1/credits, account-wide).
#   d/w/m   = GET /api/v1/key usage_daily/weekly/monthly. Per OpenRouter's docs these
#             cover "the current UTC day / UTC week (Mon-Sun) / UTC month" — CALENDAR
#             windows resetting at UTC midnight, NOT rolling 24h/7d/30d. They are also
#             PER-KEY and EXCLUDE BYOK spend (reported separately as byok_usage_*,
#             which costs no credits).
#   Balance turns red under 1 day of the current day's burn, yellow under 3 days.
#   "OR ?" = no key configured,  "OR !" = API/parse error (not a silent fake balance).
# No rolling-24h figure exists in the API: /api/v1/activity is also UTC-day-grouped
# and 403s without a management key. It would need local differencing of `usage`.

key="${OPENROUTER_API_KEY:-}"
key_file="$HOME/.config/openrouter/key"
[ -z "$key" ] && [ -r "$key_file" ] && key=$(tr -d '\r\n' < "$key_file")

if [ -z "$key" ]; then
    echo "OR ?"
    exit 0
fi

credits=$(curl -s -m 8 -H "Authorization: Bearer $key" https://openrouter.ai/api/v1/credits)
usage=$(curl -s -m 8 -H "Authorization: Bearer $key" https://openrouter.ai/api/v1/key)
export credits usage
python3 <<'PYEOF'
import os, json
try:
    c = json.loads(os.environ["credits"])["data"]
    k = json.loads(os.environ["usage"])["data"]
    bal = float(c["total_credits"]) - float(c["total_usage"])
    day, week, month = (float(k["usage_" + p]) for p in ("daily", "weekly", "monthly"))
    txt = f"OR ${bal:.2f}"
    if day > 0:
        runway = bal / day
        if runway < 1:
            txt = f"<span color='#ff5555'>{txt}</span>"
        elif runway < 3:
            txt = f"<span color='#f1fa8c'>{txt}</span>"
    print(f"{txt} d${day:.2f} w${week:.2f} m${month:.2f}")
except (KeyError, ValueError, TypeError, json.JSONDecodeError):
    print("OR !")
PYEOF
