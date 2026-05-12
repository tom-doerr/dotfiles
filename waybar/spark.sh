#!/bin/bash
# Usage: spark.sh <hostname>
host=${1:-spark-1}
bar() { v=$1; [[ $v -lt 0 || $v -gt 100 ]] && v=0; filled=$((v/10)); for ((i=0; i<filled; i++)); do printf '█'; done; for ((i=filled; i<10; i++)); do printf '░'; done; }
fmt() { [[ $1 -gt 1048576 ]] && printf "%4dMB" $((($1+524288)/1048576)) || printf "%4dKB" $((($1+512)/1024)); }
pad() { printf "%-${2}s" "$1"; }
red() { printf "<span color='#ff5555'>%s</span>" "$1"; }
cache="/tmp/spark_$host"

cmd='if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=utilization.gpu,power.draw --format=csv,noheader,nounits | head -1; else echo "-1 0"; fi
awk "/^cpu /{i=\$5+\$6; t=\$2+\$3+\$4+\$5+\$6+\$7+\$8; print i, t}" /proc/stat
awk "/MemTotal/{t=\$2}/MemAvailable/{a=\$2}END{printf \"%.0f\n\",100-a*100/t}" /proc/meminfo
disk=/; [ -d /volume1 ] && disk=/volume1; echo $(df "$disk" --output=pcent | tail -1 | tr -dc "0-9")
awk "/^[[:space:]]*(wl|en|eth|bond)/{gsub(/:/, \"\"); rx+=\$2; tx+=\$10} END{printf \"%.0f %.0f\n\", rx, tx}" /proc/net/dev
if command -v zramctl >/dev/null 2>&1; then
  zramctl -b --raw --noheadings -o DATA,COMPR 2>/dev/null | awk "{zd+=\$1; zc+=\$2} END{print zd+0, zc+0}"
else
  for f in /sys/block/zram*/mm_stat; do
    [ -r "$f" ] || continue
    read -r orig compr _ < "$f"
    zd=$((zd + orig))
    zc=$((zc + compr))
  done
  echo "${zd:-0} ${zc:-0}"
fi
cat /sys/module/zswap/parameters/enabled 2>/dev/null || echo N
awk "/Zswap:/{zs=\$2}/Zswapped:/{zw=\$2}END{print zs+0, zw+0}" /proc/meminfo
awk "NR>1 && \$1 !~ /^\\/dev\\/zram/ {if(\$2==\"partition\"){nvs+=\$3;nv+=\$4}else if(\$2==\"file\"){sfs+=\$3;sf+=\$4}} END{print nv+0, nvs+0, sf+0, sfs+0}" /proc/swaps 2>/dev/null'

# Read cached data (validate 20 fields: g p c m d rx tx pt zd zc zse zs zw nv nvs sf sfs ci ct _)
cached=$(cat "$cache" 2>/dev/null)
case $(echo "$cached" | wc -w) in
  20) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs pci pct _ <<< "$cached" ;;
  18) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs pci pct _ <<< "$cached"; sf=0; sfs=0 ;;
  17) read -r g p c m d prx ptx pt zd zc zse zs zw nv pci pct _ <<< "$cached"; nvs=0; sf=0; sfs=0 ;;
esac
now=$(date +%s); fetch_ok=0

# Fetch with timeout
ssh_timeout=2
connect_timeout=1
if [[ "$host" == "nas" ]]; then
  ssh_timeout=5
  connect_timeout=3
fi
if [[ "$host" == "$(hostname)" ]]; then data=$(eval "$cmd" 2>/dev/null)
else data=$(timeout "$ssh_timeout" ssh -o ConnectTimeout="$connect_timeout" "$host" "$cmd" 2>/dev/null); fi

