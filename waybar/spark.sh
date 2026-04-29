#!/bin/bash
# Usage: spark.sh <hostname>
host=${1:-spark-1}
bar() { v=$1; [[ $v -lt 0 || $v -gt 100 ]] && v=0; filled=$((v/10)); for ((i=0; i<filled; i++)); do printf '█'; done; for ((i=filled; i<10; i++)); do printf '░'; done; }
fmt() { [[ $1 -gt 1048576 ]] && printf "%4dMB" $((($1+524288)/1048576)) || printf "%4dKB" $((($1+512)/1024)); }
pad() { printf "%-${2}s" "$1"; }
red() { printf "<span color='#ff5555'>%s</span>" "$1"; }
cache="/tmp/spark_$host"

cmd='nvidia-smi --query-gpu=utilization.gpu,power.draw --format=csv,noheader,nounits
awk "/^cpu /{i=\$5+\$6; t=\$2+\$3+\$4+\$5+\$6+\$7+\$8; print i, t}" /proc/stat
awk "/MemTotal/{t=\$2}/MemAvailable/{a=\$2}END{printf \"%.0f\n\",100-a*100/t}" /proc/meminfo
echo $(df / --output=pcent | tail -1 | tr -dc "0-9")
awk "/wl|en.*:/{gsub(/:/, \"\"); rx+=\$2; tx+=\$10} END{print rx, tx}" /proc/net/dev
zramctl -b --raw --noheadings -o DATA,COMPR /dev/zram0 2>/dev/null || echo "0 0"
cat /sys/module/zswap/parameters/enabled 2>/dev/null || echo N
awk "/Zswap:/{zs=\$2}/Zswapped:/{zw=\$2}END{print zs+0, zw+0}" /proc/meminfo
awk "BEGIN{s=0;v=0}/swap.img/{s=\$3;v=\$4}END{print v, s}" /proc/swaps 2>/dev/null'

# Read cached data (validate 18 fields: g p c m d rx tx pt zd zc zse zs zw nv nvs ci ct _)
cached=$(cat "$cache" 2>/dev/null)
case $(echo "$cached" | wc -w) in
  18) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs pci pct _ <<< "$cached" ;;
  17) read -r g p c m d prx ptx pt zd zc zse zs zw nv pci pct _ <<< "$cached"; nvs=0 ;;
esac
now=$(date +%s); fetch_ok=0

# Fetch with timeout
if [[ "$host" == "$(hostname)" ]]; then data=$(eval "$cmd" 2>/dev/null)
else data=$(timeout 2 ssh -o ConnectTimeout=1 "$host" "$cmd" 2>/dev/null); fi

# Update cache on success, use cached on failure
if [[ -n "$data" ]]; then
  read -r g p ci ct m d rx tx zd zc zse zs zw nv nvs <<< "$(echo "$data" | tr ',\n' '  ')"
  p=${p%.*}; nv=${nv:-0}; nvs=${nvs:-0}
  # CPU % from jiffies delta (with sanity checks)
  if [[ -n "$pci" && -n "$pct" && $ci -ge $pci && $ct -gt $pct ]]; then
    di=$((ci - pci)); dtc=$((ct - pct))
    # dtc ~100-1000 for 1s (100Hz * cores). >100k = stale cache, keep old c
    if [[ $dtc -gt 0 && $dtc -lt 100000 ]]; then
      c=$((100 - di * 100 / dtc))
      [[ $c -lt 0 ]] && c=0; [[ $c -gt 100 ]] && c=100
    fi
  fi
  : ${c:=0}
  echo "$g $p $c $m $d $rx $tx $now $zd $zc ${zse:-N} ${zs:-0} ${zw:-0} $nv $nvs $ci $ct _" > "$cache"
  pt=$now; prx=${prx:-$rx}; ptx=${ptx:-$tx}; fetch_ok=1
else rx=$prx; tx=$ptx; fi
[[ -z "$g" ]] && echo "$(red "$(pad "$host OFFLINE" 150)")" && exit
# Calculate age - show failure state clearly
if [[ -z "$pt" ]]; then
  age=$(red "$(pad "FAIL" 5)"); dt=1
else
  dt=$((now - pt)); [[ $dt -lt 1 ]] && dt=1
  if [[ $fetch_ok -eq 0 ]]; then
    age=$(red "$(printf "%5s" "${dt}s!")")
  elif [[ $dt -gt 3 ]]; then
    age=$(red "$(printf "%5s" "${dt}s")")
  else
    age=$(printf "%5s" "${dt}s")
  fi
fi
rxs=$(( (rx - ${prx:-rx}) / dt )); txs=$(( (tx - ${ptx:-tx}) / dt ))
gpuv=$(printf "GPU%s%3d%% %3dW" "$(bar $g)" "$g" "$p")
cpuv=$(printf "CPU%s%3d%%" "$(bar $c)" "$c")
memv=$(pad "$(printf "MEM%s%3d%%" "$(bar $m)" "$m")" 17); [[ $m -gt 90 ]] && memv=$(red "$memv")
dskv=$(pad "$(printf "DSK%s%3d%%" "$(bar $d)" "$d")" 17); [[ $d -gt 90 ]] && dskv=$(red "$dskv")
zram=$(pad "Z:0" 15); [[ $zc -gt 0 ]] && zram=$(echo "$zd $zc" | awk '{printf "%-15s", sprintf("Z:%.1fG/%.1fx",$1/1073741824,$1/$2)}')
zswap=""; if [[ "${zse:-N}" == "Y" || ${zs:-0} -gt 0 || ${zw:-0} -gt 0 ]]; then zswap=$(awk -v zs="${zs:-0}" -v zw="${zw:-0}" 'BEGIN{if(zw<=0&&zs<=0)v="ZS:0";else if(zs>0)v=sprintf("ZS:%.1fG/%.1fx",zw/1048576,zw/zs);else v=sprintf("ZS:%.1fG",zw/1048576); printf "%-16s", v}'); fi
nvv=""; if [[ ${nv:-0} -gt 1024 ]]; then nvv=$(awk -v n="$nv" 'BEGIN{if(n>1048576)v=sprintf("NV:%.1fG",n/1048576);else v=sprintf("NV:%dM",n/1024); printf "%-10s", v}'); [[ ${nvs:-0} -gt 0 && $((nv * 2)) -gt $nvs ]] && nvv=$(red "$nvv"); fi
swapv="$zram"
[[ -n "$zswap" ]] && swapv="$swapv $zswap"
[[ -n "$nvv" ]] && swapv="$swapv $nvv"
printf "%s %s %s %s %s %s %s↓ %s↑ %s\n" "$host" "$gpuv" "$cpuv" "$memv" "$swapv" "$dskv" "$(fmt $rxs)" "$(fmt $txs)" "$age"
