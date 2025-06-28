-- Disable loading system vimrc files
vim.g.loaded_vimrc = 1
vim.g.loaded_gvimrc = 1
vim.g.skip_loading_mswin = 1

-- Keep filetype detection enabled
vim.cmd('filetype plugin indent on')

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- Safely require lazy and handle any errors
local status_ok, lazy = pcall(require, "lazy")
if not status_ok then
  vim.notify("Failed to load lazy.nvim. Please run :Lazy sync", vim.log.levels.ERROR)
  return
end

-- Set leaders
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Vimwiki configuration
vim.g.vimwiki_list = {{path = '~/vimwiki/', syntax = 'markdown', ext = '.md'}}

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- Import plugins
    { import = "plugins" },
  },
  install = { colorscheme = { "gruvbox" } },
  checker = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "netrw",
        "netrwPlugin",
        "netrwSettings",
        "netrwFileHandlers"
      },
    },
  },
})

-- Plugin update mapping
vim.keymap.set('n', '<Leader>u', '<cmd>Lazy update<cr>', { desc = 'Update plugins' })

-- Basic Neovim settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.swapfile = false          -- Disable swap files
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 50
vim.opt.clipboard = "unnamedplus"

-- Theme cycling with fallback
local themes = { "gruvbox", "habamax", "desert", "slate" }
local current_theme = 1

function _G.cycle_theme()
  current_theme = current_theme % #themes + 1
  local ok, _ = pcall(vim.cmd, "colorscheme " .. themes[current_theme])
  if ok then
    vim.notify("Colorscheme: " .. themes[current_theme], vim.log.levels.INFO)
  else
    vim.notify("Failed to load colorscheme: " .. themes[current_theme], vim.log.levels.ERROR)
  end
end

-- Key mappings
vim.keymap.set('n', '<M-j>', 'o<ESC>', { noremap = true, silent = true, desc = 'Insert new line below' })
vim.keymap.set('n', '<M-k>', 'O<ESC>', { noremap = true, silent = true, desc = 'Insert new line above' })
vim.keymap.set('n', '<M-d>', 'ZZ', { noremap = true, silent = true, desc = 'Save and close current window' })
vim.keymap.set('n', '<Leader>b', '<cmd>Black<cr>', { desc = 'Run Black formatter' })
vim.keymap.set('n', '<C-M-l>', '<cmd>lua cycle_theme()<cr>', { desc = 'Cycle color theme' })
vim.keymap.set('i', '<C-M-k>', '<cmd>lua cycle_theme()<cr>', { desc = 'Cycle color theme' })
vim.keymap.set('i', '<Tab>', function() 
    return vim.fn['copilot#Accept']() ~= '' and '<Tab>' or vim.fn['copilot#Accept']()
end, { expr = true })
-- Toggle comment in normal mode (single line)
vim.keymap.set('n', '<C-p>', function()
    require('Comment.api').toggle.linewise.current()
end, { noremap = true, silent = true, desc = 'Toggle comment' })

-- Toggle comment in visual line mode (multiple lines)
vim.keymap.set('x', '<C-p>', function()
    require('Comment.api').toggle.linewise(vim.fn.visualmode())
end, { noremap = true, silent = true, desc = 'Toggle comment' })

