#!/bin/bash
# Usage: spark.sh <hostname>
host=${1:-spark-1}
bar() { v=$1; [[ $v -lt 0 || $v -gt 100 ]] && v=0; printf '█%.0s' $(seq 1 $((v/10))); printf '░%.0s' $(seq 1 $((10-v/10))); }
fmt() { [[ $1 -gt 1048576 ]] && printf "%4dMB" $((($1+524288)/1048576)) || printf "%4dKB" $((($1+512)/1024)); }
cache="/tmp/spark_$host"

cmd='nvidia-smi --query-gpu=utilization.gpu,power.draw --format=csv,noheader,nounits
awk "/^cpu /{printf \"%.0f\n\",100-((\$5+\$6)*100/(\$2+\$3+\$4+\$5+\$6+\$7+\$8))}" /proc/stat
awk "/MemTotal/{t=\$2}/MemAvailable/{a=\$2}END{printf \"%.0f\n\",100-a*100/t}" /proc/meminfo
echo $(df / --output=pcent | tail -1 | tr -dc "0-9")
awk "/wl|en.*:/{gsub(/:/, \"\"); rx+=\$2; tx+=\$10} END{print rx, tx}" /proc/net/dev
zramctl -b --raw --noheadings -o DATA,COMPR /dev/zram0 2>/dev/null || echo "0 0"'

# Read cached data (validate 10 fields)
cached=$(cat "$cache" 2>/dev/null)
[[ $(echo "$cached" | wc -w) -eq 10 ]] && read -r g p c m d prx ptx pt zd zc <<< "$cached"
now=$(date +%s); pt=${pt:-$now}

# Fetch with timeout
if [[ "$host" == "$(hostname)" ]]; then data=$(eval "$cmd" 2>/dev/null)
else data=$(timeout 2 ssh -o ConnectTimeout=1 "$host" "$cmd" 2>/dev/null); fi

# Update cache on success, use cached on failure
if [[ -n "$data" ]]; then
  read -r g p c m d rx tx zd zc <<< "$(echo "$data" | tr ',\n' '  ')"
  p=${p%.*}; echo "$g $p $c $m $d $rx $tx $now $zd $zc" > "$cache"
  pt=$now; prx=${prx:-$rx}; ptx=${ptx:-$tx}
else rx=$prx; tx=$ptx; fi
[[ -z "$g" ]] && echo "$host offline" && exit
# Calculate age and network speed
dt=$((now - pt)); [[ $dt -lt 1 ]] && dt=1
age="${dt}s"; [[ $dt -gt 3 ]] && age="<span color='#ff5555'>${dt}s</span>"
rxs=$(( (rx - ${prx:-rx}) / dt )); txs=$(( (tx - ${ptx:-tx}) / dt ))
memv=$(printf "MEM%s%2d%%" "$(bar $m)" "$m"); [[ $m -gt 90 ]] && memv="<span color='#ff5555'>$memv</span>"
dskv=$(printf "DSK%s%2d%%" "$(bar $d)" "$d"); [[ $d -gt 90 ]] && dskv="<span color='#ff5555'>$dskv</span>"
zram=""; [[ $zc -gt 0 ]] && zram=$(echo "$zd $zc" | awk '{printf "Z%.1fG/%.1fx",$1/1073741824,$1/$2}')
printf "%s GPU%s%2d%% %3dW CPU%s%2d%% %s %s %s %s↓ %s↑ %s          \n" "$host" "$(bar $g)" "$g" "$p" "$(bar $c)" "$c" "$memv" "$zram" "$dskv" "$(fmt $rxs)" "$(fmt $txs)" "$age"
