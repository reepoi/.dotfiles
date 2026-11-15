local H = dofile('tests/helpers.lua')
local MiniTest = require('mini.test')
local eq = MiniTest.expect.equality
local deck = require('slopscoop.deck')

local T = MiniTest.new_set()

T['slugify'] = function()
  eq(deck.slugify('The class: Pairs (v2)!'), 'the-class-pairs-v2')
end

T['parse'] = function()
  local slides = deck.parse(H.deck)
  eq(vim.tbl_map(function(s)
    return { s.title, s.slug, s.topic, s.lnum, s.last }
  end, slides), {
    { 'Top-level function', 'top-level-function', 'Data', 5, 14 },
    { 'The class', 'pairs', 'Data', 15, 19 },
    { 'Broken anchor', 'broken-anchor', 'Tests', 22, 23 },
  })
  -- The fenced block hides its heading and its @code line.
  eq(vim.tbl_map(function(a)
    return { a.spec, a.lnum }
  end, slides[1].anchors), { { 'pkg/mod.py::top', 8 } })
  eq(#slides[2].anchors, 2)
end

T['slide_at and anchor_at'] = function()
  local d = { slides = deck.parse(H.deck) }
  eq(deck.slide_at(d, 3), nil)
  eq(deck.slide_at(d, 20), nil)
  local pairs_slide = deck.slide_at(d, 17)
  eq(pairs_slide.slug, 'pairs')
  eq(deck.anchor_at(pairs_slide, 15).spec, 'pkg/mod.py::Pairs.__init__')
  eq(deck.anchor_at(pairs_slide, 17).spec, 'pkg/mod.py::Pairs.__init__')
  eq(deck.anchor_at(pairs_slide, 18).spec, 'pkg/mod.py:3')
  eq(deck.anchor_at(pairs_slide, 19).spec, 'pkg/mod.py:3')
end

T['is_deck and find follow the decks glob'] = function()
  local root = H.repo({
    ['review/feature/deck.md'] = H.deck,
    ['review/deck.md'] = { '# no' },
    ['other/feature/deck.md'] = { '# no' },
  })
  eq(deck.is_deck(vim.fs.joinpath(root, 'review/feature/deck.md')), true)
  eq(deck.is_deck(vim.fs.joinpath(root, 'review/deck.md')), false)
  eq(deck.is_deck(vim.fs.joinpath(root, 'other/feature/deck.md')), false)
  eq(deck.find(root), { vim.fs.joinpath(root, 'review/feature/deck.md') })
end

return T
