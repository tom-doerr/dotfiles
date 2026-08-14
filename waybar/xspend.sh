#!/bin/sh
# Waybar module: estimated X (Twitter) API spend this billing cycle.
# Output: "X $157 d$5 r7k/3M" = cycle-to-date, today, Post reads vs the 3M cap.
#
# SPEND, not balance: X has no credits/billing endpoint (unlike OpenRouter's
# /api/v1/credits or Vast's /users/current), so nothing here is a real
# statement figure. Both counts are measured -- reads from GET /2/usage/tweets,
# writes from our own posted_posts -- then priced at published pay-per-use
# rates ($0.005/read, $0.20/post-with-URL). Override via X_USD_PER_* env vars
# after checking the Developer Console.
#
# Writes dominate and are absent from the usage endpoint entirely, so a module
# built on the API alone would under-report by ~4x.
#
# Set X_SPEND_CAP to your Developer Console cap to get colour: yellow at 70%,
# red at 90%. That cap 403s every write when hit (it stopped posting for 6h on
# 2026-07-03); the 3M read cap is never close.
# "X ?" = module unavailable (never a fake $0).

cd /home/tom/git/x_twitter_production 2>/dev/null || {
    echo '{"text":"X ?","tooltip":"api_spend unavailable"}'; exit 0; }
set -a
[ -r .env ] && . ./.env
set +a
PYTHONPATH=. .venv/bin/python -m x_twitter.services.api_spend --waybar 2>/dev/null \
    || echo '{"text":"X ?","tooltip":"api_spend failed"}'
