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
if [ -n "$FU" ]; then printf "%s\n" "$FU" | awk "/^Pending reconcile:/{f=1;next} f&&NF<2{f=0} f{n=\$1;sub(/:\$/,\"\",n); if(n==\"replicas\")r=\$2; else if(n==\"erasure_code\")e=\$2; else if(n==\"high_priority\"){} else if(n==\"compression\")c=\$2; else if(n==\"target\")t=\$2; else o+=\$2; m+=\$3} END{printf \"%d|%d|%d|%d|%d|%d\n\",r,e,c,t,o,m}"; else echo -1; fi
sdevs=""; hdevs=""
for d in "$BASE"/dev-*; do l=$(cat "$d/label" 2>/dev/null); b=$(basename "$(readlink -f "$d/block" 2>/dev/null)" 2>/dev/null); case "$l" in ssd.*) sdevs="$sdevs $b";; hdd.*) hdevs="$hdevs $b";; esac; done
awk -v s="$sdevs" -v h="$hdevs" "BEGIN{n=split(s,S,\" \");for(i=1;i<=n;i++)ss[S[i]]=1;m=split(h,H,\" \");for(i=1;i<=m;i++)hh[H[i]]=1} {if(\$3 in ss){sr+=\$6;sw+=\$10}else if(\$3 in hh){hr+=\$6;hw+=\$10;hc+=\$8;ht+=\$11}} END{printf \"%d %d %d %d %d %d\n\",sr,sw,hr,hw,hc,ht}" /proc/diskstats
errs=0
for d in "$BASE"/dev-*; do e=$(awk "/IO errors since filesystem creation/{f=1;next} /IO errors since/{f=0;next} f&&/read:|write:|checksum:/{n=\$0;sub(/.*:/,\"\",n);gsub(/[^0-9]/,\"\",n);s+=n} END{print s+0}" "$d/io_errors" 2>/dev/null); errs=$((errs + ${e:-0})); done
echo "$errs"
if [ -r "$CS" ]; then awk "$TB \$1==\"lz4\"{l4=tb(\$3);l4c=tb(\$2)} \$1==\"zstd\"{zl=tb(\$3);zc=tb(\$2)} \$1==\"incompressible\"{il=tb(\$3)} END{printf \"%d %d %d %d %d\n\", l4/1073741824,(l4c>0?l4*100/l4c:0),zl/1073741824,(zc>0?zl*100/zc:0),il/1073741824}" "$CS"; else echo "0 0 0 0 0"; fi
CGV=""; for d in "$BASE"/dev-*; do l=$(cat "$d/label" 2>/dev/null); case "$l" in ssd.*) ;; *) continue;; esac; cg=$(awk "/^current:/{gsub(/%/,\"\"); print \$2; exit}" "$d/congested" 2>/dev/null); mr=$(awk "/median read latency:/{v=\$4; if(\$5==\"ms\")v*=1000; if(\$5==\"s\")v*=1000000; printf \"%d\", v; exit}" "$d/congested" 2>/dev/null); CGV="$CGV|${l##*.}:${cg:--1}:${mr:--1}"; done
if [ -n "$CGV" ]; then echo "${CGV#|}"; else echo -1; fi
DV=""; for d in "$BASE"/dev-*; do l=$(cat "$d/label" 2>/dev/null); [ -z "$l" ] && continue; b=$(basename "$(readlink -f "$d/block" 2>/dev/null)" 2>/dev/null); [ -z "$b" ] && continue; st=$(awk -v n="$b" "\$3==n{printf \"%d:%d:%d:%d:%d\", \$4,\$8,\$6,\$10,\$13; f=1; exit} END{if(!f)printf \"0:0:0:0:0\"}" /proc/diskstats); up=$(printf "%s\n" "$FU" | awk -v L="$l" "\$1==L{for(i=1;i<=NF;i++)if(\$i~/%\$/){q=\$i;gsub(/%/,\"\",q);print q;exit}}"); mr=$(awk "/median read latency:/{v=\$4; if(\$5==\"ms\")v*=1000; if(\$5==\"s\")v*=1000000; printf \"%d\", v; exit} END{}" "$d/congested" 2>/dev/null); pb=${b%p[0-9]*}; tp=$(cat /sys/block/$pb/device/hwmon*/temp1_input /sys/block/$pb/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); DV="$DV|$l:$st:${up:-0}:${mr:--1}:${tp:--1}"; done; if [ -n "$DV" ]; then echo "${DV#|}"; else echo -1; fi
OB=""; for d in "$BASE"/dev-*; do case "$(cat "$d/label" 2>/dev/null)" in *optane*) OB="$d";; esac; done; if [ -n "$OB" ] && [ -n "$FU" ]; then ou=$(printf "%s\n" "$FU" | awk "/optane/{print \$7; exit}"); os=$(printf "%s\n" "$FU" | awk "/optane/{print \$6; exit}"); ob=$(basename "$(readlink -f "$OB/block" 2>/dev/null)" 2>/dev/null); pn=${ob%p[0-9]*}; ot=$(cat /sys/block/$pn/device/hwmon*/temp1_input 2>/dev/null | head -1); fg=$(cat "$BASE/options/foreground_target" 2>/dev/null); oc=$(awk "/^cached/{print \$2; exit}" "$OB/alloc_debug" 2>/dev/null); obs=$(cat "$OB/bucket_size" 2>/dev/null | awk "{v=\$1+0; u=substr(\$1,length(\$1)); if(u==\"k\")v*=1024; else if(u==\"M\")v*=1048576; else if(u==\"G\")v*=1073741824; printf \"%d\", v}"); echo "${ou:-0}|${os:-0}|${ot:-0}|${fg:-?}|$(( ${oc:-0} * ${obs:-0} ))"; else echo -1; fi
PR="$BASE/counters/data_read_promote"; if [ -r "$PR" ]; then awk "$TB /since mount:/{print int(tb(\$NF)); f=1; exit} END{if(!f)print 0}" "$PR"; else echo 0; fi'

