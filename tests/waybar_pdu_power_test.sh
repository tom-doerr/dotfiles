#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT
prom_file="$fixture_dir/pdu.prom"

write_fixture() {
  local up=$1 updated=$2
  printf '%s\n' \
    "pdu_up $up" \
    "pdu_last_success_unixtime_seconds $updated" \
    'pdu_outlet_power_watts{outlet="1",name="spark-1",pdu_name="Outlet1"} 151' \
    'pdu_outlet_power_watts{outlet="2",name="spark-2",pdu_name="Outlet2"} 2' \
    'pdu_outlet_power_watts{outlet="3",name="spark-3",pdu_name="Outlet3"} 142' \
    > "$prom_file"
}

write_fixture 1 1786211400.750
value=$(PDU_PROM_FILE="$prom_file" PDU_NOW_EPOCH=1786211420 "$root/waybar/pdu-power.sh" spark-2)
[[ "$value" == "2" ]]

if PDU_PROM_FILE="$prom_file" PDU_NOW_EPOCH=1786211421 "$root/waybar/pdu-power.sh" spark-2; then
  echo "accepted a stale PDU sample" >&2
  exit 1
fi

write_fixture 0 1786211400.750
if PDU_PROM_FILE="$prom_file" PDU_NOW_EPOCH=1786211400 "$root/waybar/pdu-power.sh" spark-2; then
  echo "accepted a failed PDU sample" >&2
  exit 1
fi

write_fixture 1 1786211400.750
if PDU_PROM_FILE="$prom_file" PDU_NOW_EPOCH=1786211400 "$root/waybar/pdu-power.sh" spark-4; then
  echo "accepted an unmapped outlet" >&2
  exit 1
fi
