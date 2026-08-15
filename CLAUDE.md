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
**Only ONE SSH probe still runs:** `spark.sh nas` renders both rows and writes the
storage half to `/tmp/spark_nas.row2`; `waybar/nas-row2.sh` (module `custom/nas2`)
only displays that file and shows red if it is missing or >30s stale. Do NOT give
nas2 its own probe — the NAS answers slowly under pool load and this would double
the SSH pressure on it. Adjacent GTK labels have NO gap of their own, so any module
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
`spark.sh` parses a fixed **38-field** positional cache at `/tmp/spark_<host>`;
changing emitted fields means updating `cmd`, the success `read`, the cache
`echo`, and the `case $(... wc -w)` blocks — fragile, so prefer repurposing slots.

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
yellow under 48 h, and red at any balance under $5 (too low to start anything even
when idle). The runway suffix is omitted while nothing is running — an idle
account has no meaningful runway.

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
