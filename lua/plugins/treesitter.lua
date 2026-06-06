return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
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
      auto_install = true,
      highlight = true,
      indent = true,
    },
    config = function(_, opts)
      local treesitter = require('nvim-treesitter')

      treesitter.setup()
      treesitter.install(opts.ensure_installed)

      local group = vim.api.nvim_create_augroup('n-treesitter', { clear = true })

      local function start_treesitter(buf, lang)
        local ok = true

        if opts.highlight then
          ok = pcall(vim.treesitter.start, buf, lang)
        elseif opts.indent then
          ok = pcall(vim.treesitter.get_parser, buf, lang)
        end

        if not ok then
          return false
        end

        if opts.indent then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end

        return true
      end

      vim.api.nvim_create_autocmd('FileType', {
        group = group,
        callback = function(event)
          local lang = vim.treesitter.language.get_lang(event.match)
          if not lang then
            return
          end

          if start_treesitter(event.buf, lang) or not opts.auto_install then
            return
          end

          if not vim.list_contains(treesitter.get_available(), lang) then
            return
          end

          treesitter.install({ lang }):await(function(err, ok)
            if err or not ok then
              return
            end

            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(event.buf) then
                start_treesitter(event.buf, lang)
              end
            end)
          end)
        end,
      })
    end,
  },
}
