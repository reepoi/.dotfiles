vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function()
    use 'wbthomason/packer.nvim'
    use 'ThePrimeagen/git-worktree.nvim'
    use 'nvim-lua/plenary.nvim'
    -- use {'lewis6991/gitsigns.nvim',
         -- config = function() require('gitsigns').setup() end}

    use {'w0rp/ale',
         ft = {'sh', 'zsh', 'bash', 'c', 'cpp', 'cmake', 'html', 'markdown',
               'racket', 'vim', 'tex', 'javascript', 'vue', 'python'},
         cmd = 'ALEEnable',
         config = 'vim.cmd[[ALEEnable]]'}


    use 'nvim-lua/popup.nvim'
    use 'nvim-telescope/telescope.nvim'
    use 'nvim-telescope/telescope-fzy-native.nvim'

    use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate'}

    use {'ThePrimeagen/harpoon',
         config = function()
             require('telescope').load_extension('harpoon')
             -- vim.cmd [[:Telescope harpoon marks]]
         end}

    use {'gruvbox-community/gruvbox', config = 'vim.cmd[[colorscheme gruvbox]]'}
end)

