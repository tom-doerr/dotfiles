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
#   24h$   = TRUE rolling 24h, computed here (the API has no such window:
#            /api/v1/activity is UTC-day-grouped too and 403s without a management
#            key). Each run appends `epoch usage` — the cumulative per-key counter —
#            to ~/.local/state/waybar-openrouter/usage.tsv and differences against
#            the newest sample that is still >=24h old. Shows "24h—" until the
#            history is long enough (never a short-window figure passed off as a
#            full day) and red "24h!" if the state file cannot be written.

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
import os, json, time

STATE = os.path.expanduser("~/.local/state/waybar-openrouter/usage.tsv")
KEEP = 30 * 3600      # prune horizon: >24h so the reference sample survives gaps
WINDOW = 24 * 3600


def rolling(now, total):
    """Spend over the last 24h, by differencing our own samples of `usage`.

    Returns None until a sample at least WINDOW old exists. An incomplete window
    would silently under-report (looking like a quiet day rather than a short
    history), which is worse than showing nothing.
    """
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    rows = []
    if os.path.exists(STATE):
        with open(STATE) as fh:
            for line in fh:
                parts = line.split()
                if len(parts) == 2:
                    rows.append((float(parts[0]), float(parts[1])))
    rows.append((now, total))
    rows = [r for r in rows if now - r[0] <= KEEP]
    tmp = STATE + ".tmp"
    with open(tmp, "w") as fh:
        fh.writelines("%d %.6f\n" % r for r in rows)
    os.replace(tmp, STATE)
    # newest sample that is still at least 24h old = closest to exactly t-24h
    old = [r for r in rows if now - r[0] >= WINDOW]
    return total - max(old)[1] if old else None


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
    try:
        r24 = rolling(time.time(), float(k["usage"]))
        rtxt = "24h$%.2f" % r24 if r24 is not None else "24h—"
    except OSError:
        rtxt = "<span color='#ff5555'>24h!</span>"
    print(f"{txt} {rtxt} d${day:.2f} w${week:.2f} m${month:.2f}")
except (KeyError, ValueError, TypeError, json.JSONDecodeError):
    print("OR !")
PYEOF
