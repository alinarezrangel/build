return function(...)
   local Posix_File_System = require "build.file-systems.posix"
   local Table_Store = require "build.stores.table"
   local JSON_Store = require "build.stores.json"
   local make_dsl = require "build.dsl.make"
   local colors = require "build.colors"
   local getopt = require "build.getopt"
   local utils = require "build.utils"
   local Phony_Adapter = require "build.rebuilders.phony-adapter"

   local OPTIONS = {
      getopt.ONCE_EACH,
      getopt.opt("C", "directory", "directory", 1),
      getopt.opt(nil, "color", "color", 1),
      getopt.opt(nil, "rebuilder", "rebuilder", 1),
      getopt.opt(nil, "scheduler", "scheduler", 1),
      getopt.opt(nil, "hasher", "hasher", 1),
      getopt.opt("D", "database", "db_file", 1),
      getopt.ONE_OF,
      getopt.opt("f", "file", "makefile", 1),
      getopt.opt(nil, "makefile", "makefile", 1),
      getopt.MANY_OF,
      getopt.flag("h", "help", "show_help"),
      getopt.flag("n", "just-print", "dry_run"),
      getopt.flag(nil, "dry-run", "dry_run"),
      getopt.flag(nil, "recon", "dry_run"),
      getopt.flag("s", "silent", "quiet"),
      getopt.flag(nil, "quiet", "quiet"),
      getopt.flag("v", "version", "show_version"),
      getopt.opt("W", "what-if", "pretend_modified", 1),
      getopt.opt(nil, "new-file", "pretend_modified", 1),
      getopt.opt(nil, "assume-new", "pretend_modified", 1),
      getopt.opt("o", "old-file", "pretend_up_to_date", 1),
      getopt.opt(nil, "assume-old", "pretend_up_to_date", 1),
   }

   local HELP = ([[build.make -- A simple, make-like build tool.
Usage:
    make [OPTION]... [TARGET]...

This simple, make-like tool will rebuild out-of-date files in a directory using
the instructions contained in a makefile. See the man page build.make(1), the
info manual `info build.make` or the web page
<https://alinarezrangel.github.io/build/man/make.html> for more help.

Available options are:

-C DIR, --directory DIR                    : Switch to DIR before operating.
--color always|never|auto                  : Enable or disable colored output.
-f FILE, --file FILE, --makefile FILE      : Use FILE as the makefile.
-h, --help                                 : Show this help and exit.
-n, --just-print, --dry-run, --recon       : Just print what should be done,
                                           . don't do anything.
-s, --silent, --quiet                      : Be more quiet.
-v, --version                              : Show version and exit.
--database FILE                            : Use FILE as the backing database file.
--scheduler NAME                           : Set the scheduler. Must be
                                           . `topological` or `suspending`.
--rebuilder NAME                           : Set the rebuilder. Must be `vt`
                                           . or `mtime`.
--hasher NAME                              : Set the hasher. Must be `sha1`,
                                           . `apenwarr` or `mtime`.
]])

   local VERSION = ([[build.make revision 1

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

   local options, targets = getopt.parse_command_line(OPTIONS, {...})

   options.color = options.color or "auto"

   if options.show_help then
      print(HELP)
      os.exit(true, true)
   elseif options.show_version then
      print(VERSION)
      os.exit(true, true)
   end

   local function read_file(name)
      local handle <close> = io.open(name, "rb")
      if not handle then
         return nil
      else
         return handle:read "a"
      end
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

   local fs = Posix_File_System.global()

   if options.directory then
      printfc("[:cyan]INFO[:] Changing CWD to %s", options.directory)
      Posix_File_System.change_current_directory(fs, options.directory)
   end

   local function get_build_system(Store, config, tasks, dependency_graph)
      local res = {}
      local Base_Rebuilder, base_rebuilder
      assert(config.rebuilder, "must specify a rebuilder with --rebuilder")
      if config.rebuilder == "mtime" then
         Base_Rebuilder = require "build.rebuilders.mtime" (Posix_File_System)
         base_rebuilder = Base_Rebuilder.create(fs)
      elseif config.rebuilder == "vt" then
         local Hasher, hasher
         assert(config.hasher, "the vt rebuilder requires the --hasher option")
         if config.hasher == "sha1" then
            Hasher = require "build.hashers.sha1" (Posix_File_System)
            hasher = Hasher.create(fs)
         elseif config.hasher == "mtime" then
            Hasher = require "build.hashers.mtime" (Posix_File_System)
            hasher = Hasher.create(fs)
         elseif config.hasher == "apenwarr" then
            Hasher = require "build.hashers.apenwarr" (Posix_File_System)
            hasher = Hasher.create(fs)
         else
            error("unknown hasher name: " .. config.hasher)
         end
         assert(config.Backing_Store and config.backing_store,
                "must use --database flag when using the vt rebuilder")
         local Verifying_Trace_Store = require "build.traces.verifying.hash" (config.Backing_Store, Hasher)
         local vt = Verifying_Trace_Store.create(config.backing_store, hasher)
         res.Hasher = Hasher
         res.hasher = hasher
         res.Verifying_Trace_Store = Verifying_Trace_Store
         res.verifying_trace_store = vt
         Base_Rebuilder = require "build.rebuilders.verifying-traces" (Verifying_Trace_Store)
         base_rebuilder = Base_Rebuilder.create(vt)
      else
         error("unknown rebuilder name: " .. config.rebuilder)
      end

      res.Base_Rebuilder = Base_Rebuilder
      res.base_rebuilder = base_rebuilder

      config.is_phony_key = config.is_phony_key or function(key)
         return false
      end

      res.Rebuilder = Phony_Adapter
      res.rebuilder = res.Rebuilder.create(res.base_rebuilder, config.is_phony_key)

      local Scheduler, scheduler, final_tasks
      assert(config.scheduler, "must specify an scheduler with --scheduler")
      if config.scheduler == "topological" then
         Scheduler = require "build.schedulers.topological" (Store)
         final_tasks = Scheduler.topological_tasks(tasks, dependency_graph)
      elseif config.scheduler == "suspending" then
         Scheduler = require "build.schedulers.suspending" (Store)
         final_tasks = tasks
      else
         error("unknown scheduler name: " .. config.scheduler)
      end
      scheduler = Scheduler.create(res.rebuilder)
      res.Scheduler = Scheduler
      res.scheduler = scheduler
      res.tasks = final_tasks

      function res:build(key, store)
         return self.scheduler(self.tasks, key, store)
      end

      return res
   end

   local MAKEFILES_NAMES = {
      "BUILDmakefile",
      "BuildMakefile",
      "makefile",
      "Makefile",
   }

   local makefile
   if options.makefile then
      makefile = assert(read_file(options.makefile), "could not read " .. options.makefile)
   else
      for i = 1, #MAKEFILES_NAMES do
         makefile = read_file(MAKEFILES_NAMES[i])
         if makefile then
            break
         end
      end
      if not makefile then
         error("could not find a suitable makefile")
      end
   end

   local recipe_options = {}

   local function escape_shell(strs)
      local args = {"--"}
      table.move(strs, 1, #strs, 2, args)
      local res = Posix_File_System.run_wait(fs, "shell-quote", args, { capture_stdout = true })
      if res.exit_code ~= 0 then
         error("no shell-quote")
      else
         return utils.chomp_end(res.stdout)
      end
   end

   local function build_shell_invocation(line)
      local final = {}
      for i = 1, #line do
         local el = line[i]
         if type(el) == "string" then
            final[#final + 1] = el
         else
            final[#final + 1] = escape_shell(el)
         end
      end
      return table.concat(final)
   end

   local function run(key, lines_of_code, dependencies, fetch)
      for i = 1, #lines_of_code do
         local line = lines_of_code[i]
         assert(#line >= 1)
         local copy = {}
         table.move(line, 1, #line, 1, copy)
         local display = true
         if line[1] ~= "" and string.sub(line[1], 1, 1) == "+" then
            copy[1] = string.sub(copy[1], 2)
            display = false
         end
         if options.quiet then
            display = false
         end
         local script = build_shell_invocation(copy)
         if display then
            printfc("[:red]RUN[:] %s", script)
         end
         assert(#recipe_options.shell > 0)
         local program = recipe_options.shell[1]
         local args = {}
         for i = 2, #recipe_options.shell do
            args[i - 1] = recipe_options.shell[i]
         end
         args[#args + 1] = script
         if not options.dry_run then
            local exit_code = Posix_File_System.run_wait(fs, program, args)
            if not options.ignore_errors then
               assert(exit_code == 0, "error while building " .. key)
            end
         end
      end
   end

   local recipe = make_dsl.parse_and_prepare(makefile, run)

   local function get_special_target(name)
      return recipe.dependency_graph["." .. name]
   end

   recipe_options.shell = get_special_target "SHELL" or {"sh", "-c"}
   recipe_options.phony = get_special_target "PHONY" or {}

   recipe_options.is_phony = {}
   for i = 1, #recipe_options.phony do
      recipe_options.is_phony[recipe_options.phony[i]] = true
   end

   local function middletasks(key)
      if not recipe.dependency_graph[key] then
         return function(fetch)
            if not Posix_File_System.get_mtime(fs, key) then
               printfc("[:red]ERROR[:] The file «%s» does not exists and there are no instructions for building it", key)
               error("Could not build " .. key)
            else
               return true
            end
         end
      else
         local task = recipe.tasks(key)
         return function(fetch)
            local is_phony = recipe_options.is_phony[key]
            if not is_phony and not options.quiet then
               printfc("[:green]BUILDING[:] %s", key)
            end
            local value = task(fetch)
            if not is_phony and not options.quiet then
               printfc("[:blue]DONE[:] %s", key)
            end
            return value
         end
      end
   end

   local store = Table_Store.empty()
   local build_config = {
      rebuilder = options.rebuilder or "mtime",
      scheduler = options.scheduler or "topological",
      hasher = options.hasher,
      is_phony_key = function(key)
         return recipe_options.is_phony[key]
      end,
   }

   local function close_db()
      if not options.db_file then
         return
      end
      printfc("[:cyan]INFO[:] Closing the database")
      assert(build_config.Backing_Store).save(assert(build_config.backing_store))
   end
   local backing_store_closer <close> = utils.closer(close_db, nil)
   if options.db_file then
      build_config.Backing_Store = JSON_Store
      build_config.backing_store = build_config.Backing_Store.open(options.db_file)
   end
   local generated_build_system = get_build_system(Table_Store, build_config, middletasks, recipe.dependency_graph)
   local function make(key)
      return generated_build_system:build(key, store)
   end

   for i = 1, #targets do
      make(targets[i])
   end
   if #targets == 0 then
      printfc("[:cyan]INFO[:] Defaulting to all")
      make "all"
   end
end
