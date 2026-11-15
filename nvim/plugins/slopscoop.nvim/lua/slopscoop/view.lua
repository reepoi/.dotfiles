---A deck buffer drives the preview window: moving the cursor to a slide (or one
---of its @code lines) shows that code there with :pedit, highlighted. Problems
---with the deck (anchors that do not resolve, duplicate slugs, slides changed
---since reviewed) are diagnostics on the deck; headings get virtual text with
---the reviewed mark and the slide's open notes written in the deck.
local anchor = require('slopscoop.anchor')
local deck = require('slopscoop.deck')
local notes = require('slopscoop.notes')
local reviewed = require('slopscoop.reviewed')

local M = {}

M.ns = vim.api.nvim_create_namespace('slopscoop.view')
M.anchor_ns = vim.api.nvim_create_namespace('slopscoop.anchor')
M.check_ns = vim.api.nvim_create_namespace('slopscoop.deck')

---@class slopscoop.Session
---@field buf integer
---@field deck slopscoop.Deck
---@field shown? string  key of the anchor last shown

---@type table<integer, slopscoop.Session>
M.sessions = {}

---The deck buffer entered last.
---@type integer?
M.last = nil

---@param buf integer
---@return slopscoop.Session?
function M.session(buf)
  return M.sessions[buf]
end

---The session of the deck entered last, if it is still open.
---@return slopscoop.Session?
function M.last_session()
  return M.last and M.sessions[M.last] or nil
end

---The preview window of the current tab page.
---@return integer?
function M.preview_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.wo[win].previewwindow then
      return win
    end
  end
  return nil
end

---The width :Vexplore gives a split of window `win`: g:netrw_winsize percent of
---its width when positive, that many columns when negative, half when unset.
---@param win integer
---@return integer
local function vex_width(win)
  local size = tonumber(vim.g.netrw_winsize) or 50
  if size == 0 then
    size = 50
  end
  local width = size > 0 and math.floor(size * vim.api.nvim_win_get_width(win) / 100) or -size
  return math.max(width, 1)
end

---@param session slopscoop.Session
local function reparse(session)
  session.deck.slides = deck.parse(vim.api.nvim_buf_get_lines(session.buf, 0, -1, false))
end

---@param lnum integer
---@param message string
---@param severity vim.diagnostic.Severity
---@return vim.Diagnostic.Set
local function problem(lnum, message, severity)
  return { lnum = lnum - 1, col = 0, message = message, severity = severity, source = 'slopscoop' }
end

---Redraw heading virtual text and the deck's diagnostics.
---@param session slopscoop.Session
function M.decorate(session)
  local buf, d = session.buf, session.deck
  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  local marks = reviewed.read(d)
  local open = {} ---@type table<string, integer>
  for _, note in ipairs(notes.list(d.dir)) do
    local slug = notes.get(note, 'slide')
    if slug and not notes.is_closed(note) then
      open[slug] = (open[slug] or 0) + 1
    end
  end
  local problems = {}
  local seen = {} ---@type table<string, integer>
  for _, slide in ipairs(d.slides) do
    if seen[slide.slug] then
      problems[#problems + 1] = problem(
        slide.lnum,
        ('duplicate slug %s (also line %d)'):format(slide.slug, seen[slide.slug]),
        vim.diagnostic.severity.ERROR
      )
    end
    seen[slide.slug] = seen[slide.slug] or slide.lnum

    local chunks = {}
    local state, mark = reviewed.state(d, slide, marks)
    if state == 'reviewed' then
      chunks[#chunks + 1] = { ' ✓ ' .. mark.commit, 'SlopScoopReviewed' }
    elseif state == 'changed' then
      problems[#problems + 1] = problem(
        slide.lnum,
        ('code changed since reviewed at %s'):format(mark.commit),
        vim.diagnostic.severity.WARN
      )
    end
    local count = open[slide.slug]
    if count then
      chunks[#chunks + 1] = { (' %d open note%s'):format(count, count == 1 and '' or 's'), 'SlopScoopNotes' }
    end
    if #chunks > 0 then
      vim.api.nvim_buf_set_extmark(buf, M.ns, slide.lnum - 1, 0, { virt_text = chunks })
    end

    for _, entry in ipairs(slide.anchors) do
      local err
      if not entry.anchor then
        err = 'cannot parse anchor ' .. entry.spec
      else
        _, err = anchor.resolve(d.root, entry.anchor)
      end
      if err then
        problems[#problems + 1] = problem(entry.lnum, err, vim.diagnostic.severity.ERROR)
      end
    end
  end
  vim.diagnostic.set(M.check_ns, buf, problems)
end

---Show the anchor the cursor selects in the preview window.
---@param session slopscoop.Session
function M.follow(session)
  local win = vim.fn.bufwinid(session.buf)
  if win == -1 then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(win)[1]
  local slide = deck.slide_at(session.deck, lnum)
  local entry = slide and deck.anchor_at(slide, lnum)
  if not entry or not entry.anchor then
    return
  end
  local key = entry.lnum .. ':' .. entry.spec
  if key == session.shown then
    return
  end
  local range = anchor.resolve(session.deck.root, entry.anchor)
  if not range then
    return
  end
  session.shown = key
  local opening = not M.preview_window()
  local width = vex_width(win)
  vim.api.nvim_win_call(win, function()
    vim.cmd(('vertical belowright pedit +%d %s'):format(range.first, vim.fn.fnameescape(range.path)))
  end)
  local preview = M.preview_window()
  if not preview then
    return
  end
  if opening then
    -- The deck takes the left window :Vexplore would make; the code gets the rest.
    vim.api.nvim_win_set_width(win, width)
  end
  local buf = vim.api.nvim_win_get_buf(preview)
  vim.api.nvim_buf_clear_namespace(buf, M.anchor_ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, M.anchor_ns, range.first - 1, 0, {
    end_row = range.last,
    hl_group = 'SlopScoopAnchor',
    hl_eol = true,
    priority = 50,
  })
  vim.api.nvim_win_call(preview, function()
    -- Center the code's first line vertically, like zz.
    vim.api.nvim_win_set_cursor(preview, { range.first, 0 })
    vim.cmd('normal! zz')
  end)
end

---Attach a session to deck buffer `buf`.
---@param buf integer
---@return slopscoop.Session?
function M.attach(buf)
  if M.sessions[buf] then
    return M.sessions[buf]
  end
  local d = deck.load(vim.api.nvim_buf_get_name(buf), vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  if not d then
    return nil
  end
  local session = { buf = buf, deck = d }
  M.sessions[buf] = session
  M.last = buf
  local group = vim.api.nvim_create_augroup('slopscoop.view.' .. buf, { clear = true })
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = group,
    buffer = buf,
    -- Loading the code buffer must run its own autocommands (filetype
    -- detection, LSP attach), which only happens in a nested autocommand.
    nested = true,
    callback = function()
      M.follow(session)
    end,
  })
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    buffer = buf,
    callback = function()
      M.last = buf
    end,
  })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave', 'BufWritePost', 'FileChangedShellPost' }, {
    group = group,
    buffer = buf,
    callback = function()
      reparse(session)
      M.decorate(session)
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = buf,
    callback = function()
      M.sessions[buf] = nil
      if M.last == buf then
        M.last = nil
      end
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })
  M.decorate(session)
  return session
end

---Redecorate every session (after notes or marks change).
function M.decorate_all()
  for buf, session in pairs(M.sessions) do
    if vim.api.nvim_buf_is_valid(buf) then
      M.decorate(session)
    end
  end
end

return M
