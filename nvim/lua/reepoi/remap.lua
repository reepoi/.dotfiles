vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = function(mode, keys, func, desc, opts)
    vim.keymap.set(mode, keys, func, vim.tbl_extend("force", { desc = desc }, opts or {}))
end

-- zz that also centers lines near the top of the buffer: Neovim cannot scroll
-- above line 1, so blank virtual lines are added above it and just enough of
-- them are scrolled into view. Mappings below that end in zz use remap = true
-- so they get this version.
local center_ns = vim.api.nvim_create_namespace("center_top")
keymap("n", "zz", function()
    local height = vim.api.nvim_win_get_height(0)
    vim.api.nvim_buf_clear_namespace(0, center_ns, 0, 1)
    vim.cmd("normal! zz")
    -- Screen rows (not buffer lines) short of the middle, so wrapped lines count.
    local need = math.floor((height - 1) / 2) + 1 - vim.fn.winline()
    if need > 0 and vim.fn.line("w0") == 1 then
        local lines = {}
        for _ = 1, height do lines[#lines + 1] = { { "", "" } } end
        vim.api.nvim_buf_set_extmark(0, center_ns, 0, 0, { virt_lines = lines, virt_lines_above = true })
        vim.fn.winrestview({ topline = 1, topfill = need })
    end
end, "Center line, even at the top of the buffer")

keymap("v", "J", ":m '>+1<CR>gv=gv", "Move visual selection down")
keymap("v", "K", ":m '<-2<CR>gv=gv", "Move visual selection up")

keymap("n", "J", "mzJ`z", "[J]oin lines")
keymap("n", "<C-d>", "<C-d>zz", "Page down with cursor centering", { remap = true })
keymap("n", "<C-u>", "<C-u>zz", "Page up with cursor centering", { remap = true })
keymap("n", "n", "nzzzv", "Next search match with cursor centering", { remap = true })
keymap("n", "N", "Nzzzv", "Prev search match with cursor centering", { remap = true })

keymap("x", "<leader>p", [["_dP]])

keymap({ "n", "v" }, "<leader>y", [["+y]])
keymap("n", "<leader>Y", [["+Y]])

keymap({ "n", "v" }, "<leader>d", [["_d]])

keymap("n", "<leader>gd", "<cmd>silent !zellij run -f -- git diff %<CR>")
keymap("n", "<C-f>", "<cmd>silent !zellij run -f -- zellij-sessionizer<CR>")

keymap("n", "<leader>j", "<cmd>cnext<CR>zz", nil, { remap = true })
keymap("n", "<leader>k", "<cmd>cprev<CR>zz", nil, { remap = true })
-- keymap("n", "<leader>k", "<cmd>lnext<CR>zz")
-- keymap("n", "<leader>j", "<cmd>lprev<CR>zz")

-- keymap("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
