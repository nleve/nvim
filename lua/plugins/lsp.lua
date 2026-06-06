return {
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'williamboman/mason.nvim', config = true },
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
      'hrsh7th/cmp-nvim-lsp',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('n-lsp-attach', { clear = true }),
        callback = function(event)
          local buf = event.buf
          local client = vim.lsp.get_client_by_id(event.data.client_id)

          local function bmap(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
          end

          bmap('n', 'gd', function()
            require('telescope.builtin').lsp_definitions()
          end, 'LSP: Definition')
          bmap('n', 'gr', function()
            require('telescope.builtin').lsp_references()
          end, 'LSP: References')
          bmap('n', 'gI', function()
            require('telescope.builtin').lsp_implementations()
          end, 'LSP: Implementation')
          bmap('n', '<leader>ca', vim.lsp.buf.code_action, 'Code action')
          bmap('n', '<leader>cr', vim.lsp.buf.rename, 'Rename')
          bmap('n', 'K', vim.lsp.buf.hover, 'Hover')
          bmap('n', '<C-k>', vim.lsp.buf.signature_help, 'Signature help')

          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            vim.lsp.inlay_hint.enable(false, { bufnr = buf })
          end
        end,
      })

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

      local servers = {
        clangd = {},
        lua_ls = {
          settings = {
            Lua = {
              runtime = {
                version = 'LuaJIT',
              },
              completion = { callSnippet = 'Replace' },
              diagnostics = {
                globals = { 'vim' },
              },
              workspace = {
                checkThirdParty = false,
                library = {
                  vim.env.VIMRUNTIME,
                },
              },
            },
          },
        },
        pyright = {},
        rust_analyzer = {},
        ts_ls = {},
        zls = {},
      }

      require('mason').setup()

      local ensure_installed = vim.tbl_keys(servers)
      vim.list_extend(ensure_installed, { 'stylua' })
      require('mason-tool-installer').setup({ ensure_installed = ensure_installed })

      require('mason-lspconfig').setup({
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      })
    end,
  },

  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>cf',
        function()
          require('conform').format({ async = true, lsp_format = 'fallback' })
        end,
        desc = 'Format',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function()
        return { timeout_ms = 500, lsp_format = 'fallback' }
      end,
      formatters = {
        stylua = {
          prepend_args = {
            '--indent-type',
            'Spaces',
            '--indent-width',
            '2',
            '--quote-style',
            'AutoPreferSingle',
          },
        },
      },
      formatters_by_ft = {
        lua = { 'stylua' },
      },
    },
  },
}
