#!/usr/bin/env bash
set -euo pipefail

f="nvim/lua/plugins/init.lua"

# Normal mode ; mapping calls the wrapper function
rg -nF "vim.keymap.set('n', ';', h_then_hop_words_normal" "$f" >/dev/null

# Visual/Operator ; mapping calls hop.hint_words
rg -nF "vim.keymap.set({'v', 'o'}, ';', function() hop.hint_words() end" "$f" >/dev/null

echo "OK: Hop semicolon mappings exist (normal + v/o)"
