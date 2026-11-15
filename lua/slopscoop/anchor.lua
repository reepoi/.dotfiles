---Anchors name code by file and symbol or line range:
---
---  path                  the whole file
---  path:12               line 12
---  path:12-20            lines 12 to 20
---  path::Class.method    a symbol, found with treesitter
local util = require('slopscoop.util')

local M = {}

---@class slopscoop.Anchor
---@field path string     relative to the git root
---@field symbol? string
---@field first? integer  1-based, inclusive
---@field last? integer

---@class slopscoop.Range
---@field path string     absolute
---@field first integer
---@field last integer

---@param spec string
---@return slopscoop.Anchor?
function M.parse(spec)
  local path, symbol = spec:match('^(.-)::([%w_%.]+)$')
  if path and path ~= '' then
    return { path = path, symbol = symbol }
  end
  local p, a, b = spec:match('^(.-):(%d+)%-(%d+)$')
  if p and p ~= '' then
    return { path = p, first = tonumber(a), last = tonumber(b) }
  end
  p, a = spec:match('^(.-):(%d+)$')
  if p and p ~= '' then
    return { path = p, first = tonumber(a), last = tonumber(a) }
  end
  if spec ~= '' and not spec:find('%s') then
    return { path = spec }
  end
  return nil
end

---@param anchor slopscoop.Anchor
---@return string
function M.format(anchor)
  if anchor.symbol then
    return anchor.path .. '::' .. anchor.symbol
  elseif anchor.first and anchor.first ~= anchor.last then
    return ('%s:%d-%d'):format(anchor.path, anchor.first, anchor.last)
  elseif anchor.first then
    return ('%s:%d'):format(anchor.path, anchor.first)
  end
  return anchor.path
end

---@class slopscoop.Symbol
---@field name string  dotted, qualified by enclosing symbols
---@field first integer
---@field last integer

-- Parsed symbols by language and source text: decorating a deck resolves the
-- same files many times.
local cache, cached = {}, 0

---The symbols that the language's `slopscoop` query captures in `lines`.
---@param lang string
---@param lines string[]
---@return slopscoop.Symbol[]? symbols
---@return string? err
function M.symbols(lang, lines)
  if not pcall(vim.treesitter.language.add, lang) then
    return nil, ('no treesitter parser for %s (install one, e.g. :TSInstall %s)'):format(lang, lang)
  end
  local ok, query = pcall(vim.treesitter.query.get, lang, 'slopscoop')
  if not ok or not query then
    return nil, ('no slopscoop query for %s (add queries/%s/slopscoop.scm)'):format(lang, lang)
  end
  local source = table.concat(lines, '\n')
  local key = lang .. '\0' .. source
  if cache[key] then
    return cache[key]
  end
  local tree = vim.treesitter.get_string_parser(source, lang):parse()[1]

  local found = {} ---@type {node: TSNode, name: string}[]
  local by_id = {} ---@type table<string, string>
  for _, match in query:iter_matches(tree:root(), source, 0, -1) do
    local node, name
    for id, nodes in pairs(match) do
      local capture = query.captures[id]
      if capture == 'symbol' then
        node = nodes[#nodes]
      elseif capture == 'name' then
        name = vim.treesitter.get_node_text(nodes[#nodes], source)
      end
    end
    if node and name then
      found[#found + 1] = { node = node, name = name }
      by_id[node:id()] = name
    end
  end

  local symbols = {}
  for _, entry in ipairs(found) do
    local parts = { entry.name }
    local parent = entry.node:parent()
    while parent do
      local outer = by_id[parent:id()]
      if outer then
        table.insert(parts, 1, outer)
      end
      parent = parent:parent()
    end
    local node = entry.node
    local wrapper = node:parent()
    if wrapper and wrapper:type() == 'decorated_definition' then
      node = wrapper
    end
    local start_row, _, end_row, end_col = node:range()
    if end_col == 0 and end_row > start_row then
      end_row = end_row - 1
    end
    symbols[#symbols + 1] = { name = table.concat(parts, '.'), first = start_row + 1, last = end_row + 1 }
  end
  if cached >= 64 then
    cache, cached = {}, 0
  end
  cache[key], cached = symbols, cached + 1
  return symbols
end

---@param path string
---@return string?
local function language(path)
  local ft = vim.filetype.match({ filename = path })
  return ft and vim.treesitter.language.get_lang(ft) or nil
end

---Resolve `anchor` to lines of a file in `root`.
---@param root string
---@param anchor slopscoop.Anchor
---@return slopscoop.Range? range
---@return string? err
function M.resolve(root, anchor)
  local path = vim.fs.joinpath(root, anchor.path)
  local lines = util.lines(path)
  if not lines then
    return nil, 'no file ' .. anchor.path
  end
  if not anchor.symbol then
    local first, last = anchor.first or 1, anchor.last or #lines
    if first < 1 or last > #lines or first > last then
      return nil, ('%s has %d lines, not %d-%d'):format(anchor.path, #lines, first, last)
    end
    return { path = path, first = first, last = last }
  end
  local lang = language(path)
  if not lang then
    return nil, 'unknown language for ' .. anchor.path
  end
  local symbols, err = M.symbols(lang, lines)
  if not symbols then
    return nil, err
  end
  local matches = vim.tbl_filter(function(symbol)
    return symbol.name == anchor.symbol
  end, symbols)
  if #matches == 0 then
    return nil, ('no symbol %s in %s'):format(anchor.symbol, anchor.path)
  elseif #matches > 1 then
    local at = vim.tbl_map(function(symbol)
      return tostring(symbol.first)
    end, matches)
    return nil, ('symbol %s is ambiguous in %s (lines %s)'):format(anchor.symbol, anchor.path, table.concat(at, ', '))
  end
  return { path = path, first = matches[1].first, last = matches[1].last }
end

---The text of a resolved range.
---@param range slopscoop.Range
---@return string[]
function M.text(range)
  local lines = util.lines(range.path) or {}
  return vim.list_slice(lines, range.first, range.last)
end

return M
