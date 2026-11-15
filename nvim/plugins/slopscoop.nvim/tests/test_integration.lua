local H = dofile('tests/helpers.lua')
local MiniTest = require('mini.test')
local eq = MiniTest.expect.equality
local slopscoop = require('slopscoop')
local view = require('slopscoop.view')
local diagnostics = require('slopscoop.diagnostics')

local T = MiniTest.new_set({ hooks = { post_case = H.reset } })

local root, deck_path, code_path

---Open the deck of a fresh repository; its window, buffer and session.
local function open_deck()
  root = H.repo({ ['pkg/mod.py'] = H.python, ['review/f/deck.md'] = H.deck })
  deck_path = vim.fs.joinpath(root, 'review/f/deck.md')
  code_path = vim.fs.joinpath(root, 'pkg/mod.py')
  vim.cmd.edit(deck_path)
  local buf = vim.api.nvim_get_current_buf()
  return vim.api.nvim_get_current_win(), buf, view.session(buf)
end

local function move(win, lnum)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { lnum, 0 })
  vim.api.nvim_exec_autocmds('CursorMoved', { buffer = vim.api.nvim_win_get_buf(win) })
end

local function anchor_lines(buf)
  local marks = vim.api.nvim_buf_get_extmarks(buf, view.anchor_ns, 0, -1, { details = true })
  eq(#marks, 1)
  return { marks[1][2] + 1, marks[1][4].end_row }
end

local function heading_text(buf, lnum)
  local marks = vim.api.nvim_buf_get_extmarks(buf, view.ns, { lnum - 1, 0 }, { lnum - 1, -1 }, { details = true })
  if #marks == 0 then
    return ''
  end
  return table.concat(vim.tbl_map(function(chunk)
    return chunk[1]
  end, marks[1][4].virt_text))
end

T['a deck attaches and reports anchors that do not resolve'] = function()
  local _, buf, session = open_deck()
  eq(session ~= nil, true)
  local problems = vim.diagnostic.get(buf, { namespace = view.check_ns })
  eq(#problems, 1)
  eq(problems[1].lnum, 22)
  eq(problems[1].message, 'no symbol missing in pkg/mod.py')
end

T['the preview window follows the cursor'] = function()
  local win = open_deck()
  move(win, 7)
  local code_win = view.preview_window()
  eq(code_win ~= nil, true)
  eq(vim.api.nvim_get_current_win(), win)
  eq(vim.bo[vim.api.nvim_win_get_buf(code_win)].filetype, 'python')
  local code_buf = vim.api.nvim_win_get_buf(code_win)
  eq(vim.api.nvim_buf_get_name(code_buf), code_path)
  eq(vim.api.nvim_win_get_cursor(code_win)[1], 6)
  eq(anchor_lines(code_buf), { 6, 9 })

  move(win, 16)
  eq(vim.api.nvim_win_get_cursor(code_win)[1], 15)
  move(win, 18)
  eq(vim.api.nvim_win_get_cursor(code_win)[1], 3)
  eq(anchor_lines(code_buf), { 3, 3 })

  -- The same window is reused after the user opens something else in it.
  vim.api.nvim_win_call(code_win, function()
    vim.cmd.enew()
  end)
  move(win, 7)
  eq(view.preview_window(), code_win)
  eq(#vim.api.nvim_tabpage_list_wins(0), 2)
  eq(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(code_win)), code_path)
end

T['a note on code becomes a diagnostic until it is closed'] = function()
  local win, buf = open_deck()
  move(win, 7)
  vim.api.nvim_set_current_win(view.preview_window())
  slopscoop.note(6, 7)
  vim.cmd('stopinsert')
  local note_path = vim.fs.joinpath(root, 'review/f/notes/N1.md')
  eq(vim.api.nvim_buf_get_name(0), note_path)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local head = vim.trim(vim.system({ 'git', '-C', root, 'rev-parse', '--short', 'HEAD' }):wait().stdout)
  eq(lines[1], ('tag=? status=open at=%s pkg/mod.py:6-7'):format(head))
  eq(vim.list_slice(lines, 3, 6), { '```python', 'def top(x):', '    def inner():', '```' })
  eq(lines[#lines]:match('^you %(%d+%-%d+%-%d+%): $') ~= nil, true)

  vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'Is inner needed?' })
  vim.cmd('silent write')
  local code_buf = vim.fn.bufnr(code_path)
  local found = vim.diagnostic.get(code_buf, { namespace = diagnostics.ns })
  eq(#found, 1)
  eq({ found[1].lnum, found[1].end_lnum, found[1].code }, { 5, 6, 'N1' })
  eq(found[1].severity, vim.diagnostic.severity.INFO)
  eq(found[1].message:match('Is inner needed%?') ~= nil, true)
  -- Notes on code are not counted on headings; slide notes are.
  eq(heading_text(buf, 5), '')

  lines[1] = lines[1]:gsub('status=open', 'status=resolved')
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { lines[1] })
  vim.cmd('silent write')
  eq(#vim.diagnostic.get(code_buf, { namespace = diagnostics.ns }), 0)
  eq(buf ~= nil, true)
end

T['a note in the deck is about the slide and counted on its heading'] = function()
  local win, buf = open_deck()
  move(win, 7)
  slopscoop.note(7, 7)
  vim.cmd('stopinsert')
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  eq(lines[1], 'tag=? status=open slide=top-level-function')
  eq(vim.list_slice(lines, 3, 5), { '```markdown', 'Why top exists.', '```' })
  vim.cmd('silent write')
  eq(heading_text(buf, 5), ' 1 open note')
end

T['the deck entered last receives notes on code'] = function()
  local win = open_deck()
  H.write(root, 'review/g/deck.md', { '## Other' })
  vim.api.nvim_set_current_win(win)
  vim.cmd.edit(code_path)
  slopscoop.note(3, 3)
  vim.cmd('stopinsert')
  eq(vim.api.nvim_buf_get_name(0), vim.fs.joinpath(root, 'review/f/notes/N1.md'))
end

T['reviewed marks show on headings'] = function()
  local win, buf = open_deck()
  move(win, 16)
  slopscoop.toggle_reviewed()
  local head = vim.trim(vim.system({ 'git', '-C', root, 'rev-parse', '--short', 'HEAD' }):wait().stdout)
  eq(heading_text(buf, 15), ' ✓ ' .. head)
  local code = vim.deepcopy(H.python)
  code[16] = '        self.a = 2'
  H.write(root, 'pkg/mod.py', code)
  slopscoop.refresh()
  eq(heading_text(buf, 15), '')
  local warnings = vim.diagnostic.get(buf, { namespace = view.check_ns, severity = vim.diagnostic.severity.WARN })
  eq(vim.tbl_map(function(d)
    return { d.lnum, d.message }
  end, warnings), { { 14, 'code changed since reviewed at ' .. head } })
end

T['check lists every kind of problem'] = function()
  local win, buf = open_deck()
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, { '## Broken anchor' })
  vim.api.nvim_exec_autocmds('TextChanged', { buffer = buf })
  H.write(root, 'review/f/reviewed', { 'gone abc 2026-01-01 0123456789ab' })
  H.write(root, 'review/f/notes/N1.md', { 'tag=! pkg/mod.py:6', '', '```python', 'def renamed(x):', '```' })
  H.write(root, 'review/f/notes/N2.md', { 'tag=? slide=nope dup=N9' })
  H.write(root, 'review/f/notes/N3.md', { 'tag=? status=resolved pkg/mod.py:6', '', '```', 'gone', '```' })
  vim.api.nvim_set_current_win(win)
  slopscoop.check()
  local texts = vim.tbl_map(function(item)
    return item.text
  end, vim.fn.getqflist())
  table.sort(texts)
  eq(texts, {
    'N1: its quoted code is no longer in pkg/mod.py',
    'N2 is a duplicate of missing note N9',
    'N2 is about missing slide nope',
    'duplicate slug broken-anchor (also line 22)',
    'no symbol missing in pkg/mod.py',
    'reviewed mark for missing slide gone',
  })
end

T['gf follows symbols, line anchors and note ids'] = function()
  local win = open_deck()
  H.write(root, 'review/f/notes/N1.md', { 'tag=?', '', 'See `pkg/mod.py::Pairs.__init__`, pkg/mod.py:3 and N2.' })
  H.write(root, 'review/f/notes/N2.md', { 'tag=?' })
  vim.api.nvim_set_current_win(win)
  vim.cmd.edit(vim.fs.joinpath(root, 'review/f/notes/N1.md'))
  local note_buf = vim.api.nvim_get_current_buf()
  local function at(pattern, keys)
    vim.api.nvim_set_current_buf(note_buf)
    local col = vim.api.nvim_buf_get_lines(note_buf, 2, 3, false)[1]:find(pattern, 1, true)
    vim.api.nvim_win_set_cursor(0, { 3, col - 1 })
    vim.cmd('normal ' .. keys)
    return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t'), vim.api.nvim_win_get_cursor(0)[1]
  end
  eq({ at('pkg/mod.py::', 'gf') }, { 'mod.py', 15 })
  eq({ at('pkg/mod.py:3', 'gF') }, { 'mod.py', 3 })
  eq({ at('N2', 'gf') }, { 'N2.md', 1 })
end

return T
