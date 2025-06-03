-- Disable loading of old vim plugins and config to prevent conflicts
vim.opt.runtimepath:remove(vim.fn.expand('~/.vim'))
vim.opt.runtimepath:remove('/usr/share/vim/vimfiles')
vim.g.loaded_vimrc = 1
vim.g.loaded_gvimrc = 1

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
vim.keymap.set('n', '<M-d>', 'ZZ', { noremap = true, silent = true, desc = 'Save and close current window' })

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
