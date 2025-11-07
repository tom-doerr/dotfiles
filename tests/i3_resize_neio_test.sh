#!/usr/bin/env bash
set -euo pipefail
cfg="i3/config"

rg -n '^\s*bindsym n resize shrink width 50 px or 5 ppt$' "$cfg" >/dev/null
rg -n '^\s*bindsym e resize grow height 50 px or 5 ppt$' "$cfg" >/dev/null
rg -n '^\s*bindsym i resize shrink height 50 px or 5 ppt$' "$cfg" >/dev/null
rg -n '^\s*bindsym o resize grow width 50 px or 5 ppt$' "$cfg" >/dev/null

echo "OK: resize mode has NEIO aliases"

