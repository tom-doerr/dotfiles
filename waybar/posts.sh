#!/bin/bash
count=$(psql -d twitter -tAc "SELECT COUNT(*) FROM saved_posts WHERE status = 'saved';" 2>/dev/null || echo 0)
echo "PQ $count    "
