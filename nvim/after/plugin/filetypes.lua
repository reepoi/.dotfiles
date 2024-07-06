vim.filetype.add({
    extension = {
        typ = 'typst',
    },
    filename = {
        ['test.typ'] = 'typst',
    },
    pattern = {
        ['*.typ'] = { 'typst', { priority = 10 } },
    }
})

vim.g['filetype_typ'] = 'typst'
