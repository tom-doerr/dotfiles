#!/bin/bash
# Usage: spark.sh <hostname>
host=${1:-spark-1}
script_dir=$(dirname "$(readlink -f "$0")")
if [[ "${SPARK_WAYBAR_INNER:-0}" != "1" ]]; then
  outer_timeout=4
  [[ "$host" == "nas" ]] && outer_timeout=8
  exec timeout --kill-after=1s "$outer_timeout" env SPARK_WAYBAR_INNER=1 "$0" "$@"
fi
bar() { v=$1; [[ $v -lt 0 || $v -gt 100 ]] && v=0; filled=$((v/10)); for ((i=0; i<filled; i++)); do printf '█'; done; for ((i=filled; i<10; i++)); do printf '░'; done; }
fmt() { [[ $1 -gt 1048576 ]] && printf "%4dMB" $((($1+524288)/1048576)) || printf "%4dKB" $((($1+512)/1024)); }
pad() { printf "%-${2}s" "$1"; }
hb() { awk -v b="${1:-0}" 'BEGIN{if(b<=0){print "0";exit} u="BKMGTP"; i=1; while(b>=1024&&i<6){b/=1024;i++} printf (b<10?"%.1f%s":"%.0f%s"), b, substr(u,i,1)}'; }
red() { printf "<span color='#ff5555'>%s</span>" "$1"; }
yellow() { printf "<span color='#f1fa8c'>%s</span>" "$1"; }
cache="/tmp/spark_$host"

