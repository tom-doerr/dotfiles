#!/bin/bash
# Waybar: what the CURRENT QUOTA WINDOWS would cost at API list prices.
#
# The windows come from agent-usage (Claude's /api/oauth/usage + Codex's logged
# rate_limits), so each figure sits under the bar it belongs to: the Claude
# groups are summed since the weekly window opened (Fri 03:00 UTC), Codex since
# its own weekly window opened, and "5h" is the current Claude session window.
# Calendar days are deliberately NOT used -- nothing here resets at midnight, in
# any timezone, so a "today" figure would line up with nothing else on the row.
#
# Text: "CDX $1.2k+? CC $890 FBL $1.4k  5h $12".  Yellow "+?" = that group has
# requests whose model has no published price (Codex auto-review) -> floor, not total.
exec python3 - <<'PY'
import json
import subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path

DOTFILES = Path.home() / "git/dotfiles/scripts"
LABELS = [("codex", "CDX", "codex_week"), ("claude", "CC", "week"), ("claude_fable", "FBL", "week")]


def fail(msg):
    print(json.dumps({"text": "<span color='#ff5555'>spend ?</span>", "tooltip": msg}))
    raise SystemExit(0)


def run(args, timeout):
    out = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if out.returncode != 0:
        fail(f"{Path(args[0]).name} exit {out.returncode}: {(out.stderr or out.stdout).strip()[:300]}")
    return json.loads(out.stdout)


# Window starts, derived from the same limits the bars above are drawn from.
# Window STARTS only change at a reset, so an old cached payload is fine here;
# this must not add fetches to an endpoint that rate-limits.
usage = run([str(DOTFILES / "agent-usage"), "--max-age", "3600"], 60)
starts = {}
for entry in usage["entries"]:
    window, resets = entry.get("window_seconds"), entry.get("resets_at")
    if not window or resets is None:
        continue
    ends = (datetime.fromtimestamp(resets, timezone.utc) if isinstance(resets, (int, float))
            else datetime.fromisoformat(str(resets).replace("Z", "+00:00")))
    began = (ends - timedelta(seconds=window)).astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    key = ("codex_week" if entry["label"].startswith("CDX")
           else "session" if entry["label"].endswith("5h") else "week")
    starts.setdefault(key, began)
if "week" not in starts or "codex_week" not in starts:
    fail(f"missing quota windows: got {sorted(starts)}; " + "; ".join(usage.get("problems") or []))

groups = run(["nice", "-n", "10", str(DOTFILES / "agent-cost-report"), "--spans", json.dumps(starts)], 180)["groups"]


def usd(v):
    return f"${v / 1000:.1f}k" if v >= 1000 else f"${v:.0f}"


parts, tip = [], []
total = 0.0
for key, label, span in LABELS:
    cell = (groups.get(key) or {}).get(span) or {}
    total += cell.get("usd", 0.0)
    mark = "<span color='#f1fa8c'>+?</span>" if cell.get("unpriced_requests") else "  "
    parts.append(f"{label} {usd(cell.get('usd', 0.0)):>5}{mark}")
    tip.append(f"{label}: {usd(cell.get('usd', 0.0))} since its window opened "
               f"{starts[span].replace('T', ' ').replace('Z', ' UTC')}"
               + (f"  (+{cell['unpriced_requests']} unpriced requests)" if cell.get("unpriced_requests") else ""))
session = (groups.get("claude") or {}).get("session", {}).get("usd", 0.0) \
    + (groups.get("claude_fable") or {}).get("session", {}).get("usd", 0.0)
tip.append(f"\nCurrent 5h Claude session: {usd(session)}")
tip.append(f"All groups this quota week: {usd(total)}")
tip.append("Spans match the bars above (quota windows), not calendar days — nothing resets at midnight.")
tip.append("+? = model has no published price (Codex auto-review); figure is a floor.")
print(json.dumps({"text": "  ".join(parts) + f"  5h {usd(session):>5}", "tooltip": "\n".join(tip)}))
PY
