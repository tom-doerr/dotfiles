#!/bin/bash
data=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
util=$(echo "$data" | cut -d',' -f1 | tr -d ' ')
temp=$(echo "$data" | cut -d',' -f2 | tr -d ' ')
echo "GPU ${util}% ${temp}°C"
