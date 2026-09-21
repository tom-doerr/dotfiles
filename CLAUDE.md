# Claude Configuration Notes - Dotfiles

## Neovim Autosave Issues

### Problem
Neovim was not autosaving on all edits. The configuration used `TextChangedPost` event which doesn't exist in Neovim.

### Solution
Fixed by updating the autocmd to use the correct events:
- `TextChanged` - triggers after text changes in normal mode
- `TextChangedI` - triggers after text changes in insert mode
- `CmdlineLeave` - triggers after leaving command line (catches substitutions and ex commands)

Location: `/home/tom/git/dotfiles/nvim/init.lua` lines 183-189

### Current Autosave Triggers
1. `InsertLeave` - when leaving insert mode
2. `FocusLost` - when neovim loses focus
3. `TextChanged`, `TextChangedI`, `CmdlineLeave` - on text changes
4. `BufLeave` - when leaving a buffer
5. Periodic `checktime` every 2 seconds to reload external changes

## i3 Function Key Bindings

### Problem
Function keys F1, F2, F3, F5, F9 were not working in applications because they were bound in i3 config.

### Solution
Commented out the function key bindings in `i3/config`:
- F1-F3: concentration label tracking
- F5: inference signal file
- F9: log timestamp refocused script

Reload i3 with `$mod+Shift+r` to apply changes.

## Semantic Code Search Plan

### Goal
Add local semantic search alongside existing ripgrep/fzf flows using a persistent vector index.

### Components
1. **Neovim plugin**: `vectorcode.nvim` for Telescope pickers and CLI utilities.
2. **Embedding runtime**: Ollama running `nomic-embed-text` locally (HTTP API compatible with OpenAI format).
3. **Vector database**: Qdrant in Docker with storage volume at `~/qdrant_storage`.
4. **Updater**: Watchman + Python helper that batches modified file paths and calls `vectorcode index --update`.

### Implementation Steps
1. Start services  
   - `docker run -d --name qdrant -p 6333:6333 -p 6334:6334 -v ~/qdrant_storage:/qdrant/storage qdrant/qdrant`  
   - `ollama run nomic-embed-text` (ensure Ollama daemon is up).
2. Configure VectorCode  
   - `~/.config/vectorcode/config.json` → set `embedding` base URL to Ollama and `database` to the Qdrant collection.  
   - Run `vectorcode index --rebuild $HOME/git/dotfiles` once to seed the index.
3. Automate updates  
   - Watchman trigger on repository `BufWritePost` / created files writes paths to `/tmp/vectorcode_queue`.  
   - Cron or systemd timer executes `vectorcode index --update @/tmp/vectorcode_queue` every ~30 s, then clears the queue.
4. Neovim integration  
   - Map `<leader>sv` → `:VectorCode search` (semantic) and keep `<leader>s` for `live_grep`.  
   - Optional: add `:VectorCode refresh` command to Neovim which touches the queue file for manual reindexing.
5. Maintenance  
   - Weekly `vectorcode index --sync` to catch branch switches or large refactors.  
   - Monitor `~/.vectorcode/logs` for failed ingests and re-run update if needed.

### Notes
- Keep chunk size consistent (default 512 tokens) so Qdrant payloads remain uniform.  
- If Ollama is too slow, swap in a sentence-transformers model inside a Python FastAPI server that mimics `/v1/embeddings`.  
- For multi-repo support, use separate Qdrant collections and include `{project = "dotfiles"}` in payload metadata for filtering.

## Hyprland Configuration

### Setup
- Config: `~/git/dotfiles/hypr/hyprland.conf` (symlinked)
- Displays: 3x Dell U2725QE 27" 4K portrait row (see below)
- Samsung S95D TV GONE since Jul 29 2026 (physically unplugged for
  good; its monitorv2 block removed from the config). HDMI-A-1 now =
  RIGHTMOST Dell (9FZKPF4), moved from USB-C DP to an HDMI cable.
- Terminal: Ghostty with frosted glass blur

### 3x Dell U2725QE Portrait Monitors (Jul 2026)
- Connect as `Unknown-2/3/4` — NVIDIA driver on GB10 doesn't report proper
  connector type names for DP/USB-C outputs, so Hyprland shows "Unknown-N".
  Exception since Jul 29 2026: rightmost Dell (9FZKPF4) is on an HDMI
  cable → proper name `HDMI-A-1` (HDMI connectors ARE typed correctly).
- Config matches on `desc:Dell Inc. DELL U2725QE <serial>` instead of the
  connector name (robust against Unknown-N renumbering across reboots).
- Layout: portrait row, left→right: FCZKPF4 (0x2160), 58ZKPF4
  (1728x2160), 9FZKPF4 (3456x2160). Positions kept at y=2160 even
  though the TV above (672x0) is gone since Jul 29 2026 — nothing
  occupies y<2160 now; renormalizing to y=0 would churn saved window
  geometries for no gain.
- All three: 3840x2160@120, scale 1.25 (logical 1728x3072, divides cleanly),
  `transform = 1` = top edge physically on the RIGHT. `transform = 3` = top
  on the LEFT (first Dell's original orientation before its 180° flip).
- Identify which panel is which: `swww clear FF0000 --outputs Unknown-4`
  (then restore via `systemctl --user start wallpaper-switcher.service`).
- All three Dells: `bitdepth = 10` (XBGR2101010 at full 120Hz, DSC
  handles the bandwidth; tested on FCZKPF4 first, then extended Jul 13).
- HDR test on FCZKPF4 (Jul 13): `cm = hdr` + `sdr_max_luminance = 200`
  set but FALLS BACK to srgb — Hyprland log: "connector Unknown-4 crtc
  doesn't support HDR (0)" (EDID advertises no HDR EOTFs; TV shows "(7)").
  Likely cause: Smart HDR disabled in the Dell OSD → monitor omits HDR
  from EDID. Enable via OSD joystick, then re-check log/`hyprctl monitors`.
- **Jul 13 window-destruction incident:** enabling DisplayHDR 600 in the
  left Dell's OSD re-enumerated its TB hub (keyboard+mouse on monitor USB
  dropped) and retrained the daisy chain → RIGHT Dell (Unknown-2) flapped
  → ~25 windows died: GTK4 apps crash on output removal (Ghostty,
  Nautilus); Chromium/Firefox/Bambu survive. Same app-crash pattern as
  the Jul 1 HDMI incident. hdmi-force-on only pins the TV's connector.
  OSD capability changes = hot-replug of monitor + downstream chain —
  close/park GTK4 windows first.
  **Mitigated Jul 13:** hdmi-force-on.service now pins ALL connected
  connectors via `/usr/local/bin/drm-force-on` (see ~/CLAUDE.md).
  **Jul 22:** udev topup added — a monitor appearing post-boot (e.g. Dell
  in deep standby during reboot = "no signal", 0-byte EDID) is auto-forced
  via `99-drm-force-topup.rules` → `drm-force-topup.service`; no manual
  `systemctl restart hdmi-force-on` needed. `drm-force-on detect` disarms
  topup (state file `/run/drm-force-on.forced` removed) until re-armed.
  (hdmi-force-on itself DISABLED Jul 29 2026 — TV gone; topup now a no-op.)
