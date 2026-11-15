local H = {}

---Write `files` (path -> lines) into a new git repository with one commit.
---@param files table<string, string[]>
---@return string root
function H.repo(files)
  local root = vim.fs.normalize(vim.fn.tempname())
  vim.fn.mkdir(root, 'p')
  root = vim.uv.fs_realpath(root)
  for path, lines in pairs(files) do
    H.write(root, path, lines)
  end
  local function git(args)
    local result = vim.system(vim.list_extend({ 'git', '-C', root, '-c', 'user.name=t', '-c', 'user.email=t@t' }, args)):wait()
    assert(result.code == 0, result.stderr)
  end
  git({ 'init', '-q' })
  git({ 'add', '-A' })
  git({ 'commit', '-q', '-m', 'init', '--allow-empty' })
  return root
end

---@param root string
---@param path string
---@param lines string[]
function H.write(root, path, lines)
  local full = vim.fs.joinpath(root, path)
  vim.fn.mkdir(vim.fs.dirname(full), 'p')
  vim.fn.writefile(lines, full)
end

H.python = {
  'import os',
  '',
  'SPLITS = ("train", "val")',
  '',
  '',
  'def top(x):',
  '    def inner():',
  '        return x',
  '    return inner',
  '',
  '',
  'class Pairs:',
  '    size = 3',
  '',
  '    def __init__(self):',
  '        self.a = 1',
  '',
  '    @property',
  '    def value(self):',
  '        return self.a',
  '',
  '    @value.setter',
  '    def value(self, v):',
  '        self.a = v',
}

H.deck = {
  '# Data',
  '',
  'Intro prose for the topic.',
  '',
  '## Top-level function',
  '',
  'Why top exists.',
  '@code pkg/mod.py::top',
  '',
  '```python',
  '## not a heading',
  '@code not/an.py::anchor',
  '```',
  '',
  '## The class {#pairs}',
  '@code pkg/mod.py::Pairs.__init__',
  'Between anchors.',
  '@code pkg/mod.py:3',
  '',
  '# Tests',
  '',
  '## Broken anchor',
  '@code pkg/mod.py::missing',
}

---Close every window and wipe every buffer.
function H.reset()
  vim.cmd('silent! %bwipeout!')
  vim.cmd('silent! only')
end

return H
