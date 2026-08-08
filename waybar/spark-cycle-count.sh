#!/bin/bash
set -euo pipefail

host=${1:?usage: spark-cycle-count.sh spark-2|spark-3}
case "$host" in
  spark-2|spark-3) ;;
  *) exit 1 ;;
esac

state_file=${SPARK_WATCHDOG_STATE_FILE:-"$HOME/.local/state/spark-pdu-watchdog/state.json"}
now=${SPARK_WATCHDOG_NOW_EPOCH:-$(date +%s.%N)}

[[ "$now" =~ ^[0-9]+([.][0-9]+)?$ ]] || exit 1
if [[ ! -r "$state_file" ]]; then
  printf '0\n'
  exit
fi

jq -r --arg host "$host" --argjson now "$now" '
  [
    (.hosts[$host].cycle_history // [])[]?
    | select(type == "number")
    | select(. >= ($now - 86400) and . <= $now)
  ]
  | length
' "$state_file"
