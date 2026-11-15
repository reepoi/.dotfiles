-- Runtime for the tests: this plugin, mini.test and the parser built by `make deps`.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
-- Prepended, so Neovim's bundled parsers (markdown, ...) stay available.
vim.opt.runtimepath:prepend({ root, root .. '/deps', root .. '/deps/mini.test' })
vim.o.swapfile = false
vim.cmd('runtime plugin/slopscoop.lua')
require('mini.test').setup()
