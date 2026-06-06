local map = vim.keymap.set
local util = require 'config.util'

map('n', '<Esc>', '<cmd>nohlsearch<CR>')
map('t', '<Esc><Esc>', '<C-\\><C-n>')

map({ 'n', 'i', 'v', 'x', 's', 'o', 'c', 't' }, '<MiddleMouse>', '<Nop>', { desc = 'Disable middle-click paste' })
map({ 'n', 'i', 'v', 'x', 's', 'o', 'c', 't' }, '<2-MiddleMouse>', '<Nop>')
map({ 'n', 'i', 'v', 'x', 's', 'o', 'c', 't' }, '<3-MiddleMouse>', '<Nop>')
map({ 'n', 'i', 'v', 'x', 's', 'o', 'c', 't' }, '<MiddleDrag>', '<Nop>')
map({ 'n', 'i', 'v', 'x', 's', 'o', 'c', 't' }, '<MiddleRelease>', '<Nop>')

map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Prev diagnostic' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostics (loclist)' })
map('n', '<leader>dl', function()
  local config = vim.diagnostic.config()
  local enabled = config.virtual_lines ~= false and config.virtual_lines ~= nil

  vim.diagnostic.config({
    virtual_lines = not enabled,
  })

  vim.notify('Diagnostic virtual lines ' .. (enabled and 'off' or 'on'), vim.log.levels.INFO)
end, { desc = 'Toggle diagnostic virtual lines' })

map('n', '<A-h>', function()
  util.window_or_tmux 'left'
end, { desc = 'Window left' })
map('n', '<A-j>', function()
  util.window_or_tmux 'down'
end, { desc = 'Window down' })
map('n', '<A-k>', function()
  util.window_or_tmux 'up'
end, { desc = 'Window up' })
map('n', '<A-l>', function()
  util.window_or_tmux 'right'
end, { desc = 'Window right' })

map('n', '<leader>i', function()
  vim.cmd.edit(vim.fn.stdpath('config') .. '/init.lua')
end, { desc = 'Edit init.lua' })

map('n', '<leader>n', function()
  vim.cmd.edit(vim.fn.expand('~/notebook.org'))
end, { desc = 'Edit notebook.org' })

map('n', '<leader><leader>', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').commands()
end, { desc = 'Commands' })

map('n', '<leader>ff', function()
  util.lazy_load('telescope.nvim')
  local dir = require('config.util').buffer_dir(0)
  require('telescope.builtin').find_files({ cwd = dir, hidden = true })
end, { desc = 'Find files (buffer dir)' })

map('n', '<leader>fp', function()
  util.lazy_load('telescope.nvim')
  local root = require('config.util').project_root(0)
  require('telescope.builtin').find_files({ cwd = root, hidden = true })
end, { desc = 'Find files (project)' })

map('n', '<leader>fh', function()
  util.lazy_load('telescope.nvim')
  local home = vim.fn.expand('~')
  require('telescope.builtin').find_files({ cwd = home, hidden = true })
end, { desc = 'Find files (~)' })

map('n', '<leader>fo', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').oldfiles()
end, { desc = 'Recent files' })

map('n', '<leader>fr', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').resume()
end, { desc = 'Resume picker' })

map('n', '<leader>fi', function()
  util.lazy_load('telescope.nvim')
  local cfg = vim.fn.stdpath('config')
  require('telescope.builtin').find_files({ cwd = cfg, hidden = true })
end, { desc = 'Find files (init)' })

map('n', '<leader>bb', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').buffers({ sort_mru = true, ignore_current_buffer = true })
end, { desc = 'Buffers' })

map('n', '<leader>bx', '<cmd>bdelete<CR>', { desc = 'Kill buffer' })
map('n', '<leader>bw', '<cmd>bdelete | quit<CR>', { desc = 'Kill buffer + window' })

map('n', '<leader>w/', '<cmd>vsplit<CR>', { desc = 'Split right' })
map('n', '<leader>w-', '<cmd>split<CR>', { desc = 'Split down' })
map('n', '<leader>wx', '<cmd>close<CR>', { desc = 'Close window' })
map('n', '<leader>wo', '<cmd>only<CR>', { desc = 'Only window' })
map('n', '<leader>wT', require('config.util').toggle_window_split, { desc = 'Toggle split orientation' })

map('n', '<leader>//', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').current_buffer_fuzzy_find()
end, { desc = 'Search line (buffer)' })

map('n', '<leader>/r', function()
  util.lazy_load('telescope.nvim')
  require('telescope').extensions.live_grep_args.live_grep_args()
end, { desc = 'Ripgrep (args)' })

map('n', '<leader>/b', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').buffers({ sort_mru = true, ignore_current_buffer = true })
end, { desc = 'Buffers' })

map('n', '<leader>/o', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').treesitter()
end, { desc = 'Outline (treesitter)' })

map('n', '<leader>/i', function()
  util.lazy_load('telescope.nvim')
  if #vim.lsp.get_clients({ bufnr = 0 }) > 0 then
    require('telescope.builtin').lsp_document_symbols()
  else
    require('telescope.builtin').treesitter()
  end
end, { desc = 'Imenu (LSP symbols)' })

