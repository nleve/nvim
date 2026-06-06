return {
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    cmd = 'Neotree',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {
      close_if_last_window = true,
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
      default_component_configs = {
        indent = { with_markers = true },
        git_status = {
          symbols = {
            added = 'A',
            modified = 'M',
            deleted = 'D',
            renamed = 'R',
            untracked = '?',
            ignored = 'I',
            unstaged = 'U',
            staged = 'S',
            conflict = '!',
          },
        },
      },
    },
  },
}
