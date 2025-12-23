#!/usr/bin/env bash
set -euo pipefail

f="nvim/lua/plugins/init.lua"
rg -n "^\s*vim\.keymap\.set\('n', '<leader>s', '<cmd>Telescope live_grep<cr>'" "$f" >/dev/null
echo "OK: Neovim project content search mapped on <leader>s"
