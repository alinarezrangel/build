return function(...)
   local Posix_File_System = require "build.file-systems.posix"
   local Table_Store = require "build.stores.table"
   local Build = require "build.systems.make" (Posix_File_System, Table_Store)
   local make_dsl = require "build.dsl.make"
   local colors = require "build.colors"
   local getopt = require "build.getopt"
   local utils = require "build.utils"

   local OPTIONS = {
      getopt.ONCE_EACH,
      getopt.opt("C", "directory", "directory", 1),
      getopt.opt("j", "jobs", "num_jobs", 1),
      getopt.opt(nil, "color", "color", 1),
      getopt.ONE_OF,
      getopt.opt("f", "file", "makefile", 1),
      getopt.opt(nil, "makefile", "makefile", 1),
      getopt.MANY_OF,
      getopt.flag("h", "help", "show_help"),
      getopt.flag("B", "always-make", "always_outdated"),
      getopt.flag("e", "environment-overrides", "env_overrides"),
      getopt.flag("i", "ignore-errors", "ignore_errors"),
      getopt.opt("I", "include-dir", "include_dir", 1),
      getopt.flag("n", "just-print", "dry_run"),
      getopt.flag(nil, "dry-run", "dry_run"),
      getopt.flag(nil, "recon", "dry_run"),
      getopt.opt("o", "old-file", "assume_old", 1),
      getopt.opt(nil, "assume-old", "assume_old", 1),
      getopt.flag("q", "question", "question_mode"),
      getopt.flag("s", "silent", "quiet"),
      getopt.flag(nil, "quiet", "quiet"),
      getopt.flag("t", "touch", "touch_files"),
      getopt.flag("v", "version", "show_version"),
      getopt.opt("W", "what-if", "assume_new", 1),
      getopt.opt(nil, "new-file", "assume_new", 1),
      getopt.opt(nil, "assume-new", "assume_new", 1),
      getopt.opt("a", "assume-up-to-date", "assume_up_to_date", 1),
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
-j JOBS, --jobs JOBS                       : Start JOBS parallel jobs.
--color always|never|auto                  : Enable or disable colored output.
-f FILE, --file FILE, --makefile FILE      : Use FILE as the makefile.
-h, --help                                 : Show this help and exit.
-B, --always-make                          : Treat all targets as outdated.
-e, --environment-overrides                : Make environment variables
                                           . override make variables.
-i, --ignore-errors                        : Proceed despite errors.
-I DIR, --include-dir DIR                  : Add DIR to the list of
                                           . directories to search when
                                           . including.
-n, --just-print, --dry-run, --recon       : Just print what should be done,
                                           . don't do anything.
-o FILE, --old-file FILE                   : Assume FILE to be very old and
                                           . don't update it.
-q, --question                             : Exit indicating if everything is
                                           . up to date.
-s, --silect, --quiet                      : Be more quiet.
-t, --touch                                : Touch, but don't build files.
-v, --version                              : Show version and exit.
-W FILE, --what-if FILE, --assume-new FILE : Assume that FILE very new and
                                           . don't update it.
-a TARGET, --assume-up-to-date TARGET      : Assume that TARGET is up to date.
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
      if options.color == "never" then
         print(string.format(string.gsub(fmt, M.PATTERN, ""), ...))
      else
         print(colors.format(fmt, ...))
      end
   end

   local fs = Posix_File_System.global()

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
      local res = Posix_File_System.run_wait(fs, "shell-quote", strs, { capture_stdout = true })
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

   local store = Table_Store.empty()
   local build = Build.create(fs)

   local function middletasks(key)
      if not recipe.dependency_graph[key] then
         return function(fetch)
            if not Posix_File_System.get_mtime(fs, key) then
               printf("The file does not exists and there are no instructions for building it")
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

   local topotasks = Build.Scheduler.topological_tasks(middletasks, recipe.dependency_graph)
   local function make(key)
      return build(topotasks, key, store)
   end

   for i = 1, #targets do
      make(targets[i])
   end
   if #targets == 0 then
      make "all"
   end
end
