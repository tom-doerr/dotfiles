#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT
state_file="$fixture_dir/state.json"

printf '%s\n' \
  '{' \
  '  "hosts": {' \
  '    "spark-2": {"cycle_history": [113599.9, 113600, 199999.5, 200001, "bad"]},' \
  '    "spark-3": {"cycle_history": []}' \
  '  }' \
  '}' \
  > "$state_file"

count=$(
  SPARK_WATCHDOG_STATE_FILE="$state_file" \
  SPARK_WATCHDOG_NOW_EPOCH=200000 \
    "$root/waybar/spark-cycle-count.sh" spark-2
)
[[ "$count" == "2" ]]

count=$(
  SPARK_WATCHDOG_STATE_FILE="$state_file" \
  SPARK_WATCHDOG_NOW_EPOCH=200000 \
    "$root/waybar/spark-cycle-count.sh" spark-3
)
[[ "$count" == "0" ]]

if SPARK_WATCHDOG_STATE_FILE="$state_file" \
  "$root/waybar/spark-cycle-count.sh" spark-1; then
  echo "accepted a host without a watchdog-controlled outlet" >&2
  exit 1
fi

count=$(
  SPARK_WATCHDOG_STATE_FILE="$fixture_dir/missing.json" \
    "$root/waybar/spark-cycle-count.sh" spark-2
)
[[ "$count" == "0" ]]
