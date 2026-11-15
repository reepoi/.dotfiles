# slopscoop.nvim

Review code along a story. A **deck** (a markdown file) walks through a feature
slide by slide. Each slide explains a step and points at real code, and moving
through the deck shows that code next to it. You write **notes** on code or on
slides. They live as files in the repository, so someone else (a teammate, or
an AI agent) can answer them in place while you keep reviewing.

slopscoop builds on what Neovim already has:

- Code shows in the preview window (`:pedit`), so it is the real file and
  your LSP's `gd` and `gr` work there. `<C-w>P` jumps into it, and `<C-w>z`
  closes it.
- Open notes are `vim.diagnostic` entries, so signs, virtual text, `]d`/`[d`,
  the float and `:lua vim.diagnostic.setqflist()` all work with them.
- Problems with the deck are diagnostics on the deck. `:SlopScoop check`
  adds a few more and puts them all in the quickfix list.
- The deck is an ordinary markdown buffer, so `gO` gives a table of contents
  and `]]`/`[[` move between headings.
- Files changed outside Neovim reload through `'autoread'`.

It has no dependencies, and it doesn't depend on any particular LSP.

## Requirements

- Neovim 0.12 or later
- git
- A treesitter parser for each language whose symbols you anchor
  (Python: `:TSInstall python`). Line anchors need no parser.

## Installation

With `vim.pack`:

```lua
vim.pack.add({ 'https://github.com/<you>/slopscoop.nvim' })
require('slopscoop').setup()
```

With lazy.nvim:

```lua
{ '<you>/slopscoop.nvim', opts = {} }
```

The plugin loads lazily; `setup()` only applies options and keymaps.

## Decks

Decks are files matching `review/*/deck.md` (option `decks`) in a git
repository. `#` headings are topics; `##` headings are slides. A slide points
at code with `@code` lines:

```markdown
# Training data

## Choosing the data module {#data-module}

DiffDA is selected when `forecast_experiment_alt_id` is set ...

@code rolling_da/train.py::configure_data_module
@code rolling_da/train.py:110-113

Flows to: rolling_da/diffda.py::forecast_source
```

Anchors:

| Anchor | Code |
|---|---|
| `path::Name` | a function, class or assignment, found with treesitter; nested names are dotted (`Class.method`), and decorators are included |
| `path:12-20` | lines 12 to 20 |
| `path:12` | line 12 |
| `path` | the whole file |

Paths are relative to the git root. `@code` lines inside code fences are
ignored. A slug comes from the title unless the heading ends with `{#slug}`.
Give an explicit slug if you expect to rename the slide.

Open the deck with `:edit`. When the cursor is on a slide, the preview window
(opened vertically, on the right; the deck keeps the width `:Vexplore` gives
its window, see `g:netrw_winsize`) shows the slide's code. When the cursor is on or below one
of its `@code` lines, it shows that anchor. Anchors that don't resolve and
duplicate slugs are errors on their line.

## Notes

`<leader>rn` on a line, or on a visual selection, opens a new note in a
split. Write it, then `:w`. Notes are files `review/<deck>/notes/N<k>.md`:

````markdown
tag=? status=open at=81ebfdf rolling_da/diffda.py:162

```python
residual = (self.truths[index] - forecast) / self.source.residual_scale
```

you (2026-11-15): Is this the s that sampling uses? See N3.
````

The first line is the header: `key=value` tokens in any order, plus the
location. The plugin uses these keys:

| Key | Values |
|---|---|
| `tag` | `?` question, `!` issue, `ok`. These become the diagnostic severities info, warning and hint. |
| `status` | `open` (the default), `answered`, `fixed`, `resolved`, `wontfix`, `dup` (option `closed_statuses` lists the statuses that hide a note) |
| `at` | the commit the note was written at |
| `slide` | the slug, for notes written in the deck |
| `dup` | the note this one duplicates, e.g. `dup=N3` |

Other keys are allowed and are kept as they are. The fenced block quotes the
code. When the code moves, the note follows the quote. When the quote is gone,
the note is marked `[stale]`. The rest of the file is the thread.

Open notes on code show as diagnostics in that code. Use
`:lua vim.diagnostic.setqflist()` to list them all. Open notes written in the
deck (`slide=`) are counted on their slide's heading.

A note on code belongs to the deck you entered last, or to the only deck in
the repository.

## Reviewed marks

`<leader>rr` in a deck marks the slide under the cursor reviewed. The heading
shows `✓ <commit>`. When the slide's code changes, the heading gets a warning
diagnostic, `code changed since reviewed at <commit>`, and `<leader>rr`
renews the mark. Marks are stored
in `review/<deck>/reviewed`, one line per slide. Only the plugin writes this
file, so other people can edit the deck while you review.

## Links

In decks and notes:

- `gf` on `path::Name` opens the symbol. This is the only link slopscoop
  handles itself.
- `gF` on `path:12` opens the line (built in).
- `gf` on `N3` opens the note (built in: slopscoop sets `'path'` and
  `'suffixesadd'` in these buffers).

## Checking

`<leader>rc` (`:SlopScoop check`) fills the quickfix list with the deck's
diagnostics:

- anchors that don't resolve
- duplicate slugs
- slides whose code changed since they were reviewed

It adds what diagnostics on the deck can't show:

- marks for slides that no longer exist
- open notes whose quoted code is gone
- notes about missing files, slides or notes

## Commands

| Command | Action |
|---|---|
| `:SlopScoop note` | Note on the current line; `:'<,'>SlopScoop note` for a range |
| `:SlopScoop reviewed` | Toggle the slide's reviewed mark |
| `:SlopScoop check` | Check the deck (the default subcommand) |
| `:SlopScoop refresh` | Reload changed files, notes and marks (also done on `FocusGained`; under tmux this needs `set -g focus-events on`) |

## Configuration

```lua
require('slopscoop').setup({
  decks = 'review/*/deck.md',
  notes_dir = 'notes',
  reviewed_file = 'reviewed',
  closed_statuses = { 'resolved', 'wontfix', 'dup' },
  author = 'you',
  keymaps = { note = '<leader>rn', reviewed = '<leader>rr', check = '<leader>rc' },
})
```

Set a keymap to `false` to disable it. The highlight groups are
`SlopScoopAnchor`, `SlopScoopReviewed` and `SlopScoopNotes`.

### Other languages

Symbol anchors use the query `queries/<lang>/slopscoop.scm`. Capture the
definition as `@symbol` and its name as `@name`. See `queries/python/` for an
example.

## Development

```sh
make test                  # fetches mini.test, builds the Python parser, runs all tests
make test-file FILE=tests/test_anchor.lua
make test NVIM=/path/to/nvim
```
