local Posix_File_System = require "build.file-systems.posix"
local Table_Store = require "build.stores.table"
local JSON_Store = require "build.stores.json"
local Build = require "build.systems.sha1-redo" (Posix_File_System, Table_Store, JSON_Store)

local function tasks(key)
   if key == "libbuild-support.so" then
      return function(fetch)
         fetch "exts/file_system.c"
         print "build libbuild"
         os.execute "touch libbuild-support.so"
         return true
      end
   elseif key == "exts/file_system.c" then
      return function(fetch)
         print "src exts/file_system.c"
         return true
      end
   elseif key == "all" then
      return function(fetch)
         print "all"
         fetch "libbuild-support.so"
         return true
      end
   else
      error("cannot build " .. key)
   end
end

-- local tasks_dependencies = {
--    ["libbuild-support.so"] = {"exts/file_system.c"},
--    ["exts/file_system.c"] = {},
--    ["all"] = {"libbuild-support.so"},
-- }

os.execute "mkdir -p .build-db"

local store = Table_Store.empty()
local metadata_store = JSON_Store.open "meta-alist.json"
local build = Build.create(Posix_File_System.global(), metadata_store)
-- local topotasks = Build.create_tasks(tasks, tasks_dependencies)
local function make(key)
   return build(tasks, key, store)
end

-- do
--    local gv <close> = assert(io.open("graph.dot", "w"))
--    Build.Scheduler.graph_to_graphviz(topotasks, gv)
-- end
print(make "libbuild-support.so")

JSON_Store.save(metadata_store)
