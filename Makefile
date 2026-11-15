.PHONY: test test-file deps clean

NVIM ?= nvim
CC ?= cc
TS_PYTHON_VERSION = v0.25.0

# Tests run with no user config and a scratch XDG tree.
TEST_HOME = $(CURDIR)/.tests
NVIM_TEST = XDG_DATA_HOME=$(TEST_HOME)/data XDG_STATE_HOME=$(TEST_HOME)/state \
	XDG_CACHE_HOME=$(TEST_HOME)/cache XDG_CONFIG_HOME=$(TEST_HOME)/config \
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua

test: deps
	$(NVIM_TEST) -c "lua MiniTest.run()"

# make test-file FILE=tests/test_anchor.lua
test-file: deps
	$(NVIM_TEST) -c "lua MiniTest.run_file('$(FILE)')"

deps: deps/mini.test deps/parser/python.so

deps/mini.test:
	git clone --depth 1 https://github.com/nvim-mini/mini.test $@

deps/tree-sitter-python:
	git clone --depth 1 --branch $(TS_PYTHON_VERSION) https://github.com/tree-sitter/tree-sitter-python $@

deps/parser/python.so: deps/tree-sitter-python
	mkdir -p deps/parser
	$(CC) -O2 -shared -fPIC -I $</src $</src/parser.c $</src/scanner.c -o $@

clean:
	rm -rf deps .tests
