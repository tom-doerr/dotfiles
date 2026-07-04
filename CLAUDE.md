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
- Display: Samsung S95D 55" OLED at 4K@120Hz
- Terminal: Ghostty with frosted glass blur

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

Active module is **`spark.sh <host>`** for all bars (`custom/spark1|2|3` and
`custom/nas`). The `spark1.sh`/`spark2.sh`/`spark3.sh` symlinks are legacy/unused.
`spark.sh` parses a fixed **26-field** positional cache at `/tmp/spark_<host>`;
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
- `md1`/`md2` RAID devices are gone (only `md127`, the read-only old RAID6). Their
  4 cache slots (positions 20-23) are **repurposed on the NAS for 4 bcachefs
  metrics** (kept field count at 26 — no parser surgery): `bc_saved`=compression
  saved GiB, `bc_ssd`=SSD fast-tier share %, `bc_ratio`=overall ratio ×100,
  `bc_backlog`=rebalance backlog GiB. Displayed (NAS only):
  `CMP:<saved>G/<ratio>x SSD:<share>% RB:<backlog>G`, red if backlog ≥100 GiB.
- Stats read non-root from `/sys/fs/bcachefs/<uuid>/internal/accounting`
  (`compression` lines: $4=uncompressed $5=compressed sectors; `replicas user`
  `[0 1]`=SSD, `[2 3]`=HDD; backlog from top-level `rebalance_work` counter in
  sectors). Uses `find` not a shell glob (zsh `nomatch` safe on sparks).
- **bcachefs CLI:** NOT installed. Debian 13 (trixie) **dropped `bcachefs-tools`**
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
