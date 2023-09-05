local M = {}

local utils = require "build.utils"

-- Creates a flag for `getopt`.
--
-- Flags are boolean values that do not take an argument. For example, `--help`
-- or `--verbose` could be flags.
--
-- Takes one of 3 forms:
--
--     M.flag(name)
--     M.flag(short, long)
--     M.flag(short, long, var)
--
-- The first form is a DWIM (do what I mean) one: it accepts a string and
-- derives the other properties from it. `M.flag "-h"` will create a flag with
-- a short form of `-h` and a var of `h`, while `M.flag "--help"` will create a
-- flag with a long form of `--help` and a var of `help`.
--
-- The second form derives the var name from the long form option. For example:
-- `M.flag("h", "help")` is the same than `M.flag("h", "help", "help")`.
--
-- The third form allows you to specify all fields. For example: `M.flag("h",
-- "help", "show_help")`.
--
-- IMPORTANT: Note how only the first form takes a string prefixed with `"-"`
-- or `"--"`.
function M.flag(...)
   local n = select("#", ...)
   local opt = { short = nil, long = nil, var = nil, type = "flag" }
   if n == 1 then
      local name = ...
      if string.sub(name, 1, 2) == "--" then
         opt.long = name
      else
         assert(string.sub(name, 1, 1) == "-")
         opt.short = name
      end
      opt.var = string.match(name, "^%-%-?([^%s=]*)")
   elseif n == 2 then
      local short, long = ...
      opt.short = short
      opt.long = long
      opt.var = long
   elseif n == 3 then
      local short, long, var = ...
      opt.short = short
      opt.long = long
      opt.var = var
   else
      error("invalid flag call: must be one of flag(name), flag(short, long) or flag(short, long, var)")
   end
   return opt
end

-- Creates an option for `getopt`.
--
-- Unlike flags, options can take 1 or more arguments; the number of arguments
-- that an option takes is known as it's nargs. This function takes one of five
-- forms:
--
--     M.opt(name)
--     M.opt(short, long)
--     M.opt(short, long, var)
--     M.opt(short, long, nargs)
--     M.opt(short, long, var, nargs)
--
-- The first one is the DWIM form, just like `M.flag` it derives the var name
-- from the `name` parameter, which is a short or long form string. The nargs
-- field defaults to 1.
--
-- The second form derives the var name from the long form. The nargs field
-- defaults to 1.
--
-- The third form allows you to specify the var name while the fourth form
-- derives it from the long form, instead allowing you to specify the
-- nargs. There forms are disambiguated from the type of the third argument:
-- number means nargs and string means name.
--
-- The fifth form allows you to specify all fields directly.
--
-- IMPORTANT: Note how only the first form takes a string prefixed with `"-"`
-- or `"--"`.
function M.opt(...)
   local n = select("#", ...)
   local opt = { short = nil, long = nil, var = nil, nargs = 1, type = "option" }
   if n == 1 then
      local name = ...
      if string.sub(name, 1, 2) == "--" then
         opt.long = name
      else
         assert(string.sub(name, 1, 1) == "-")
         opt.short = name
      end
      opt.var = string.match(name, "^%-%-?([^%s=]*)")
   elseif n == 2 then
      local short, long = ...
      opt.short = short
      opt.long = long
      opt.var = long
   elseif n == 3 then
      local short, long, var_or_nargs = ...
      opt.short = short
      opt.long = long
      if type(var_or_nargs) == "number" then
         opt.nargs = var_or_nargs
         opt.var = opt.long
      else
         opt.var = var_or_nargs
      end
   elseif n == 4 then
      local short, long, var, nargs = ...
      opt.short = short
      opt.long = long
      opt.var = var
      opt.nargs = nargs
   else
      error("invalid opt call: must be one of opt(name), opt(short, long), opt(short, long, var_or_nargs) or opt(short, long, var, nargs)")
   end
   return opt
end

-- Groups:
M.MANY_OF = {}   -- Many of the following.
M.ONE_OF = {}    -- One of any of the following.
M.ONCE_EACH = {} -- One of each of the following.

