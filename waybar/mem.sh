#!/bin/bash
read -r total avail <<< $(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print t, a}' /proc/meminfo)
util=$((100 - (avail * 100 / total)))
filled=$((util / 10))
empty=$((10 - filled))
bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))$(printf '░%.0s' $(seq 1 $empty 2>/dev/null))
echo "spark-1 MEM ${bar} ${util}%"
