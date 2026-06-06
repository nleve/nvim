return {
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable('make') == 1
        end,
      },
      'nvim-telescope/telescope-ui-select.nvim',
      'nvim-telescope/telescope-live-grep-args.nvim',
      'debugloop/telescope-undo.nvim',
    },
    opts = function()
      local actions = require('telescope.actions')
      local themes = require('telescope.themes')

      return {
        defaults = {
          sorting_strategy = 'ascending',
          layout_config = {
            prompt_position = 'top',
            width = 0.95,
            height = 0.9,
            preview_cutoff = 80,
          },
          mappings = {
            i = {
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
              ['<C-q>'] = actions.send_selected_to_qflist + actions.open_qflist,
            },
            n = {
              ['q'] = actions.close,
              ['<C-q>'] = actions.send_selected_to_qflist + actions.open_qflist,
            },
          },
        },
        extensions = {
          ['ui-select'] = themes.get_dropdown(),
          undo = {
            side_by_side = true,
            layout_strategy = 'vertical',
            layout_config = { preview_height = 0.6 },
          },
        },
      }
    end,
    config = function(_, opts)
      local telescope = require('telescope')
      telescope.setup(opts)

      pcall(telescope.load_extension, 'fzf')
      pcall(telescope.load_extension, 'ui-select')
      pcall(telescope.load_extension, 'live_grep_args')
      pcall(telescope.load_extension, 'undo')
    end,
  },
}
