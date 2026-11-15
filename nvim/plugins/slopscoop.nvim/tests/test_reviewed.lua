local H = dofile('tests/helpers.lua')
local MiniTest = require('mini.test')
local eq = MiniTest.expect.equality
local deck = require('slopscoop.deck')
local reviewed = require('slopscoop.reviewed')

local T = MiniTest.new_set({ hooks = { post_case = H.reset } })

T['toggle, staleness and renewal'] = function()
  local root = H.repo({ ['pkg/mod.py'] = H.python, ['review/f/deck.md'] = H.deck })
  local d = deck.load(vim.fs.joinpath(root, 'review/f/deck.md'))
  local top, pairs_slide = d.slides[1], d.slides[2]

  eq(reviewed.toggle(d, pairs_slide), true)
  eq(reviewed.toggle(d, top), true)
  local lines = vim.fn.readfile(reviewed.path(d))
  eq(#lines, 2)
  eq(lines[1]:match('^pairs '), 'pairs ')
  eq(lines[2]:match('^top%-level%-function '), 'top-level-function ')
  eq((reviewed.state(d, top, reviewed.read(d))), 'reviewed')

  -- Editing top's code invalidates its mark only.
  local code = vim.deepcopy(H.python)
  code[8] = '        return x + 1'
  H.write(root, 'pkg/mod.py', code)
  local marks = reviewed.read(d)
  eq((reviewed.state(d, top, marks)), 'changed')
  eq((reviewed.state(d, pairs_slide, marks)), 'reviewed')

  -- Toggling a changed mark renews it; toggling a current one removes it.
  eq(reviewed.toggle(d, top), true)
  eq((reviewed.state(d, top, reviewed.read(d))), 'reviewed')
  eq(reviewed.toggle(d, top), false)
  eq(reviewed.read(d)['top-level-function'], nil)
end

T['other lines in the file survive a toggle'] = function()
  local root = H.repo({ ['pkg/mod.py'] = H.python, ['review/f/deck.md'] = H.deck })
  local d = deck.load(vim.fs.joinpath(root, 'review/f/deck.md'))
  H.write(root, 'review/f/reviewed', { 'gone-slide abc 2026-01-01 0123456789ab' })
  reviewed.toggle(d, d.slides[1])
  eq(vim.tbl_keys(reviewed.read(d)), vim.tbl_keys({ ['gone-slide'] = 1, ['top-level-function'] = 1 }))
end

return T