- **Driver 580.173.02 (Jul 29 2026): power-button wake of a deep-standby
  Dell no longer emits ANY hotplug** (the "appears post-boot" behavior
  above was 580.159). USB-C DP alt-mode never negotiates when the Dell
  slept through boot; fix = unplug/replug the USB-C cable with the
  monitor powered ON. Details in ~/CLAUDE.md.
- Forced-connector side effect: power-cycled Dell = no signal (DP link
  not retrained). Fix: `hyprctl dispatch dpms off Unknown-N` then
  `dpms on Unknown-N` — modeset retrains the link, no window loss.
- **HDR on the Dells = DEAD END (Jul 13, driver limitation).** After a
  fake replug (sysfs `echo off`/`detect`) Hyprland accepted `cm = hdr`
  (EDID re-parse saw the PQ block) BUT the NVIDIA driver exposes
  HDR_OUTPUT_METADATA only on HDMI, not DP/USB-C ("crtc doesn't support
  HDR (0)" persists) → monitor decodes PQ as SDR = washed out/dim.
  Reverted to srgb + bitdepth 10. Don't retry until the NVIDIA driver
  supports DP HDR metadata. Fake-replug recipe (no cable pull needed):
  `echo off > .../status; sleep 4; echo detect > .../status`, then
  `systemctl restart hdmi-force-on` to re-arm forcing.
- Workspaces pinned left→right: 4 (FCZKPF4), 5 (58ZKPF4), 6 (9FZKPF4),
  with `default:true, persistent:true` — they return home when a Dell
  reconnects and survive as empty workspaces.

### Keyboard
- ZSA Voyager (compact split, no arrow keys)
- Colemak DH layout
- Navigation: Super + neio (focus), Super + Shift + neio (move window)

### HDR + Transparency (Fixed Jan 2026)
Use `cm,hdr` in monitor line instead of `cm_enabled = true` in render block.
This gives HDR AND working transparency.

```
monitor=HDMI-A-1,3840x2160@119.88,auto,auto,bitdepth,10,cm,hdr
render { cm_enabled = false }
```

### Style
- Gaps: airy (12 inner, 40 outer)
- Blur: frosted glass (size 6, passes 3)
- Animations: snappy (~2x default speed)

### Screenshots: hypr-screenshot
Script `hypr/hypr-screenshot` (lossless PNG + clipboard + JSON/iTXt metadata).
Modes: `region` (slurp), `full`, `window` (focused window via `hyprctl activewindow -j` + jq), `geometry`.
Binds: `Super+M` region, `Super+Shift+M` full, `Super+Ctrl+M` window.
No cursor in any mode (grim omits pointer unless `-c`). `window` guards on `*null*` (no focused window).

### Notifications: swaync (not mako)
Use swaync (SwayNotificationCenter), not mako. Both were enabled causing DBus conflicts.

Fix: `pkill mako && systemctl --user restart swaync`
Permanent: `sudo systemctl --global disable mako.service`

## Ghostty Configuration

- Config: `~/git/dotfiles/ghostty/config` (symlinked)
- Font size 7 is normal for 55" 4K (same PPI as 27" 1080p)
- Transparency works with HDR (using cm,hdr in monitor line)

## Zsh Ctrl+J Fuzzy Directory Jump

Ctrl+J searches directories starting from `~` (home), not current directory.

### Problem
Ctrl+J (fzf_cd) was hanging for several seconds after selecting a directory.

### Root Cause
The for loop `(for d in {1..20}; do find...; done) | fzf` continues after fzf exits.
Each remaining find spawns, gets SIGPIPE, exits - but loop runs all 20 iterations.

### Solution
Added `|| break` to exit loop on SIGPIPE: `find ... 2>/dev/null || break`

Location: `/home/tom/.zshrc` lines 48-56

Note: Same issue exists in fzf-file-widget (Ctrl+A, lines 90-97).

## Bambu Studio on ARM64 (DGX Spark)

### Problem
Bambu Studio only provides x86_64 builds. No native ARM64.

### Failed: box64
WebKit2GTK dependency blocks emulation. Box64 can't handle webkit symbols.

### Working: Docker x86 Emulation
Requires: `qemu-user-static` package.

**Container:** `bambu-studio` (Docker, x86_64 Ubuntu 24.04)
**Launch:** `bambu-studio` or app launcher
**Files:** `~/3d-prints` mounted to `/root/3d-prints` in container

### Cleanup (optional)
- `~/VMs/bambu-studio/` - 5.8GB Ubuntu ISO, not needed
- `~/Applications/x86_64-libs/` - box64 libs, not needed

## Steam Gaming on DGX Spark (ARM64)

### Overview
Canonical built an ARM64 Steam snap using FEX emulator for x86 translation. The DGX Spark is the **primary test device** for this effort.

### Installation
```bash
sudo snap install steam --candidate
```
Requires NVIDIA driver 580.95.05 series.

### Performance (Cyberpunk 2077 @ 1080p)
| Configuration | FPS |
|---------------|-----|
| Medium, no DLSS (Box64) | ~50 |
| Low settings (Proton) | ~100 |
| High + RT Ultra + DLSS 4 + MFG | 175+ |

### Optimal Setup
- Use **Proton 10.0-2 beta** (not Box64)
- Enable **DLSS 4 with Multi-Frame Generation**
- Per-game: Right-click → Properties → Compatibility → Force Proton

### GB10 vs RTX 5090
- Raw performance: GB10 ~1/3 of RTX 5090
- Memory bandwidth: 273 GB/s vs 1,792 GB/s (6.5x slower)
- Advantage: 128GB unified memory (no VRAM limits)

### Confirmed Working Games
- Counter-Strike 2: "Multi-hour sessions, smooth"
- Dota 2, Portal 2: Native Linux, no issues
- Cyberpunk 2077: Works with DLSS/Proton setup

