#!/bin/sh
# Waybar module: impressions of tweets posted in the last 24h — the total
# so far, and the projection of what that cohort will have at one week of
# age ("IMP 532k→1.1M").
# The projection divides each post's latest snapshot by the share of its
# 7-day impressions expected at that age (accrual curve measured on 10.6k
# posts; see x_twitter/services/revenue_model.py and CLAUDE.md).
# Output: "IMP ?" on failure — visible, never a fake number.

cd /home/tom/git/x_twitter_production 2>/dev/null || { echo "IMP ?"; exit 0; }
PYTHONPATH=. .venv/bin/python -m x_twitter.services.revenue_model \
    --waybar-impressions 2>/dev/null || echo "IMP ?"
