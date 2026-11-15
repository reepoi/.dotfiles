---Open notes as vim.diagnostic entries on the code they quote, so signs,
---virtual text, ]d/[d, the diagnostic float and setqflist() all apply.
local deck = require('slopscoop.deck')
local notes = require('slopscoop.notes')
local util = require('slopscoop.util')

local M = {}

M.ns = vim.api.nvim_create_namespace('slopscoop.notes')

local severity = {
  ['!'] = vim.diagnostic.severity.WARN,
  ['?'] = vim.diagnostic.severity.INFO,
  ok = vim.diagnostic.severity.HINT,
}

---Every note of every deck in `root`.
---@param root string
---@return slopscoop.Note[]
function M.all_notes(root)
  local all = {}
  for _, path in ipairs(deck.find(root)) do
    vim.list_extend(all, notes.list(vim.fs.dirname(path)))
  end
  return all
end

---@param note slopscoop.Note
---@return string
function M.message(note)
  local head = ('%s [%s %s]'):format(note.id, notes.get(note, 'tag') or '?', notes.get(note, 'status') or 'open')
  local body, fence = {}, nil
  for _, line in ipairs(note.body) do
    local marker = line:match('^%s*(```+)') or line:match('^%s*(~~~+)')
    if fence then
      if marker then
        fence = false
      end
    elseif fence == nil and marker then
      fence = marker
    elseif vim.trim(line) ~= '' then
      body[#body + 1] = line
    end
  end
  return #body > 0 and head .. '\n' .. table.concat(body, '\n') or head
end

---Set the note diagnostics of `buf`.
---@param buf integer
function M.refresh(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then
    return
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local root = name ~= '' and util.root(name)
  if not root or (#deck.find(root) == 0 and not vim.diagnostic.get(buf, { namespace = M.ns })[1]) then
    return
  end
  local rel = util.relative(root, name)
  local items = {}
  for _, note in ipairs(M.all_notes(root)) do
    if note.location and note.location.path == rel and not notes.is_closed(note) then
      local place = notes.place(root, note)
      if place then
        local message = M.message(note)
        if place.stale then
          message = '[stale] ' .. message
        end
        items[#items + 1] = {
          lnum = place.first - 1,
          end_lnum = place.last - 1,
          col = 0,
          message = message,
          severity = severity[notes.get(note, 'tag') or ''] or vim.diagnostic.severity.INFO,
          source = 'slopscoop',
          code = note.id,
          user_data = { file = note.file },
        }
      end
    end
  end
  vim.diagnostic.set(M.ns, buf, items)
end

---Refresh every loaded buffer.
function M.refresh_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      M.refresh(buf)
    end
  end
end

return M
