local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {
        'ellisonleao/gruvbox.nvim',
        priority = 1000 ,
        config = function()
            vim.o.background = 'light'
            vim.cmd('colorscheme gruvbox')
        end,
    },
    {
        'nvim-telescope/telescope.nvim', version = 'v0.2.1',
        dependencies = { 'nvim-lua/plenary.nvim' }
    },
    {
        'nvim-telescope/telescope-file-browser.nvim',
        dependencies = {
            'nvim-telescope/telescope.nvim',
            'nvim-lua/plenary.nvim'
        }
    },
    {
        'nvim-telescope/telescope-ui-select.nvim',
        dependencies = {
            'nvim-telescope/telescope.nvim',
            'nvim-lua/plenary.nvim'
        }
    },
    {'tpope/vim-fugitive'},
    {
        'ThePrimeagen/harpoon',
        branch = 'harpoon2',
        dependencies = {
            'nvim-lua/plenary.nvim',
            'nvim-telescope/telescope.nvim'
        }
    },
    {'christoomey/vim-tmux-navigator'},
    {
        'nvim-treesitter/nvim-treesitter',
        branch = 'main',
        lazy = false,
        build = ':TSUpdate',
    },
    {'mbbill/undotree'},
    {
        'neovim/nvim-lspconfig',
        dependencies = {
            {'mason-org/mason.nvim'},
            {'mason-org/mason-lspconfig.nvim'},

            {'j-hui/fidget.nvim', opts = {} },
        },
    },
    {
        'folke/lazydev.nvim',
        ft = 'lua',
        opts = {
            library = {
                { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
            },
        },
    },
    {
        -- Autocompletion
        'hrsh7th/nvim-cmp',
        dependencies = {
            -- Snippet Engine & its associated nvim-cmp source
            {
                'L3MON4D3/LuaSnip',
                version = 'v2.*'
            },
            'saadparwaiz1/cmp_luasnip',

            -- Adds LSP completion capabilities
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-path',

            -- Adds a number of user-friendly snippets
            'rafamadriz/friendly-snippets',
        },
    },
    {'folke/which-key.nvim', opts = {} },
    {
        'nvim-lualine/lualine.nvim',
        opts = {
            options = {
                icons_enabled = false,
                theme = 'gruvbox',
                component_separators = '|',
                section_separators = '',
            },
        },
    },
    {
        'lukas-reineke/indent-blankline.nvim',
        main = 'ibl',
        opts = {},
    },
    {
        'numToStr/Comment.nvim',
        opts = {
            toggler = {
                line = '<C-_>', -- Ctrl+/
            },
            opleader = {
                line = '<C-_>', -- Ctrl+/
            },
        },
    },
    {
        'mfussenegger/nvim-dap',
        dependencies = {
            'mfussenegger/nvim-dap-python',
            'rcarriga/nvim-dap-ui',
            'theHamsta/nvim-dap-virtual-text',
            'nvim-neotest/nvim-nio',
            'mason-org/mason.nvim',
        }
    },
    {
        'chomosuke/typst-preview.nvim',
        lazy = false, -- or ft = 'typst'
        version = '1.*',
        opts = {
            ['tinymist'] = 'tinymist',
        },
    },
    {
        'Olical/conjure',
        ft = { 'clojure', 'fennel' }, -- etc
        lazy = true,
        init = function()
          -- Set configuration options here
          -- Uncomment this to get verbose logging to help diagnose internal Conjure issues
          -- This is VERY helpful when reporting an issue with the project
          -- vim.g["conjure#debug"] = true
        end,
    },
    {
        'MeanderingProgrammer/render-markdown.nvim',
        ft = 'markdown',
        dependencies = { 'nvim-treesitter/nvim-treesitter' },
        opts = {
            latex = { enabled = false },
        },
    },
    {
        -- git subtree of ~/GitHub/slopscoop.nvim (see `git subtree pull/push`).
        dir = vim.fn.stdpath('config') .. '/plugins/slopscoop.nvim',
        name = 'slopscoop.nvim',
        -- lazy doesn't build help tags for `dir` plugins; (re)build them when
        -- doc/tags is missing or older than the help file.
        init = function(plugin)
            local doc = plugin.dir .. '/doc'
            local tags = vim.uv.fs_stat(doc .. '/tags')
            local txt = vim.uv.fs_stat(doc .. '/slopscoop.txt')
            if txt and (not tags or tags.mtime.sec < txt.mtime.sec) then
                vim.cmd.helptags(vim.fn.fnameescape(doc))
            end
        end,
        opts = {
            author = 'Taos',
            keymaps = {
                -- <leader>rn is LSP rename, so slopscoop uses <leader>s.
                note = '<leader>sn',
                reviewed = '<leader>sr',
                check = '<leader>sc',
            },
        },
    },
})
