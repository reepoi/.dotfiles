-- nvim-treesitter `main` branch (the `master` branch does not support 0.12).
-- Parsers are built with the `tree-sitter` CLI and a C compiler.
local ensure_installed = { "javascript", "typescript", "c", "lua", "rust", "typst", "python", "markdown" }

require('nvim-treesitter').install(ensure_installed)

vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('reepoi-treesitter', {}),
    callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then
            return
        end
        -- Install missing parsers on demand (the old `auto_install = true`),
        -- skipping sql as before.
        if lang ~= 'sql' and not vim.treesitter.language.add(lang)
            and vim.list_contains(require('nvim-treesitter').get_available(), lang) then
            require('nvim-treesitter').install(lang):await(function()
                if vim.api.nvim_buf_is_valid(args.buf) then
                    pcall(vim.treesitter.start, args.buf, lang)
                end
            end)
            return
        end
        pcall(vim.treesitter.start, args.buf, lang)
    end,
})
