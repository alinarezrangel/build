return function(Posix_File_System)
   local M = {}

   local utils = require "build.utils"

   M.REDO_DSL_VERSION = utils.semver "0.1.0"

   M.DEFAULT_NAME = "default"
   M.DO_EXTENSION = "do.lua"
   M.REDOFILE_FILE = "Redofile.lua"

   function M.recipe_files_for_filename(filename)
      local name = utils.basename(filename)
      local segments = utils.split_match(name, "([^%.]*)")
      local recipes = {}
      for i = 1, #segments do
         local sub = utils.table_sub(segments, i)
         local subname = table.concat(sub, ".")
         if i > 1 then
            subname = M.DEFAULT_NAME .. "." .. subname
         end
         recipes[#recipes + 1] = subname .. "." .. M.DO_EXTENSION
      end
      return recipes
   end

   function M.paths_for_recipes(filename)
      local paths = {}
      local orig_filename = filename
      repeat
         local name = utils.dirname(filename)
         local removed_so_far
         if filename ~= orig_filename then
            -- Previous check only to prevent this from happening on the first
            -- iteration.
            if name == "/" or name == "." then
               removed_so_far = orig_filename
            else
               removed_so_far = string.sub(orig_filename, string.len(name), -1)
            end
         else
            removed_so_far = utils.basename(orig_filename)
         end
         local trimmed = string.match(name, "^(.-)/?$")
         paths[#paths + 1] = { path = trimmed, rel = removed_so_far }
         filename = trimmed
      until name == "/" or name == "." or name == ""
      return paths
   end

   function M.find_recipe_for_filename(filename, find)
      local names = M.recipe_files_for_filename(filename)
      local paths = M.paths_for_recipes(filename)
      for i = 1, #paths do
         for j = 1, #names do
            local res = find(paths[i].path .. "/" .. names[j])
            if res then
               return res, paths[i].rel
            end
         end
      end
      return nil
   end

   function M.file_exists(fs, filename)
      local res = Posix_File_System.get_stats(fs, filename)
      return not not res
   end

   function M.extend_env_with_dsl(fs, base_env)
      local env = utils.shallow_copy(base_env)

      env.utils = utils
      env.REDO_DSL_VERSION = M.REDO_DSL_VERSION
      env.SHELL = "sh"

      function env.run_wait(...)
         return Posix_File_System.run_wait(fs, ...)
      end

      function env.run(cli)
         local program = cli[1]
         local args = utils.table_sub(cli, 2)
         local exit_code = env.run_wait(program, args)
         return exit_code
      end

      function env.sh(cmd)
         assert(type(cmd) == "string", "sh(cmd) function only accepts a string")
         local exit_code = env.run {env.SHELL, "-c", cmd}
         assert(exit_code == 0, "sh(cmd): non-zero exit code from shell")
         return exit_code
      end

      function env.shellquote(words)
         local args = utils.shallow_copy(words)
         table.insert(args, 1, "--")
         local res = env.run_wait("shell-quote", args, { capture_stdout = true })
         assert(res.exit_code == 0)
         return utils.chomp_end(res.stdout)
      end

      function env.shf(cmdf, ...)
         local i = 1
         local args = table.pack(...)
         local function repl(c)
            if c == "%" then
               return "%"
            elseif c == "s" then
               local arg = args[i]
               i = i + 1
               return arg
            elseif c == "w" then
               local arg = args[i]
               i = i + 1
               return env.shellquote {arg}
            elseif c == "W" then
               local arg = args[i]
               i = i + 1
               return env.shellquote(arg)
            else
               error("shf(cmdf, ...): unknown escape sequence '%" .. c .. "'")
            end
         end
         local cmd = string.gsub(cmdf, "%%(.)", repl)
         return env.run {env.SHELL, "-c", cmd}
      end

      function env.get_cwd()
         return Posix_File_System.get_current_directory(fs)
      end

      function env.cd(path)
         Posix_File_System.change_current_directory(fs, path)
      end

      function env.read_file(path)
         local handle <close>, errmsg = io.open(path, "rb")
         assert(handle, "read_file(path): " .. tostring(errmsg))
         return handle:read "a"
      end

      function env.write_file(path, contents)
         local handle <close>, errmsg = io.open(path, "wb")
         assert(handle, "write_file(path): " .. tostring(errmsg))
         handle:write(contents)
      end

      join = utils.eager_join

      return env
   end

   function M.make_lua_env()
      local env = utils.shallow_copy(_G)
      env._G = env
      return env
   end

   function M.run_recipe(recipe_filename, env)
      local func, err = loadfile(recipe_filename, "t", env)
      assert(func, err)
      return func
   end

   return M
end