-- Toggle comment in visual block mode (block comments)
vim.keymap.set('x', '<C-b>', function()
    require('Comment.api').toggle.blockwise(vim.fn.visualmode())
end, { noremap = true, silent = true, desc = 'Toggle block comment' })
-- Print variable under cursor
vim.keymap.set('n', '<M-p>', function() _G.print_variable(false) end, { noremap = true, silent = true, desc = 'Print variable' })
vim.keymap.set('n', '<M-S-p>', function() _G.print_variable(true) end, { noremap = true, silent = true, desc = 'Print variable with name' })
vim.keymap.set('n', '<leader>h', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlights' })

-- Insert current military time
vim.keymap.set('n', '<leader>it', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local time_str = os.date("%H%M")
    vim.api.nvim_buf_set_text(0, row, col, row, col, {time_str})
    vim.api.nvim_win_set_cursor(0, {cursor[1], cursor[2] + #time_str})
end, { noremap = true, silent = true, desc = 'Insert military time' })

-- Insert current datetime in T notation
vim.keymap.set('n', '<leader>id', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local datetime_str = os.date("%Y-%m-%dT%H:%M:%S")
    vim.api.nvim_buf_set_text(0, row, col, row, col, {datetime_str})
    vim.api.nvim_win_set_cursor(0, {cursor[1], cursor[2] + #datetime_str})
end, { noremap = true, silent = true, desc = 'Insert datetime in T notation' })

-- Git commands with safety checks
vim.keymap.set('n', '<leader>gc', '<cmd>Git commit -v -q -- %<cr>', { desc = 'Git commit current file' })
vim.keymap.set('n', '<leader>gp', '<cmd>Git push<cr>', { desc = 'Git push' })

-- Debug help
vim.keymap.set('n', '<Leader>?', '<cmd>echo "Leader is: " . g:mapleader<cr>', { desc = 'Debug: Show leader key' })

-- Terminal settings
vim.cmd([[
    set ttimeout
    set ttimeoutlen=50
    set t_RV=
]])

-- Cleanup commands
vim.cmd('silent! delcommand History')

-- Autocommands
local function save_buffers(condition)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) 
       and vim.api.nvim_buf_get_option(buf, "modifiable")
       and vim.api.nvim_buf_get_option(buf, "modified") then
      if not condition or condition(buf) then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("silent! write")
        end)
      end
    end
  end
end

vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  callback = function()
    if vim.bo.modifiable and vim.bo.modified then
      vim.cmd("silent! write")
    end
  end,
  desc = "Autosave on leaving insert mode"
})

vim.api.nvim_create_autocmd("FocusLost", {
  pattern = "*",
  callback = function() save_buffers() end,
  desc = "Autosave modified buffers when Neovim loses focus"
})

-- Save on any text change
vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
  pattern = "*",
  callback = function()
    if vim.bo.modifiable and vim.bo.modified then
      vim.cmd("silent! write")
    end
  end,
  desc = "Autosave on text change"
})

vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
  pattern = "*",
  callback = function()
    if vim.bo.filetype == "" then
      vim.cmd("filetype detect")
    end
  end
})

-- Set filetype for jsonl and ndjson files to json
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = {"*.jsonl", "*.ndjson"},
  callback = function()
    vim.bo.filetype = 'json'
  end,
  desc = "Set filetype for JSON Lines/NDJSON files to json"
})

-- Set appearance with error handling
local colorscheme_ok, _ = pcall(vim.cmd, "colorscheme gruvbox")
if not colorscheme_ok then
  vim.cmd("colorscheme desert")
  vim.notify("Fallback to desert colorscheme", vim.log.levels.WARN)
end

-- Autoreload config on save
local config_dir = vim.fn.stdpath('config')
vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = {
    config_dir .. '/init.lua',
    config_dir .. '/lua/plugins/*.lua'
  },
  callback = function()
    local ok, err = pcall(_G.reload_config)
    if ok then
      vim.notify('Config reloaded!', vim.log.levels.INFO)
    else
      vim.notify('Error reloading config: ' .. err, vim.log.levels.ERROR)
    end
  end,
  desc = 'Reload Neovim config on change'
})

-- Print variable under cursor
function _G.print_variable(debug_mode)
  local word = vim.fn.expand('<cword>')
  if word == '' then
    vim.notify("No variable under cursor", vim.log.levels.WARN)
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]   -- 1-indexed
  local lnum0 = lnum - 1
  local text
  if debug_mode then
    text = string.format('print("%s", %s)', word, word)
  else
    text = string.format('print(%s)', word)
  end
  vim.api.nvim_buf_set_lines(0, lnum0+1, lnum0+1, false, {text})
  vim.api.nvim_win_set_cursor(0, {lnum+1, 0})
end

-- Debug mappings
vim.keymap.set('n', '<leader>ts', '<cmd>TSModuleInfo<cr>', { desc = 'Treesitter module info' })
vim.keymap.set('n', '<leader>td', '<cmd>TSHighlightCapturesUnderCursor<cr>', { desc = 'Debug treesitter highlight' })

-- Config reload using lazy.nvim's method
function _G.reload_config()
  require("lazy").reload()
  vim.notify("Plugins reloaded!", vim.log.levels.INFO)
end

vim.keymap.set('n', '<leader>r', '<cmd>lua reload_config()<cr>', { desc = 'Reload plugins' })
