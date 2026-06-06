#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

rg -F 'lock_cmd = /home/tom/git/dotfiles/hypr/oled-lock' "$repo/hypr/hypridle.conf"
rg -F 'color = rgba(000000ff)' "$repo/hypr/hyprlock.conf"

OLED_LOCK_GEOMETRY=640x360 OLED_LOCK_OUTPUT="$tmpdir/oled-lock.png" "$repo/hypr/oled-lock" --render-only >/dev/null
test -s "$tmpdir/oled-lock.png"

python3 - "$tmpdir/oled-lock.png" <<'PY2'
import sys
from PIL import Image

image = Image.open(sys.argv[1]).convert("RGB")
pixels = list(image.getdata())
active = sum(pixel != (0, 0, 0) for pixel in pixels)
total = len(pixels)

assert image.size == (640, 360), image.size
assert active > 100, active
assert active < total * 0.01, active
PY2