cmd='if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=utilization.gpu,power.draw --format=csv,noheader,nounits | head -1; else echo "-1 0"; fi
awk "/^cpu /{i=\$5+\$6; t=\$2+\$3+\$4+\$5+\$6+\$7+\$8; print i, t}" /proc/stat
awk "/MemTotal/{t=\$2}/MemAvailable/{a=\$2}END{printf \"%.0f\n\",100-a*100/t}" /proc/meminfo
disk=/
if grep -q " /pool " /proc/mounts 2>/dev/null; then disk=/pool
elif grep -q " /volume1 " /proc/mounts 2>/dev/null; then disk=/volume1
elif [ -d /pool ] || [ -d /volume1 ]; then disk=""
fi
FU=""; [ "$disk" = /pool ] && [ -x ~/.local/bin/bcachefs ] && FU=$(~/.local/bin/bcachefs fs usage /pool 2>/dev/null)
if [ -n "$disk" ]; then ssdf=""; if [ -n "$FU" ]; then sv=$(printf "%s\n" "$FU" | awk "/^ssd/{for(i=1;i<=NF;i++)if(\$i~/%\$/){p=\$i;gsub(/%/,\"\",p);s+=p;n++}}END{if(n>0)printf \"%d\",s/n+0.5}"); [ -n "$sv" ] && ssdf="|$sv"; fi; echo "$(df "$disk" --output=pcent | tail -1 | tr -dc "0-9")|$(df -h "$disk" --output=used | tail -1 | tr -dc "0-9.TGMKP")${ssdf}"; else echo -1; fi
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
awk "NR>1 && \$1 !~ /^\\/dev\\/zram/ {if(\$2==\"partition\"){nvs+=\$3;nv+=\$4}else if(\$2==\"file\"){sfs+=\$3;sf+=\$4}} END{print nv+0, nvs+0, sf+0, sfs+0}" /proc/swaps 2>/dev/null
if [ -r /tmp/waybar-nvme-cache-dirty ]; then awk "NR==1{print \$1+0; exit}" /tmp/waybar-nvme-cache-dirty; else echo -1; fi
awk "/^full /{for(i=1;i<=NF;i++)if(\$i~/^avg60=/){v=\$i; sub(/^avg60=/,0,v); print v+0; found=1}}END{if(!found)print -1}" /proc/pressure/io 2>/dev/null
BASE=$(find /sys/fs/bcachefs -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)
CS="$BASE/compression_stats"; DU="$BASE/counters/data_update"; RC="$BASE/counters/reconcile_data"
TB="function tb(s,  n,u){n=s+0;u=substr(s,length(s),1);if(u==\"k\")n*=1024;else if(u==\"M\")n*=1048576;else if(u==\"G\")n*=1073741824;else if(u==\"T\")n*=1099511627776;return n}"
if [ -r "$CS" ]; then awk "$TB \$1==\"lz4\"||\$1==\"zstd\"{c+=tb(\$2);u+=tb(\$3)} END{if(u>c)print int((u-c)/1073741824);else print 0}" "$CS"; else echo -1; fi
DUV=0; for F in "$DU" "$RC"; do [ -r "$F" ] && DUV=$((DUV + $(awk "$TB /since mount:/{print int(tb(\$NF));f=1;exit} END{if(!f)print 0}" "$F"))); done; echo "$DUV"
if [ -r "$CS" ]; then awk "$TB \$1==\"lz4\"||\$1==\"zstd\"||\$1==\"incompressible\"{c+=tb(\$2);u+=tb(\$3)} END{if(c>0)print int(u*100/c);else print -1}" "$CS"; else echo -1; fi
if [ -n "$FU" ]; then printf "%s\n" "$FU" | awk "/^Pending reconcile:/{f=1;next} f&&NF<2{f=0} f{n=\$1;sub(/:\$/,\"\",n); if(n==\"replicas\")r=\$2; else if(n==\"compression\")c=\$2; else if(n==\"target\")t=\$2; else o+=\$2; m+=\$3} END{printf \"%d|%d|%d|%d|%d\n\",r,c,t,o,m}"; else echo -1; fi
sdevs=""; hdevs=""
for d in "$BASE"/dev-*; do l=$(cat "$d/label" 2>/dev/null); b=$(basename "$(readlink -f "$d/block" 2>/dev/null)" 2>/dev/null); case "$l" in ssd.*) sdevs="$sdevs $b";; hdd.*) hdevs="$hdevs $b";; esac; done
awk -v s="$sdevs" -v h="$hdevs" "BEGIN{n=split(s,S,\" \");for(i=1;i<=n;i++)ss[S[i]]=1;m=split(h,H,\" \");for(i=1;i<=m;i++)hh[H[i]]=1} {if(\$3 in ss){sr+=\$6;sw+=\$10}else if(\$3 in hh){hr+=\$6;hw+=\$10;hc+=\$8;ht+=\$11}} END{printf \"%d %d %d %d %d %d\n\",sr,sw,hr,hw,hc,ht}" /proc/diskstats
errs=0
for d in "$BASE"/dev-*; do e=$(awk "/IO errors since filesystem creation/{f=1;next} /IO errors since/{f=0;next} f&&/read:|write:|checksum:/{n=\$0;sub(/.*:/,\"\",n);gsub(/[^0-9]/,\"\",n);s+=n} END{print s+0}" "$d/io_errors" 2>/dev/null); errs=$((errs + ${e:-0})); done
echo "$errs"
if [ -r "$CS" ]; then awk "$TB \$1==\"lz4\"{l4=tb(\$3);l4c=tb(\$2)} \$1==\"zstd\"{zl=tb(\$3);zc=tb(\$2)} \$1==\"incompressible\"{il=tb(\$3)} END{printf \"%d %d %d %d %d\n\", l4/1073741824,(l4c>0?l4*100/l4c:0),zl/1073741824,(zc>0?zl*100/zc:0),il/1073741824}" "$CS"; else echo "0 0 0 0 0"; fi'