# Read cached data (validate 26 fields: g p c m d rx tx pt zd zc zse zs zw nv nvs sf sfs ncd iop md1u md2u md1t md2t ci ct _)
# NOTE: the 4 slots at positions 20-23 (once md1u/md2u/md1t/md2t) are repurposed on the NAS for bcachefs: bc_saved=compression saved GiB, bc_ssd=SSD fast-tier share %, bc_ratio=overall ratio x100, bc_backlog="Pending reconcile" bytes packed replicas|compression|target|other|metadata (was reconcile_scan_pending GiB, dropped Jul 8 as meaningless). md1/md2 RAID devices no longer exist post-reinstall.
cached=$(cat "$cache" 2>/dev/null)
case $(echo "$cached" | wc -w) in
  42) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs ncd iop bc_saved pdu bc_ratio bc_backlog pci pct psrd pswr phrd phwr phwc phwt errs lz4log lz4r zstdlog zstdr inclog cgv pdevs optv pprom _ <<< "$cached" ;;
  41) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs ncd iop bc_saved pdu bc_ratio bc_backlog pci pct psrd pswr phrd phwr phwc phwt errs lz4log lz4r zstdlog zstdr inclog cgv pdevs optv _ <<< "$cached" ;;
  39) read -r g p c m d prx ptx pt zd zc zse zs zw nv nvs sf sfs ncd iop bc_saved pdu bc_ratio bc_backlog pci pct psrd pswr phrd phwr phwc phwt errs lz4log lz4r zstdlog zstdr inclog cgv _ <<< "$cached" ;;
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
  read -r g p ci ct m d rx tx zd zc zse zs zw nv nvs sf sfs ncd iop bc_saved du bc_ratio bc_backlog srd swr hrd hwr hwc hwt errs lz4log lz4r zstdlog zstdr inclog cgv devs optv promv <<< "$(echo "$data" | tr ',\n' '  ')"
  p=${p%.*}; nv=${nv:-0}; nvs=${nvs:-0}; sf=${sf:-0}; sfs=${sfs:-0}; ncd=${ncd:--1}; iop=${iop:--1}
  bc_saved=${bc_saved:--1}; du=${du:-0}; bc_ratio=${bc_ratio:--1}; bc_backlog=${bc_backlog:--1}
  srd=${srd:-0}; swr=${swr:-0}; hrd=${hrd:-0}; hwr=${hwr:-0}; hwc=${hwc:-0}; hwt=${hwt:-0}; errs=${errs:-0}
  lz4log=${lz4log:-0}; lz4r=${lz4r:-0}; zstdlog=${zstdlog:-0}; zstdr=${zstdr:-0}; inclog=${inclog:-0}; cgv=${cgv:--1}; devs=${devs:--1}; optv=${optv:--1}; promv=${promv:-0}
  rate_prx=${prev_rx:-$rx}; rate_ptx=${prev_tx:-$tx}
  if [[ -n "$prev_pt" ]]; then
    rate_dt=$((now - prev_pt)); [[ $rate_dt -lt 1 ]] && rate_dt=1
  fi
  # bcachefs rates: destage (data_update delta) + per-tier throughput (diskstats sectors delta), MB/s
  dst=0; [[ -n "$pdu" && ${du:-0} -ge ${pdu:-0} ]] && dst=$(( (du - pdu) / rate_dt / 1048576 ))
  promo=0; [[ -n "$pprom" && ${promv:-0} -ge ${pprom:-0} ]] && promo=$(( (promv - pprom) / rate_dt ))
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
  echo "$g $p $c $m $d $rx $tx $now $zd $zc ${zse:-N} ${zs:-0} ${zw:-0} $nv $nvs $sf $sfs ${ncd:--1} ${iop:--1} ${bc_saved:--1} ${du:-0} ${bc_ratio:--1} ${bc_backlog:--1} $ci $ct ${srd:-0} ${swr:-0} ${hrd:-0} ${hwr:-0} ${hwc:-0} ${hwt:-0} ${errs:-0} ${lz4log:-0} ${lz4r:-0} ${zstdlog:-0} ${zstdr:-0} ${inclog:-0} ${cgv:--1} ${devs:--1} ${optv:--1} ${promv:-0} _" > "$cache"
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
  # compression totals (lz4 = written awaiting zstd recompress, zstd = done,
  # raw = incompressible) + mover throughput + promote rate
  cmpsz=$(awk -v g="${bc_saved:-0}" 'BEGIN{if(g>=1024)printf "%.1fT",g/1024; else printf "%dG",g}')
  oratio=$(awk -v r="${bc_ratio:--1}" 'BEGIN{if(r<0)print "?"; else printf "%.2f", r/100}')
  cmpv=$(awk -v a="${lz4log:-0}" -v ar="${lz4r:-0}" -v b="${zstdlog:-0}" -v br="${zstdr:-0}" -v c="${inclog:-0}" 'BEGIN{printf "lz4 %.1fT@%.2fx zstd %.1fT@%.2fx raw %.1fT", a/1024,ar/100,b/1024,br/100,c/1024}')
  mdv="cmp saved ${cmpsz}@${oratio}x ($cmpv)  moved ${dst:-0}M/s  promoted $(hb ${promo:-0})/s"
