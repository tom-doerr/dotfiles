#!/bin/bash
data=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null)
util=$(echo "$data" | cut -d',' -f1 | tr -d ' ')
temp=$(echo "$data" | cut -d',' -f2 | tr -d ' ')
watts=$(echo "$data" | cut -d',' -f3 | tr -d ' ' | cut -d'.' -f1)
filled=$((util / 10))
empty=$((10 - filled))
bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))$(printf '░%.0s' $(seq 1 $empty 2>/dev/null))
echo "spark-1 GPU ${bar} ${util}% ${temp}°C ${watts}W"
