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

Custom modules: `spark1.sh`, `spark2.sh`, `spark3.sh` (SSH, shows "offline" if unreachable).

### CPU Calculation
Must count `iowait` ($6) as idle, not just `idle` ($5):
```
100-(($5+$6)*100/($2+$3+$4+$5+$6+$7+$8))
```

## Swappiness

High iowait (70-80%) despite free RAM was caused by `vm.swappiness=190`.

Fix: `sudo sysctl vm.swappiness=60`

To clear existing swap: `sudo swapoff -a && sudo swapon -a`
