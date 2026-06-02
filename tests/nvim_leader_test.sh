#!/usr/bin/env bash
set -euo pipefail

f="nvim/init.lua"
rg -nF "vim.g.mapleader = \" \"" "$f" >/dev/null
rg -nF 'vim.g.maplocalleader = "\\"' "$f" >/dev/null
echo "OK: Leader is <Space>; LocalLeader is \\"
