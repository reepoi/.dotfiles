local harpoon = require('harpoon')

harpoon:setup({})

local conf = require('telescope.config').values
local function toggle_telescope(harpoon_files)
    local file_paths = {}
    for _, item in ipairs(harpoon_files.items) do
        table.insert(file_paths, item.value)
    end

    require("telescope.pickers").new({}, {
        prompt_title = "Harpoon",
        finder = require("telescope.finders").new_table({
            results = file_paths,
        }),
        previewer = conf.file_previewer({}),
        sorter = conf.generic_sorter({}),
    }):find()
end

-- vim.keymap.set("n", "<leader>hh", function() toggle_telescope(harpoon:list()) end, { desc = 'Open Harpoon menu' })
vim.keymap.set("n", "<leader>hh", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)
vim.keymap.set("n", "<leader>ht", function() harpoon:list():select(1) end)
vim.keymap.set("n", "<leader>hs", function() harpoon:list():select(2) end)
vim.keymap.set("n", "<leader>hr", function() harpoon:list():select(3) end)
vim.keymap.set("n", "<leader>ha", function() harpoon:list():select(4) end)
vim.keymap.set("n", "<leader>hm", function() harpoon:list():append() end)
