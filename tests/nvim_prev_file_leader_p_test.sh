#!/usr/bin/env bash
set -euo pipefail

f="nvim/lua/keymaps.lua"
rg -n "map\('n', '<leader>p', '<C-\^>'" "$f" >/dev/null
echo "OK: Previous file mapped on <leader>p"