-- Parses the command line arguments.
--
-- `cli` is the sequential table with the arguments. `options` is the
-- sequential table with the list of options to parse (either `M.flag`s or
-- `M.opt`s). `config` is an optional table that changes some of the behaviour
-- of `getopt`.
--
-- Returns 2 values: a table mapping each option name to their value list, and
-- the sequential table of all positional command line arguments passed.
--
-- The values `M.MANY_OF`, `M.ONE_OF` and `M.ONCE_EACH` are ignored when they
-- appear as elements of `options`.
--
-- # Command line parsing #
--
-- Long form options can have their value specified via the syntax
-- `--option=value` or via `--option value1 value2 ...`. Short form options can
-- have their values specified like `-s value1 value2 ...`.
--
-- Short form options can also be combined on a single argument: `-abc value1
-- value2 ...`. When this happens, each character of the combined short form
-- argument is interpreted as a short form option itself. If some of them
-- require values, the values are extracted sequentially from the command line
-- arguments. For example, if the flag `-a` takes 0 arguments, `-b` takes 1 and
-- `-c` takes 2 then `-abc B C1 C2` will assign `B` to `-b` and `C1` and `C2`
-- to `-c`.
--
-- By default, once the first non-option argument is found, all remaining
-- arguments are taken as positional. This means that in `-a b -c` (assuming
-- that `-a` takes no arguments) `-c` will not be interpreted as an option. You
-- can change this the `gnu_mixed = true` option in the `config` table. When
-- this option is set, positional and options can be mixed together.
--
-- The argument `-` (single dash) is always interpreted as a non-option. The
-- special argument `--` will finish the options, parsing all subsequent
-- arguments as positional. `--` cannot be "mixed" with other short options:
-- `-a-` is NOT parsed as `-a --`.
--
-- # Values produced #
--
-- When an option is parsed, it is assigned a value. Each option actually has a
-- *value list* containing all found values.
--
-- If the option takes no arguments (because it's nargs is 0 or it is a flag)
-- then the value associated will be `{}` (the empty table). This means that
-- the value list associated with a flag that was found is a list with possibly
-- many empty lists inside. For example, if `-h` is a flag, then `-h -h` will
-- result in a value list of `{{}, {}}`.
--
-- If the option takes at least one narg, those arguments will be pushed to the
-- value list. For example, if the option `-o` takes 1 argument, then `-o 1 -o
-- 2` will result in the value list `{{"1"}, {"2"}}`. Whereas if `-T` takes 2
-- nargs then `-T A B -T C D` will result in `{{"A", "B"}, {"C", "D"}}`.
--
-- If an option was not found, its key will not be set on the returned table.
--
-- # `parseopt` #
--
-- This mechanism of returning values is extremely flexible, allowing you to
-- partially reconstruct the `cli` list from the returned values. Nonetheless,
-- it is not very useful for CLI tools. For these, see the `M.parseopt`
-- function which modifies the returned tables so that they can be used more
-- easily.
function M.getopt(options, cli, config)
   config = config or {}
   local gnu_mixed = config.gnu_mixed

   local vars = {}
   local pos = {}

   local by_cli = { short = {}, long = {} }

   for i = 1, #options do
      local opt = options[i]
      if opt.short then
         by_cli.short[opt.short] = opt
      end
      if opt.long then
         by_cli.long[opt.long] = opt
      end
   end

   local function handle_pos(pos_arg)
      pos[#pos + 1] = pos_arg
      return not gnu_mixed
   end

   local function nargs_of(type, opt)
      return assert(by_cli[type][opt], "option " .. opt .. " does not exists").nargs or 0
   end

   local function handle_opt(type, opt, values)
      local var = assert(by_cli[type][opt], "option " .. opt .. " does not exists").var
      vars[var] = vars[var] or {}
      table.insert(vars[var], values)
   end

   local i = 1
   while i <= #cli do
      local arg = cli[i]
      i = i + 1
      if arg == "" then
         if handle_pos(arg) then break end
      elseif arg == "-" then
         if handle_pos(arg) then break end
      elseif arg == "--" then
         break
      elseif string.sub(arg, 1, 2) == "--" then
         local name, value = string.match(arg, "^%-%-([^-][^=]*)=(.*)$")
         if name and value then
            handle_opt("long", name, {value})
         else
            name = string.match(arg, "^%-%-([^-][^=]*)$")
            if name then
               local nargs = nargs_of("long", name)
               local values = utils.table_sub(cli, i, i + nargs - 1)
               i = i + nargs
               handle_opt("long", name, values)
            else
               error("invalid syntax in option " .. arg)
            end
         end
      elseif string.sub(arg, 1, 1) == "-" then
         for j = 2, string.len(arg) do
            local flag = string.sub(arg, j, j)
            local nargs = nargs_of("short", flag)
            local values = utils.table_sub(cli, i, i + nargs - 1)
            i = i + nargs
            handle_opt("short", flag, values)
         end
      else
         if handle_pos(arg) then break end
      end
   end

   for j = i, #cli do
      handle_pos(cli[j])
   end

   return vars, pos
end

-- All values that will be treated as "truthy" when dealing with CLI flags.
M.TRUTHY = {
   yes = true,
   enable = true,
   enabled = true,
}

-- All "falsy" values.
M.FALSY = {
   no = true,
   disable = true,
   disabled = true,
}

-- Fixup the return value of `getopt` so that tools can be implemented more
-- easily.
--
-- `M.getopt` is very useful and flexible, but it does NO validation of the
-- parsed command line. This function validates and transforms the returned
-- table.
--
-- `options` is the same `options` list passed to `M.getopt`, while `vars` is
-- the first return value of `M.getopt`.
--
-- The `options` list can contain the special elements `M.MANY_OF`, `M.ONE_OF`
-- and `M.ONCE_EACH`, each one defining a *group*. An implicit `M.MANY_OF` is
-- added at the beginning of `options`.
--
-- Each group puts restrictions on how many repetitions the options contained
-- may have. `MANY_OF` is the default and it means "many of any of these
-- options". `ONE_OF` means "a single one of any of the following", and
-- `ONCE_EACH` means, well, "once of each one of the following".
--
-- For example: to say that the options `-h` and `-v` may only appear once, and
-- cannot be mixed together you could say:
--
--     options = {
--        M.ONE_OF,
--        M.flag("-h"),
--        M.flag("-v"),
--     }
--
-- Whereas to say that `-V` and `-d` can appear only once, but both can appear
-- together say:
--
--     options = {
--        M.ONCE_EACH,
--        M.flag("-V"),
--        M.flag("-d"),
--     }
--
-- You can have several of these groups:
--
--     options = {
--        -- Implicit M.MANY_OF
--        M.opt("i", "input", "input_files", 1),
--        M.ONE_OF,
--        M.flag("h", "help"),
--        M.flag("v", "version"),
--        M.ONCE_EACH,
--        M.opt("o", "output", "output_file", 1),
--        M.flag("V", "verbose"),
--     }
--
-- The second thing this function does is to transform the `vars` table: If an
-- option is a flag, it's value in `vars` is changed from a list of empty lists
-- to a single `true` or `false`/`nil`. Similarly, if an option has a nargs of
-- 1 then rather than returning a list of lists of strings (like `{{"a"},
-- {"b"}, {"c"}}`) the list is flattened (to `{"a", "b", "c"}`). This only
-- happens when nargs is 1, so that for more complex options you can still
-- distinguish the original grouping.
--
-- Returns the new `vars` table with all of these changes.
function M.parseopt(options, vars)
   local nvars = {}
   local reps, group = "many", nil
   local groups = {}
   for i = 1, #options do
      local opt = options[i]
      if opt == M.ONCE_EACH or opt == M.ONE_OF or opt == M.MANY_OF then
         group = i
         assert(not groups[group])
         groups[group] = { type = opt, active = true }
      elseif opt.var then
         table.insert(groups[group], opt.var)
      end
   end
   group = nil

   local handled_option = {}

   for i = 1, #options do
      local opt = options[i]
      if opt == M.ONCE_EACH or opt == M.ONE_OF or opt == M.MANY_OF then
         group = i
         if opt == M.MANY_OF then
            reps = "many"
         elseif opt == M.ONCE_EACH then
            reps = "once-each"
         elseif opt == M.ONE_OF then
            reps = "one-of"
         end
      elseif opt.var and not handled_option[opt.var] then
         handled_option[opt.var] = true

         local var = opt.var
         local values = vars[var]
         if values and #values > 0 then
            if reps == "one-of" then
               groups[group].active = false
            end
            if opt.type == "flag" then
               if reps == "once-each" or reps == "one-of" then
                  assert(#values == 1, "repeated option " .. opt.long)
               end
               local last = values[#values]
               assert(#last == 0 or #last == 1)
               if #last == 0 then
                  nvars[var] = true
               elseif M.TRUTHY[last[1]] then
                  nvars[var] = true
               elseif M.FALSY[last[1]] then
                  nvars[var] = false
               else
                  error("invalid value for flag option " .. opt.long .. ": " .. last[1])
               end
            else
               if reps == "once-each" or reps == "one-of" then
                  assert(#values == 1, "repeated option: " .. opt.long)
                  if opt.nargs == 1 then
                     assert(#values[1] == 1)
                     nvars[var] = values[1][1]
                  else
                     nvars[var] = values[1]
                  end
               else
                  if opt.nargs == 1 then
                     nvars[var] = values
                     for j = 1, #nvars[var] do
                        assert(#nvars[var][j] == 1)
                        nvars[var][j] = nvars[var][j][1]
                     end
                  else
                     nvars[var] = values
                  end
               end
            end
         end
      end
   end

   return nvars
end

-- Helper function that uses `getopt` to parse a `cli` table, then applies
-- `parseopt` to the result.
--
-- Returns 2 tables: the "better" vars table as returned from `parseopt` and
-- the sequential table with all the positional arguments.
function M.parse_command_line(options, cli, config)
   local vars, pos = M.getopt(options, cli, config)
   local nvars = M.parseopt(options, vars)
   return nvars, pos
end

return M
