LUA = lua5.4
PANDOC = pandoc

PANDOC_FLAGS = --lua-filter docs/pandoc-filter.lua --toc --css mkmain.css	\
--template docs/template.html

OUTPUTS = outputs

LUA_FILES = build/dsl/make.lua build/file-systems/posix.lua				\
build/hashers/init.lua build/hashers/mtime.lua build/hashers/sha1.lua	\
build/hashers/combined-clean.lua build/hashers/combined-dirty.lua		\
build/rebuilders/init.lua build/rebuilders/mtime.lua					\
build/rebuilders/dirty_bit.lua build/rebuilders/verifying-traces.lua	\
build/schedulers/init.lua build/schedulers/suspending.lua				\
build/schedulers/topological.lua build/stores/json.lua					\
build/stores/sqlite3.lua build/stores/table.lua build/systems/init.lua	\
build/systems/make.lua build/systems/ninja.lua build/systems/redo.lua	\
build/systems/sha1-redo.lua build/systems/shake.lua						\
build/third-party/mpeterv-sha1.lua build/third-party/rxi-json.lua		\
build/traces/init.lua build/traces/verifying/init.lua					\
build/traces/verifying/hash.lua build/colors.lua build/getopt.lua		\
build/init.lua build/utils.lua build/programs/make.lua

DOCS = docs/README.md docs/install.md docs/make.md

PAGES = $(OUTPUTS)/docs/index.html $(OUTPUTS)/docs/README.html	\
$(OUTPUTS)/docs/install.html $(OUTPUTS)/docs/make.html			\
$(OUTPUTS)/docs/main.css $(OUTPUTS)/docs/mkmain.css

.PHONY: all
all: TAGS docs

docs: $(PAGES)

TAGS: $(LUA_FILES)
	etags -l lua -o $@ $(LUA_FILES)

$(OUTPUTS)/docs/%.html: docs/%.html
	cp $< $@

$(OUTPUTS)/docs/%.css: docs/%.css
	cp $< $@

$(OUTPUTS)/docs/%.html: docs/%.md docs/template.html docs/pandoc-filter.lua
	mkdir -p $(OUTPUTS)/docs
	$(PANDOC) $(PANDOC_FLAGS) -f markdown -t html --output $@ $<
