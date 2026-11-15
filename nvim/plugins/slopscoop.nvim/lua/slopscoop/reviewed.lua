---Reviewed marks: one line per slide, `<slug> <commit> <date> <hash>`, sorted by
---slug. `hash` is the sha256 prefix of the slide's anchored code when it was
---marked, so a mark goes stale when that code changes. Only the plugin writes it.
local anchor = require('slopscoop.anchor')
local config = require('slopscoop.config')
local util = require('slopscoop.util')

local M = {}

---@class slopscoop.Mark
---@field slug string
---@field commit string
---@field date string
---@field hash string

---@param deck slopscoop.Deck
---@return string
function M.path(deck)
  return vim.fs.joinpath(deck.dir, config.options.reviewed_file)
end

---@param deck slopscoop.Deck
---@return table<string, slopscoop.Mark>
function M.read(deck)
  local marks = {}
  local path = M.path(deck)
  if vim.fn.filereadable(path) == 0 then
    return marks
  end
  for _, line in ipairs(vim.fn.readfile(path)) do
    local slug, commit, date, hash = line:match('^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*$')
    if slug then
      marks[slug] = { slug = slug, commit = commit, date = date, hash = hash }
    end
  end
  return marks
end

---@param deck slopscoop.Deck
---@param marks table<string, slopscoop.Mark>
function M.write(deck, marks)
  local slugs = vim.tbl_keys(marks)
  table.sort(slugs)
  local lines = {}
  for _, slug in ipairs(slugs) do
    local mark = marks[slug]
    lines[#lines + 1] = table.concat({ mark.slug, mark.commit, mark.date, mark.hash }, ' ')
  end
  util.write_atomic(M.path(deck), lines)
end

---The hash of a slide's anchored code; anchors that do not resolve count by spec.
---@param deck slopscoop.Deck
---@param slide slopscoop.Slide
---@return string
function M.hash(deck, slide)
  local parts = {}
  for _, entry in ipairs(slide.anchors) do
    local range = entry.anchor and anchor.resolve(deck.root, entry.anchor)
    parts[#parts + 1] = entry.spec
    if range then
      vim.list_extend(parts, anchor.text(range))
    end
  end
  return vim.fn.sha256(table.concat(parts, '\n')):sub(1, 12)
end

---@alias slopscoop.MarkState 'reviewed'|'changed'|nil

---@param deck slopscoop.Deck
---@param slide slopscoop.Slide
---@param marks table<string, slopscoop.Mark>
---@return slopscoop.MarkState
---@return slopscoop.Mark?
function M.state(deck, slide, marks)
  local mark = marks[slide.slug]
  if not mark then
    return nil
  end
  return mark.hash == M.hash(deck, slide) and 'reviewed' or 'changed', mark
end

---Mark `slide` reviewed, or remove its mark. Rereads the file first.
---@param deck slopscoop.Deck
---@param slide slopscoop.Slide
---@return boolean marked
function M.toggle(deck, slide)
  local marks = M.read(deck)
  local marked
  if marks[slide.slug] and M.state(deck, slide, marks) == 'reviewed' then
    marks[slide.slug] = nil
    marked = false
  else
    marks[slide.slug] = {
      slug = slide.slug,
      commit = util.head(deck.root) or 'none',
      date = os.date('%Y-%m-%d') --[[@as string]],
      hash = M.hash(deck, slide),
    }
    marked = true
  end
  M.write(deck, marks)
  return marked
end

return M
