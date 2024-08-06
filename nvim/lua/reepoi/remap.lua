vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = function(mode, keys, func, desc)
    vim.keymap.set(mode, keys, func, { desc = desc })
end

keymap("v", "J", ":m '>+1<CR>gv=gv", "Move visual selection down")
keymap("v", "K", ":m '<-2<CR>gv=gv", "Move visual selection up")

keymap("n", "J", "mzJ`z", "[J]oin lines")
keymap("n", "<C-d>", "<C-d>zz", "Page down with cursor centering")
keymap("n", "<C-u>", "<C-u>zz", "Page up with cursor centering")
keymap("n", "n", "nzzzv", "Next search match with cursor centering")
keymap("n", "N", "Nzzzv", "Prev search match with cursor centering")

keymap("x", "<leader>p", [["_dP]])

keymap({ "n", "v" }, "<leader>y", [["+y]])
keymap("n", "<leader>Y", [["+Y]])

keymap({ "n", "v" }, "<leader>d", [["_d]])

keymap("n", "<leader>gd", "<cmd>silent !zellij run -f -- git diff %<CR>")
keymap("n", "<C-f>", "<cmd>silent !zellij run -f -- zellij-sessionizer<CR>")

keymap("n", "<leader>j", "<cmd>cnext<CR>zz")
keymap("n", "<leader>k", "<cmd>cprev<CR>zz")
-- keymap("n", "<leader>k", "<cmd>lnext<CR>zz")
-- keymap("n", "<leader>j", "<cmd>lprev<CR>zz")

-- keymap("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
