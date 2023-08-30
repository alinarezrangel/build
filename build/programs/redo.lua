return function(...)
   local Posix_File_System = require "build.file-systems.posix"
   local Table_Store = require "build.stores.table"
   local JSON_Store = require "build.stores.json"
   local redo_dsl = require "build.dsl.redo" (Posix_File_System)
   local colors = require "build.colors"
   local getopt = require "build.getopt"
   local utils = require "build.utils"

   local fs = Posix_File_System.global()

   local OPTIONS = {
      getopt.ONCE_EACH,
      getopt.opt("C", "directory", "directory", 1),
      getopt.opt(nil, "color", "color", 1),
      getopt.opt(nil, "rebuilder", "rebuilder", 1),
      getopt.opt(nil, "scheduler", "scheduler", 1),
      getopt.opt(nil, "hasher", "hasher", 1),
      getopt.opt("D", "database", "db_file", 1),
      getopt.flag(nil, "clean", "do_clean"),
      getopt.flag(nil, "list-cleanable", "list_cleanable"),
      getopt.MANY_OF,
      getopt.flag("h", "help", "show_help"),
      getopt.flag("v", "version", "show_version"),
   }

   local options, targets = getopt.parse_command_line(OPTIONS, {...})

   local HELP = ([[build.redo -- A simple, redo-like build tool.
Usage:
    redo [OPTION]... [TARGET]...

This simple, redo-like tool will rebuild out-of-date files in a directory using
the several `.do.lua` files. See the man page build.redo(1), the info manual
`info build.redo` or the web page
<https://alinarezrangel.github.io/build/man/redo.html> for more help.

Available options are:

-C DIR, --directory DIR   : Switch to DIR before operating.
--color always|never|auto : Enable or disable colored output.
-h, --help                : Show this help and exit.
-v, --version             : Show version and exit.
--database FILE           : Use FILE as the backing database file.
--clean                   : Clean all the intermediary files.
--list-cleanable          : List all intermediary files.
]])

   local VERSION = ([[build.redo revision 1

Report any bug or issue to <https://github.com/alinarezrangel/build>

Copyright (C) 2022 Alejandro Linarez Rangel
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This program comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions

The JSON library used (<github.com/rxi/json.lua>) was created by:
Copyright (c) 2020 rxi

The SHA1 hashing library used (<github.com/mpeterv/sha1>) was created by:
Copyright (c) 2013 Enrique García Cota, Eike Decker, Jeffrey Friedl
Copyright (c) 2018 Peter Melnichenko

Nonetheless, please report any bug related to the hashing to this (build.make)
project, as many modifications were made to the original SHA1 library.
]])

   options.color = options.color or "auto"

   if options.show_help then
      print(HELP)
      os.exit(true, true)
   elseif options.show_version then
      print(VERSION)
      os.exit(true, true)
   end

   if options.directory then
      Posix_File_System.change_current_directory(fs, options.directory)
   end

   local function printf(fmt, ...)
      print(string.format(fmt, ...))
   end

   local function printfc(fmt, ...)
      if options.color == "never"
         or (options.color == "auto"
             and not Posix_File_System.is_a_terminal(fs, io.stdout))
      then
         print(string.format(string.gsub(fmt, colors.PATTERN, ""), ...))
      else
         print(colors.format(fmt, ...))
      end
   end

   local IMPOSSIBLE_DEPENDENCY = "\0IMPOSSIBLE_DEPENDENCY"

   local function File_Of_Key(key)
      if rawequal(key, IMPOSSIBLE_DEPENDENCY) then
         return nil
      else
         return key
      end
   end

   local database_file = ".build-lua-redo-db.json"
   if options.db_file then
      database_file = options.db_file
   end

   local global_env = redo_dsl.make_lua_env()
   global_env = redo_dsl.extend_env_with_dsl(fs, global_env)

   global_env.Posix_File_System = Posix_File_System
   global_env.posix_file_system = fs
   global_env.BASE_DIR = Posix_File_System.get_current_directory(fs)

   function global_env.prelude(env) end
   function global_env.postlude(env) end

   local nesting_level, redofile_path = 0, nil

   local function tasks(key)
      if rawequal(key, IMPOSSIBLE_DEPENDENCY) then
         return function(fetch)
            return true
         end
      end

      local function find(path)
         if Posix_File_System.get_stats(fs, path) then
            return path
         else
            return nil
         end
      end

      local filepath = assert(File_Of_Key(key), "unreachable: the key has no file: " .. tostring(key))
      local path, rel_path_to_file = redo_dsl.find_recipe_for_filename(filepath, find)

      local indentation = string.rep("  ", nesting_level)

      if path and rel_path_to_file then
         return function(fetch)
            local subenv = utils.shallow_copy(global_env)
            printfc("[:green]RUNNING[:] %s%s (%s)", indentation, key, path)

            subenv._G = subenv
            subenv.ABS_TARGET = key
            subenv.ABS_TARGET_NAME = utils.basename(subenv.ABS_TARGET)
            subenv.ABS_TARGET_DIR = utils.dirname(subenv.ABS_TARGET)
            subenv.RECIPE = path
            subenv.RECIPE_NAME = utils.basename(subenv.RECIPE)
            subenv.RECIPE_DIR = utils.dirname(subenv.RECIPE)
            subenv.TARGET = rel_path_to_file
            subenv.TARGET_NAME = utils.basename(subenv.TARGET)
            subenv.TARGET_DIR = utils.dirname(subenv.TARGET)
            subenv.REL_BASE_DIR = subenv.empty_or(string.rep("../", subenv.num_directories(subenv.RECIPE)), ".")
            local inside = subenv.RECIPE_DIR

            local previous_cwd = Posix_File_System.get_current_directory(fs)
            local is_inside = false
            local function cd_in()
               Posix_File_System.change_current_directory(fs, inside)
               is_inside = true
            end
            local function cd_out()
               Posix_File_System.change_current_directory(fs, previous_cwd)
               is_inside = false
            end

            local function safe_fetch(key)
               cd_out()
               local file = File_Of_Key(key)
               local res
               if file then
                  local actual_file
                  if utils.is_absolute(file) then
                     actual_file = file
                  else
                     actual_file = utils.eager_join(inside, file)
                  end
                  res = fetch(actual_file)
               else
                  res = fetch(key)
               end
               cd_in()
               return res
            end

            function subenv.ifchange(...)
               local res, args = {}, {...}
               for i = 1, select("#", ...) do
                  res[i] = safe_fetch(args[i])
               end
               return res
            end

            function subenv.ifanychanges(deps)
               local res = {}
               for i = 1, deps.n or #deps do
                  res[i] = safe_fetch(deps[i])
               end
               return res
            end

            function subenv.always()
               safe_fetch(IMPOSSIBLE_DEPENDENCY)
            end

            -- This is necessary to add the dependency of every file to their
            -- recipe and the Redofile (if it exists).
            --
            -- We don't use `subenv.ifchange` because that resolves the
            -- filename *relative to the recipe file*, while here we have the
            -- filename *relative to the tool CWD*.
            fetch(path)
            if redofile_path then
               fetch(redofile_path)
            end

            local cder <close> = utils.closer(cd_out, nil)
            local chunk = redo_dsl.run_recipe(path, subenv)
            cd_in()
            subenv:prelude()
            chunk()
            subenv:postlude()
            cd_out()
            printfc("[:blue]DONE[:]    %s%s (%s)", indentation, key, path)
         end
      elseif Posix_File_System.get_stats(fs, key) then
         return function(fetch)
            -- Nothing to do: it is a source file.
            printfc("[:blue]DONE[:]    %s%s", indentation, key)
         end
      else
         printfc("[:red]ERROR[:]   %sCannot build %s: is not a source file and there is no recipe", indentation, key)
         error("Could not build " .. key)
      end
   end

   local function nesting_tasks(key)
      local task = tasks(key)
      if task then
         return function(fetch)
            nesting_level = nesting_level + 1
            local res = task(fetch)
            nesting_level = nesting_level - 1
            return res
         end
      else
         return task
      end
   end

   printfc("[:cyan]INFO[:] Using database %s", database_file)

   local Backing_Store = JSON_Store
   local backing_store = Backing_Store.open(database_file)

   local function close_db()
      printfc("[:cyan]INFO[:] Closing the database")
      Backing_Store.save(backing_store)
   end
   local backing_store_closer <close> = utils.closer(close_db, nil)

   local Store = Table_Store
   local store = Store.empty()

   local Hasher = require "build.hashers.apenwarr" (Posix_File_System, File_Of_Key)
   local hasher = Hasher.create(fs)

   local Verifying_Trace_Store = require "build.traces.verifying.hash" (Backing_Store, Hasher)
   local vt = Verifying_Trace_Store.create(backing_store, hasher)
   local Rebuilder = require "build.rebuilders.verifying-traces" (Verifying_Trace_Store)
   local rebuilder = Rebuilder.create(vt)

   local Scheduler = require "build.schedulers.suspending" (Store)
   local scheduler = Scheduler.create(rebuilder)

   local function build(key)
      return scheduler(nesting_tasks, key, store)
   end

   function global_env.build(key)
      return (build(key))
   end

   do
      local stats = Posix_File_System.get_stats(fs, redo_dsl.REDOFILE_FILE)
      if stats then
         redo_dsl.run_recipe(redo_dsl.REDOFILE_FILE, global_env)()
         redofile_path = redo_dsl.REDOFILE_FILE
      end
   end

   function global_env.build(key)
      error("cannot call the build(key) function after the main script has executed")
   end

   if options.do_clean or options.list_cleanable then
      if options.do_clean then
         printfc("[:red]WARN[:]  Cleaning intermediary files")
      end
      -- FIXME: This should not access the Backing_Store internals.
      assert(Backing_Store == JSON_Store, "NYI: non-JSON backing stores for cleaning")
      local errnos = Posix_File_System.get_errno(fs)
      for key in pairs(backing_store.base.keys) do
         local value = backing_store.base.values[key]
         -- FIXME: This should not access the Rebuilder internals
         local should_delete = not not next(value.dependencies) -- has any dependencies?
         if options.do_clean then
            if should_delete then
               local ok, errmsg, errno = Posix_File_System.try_delete_file(fs, key)
               if not ok then
                  if errno == errnos.ENOENT then
                     printfc("[:yellow]I[:] %s", key)
                  else
                     error("could not delete the file " .. key .. ": " .. errmsg)
                  end
               else
                  printfc("[:red]D[:] %s", key)
               end
            else
               printfc("[:green]K[:] %s", key)
            end
         else
            assert(options.list_cleanable)
            if not should_delete then
               printfc("[:green]K[:] %s", key)
            else
               printfc("[:red]D[:] %s", key)
            end
         end
      end
   elseif #targets == 0 then
      printfc("[:cyan]INFO[:] Implicitly building 'all' target")
      build "all"
   else
      for i = 1, #targets do
         build(targets[i])
      end
   end
end
