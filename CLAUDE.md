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