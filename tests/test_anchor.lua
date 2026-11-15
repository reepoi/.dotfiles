local H = dofile('tests/helpers.lua')
local MiniTest = require('mini.test')
local eq = MiniTest.expect.equality
local anchor = require('slopscoop.anchor')

local T = MiniTest.new_set()

T['parse and format round-trip'] = function()
  for _, spec in ipairs({ 'a/b.py', 'a/b.py:3', 'a/b.py:3-9', 'a/b.py::C.m', 'a/b.py::NAME' }) do
    eq(anchor.format(anchor.parse(spec)), spec)
  end
  eq(anchor.parse('a/b.py::C.m'), { path = 'a/b.py', symbol = 'C.m' })
  eq(anchor.parse('a/b.py:4-7'), { path = 'a/b.py', first = 4, last = 7 })
  eq(anchor.parse(''), nil)
end

local root
T['resolve'] = MiniTest.new_set({
  hooks = {
    pre_once = function()
      root = H.repo({ ['pkg/mod.py'] = H.python })
    end,
  },
})

local function lines_of(spec)
  local range, err = anchor.resolve(root, anchor.parse(spec))
  return range and { range.first, range.last } or err
end

T['resolve']['functions, nested functions and classes'] = function()
  eq(lines_of('pkg/mod.py::top'), { 6, 9 })
  eq(lines_of('pkg/mod.py::top.inner'), { 7, 8 })
  eq(lines_of('pkg/mod.py::Pairs'), { 12, 24 })
  eq(lines_of('pkg/mod.py::Pairs.__init__'), { 15, 16 })
end

T['resolve']['module and class assignments'] = function()
  eq(lines_of('pkg/mod.py::SPLITS'), { 3, 3 })
  eq(lines_of('pkg/mod.py::Pairs.size'), { 13, 13 })
end

T['resolve']['line ranges and whole files'] = function()
  eq(lines_of('pkg/mod.py:3-5'), { 3, 5 })
  eq(lines_of('pkg/mod.py'), { 1, #H.python })
  eq(lines_of('pkg/mod.py:20-99'), 'pkg/mod.py has 24 lines, not 20-99')
end

T['resolve']['errors name the problem'] = function()
  eq(lines_of('pkg/mod.py::nothing'), 'no symbol nothing in pkg/mod.py')
  eq(lines_of('pkg/mod.py::inner'), 'no symbol inner in pkg/mod.py')
  eq(lines_of('pkg/mod.py::Pairs.value'), 'symbol Pairs.value is ambiguous in pkg/mod.py (lines 18, 22)')
  eq(lines_of('pkg/other.py::x'), 'no file pkg/other.py')
end

T['resolve']['decorators belong to the symbol'] = function()
  local symbols = anchor.symbols('python', H.python)
  local values = vim.tbl_filter(function(s)
    return s.name == 'Pairs.value'
  end, symbols)
  eq(vim.tbl_map(function(s)
    return { s.first, s.last }
  end, values), { { 18, 20 }, { 22, 24 } })
end

T['resolve']['unsaved buffer edits count'] = function()
  local path = vim.fs.joinpath(root, 'pkg/mod.py')
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, { '# added', '# added' })
  eq(lines_of('pkg/mod.py::top'), { 8, 11 })
  vim.api.nvim_buf_delete(buf, { force = true })
  eq(lines_of('pkg/mod.py::top'), { 6, 9 })
end

return T
