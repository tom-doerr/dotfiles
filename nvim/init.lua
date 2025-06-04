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
  checker = { enabled = true },
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

-- Theme cycling
local themes = { "gruvbox", "habamax", "desert", "slate" }
local current_theme = 1

function _G.cycle_theme()
  current_theme = current_theme % #themes + 1
  vim.cmd("colorscheme " .. themes[current_theme])
  vim.notify("Colorscheme: " .. themes[current_theme], vim.log.levels.INFO)
end

-- Key mappings
vim.keymap.set('n', '<M-d>', 'ZZ', { noremap = true, silent = true, desc = 'Save and close current window' })
vim.keymap.set('n', '<Leader>b', '<cmd>Black<cr>', { desc = 'Run Black formatter' })
vim.keymap.set('n', '<C-M-l>', '<cmd>lua cycle_theme()<cr>', { desc = 'Cycle color theme' })
vim.keymap.set('i', '<C-M-k>', '<cmd>lua cycle_theme()<cr>', { desc = 'Cycle color theme' })
vim.keymap.set('i', '<Tab>', function() 
    return vim.fn['copilot#Accept']() ~= '' and '<Tab>' or vim.fn['copilot#Accept']()
end, { expr = true })
vim.keymap.set('n', '<C-p>', function() require('Comment.api').toggle.linewise.current() end, 
  { noremap = true, silent = true, desc = 'Toggle comment' })
vim.keymap.set('n', '<leader>h', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlights' })

-- Git commands with safety checks
function _G.safe_git_commit()
  if vim.fn.FugitiveIsGitDir() == 1 then
    vim.cmd('Git commit -v -q %:p | startinsert')
  else
    vim.notify("Not in a git repository", vim.log.levels.WARN)
  end
end

function _G.safe_git_push()
  if vim.fn.FugitiveIsGitDir() == 1 then
    vim.cmd('Git push')
  else
    vim.notify("Not in a git repository", vim.log.levels.WARN)
  end
end

vim.keymap.set('n', '<leader>gc', '<cmd>lua safe_git_commit()<cr>', { desc = 'Git commit current file' })
vim.keymap.set('n', '<leader>gp', '<cmd>lua safe_git_push()<cr>', { desc = 'Git push' })

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

vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
  pattern = "*",
  callback = function()
    if vim.bo.filetype == "" then
      vim.cmd("filetype detect")
    end
  end
})

-- Set appearance
vim.cmd("colorscheme gruvbox")
vim.cmd("TSEnable highlight")

-- Debug mappings
vim.keymap.set('n', '<leader>ts', '<cmd>TSModuleInfo<cr>', { desc = 'Treesitter module info' })
vim.keymap.set('n', '<leader>td', '<cmd>TSHighlightCapturesUnderCursor<cr>', { desc = 'Debug treesitter highlight' })

-- Config reload using lazy.nvim's method
function _G.reload_config()
  require("lazy").reload()
  vim.notify("Plugins reloaded!", vim.log.levels.INFO)
end

vim.keymap.set('n', '<leader>r', '<cmd>lua reload_config()<cr>', { desc = 'Reload plugins' })
