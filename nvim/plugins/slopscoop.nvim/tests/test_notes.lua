local H = dofile('tests/helpers.lua')
local MiniTest = require('mini.test')
local eq = MiniTest.expect.equality
local notes = require('slopscoop.notes')

local T = MiniTest.new_set({ hooks = { post_case = H.reset } })

T['header keeps unknown keys and their order'] = function()
  local line = 'status=open zz=1 tag=! at=abc pkg/mod.py:6-9 prio=high'
  local header = notes.parse_header(line)
  eq(header.location, { path = 'pkg/mod.py', first = 6, last = 9 })
  eq(notes.get(header, 'tag'), '!')
  eq(notes.get(header, 'zz'), '1')
  eq(notes.format_header(header), 'status=open zz=1 tag=! at=abc prio=high pkg/mod.py:6-9')
  eq(notes.parse_header('tag=? slide=pairs').location, nil)
end

T['parse takes the id from the file name and the first fenced block as quote'] = function()
  local note = notes.parse('/x/notes/N12.md', {
    'tag=? status=answered pkg/mod.py:6',
    '',
    '```python',
    'def top(x):',
    '```',
    '',
    'you (2026-11-15): why?',
    '```',
    'later block',
    '```',
  })
  eq(note.id, 'N12')
  eq(note.quote, { 'def top(x):' })
  eq(notes.is_closed(note), false)
  eq(notes.is_closed(notes.parse('/x/notes/N1.md', { 'status=resolved' })), true)
  eq(notes.is_closed(notes.parse('/x/notes/N1.md', { 'tag=!' })), false)
end

local function note_at(location, quote)
  local lines = { 'tag=? ' .. location, '', '```python' }
  vim.list_extend(lines, quote)
  vim.list_extend(lines, { '```' })
  return notes.parse('/x/notes/N1.md', lines)
end

T['place'] = function()
  local root = H.repo({ ['pkg/mod.py'] = H.python })
  -- Recorded lines still hold the quote.
  eq(notes.place(root, note_at('pkg/mod.py:6-7', { 'def top(x):', '    def inner():' })), { first = 6, last = 7, stale = false })
  -- The code moved: the nearest occurrence wins.
  eq(notes.place(root, note_at('pkg/mod.py:2', { 'def top(x):' })), { first = 6, last = 6, stale = false })
  eq(notes.place(root, note_at('pkg/mod.py:24', { '        self.a = 1' })), { first = 16, last = 16, stale = false })
  -- The code is gone: stale, at the recorded lines.
  eq(notes.place(root, note_at('pkg/mod.py:6-7', { 'def gone():' })), { first = 6, last = 7, stale = true })
  -- No quote: the recorded lines.
  eq(notes.place(root, notes.parse('/x/notes/N1.md', { 'pkg/mod.py:4' })), { first = 4, last = 4, stale = false })
end

T['next_id counts note files and unsaved note buffers'] = function()
  local root = H.repo({
    ['review/f/deck.md'] = H.deck,
    ['review/f/notes/N2.md'] = { 'tag=?' },
    ['review/f/notes/N10.md'] = { 'tag=?' },
    ['review/f/notes/README.md'] = { 'x' },
  })
  local deck_dir = vim.fs.joinpath(root, 'review/f')
  eq(notes.next_id(deck_dir), 'N11')
  vim.cmd.edit(vim.fs.joinpath(deck_dir, 'notes/N11.md'))
  eq(notes.next_id(deck_dir), 'N12')
  eq(vim.tbl_map(function(n)
    return n.id
  end, notes.list(deck_dir)), { 'N2', 'N10' })
end

return T
