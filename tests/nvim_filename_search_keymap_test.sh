#!/usr/bin/env bash
set -euo pipefail

f="nvim/lua/plugins/init.lua"
rg -n "^\s*vim\.keymap\.set\('n', '<leader>o', '<cmd>Telescope find_files<cr>'" "$f" >/dev/null
echo "OK: Neovim filename fuzzy search mapped on <leader>o"
