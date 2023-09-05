LUA = lua5.4
PANDOC = pandoc

PANDOC_FLAGS = --lua-filter docs/pandoc-filter.lua --toc --css mkmain.css	\
--template docs/template.html

OUTPUTS = outputs

LUA_FILES = build/dsl/make.lua build/dsl/redo.lua build/file-systems/posix.lua	\
build/hashers/init.lua build/hashers/mtime.lua build/hashers/sha1.lua			\
build/hashers/combined-clean.lua build/hashers/combined-dirty.lua				\
build/rebuilders/init.lua build/rebuilders/mtime.lua							\
build/rebuilders/dirty_bit.lua build/rebuilders/verifying-traces.lua			\
build/schedulers/init.lua build/schedulers/suspending.lua						\
build/schedulers/topological.lua build/stores/json.lua							\
build/stores/sqlite3.lua build/stores/table.lua build/systems/init.lua			\
build/systems/make.lua build/systems/ninja.lua build/systems/redo.lua			\
build/systems/sha1-redo.lua build/systems/shake.lua								\
build/third-party/mpeterv-sha1.lua build/third-party/rxi-json.lua				\
build/traces/init.lua build/traces/verifying/init.lua							\
build/traces/verifying/hash.lua build/colors.lua build/getopt.lua				\
build/init.lua build/utils.lua build/programs/make.lua build/programs/redo.lua

PAGES = $(OUTPUTS)/docs/index.html $(OUTPUTS)/docs/main.css						\
$(OUTPUTS)/docs/mkmain.css $(OUTPUTS)/docs/README.html							\
$(OUTPUTS)/docs/install.html $(OUTPUTS)/docs/make.html							\
$(OUTPUTS)/docs/redo.html $(OUTPUTS)/docs/internals.html						\
$(OUTPUTS)/docs/stores-table.html $(OUTPUTS)/docs/stores-json.html				\
$(OUTPUTS)/docs/schedulers-suspending.html										\
$(OUTPUTS)/docs/schedulers-topological.html										\
$(OUTPUTS)/docs/rebuilders-mtime.html											\
$(OUTPUTS)/docs/rebuilders-verifying-traces.html								\
$(OUTPUTS)/docs/rebuilders-dirty-bit.html										\
$(OUTPUTS)/docs/rebuilders-phony-adapter.html									\
$(OUTPUTS)/docs/traces-verifying-hash.html $(OUTPUTS)/docs/hashers-mtime.html	\
$(OUTPUTS)/docs/hashers-sha1.html $(OUTPUTS)/docs/hashers-apenwarr.html			\
$(OUTPUTS)/docs/hashers-combined-clean.html										\
$(OUTPUTS)/docs/hashers-combined-dirty.html										\
$(OUTPUTS)/docs/file-systems-posix.html

.PHONY: all
all: TAGS all_docs

.PHONY: all_docs
all_docs: $(PAGES) $(OUTPUTS)/docs.zip

TAGS: $(LUA_FILES)
	etags -l lua -o $@ $(LUA_FILES)

$(OUTPUTS)/docs.zip: $(PAGES)
	rm $@ || true
	zip -r $@ $^

$(OUTPUTS)/docs/%.css: docs/%.css
	cp $< $@

$(OUTPUTS)/docs/%.html: docs/%.md docs/template.html docs/pandoc-filter.lua
	mkdir -p $(OUTPUTS)/docs
	$(PANDOC) $(PANDOC_FLAGS) -f markdown -t html --output $@ $<

$(OUTPUTS)/docs/index.html: docs/index.html
	cp $< $@
