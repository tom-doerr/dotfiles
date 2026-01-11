#!/bin/bash
bar() { printf '█%.0s' $(seq 1 $(($1/10)) 2>/dev/null); printf '░%.0s' $(seq 1 $((10-$1/10)) 2>/dev/null); }
g=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
read -r total avail <<< $(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print t,a}' /proc/meminfo)
m=$((100 - avail * 100 / total))
c=$(awk '/^cpu /{printf "%.0f",100-($5*100/($2+$3+$4+$5+$6))}' /proc/stat)
echo "spark-1 GPU$(bar $g)${g}% CPU$(bar $c)${c}% MEM$(bar $m)${m}%    "
