#!/bin/sh
# Waybar module: one NAS storage row. Usage: nas-row.sh <n> [lines]
#
# These rows do NOT probe the NAS. `spark.sh nas` renders every row from its
# single SSH probe and writes them to /tmp/spark_nas.row<n>; here we only
# display one. Probing per row would multiply the SSH load on a box that
# already answers slowly under heavy pool IO.
#
# Rows: 2=BW 3=IOPS 4=LAT 7=UTIL 5=FILL/TEMP 8=congestion 6=compression/reconcile phase/fg-target
# 9=Optane + reconcile backlog, two lines: values, and their 1-minute deltas below
# (display order comes from the waybar config, not the numbers).
# Grouped by metric rather than by device, so an Optane figure can never be
# mistaken for the SSD one sitting next to it.
#
# lines=2 prints waybar JSON ("return-type": "json") with exactly two text lines
# (the second blank if the file has only one), so modules sharing a two-line bar
# keep their first lines level. Plain text output cannot do this: waybar reads a
# plain second line as the tooltip.
#
# Non-silent: a missing file, or one older than STALE seconds (the writer runs
# on the nas bar's 5s interval), is reported in red rather than shown as an
# innocent-looking stale line.

n=${1:?usage: nas-row.sh <row-number> [lines]}
lines=${2:-1}
f=/tmp/spark_nas.row$n
STALE=${NAS_ROW_STALE:-30}

if [ ! -r "$f" ]; then
    first="<span color='#ff5555'>row$n: no data from spark.sh nas</span>"
    second=" "
else
    age=$(( $(date +%s) - $(stat -c %Y "$f") ))
    first=$(sed -n 1p "$f")
    second=$(sed -n 2p "$f")
    [ -z "$first" ] && first="<span color='#ff5555'>row$n: empty</span>"
    if [ "$age" -gt "$STALE" ]; then
        first="$first <span color='#ff5555'>${age}s!</span>"
    fi
fi

if [ "$lines" -gt 1 ]; then
    [ -z "$second" ] && second=" "
    esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
    printf '{"text":"%s\\n%s"}\n' "$(esc "$first")" "$(esc "$second")"
else
    printf '%s\n' "$first"
fi
