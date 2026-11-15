---Notes: one file per note, `<deck dir>/notes/N<k>.md`. The first line is the
---header: order-free `key=value` tokens and at most one location token
---(`path:12` or `path:12-20`, relative to the git root), e.g.
---
---  tag=! status=open at=81ebfdf rolling_da/diffda.py:162
---
---The first fenced block below it quotes the code the note is about. The rest
---is the thread. Unknown keys are kept as they are when the header is rewritten.
local anchor = require('slopscoop.anchor')
local config = require('slopscoop.config')
local util = require('slopscoop.util')

local M = {}

---@class slopscoop.Field
---@field key string
---@field value string

---@class slopscoop.Note
---@field id string                  e.g. N12, from the file name
---@field file string                absolute path of the note file
---@field fields slopscoop.Field[]   in header order
---@field location? slopscoop.Anchor
---@field quote string[]             lines of the first fenced block
---@field body string[]              lines after the header

---@class slopscoop.Header
---@field fields slopscoop.Field[]
---@field location? slopscoop.Anchor

---@param line string
---@return slopscoop.Header
function M.parse_header(line)
  local header = { fields = {} }
  for token in line:gmatch('%S+') do
    local key, value = token:match('^([%w_%-]+)=(.*)$')
    if key then
      header.fields[#header.fields + 1] = { key = key, value = value }
    elseif not header.location then
      header.location = anchor.parse(token)
    end
  end
  return header
end

---@param header slopscoop.Header
---@return string
function M.format_header(header)
  local tokens = {}
  for _, field in ipairs(header.fields) do
    tokens[#tokens + 1] = field.key .. '=' .. field.value
  end
  if header.location then
    tokens[#tokens + 1] = anchor.format(header.location)
  end
  return table.concat(tokens, ' ')
end

---@param note slopscoop.Note|slopscoop.Header
---@param key string
---@return string?
function M.get(note, key)
  for _, field in ipairs(note.fields) do
    if field.key == key then
      return field.value
    end
  end
  return nil
end

---@param lines string[]
---@return string[]
local function first_fence(lines)
  local quote, fence = {}, nil
  for _, line in ipairs(lines) do
    local marker = line:match('^%s*(```+)') or line:match('^%s*(~~~+)')
    if fence then
      if marker and marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then
        return quote
      end
      quote[#quote + 1] = line
    elseif marker then
      fence = marker
    end
  end
  return fence and quote or {}
end

---@param file string absolute
---@param lines string[]
---@return slopscoop.Note
function M.parse(file, lines)
  local header = M.parse_header(lines[1] or '')
  local body = vim.list_slice(lines, 2)
  return {
    id = vim.fn.fnamemodify(file, ':t:r'),
    file = file,
    fields = header.fields,
    location = header.location,
    quote = first_fence(body),
    body = body,
  }
end

---@param deck_dir string
---@return string
function M.dir(deck_dir)
  return vim.fs.joinpath(deck_dir, config.options.notes_dir)
end

---Every note of the deck in `deck_dir`, sorted by number.
---@param deck_dir string
---@return slopscoop.Note[]
function M.list(deck_dir)
  local notes = {}
  for _, file in ipairs(vim.fn.globpath(M.dir(deck_dir), 'N*.md', false, true)) do
    if vim.fn.fnamemodify(file, ':t'):match('^N%d+%.md$') then
      notes[#notes + 1] = M.parse(file, util.lines(file) or {})
    end
  end
  table.sort(notes, function(a, b)
    return tonumber(a.id:sub(2)) < tonumber(b.id:sub(2))
  end)
  return notes
end

---The next free note id of a deck, counting unsaved note buffers too.
---@param deck_dir string
---@return string
function M.next_id(deck_dir)
  local dir = M.dir(deck_dir)
  local high = 0
  local function consider(name)
    local k = tonumber(name:match('^N(%d+)%.md$'))
    if k and k > high then
      high = k
    end
  end
  for _, file in ipairs(vim.fn.globpath(dir, 'N*.md', false, true)) do
    consider(vim.fn.fnamemodify(file, ':t'))
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.fs.dirname(name) == dir then
      consider(vim.fn.fnamemodify(name, ':t'))
    end
  end
  return 'N' .. (high + 1)
end

---@param note slopscoop.Note
---@return boolean
function M.is_closed(note)
  return vim.tbl_contains(config.options.closed_statuses, M.get(note, 'status') or 'open')
end

---@class slopscoop.Placement
---@field first integer
---@field last integer
---@field stale boolean  true when the quote no longer matches; the recorded lines are used

---Where a note's code is now: its recorded lines when they still hold the
---quote, else the occurrence of the quote nearest to them, else (stale) the
---recorded lines.
---@param root string
---@param note slopscoop.Note
---@return slopscoop.Placement?
function M.place(root, note)
  local loc = note.location
  if not loc or loc.symbol then
    return nil
  end
  local lines = util.lines(vim.fs.joinpath(root, loc.path))
  if not lines then
    return nil
  end
  local first = math.max(1, math.min(loc.first or 1, #lines))
  local last = math.max(first, math.min(loc.last or first, #lines))
  local quote = note.quote
  if #quote == 0 then
    return { first = first, last = last, stale = false }
  end
  local function holds(at)
    for i, line in ipairs(quote) do
      if lines[at + i - 1] ~= line then
        return false
      end
    end
    return true
  end
  if holds(loc.first or 1) then
    return { first = loc.first, last = loc.first + #quote - 1, stale = false }
  end
  local best
  for at = 1, #lines - #quote + 1 do
    if holds(at) and (not best or math.abs(at - (loc.first or 1)) < math.abs(best - (loc.first or 1))) then
      best = at
    end
  end
  if best then
    return { first = best, last = best + #quote - 1, stale = false }
  end
  return { first = first, last = last, stale = true }
end

---The lines of a new note.
---@param header slopscoop.Header
---@param quote string[]
---@param lang string
---@return string[]
function M.template(header, quote, lang)
  local lines = { M.format_header(header), '' }
  if #quote > 0 then
    lines[#lines + 1] = '```' .. lang
    vim.list_extend(lines, quote)
    lines[#lines + 1] = '```'
    lines[#lines + 1] = ''
  end
  lines[#lines + 1] = ('%s (%s): '):format(config.options.author, os.date('%Y-%m-%d'))
  return lines
end

return M
