#!/usr/bin/env bash
set -euo pipefail

cfg="i3/config"

# Ensure Colemak-DH nav bindings exist
rg -n '^bindsym \$mod\+n +focus left$' "$cfg" >/dev/null
rg -n '^bindsym \$mod\+e +focus down$' "$cfg" >/dev/null
rg -n '^bindsym \$mod\+i +focus up$' "$cfg" >/dev/null
rg -n '^bindsym \$mod\+o +focus right$' "$cfg" >/dev/null

# Ensure Colemak-DH move bindings exist (Shift+NEIO)
rg -n '^bindsym \$mod\+Shift\+n +move left$' "$cfg" >/dev/null
rg -n '^bindsym \$mod\+Shift\+e +move down$' "$cfg" >/dev/null
rg -n '^bindsym \$mod\+Shift\+i +move up$' "$cfg" >/dev/null
rg -n '^bindsym \$mod\+Shift\+o +move right$' "$cfg" >/dev/null

# Ensure conflicting workspace bindings removed
if rg -n '^bindsym \$mod\+n +workspace next' "$cfg"; then
  echo "FAIL: $cfg still maps $mod+n to workspace next" >&2
  exit 1
fi
if rg -n '^bindsym \$mod\+p +workspace prev' "$cfg"; then
  echo "FAIL: $cfg still maps $mod+p to workspace prev" >&2
  exit 1
fi

# Ensure sticky helper exists
rg -n '^bindsym \$mod\+Shift\+a +sticky toggle;' "$cfg" >/dev/null
if rg -n '^bindsym \$mod\+Shift\+o +sticky toggle;' "$cfg"; then
  echo "FAIL: sticky toggle still on $mod+Shift+o (conflicts with move)" >&2
  exit 1
fi

# Ensure no conflicting border binding on Ctrl+n (none expected now)
if rg -n '^bindsym \$mod\+Shift\+n +border normal$' "$cfg"; then
  echo "FAIL: stale border binding on $mod+Shift+n detected" >&2
  exit 1
fi

# Ensure no release-trigger on $mod+p
if rg -n '^bindsym --release \$mod\+p ' "$cfg"; then
  echo "FAIL: --release still present for $mod+p" >&2
  exit 1
fi

echo "OK: i3 Colemak+QWERTY nav bindings look good"
