local M = {}

function M.check()
  local health = vim.health
  health.start('slopscoop.nvim')

  if vim.fn.has('nvim-0.12') == 1 then
    health.ok('Neovim ' .. tostring(vim.version()))
  else
    health.error('Neovim 0.12 or later is required, found ' .. tostring(vim.version()))
  end

  if vim.fn.executable('git') == 1 then
    health.ok('git found')
  else
    health.error('git not found', { 'Notes record commits and decks find their repository with git' })
  end

  local config = require('slopscoop.config').options
  local root = require('slopscoop.util').root(vim.fn.getcwd())
  if root then
    local decks = require('slopscoop.deck').find(root)
    health.info(('%d deck(s) match %s in %s'):format(#decks, config.decks, root))
  else
    health.info('The current directory is not in a git repository')
  end

  health.start('slopscoop.nvim: symbol anchors (path::Name)')
  local queries = vim.api.nvim_get_runtime_file('queries/*/slopscoop.scm', true)
  for _, file in ipairs(queries) do
    local lang = vim.fn.fnamemodify(file, ':h:t')
    if not pcall(vim.treesitter.language.add, lang) then
      health.warn(('no treesitter parser for %s'):format(lang), {
        ('Install one (e.g. :TSInstall %s) to use %s symbol anchors'):format(lang, lang),
      })
    else
      local ok, err = pcall(vim.treesitter.query.get, lang, 'slopscoop')
      if ok then
        health.ok(('%s: parser and query'):format(lang))
      else
        health.error(('%s: the slopscoop query does not compile: %s'):format(lang, err))
      end
    end
  end
end

return M
