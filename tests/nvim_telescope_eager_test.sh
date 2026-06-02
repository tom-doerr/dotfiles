#!/usr/bin/env bash
set -euo pipefail

f="nvim/lua/plugins/init.lua"

# Look for telescope plugin declaration and confirm lazy = false is nearby
start_line=$(rg -n "'nvim-telescope/telescope.nvim'" "$f" | head -n1 | cut -d: -f1 || true)
if [ -z "$start_line" ]; then
  echo "FAIL: telescope plugin spec not found in $f" >&2
  exit 1
fi

tail_start=$(( start_line ))
tail -n +$tail_start "$f" | sed -n '1,8p' | rg -n "lazy\s*=\s*false" >/dev/null || {
  echo "FAIL: telescope is not eager-loaded (lazy=false missing near spec)" >&2
  exit 1
}

echo "OK: telescope is eager-loaded (lazy=false)"
