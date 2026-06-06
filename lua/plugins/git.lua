return {
  {
    'barrettruth/diffs.nvim',
    lazy = false,
    init = function()
      vim.g.diffs = {
        integrations = {
          neogit = true,
          gitsigns = true,
        },
      }
    end,
  },
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      numhl = true,
    },
  },

	{
		"NeogitOrg/neogit",
		cmd = "Neogit",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"sindrets/diffview.nvim",
			"nvim-telescope/telescope.nvim",
		},
		opts = {
			kind = "tab",
			disable_hint = true,
			integrations = { diffview = true, telescope = true },
		},
	},

	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewFileHistory" },
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {},
	},
}
