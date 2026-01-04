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

### HDR vs Transparency
HDR (`cm_enabled = true`) breaks window transparency. Currently HDR is on.
To fix transparency: set `cm_enabled = false` in render block.

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
- Transparency looks whitish due to HDR + light default wallpaper

## Zsh Ctrl+J Fuzzy Directory Jump

### Problem
Ctrl+J (fzf_cd) was hanging for several seconds after selecting a directory.

### Root Cause
The for loop `(for d in {1..20}; do find...; done) | fzf` continues after fzf exits.
Each remaining find spawns, gets SIGPIPE, exits - but loop runs all 20 iterations.

### Solution
Added `|| break` to exit loop on SIGPIPE: `find ... 2>/dev/null || break`

Location: `/home/tom/.zshrc` lines 48-56

Note: Same issue exists in fzf-file-widget (Ctrl+A, lines 90-97).
