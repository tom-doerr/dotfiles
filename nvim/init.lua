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
vim.opt.updatetime = 250
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
vim.keymap.set('n', '<leader>d', function()
    local bufnr = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients and vim.lsp.get_clients({ bufnr = bufnr }) or vim.lsp.buf_get_clients(bufnr)
    if not clients or vim.tbl_isempty(clients) then
        vim.notify('No LSP attached to this buffer', vim.log.levels.WARN)
        return
    end

    local supports_definition = false
    for _, client in pairs(clients) do
        local caps = client.server_capabilities or client.resolved_capabilities
        if caps and (caps.definitionProvider or caps.goto_definition) then
            supports_definition = true
            break
        end
    end

    if supports_definition then
        vim.lsp.buf.definition()
    else
        vim.notify('Attached LSP has no definition capability', vim.log.levels.WARN)
    end
end, { noremap = true, silent = true, desc = 'LSP: go to definition' })
-- Print variable under cursor
vim.keymap.set('n', '<M-p>', function() _G.print_variable(false) end, { noremap = true, silent = true, desc = 'Print variable' })
vim.keymap.set('n', '<M-S-p>', function() _G.print_variable(true) end, { noremap = true, silent = true, desc = 'Print variable with name' })
vim.keymap.set('n', '<leader>h', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlights' })

-- Insert current time in 24h format (HH:MM)
vim.keymap.set('n', '<leader>it', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local time_str = os.date("%H:%M")
    vim.api.nvim_buf_set_text(0, row, col, row, col, {time_str})
    vim.api.nvim_win_set_cursor(0, {cursor[1], cursor[2] + #time_str})
end, { noremap = true, silent = true, desc = 'Insert time (HH:MM)' })

-- Insert current datetime
vim.keymap.set('n', '<leader>td', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local datetime_str = os.date("%Y-%m-%d %H:%M:%S")
    vim.api.nvim_buf_set_text(0, row, col, row, col, {datetime_str})
    vim.api.nvim_win_set_cursor(0, {cursor[1], cursor[2] + #datetime_str})
end, { noremap = true, silent = true, desc = 'Insert datetime' })

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
  callback = function() save_buffers() end,
  desc = "Autosave on leaving insert mode"
})

vim.api.nvim_create_autocmd("FocusLost", {
  pattern = "*",
  callback = function() save_buffers() end,
  desc = "Autosave modified buffers when Neovim loses focus"
})

-- Save on any text change (including substitutions)
vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "CmdlineLeave"}, {
  pattern = "*",
  callback = function()
    save_buffers()  -- Saves all modified buffers that are modifiable
  end,
  desc = "Autosave on text change"
})

-- Save when leaving buffer
vim.api.nvim_create_autocmd("BufLeave", {
  pattern = "*",
  callback = function()
    save_buffers()  -- Saves all modified buffers that are modifiable
  end,
  desc = "Autosave on leaving buffer"
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

-- Print variable under cursor as f-string
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
    text = string.format('print(f"%s: {%s}")', word, word)
  else
    text = string.format('print(f"{%s}")', word)
  end
  vim.api.nvim_buf_set_lines(0, lnum0+1, lnum0+1, false, {text})
  vim.api.nvim_win_set_cursor(0, {lnum+1, 0})
end

-- Auto-reload files changed outside of Neovim, even while unfocused
vim.opt.autoread = true

local uv = vim.loop
local autoread_group = vim.api.nvim_create_augroup("autoread_watchers", { clear = true })
local watchers = {}

local function stop_watch(path)
  local entry = watchers[path]
  if not entry then
    return
  end
  entry.handle:stop()
  entry.handle:close()
  watchers[path] = nil
end

local function schedule_checktime(bufnr)
  if vim.bo[bufnr].modified then
    return
  end
  vim.api.nvim_buf_call(bufnr, function()
    pcall(vim.cmd, 'silent! checktime')
  end)
end

local function start_watch(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  if vim.bo[bufnr].buftype ~= "" then
    return
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return
  end

  local path = uv.fs_realpath(name)
  if not path or watchers[path] then
    return
  end

  local handle = uv.new_fs_event()
  if not handle then
    return
  end

  watchers[path] = { handle = handle, bufnr = bufnr }
  handle:start(path, {}, vim.schedule_wrap(function(err)
    if err then
      return
    end
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      stop_watch(path)
      return
    end
    schedule_checktime(bufnr)
  end))
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufFilePost", "BufWinEnter" }, {
  group = autoread_group,
  callback = function(ev)
    start_watch(ev.buf)
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = autoread_group,
  callback = function(ev)
    local name = vim.api.nvim_buf_get_name(ev.buf)
    if name == "" then
      return
    end
    local path = uv.fs_realpath(name)
    if path then
      stop_watch(path)
    end
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = autoread_group,
  callback = function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      start_watch(bufnr)
    end
  end,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = autoread_group,
  callback = function(ev)
    vim.notify(string.format("Reloaded %s", ev.file), vim.log.levels.INFO, { title = "autoread" })
    vim.schedule(function()
      local bufnr = ev.buf
      if not vim.api.nvim_buf_is_loaded(bufnr) then
        return
      end
      vim.api.nvim_buf_call(bufnr, function()
        pcall(vim.cmd, 'silent! syntax sync fromstart')
      end)
      if vim.treesitter then
        pcall(vim.treesitter.stop, bufnr)
        pcall(vim.treesitter.start, bufnr)
      end
    end)
  end,
})

vim.api.nvim_create_user_command("AutoreadWatchNow", function()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    start_watch(bufnr)
  end
end, {})

vim.api.nvim_create_user_command("AutoreadWatchInfo", function()
  local info = {}
  for path, data in pairs(watchers) do
    table.insert(info, { path = path, bufnr = data.bufnr })
  end
  vim.print(info)
end, {})

vim.cmd("AutoreadWatchNow")

-- Fallback: still poke :checktime on focus/cursor events, but keep it quiet
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "FocusGained" }, {
  group = autoread_group,
  callback = function()
    pcall(vim.cmd, 'silent! checktime')
  end,
})

-- Periodic check in case a watcher misses an event (e.g. network mounts)
local check_timer = uv.new_timer()
local interval = 5000
check_timer:start(interval, interval, vim.schedule_wrap(function()
  local mode = vim.fn.mode(1)
  if mode == 'n' or mode == 'v' or mode == 'c' then
    pcall(vim.cmd, 'silent! checktime')
  end
end))

vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    if check_timer:is_active() then
      check_timer:stop()
      check_timer:close()
    end
    for path in pairs(watchers) do
      stop_watch(path)
    end
  end,
})

-- Debug mappings
vim.keymap.set('n', '<leader>ts', '<cmd>TSModuleInfo<cr>', { desc = 'Treesitter module info' })
vim.keymap.set('n', '<leader>th', '<cmd>TSHighlightCapturesUnderCursor<cr>', { desc = 'Debug treesitter highlight' })

-- Config reload using lazy.nvim's method
function _G.reload_config()
  require("lazy").reload()
  vim.notify("Plugins reloaded!", vim.log.levels.INFO)
end

vim.keymap.set('n', '<leader>r', '<cmd>lua reload_config()<cr>', { desc = 'Reload plugins' })