map('n', '<leader>/t', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').colorscheme({ enable_preview = true })
end, { desc = 'Theme' })

map('n', '<leader>/e', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').diagnostics({ bufnr = 0 })
end, { desc = 'Diagnostics (buffer)' })

map('n', '<leader>u', function()
  util.lazy_load('telescope.nvim')
  require('telescope').extensions.undo.undo()
end, { desc = 'Undo' })

map('n', '<leader>gg', function()
  util.lazy_load({ 'neogit', 'diffview.nvim' })
  require('neogit').open()
end, { desc = 'Neogit' })

map('n', '<leader>gd', function()
  util.lazy_load('diffview.nvim')
  vim.cmd.DiffviewOpen()
end, { desc = 'Diffview' })

map('n', '<leader>gD', function()
  util.lazy_load('diffview.nvim')
  vim.cmd.DiffviewClose()
end, { desc = 'Diffview close' })

map('n', '<leader>gF', function()
  util.lazy_load('diffview.nvim')
  vim.cmd.DiffviewFileHistory()
end, { desc = 'Repo history' })

map('n', '<leader>gf', function()
  util.lazy_load('diffview.nvim')
  local file = vim.fn.expand('%:p')
  if file == '' then
    return
  end
  vim.cmd('DiffviewFileHistory ' .. vim.fn.fnameescape(file))
end, { desc = 'File history' })

map('n', '<leader>gt', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').git_status()
end, { desc = 'Git status' })

map('n', '<leader>gB', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').git_branches()
end, { desc = 'Branches' })

map('n', '<leader>gT', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').git_stash()
end, { desc = 'Stash' })

map('n', '<leader>gl', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').git_commits()
end, { desc = 'Commits (repo)' })

map('n', '<leader>gL', function()
  util.lazy_load('telescope.nvim')
  require('telescope.builtin').git_bcommits()
end, { desc = 'Commits (file)' })

map('n', '<leader>gn', function()
  util.lazy_load('gitsigns.nvim')
  require('gitsigns').nav_hunk('next')
end, { desc = 'Next hunk' })

map('n', '<leader>gp', function()
  util.lazy_load('gitsigns.nvim')
  require('gitsigns').nav_hunk('prev')
end, { desc = 'Prev hunk' })

map('n', '<leader>gs', function()
  util.lazy_load('gitsigns.nvim')
  require('gitsigns').stage_hunk()
end, { desc = 'Stage hunk' })

map('n', '<leader>gS', function()
  util.lazy_load('gitsigns.nvim')
  require('gitsigns').stage_buffer()
end, { desc = 'Stage file' })

map('n', '<leader>gU', function()
  util.lazy_load('gitsigns.nvim')
  require('gitsigns').reset_buffer_index()
end, { desc = 'Unstage file' })

map('n', '<leader>gu', function()
  util.lazy_load('gitsigns.nvim')
  require('gitsigns').undo_stage_hunk()
end, { desc = 'Unstage hunk' })

map('n', '<leader>gr', function()
  util.lazy_load('gitsigns.nvim')
  if vim.fn.confirm('Discard current hunk?', '&Yes\n&No', 2) ~= 1 then
    return
  end
  require('gitsigns').reset_hunk()
end, { desc = 'Discard hunk' })

map('n', '<leader>gR', function()
  util.lazy_load('gitsigns.nvim')
  if vim.fn.confirm('Discard ALL changes in this file?', '&Yes\n&No', 2) ~= 1 then
    return
  end
  require('gitsigns').reset_buffer()
end, { desc = 'Discard file changes' })

map('n', '<leader>gH', function()
  util.lazy_load('gitsigns.nvim')
  require('gitsigns').diffthis()
end, { desc = 'Diff this file' })

map('n', '<leader>gh', function()
  util.lazy_load('gitsigns.nvim')
  require('gitsigns').preview_hunk()
end, { desc = 'Show hunk' })

map('n', '<leader>gb', function()
  util.lazy_load('gitsigns.nvim')
  require('gitsigns').blame_line({ full = true })
end, { desc = 'Blame line' })

map('n', '<leader>tt', function()
  require('config.util').float_term({ title = 'shell' })
end, { desc = 'Terminal (float)' })

map('n', '<leader>rr', function()
  for name, _ in pairs(package.loaded) do
    if name:match '^config%.' or name:match '^agent_harness' then
      package.loaded[name] = nil
    end
  end

  require('config.options')
  require('config.autocmds')
  require('config.keymaps')

  vim.notify('Reloaded config', vim.log.levels.INFO)
end, { desc = 'Reload config' })

map('n', '<leader>rl', '<cmd>luafile %<CR>', { desc = 'Reload current Lua file' })

map('n', '<leader>tn', function()
  local name = vim.fn.input('Terminal name: ')
  if name == '' then
    return
  end
  require('config.util').float_term({ title = 'term-' .. name })
end, { desc = 'Terminal (named)' })

map('n', '<leader><Tab>', function()
  util.lazy_load('neo-tree.nvim')
  vim.cmd('Neotree toggle reveal')
end, { desc = 'Neo-tree' })