fi
# backlog = bcachefs "Pending reconcile" queues (bytes, data column) packed
# replicas|erasure_code|compression|target|other|metadata (high_priority is
# skipped: it mirrors replicas). repl=extra copies owed, ec=awaiting stripe,
# recmpr=lz4->zstd, destage=wrong device (SSD->HDD moves).
rclv=""
if [[ "$host" == "nas" && "${bc_backlog:-}" == *"|"* ]]; then
  IFS='|' read -r rcr rce rcc rct rco rcm <<< "$bc_backlog"
  rclv=$(printf "backlog: repl %s  ec %s  recmpr %s  destage %s" "$(hb "$rcr")" "$(hb "${rce:-0}")" "$(hb "$rcc")" "$(hb "$rct")")
  [[ $((${rco:-0} + ${rcm:-0})) -gt 0 ]] && rclv="$rclv$(yellow " +misc $(hb $((rco + rcm)))")"
elif [[ "$host" == "nas" && "${bc_backlog:-}" == "-1" ]]; then
  rclv=$(red "backlog:?")
fi
# CG = bcachefs per-device congestion (dev-*/congested "current" %) + median read
# latency for the two Lexars — the device-health signal IO-PSI can't give (PSI/%util
# read the same for busy-and-fine vs congested; congested is a latency-over-threshold
# vote by bcachefs itself). NB the % is relative to each device's OWN adaptive
# threshold, so lexar1 vs lexar2 percentages are not directly comparable.
cgvv=""
if [[ "$host" == "nas" && "${cgv:-}" == *:* ]]; then
  for part in $(tr '|' '\n' <<< "$cgv" | sort); do
    IFS=':' read -r cgn cgc cgr <<< "$part"
    seg=$(awk -v n="$cgn" -v c="${cgc:--1}" -v r="${cgr:--1}" 'BEGIN{printf "%s cong %d%% rd %.1fms", n, c, r/1000}')
    # yellow, not red (Sep 9 2026, user request): a high congestion vote only
    # throttles promote writes onto that device, it is not a fault. Red stays
    # reserved for the probe itself failing (below).
    [[ ${cgc:--1} -ge 50 || ${cgr:--1} -ge 3000 ]] && seg=$(yellow "$seg")
    cgvv="${cgvv:+$cgvv }$seg"
  done
