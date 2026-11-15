if vim.g.loaded_slopscoop then
  return
end
vim.g.loaded_slopscoop = true

vim.api.nvim_create_user_command('SlopScoop', function(opts)
  require('slopscoop').command(opts)
end, {
  nargs = '?',
  range = true,
  complete = function()
    return require('slopscoop').complete()
  end,
  desc = 'SlopScoop: note | reviewed | check | refresh',
})

for group, link in pairs({
  SlopScoopAnchor = 'ColorColumn',
  SlopScoopReviewed = 'DiagnosticOk',
  SlopScoopNotes = 'DiagnosticInfo',
}) do
  vim.api.nvim_set_hl(0, group, { link = link, default = true })
end

local group = vim.api.nvim_create_augroup('slopscoop', { clear = true })

-- Decks and notes are attached as they are read; other files in a repository
-- with decks get their notes as diagnostics.
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
  group = group,
  callback = function(args)
    local path = vim.api.nvim_buf_get_name(args.buf)
    if path == '' then
      return
    end
    local slopscoop = require('slopscoop')
    if path:sub(-3) == '.md' then
      if require('slopscoop.deck').is_deck(path) then
        slopscoop.attach_deck(args.buf)
        return
      elseif slopscoop.is_note(path) then
        slopscoop.attach_note(args.buf)
        return
      end
    end
    require('slopscoop.diagnostics').refresh(args.buf)
  end,
})

-- A written note or source file can move notes; a written deck redecorates itself.
vim.api.nvim_create_autocmd('BufWritePost', {
  group = group,
  callback = function(args)
    local path = vim.api.nvim_buf_get_name(args.buf)
    local slopscoop = require('slopscoop')
    if slopscoop.is_note(path) then
      slopscoop.refresh()
    else
      require('slopscoop.diagnostics').refresh(args.buf)
      require('slopscoop.view').decorate_all()
    end
  end,
})

-- Files written outside Neovim (notes answered, code fixed): reload changed
-- buffers ('autoread'), then notes and marks.
vim.api.nvim_create_autocmd({ 'FocusGained', 'TermLeave' }, {
  group = group,
  callback = function()
    if next(require('slopscoop.view').sessions) == nil then
      return
    end
    require('slopscoop').refresh()
  end,
})
