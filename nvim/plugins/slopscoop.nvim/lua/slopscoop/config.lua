local M = {}

---@class slopscoop.Keymaps
---@field note string|false      Create a note from the current line or visual selection.
---@field reviewed string|false  Toggle the reviewed mark of the slide under the cursor (deck buffers).
---@field check string|false     Check the deck and fill the quickfix list.

---@class slopscoop.Config
---@field decks string            Glob, relative to the git root, matching deck files.
---@field notes_dir string        Directory, relative to a deck's directory, holding note files.
---@field reviewed_file string    File, relative to a deck's directory, holding reviewed marks.
---@field closed_statuses string[] Note statuses that produce no diagnostic.
---@field keymaps slopscoop.Keymaps
---@field author string           Name written before your entries in a new note's thread.

---@type slopscoop.Config
M.defaults = {
  decks = 'review/*/deck.md',
  notes_dir = 'notes',
  reviewed_file = 'reviewed',
  closed_statuses = { 'resolved', 'wontfix', 'dup' },
  author = 'you',
  keymaps = {
    note = '<leader>rn',
    reviewed = '<leader>rr',
    check = '<leader>rc',
  },
}

---@type slopscoop.Config
M.options = vim.deepcopy(M.defaults)

---@param opts? table
function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts or {})
end

return M
