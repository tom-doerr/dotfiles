#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/scripts/span-toggle"
fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT
mock_bin="$fixture_dir/bin"
log="$fixture_dir/hyprctl.log"
runtime="$fixture_dir/runtime"
mkdir -p "$mock_bin"

rg -F 'bind = $mainMod CTRL, F, exec, ~/.local/bin/span-toggle' "$repo_root/hypr/hyprland.conf" >/dev/null

cat > "$mock_bin/hyprctl" <<'MOCK'
#!/bin/sh
printf '%s\n' "$*" >> "$SPAN_TEST_LOG"
case "$1" in
  activewindow)
    if [ -n "${SPAN_ACTIVE_JSON_AFTER:-}" ] \
      && grep -Fq 'dispatch fullscreenstate 0 0 set' "$SPAN_TEST_LOG"; then
      printf '%s\n' "$SPAN_ACTIVE_JSON_AFTER"
    else
      printf '%s\n' "$SPAN_ACTIVE_JSON"
    fi
    ;;
  clients)
    printf '%s\n' "$SPAN_CLIENTS_JSON"
    ;;
  dispatch|--batch) ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$mock_bin/hyprctl"

run_span() {
  local active_json=$1
  local clients_json=$2
  local active_json_after=${3:-}
  PATH="$mock_bin:$PATH" \
  XDG_RUNTIME_DIR="$runtime" \
  SPAN_TEST_LOG="$log" \
  SPAN_ACTIVE_JSON="$active_json" \
  SPAN_ACTIVE_JSON_AFTER="$active_json_after" \
  SPAN_CLIENTS_JSON="$clients_json" \
    "$script"
}

assert_log() {
  local expected=$1
  local actual
  actual=$(<"$log")
  if [[ "$actual" != "$expected" ]]; then
    diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual")
    exit 1
  fi
}

a_tiled='{"address":"0xabc","floating":false,"fullscreen":0,"fullscreenClient":0,"at":[100,200],"size":[800,600]}'
a_spanned='{"address":"0xabc","floating":true,"fullscreen":0,"fullscreenClient":0,"at":[0,2160],"size":[5184,3072]}'
b_tiled='{"address":"0xdef","floating":false,"fullscreen":0,"fullscreenClient":0,"at":[300,400],"size":[700,500]}'

run_span "$a_tiled" '[]'
run_span "$a_spanned" "[$a_spanned]"

expected=$(printf '%s\n' \
  'activewindow -j' \
  'dispatch setfloating address:0xabc' \
  '--batch dispatch movewindowpixel exact 0 2160,address:0xabc; dispatch resizewindowpixel exact 5184 3072,address:0xabc; dispatch alterzorder bottom,address:0xabc' \
  'dispatch focuswindow address:0xabc' \
  'activewindow -j' \
  'clients -j' \
  'dispatch setfloating address:0xabc' \
  '--batch dispatch movewindowpixel exact 100 200,address:0xabc; dispatch resizewindowpixel exact 800 600,address:0xabc' \
  'dispatch movecursor 500 500' \
  'dispatch settiled address:0xabc' \
  'dispatch focuswindow address:0xabc')
assert_log "$expected"

[[ ! -e "$runtime/span-toggle/active" ]]
[[ ! -e "$runtime/span-toggle/0xabc" ]]

# A stale marker must never hijack the selected window.
runtime="$fixture_dir/stale-runtime"
log="$fixture_dir/stale.log"
mkdir -p "$runtime/span-toggle"
printf '%s\n' '0xabc' > "$runtime/span-toggle/active"
printf '%s\n' '1 1730 2160 5184 3072' > "$runtime/span-toggle/0xabc"
run_span "$b_tiled" "[$a_tiled,$b_tiled]"

expected=$(printf '%s\n' \
  'activewindow -j' \
  'clients -j' \
  'dispatch setfloating address:0xdef' \
  '--batch dispatch movewindowpixel exact 0 2160,address:0xdef; dispatch resizewindowpixel exact 5184 3072,address:0xdef; dispatch alterzorder bottom,address:0xdef' \
  'dispatch focuswindow address:0xdef')
assert_log "$expected"
[[ $(<"$runtime/span-toggle/active") == 0xdef ]]
[[ $(<"$runtime/span-toggle/0xdef") == '0 0 0 300 400 700 500' ]]
[[ ! -e "$runtime/span-toggle/0xabc" ]]

# Focusing B while A genuinely spans restores A, then spans and focuses B.
runtime="$fixture_dir/switch-runtime"
log="$fixture_dir/switch.log"
mkdir -p "$runtime/span-toggle"
printf '%s\n' '0xabc' > "$runtime/span-toggle/active"
printf '%s\n' '0 0 0 100 200 800 600' > "$runtime/span-toggle/0xabc"
run_span "$b_tiled" "[$a_spanned,$b_tiled]"

expected=$(printf '%s\n' \
  'activewindow -j' \
  'clients -j' \
  'dispatch setfloating address:0xabc' \
  '--batch dispatch movewindowpixel exact 100 200,address:0xabc; dispatch resizewindowpixel exact 800 600,address:0xabc' \
  'dispatch movecursor 500 500' \
  'dispatch settiled address:0xabc' \
  'dispatch focuswindow address:0xdef' \
  'activewindow -j' \
  'dispatch setfloating address:0xdef' \
  '--batch dispatch movewindowpixel exact 0 2160,address:0xdef; dispatch resizewindowpixel exact 5184 3072,address:0xdef; dispatch alterzorder bottom,address:0xdef' \
  'dispatch focuswindow address:0xdef')
assert_log "$expected"
[[ $(<"$runtime/span-toggle/active") == 0xdef ]]
[[ ! -e "$runtime/span-toggle/0xabc" ]]

# One-monitor fullscreen is left before spanning and restored on the second press.
runtime="$fixture_dir/fullscreen-runtime"
log="$fixture_dir/fullscreen.log"
mkdir -p "$runtime"
c_full='{"address":"0xc00","floating":false,"fullscreen":2,"fullscreenClient":2,"at":[0,2160],"size":[1728,3072]}'
c_tiled='{"address":"0xc00","floating":false,"fullscreen":0,"fullscreenClient":0,"at":[700,800],"size":[900,1000]}'
c_spanned='{"address":"0xc00","floating":true,"fullscreen":0,"fullscreenClient":0,"at":[0,2160],"size":[5184,3072]}'
run_span "$c_full" '[]' "$c_tiled"
run_span "$c_spanned" "[$c_spanned]"

expected=$(printf '%s\n' \
  'activewindow -j' \
  'dispatch fullscreenstate 0 0 set' \
  'activewindow -j' \
  'dispatch setfloating address:0xc00' \
  '--batch dispatch movewindowpixel exact 0 2160,address:0xc00; dispatch resizewindowpixel exact 5184 3072,address:0xc00; dispatch alterzorder bottom,address:0xc00' \
  'dispatch focuswindow address:0xc00' \
  'activewindow -j' \
  'clients -j' \
  'dispatch setfloating address:0xc00' \
  '--batch dispatch movewindowpixel exact 700 800,address:0xc00; dispatch resizewindowpixel exact 900 1000,address:0xc00' \
  'dispatch movecursor 1150 1300' \
  'dispatch settiled address:0xc00' \
  'dispatch focuswindow address:0xc00' \
  'dispatch fullscreenstate 2 2 set')
assert_log "$expected"
[[ ! -e "$runtime/span-toggle/active" ]]
[[ ! -e "$runtime/span-toggle/0xc00" ]]

echo 'OK: span toggle restores, rejects stale state, switches targets, and preserves fullscreen'
