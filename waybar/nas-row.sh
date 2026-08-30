#!/bin/sh
# Waybar module: one NAS storage row. Usage: nas-row.sh <n>
#
# These rows do NOT probe the NAS. `spark.sh nas` renders every row from its
# single SSH probe and writes them to /tmp/spark_nas.row<n>; here we only
# display one. Probing per row would multiply the SSH load on a box that
# already answers slowly under heavy pool IO.
#
# Rows (2026-08-31): 2=BW 3=IOPS 4=LAT 5=FILL/TEMP 6=compression/reconcile.
# Grouped by metric rather than by device, so an Optane figure can never be
# mistaken for the SSD one sitting next to it.
#
# Non-silent: a missing file, or one older than STALE seconds (the writer runs
# on the nas bar's 5s interval), is reported in red rather than shown as an
# innocent-looking stale line.

n=${1:?usage: nas-row.sh <row-number>}
f=/tmp/spark_nas.row$n
STALE=${NAS_ROW_STALE:-30}

if [ ! -r "$f" ]; then
    echo "<span color='#ff5555'>row$n: no data from spark.sh nas</span>"
    exit 0
fi

age=$(( $(date +%s) - $(stat -c %Y "$f") ))
line=$(cat "$f")
[ -z "$line" ] && line="<span color='#ff5555'>row$n: empty</span>"
if [ "$age" -gt "$STALE" ]; then
    line="$line <span color='#ff5555'>${age}s!</span>"
fi
printf '%s\n' "$line"
