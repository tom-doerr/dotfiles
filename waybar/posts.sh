#!/bin/bash
count=$(psql -d twitter -tAc "SELECT COUNT(*) FROM saved_posts WHERE status = 'saved';" 2>/dev/null)
count_rc=$?
last=$(psql -d twitter -tAc "SELECT EXTRACT(EPOCH FROM NOW() - posted_at)::int FROM saved_posts WHERE status = 'posted' ORDER BY posted_at DESC LIMIT 1;" 2>/dev/null)
last_rc=$?
if [[ $count_rc -ne 0 || $last_rc -ne 0 ]]; then
  echo "<span color='#ff5555'>PQ DB?   </span>"
  exit 0
fi
age="${last:-0}s"; [[ ${last:-0} -gt 1000 ]] && age="<span color='#ff5555'>$age</span>"
echo "PQ $count $age    "
