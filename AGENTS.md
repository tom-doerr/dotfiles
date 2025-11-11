# Codex Agent Notes (dotfiles)

- Keep changes minimal; no fallbacks; add tests after edits.
- i3 config lives at `i3/config`; `exec --no-startup-id xbindkeys` starts user hotkeys.
- STT mapping source is not in i3: it’s in `~/.xbindkeysrc` → runs `~/git/voice_input/voice_toggle.sh` on `b:9` (mouse button 9).
- Change applied (2025‑11‑01): commented out those two lines in `~/.xbindkeysrc` and backed up to `~/.xbindkeysrc.bak.<timestamp>`.
- Test added: `tests/xbindkeys_no_stt_test.sh` ensures no active (uncommented) `voice_toggle.sh` binding remains.
- Note: `$mod+p` appears twice in `i3/config` (workspace prev vs. `--release` add_anki_screenshot). Consider resolving to a single behavior.

2025‑11‑07: Colemak‑DH nav keys in i3
- Added Colemak nav in `i3/config`: `$mod+n/e/i/o` → focus left/down/up/right.
- Kept existing QWERTY home‑row nav (`j/k/l/;`). Did not change `$mod+h` since it’s used for `split h` here.
- Freed conflicting bindings:
  - Removed `$mod+n`/`$mod+p` workspace next/prev; rely on `$mod+Ctrl+Right/Left` (already present). This also resolves the `$mod+p` conflict with the `--release` Anki screenshot.
  - Removed `layout toggle split` binding to avoid duplicate with exit on `$mod+Shift+e` (use `$mod+q` split toggle instead).
  - Sticky toggle now on `$mod+Shift+a` (freed `$mod+Shift+o` for move‑right).
- Test added: `tests/i3_nav_keys_test.sh` verifies NEIO focus binds exist and conflicts are gone.

2025‑11‑07: Colemak move‑window bindings
- Added `$mod+Shift+n/e/i/o` → move left/down/up/right (tiling moves).
- Left pixel moves on `$mod+Shift+j/k/l/;` for floating windows.
- Updated test to assert move binds and sticky relocation; tests pass.

2025‑11‑07: Resize mode NEIO aliases
- Added `n/e/i/o` in `mode "resize"` mirroring `j/k/l/;`.
- Test added: `tests/i3_resize_neio_test.sh`; all tests pass.

2025‑11‑09: Move stays on Shift
- Reverted move-window to `$mod+Shift+n/e/i/o`.
- Moved exit shortcut to `$mod+Shift+Escape` to avoid conflict with `Shift+e`.
- Tests updated; `i3 -C` clean; reload succeeds.

Notes / potential issues
- i3 `bindsym` is layout‑dependent; enabling both NEIO and JKL provides simple multi‑layout support without `bindcode` complexity.

2025‑11‑07: How to reload i3
- Reload config: press `$mod+Shift+c` (Super+Shift+C).
- CLI alternative: `i3-msg reload` (and `i3-msg restart` if needed).
- If it errors, run `i3 -C` to see the failing line.

2025‑11‑07: Config linkage
- Verified `~/.config/i3/config` is a symlink to `~/git/dotfiles/i3/config` on this system; reloading i3 picks up repo changes.

2025‑11‑07: i3 reload error reported
- Ask user to run `i3 -C` and share the exact error line(s) and line number.
- If not symlinked, validate which file i3 reads: usually `~/.config/i3/config`.

2025‑11‑07: Accidental‑trigger review (suspects)
- `--release $mod+p` → `add_anki_screenshot.sh` at `i3/config:374`; very easy to hit during workspace nav habits.
- `$mod+h` → `split h` at `i3/config:72`; clashes with Vim‑muscle memory for focus.
- `$mod+q` → `split toggle` at `i3/config:74`; near common letters.
- `$mod+b` → `workspace back_and_forth` at `i3/config:67`; surprising workspace flips.
- `$mod+Shift+q` → kill at `i3/config:22`; fat‑finger risk.
- `$mod+Shift+o` → sticky toggle at `i3/config:385`; less risky now, but still close to nav `o`.

Suggested fixes (pending user pick)
- Move Anki screenshot to `$mod+Shift+P` and drop `--release`.
- Consider moving `split h` off `$mod+h` or add HJKL focus and relocate split.
- Optionally comment out `workspace back_and_forth`.
2025‑11‑07: Removed release trigger
- Changed `bindsym --release $mod+p …add_anki_screenshot.sh` to `bindsym $mod+p …` in `i3/config:380`.
- Left `--release $mod+x` untouched for now; can remove if wanted.

2025‑11‑07: Fix move-left not working
- Cause: duplicate binding for `$mod+Shift+n` — `border normal` (i3/config:10) conflicted with new `move left` (i3/config:45). i3 keeps the earlier one and ignores the later, so move-left didn’t fire and reload printed a duplicate-binding error.
- Fix: remapped `border normal` to `$mod+Shift+y`.
- Test: `tests/i3_nav_keys_test.sh` now fails if `$mod+Shift+n` is bound to `border normal`.

2025‑11‑11: Fuzzy‑search shortcuts (current)
- i3 launcher: `$mod+d` → `dmenu_run` (`i3/config:26`). `rofi -show run` exists but is commented (`i3/config:25`).
- Neovim Telescope: `<leader>f` and `<C-s>` → `Telescope find_files` (`nvim/lua/plugins/init.lua:120`, `:121`);
  `<leader>fs` → `current_buffer_fuzzy_find` (`:127`); `<leader>fg` → `live_grep` (`:126`).
- Zsh + fzf: `Ctrl+K` history (`zshrc_custom.sh:166`), `Alt/Ctrl+A` file widget (`:182`, `:183`),
  `Alt/Ctrl+J` z+j dir jump (`:169`, `:170`), `Ctrl+S` opens `nvim` oldfiles picker (`:240`).

Notes
- If “fuzzy search” is intended as the i3 app launcher, consider switching back to `rofi` for true fuzzy matching and replacing the current `dmenu_run`.

2025‑11‑11: Project content search mapping
- Added Neovim mapping: `<leader>e` → `Telescope live_grep` for project-wide content search (Colemak-DH home row). File: `nvim/lua/plugins/init.lua:121–129` area.
- Test: `tests/nvim_project_search_keymap_test.sh` asserts the mapping exists; all tests pass locally.
- Future cleanup (optional): remove duplicate live_grep bindings (`<leader>s`, `<leader>fg`) to keep the surface minimal.

2025‑11‑11: Filename fuzzy search mapping
- Added Neovim mapping: `<leader>i` → `Telescope find_files` (home‑row on Colemak‑DH; pairs with `<leader>e` content search). File: `nvim/lua/plugins/init.lua` near other Telescope maps.
- Test: `tests/nvim_filename_search_keymap_test.sh` verifies the keymap.

2025‑11‑11: Git shorthand
- "acp" means: run tests, then `git add -A`, `git commit`, and `git push`.
- Commit style: concise, mention mappings/tests/docs; keep it minimal.