# Read cached data (validate 26 fields: g p c m d rx tx pt zd zc zse zs zw nv nvs sf sfs ncd iop md1u md2u md1t md2t ci ct _)
# NOTE: the 4 slots at positions 20-23 (once md1u/md2u/md1t/md2t) are repurposed on the NAS for bcachefs: bc_saved=compression saved GiB, bc_ssd=SSD fast-tier share %, bc_ratio=overall ratio x100, bc_backlog="Pending reconcile" bytes packed replicas|compression|target|other|metadata (was reconcile_scan_pending GiB, dropped Jul 8 as meaningless). md1/md2 RAID devices no longer exist post-reinstall.
cached=$(cat "$cache" 2>/dev/null)
case $(echo "$cached" | wc -w) in
  38) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs ncd iop bc_saved pdu bc_ratio bc_backlog pci pct psrd pswr phrd phwr phwc phwt errs lz4log lz4r zstdlog zstdr inclog _ <<< "$cached" ;;
  33) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs ncd iop bc_saved pdu bc_ratio bc_backlog pci pct psrd pswr phrd phwr phwc phwt errs _ <<< "$cached" ;;
  32) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs ncd iop bc_saved pdu bc_ratio bc_backlog pci pct psrd pswr phrd phwr phwc phwt _ <<< "$cached" ;;
  30) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs ncd iop bc_saved pdu bc_ratio bc_backlog pci pct psrd pswr phrd phwr _ <<< "$cached" ;;
  26) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs ncd iop bc_saved bc_ssd bc_ratio bc_backlog pci pct _ <<< "$cached" ;;
  22) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs ncd iop pci pct _ <<< "$cached" ;;
  21) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs ncd pci pct _ <<< "$cached"; iop=-1 ;;
  20) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs pci pct _ <<< "$cached"; ncd=-1; iop=-1 ;;
  18) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs pci pct _ <<< "$cached"; sf=0; sfs=0; ncd=-1; iop=-1 ;;
  17) read -r g p c m d prx ptx pt zd zc zse zs zw nv pci pct _ <<< "$cached"; nvs=0; sf=0; sfs=0; ncd=-1; iop=-1 ;;
esac
prev_rx=$prx; prev_tx=$ptx; prev_pt=$pt
rate_prx=$prx; rate_ptx=$ptx; rate_dt=1
now=$(date +%s); fetch_ok=0

# Fetch with timeout
ssh_timeout=2
connect_timeout=1
if [[ "$host" == "nas" ]]; then
  ssh_timeout=5
  connect_timeout=3
fi
ssh_opts=(
  -o BatchMode=yes
  -o ConnectTimeout="$connect_timeout"
  -o ConnectionAttempts=1
  # Reuse the SSH multiplexed master from ~/.ssh/config (do NOT force ControlPath=none,
  # do NOT set an aggressive ServerAlive keepalive). Under heavy NAS load, a fresh
  # TCP+handshake fails and a 1s keepalive (ServerAliveInterval=1/CountMax=1) drops the
  # connection after one missed ping, so the bar sat stale for 20+ min. A new channel on
  # the warm master is instant instead. Failure of a truly dead host is still bounded by
  # the `timeout --kill-after=1s $ssh_timeout` wrapper + ConnectTimeout.
  # Verified under codex's copy load: reuse + no keepalive = 8/8, vs 0/8 with either.
)
if [[ "$host" == "$(hostname)" ]]; then data=$(eval "$cmd" 2>/dev/null)
else data=$(timeout --kill-after=1s "$ssh_timeout" ssh "${ssh_opts[@]}" "$host" "$cmd" 2>/dev/null); fi

