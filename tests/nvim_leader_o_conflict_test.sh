#!/usr/bin/env bash
set -euo pipefail

# Fails if <leader>o is defined in keymaps.lua, which would override Telescope's mapping.
f="nvim/lua/keymaps.lua"
if rg -n "<leader>o" "$f" >/dev/null; then
  echo "FAIL: <leader>o is mapped in $f (conflicts with Telescope find_files)" >&2
  exit 1
fi
echo "OK: No conflicting <leader>o mapping in keymaps.lua"
