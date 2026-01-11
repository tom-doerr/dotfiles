#!/bin/bash
bar() { printf '█%.0s' $(seq 1 $(($1/10)) 2>/dev/null); printf '░%.0s' $(seq 1 $((10-$1/10)) 2>/dev/null); }
data=$(ssh -o ConnectTimeout=2 spark-2 '
nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits
awk "/^cpu /{printf \"%.0f\n\",100-(\$5*100/(\$2+\$3+\$4+\$5+\$6))}" /proc/stat
awk "/MemTotal/{t=\$2}/MemAvailable/{a=\$2}END{printf \"%.0f\n\",100-a*100/t}" /proc/meminfo
' 2>/dev/null)
[[ -z "$data" ]] && echo "spark-2 offline" && exit
read -r g c m <<< "$(echo "$data" | tr '\n' ' ')"
echo "spark-2 GPU$(bar $g)${g}% CPU$(bar $c)${c}% MEM$(bar $m)${m}%    "