# Update cache on success, use cached on failure
if [[ -n "$data" ]]; then
  read -r g p ci ct m d rx tx zd zc zse zs zw nv nvs sf sfs ncd iop bc_saved du bc_ratio bc_backlog srd swr hrd hwr hwc hwt errs lz4log lz4r zstdlog zstdr inclog <<< "$(echo "$data" | tr ',\n' '  ')"
  p=${p%.*}; nv=${nv:-0}; nvs=${nvs:-0}; sf=${sf:-0}; sfs=${sfs:-0}; ncd=${ncd:--1}; iop=${iop:--1}
  bc_saved=${bc_saved:--1}; du=${du:-0}; bc_ratio=${bc_ratio:--1}; bc_backlog=${bc_backlog:--1}
  srd=${srd:-0}; swr=${swr:-0}; hrd=${hrd:-0}; hwr=${hwr:-0}; hwc=${hwc:-0}; hwt=${hwt:-0}; errs=${errs:-0}
  lz4log=${lz4log:-0}; lz4r=${lz4r:-0}; zstdlog=${zstdlog:-0}; zstdr=${zstdr:-0}; inclog=${inclog:-0}
  rate_prx=${prev_rx:-$rx}; rate_ptx=${prev_tx:-$tx}
  if [[ -n "$prev_pt" ]]; then
    rate_dt=$((now - prev_pt)); [[ $rate_dt -lt 1 ]] && rate_dt=1
  fi
  # bcachefs rates: destage (data_update delta) + per-tier throughput (diskstats sectors delta), MB/s
  dst=0; [[ -n "$pdu" && ${du:-0} -ge ${pdu:-0} ]] && dst=$(( (du - pdu) / rate_dt / 1048576 ))
  ssd_r=0; ssd_w=0; hdd_r=0; hdd_w=0
  [[ -n "$psrd" && ${srd:-0} -ge ${psrd:-0} ]] && ssd_r=$(( (srd - psrd) * 512 / rate_dt / 1048576 ))
  [[ -n "$pswr" && ${swr:-0} -ge ${pswr:-0} ]] && ssd_w=$(( (swr - pswr) * 512 / rate_dt / 1048576 ))
  [[ -n "$phrd" && ${hrd:-0} -ge ${phrd:-0} ]] && hdd_r=$(( (hrd - phrd) * 512 / rate_dt / 1048576 ))
  [[ -n "$phwr" && ${hwr:-0} -ge ${phwr:-0} ]] && hdd_w=$(( (hwr - phwr) * 512 / rate_dt / 1048576 ))
  hdd_wa=0; [[ -n "$phwc" && ${hwc:-0} -gt ${phwc:-0} ]] && hdd_wa=$(( (hwt - phwt) / (hwc - phwc) ))
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
  echo "$g $p $c $m $d $rx $tx $now $zd $zc ${zse:-N} ${zs:-0} ${zw:-0} $nv $nvs $sf $sfs ${ncd:--1} ${iop:--1} ${bc_saved:--1} ${du:-0} ${bc_ratio:--1} ${bc_backlog:--1} $ci $ct ${srd:-0} ${swr:-0} ${hrd:-0} ${hwr:-0} ${hwc:-0} ${hwt:-0} ${errs:-0} ${lz4log:-0} ${lz4r:-0} ${zstdlog:-0} ${zstdr:-0} ${inclog:-0} _" > "$cache"
  pt=$now; fetch_ok=1
else
  rx=$prx; tx=$ptx
  rate_prx=${prx:-$rx}; rate_ptx=${ptx:-$tx}
  if [[ -n "$pt" ]]; then
    rate_dt=$((now - pt)); [[ $rate_dt -lt 1 ]] && rate_dt=1
  fi
fi
wallv=""
if [[ "$host" =~ ^spark-[123]$ ]]; then
  if wall_sample=$("$script_dir/pdu-power.sh" "$host" 2>/dev/null); then
    read -r wall_power wall_state <<< "$wall_sample"
    if [[ "$wall_power" =~ ^[0-9]+$ && "$wall_state" == "fresh" ]]; then
      wallv=$(printf "AC:%3dW" "$wall_power")
    elif [[ "$wall_power" =~ ^[0-9]+$ && "$wall_state" == "stale" ]]; then
      wallv=$(yellow "$(printf "AC:%3dW~" "$wall_power")")
    else
      wallv=$(red "AC:---W")
    fi
  else
    wallv=$(red "AC:---W")
  fi
fi
cyclev=""
if [[ "$host" == "spark-2" || "$host" == "spark-3" ]]; then
  if cycle_count=$("$script_dir/spark-cycle-count.sh" "$host" 2>/dev/null) \
    && [[ "$cycle_count" =~ ^[0-9]+$ ]] && ((cycle_count > 0)); then
    cyclev=$(red "CYC:$cycle_count")
  fi
