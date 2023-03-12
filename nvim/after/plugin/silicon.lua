local silicon = require('silicon')
silicon.setup({})

vim.keymap.set("v", "<leader>zc", function() silicon.visualise_api({}) end)
