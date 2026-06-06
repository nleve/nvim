return {
  { 'tpope/vim-sleuth', lazy = false },

  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = {
      style = 'night',
      terminal_colors = true,
    },
    config = function(_, opts)
      require('tokyonight').setup(opts)
      vim.cmd.colorscheme 'tokyonight'
    end,
  },

  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      delay = 50,
      icons = { mappings = vim.g.have_nerd_font },
    },
    config = function(_, opts)
      local wk = require 'which-key'
      wk.setup(opts)

        wk.add {
          { '<leader>a', group = 'Agent' },
          { '<leader>c', group = 'Code' },
          { '<leader>f', group = 'Find' },
          { '<leader>r', group = 'Reload' },
          { '<leader>b', group = 'Buffers' },
          { '<leader>g', group = 'Git' },
          { '<leader>t', group = 'Terminal' },
          { '<leader>w', group = 'Windows' },
          { '<leader>/', group = 'Search' },
        }
      end,
    },

  {
    'echasnovski/mini.nvim',
    event = 'VeryLazy',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.surround').setup()
      require('mini.comment').setup()
    end,
  },

  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      { 's', function() require('flash').jump() end, mode = { 'n', 'x', 'o' }, desc = 'Flash' },
      { 'S', function() require('flash').treesitter() end, mode = { 'n', 'x', 'o' }, desc = 'Flash treesitter' },
    },
  },

  { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
}
