return {
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    opts = {
      languages = {
        'bash',
        'c',
        'cpp',
        'diff',
        'html',
        'json',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'python',
        'query',
        'rust',
        'toml',
        'typescript',
        'vim',
        'vimdoc',
        'yaml',
        'zig',
      },
    },
    config = function(_, opts)
      local treesitter = require('nvim-treesitter')

      treesitter.setup()
      treesitter.install(opts.languages)

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('config-treesitter', { clear = true }),
        callback = function()
          if pcall(vim.treesitter.start) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
