local M = {}

local function tsub(t, i, j)
   local len = t.n or #t
   i = i or 1
   j = j or len
   local res, w = {}, 1
   for k = i, j do
      res[w] = t[k]
      w = w + 1
   end
   return res
end

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
M.MANY_OF = {}
M.ONE_OF = {}
M.ONCE_EACH = {}

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
               local values = tsub(cli, i, i + nargs - 1)
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
            local values = tsub(cli, i, i + nargs - 1)
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

M.TRUTHY = {
   yes = true,
   enable = true,
   enabled = true,
}

M.FALSY = {
   no = true,
   disable = true,
   disabled = true,
}

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

function M.parse_command_line(options, cli, config)
   local vars, pos = M.getopt(options, cli, config)
   local nvars = M.parseopt(options, vars)
   return nvars, pos
end

return M
