#!/bin/sh
# Waybar module: estimated X revenue — last 24h earned, and the payout
# now accruing (projected to period end).
# Model: x_twitter/services/revenue_model.py — impressions accrued in the
# window x $/impression from the last 2 payouts (counting window ends ~2d
# before the labeled period end; both facts measured, see CLAUDE.md).
# Output: "REV $215 NXT $1,735". "REV ? NXT ?" on failure (never a fake number).

cd /home/tom/git/x_twitter_production 2>/dev/null || { echo "REV ? NXT ?"; exit 0; }
PYTHONPATH=. .venv/bin/python -m x_twitter.services.revenue_model --waybar 2>/dev/null \
    || echo "REV ? NXT ?"
