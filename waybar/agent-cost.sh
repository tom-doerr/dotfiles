#!/bin/bash
# Waybar: what today's Codex / Claude Code / Claude Code (Fable) usage would
# cost at API list prices -- see scripts/agent-cost-report.  Nothing is billed
# to an API account; these are list-price equivalents of subscription usage.
#
# Text: "CDX   $78  CC  $117  FBL  $181  30d $9.9k", fixed-width so the numbers
# do not shift columns as they grow.  A yellow "+?" after a figure means that
# group has requests whose model has no published price (Codex's auto-review),
# so the number is a floor, not a total.  Tooltip carries 7d / 30d / all-time.
#
# Cost is read from the report's own file cache, so a run is ~0.2 s when no
# transcript changed and a few seconds when an active session file grew.
exec python3 - <<'PY'
import json
import subprocess
from pathlib import Path

REPORT = Path.home() / "git/dotfiles/scripts/agent-cost-report"
LABELS = [("codex", "CDX"), ("claude", "CC"), ("claude_fable", "FBL")]


def fail(msg):
    print(json.dumps({"text": "<span color='#ff5555'>agents ?</span>", "tooltip": msg}))
    raise SystemExit(0)


try:
    out = subprocess.run(
        ["nice", "-n", "10", str(REPORT), "--windows"],
        capture_output=True, text=True, timeout=180,
    )
except (OSError, subprocess.TimeoutExpired) as err:
    fail(f"agent-cost-report: {err}")
if out.returncode != 0:
    fail(f"agent-cost-report exit {out.returncode}: {out.stderr.strip()[:300]}")
try:
    groups = json.loads(out.stdout)["groups"]
except (ValueError, KeyError) as err:
    fail(f"unparseable report output: {err}")


def usd(v):
    """Compact and fixed-width: $1.2k / $181 / $0."""
    return f"${v / 1000:.1f}k" if v >= 1000 else f"${v:.0f}"


parts, tip = [], []
day_total = 0.0
for key, label in LABELS:
    w = groups.get(key) or {}
    today = (w.get("today") or {}).get("usd", 0.0)
    day_total += today
    mark = "<span color='#f1fa8c'>+?</span>" if (w.get("today") or {}).get("unpriced_requests") else "  "
    d30 = (w.get("d30") or {}).get("usd", 0.0)
    # bright = today, dim = trailing 30 days, so the row carries rate and recent total
    parts.append(f"{label} {usd(today):>5}{mark} <span color='#6272a4'>{usd(d30):>5}</span>")
    tip.append(
        f"{label}: today {usd(today)}  7d {usd((w.get('d7') or {}).get('usd', 0))}"
        f"  30d {usd((w.get('d30') or {}).get('usd', 0))}  all {usd((w.get('all') or {}).get('usd', 0))}"
        + (f"  (+{(w.get('all') or {}).get('unpriced_requests', 0)} unpriced requests)"
           if (w.get("all") or {}).get("unpriced_requests") else "")
    )
month = sum((groups.get(k) or {}).get("d30", {}).get("usd", 0.0) for k, _ in LABELS)
tip.append(f"\nday total {usd(day_total)}, 30d {usd(month)} at API list prices (UTC days)")
tip.append("+? = model has no published price (Codex auto-review); figure is a floor")
print(json.dumps({"text": "  ".join(parts) + f"  30d {usd(month):>5}", "tooltip": "\n".join(tip)}))
PY
