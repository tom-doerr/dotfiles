#!/bin/sh
# Waybar module: sum of impressions on tweets posted in the last 24h (latest snapshot per post).
# Source: twitter DB post_analytics, deduped by post_id (newest fetched_at); local peer auth.
# Output: "IMP <humanized>" e.g. "IMP 541.5k". "IMP ?" on DB error (visible, not a silent fake).

sum=$(psql -d twitter -tAc "SELECT COALESCE(SUM(impressions),0) FROM (SELECT DISTINCT ON (post_id) impressions FROM post_analytics WHERE post_created_at >= NOW() - INTERVAL '24 hours' ORDER BY post_id, fetched_at DESC) t;" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$sum" ]; then
    echo "IMP ?"
    exit 0
fi
echo "$sum" | awk '{n=$1;
  if (n>=1000000) printf "IMP %.1fM\n", n/1000000;
  else if (n>=1000) printf "IMP %.1fk\n", n/1000;
  else printf "IMP %d\n", n}'
