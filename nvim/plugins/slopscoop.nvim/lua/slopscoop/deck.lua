---A deck is a markdown file: `#` headings are topics, `##` headings slides, and
---`@code <anchor>` lines (outside code fences) point a slide at code.
---A heading may end with `{#slug}`; otherwise its slug comes from its title.
local anchor = require('slopscoop.anchor')
local config = require('slopscoop.config')

local M = {}

---@class slopscoop.DeckAnchor
---@field spec string
---@field anchor? slopscoop.Anchor  nil when the spec does not parse
---@field lnum integer              line of the @code line in the deck

---@class slopscoop.Slide
---@field title string
---@field slug string
---@field topic? string
---@field lnum integer   heading line
---@field last integer   last line of the slide
---@field anchors slopscoop.DeckAnchor[]

---@class slopscoop.Deck
---@field path string    absolute
---@field dir string     absolute
---@field root string    git root
---@field slides slopscoop.Slide[]

---@param title string
---@return string
function M.slugify(title)
  local slug = title:lower():gsub('[^%w]+', '-'):gsub('^%-+', ''):gsub('%-+$', '')
  return slug
end

---@param line string
---@return string? title
---@return string? slug
local function heading_title(line)
  local title = vim.trim(line)
  local text, slug = title:match('^(.-)%s*{#([%w_%-]+)}$')
  if text then
    return text, slug
  end
  return title, M.slugify(title)
end

---Parse deck `lines`.
---@param lines string[]
---@return slopscoop.Slide[]
function M.parse(lines)
  local slides = {} ---@type slopscoop.Slide[]
  local topic ---@type string?
  local current ---@type slopscoop.Slide?
  local fence ---@type string?
  local function close(lnum)
    if current then
      current.last = lnum
      current = nil
    end
  end
  for lnum, line in ipairs(lines) do
    local marker = line:match('^%s*(```+)') or line:match('^%s*(~~~+)')
    if fence then
      if marker and marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then
        fence = nil
      end
    elseif marker then
      fence = marker
    else
      local level, text = line:match('^(#+)%s+(.+)$')
      if level == '#' then
        close(lnum - 1)
        topic = heading_title(text)
      elseif level == '##' then
        close(lnum - 1)
        local title, slug = heading_title(text)
        current = { title = title, slug = slug, topic = topic, lnum = lnum, last = #lines, anchors = {} }
        slides[#slides + 1] = current
      elseif current then
        local spec = line:match('^@code%s+(%S+)%s*$')
        if spec then
          current.anchors[#current.anchors + 1] = { spec = spec, anchor = anchor.parse(spec), lnum = lnum }
        end
      end
    end
  end
  close(#lines)
  return slides
end

---@param path string absolute path of a deck file
---@param lines? string[] defaults to the file's current lines
---@return slopscoop.Deck?
function M.load(path, lines)
  local util = require('slopscoop.util')
  local root = util.root(path)
  if not root then
    return nil
  end
  lines = lines or util.lines(path) or {}
  return { path = path, dir = vim.fs.dirname(path), root = root, slides = M.parse(lines) }
end

---@param deck slopscoop.Deck
---@param lnum integer
---@return slopscoop.Slide?
function M.slide_at(deck, lnum)
  for _, slide in ipairs(deck.slides) do
    if lnum >= slide.lnum and lnum <= slide.last then
      return slide
    end
  end
  return nil
end

---The anchor a cursor at `lnum` selects in `slide`: the last @code line at or
---above it, else the slide's first.
---@param slide slopscoop.Slide
---@param lnum integer
---@return slopscoop.DeckAnchor?
function M.anchor_at(slide, lnum)
  local chosen = slide.anchors[1]
  for _, entry in ipairs(slide.anchors) do
    if entry.lnum <= lnum then
      chosen = entry
    end
  end
  return chosen
end

---Is `path` a deck file under its git root?
---@param path string absolute
---@return boolean
function M.is_deck(path)
  local util = require('slopscoop.util')
  local root = util.root(path)
  if not root then
    return false
  end
  local rel = util.relative(root, path)
  if not rel then
    return false
  end
  return vim.glob.to_lpeg(config.options.decks):match(rel) ~= nil
end

---Every deck file in `root`.
---@param root string
---@return string[]
function M.find(root)
  return vim.fn.globpath(root, config.options.decks, false, true)
end

return M