elif [[ "$host" == "nas" ]]; then
  cgvv=$(red "congestion:?")
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
# Per-device storage stats, grouped BY METRIC rather than by device: rendering
# "opt 40MB SSD 10MB" on one line made the Optane figure read as the SSD's. Each
# group (BW / IOPS / LAT / FILL+TEMP) gets its own row, aggregate-by-type first,
# then per device. Deltas are against the previous cycle, so the first sample
# after a cache miss shows zeros rather than a since-boot average.
# Arrow convention (device view, matching the old SSD/HDD row and net rx/tx):
# ↓ = writes INTO the device, ↑ = reads served FROM it. Write printed first.
bwv=""; iopsv=""; latv=""; occv=""
if [[ "$host" == "nas" && "${devs:-}" == *:* && "${pdevs:-}" == *:* ]]; then
  mapfile -t _drow < <(awk -v cur="$devs" -v prv="$pdevs" -v dt="${rate_dt:-1}" 'BEGIN{
    if(dt<1)dt=1
    n=split(prv,P,"|"); for(i=1;i<=n;i++){k=index(P[i],":"); if(k)p[substr(P[i],1,k-1)]=substr(P[i],k+1)}
    m=split(cur,C,"|"); cnt=0
    for(i=1;i<=m;i++){
      k=index(C[i],":"); if(!k) continue
      l=substr(C[i],1,k-1); split(substr(C[i],k+1),F,":")
      t=l; sub(/^hdd\.exos/,"e",t); sub(/^ssd\.lexar/,"l",t); if(t ~ /optane/)t="op"
      grp=(l ~ /optane/)?"opt":((l ~ /^hdd/)?"hdd":"ssd")
      fill[t]=F[6]+0; lat[t]=F[7]+0; tmp[t]=F[8]+0
      if(l in p){split(p[l],Q,":")
        u=(F[5]-Q[5])/dt/10; if(u<0)u=0; if(u>100)u=100
      } else u=0
      du[t]=u; us[grp]+=u; uc[grp]++
      if(l in p){split(p[l],Q,":")
        rd=(F[1]-Q[1])/dt; wr=(F[2]-Q[2])/dt; if(rd<0)rd=0; if(wr<0)wr=0
        br=(F[3]-Q[3])*512/dt/1048576; bw=(F[4]-Q[4])*512/dt/1048576; if(br<0)br=0; if(bw<0)bw=0
      } else {rd=0;wr=0;br=0;bw=0}
      dr[t]=rd; dw[t]=wr; dbr[t]=br; dbw[t]=bw
      tr[grp]+=rd; tw[grp]+=wr; tbr[grp]+=br; tbw[grp]+=bw; seen[grp]=1
      if(lat[t]>=0){ls[grp]+=lat[t]; lc[grp]++}
      order[++cnt]=t
    }
    for(i=1;i<=cnt;i++)for(j=i+1;j<=cnt;j++)if(order[j]<order[i]){x=order[i];order[i]=order[j];order[j]=x}
    B="BW"; I="IOPS"; L="LAT"; U="UTIL"; O="FILL/TEMP"
    split("opt ssd hdd",G," ")
    for(i=1;i<=3;i++){k=G[i]; if(!(k in seen))continue
      B=B sprintf("  %s %4d\xe2\x86\x93%4d\xe2\x86\x91", k, tbw[k]+0.5, tbr[k]+0.5)
      I=I sprintf("  %s %5d\xe2\x86\x93%5d\xe2\x86\x91", k, tw[k]+0.5, tr[k]+0.5)
      L=L sprintf("  %s %5.1f", k, (lc[k]?ls[k]/lc[k]:0)/1000)
      U=U sprintf("  %s %3d%%", k, (uc[k]?us[k]/uc[k]:0)+0.5)
    }
    B=B "MB \xe2\x94\x82"; I=I " \xe2\x94\x82"; L=L "ms \xe2\x94\x82"; U=U " \xe2\x94\x82"
    for(i=1;i<=cnt;i++){t=order[i]
      B=B sprintf("  %s %3d\xe2\x86\x93%3d\xe2\x86\x91", t, dbw[t]+0.5, dbr[t]+0.5)
      I=I sprintf("  %s %4d\xe2\x86\x93%4d\xe2\x86\x91", t, dw[t]+0.5, dr[t]+0.5)
      if(lat[t]>=0) L=L sprintf("  %s %4.1f", t, lat[t]/1000)
      useg=sprintf("  %s %3d%%", t, du[t]+0.5)
      if(du[t]>=90) useg="<span color=\"#ff5555\">" useg "</span>"
      U=U useg
      O=O sprintf("  %s %2d%%/%2d\xc2\xb0", t, fill[t], tmp[t]/1000)
    }
    print B; print I; print L; print U; print O
  }')
  bwv="${_drow[0]}"; iopsv="${_drow[1]}"; latv="${_drow[2]}"; utilv="${_drow[3]}"; occv="${_drow[4]}"
