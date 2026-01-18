#!/bin/bash
count=$(psql -d twitter -tAc "SELECT COUNT(*) FROM saved_posts WHERE status = 'saved';" 2>/dev/null || echo 0)
last=$(psql -d twitter -tAc "SELECT EXTRACT(EPOCH FROM NOW() - posted_at)::int FROM saved_posts WHERE status = 'posted' ORDER BY posted_at DESC LIMIT 1;" 2>/dev/null)
age="${last:-0}s"; [[ ${last:-0} -gt 960 ]] && age="<span color='#ff5555'>$age</span>"
echo "PQ $count $age    "
