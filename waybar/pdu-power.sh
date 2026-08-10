#!/bin/bash
set -euo pipefail

host=${1:?usage: pdu-power.sh spark-N}
prom_file=${PDU_PROM_FILE:-"$HOME/.local/share/node_exporter/textfile/pdu.prom"}
max_age=${PDU_MAX_AGE_SECONDS:-20}
stale_max_age=${PDU_STALE_MAX_AGE_SECONDS:-60}
now=${PDU_NOW_EPOCH:-$(date +%s)}

[[ -r "$prom_file" ]] || exit 1
up=$(awk '$1 == "pdu_up" {print $2; exit}' "$prom_file")
updated=$(awk '$1 == "pdu_last_success_unixtime_seconds" {print $2; exit}' "$prom_file")
updated=${updated%%.*}
[[ "$up" =~ ^[01]$ && "$updated" =~ ^[0-9]+$ ]] || exit 1
age=$((now - updated))
[[ $age -ge 0 && $age -le $stale_max_age ]] || exit 1
state=stale
[[ "$up" == "1" && $age -le $max_age ]] && state=fresh
power=$(awk -v wanted="name=\"$host\"" '
  $1 ~ /^pdu_outlet_power_watts\{/ && index($1, wanted) {printf "%.0f\n", $2; exit}
' "$prom_file")
[[ "$power" =~ ^[0-9]+$ ]] || exit 1
printf '%s %s\n' "$power" "$state"
