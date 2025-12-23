local M = {}

function M.setup()
  local map = vim.keymap.set

  map('n', '<Leader>u', '<cmd>Lazy update<cr>', { desc = 'Update plugins' })
  map('n', '<M-j>', 'o<ESC>', { noremap = true, silent = true, desc = 'Insert new line below' })
  map('n', '<M-k>', 'O<ESC>', { noremap = true, silent = true, desc = 'Insert new line above' })
  map('n', '<M-d>', 'ZZ', { noremap = true, silent = true, desc = 'Save and close current window' })
  map('n', '<Leader>b', '<cmd>Black<cr>', { desc = 'Run Black formatter' })
  map('n', '<C-M-l>', '<cmd>lua cycle_theme()<cr>', { desc = 'Cycle color theme' })
  map('n', '<leader>tc', cycle_theme, { desc = 'Cycle color theme' })
  map('i', '<C-M-k>', '<cmd>lua cycle_theme()<cr>', { desc = 'Cycle color theme' })

  local has_comment, comment_api = pcall(require, "Comment.api")
  if has_comment then
    map('n', '<C-p>', function()
      comment_api.toggle.linewise.current()
    end, { noremap = true, silent = true, desc = 'Toggle comment' })

    map('x', '<C-p>', function()
      comment_api.toggle.linewise(vim.fn.visualmode())
    end, { noremap = true, silent = true, desc = 'Toggle comment' })

    map('x', '<C-b>', function()
      comment_api.toggle.blockwise(vim.fn.visualmode())
    end, { noremap = true, silent = true, desc = 'Toggle block comment' })
  end

  map('n', '<leader>d', function()
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

  map('n', '<M-p>', function()
    _G.print_variable(false)
  end, { noremap = true, silent = true, desc = 'Print variable' })

  map('n', '<M-S-p>', function()
    _G.print_variable(true)
  end, { noremap = true, silent = true, desc = 'Print variable with name' })

  map('n', '<leader>h', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlights' })
  map('n', '<leader>p', '<C-^>', { desc = 'Go to previous file' })

  map('n', '<leader>it', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local time_str = os.date("%H:%M")
    vim.api.nvim_buf_set_text(0, row, col, row, col, { time_str })
    vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + #time_str })
  end, { noremap = true, silent = true, desc = 'Insert time (HH:MM)' })

  map('n', '<leader>td', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local datetime_str = os.date("%Y-%m-%d %H:%M:%S")
    vim.api.nvim_buf_set_text(0, row, col, row, col, { datetime_str })
    vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + #datetime_str })
  end, { noremap = true, silent = true, desc = 'Insert datetime' })

  map('n', '<leader>gc', '<cmd>Git commit -v -q -- %<cr>', { desc = 'Git commit current file' })
  map('n', '<leader>gp', '<cmd>Git push<cr>', { desc = 'Git push' })

  map('n', '<Leader>?', '<cmd>echo "Leader is: " . g:mapleader<cr>', { desc = 'Debug: Show leader key' })
  map('n', '<leader>ts', '<cmd>TSModuleInfo<cr>', { desc = 'Treesitter module info' })
  map('n', '<leader>th', '<cmd>TSHighlightCapturesUnderCursor<cr>', { desc = 'Debug treesitter highlight' })
  map('n', '<leader>r', '<cmd>lua reload_config()<cr>', { desc = 'Reload plugins' })
end

return M