fi
[[ -z "$g" ]] && echo "$(red "$(pad "$host OFFLINE" 20)")${wallv:+ $wallv}${cyclev:+ $cyclev}" && exit
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
rxs=$(( (rx - ${rate_prx:-$rx}) / rate_dt )); txs=$(( (tx - ${rate_ptx:-$tx}) / rate_dt ))
[[ $rxs -lt 0 ]] && rxs=0
[[ $txs -lt 0 ]] && txs=0
gpuv=""; [[ ${g:-0} -ge 0 ]] && gpuv=$(printf "GPU%s%3d%% %3dW" "$(bar $g)" "$g" "$p")
cpuv=$(printf "CPU%s%3d%%" "$(bar $c)" "$c")
memv=$(pad "$(printf "MEM%s%3d%%" "$(bar $m)" "$m")" 17); [[ $m -gt 95 ]] && memv=$(red "$memv")
# d is "pct|used" (e.g. "9|8.0T"); bar shows pct, label shows used storage
dpct=${d%%|*}; drest=${d#*|}; [[ "$drest" == "$d" ]] && drest=""; dused=${drest%%|*}; dssd=${drest#*|}; [[ "$dssd" == "$drest" ]] && dssd=""
ssdv=""; [[ -n "$dssd" ]] && ssdv=$(printf "%-7s" "SSD:${dssd}%")
if [[ ${dpct:--1} -lt 0 ]]; then
  dskv=$(red "$(pad "DSK NO-POOL" 18)")
elif [[ -n "$dused" ]]; then
  dskv=$(pad "$(printf "DSK%s%5s" "$(bar $dpct)" "$dused")" 18); [[ $dpct -gt 90 ]] && dskv=$(red "$dskv")
else
  dskv=$(pad "$(printf "DSK%s%3d%%" "$(bar $dpct)" "$dpct")" 18); [[ $dpct -gt 90 ]] && dskv=$(red "$dskv")
fi
iopv=""; iop_pct=$(awk -v p="${iop:--1}" 'BEGIN{if(p<0)print -1; else printf "%d", p+0.5}')
if [[ $iop_pct -ge 0 ]]; then iopv=$(printf "%-7s" "IO:${iop_pct}%"); [[ $iop_pct -ge 20 ]] && iopv=$(red "$iopv"); fi
mdv=""
if [[ "$host" == "nas" && ${bc_saved:--1} -ge 0 ]]; then
  # bcachefs: overall CMP (saved/ratio) + per-algo logical+ratio (lz4=pending zstd / zstd=done / inc) + DST
  cmpsz=$(awk -v g="${bc_saved:-0}" 'BEGIN{if(g>=1024)printf "%.1fT",g/1024; else printf "%dG",g}')
  oratio=$(awk -v r="${bc_ratio:--1}" 'BEGIN{if(r<0)print "?"; else printf "%.2f", r/100}')
  cmpv=$(awk -v a="${lz4log:-0}" -v ar="${lz4r:-0}" -v b="${zstdlog:-0}" -v br="${zstdr:-0}" -v c="${inclog:-0}" 'BEGIN{printf "lz4 %4.1fT/%.2fx zstd %4.1fT/%.2fx inc %4.1fT", a/1024,ar/100,b/1024,br/100,c/1024}')
  mdv="CMP:${cmpsz}/${oratio}x $cmpv DST:${dst:-0}M"
fi
# RCL = bcachefs "Pending reconcile" backlog (bytes, data column) packed as
# replicas|compression|target|other|metadata. r=extra copies owed (3x build),
# c=recompress lz4->zstd, t=wrong target device (SSD->HDD destage).
rclv=""
if [[ "$host" == "nas" && "${bc_backlog:-}" == *"|"* ]]; then
  IFS='|' read -r rcr rcc rct rco rcm <<< "$bc_backlog"
  rclv=$(printf "RCL r%4s c%4s t%4s" "$(hb "$rcr")" "$(hb "$rcc")" "$(hb "$rct")")
  [[ $((${rco:-0} + ${rcm:-0})) -gt 0 ]] && rclv="$rclv$(yellow "+$(hb $((rco + rcm)))")"
elif [[ "$host" == "nas" && "${bc_backlog:-}" == "-1" ]]; then
  rclv=$(red "RCL:?")
fi
tputv=""
if [[ "$host" == "nas" && -n "$psrd" ]]; then
  tputv=$(printf "SSD %4d↓%4d↑MB HDD %4d↓%4d↑MB %4dms" "${ssd_w:-0}" "${ssd_r:-0}" "${hdd_w:-0}" "${hdd_r:-0}" "${hdd_wa:-0}")
fi
errv=""
[[ "$host" == "nas" && ${errs:-0} -gt 0 ]] && errv=$(red "$(printf "ERR:%d" "${errs:-0}")")
zram=""; [[ $zc -gt 0 ]] && zram=$(echo "$zd $zc" | awk '{printf "%-15s", sprintf("Z:%.1fG/%.1fx",$1/1073741824,$1/$2)}')
zswap=""; if [[ "${zse:-N}" == "Y" || ${zs:-0} -gt 0 || ${zw:-0} -gt 0 ]]; then zswap=$(awk -v zs="${zs:-0}" -v zw="${zw:-0}" 'BEGIN{if(zw<=0&&zs<=0)v="ZS:0";else if(zs>0)v=sprintf("ZS:%.1fG/%.1fx",zw/1048576,zw/zs);else v=sprintf("ZS:%.1fG",zw/1048576); printf "%-13s", v}'); fi
nv=${nv:-0}; nvs=${nvs:-0}; sf=${sf:-0}; sfs=${sfs:-0}
if [[ "$host" == "nas" ]]; then
  shown_nv=$nv; shown_nvs=$nvs; shown_sf=$sf; shown_sfs=$sfs
else
  shown_nv=$((nv + sf)); shown_nvs=$((nvs + sfs)); shown_sf=0; shown_sfs=0
fi
nvv=""; if [[ ${shown_nv:-0} -gt 1024 ]]; then nvv=$(awk -v n="$shown_nv" 'BEGIN{if(n>1048576)v=sprintf("NV:%.1fG",n/1048576);else v=sprintf("NV:%dM",n/1024); printf "%-9s", v}'); [[ ${shown_nvs:-0} -gt 0 && $((shown_nv * 100)) -ge $((shown_nvs * 95)) ]] && nvv=$(red "$nvv"); fi
sfv=""; if [[ ${shown_sf:-0} -gt 1024 ]]; then sfv=$(awk -v n="$shown_sf" 'BEGIN{if(n>1048576)v=sprintf("SF:%.1fG",n/1048576);else v=sprintf("SF:%dM",n/1024); printf "%-10s", v}'); [[ ${shown_sfs:-0} -gt 0 && $((shown_sf * 100)) -ge $((shown_sfs * 95)) ]] && sfv=$(red "$sfv"); fi
ncdv=""; ncd_text=$(awk -v p="${ncd:--1}" 'BEGIN{if(p<0)print ""; else printf "%.2f", p}')
ncd_red=$(awk -v p="${ncd:--1}" 'BEGIN{if(p>=95)print 1; else print 0}')
if [[ "$host" == "nas" && -n "$ncd_text" ]]; then ncdv=$(printf "%-11s" "NVD:${ncd_text}%"); [[ $ncd_red -eq 1 ]] && ncdv=$(red "$ncdv"); fi
swapv=""
[[ -n "$zram" ]] && swapv="$zram"
[[ -n "$zswap" ]] && swapv="${swapv:+$swapv }$zswap"
[[ -n "$nvv" ]] && swapv="${swapv:+$swapv }$nvv"
[[ -n "$sfv" ]] && swapv="${swapv:+$swapv }$sfv"
[[ -n "$ncdv" ]] && swapv="${swapv:+$swapv }$ncdv"
# The NAS carries far more than a spark (bcachefs compression, reconcile backlog,
# per-tier throughput) and outgrew one 1728px row. Split it: the storage groups go
# to a SECOND bar, rendered here and handed to `custom/nas2` via this file, so the
# NAS is still probed ONCE per cycle rather than twice.
if [[ "$host" == "nas" ]]; then
  row2=""
  for v in "$mdv" "$rclv" "$errv" "$tputv"; do [[ -n "$v" ]] && row2="${row2:+$row2 }$v"; done
  printf '%s\n' "$row2" > "$cache.row2"
  mdv=""; rclv=""; errv=""; tputv=""
fi
prefix="$host"
[[ -n "$gpuv" ]] && prefix="$prefix $gpuv"
[[ -n "$wallv" ]] && prefix="$prefix $wallv"
[[ -n "$cyclev" ]] && prefix="$prefix $cyclev"
line="$prefix $cpuv $memv"
[[ -n "$iopv" ]] && line="$line $iopv"
[[ -n "$mdv" ]] && line="$line $mdv"
[[ -n "$rclv" ]] && line="$line $rclv"
[[ -n "$errv" ]] && line="$line $errv"
[[ -n "$tputv" ]] && line="$line $tputv"
[[ -n "$swapv" ]] && line="$line $swapv"
[[ -n "$ssdv" ]] && line="$line $ssdv"
printf "%s %s %s↓ %s↑ %s\n" "$line" "$dskv" "$(fmt $rxs)" "$(fmt $txs)" "$age"
