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
- Updated: `<leader>o` → `Telescope find_files` (Colemak‑DH home row). Replaces prior `<leader>i`.
- Test: `tests/nvim_filename_search_keymap_test.sh` updated accordingly.

2025‑11‑11: Git shorthand
- "acp" means: run tests, then `git add -A`, `git commit`, and `git push`.
- Commit style: concise, mention mappings/tests/docs; keep it minimal.

2025‑11‑11: Telescope keymap audit (applied)
- Files: standardized on `<leader>o` (find_files). Removed leader duplicates `<leader>f`/`<leader>ff>`; kept `<C-s>` as optional non‑leader.
- Content: standardized on `<leader>s` (live_grep). Removed `<leader>e` and `<leader>fg` duplicates.
- Others kept: `<leader>fs` buffer fuzzy find; `<leader>fb` buffers; `<leader>fh` help; `<leader>:` cmd history.

2025‑11‑11: Leader keys
- `mapleader` is Space; `maplocalleader` is `\`. File: `nvim/init.lua:25–26`.
- Test added: `tests/nvim_leader_test.sh` verifies both assignments.

2025‑11‑11: Hop jump mappings
- Added Hop char jumps: `s` → 2‑char jump (current window); `S` → 2‑char jump across all windows. File: `nvim/lua/plugins/init.lua` in Hop config.
- Test: `tests/nvim_hop_mappings_test.sh` greps for `hint_char2()` and `multi_windows = true`.
- Note: This repurposes default `s`/`S` motions; if you rely on `s` (substitute), consider `gs`/`gS` instead.
- Also: `;` currently runs a custom Hop‑word action.

2025‑11‑11: Why `<Space>f`/`<Space>s` didn’t work
- We deduped and removed `<Space>f`; filename search is now `<Space>o` (see note below about a conflicting map in `keymaps.lua`).
- `<Space>s` mapping lived inside Telescope’s plugin `config`, but Telescope was lazy‑loaded with no key triggers, so the mapping wasn’t created at startup. Fix: set `lazy = false` for Telescope. Test: `tests/nvim_telescope_eager_test.sh`.
- Heads‑up: `nvim/lua/keymaps.lua:63` maps `<Space>o` to previous file (`<C-^>`), overriding the Telescope file search map. Decide which one to keep.

2025‑11‑11: Revert Hop `s`/`S` bindings
- Removed `s`/`S` char-jump mappings per request; semicolon remains the Hop trigger.
- Test updated: `tests/nvim_hop_semicolon_test.sh` ensures `;` mappings exist.
2025‑11‑11: Hop mapping options (proposed)
- Goal: one key then type chars to jump anywhere (Hop).
- 11a (recommend): `;` → `hop.hint_char2()` (current window). Minimal; fast.
- 11b: `;` → `hop.hint_char2({ multi_windows = true })` (all windows).
- 11c: Split: `;` → char2 (current window), `g;` → char2 (all windows).
- 11d: Keep `;` = Hop words; add `<Space>;` → char2 (avoids overriding current `;`).
- 11e: Use `gs`/`gS` for char2 (preserves default `s`/`S`).
- 11f: Line jumping: `<Space>l` → `hop.hint_lines()`; keep `;` for words.
- Note: Pick one; do not keep multiple to avoid muscle-memory conflicts. Remove the old `;` mapping when switching.
2025‑11‑11: Why use Hop char2
- Char2 balances precision and speed: far fewer on‑screen hints than char1, but no word‑boundary constraints like `hint_words`.
- Works uniformly across code, prose, and symbols (camelCase, snake_case, punctuation, paths) without per‑language setup.
- Muscle‑memory friendly: one trigger then two natural letters you already see under the cursor.
- Tradeoffs: char1 is faster to type but noisy; `hint_words` is simple but can’t jump mid‑token. Choose based on preference.

2025‑11‑11: Why `<leader>o` fuzzy file search didn’t work
- Root cause: conflicting map in `nvim/lua/keymaps.lua:63` sets `<leader>o` to `<C-^>` (previous file), overriding Telescope’s `<leader>o` → `find_files` in `nvim/lua/plugins/init.lua:123`.
- Load order: Telescope is eager (`lazy = false`), but `require("keymaps").setup()` runs at the end of `nvim/init.lua`, so the keymaps file wins.
- Added test: `tests/nvim_leader_o_conflict_test.sh` fails if `<leader>o` is defined in `keymaps.lua`.
- Suggested fix: remove the `<leader>o` mapping in `keymaps.lua` and rely on native `<C-^>` for previous file, keeping `<leader>o` exclusively for Telescope.

2025‑11‑12: Prev file on `<leader>p` (applied)
- Change: remapped previous file to `<leader>p` in `nvim/lua/keymaps.lua`; `<leader>o` is now free for Telescope files.
- Test: `tests/nvim_prev_file_leader_p_test.sh` asserts the new mapping.
- Guard: `tests/nvim_leader_o_conflict_test.sh` prevents regressions by failing if `<leader>o` reappears in `keymaps.lua`.

2025‑11‑12: Fixed flaky tests
- `tests/nvim_leader_test.sh`: switched to fixed‑string `rg -F` and corrected backslash escaping for `maplocalleader = "\\"`.
- `tests/nvim_hop_semicolon_test.sh`: simplified to fixed‑string checks; no brittle regexes.
- Full suite now passes locally.

2025‑11‑24: ZSA Keymapp install (user‑space)
- Found `~/Downloads/keymapp-latest.tar.gz`; installed Keymapp to `~/.local/opt/keymapp` and symlinked `~/.local/bin/keymapp`.
- Added desktop entry: `~/.local/share/applications/keymapp.desktop` (icon from the tarball).
- Test added: `tests/keymapp_install_test.sh` verifies binary, icon, and desktop entry.
- Note: udev rules for ZSA (vendor `3297`) were NOT installed due to no root access in this session. Without them, Keymapp may not detect keyboards. Next session with sudo: add `/etc/udev/rules.d/50-zsa.rules` and reload udev.
- Ubuntu 20.04: if Keymapp fails to start, install runtime deps: `libwebkit2gtk-4.0-37 libusb-1.0-0 libgtk-3-0`.

What I learned / keep in mind
- Prefer user‑space installs when escalations aren’t available; leave a minimal test.
- ZSA needs udev `uaccess` rules for Vendor `3297`; add them system‑wide when allowed.
