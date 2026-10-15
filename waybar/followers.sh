#!/bin/sh
# Waybar module: net new followers over the last 7 days, plus one bar per
# 24 h span ending now ("FOL +134 ▂▄▁▃▃▂█"). X reports only the follower
# count, so this is follows minus unfollows (profile_stats, 5-min snapshots).
# Model: x_twitter/services/follower_growth.py. A red "FOL ?" on failure or
# stale data — visible, never a fake number.

cd /home/tom/git/x_twitter_production 2>/dev/null || { echo '{"text":"<span color='"'"'#ff5555'"'"'>FOL ?</span>","tooltip":"x_twitter_production missing"}'; exit 0; }
PYTHONPATH=. .venv/bin/python -m x_twitter.services.follower_growth --waybar 2>/dev/null \
    || echo '{"text":"<span color='"'"'#ff5555'"'"'>FOL ?</span>","tooltip":"follower_growth failed"}'
