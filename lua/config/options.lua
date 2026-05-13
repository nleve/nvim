vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.cursorline = true

vim.opt.showmode = false

vim.opt.mouse = "a"

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

vim.opt.scrolloff = 10
vim.opt.sidescrolloff = 10

vim.opt.undofile = true
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false

vim.opt.autoread = true

vim.opt.breakindent = true

vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

vim.opt.inccommand = "split"

vim.opt.termguicolors = true

vim.schedule(function()
	vim.opt.clipboard = "unnamedplus"
end)

vim.opt.showtabline = 1