# Update cache on success, use cached on failure
if [[ -n "$data" ]]; then
  read -r g p ci ct m d rx tx zd zc zse zs zw nv nvs sf sfs <<< "$(echo "$data" | tr ',\n' '  ')"
  p=${p%.*}; nv=${nv:-0}; nvs=${nvs:-0}; sf=${sf:-0}; sfs=${sfs:-0}
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
  echo "$g $p $c $m $d $rx $tx $now $zd $zc ${zse:-N} ${zs:-0} ${zw:-0} $nv $nvs $sf $sfs $ci $ct _" > "$cache"
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
[[ $rxs -lt 0 ]] && rxs=0
[[ $txs -lt 0 ]] && txs=0
gpuv=""; [[ ${g:-0} -ge 0 ]] && gpuv=$(printf "GPU%s%3d%% %3dW" "$(bar $g)" "$g" "$p")
cpuv=$(printf "CPU%s%3d%%" "$(bar $c)" "$c")
memv=$(pad "$(printf "MEM%s%3d%%" "$(bar $m)" "$m")" 17); [[ $m -gt 95 ]] && memv=$(red "$memv")
dskv=$(pad "$(printf "DSK%s%3d%%" "$(bar $d)" "$d")" 17); [[ $d -gt 90 ]] && dskv=$(red "$dskv")
zram=""; [[ $zc -gt 0 ]] && zram=$(echo "$zd $zc" | awk '{printf "%-15s", sprintf("Z:%.1fG/%.1fx",$1/1073741824,$1/$2)}')
zswap=""; if [[ "${zse:-N}" == "Y" || ${zs:-0} -gt 0 || ${zw:-0} -gt 0 ]]; then zswap=$(awk -v zs="${zs:-0}" -v zw="${zw:-0}" 'BEGIN{if(zw<=0&&zs<=0)v="ZS:0";else if(zs>0)v=sprintf("ZS:%.1fG/%.1fx",zw/1048576,zw/zs);else v=sprintf("ZS:%.1fG",zw/1048576); printf "%-16s", v}'); fi
nv=${nv:-0}; nvs=${nvs:-0}; sf=${sf:-0}; sfs=${sfs:-0}
if [[ "$host" == "nas" ]]; then
  shown_nv=$nv; shown_nvs=$nvs; shown_sf=$sf; shown_sfs=$sfs
else
  shown_nv=$((nv + sf)); shown_nvs=$((nvs + sfs)); shown_sf=0; shown_sfs=0
fi
nvv=""; if [[ ${shown_nv:-0} -gt 1024 ]]; then nvv=$(awk -v n="$shown_nv" 'BEGIN{if(n>1048576)v=sprintf("NV:%.1fG",n/1048576);else v=sprintf("NV:%dM",n/1024); printf "%-10s", v}'); [[ ${shown_nvs:-0} -gt 0 && $((shown_nv * 100)) -ge $((shown_nvs * 95)) ]] && nvv=$(red "$nvv"); fi
sfv=""; if [[ ${shown_sf:-0} -gt 1024 ]]; then sfv=$(awk -v n="$shown_sf" 'BEGIN{if(n>1048576)v=sprintf("SF:%.1fG",n/1048576);else v=sprintf("SF:%dM",n/1024); printf "%-10s", v}'); [[ ${shown_sfs:-0} -gt 0 && $((shown_sf * 100)) -ge $((shown_sfs * 95)) ]] && sfv=$(red "$sfv"); fi
swapv=""
[[ -n "$zram" ]] && swapv="$zram"
[[ -n "$zswap" ]] && swapv="${swapv:+$swapv }$zswap"
[[ -n "$nvv" ]] && swapv="${swapv:+$swapv }$nvv"
[[ -n "$sfv" ]] && swapv="${swapv:+$swapv }$sfv"
prefix="$host"
[[ -n "$gpuv" ]] && prefix="$prefix $gpuv"
line="$prefix $cpuv $memv"
[[ -n "$swapv" ]] && line="$line $swapv"
printf "%s %s %s↓ %s↑ %s\n" "$line" "$dskv" "$(fmt $rxs)" "$(fmt $txs)" "$age"
