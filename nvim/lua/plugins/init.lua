-- Basic plugins configuration
return {
  -- Colorscheme (using gruvbox like your old config)
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        transparent_mode = false,
      })
    end,
  },

  -- Copilot
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept = "<Tab>",
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        panel = { enabled = false },
        filetypes = {
          xml = false,
          fish = true,
        },
      })
    end,
  },

  -- Windsurf (Codeium) AI code completion
  {
    "Exafunction/windsurf.nvim",
    enabled = false, -- Set to true to enable, false to disable
    event = "VeryLazy", -- Or "BufReadPre", "BufNewFile"
    config = function()
      -- Placeholder for Windsurf/Codeium setup
      -- You will likely need to run an authentication command provided by the plugin
      -- e.g., :WindsurfAuth or :CodeiumAuth
      -- require("windsurf").setup({
      --   -- any specific config options from the plugin's documentation
      -- })
      vim.notify("Windsurf (Codeium) plugin added. Set 'enabled = true' and run authentication if needed.", vim.log.levels.INFO)
    end,
  },

  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup {}
    end,
  },

  -- Fuzzy finder
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('telescope').setup({
        defaults = {
          layout_strategy = 'vertical',
          layout_config = {
            vertical = { width = 0.9 }
          },
          mappings = {
            i = {
              ["<C-j>"] = require('telescope.actions').move_selection_next,
              ["<C-k>"] = require('telescope.actions').move_selection_previous,
            }
          },
          preview = {
            treesitter = true
          },
          -- Use gruvbox colors
          color_devicons = true,
          set_env = { COLORTERM = "truecolor" },
        },
        pickers = {
          find_files = {
            theme = "gruvbox_dark",
          },
          live_grep = {
            theme = "gruvbox_dark",
          },
          buffers = {
            theme = "gruvbox_dark",
          },
        }
      })

      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<C-s>', builtin.find_files, { desc = 'Telescope find files' })
      vim.keymap.set('n', '<leader>s', builtin.find_files, { desc = 'Telescope find files' })
      vim.keymap.set('n', '<Space>', builtin.find_files, { desc = 'Telescope find files' })
      vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
      vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
      vim.keymap.set('n', '<leader>:', builtin.command_history, { desc = 'Telescope command history' })
    end,
  },

  -- Treesitter for syntax highlighting (must load at startup)
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    priority = 900,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { 
          "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline",
          "python", "javascript", "typescript", "html", "css", "json", "yaml", "bash"
        },
        auto_install = true,
        sync_install = false,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = true,
        },
        indent = { enable = true },
      })
    end,
  },

  -- LSP Configuration
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      -- "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("mason").setup()
      local lspconfig = require("lspconfig") -- Define lspconfig before mason-lspconfig setup uses it in handler

      -- require("mason-lspconfig").setup({
        -- ensure_installed = { "lua_ls" },
        -- automatic_installation = false,
        -- handlers = {
          -- Generic fallback handler for any server not explicitly handled.
          -- This will be called for servers found by mason-lspconfig that don't have a specific handler below.
          -- function(server_name)
            -- local server_ok, server_config = pcall(require, "lspconfig." .. server_name)
            -- if server_ok and server_config and server_config.setup then
            --   require("lspconfig")[server_name].setup({})
            --   vim.notify("Mason-lspconfig: Automatically configured " .. server_name, vim.log.levels.INFO)
            -- else
            --   vim.notify("Mason-lspconfig: Skipping automatic configuration for " .. server_name .. ". No default lspconfig found or setup function missing.", vim.log.levels.WARN)
            -- end
          -- end,

          -- Default handler (if you want to see it explicitly) -- This comment can be kept or removed
          -- -- function(server_name) 
          -- --   lspconfig[server_name].setup({})
          -- -- end,

          -- Custom handler for lua_ls
          -- ["lua_ls"] = function()
            -- lspconfig.lua_ls.setup({
            --   settings = {
            --     Lua = {
            --       diagnostics = {
            --         globals = { "vim" },
            --       },
            --     },
            --   },
            -- })
          -- end,
        -- },
      -- })
      
      -- Manual setup for lua_ls
      lspconfig.lua_ls.setup({
      --   settings = {
      --     Lua = {
      --       diagnostics = {
      --         globals = { "vim" },
      --       },
      --     },
      --   },
      })
    end,
  },

  -- Hop for motions (replaces EasyMotion)
  {
    "phaazon/hop.nvim",
    branch = "v2", -- Recommended for latest features
    event = "VeryLazy", -- Load when idle, or you could use `keys` to load on first use
    config = function()
      require("hop").setup() -- Initialize hop with default settings

      -- Set custom highlight colors for jump targets
      vim.api.nvim_set_hl(0, "HopNextKey", { fg = "#ff007f", bold = true })
      vim.api.nvim_set_hl(0, "HopNextKey1", { fg = "#ff0090", bold = true })

      -- Store hop module for easier access
      local hop = require("hop")

      -- Normal mode: H then HopWord
      -- This function first moves the cursor to the top of the window (H)
      -- then initiates a word hop.
      local function h_then_hop_words_normal()
        vim.cmd('normal! H') -- Execute H in normal mode, non-recursively and silently
        hop.hint_words()     -- Trigger hop for words
      end
      vim.keymap.set('n', ';', h_then_hop_words_normal, { noremap = true, silent = true, desc = "Hop: H + Word (Normal)" })

      -- Visual and Operator-pending modes: HopWord
      -- In these modes, we just want to hop to a word directly.
      vim.keymap.set({'v', 'o'}, ';', function() hop.hint_words() end, { noremap = true, silent = true, desc = "Hop: Word (Visual/Operator)" })

      -- You can add more hop mappings here if you like. For example:
      -- To hop to any line:
      -- vim.keymap.set('n', '<leader>hl', function() hop.hint_lines() end, { noremap = true, silent = true, desc = "Hop: Line" })
      -- To hop to words after the cursor:
      -- vim.keymap.set('n', '<leader>hw', function() hop.hint_words({ direction = require('hop.hint').HintDirection.AFTER_CURSOR }) end, { noremap = true, silent = true, desc = "Hop: Word After Cursor" })
    end,
  },

  -- Auto completion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
        }, {
          { name = 'buffer' },
        })
      })
    end,
  },

  -- Which-key shows available keymaps
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {}
  },

  -- Commenting support
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    config = function()
      require('Comment').setup()
    end
  },
}
