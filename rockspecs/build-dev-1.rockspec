package = "build"
version = "dev-1"
source = {
   url = "git+ssh://git@github.com/alinarezrangel/build.git"
}
description = {
   summary = "A simple build system written almost purely in Lua.",
   homepage = "https://alinarezrangel.github.io/build/",
   license = "GPL-3.0+"
}
dependencies = {
   "lua = 5.4",
   "luaposix >= 35, < 36"
}
build = {
   type = "builtin",
   install = {
      bin = {
         ["build.make"] = "programs/build.make.lua",
         ["build.redo"] = "programs/build.redo.lua"
      }
   },
   modules = {
      ["build.colors"] = "build/colors.lua",
      ["build.dsl.make"] = "build/dsl/make.lua",
      ["build.dsl.redo"] = "build/dsl/redo.lua",
      ["build.file-systems.posix"] = "build/file-systems/posix.lua",
      ["build.getopt"] = "build/getopt.lua",
      ["build.hashers.apenwarr"] = "build/hashers/apenwarr.lua",
      ["build.hashers.combined-clean"] = "build/hashers/combined-clean.lua",
      ["build.hashers.combined-dirty"] = "build/hashers/combined-dirty.lua",
      ["build.hashers.init"] = "build/hashers/init.lua",
      ["build.hashers.mtime"] = "build/hashers/mtime.lua",
      ["build.hashers.sha1"] = "build/hashers/sha1.lua",
      ["build.init"] = "build/init.lua",
      ["build.rebuilders.dirty_bit"] = "build/rebuilders/dirty_bit.lua",
      ["build.rebuilders.init"] = "build/rebuilders/init.lua",
      ["build.rebuilders.mtime"] = "build/rebuilders/mtime.lua",
      ["build.rebuilders.verifying-traces"] = "build/rebuilders/verifying-traces.lua",
      ["build.schedulers.init"] = "build/schedulers/init.lua",
      ["build.schedulers.suspending"] = "build/schedulers/suspending.lua",
      ["build.schedulers.topological"] = "build/schedulers/topological.lua",
      ["build.stores.json"] = "build/stores/json.lua",
      ["build.stores.sqlite3"] = "build/stores/sqlite3.lua",
      ["build.stores.table"] = "build/stores/table.lua",
      ["build.systems.init"] = "build/systems/init.lua",
      ["build.systems.make"] = "build/systems/make.lua",
      ["build.systems.ninja"] = "build/systems/ninja.lua",
      ["build.systems.redo"] = "build/systems/redo.lua",
      ["build.systems.sha1-redo"] = "build/systems/sha1-redo.lua",
      ["build.systems.shake"] = "build/systems/shake.lua",
      ["build.third-party.mpeterv-sha1"] = "build/third-party/mpeterv-sha1.lua",
      ["build.third-party.rxi-json"] = "build/third-party/rxi-json.lua",
      ["build.traces.init"] = "build/traces/init.lua",
      ["build.traces.verifying.hash"] = "build/traces/verifying/hash.lua",
      ["build.traces.verifying.init"] = "build/traces/verifying/init.lua",
      ["build.utils"] = "build/utils.lua",
      ["build.programs.make"] = "build/programs/make.lua",
      ["build.programs.redo"] = "build/programs/redo.lua"
   }
}