### Free Games for Testing
- **Quake II RTX**: Best ray tracing demo, tiny download
- **Warframe**: Best looking F2P, good Proton support
- **Counter-Strike 2**: Confirmed working on Spark

### References
- https://discourse.ubuntu.com/t/call-for-testing-steam-snap-for-arm64/74719
- https://www.phoronix.com/news/Steam-Snap-ARM64-FEX

## Waybar Spark Cluster Monitoring

### Layout: 7 bars on the MIDDLE Dell only (Jul 13, +vast Jul 22, +nas2 Aug 13 2026)
Config (in `~/git/private/waybar/config`) defines 6 bars, all
`"output": "Unknown-3"` (middle Dell, 1728px logical portrait), all
stacked TOP in config order; last row = "vast" (OR credit, vast credit
+ per-instance
$/h, GPU util %, VRAM used/total G from the instances API
gpu_util/vmem_usage(GB)/gpu_ram(MB), 30s poll; was position bottom
briefly — screen-bottom is a meter away from the top stack, reverted).
Rows: main (UI row, window title max-length 30), spark1, spark2, spark3,
**nas, nas2**, vast — one spark host per row since any pair (~275 chars)
exceeds the ~221-char width at 13px. The nas row USED to need
`window#waybar.nas * { font-size: 12px; }`; that override is GONE since the
Aug 13 2026 split (below).
Bars no longer appear on the TV/outer Dells (they reserve no top space).
**★ NAS SPLIT ACROSS TWO ROWS (Aug 13 2026) — shrinking the font was the wrong fix.**
Adding the RCL group pushed the nas row to 323 chars; 12px silently CLIPPED the
trailing staleness age (the one field that tells you the probe is dead, so a bad
thing to lose quietly). First attempt dropped the font to 10px; user's call was to
put the font BACK UP and add a row instead — correct, since the row would just
re-outgrow any font. Now: **`nas` = system (CPU/MEM/IO/swap/DSK/net/age),
`nas2` = bcachefs storage (CMP + per-algo, DST, RCL, ERR, SSD/HDD throughput)**,
~130 chars each, both at the global 13px with no per-bar override.
**★ Sep 6 2026: SEVEN rows — `fg:<target>` added, congestion split out.** Row 6
now ends with the pool-wide `foreground_target` (`fg:ssd` plain, `fg:hdd`
yellow = the governor or a human parked writes on HDD, red `fg:?` unreadable),
carried as the 4th `|` slot of the `optv` field so the 42-field cache format
did not change. The per-device congestion segment moved to a NEW row 8
(`nas-row.sh 8`, bar `nas8` placed directly ABOVE `nas6` in the private
config) so the last row is pure bcachefs stats (user request). Display order:
2=BW 3=IOPS 4=LAT 7=UTIL 5=FILL/TEMP 8=congestion 6=cmp+backlog+fg.
**★ RE-SPLIT INTO SIX ROWS, GROUPED BY METRIC (Aug 31-Sep 1 2026).** The
device-grouped row read "opt 40MB SSD 10MB" — the Optane figure LOOKED like
the SSD's. Rows then: 2=BW 3=IOPS 4=LAT 7=UTIL 5=FILL/TEMP 6=cmp+backlog
(Sep 3: relabeled explicit — "cmp saved X@Yx (lz4/zstd/raw)  moved N M/s
promoted N/s  backlog: repl/ec/recmpr/destage +misc  <dev> cong N% rd Nms";
the promote rate needs a data_read_promote counter the probe now ships,
cache 41→42 fields); each =
by-type aggregate (opt/ssd/hdd) then `│` then per device (e1-e8 l1 l2 op);
display order comes from the CONFIG (private repo), not the numbers.
**Latency units are adaptive since Sep 20 2026:** LAT row and the congestion row's `rd`
print `<1000 µs` as `NNNNµs` and above as `N.Nms` (awk `fl()`, if/else not `?:` for mawk);
the probe always shipped integer µs, only the `%.1fms` display hid the Optane's ~16-19 µs
median as `0.0`. The LAT row lost its trailing `ms` unit (units are per value now); width
168 → 189 chars, still under the ~221 capacity.
**Reconcile phase on row 6 (Sep 20 2026):** the 6th `|` slot of `optv` carries the first
line of the pool's top-level `reconcile_status` file, packed `scan:<type>:<pct>:<done>/<total>`
(bcachefs's own `bch2_progress` node count — printed only for fs/metadata scans; device/inum
scans pack `-`), `proc:<prio>_<kind>`, `wait` or `between`. Rendered after `promoted N/s`:
yellow `scan fs 2% 20.7k/1.01M nodes` while scanning (the mover moves nothing until the scan
ends), plain `proc normal_logical` while working, nothing otherwise. Row 6 = 194 visible chars.
Cache format still 42 fields (slot packing, same trick as `fg:`).
**Row 6 is FIXED-WIDTH since Sep 20 2026 (user: the items kept moving):** `hb()` always
prints 5 chars right-aligned, `moved %4d`, cmp/lz4/zstd/raw `%5.1fT`, scan `%3d%%` with
`%5.1fk`/`%5.2fM` counts, and `+misc` is ALWAYS printed (yellow only when nonzero) so the
items after it never shift. Verified: three consecutive renders, identical width and identical
column for every label. Width 209 visible + up to 5 for the stale suffix < ~221. Rule for any
future row-6 field: pad it; never let a value's width depend on its magnitude.
**Right-edge cut-off on BW/IOPS FIXED Sep 20 2026 (user screenshot):** two causes. (1) the
short-name rule `sub(/^ssd\.lexar/,"l")` silently stopped matching after the Sep 6 relabel to
`ssd.nand.lexarN`, so both Lexars printed 15-char names on every per-device row (BW 224, IOPS
253 visible chars vs the ~221 capacity) — now `/^ssd\.(nand\.)?lexar/`. (2) on the four rows
that open with type aggregates (BW/IOPS/LAT/UTIL) the per-device `op` entry repeated the `opt`
aggregate verbatim (single-member group) — dropped there, kept on FILL/TEMP. Widths after:
BW 185, IOPS 211, LAT 152, FILL 167, row6 209, UTIL 127, cong 74. IOPS is the tightest row
(aggregates %5d because the Optane already does 11k reads/s). Check widths with
`sed 's/<[^>]*>//g' /tmp/spark_nas.rowN | wc -m` after any change.
Arrows follow the into-device convention (w↓ r↑, write first — matches net
rx↓/tx↑; row2/3 had it inverted for a day). UTIL ≥90% renders red.
Optane matched by `/optane/` SUBSTRING, never a `^ssd`/label prefix — its
label moved optane.meta1 → ssd.optane1 (so `metadata_target=ssd` spans it)
and prefix matching silently folded it into the ssd aggregate.
NVMe temp = `device/hwmonN/temp1_input`; SATA drivetemp NESTS it at
`device/hwmon/hwmonN/` — the probe globs both.
**Only ONE SSH probe still runs:** `spark.sh nas` renders all rows and writes
`/tmp/spark_nas.rowN`; the generic `waybar/nas-row.sh <n>` (nas-row2.sh is
GONE) displays one file and shows red if missing or >30s stale. Do NOT give
any nas row its own probe — the NAS answers slowly under pool load and this
would multiply the SSH pressure on it. Adjacent GTK labels have NO gap of their own, so any module
sharing a bar needs an explicit `margin-right` (the vast row rendered as
`m$202.89VAST $26.44 30hvast:` until `#custom-openrouter, #custom-vast` got one).
Width-measuring recipe kept because it is reusable. Measure width
empirically instead of guessing at em-ratios — screenshot the row with
`grim -g "1728,2256 1728x26"` (bar rows are 24 LOGICAL px from the monitor's y:
main 2160, spark1 2184, spark2 2208, spark3 2232, nas 2256, nas2 2280, vast 2304)
and find the
rightmost lit column with PIL. Measured px/char on the 1728px portrait Dell (2149px
usable): 8px=4.81, 10px=5.77, 11px=6.57, 12px=6.67 → capacity 447/372/327/322 chars.
**11px and 12px nearly tie** (hinting snaps the advance) — so shaving a font size is
often worth ~nothing; add a row instead. `#custom-nas`/`#custom-nas2` also burn 28
logical px each on `padding: 0 8px` + `margin-right: 12px` (~5 chars) if more room is
ever needed. Gotcha: screenshot in a SEPARATE tool call from the waybar
relaunch — grim fired immediately after `hyprctl dispatch exec waybar` caught a frame
rendered before the new CSS applied, which read as "the selector doesn't work".
**SIGUSR2 reloads CSS but NOT bar structure** — config changes (outputs,
bar count) need a full waybar restart (`pkill -x waybar && waybar &`).
SIGUSR2 with the multi-bar config also logs "Cannot merge config" and
later SEGFAULTed on hyprctl reload — avoid it, always full-restart.
**Waybar IPC fix (Jul 13):** this waybar build looks for the Hyprland
socket in `/tmp/hypr/` (Hyprland puts it in `$XDG_RUNTIME_DIR/hypr/`) —
without the symlink the workspaces/window modules silently get NO data.
`exec-once = ln -sfn $XDG_RUNTIME_DIR/hypr /tmp/hypr` in hyprland.conf.

