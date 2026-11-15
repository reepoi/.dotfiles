local anchor = require('slopscoop.anchor')
local config = require('slopscoop.config')
local deck = require('slopscoop.deck')
local diagnostics = require('slopscoop.diagnostics')
local notes = require('slopscoop.notes')
local reviewed = require('slopscoop.reviewed')
local util = require('slopscoop.util')
local view = require('slopscoop.view')

local M = {}

---@param opts? slopscoop.Config
function M.setup(opts)
  config.setup(opts)
  local keys = config.options.keymaps
  if keys.note then
    vim.keymap.set('n', keys.note, '<Cmd>SlopScoop note<CR>', { desc = 'SlopScoop: note on this line' })
    vim.keymap.set('x', keys.note, ':SlopScoop note<CR>', { desc = 'SlopScoop: note on the selection', silent = true })
  end
  if keys.check then
    vim.keymap.set('n', keys.check, '<Cmd>SlopScoop check<CR>', { desc = 'SlopScoop: check the deck' })
  end
end

---The deck the current context refers to: the current deck buffer, else the
---deck entered last, else the only deck in the repository (asking when there
---are several). Calls `on_deck` with it.
---@param on_deck fun(d: slopscoop.Deck)
local function with_deck(on_deck)
  local session = view.session(vim.api.nvim_get_current_buf()) or view.last_session()
  if session then
    return on_deck(session.deck)
  end
  local name = vim.api.nvim_buf_get_name(0)
  local root = util.root(name ~= '' and name or vim.fn.getcwd())
  if not root then
    return util.notify('not in a git repository', vim.log.levels.WARN)
  end
  local paths = deck.find(root)
  local function load(path)
    local d = path and deck.load(path)
    if d then
      on_deck(d)
    end
  end
  if #paths == 0 then
    util.notify(('no deck matches %s in %s'):format(config.options.decks, root), vim.log.levels.WARN)
  elseif #paths == 1 then
    load(paths[1])
  else
    vim.ui.select(paths, {
      prompt = 'Deck',
      format_item = function(path)
        return util.relative(root, path) or path
      end,
    }, load)
  end
end

