#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
conf="$repo_root/hypr/hyprland.conf"

grep -F 'name = zsa-technology-labs-voyager-1' "$conf" >/dev/null
grep -F 'accel_profile = custom 0.5 0 0.35 0.91 2.1 4.55 8.75' "$conf" >/dev/null

grep -F 'name = nordic-2.4g-wireless-receiver-mouse' "$conf" >/dev/null
grep -F 'accel_profile = custom 0.5 0 1.5 3.0 6.0 11.25 20.25' "$conf" >/dev/null

if grep -F 'low CPI (50)' "$conf"; then
  echo 'FAIL: unsupported Voyager 50-CPI claim remains' >&2
  exit 1
fi

echo 'OK: Hyprland trackball acceleration profiles are current'