### Cursor invisible wall on rotated Dells (fixed Jul 13)
NVIDIA hw cursor plane rejects positions on transformed+fractional-scale
outputs → mouse hits invisible walls (stuck at x=3888 mid-Dell; absolute
warps worked, relative motion clamped). Fix: `cursor {
no_hardware_cursors = true }` in hyprland.conf (SW cursor, negligible cost).

Active module is **`spark.sh <host>`** for all bars (`custom/spark1|2|3` and
`custom/nas`). The `spark1.sh`/`spark2.sh`/`spark3.sh` symlinks are legacy/unused.
`spark.sh` parses a fixed positional cache at `/tmp/spark_<host>` (**41
fields on the NAS since Aug 31** — appended `devs` = per-bcachefs-device
`label:reads:writes:sec_rd:sec_wr:io_ticks:fill%:lat_us:temp_mC` packed
`|`-list, and `optv` = optane used|size|temp; older hosts still hit the
38/39-field cases); changing emitted fields means updating `cmd`, the
success `read`, the cache `echo`, and the `case $(... wc -w)` blocks —
fragile, so prefer repurposing slots. One transition cycle after a field
change computes garbage deltas from the old cache layout — clamp, don't
trust, the first sample.

### CPU Calculation
Must count `iowait` ($6) as idle, not just `idle` ($5):
```
100-(($5+$6)*100/($2+$3+$4+$5+$6+$7+$8))
```

### NAS disk = bcachefs `/pool` (fixed Jul 2026)
After the NAS Debian reinstall, the data pool moved from UGOS `/volume1` to
**bcachefs `/pool`** (2× Lexar SSD + 2× Exos HDD; tiered foreground/promote→ssd,
background→hdd; 2× replicas; lz4+zstd).
- **DSK** was silently showing `df /` (110 GB OS disk, ~14%) because the old
  `[ -d /volume1 ] && disk=/volume1` fell through to `/`. Now checks `/proc/mounts`
  for `/pool` then `/volume1` → reports the real pool (~3%). **Non-silent**: if a
  pool dir exists but is NOT mounted (mount failure), cmd emits `-1` and DSK renders
  red `DSK NO-POOL` instead of silently reporting `/`. Sparks legitimately use `/`.
  The DSK label shows human-readable **used storage** (e.g. `7.7T`), not %, next to
  the fill bar; the probe emits `pct|used` packed into the one disk field (`d` var
  split client-side on `|`), so DSK didn't grow the field count (it later grew
  26→38 for bcachefs IO rates + per-algo compression — below).
