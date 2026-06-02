#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
conf="$repo_root/hypr/hyprland.conf"
script="$repo_root/hypr/hypr-screenshot"

grep -F 'bind = $mainMod, M, exec, ~/git/dotfiles/hypr/hypr-screenshot region' "$conf" >/dev/null
grep -F 'bind = $mainMod SHIFT, M, exec, ~/git/dotfiles/hypr/hypr-screenshot full' "$conf" >/dev/null

grep -F 'grim_args=(-t png -l "$compression")' "$script" >/dev/null
grep -F 'wl-copy --type image/png' "$script" >/dev/null
grep -F 'itxt_chunk("screenshot.metadata", meta_json)' "$script" >/dev/null
grep -F '"lossless": True' "$script" >/dev/null
grep -F '"capture_limits"' "$script" >/dev/null
