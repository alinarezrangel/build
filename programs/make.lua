local Posix_File_System = require "build.file-systems.posix"
local Table_Store = require "build.stores.table"
local Build = require "build.systems.make" (Posix_File_System, Table_Store)
local make_dsl = require "build.dsl.make"
local colors = require "build.colors"

local function read_file(name)
   local handle <close> = io.open(name, "rb")
   return handle:read "a"
end

local function printf(fmt, ...)
   print(string.format(fmt, ...))
end

local function printfc(fmt, ...)
   print(colors.format(fmt, ...))
end

local fs = Posix_File_System.global()

local makefile = [[

libbuild-support.so: exts/file_system.c
    touch libbuild-support.so

all: libbuild-support.so

]]

local recipe_options = {}

local function run(key, dependencies, lines_of_code, fetch)
   for i = 1, #lines_of_code do
      local line = lines_of_code[i]
      local display = true
      if line ~= "" and string.sub(line, 1, 1) == "+" then
         line = string.sub(line, 2)
         display = false
      end
      if display then
         printfc("[:red]RUN[:] %s", line)
      end
      assert(#recipe_options.shell > 0)
      local program = recipe_options.shell[1]
      local args = {}
      for i = 2, #recipe_options.shell do
         args[i - 1] = recipe_options.shell[i]
      end
      args[#args + 1] = line
      Posix_File_System.run_wait(fs, program, args)
   end
end

local recipe = make_dsl.parse_and_prepare(makefile, run)

local function get_special_target(name)
   return recipe.dependency_graph["." .. name]
end

recipe_options.shell = get_special_target "SHELL" or {"sh", "-c"}

local store = Table_Store.empty()
local build = Build.create(fs)

local function middletasks(key)
   if not recipe.dependency_graph[key] then
      return function(fetch)
         if not Posix_File_System.get_mtime(fs, key) then
            printf("The file does not exists and there are no instructions for building it")
            error("Could not build " .. key)
         else
            printf("%s is a source file", key)
            return true
         end
      end
   else
      local task = recipe.tasks(key)
      return function(fetch)
         printfc("[:green]BUILDING[:] %s", key)
         return task(fetch)
      end
   end
end

local topotasks = Build.Scheduler.topological_tasks(middletasks, recipe.dependency_graph)
local function make(key)
   return build(topotasks, key, store)
end

make "all"
