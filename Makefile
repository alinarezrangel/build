LUA = lua5.4

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

.PHONY: all
all: TAGS

TAGS: $(LUA_FILES)
	etags -l lua -o $@ $(LUA_FILES)

$(OUTPUTS)/build.make: build/programs/make.lua
	echo '#!/usr/bin/env $(LUA)' > $@
	cat $< > $@
	chmod +x $@
