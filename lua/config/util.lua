local M = {}

function M.lazy_load(plugins)
  local ok, lazy = pcall(require, 'lazy')
  if not ok then
    return
  end

  if type(plugins) == 'string' then
    plugins = { plugins }
  end

  lazy.load { plugins = plugins }
end

function M.project_root(bufnr)
  bufnr = bufnr or 0

  local file = vim.api.nvim_buf_get_name(bufnr)
  local dir = file ~= '' and vim.fs.dirname(file) or vim.uv.cwd()

  local root = vim.fs.root(dir, { '.git' })
  if root then
    return root
  end

  return vim.uv.cwd()
end

function M.buffer_dir(bufnr)
  bufnr = bufnr or 0

  local file = vim.api.nvim_buf_get_name(bufnr)
  if file ~= '' then
    return vim.fs.dirname(file)
  end

  return vim.fn.getcwd()
end

function M.float_term(opts)
  opts = opts or {}

  local cwd = opts.cwd or M.project_root(0)
  local cmd = opts.cmd or vim.o.shell
  local title = opts.title or 'term'

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'

  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) * 0.5)
  local col = math.floor((vim.o.columns - width) * 0.5)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  })

  vim.fn.termopen(cmd, { cwd = cwd })
  vim.cmd.startinsert()

  return { buf = buf, win = win }
end

function M.toggle_window_split()
  if vim.fn.winnr('$') ~= 2 then
    return
  end

  local win1 = vim.fn.winnr()
  local win2 = win1 == 1 and 2 or 1

  local buf1 = vim.fn.winbufnr(win1)
  local buf2 = vim.fn.winbufnr(win2)

  local a = vim.fn.win_screenpos(win1)
  local b = vim.fn.win_screenpos(win2)
  local is_vertical = a[1] == b[1]

  vim.cmd.only()
  if is_vertical then
    vim.cmd.split()
  else
    vim.cmd.vsplit()
  end

  vim.cmd.wincmd('w')
  vim.cmd.buffer(buf2)
  vim.cmd.wincmd('w')
  vim.cmd.buffer(buf1)
end

function M.window_or_tmux(direction)
  local directions = {
    left = { key = 'h', tmux = '-L' },
    down = { key = 'j', tmux = '-D' },
    up = { key = 'k', tmux = '-U' },
    right = { key = 'l', tmux = '-R' },
  }

  local target = directions[direction]
  if not target then
    return
  end

  local current_win = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(target.key)

  if vim.api.nvim_get_current_win() ~= current_win or not vim.env.TMUX then
    return
  end

  vim.fn.system { 'tmux', 'select-pane', target.tmux }
end

return M