fi
# The NAS carries far more than a spark (bcachefs compression, reconcile backlog,
# per-tier throughput) and outgrew one 1728px row. Split it: the storage groups go
# to a SECOND bar, rendered here and handed to `custom/nas2` via this file, so the
# NAS is still probed ONCE per cycle rather than twice.
if [[ "$host" == "nas" ]]; then
  optd=""
  if [[ "${optv:-}" == *"|"* ]]; then
    IFS='|' read -r oused osize _ot ofg ocached <<< "$optv"
    # "used" in bcachefs fs usage = DURABLE data only (btree/journal/user); the
    # promote cache is separate and evictable — show both (Sep 12 2026: the
    # shrinking OPTuse was btree copies draining to the Lexars, not the cache).
    optd=$(awk -v u="${oused:-0}" -v c="${ocached:-0}" -v z="${osize:-0}" 'BEGIN{printf "OPT %.0fG+cache %.0fG/%.0fG", u/1073741824, c/1073741824, z/1073741824}')
  fi
  # fg = pool-wide foreground_target (4th optv slot, added Sep 6 2026). ssd = normal;
  # hdd = the governor (or a human) parked writes on HDD -> yellow so it is not forgotten.
  case "${ofg:-}" in
    ssd*) fgv="fg:${ofg}" ;;
    hdd*) fgv=$(yellow "fg:${ofg}") ;;
    *)    fgv=$(red "fg:?") ;;
  esac
  printf '%s\n' "${bwv:-BW n/a}"   > "$cache.row2"
  printf '%s\n' "${iopsv:-IOPS n/a}" > "$cache.row3"
  printf '%s\n' "${latv:-LAT n/a}"  > "$cache.row4"
  printf '%s\n' "${utilv:-UTIL n/a}" > "$cache.row7"
  printf '%s\n' "${occv:-FILL n/a}${optd:+  $optd}" > "$cache.row5"
  # row 8 = per-device congestion (user request Sep 6 2026: keep the LAST row pure
  # bcachefs stats; the bar order in the config puts row 8 directly above row 6).
  printf '%s\n' "${cgvv:-congestion n/a}" > "$cache.row8"
  row6=""
  for v in "$mdv" "$rclv" "$fgv" "$errv"; do [[ -n "$v" ]] && row6="${row6:+$row6 }$v"; done
  printf '%s\n' "$row6" > "$cache.row6"
  mdv=""; rclv=""; cgvv=""; errv=""; tputv=""
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
