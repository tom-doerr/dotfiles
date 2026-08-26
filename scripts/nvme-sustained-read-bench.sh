#!/usr/bin/env bash
# Sustained NVMe read benchmark + thermal logging (no root needed).
#
# THE PAGE CACHE IS DEFEATED TWO INDEPENDENT WAYS:
#   1. O_DIRECT (fio --direct=1) — every read bypasses the page cache and goes
#      to the device. This is the actual mechanism.
#   2. Test file LARGER THAN RAM — belt-and-braces: even if O_DIRECT were
#      silently dropped, the file still cannot fit in page cache, so reads
#      must reach the drive. The script REFUSES to run if size <= RAM.
# NVMe drives have no meaningful *read* cache (on-drive DRAM holds FTL mapping
# tables, not user data), so re-reading the same LBAs still hits NAND.
#
# Usage:  DURATION=3600 SIZE_GB=256 ./nvme-sustained-read-bench.sh
# Output: $TESTDIR/results-<stamp>/{samples.csv,fio.txt,summary.txt}
set -euo pipefail

DURATION=${DURATION:-3600}     # seconds of sustained reading
SIZE_GB=${SIZE_GB:-256}        # test file size; MUST exceed RAM
TESTDIR=${TESTDIR:-$HOME/nvme-bench}
JOBS=${JOBS:-4}
IODEPTH=${IODEPTH:-32}
BS=${BS:-1M}
SAMPLE_SEC=${SAMPLE_SEC:-2}
FIO=${FIO:-fio}

STAMP=$(date +%Y%m%d-%H%M%S)
OUTDIR=${OUTDIR:-$TESTDIR/results-$STAMP}
FILE=$TESTDIR/sustained-read.bin

command -v "$FIO" >/dev/null || { echo "FATAL: fio not found" >&2; exit 1; }
mkdir -p "$TESTDIR" "$OUTDIR"

RAM_GB=$(awk '/MemTotal/{printf "%d", $2/1048576}' /proc/meminfo)
if [ "$SIZE_GB" -le "$RAM_GB" ]; then
  echo "FATAL: SIZE_GB=$SIZE_GB must EXCEED RAM (${RAM_GB}G) or the page" >&2
  echo "       cache could serve reads. Raise SIZE_GB." >&2
  exit 1
fi

# --- resolve the backing disk and ITS nvme hwmon (indices shuffle per boot,
# so match by PCI device path, never by hwmonN) ---------------------------
SRC=$(df --output=source "$TESTDIR" | tail -1)
DISK=$(lsblk -no PKNAME "$SRC" | tr -d ' ')
[ -n "$DISK" ] || { echo "FATAL: no parent disk for $SRC" >&2; exit 1; }
DEVPATH=$(readlink -f "/sys/block/$DISK/device")

HWMON=""
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = nvme ] || continue
  [ "$(readlink -f "$h/device")" = "$DEVPATH" ] || continue
  HWMON=$h; break
done
[ -n "$HWMON" ] || { echo "FATAL: no nvme hwmon for $DISK" >&2; exit 1; }

TMAX=unset; TCRIT=unset
[ -e "$HWMON/temp1_max" ]  && TMAX=$(awk '{printf "%.1f", $1/1000}' "$HWMON/temp1_max")
[ -e "$HWMON/temp1_crit" ] && TCRIT=$(awk '{printf "%.1f", $1/1000}' "$HWMON/temp1_crit")

