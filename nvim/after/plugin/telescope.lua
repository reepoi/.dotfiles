local telescope = require('telescope')
local builtin = require('telescope.builtin')

telescope.load_extension('file_browser')
telescope.load_extension('ui-select')

vim.keymap.set("n", "<leader>ff", builtin.git_files, {})
vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
vim.keymap.set("n", "<leader>fh", builtin.find_files, {})
vim.keymap.set("n", "<leader>fa", telescope.extensions.file_browser.file_browser, { desc = "[G]oto [F]iles" })
