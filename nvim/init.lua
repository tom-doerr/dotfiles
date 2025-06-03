-- Completely disable old vim configs
vim.g.loaded_vimrc = 1
vim.g.loaded_gvimrc = 1
vim.g.did_load_filetypes = 1
vim.g.did_indent_on = 1
vim.g.skip_loading_mswin = 1

-- Remove all old vim paths from runtimepath
local new_rtp = {}
for _, path in ipairs(vim.opt.runtimepath:get()) do
    if not path:match('%.vim') and not path:match('vimfiles') then
        table.insert(new_rtp, path)
    end
end
vim.opt.runtimepath = new_rtp

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

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- Import your plugins
    { import = "plugins" },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
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

-- Basic Neovim settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 50
vim.opt.clipboard = "unnamedplus"

-- Key mappings
vim.keymap.set('n', '<M-d>', '<cmd>w<cr><cmd>q<cr>', { noremap = true, silent = true, desc = 'Save and close current window' })

-- Remove all possible conflicting mappings
local modes = {'n', 'i', 'v', 'c'}
for _, mode in ipairs(modes) do
    pcall(vim.api.nvim_del_keymap, mode, '<C-s>')
    pcall(vim.api.nvim_del_keymap, mode, '<leader>f')
end

-- Telescope mappings
local status_ok, builtin = pcall(require, 'telescope.builtin')
if status_ok then
  vim.keymap.set('n', '<leader>:', builtin.command_history, { desc = 'Telescope command history' })
  vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
  vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
  vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
  vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
end

-- Improved autosave on leaving insert mode
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  callback = function()
    if vim.bo.modifiable and vim.bo.modified then
      vim.cmd("silent! write")
    end
  end,
  desc = "Autosave on leaving insert mode"
})

-- Improved autosave when Neovim loses focus
vim.api.nvim_create_autocmd("FocusLost", {
  pattern = "*",
  callback = function()
    -- Save only modifiable and modified buffers
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) 
         and vim.api.nvim_buf_get_option(buf, "modifiable")
         and vim.api.nvim_buf_get_option(buf, "modified") then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("silent! write")
        end)
      end
    end
  end,
  desc = "Autosave modified buffers when Neovim loses focus"
})
