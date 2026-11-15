local M = {}

---The git root containing `path` (a file or directory), or nil.
---@param path string
---@return string?
function M.root(path)
  return vim.fs.root(path, '.git')
end

---Run git in `root`; the trimmed stdout, or nil on failure.
---@param root string
---@param args string[]
---@return string?
function M.git(root, args)
  local result = vim.system(vim.list_extend({ 'git', '-C', root }, args), { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout)
end

---@param root string
---@return string?
function M.head(root)
  return M.git(root, { 'rev-parse', '--short', 'HEAD' })
end

---`path` relative to `root`, or nil when it lies outside.
---@param root string
---@param path string
---@return string?
function M.relative(root, path)
  return vim.fs.relpath(root, vim.fs.normalize(vim.fn.fnamemodify(path, ':p')))
end

---The current lines of `path`: from its loaded buffer when there is one, so
---unsaved edits count, otherwise from disk. Nil when unreadable.
---@param path string absolute
---@return string[]?
function M.lines(path)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  return vim.fn.readfile(path)
end

---Write `lines` to `path` through a temporary file and a rename.
---@param path string
---@param lines string[]
function M.write_atomic(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local tmp = path .. '.tmp'
  if vim.fn.writefile(lines, tmp) ~= 0 then
    error('slopscoop: cannot write ' .. tmp)
  end
  local ok, err = vim.uv.fs_rename(tmp, path)
  if not ok then
    error('slopscoop: cannot rename ' .. tmp .. ': ' .. tostring(err))
  end
end

---@param msg string
---@param level? integer
function M.notify(msg, level)
  vim.notify('SlopScoop: ' .. msg, level or vim.log.levels.INFO)
end

return M
