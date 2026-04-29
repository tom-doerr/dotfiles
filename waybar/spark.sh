#!/bin/bash
# Usage: spark.sh <hostname>
host=${1:-spark-1}
bar() { v=$1; [[ $v -lt 0 || $v -gt 100 ]] && v=0; printf '█%.0s' $(seq 1 $((v/10))); printf '░%.0s' $(seq 1 $((10-v/10))); }
fmt() { [[ $1 -gt 1048576 ]] && printf "%4dMB" $((($1+524288)/1048576)) || printf "%4dKB" $((($1+512)/1024)); }
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
[[ -z "$g" ]] && echo "<span color='#ff5555'>$host OFFLINE</span>" && exit
# Calculate age - show failure state clearly
if [[ -z "$pt" ]]; then
  age="<span color='#ff5555'>FAIL</span>"; dt=1
else
  dt=$((now - pt)); [[ $dt -lt 1 ]] && dt=1
  if [[ $fetch_ok -eq 0 ]]; then
    age="<span color='#ff5555'>${dt}s!</span>"
  elif [[ $dt -gt 3 ]]; then
    age="<span color='#ff5555'>${dt}s</span>"
  else
    age="${dt}s"
  fi
fi
rxs=$(( (rx - ${prx:-rx}) / dt )); txs=$(( (tx - ${ptx:-tx}) / dt ))
memv=$(printf "MEM%s%2d%%" "$(bar $m)" "$m"); [[ $m -gt 90 ]] && memv="<span color='#ff5555'>$memv</span>"
dskv=$(printf "DSK%s%2d%%" "$(bar $d)" "$d"); [[ $d -gt 90 ]] && dskv="<span color='#ff5555'>$dskv</span>"
zram=""; [[ $zc -gt 0 ]] && zram=$(echo "$zd $zc" | awk '{printf "Z:%.1fG/%.1fx",$1/1073741824,$1/$2}')
zswap=""; if [[ "${zse:-N}" == "Y" || ${zs:-0} -gt 0 || ${zw:-0} -gt 0 ]]; then zswap=$(awk -v zs="${zs:-0}" -v zw="${zw:-0}" 'BEGIN{if(zw<=0&&zs<=0)printf "ZS:0";else if(zs>0)printf "ZS:%.1fG/%.1fx",zw/1048576,zw/zs;else printf "ZS:%.1fG",zw/1048576}'); fi
nvv=""; if [[ ${nv:-0} -gt 1024 ]]; then nvv=$(awk -v n="$nv" 'BEGIN{if(n>1048576)printf "NV:%.1fG",n/1048576;else printf "NV:%dM",n/1024}'); [[ ${nvs:-0} -gt 0 && $((nv * 2)) -gt $nvs ]] && nvv="<span color='#ff5555'>$nvv</span>"; fi
printf "%s GPU%s%2d%% %3dW CPU%s%2d%% %s %s %s %s %s %s↓ %s↑ %s          \n" "$host" "$(bar $g)" "$g" "$p" "$(bar $c)" "$c" "$memv" "$zram" "$zswap" "$nvv" "$dskv" "$(fmt $rxs)" "$(fmt $txs)" "$age"