---@param path string
---@param lines string[]
local function open_note(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.cmd('belowright split ' .. vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { #lines, #lines[#lines] })
  vim.cmd('startinsert!')
end

---Create a note on lines `first`..`last` of the current buffer and open it.
---In a deck, the note is about the slide; elsewhere, about the code.
---@param first integer
---@param last integer
function M.note(first, last)
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local quote = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
  local session = view.session(buf)
  if session then
    local slide = deck.slide_at(session.deck, first)
    if not slide then
      return util.notify('not on a slide', vim.log.levels.WARN)
    end
    local header = {
      fields = {
        { key = 'tag', value = '?' },
        { key = 'status', value = 'open' },
        { key = 'slide', value = slide.slug },
      },
    }
    local path = vim.fs.joinpath(notes.dir(session.deck.dir), notes.next_id(session.deck.dir) .. '.md')
    return open_note(path, notes.template(header, quote, 'markdown'))
  end
  local root = name ~= '' and util.root(name)
  local rel = root and util.relative(root, name)
  if not rel then
    return util.notify('this buffer is not a file in a git repository', vim.log.levels.WARN)
  end
  local lang = vim.bo[buf].filetype
  with_deck(function(d)
    local header = {
      fields = {
        { key = 'tag', value = '?' },
        { key = 'status', value = 'open' },
        { key = 'at', value = util.head(d.root) or 'none' },
      },
      location = { path = rel, first = first, last = last },
    }
    local path = vim.fs.joinpath(notes.dir(d.dir), notes.next_id(d.dir) .. '.md')
    open_note(path, notes.template(header, quote, lang))
  end)
end

---Toggle the reviewed mark of the slide under the cursor. A mark whose code
---changed is renewed rather than removed.
function M.toggle_reviewed()
  local session = view.session(vim.api.nvim_get_current_buf())
  if not session then
    return util.notify('not in a deck', vim.log.levels.WARN)
  end
  local slide = deck.slide_at(session.deck, vim.api.nvim_win_get_cursor(0)[1])
  if not slide then
    return util.notify('not on a slide', vim.log.levels.WARN)
  end
  local marked = reviewed.toggle(session.deck, slide)
  view.decorate(session)
  util.notify(('%s %s'):format(slide.title, marked and 'reviewed' or 'unmarked'))
end

---`gf` in decks and notes: follows `path::Symbol`; anything else (file paths,
---note ids through 'path' and 'suffixesadd') goes to the built-in gf. Use gF
---for `path:12`.
function M.gf()
  local word = vim.fn.expand('<cWORD>'):gsub('^[`%(%[<"\']+', ''):gsub('[`%)%]>"\',;%.]+$', '')
  local target = word:find('::', 1, true) and anchor.parse(word)
  local root = target and util.root(vim.api.nvim_buf_get_name(0))
  local range = root and anchor.resolve(root, target)
  if range then
    vim.cmd.edit(vim.fn.fnameescape(range.path))
    vim.api.nvim_win_set_cursor(0, { range.first, 0 })
    return
  end
  vim.cmd('normal! gf')
end

---Problems with deck `d` that are not deck diagnostics, as quickfix entries:
---reviewed marks of missing slides and problems with notes.
---@param d slopscoop.Deck
---@return vim.quickfix.entry[]
function M.other_problems(d)
  local items = {}
  local function add(path, lnum, text)
    items[#items + 1] = { filename = path, lnum = lnum, col = 1, text = text, type = 'W' }
  end
  local slugs = {}
  for _, slide in ipairs(d.slides) do
    slugs[slide.slug] = true
  end
  local marked = vim.tbl_keys(reviewed.read(d))
  table.sort(marked)
  for i, slug in ipairs(marked) do
    if not slugs[slug] then
      add(reviewed.path(d), i, ('reviewed mark for missing slide %s'):format(slug))
    end
  end
  local all = notes.list(d.dir)
  local ids = {}
  for _, note in ipairs(all) do
    ids[note.id] = true
  end
  for _, note in ipairs(all) do
    local slug = notes.get(note, 'slide')
    if slug and not slugs[slug] then
      add(note.file, 1, ('%s is about missing slide %s'):format(note.id, slug))
    end
    local dup = notes.get(note, 'dup')
    if dup and not ids[dup] then
      add(note.file, 1, ('%s is a duplicate of missing note %s'):format(note.id, dup))
    end
    local loc = note.location
    if loc and loc.symbol then
      add(note.file, 1, ('%s: a note location must be a line range, not a symbol'):format(note.id))
    elseif loc and vim.fn.filereadable(vim.fs.joinpath(d.root, loc.path)) == 0 then
      add(note.file, 1, ('%s is about missing file %s'):format(note.id, loc.path))
    elseif loc and not notes.is_closed(note) then
      local place = notes.place(d.root, note)
      if place and place.stale then
        add(note.file, 1, ('%s: its quoted code is no longer in %s'):format(note.id, loc.path))
      end
    elseif not loc and not slug then
      add(note.file, 1, ('%s has neither a location nor a slide'):format(note.id))
    end
  end
  return items
end

---Fill the quickfix list with the deck's diagnostics and other problems.
function M.check()
  with_deck(function(d)
    local buf = vim.fn.bufadd(d.path)
    vim.fn.bufload(buf)
    M.attach_deck(buf)
    local session = view.session(buf)
    if not session then
      return
    end
    view.decorate(session)
    local items = vim.diagnostic.toqflist(vim.diagnostic.get(buf, { namespace = view.check_ns }))
    vim.list_extend(items, M.other_problems(session.deck))
    local title = util.relative(d.root, d.path) or d.path
    vim.fn.setqflist({}, ' ', { title = 'SlopScoop check: ' .. title, items = items })
    if #items == 0 then
      util.notify('no problems in ' .. title)
    else
      vim.cmd('copen')
    end
  end)
end

---Reload buffers whose files changed outside Neovim ('autoread'), then notes
---and marks everywhere.
function M.refresh()
  vim.cmd('silent! checktime')
  diagnostics.refresh_all()
  view.decorate_all()
end

---Let the built-in gf find note ids (N3) and gF repository paths.
---@param buf integer
---@param deck_dir string
---@param root string
local function link_options(buf, deck_dir, root)
  vim.bo[buf].path = table.concat({ notes.dir(deck_dir), root, vim.go.path }, ',')
  vim.bo[buf].suffixesadd = '.md'
  vim.keymap.set('n', 'gf', M.gf, { buffer = buf, desc = 'SlopScoop: follow link' })
end

---Set up a deck buffer.
---@param buf integer
function M.attach_deck(buf)
  local session = view.attach(buf)
  if not session or vim.b[buf].slopscoop_attached then
    return
  end
  vim.b[buf].slopscoop_attached = true
  link_options(buf, session.deck.dir, session.deck.root)
  local key = config.options.keymaps.reviewed
  if key then
    vim.keymap.set('n', key, M.toggle_reviewed, { buffer = buf, desc = 'SlopScoop: toggle reviewed' })
  end
end

---Is `path` a note file: `N<k>.md` in a directory named like `notes_dir`?
---@param path string
---@return boolean
function M.is_note(path)
  return vim.fn.fnamemodify(path, ':t'):match('^N%d+%.md$') ~= nil
    and vim.fn.fnamemodify(path, ':h:t') == config.options.notes_dir
end

---Set up a note buffer.
---@param buf integer
function M.attach_note(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  local root = util.root(path)
  if root then
    link_options(buf, vim.fs.dirname(vim.fs.dirname(path)), root)
  end
end

local subcommands = {
  note = function(opts)
    if opts.range > 0 then
      M.note(opts.line1, opts.line2)
    else
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      M.note(lnum, lnum)
    end
  end,
  reviewed = M.toggle_reviewed,
  check = M.check,
  refresh = M.refresh,
}

---The :SlopScoop command.
---@param opts vim.api.keyset.create_user_command.command_args
function M.command(opts)
  local name = opts.fargs[1] or 'check'
  local run = subcommands[name]
  if not run then
    return util.notify('unknown subcommand ' .. name, vim.log.levels.ERROR)
  end
  run(opts)
end

---@return string[]
function M.complete()
  local names = vim.tbl_keys(subcommands)
  table.sort(names)
  return names
end

return M