- `md1`/`md2` RAID devices are gone (only `md127`, the read-only old RAID6). The
  NAS module packs **16 bcachefs metrics** into the cache: slots 20-23 = `bc_saved`
  (compression saved GiB), `du` (cumulative `data_update`+`reconcile_data` bytes → DST rate),
  `bc_ratio` (blended ratio ×100), `bc_backlog` (**re-used Aug 13 2026 for the RCL group** —
  was vestigial after RB was dropped; now holds `bcachefs fs usage` "Pending reconcile"
  bytes packed `replicas|compression|target|other|metadata`, the `d`-field `pct|used|ssd`
  packing trick reused so the field count stayed 38 and no `case wc -w` arm changed);
  slots 26-32
  (grew format 26→33) = SSD/HDD tier cumulative sectors r/w (throughput), HDD
  writes-completed & ms-writing (write await, diskstats fields 8/11), and summed
  per-drive `dev-*/io_errors` (read+write+checksum, creation-section → `errs`); slots 33-37
  = per-algo compression from `compression_stats` (`lz4log lz4r zstdlog zstdr inclog`:
  lz4/zstd logical-GiB + ratio×100, incompressible logical-GiB).
  Displayed (NAS only): `CMP:<saved>/<ratio>x lz4 <log>T/<r>x zstd <log>T/<r>x inc <log>T DST:<rate>M`
  (overall saved/ratio kept, PLUS per-algo logical size + ratio; lz4=pending-zstd-recompress,
  inc=incompressible) then `RCL r<repl> c<cmpr> t<tgt>` (Aug 13 2026 — bcachefs
  **Pending reconcile** backlog: r=extra copies owed by the 3x build, c=awaiting
  lz4→zstd recompress, t=on the wrong target device i.e. SSD→HDD destage; a yellow
  `+<n>` appends if any other category — checksum/erasure_code/high_priority/pending/
  stripes — or the metadata column goes nonzero, so unusual states surface without
  spending width when they are zero) then
  `SSD <w>↓<r>↑MB HDD <w>↓<r>↑MB <await>ms` — writes↓ on the LEFT, reads↑ on the RIGHT
  (user pref; note this is OPPOSITE the network rx/tx ↓↑ at the bar's end), fixed-width
  %4d MB/s columns so digits change in place without shifting layout, + HDD write await.
  Plus a red `ERR:<n>` shown only when summed drive io_errors > 0 (silent when healthy).
- **CG group added Aug 17 2026 (cache format 38→39 fields).** Field 39 = `cgv`,
  packed `lexar1:<congested%>:<median_read_us>|lexar2:...` from bcachefs
  `dev-*/congested` (lines `current: NN%` + `median read latency: <v> <us|ms|s>`,
  units normalized to µs remote-side). Rendered on nas2 as verbose PER-DRIVE
  segments (user request Aug 17: no mental decoding): `lexar1 congested  89%
  read  2.0ms lexar2 congested  77% read  3.0ms`, each segment individually
  **yellow (was red until Sep 9 2026 — user: high congestion is not critical,
  it only throttles promotes onto that device)** when ITS congested ≥50% or
  median read ≥3 ms (the sick drive lights up, not the group); red
  `congestion:?` stays red when the sysfs read fails (non-silent).
  Segments sort by label so lexar1 always leads (glob order is dev-1=lexar2
  first). Row measured 196 visible chars, 193 physical px margin via the grim
  recipe — fits with room for the stale suffix. Motivation: `IO:%`
  (io-PSI avg60) reads the same for busy-and-fine vs congested, and the NAS
  kernel 7.1.3 diskstats bug poisons w_await/aqu-sz (see ~/CLAUDE.md) — the
  bcachefs congested score is a latency-over-threshold vote by the fs itself and
  the median read latency is the actual congestion mechanism (btree read
  pressure). NB the % is relative to each device's OWN adaptive threshold —
  lexar1 vs lexar2 percentages are not directly comparable; the rd ms are.
  Sparks emit `-1` for the field (constant count); old 38-word caches still
  parse via the kept 38 arm.
  Dropped the old `bc_ssd` SSD-share (redundant with DSK-field `SSD:<fill>%`) and the RB field.
- **Sysfs sources changed with the DKMS bcachefs upgrade (Jul 2026):** the old
  monolithic `internal/accounting` file is GONE — `rebalance` → `reconcile` refactor.
  New non-root sources under `/sys/fs/bcachefs/<uuid>/`: `compression_stats` (human
  `T/G/M/k` — `tb()` awk parses suffix→bytes; per-algo logical(uncompressed)+ratio for
  lz4/zstd/incompressible extracted directly for display; `bc_saved` gate still =
  Σ(uncompressed−compressed) over lz4+zstd), `counters/data_update`+`counters/reconcile_data`
  "since mount" summed (DST = background-movement rate: copygc + reconcile). **RB was
  DROPPED (Jul 8):** `reconcile_scan_pending` (its old source) tracks only the SCAN queue
  — it stays 0 once the scan has found the work, NOT pending bytes — so it read 0 while
  reconcile churned 8T of `reconcile_data`. Misleading; `reconcile_data` in DST captures
  the activity instead. **"exposes no clean rebalance-backlog counter" was WRONG (fixed
  Aug 13 2026)** — it is not in sysfs, but the **CLI** has it: `bcachefs fs usage /pool`
  prints a `Pending reconcile:` section (`data`/`metadata` columns × up to 8 category
  rows: replicas, checksum, erasure_code, compression, target, high_priority, pending,
  stripes). That IS the real backlog, and it is now the RCL group. Parse gotchas: only
  **nonzero rows are printed**, so the parser must be name-keyed and treat absent rows
  as 0 (never positional); plain `fs usage` gives raw bytes (format client-side), `-h`
  gives `864M`/`2.36T`; the section ends at the first blank line. Both NAS builds
  (`/usr/local/sbin/bcachefs`, `~/.local/bin/bcachefs`) agree. Costs 70-95 ms and the
  probe **already ran it** for the SSD fill %, so the call is hoisted into `$FU` and
  both consumers read that — no extra remote work.
  Symptom of the break: `find -name accounting` empty → whole bcachefs block (gated on
  `bc_saved≥0`) vanished = "RB no longer showing".
- Per-tier throughput sums `/proc/diskstats` sectors ($6 read, $10 written, ×512)
  by bcachefs **label** (`ssd.*`/`hdd.*`) resolved from `dev-*/label`+`dev-*/block` —
  robust to `sdh`/`sdi` renumbering across reboots. Rates = cache deltas over
  `rate_dt` (same machinery as network rx/tx), clamped ≥0. HDD **write await** =
  Δms-writing/Δwrites-completed (fields 11/8) = tier saturation signal (~1ms cache-ack
  when idle → 10s-100s ms under load; measures device-ack, NOT platter durability
  unless the write is FUA/flush). Sparks emit defaults
  (constant field count) and gate the whole block off (`host==nas`).
- **bcachefs CLI: INSTALLED since Jul 2026 — the "NOT installed" note below is STALE**
  (kept for the why-no-apt-package reasoning). Two builds exist on the NAS:
  `/usr/local/sbin/bcachefs` (root, Jul 3) and `~/.local/bin/bcachefs` →
  `~/bcachefs-tools/bcachefs` (Jul 5, the one `spark.sh` calls; the probe tests
  `-x ~/.local/bin/bcachefs`). Output identical between them. Historical reason it
  had to be built by hand: Debian 13 (trixie) **dropped `bcachefs-tools`**
  (2025 upstream/Rust-version split), so no apt package. Build deps ARE present
  (cargo 1.85, rustc, libclang-dev). Install = build from source:
  `git clone --depth 1 https://github.com/koverstreet/bcachefs-tools && cd
  bcachefs-tools && nice -n19 make -j2 && sudo make install`. (Agent auto-mode
  blocks the git-clone+make as untrusted-code integration — run it manually.)
  CLI mostly pretty-prints the same accounting we already read from sysfs; the
  only extras are per-device free space + fragmentation via `bcachefs fs usage -h`.

### SSH probe stalls when NAS is loaded (fixed Jul 2026)
When codex's recovery copy loaded the NAS, the bar sat stale for 20+ min
(`963s!`, `1486s!`). Two causes in `ssh_opts`, both in play (verified 0/8 → 8/8):
1. `ServerAliveInterval=1 ServerAliveCountMax=1` dropped the connection after ONE
   second of unresponsiveness — a busy-but-reachable host gets declared dead.
2. `ControlPath=none` forced a fresh TCP+handshake per probe; under load a fresh
   connect fails, but a new channel on the warm multiplexed master (from
   `~/.ssh/config`, `ControlMaster auto` + `ControlPersist`) is instant.
Fix: removed both — reuse the master, no aggressive keepalive. Dead-host detection
still bounded by `timeout --kill-after=1s $ssh_timeout` + `ConnectTimeout`. NOT a
network/DNS/auth issue (ping 1.7ms, bare ssh 0.01s, cmd runs 0.03s on the NAS).

### OpenRouter module (`waybar/openrouter.sh`)
Shows `OR $<balance> d$<day> w$<week> m$<month>` (Aug 13 2026; was balance only).
**API map — what is actually available with a NORMAL key:**
- `GET /api/v1/credits` → `total_credits`, `total_usage` (ACCOUNT-wide). Balance = diff.
- `GET /api/v1/key` (also reachable as `/api/v1/auth/key`) → `usage_daily`,
  `usage_weekly`, `usage_monthly`, the `byok_usage_*` quartet, `limit` /
  `limit_reset` / `limit_remaining`, `is_free_tier`, `label`. **PER-KEY**, and BYOK
  spend is excluded from the credit figures (it costs no credits).
- `GET /api/v1/activity` → 403 with a normal key. **UNLOCKED Aug 15 2026**: the key
  `OPENROUTER_MANAGEMENT_API_KEY` in `~/.env_api_keys` works. Returns one row per
  **UTC day × model × endpoint × provider**: `usage`, `requests`, `prompt_tokens`,
  `completion_tokens`, `reasoning_tokens`, `byok_*`, `model`, `model_permaslug`,
  `provider_name`, `endpoint_id`. This is the ONLY per-model spend source.
  **Still not a rolling window, and not even today**: COMPLETED UTC days only (a
  `?date=<today>` filter is rejected: "Date must be within the last 30 (completed)
  UTC days"). Exported by `scripts/cloud-spend-exporter.py`; see `~/CLAUDE.md` for
  the metric names and the timestamp series that says which day they describe.
**★ `usage_daily` is CALENDAR, not rolling.** Docs: "OpenRouter credit usage (in USD)
for the current UTC day" (week = current UTC Mon-Sun, month = current UTC month) —
it resets at UTC midnight, matching `limit_reset`'s documented daily/weekly/monthly
cycles. So `d$` is *today so far*, NOT the last 24 h; near UTC midnight it drops to
~0 without spending having stopped. A genuine rolling 24 h would have to be
reconstructed locally by sampling the cumulative `usage` field (the module already
polls every 300 s, so differencing against a ~24 h-old sample would work) — not built.
Balance is colored red under 1 day of the current day's burn, yellow under 3.
**Rolling 24h IS shown (`24h$`), computed locally (Aug 13 2026):** each 300 s run
appends `epoch usage` (the cumulative per-key counter) to
`~/.local/state/waybar-openrouter/usage.tsv`, prunes past 30 h, and differences
against the NEWEST sample that is still ≥24 h old. Prune horizon is 30 h not 24 h
so the reference sample survives short gaps. Shows `24h—` until the history is
long enough — never a partial window passed off as a full day — and red `24h!` if
the state file can't be written (distinct failure from "no history yet"). Once
`cloud-spend-exporter` has run a day, `increase(openrouter_usage_total_usd[24h])`
in Prometheus gives the same number without the local file; the module keeps its
own copy so the bar does not depend on Prometheus being up.

### Vast module (`waybar/vast.sh`)
`VAST $<credit> <runway>h`, e.g. `VAST $26.34 30h`. **Colour is driven by RUNWAY,
not a flat dollar threshold** (Aug 13 2026) — Vast DESTROYS instances when credit
hits zero, so $20 is comfortable at $0.10/h and nearly spent at $2/h. Runway =
credit / Σ`dph_total` over instances with `actual_status == "running"`, which
means the module now hits BOTH `users/current/` and `instances/`. Red under 12 h,
yellow under 48 h, and red under $5 only while something is burning. **An idle
account is never coloured (Sep 9 2026, user request): with nothing running the
balance cannot drain, so the old "always red under $5" was a permanent false
alarm.** The runway suffix is omitted while nothing is running — an idle
account has no meaningful runway.

### ROSpider battery module (`waybar/rospider.sh`, Sep 8 2026)
`custom/rospider` on the MAIN bar (modules-right, before weather; private
config), 60 s, `signal: 7`, JSON. Reads the hexapod's
`/ros_robot_controller/battery` (millivolts) over `ssh rospider` + the
vendor docker/zsh recipe (see `~/git/rospider/CLAUDE.md`), maps a 3S LiPo
table (12.6 V=100 % … 10.0 V=0 %, the board's alarm level) to `🕷 NN%`,
class `warning` <40 % (yellow) / `critical` <20 % (red, bold). **Empty
output = hidden**: a 2 s `/dev/tcp` probe of port 22 first, so a powered-off
robot costs nothing (without it the ssh path burned the full 15 s timeout).
`ROSPIDER_MV=11500 ~/.config/waybar/rospider.sh` tests the formatting offline.

### Weather module (`waybar/weather.sh`)
Open-Meteo (no API key), coords for Mering. **Boot-resilience fix (Jul 30
2026):** after a reboot the module stayed BLANK >5 min — waybar's
`interval:300` did NOT self-heal from the boot-time network gap (network
not up when waybar ran the module at boot+1s). Fix = the script now retries
the fetch up to 8×/5s (~35s) WITHIN one run, so the single boot invocation
rides out the gap instead of relying on the interval. Still prints `wx ?`
on genuine failure (no silent cache fallback — keeps failures visible).
Broad `except Exception` narrowed to `(KeyError,ValueError,TypeError,
JSONDecodeError)`. Manual recover if ever blank: `kill -USR2 $(pgrep -x waybar)`.

## `nft-drift-watch` — the live nftables ruleset vs `/etc/nftables.conf`, every minute (Sep 20 2026)

`scripts/nft-drift-watch` (+ `systemd/user/nft-drift-watch.service`, `tests/nft_drift_watch_test.py`).
Third time a runtime-inserted `iifname "enP7s7" accept` (handle 19, above the drop) opened spark-1's
whole wired LAN — origin still unknown — so this turns the next one into a timestamped event with a
suspect list. Reads via a NOPASSWD `sudo -n nft -a list table inet tailscale_only`
(`systemd/nft-drift-watch.sudoers` → `/etc/sudoers.d/`, 0440); publishes
`~/.local/share/node_exporter/textfile/nft_drift.prom`.
- **Every cycle writes `nft_drift_in_sync` (1/0), `_extra_rules`, `_missing_rules`, `_up` and
  `_last_check_timestamp_seconds`** — so a run of 1s is evidence it LOOKED, and a gap means it was
  NOT RUNNING. Alerts for all three states: `systemd/nft-drift-watch.alerts.yml` (install on the NAS).
- On drift: journal lines naming each extra/missing rule + a snapshot in
  `~/.local/state/nft-drift-watch/drift-<stamp>.txt` (live listing with handles, `ps` oldest-first,
  `who -a`, 600 journal lines, nft/firewall/tailscale units); each unreadable section says so.
  Snapshot on the TRANSITION and then hourly, not per minute. Heartbeat log line hourly while in sync.
- **Parser lessons (all pinned by tests):** the live listing writes `chain input { # handle 1`, so
  strip comments quote-aware BEFORE looking for `{`; the file's `# [who date] why` tags are not
  policy; fold `\` continuations (the log rule spans four lines); `set`/`map` blocks are skipped
  (elements legitimately differ); and nft RE-SERIALISES — it prints the default `burst 5 packets` and
  drops the redundant `meta nfproto ipv4 meta l4proto tcp`, so `CANONICAL` strips those from both
  sides. Anything else still shows as drift, which is the right failure direction.
- Verified live Sep 20: with handle 19 present → `DRIFT: 1 extra`; after the user deleted it →
  `in sync`. Without the sudoers entry it publishes `nft_drift_up 0` and logs `CANNOT READ`.

## `agent-cost-report` — what Claude Code + Codex would have cost over the API (Sep 20 2026)

`scripts/agent-cost-report` + `scripts/agent-cost-pricing.json` + `tests/agent_cost_report_test.py`.
Prices the token counters the agents already write to disk; no API calls, no account access.
`--tool claude|codex|both`, `--by model|day|month|tool`, `--since/--until`, `--json`, `--no-cache`.
Parsed files are cached in `~/.cache/agent-cost-report/parsed.json` keyed by (path, size, mtime)
plus `CACHE_VERSION` — **bump that constant whenever parsing changes** or stale rows survive.
Prices are data, not code: verified Sep 20 2026 against platform.claude.com and
developers.openai.com. Unknown models are printed in an UNPRICED block with their token
counts, never priced by a guessed default.

**Waybar row `agents` (Sep 20 2026, LAST bar in the private config → y=2472 for grim):**
`waybar/agent-cost.sh` (symlinked into `~/.config/waybar/`, `custom/agentcost`, return-type
json, interval 300, min-length 56) renders `CDX $78+? $3.9k  CC $120 $3.0k  FBL $183 $3.0k
30d $9.8k` — bright = TODAY (UTC day), dim `#6272a4` = trailing 30 d, trailing `30d` = all
three groups. Groups: `codex` = every Codex model, `claude` = Claude Code minus Fable,
`claude_fable` = `claude-fable-*`. Yellow `+?` = that group has requests whose model has no
published price (Codex's `codex-auto-review`, 75k requests / 11.1B cache-read tokens here),
so the figure is a FLOOR — never silently omitted. Tooltip carries today/7d/30d/all per group.
Fed by `agent-cost-report --windows` (one JSON blob, all four windows) — **0.2-0.5 s on a warm
cache**, so the module runs the report directly and needs no timer or probe file. The cache
write is atomic (tmp + `os.replace`) because the waybar run and a manual run overlap; a
half-written 23 MB cache would be discarded silently and cost a 12-min full re-parse.
CSS `#custom-agentcost { padding: 0 8px }` — without it the row sits flush on the screen edge
once the text outgrows `min-length`. Row is 65 visible chars / 659 px of the 2149 usable.
**waybar has a USER UNIT here: `systemctl --user restart waybar`** — bar-structure changes need
a full restart (SIGUSR2 only reloads CSS), and the unit avoids `pkill` entirely.

**Quota bars on the same row (`scripts/agent-usage`, Sep 21 2026):**
`CC 5h █░░░░░░░░░  3%  7d ████░░░░░░ 43%  Fable ██████░░░░ 63%  CDX 7d ██░░░░░░░░ 19%`
(module `custom/agentusage`, interval 120, 84 chars; row total with the spend segment
= 1546 px of the 2149 usable). These are SUBSCRIPTION QUOTA percentages, a different
axis from the dollar figures next to them.
**★ PACE ROW under it (`--row time`, bar `agentpace`, Sep 21 2026):** same bars filled by
how far the WINDOW has elapsed, on the next row down, so each pair reads vertically —
usage bar longer than time bar = burning quota faster than the clock. Window lengths:
session 5 h, weekly 7 d, Codex from its own `window_minutes`; elapsed = 1 - (resets_at -
now)/window. **The two rows only work if their visible widths match exactly**, so the
pace row REPEATS the label (dimmed) instead of shortening it, pads an unknown window as
`??????????   ?`, and `#custom-agentpace` must keep the same `padding: 0 8px` as
`#custom-agentusage` — a test asserts markup-stripped `segment()` == `time_segment()`
length. Pace-row COLOUR is the projection at reset (green ≤100 %, yellow >100 %, red
>150 %), and it stays neutral below 5 % elapsed because 3 % used at 2 % elapsed is not
"150 %". Both rows share one fetch through `~/.local/state/agent-usage/payload.json`
(fresh ≤90 s, usable ≤15 min if a fetch fails — then the row says how old it is).
**★ Claude's bars come from the SERVER, not from the transcripts:
`GET https://api.anthropic.com/api/oauth/usage` with the OAuth access token in
`~/.claude/.credentials.json` (`claudeAiOauth.accessToken`) + header
`anthropic-beta: oauth-2025-04-20`.** That is exactly what the `/usage` dialog draws
(verified: dialog 3/42/63 % = endpoint 3/42/63 %). Endpoint found by grepping the CLI
bundle `~/.local/share/claude/versions/<ver>` for `api/oauth/usage` (variants
`?at_wall=1&skip_spend=1`, `?cedar_ember=1&skip_spend=1`). Response: `limits[]` with
`kind` = `session` / `weekly_all` / `weekly_scoped` (+ `scope.model.display_name`,
here Fable), each `percent` / `severity` / `resets_at`, plus `five_hour`/`seven_day`
objects, `extra_usage`, and `seven_day_breakdown` (Claude Code 97 % vs chat 3 %).
Only the dialog's "what's contributing" list is computed locally — nothing in
`~/.claude/` stores the percentages, so they cannot be read offline.
**Codex quota = the last `rate_limits` block in the newest rollout** (`primary.used_percent`,
`window_minutes` 10080 = weekly, `resets_at` epoch; `plan_type`). Read from the file TAIL
(4 MB) — rollouts reach 100s of MB. It is exact as of the last request and afterwards only
an OVER-estimate (the window rolls forward while nothing is logged), so a snapshot older
than 6 h renders dim and its age goes in the tooltip.
Colour = proximity, not activity: ≥70 % yellow, ≥90 % red, plus the server's own
`severity`. A nonzero percent always lights ≥1 cell (a 3 % bar that renders empty reads
as "no data"). Unknown `limits[].kind` values are SKIPPED, never guessed into a bar.

**★ Claude Code writes ONE JSONL LINE PER CONTENT BLOCK** (thinking / text / tool_use), each
repeating the SAME `usage` object → a naive sum double-counts (57,475 records vs 29,143 real
API calls here, i.e. ~2x, $30k vs $15k). Dedupe on `(message.id, requestId)`. A resumed or
forked session also re-writes earlier messages into the new transcript, so dedupe must span
files too.
**★ Codex has TWO transcript formats.** New builds write one `token_usage_record` per response
(`payload.usage` is per response; `turn_token_usage`/`thread_token_usage` are running totals —
summing those inflates hugely). Older builds have no such record: usage is only in
`event_msg`/`token_count`, whose `last_token_usage` is **re-emitted on rate-limit refreshes**
(measured: sum of `last` = 2x the file's own running total). Difference `total_token_usage`
instead. Files carrying both must use the record path only.
**Billing-semantics differences that matter:** Anthropic's `input_tokens` EXCLUDES cache
tokens and the 5m/1h cache-write split lives in `usage.cache_creation`; OpenAI's `input_tokens`
INCLUDES the cached part, so uncached = input - cached. Codex `output_tokens` already contains
`reasoning_output_tokens` — do not add them.
Model attribution: Claude from `message.model`; Codex by joining `token_usage_record.turn_id`
to the preceding `turn_context.model` (old format: the most recent `turn_context`).
No long-context premium exists on Claude 4.6+, so `claude-opus-5[1m]` is an alias of
`claude-opus-5` in the pricing file. Web search is billed separately ($10/1k) and is read from
`server_tool_use.web_search_requests`.

## NAS lockdown tooling (Sep 20 2026) — `systemd/nas/nftables.conf`, `scripts/nas-lockdown-deploy`, `scripts/nas-compose-rebind`

Deployed live Sep 20 11:04–11:07; the story and verification are in `~/CLAUDE.md` (NAS section).
- `nas-lockdown-deploy` (runs ON the NAS as tom, `sudo -n` from the base tmux): `nft -c`, backup,
  **`systemd-run --on-active=240` dead-man switch** deleting the table, `nft -f`; `--confirm` cancels
  the timer and enables `nftables.service`. Verify from spark-1 INSIDE the window — with
  `-o HostKeyAlias=nas` on raw IPs, or a host-key failure masquerades as a lockout.
- `nas-compose-rebind` rewrites `ports:` lines to `127.0.0.1:` + `100.85.146.21:` pairs; handles
  `"9000:9000"`, bare `5434:5432`, `0.0.0.0:` and `${VAR:-0.0.0.0}:` prefixes, `${VAR:-2283}:2283`
  (quoted on output), `/tcp` suffixes and trailing comments; **refuses the whole run on any
  unparseable entry or a file with nothing to rebind**; postgres stacks `docker stop -t 600` first;
  immich via `/usr/local/sbin/immich-compose`. Tests: `tests/nas_compose_rebind_test.py`.
- `spark1-forward-chain-patch` — spark-1 has the same Docker-forward hole; staged, needs sudo.

## ★ `scripts/` and `systemd/` are BLANKET-GITIGNORED — new files need `git add -f`

`.gitignore:24-25` ignores `systemd/` and `scripts/` wholesale ("Local/generated
config trees"), yet every real exporter/unit in them IS tracked — each was force-added.
So a new script lands in the working tree, runs fine, gets referenced from CLAUDE.md,
and is **silently absent from every commit**; `git status` won't even list it as
untracked. Always `git add -f scripts/<new> systemd/user/<new>` and verify with
`git ls-files scripts systemd`. Same class of trap as the gitignored
`tests/keymapp_install_test.sh` that rotted unnoticed — if git can't see it, nothing
will tell you it is missing.

## Swappiness

High iowait (70-80%) despite free RAM was caused by `vm.swappiness=190`.

Fix: `sudo sysctl vm.swappiness=60`

To clear existing swap: `sudo swapoff -a && sudo swapon -a`

## Neovim 0.11 Plugin Updates (Jan 2026)

### Problem
After upgrading to Neovim 0.11.5, startup errors appeared:
1. `nvim-lspconfig` deprecation warning for `require('lspconfig')`
2. `nvim-treesitter` failed - `module 'nvim-treesitter.configs' not found`

### Root Cause
Plugins were pinned to old versions for Neovim 0.9 compatibility.
New nvim-treesitter completely rewrote its API - no more `nvim-treesitter.configs`.

### Solution
1. Removed version pins from all three plugins
2. Updated treesitter config to new API:
   - `require("nvim-treesitter").install({...})` instead of `ensure_installed`
   - `vim.treesitter.start()` in FileType autocmd for highlighting
3. Updated lspconfig to use `vim.lsp.config` and `vim.lsp.enable()`

### New Treesitter API (Neovim 0.11+)
Old API (pre-rewrite):
```lua
require("nvim-treesitter.configs").setup({ ensure_installed = {...}, highlight = { enable = true } })
```

New API:
```lua
require("nvim-treesitter").install({ "lua", "python" })
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua", "python" },
  callback = function() vim.treesitter.start() end,
})
```

### New LSP API (Neovim 0.11+)
Old: `require("lspconfig").pyright.setup({})`
New: `vim.lsp.config.pyright = {}` then `vim.lsp.enable({ "pyright" })`
