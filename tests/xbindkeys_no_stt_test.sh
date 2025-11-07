#!/usr/bin/env bash
set -euo pipefail

f="$HOME/.xbindkeysrc"
if [ -f "$f" ]; then
  if rg -n '^[^#]*voice_toggle\.sh' "$f"; then
    echo "FAIL: active STT mapping still present in $f" >&2
    exit 1
  fi
fi
echo "OK: no active STT mapping in ~/.xbindkeysrc"

