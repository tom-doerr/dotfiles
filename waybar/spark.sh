#!/bin/bash
# Usage: spark.sh <hostname>
host=${1:-spark-1}
bar() { printf '█%.0s' $(seq 1 $(($1/10)) 2>/dev/null); printf '░%.0s' $(seq 1 $((10-$1/10)) 2>/dev/null); }

cmd='nvidia-smi --query-gpu=utilization.gpu,power.draw --format=csv,noheader,nounits
awk "/^cpu /{printf \"%.0f\n\",100-((\$5+\$6)*100/(\$2+\$3+\$4+\$5+\$6+\$7+\$8))}" /proc/stat
awk "/MemTotal/{t=\$2}/MemAvailable/{a=\$2}END{printf \"%.0f\n\",100-a*100/t}" /proc/meminfo
df / --output=pcent | tail -1 | tr -dc "0-9"'

if [[ "$host" == "$(hostname)" ]]; then data=$(eval "$cmd" 2>/dev/null)
else data=$(ssh -o ConnectTimeout=2 "$host" "$cmd" 2>/dev/null); fi

[[ -z "$data" ]] && echo "$host offline" && exit
read -r g p c m d <<< "$(echo "$data" | tr ',\n' '  ')"
p=${p%.*}
dsk="DSK$(bar $d)${d}%"; [[ $d -gt 90 ]] && dsk="<span color='#ff5555'>$dsk</span>"
echo "$host GPU$(bar $g)${g}% ${p}W CPU$(bar $c)${c}% MEM$(bar $m)${m}% $dsk          "
