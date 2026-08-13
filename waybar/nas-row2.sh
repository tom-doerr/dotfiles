#!/bin/sh
# Waybar module: second NAS row (bcachefs storage detail).
#
# This module does NOT probe the NAS. `spark.sh nas` renders both rows from its
# single SSH probe and writes this one to /tmp/spark_nas.row2; here we only
# display it. Two probing modules would double the SSH load on a box that
# already answers slowly under heavy pool IO.
#
# Non-silent: a missing file, or one older than STALE seconds (the writer runs
# on the nas bar's 5s interval), is reported in red rather than shown as an
# innocent-looking stale line.

f=/tmp/spark_nas.row2
STALE=${NAS_ROW2_STALE:-30}

if [ ! -r "$f" ]; then
    echo "<span color='#ff5555'>bcachefs: no data from spark.sh nas</span>"
    exit 0
fi

age=$(( $(date +%s) - $(stat -c %Y "$f") ))
line=$(cat "$f")
[ -z "$line" ] && line="<span color='#ff5555'>bcachefs: empty</span>"
if [ "$age" -gt "$STALE" ]; then
    line="$line <span color='#ff5555'>${age}s!</span>"
fi
printf '%s\n' "$line"