# --- 2 s sampler: hwmon temps + device-truth throughput from diskstats ----
# diskstats fields: $6=sectors_read (512 B), $13=io_ticks (ms busy).
# diskstats is INDEPENDENT of fio, so it also catches any other reader.
sampler() {
  local csv=$1 psect pticks prev sect ticks now
  echo "ts,elapsed_s,temp_composite_c,temp_s1_c,temp_s2_c,read_MBps,busy_pct" >"$csv"
  read -r psect pticks < <(awk -v d="$DISK" '$3==d{print $6, $13}' /proc/diskstats)
  prev=$(date +%s)
  while :; do
    sleep "$SAMPLE_SEC"
    read -r sect ticks < <(awk -v d="$DISK" '$3==d{print $6, $13}' /proc/diskstats)
    now=$(date +%s)
    awk -v ts="$(date -Is)" -v el=$((now-T0)) -v dt=$((now-prev)) \
        -v ds=$((sect-psect)) -v dk=$((ticks-pticks)) \
        -v c="$(cat "$HWMON/temp1_input")" \
        -v s1="$(cat "$HWMON/temp2_input" 2>/dev/null || echo 0)" \
        -v s2="$(cat "$HWMON/temp3_input" 2>/dev/null || echo 0)" \
        'BEGIN{if(dt<=0)exit; printf "%s,%d,%.2f,%.2f,%.2f,%.1f,%.1f\n",
           ts, el, c/1000, s1/1000, s2/1000, ds*512/1048576/dt, dk/(dt*10)}' >>"$csv"
    psect=$sect; pticks=$ticks; prev=$now
  done
}

# --- layout: must WRITE REAL DATA. A fallocate'd/sparse file returns zeros
# from the filesystem without touching the device and fakes huge numbers. ---
WANT=$((SIZE_GB*1024*1024*1024))
if [ ! -f "$FILE" ] || [ "$(stat -c %s "$FILE" 2>/dev/null || echo 0)" -ne "$WANT" ]; then
  echo "Laying out ${SIZE_GB}G at $FILE (one-time; reused by later runs)..."
  "$FIO" --name=layout --filename="$FILE" --rw=write --bs=1M --size="${SIZE_GB}G" \
    --direct=1 --ioengine=libaio --iodepth=32 --output="$OUTDIR/layout.txt"
fi

PER=$((SIZE_GB/JOBS))
echo "host=$(hostname) disk=$DISK hwmon=$HWMON warn=${TMAX}C crit=${TCRIT}C"
echo "reading ${SIZE_GB}G O_DIRECT, ${JOBS}x QD${IODEPTH} bs=$BS for ${DURATION}s"
echo "samples -> $OUTDIR/samples.csv"

T0=$(date +%s)
sampler "$OUTDIR/samples.csv" &
SAMPLER=$!
trap 'kill $SAMPLER 2>/dev/null || true' EXIT

"$FIO" --name=sustained --filename="$FILE" --rw=read --bs="$BS" \
  --direct=1 --ioengine=libaio --iodepth="$IODEPTH" --numjobs="$JOBS" \
  --size="${PER}G" --offset_increment="${PER}G" \
  --time_based --runtime="$DURATION" --group_reporting \
  --output="$OUTDIR/fio.txt" || true

kill $SAMPLER 2>/dev/null || true
sleep 1

# --- summary: first-5min vs last-5min is the THROTTLE TEST. A drive that
# thermally throttles shows falling MB/s with temperature pinned at warn. ----
{
  echo "=== $(hostname) $DISK  $(date -Is) ==="
  grep -E '^ *READ:' "$OUTDIR/fio.txt" || echo "(no fio READ line)"
  awk -F, -v tmax="$TMAX" 'NR>1 && $6>0 {
      n++; bw+=$6; t+=$3
      if(mint==""||$3<mint)mint=$3; if($3>maxt)maxt=$3
      if(minb==""||$6<minb)minb=$6; if($6>maxb)maxb=$6
      if($2<=300){eb+=$6; en++} ; last[NR]=$6; le=$2
    }
    END{
      if(!n){print "no samples"; exit}
      printf "samples      : %d over %ds\n", n, le
      printf "read MB/s    : mean %.0f  min %.0f  max %.0f\n", bw/n, minb, maxb
      printf "temp C       : mean %.1f  min %.1f  max %.1f  (warn %s)\n", t/n, mint, maxt, tmax
      if(en) printf "first 5 min  : %.0f MB/s\n", eb/en
    }' "$OUTDIR/samples.csv"
  # last 5 min mean, computed separately so the window is exact
  awk -F, -v end="$DURATION" 'NR>1 && $6>0 && $2>=end-300 {s+=$6;n++}
    END{if(n) printf "last 5 min   : %.0f MB/s\n", s/n}' "$OUTDIR/samples.csv"
  echo "csv: $OUTDIR/samples.csv"
} | tee "$OUTDIR/summary.txt"
