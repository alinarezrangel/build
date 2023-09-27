local M = {}

local utils = require "build.utils"

local function pos_to_srcloc(src, i)
   local lineno, colno = 1, 0
   -- for j = 1, i do
   --    local c = string.sub(src, j, j)
   --    if c == "\n" then
   --       lineno = lineno + 1
   --       colno = 0
   --    else
   --       colno = colno + 1
   --    end
   -- end
   local last_nl = 1
   while last_nl <= string.len(src) do
      assert(last_nl <= i)
      local next_nl = string.find(src, "\n", last_nl, true)
      assert(not next_nl or next_nl >= last_nl)
      if not next_nl then
         next_nl = string.len(src)
      end
      if next_nl >= i then
         colno = i - last_nl
         break
      else
         lineno = lineno + 1
         last_nl = next_nl + 1
      end
   end
   return { lineno = lineno, colno = colno, offset = i }
   -- And thats how you replace a trivially correct, 9-line algorithm by an
   -- unnoticeably faster way more complex 17-lines one...
end

function M.srcloc_to_string(srcloc)
   return string.format("«-%d-%d-%d»", srcloc.lineno, srcloc.colno, srcloc.offset)
end

local function print_line(src, i)
   print(">", (string.sub(src, i, string.find(src, "\n", i, true) or string.len(src))))
end

local function skip_simple_ws(src, i)
   return (string.match(src, "^[ \t]*()", i)) or i
end

local function skip_ws(src, i)
   i = skip_simple_ws(src, i)
   local c = string.sub(src, i, i)
   if c == "#" then
      -- Read up-to, but not including, the next newline. If the newline is
      -- escaped with a `\` then read the next line, again,
      -- up-to-but-not-including the \n.
      while i <= string.len(src) do
         local escapes, ni = string.match(src, "^.-(\\*)\n()", i)
         if not escapes or not ni then
            -- This comment extents to the end of the file.
            i = string.len(src) + 1
            break
         elseif string.len(escapes) % 2 == 1 then
            -- The comment was extended to the next line
            i = ni
         else
            i = ni - 1 -- just before the \n
            break
         end
      end
      return skip_ws(src, i)
   else
      local ni = string.match(src, "^\\\n()", i)
      if ni then
         i = ni
         return skip_ws(src, i)
      else
         return i
      end
   end
end

local VARIABLE_PATT = "[^:#=%s%(%)%[%]%{%}]"

local function read_variable_name(src, i)
   local name, ni = string.match(src, "^("..VARIABLE_PATT.."*)()", i)
   if name and ni then
      return name, ni
   else
      return nil, ni or i, "Could not read a variable name"
   end
end

local function read_variable_ref(src, i)
   local name, ni = string.match(src, "^%$("..VARIABLE_PATT..")()", i)
   if name and ni then
      return { type = "variable", name = name }, ni
   end
   ni = string.match(src, "^%$%(()", i)
   if not ni then
      return nil, i, "Expected `$(` (variable reference start)"
   end
   i = ni
   local errmsg
   name, ni, errmsg = read_variable_name(src, i)
   if not name or not ni then
      return nil, ni or i, errmsg
   end
   i = ni
   ni = string.match(src, "^%)()", i)
   if not ni then
      return nil, i, "Expected `)` (variable reference end)"
   end
   i = ni
   return { type = "variable", name = name }, i
end

local ESCAPES = {
   ['"'] = '"',
   ["'"] = "'",
   ["\\"] = "\\",
   ["n"] = "\n",
   ["t"] = "\t",
   ["$"] = "$",
}

local function read_string(src, i)
   if string.sub(src, i, i) ~= '"' then
      return nil, i, "Expected a literal part, a pattern, a glob, an escaped $, a variable reference or a string"
   end
   i = i + 1
   local parts = {}
   while true do
      assert(i <= string.len(src))
      simple, ni = string.match(src, "^([^\\%$\"]*)()", i)
      assert(simple and ni)
      parts[#parts + 1] = { type = "literal", text = simple }
      i = ni
      local c = string.sub(src, i, i)
      assert(c == '"' or c == "\\" or c == "$")
      if c == '"' then
         -- EOS
         i = i + 1
         return { type = "string", parts = parts }, i
      elseif c == "\\" then
         i = i + 1
         assert(i <= string.len(src))
         local escape = string.sub(src, i, i)
         i = i + 1
         local escaped
         if escape == "x" then
            escaped = string.char(tonumber("0x" .. string.sub(src, i, i + 1)))
            i = i + 2
            assert(i <= string.len(src))
         else
            escaped = assert(ESCAPES[escape])
         end
         parts[#parts + 1] = { type = "literal", text = escaped }
      elseif c == "$" then
         var, ni = read_variable_ref(src, i)
         assert(var and ni)
         i = ni
         parts[#parts + 1] = var
      end
   end
end

local function read_part(src, i)
   local simple, ni = string.match(src, "^([a-zA-Z0-9%._%+%-%*@,~/=]+)()", i)
   if simple and ni then
      return { type = "literal", text = simple }, ni
   end
   ni = string.match(src, "^%%()", i)
   if ni then
      return { type = "pattern" }, ni
   end
   ni = string.match(src, "^%*%*[^%*]()", i)
   if ni then
      return { type = "dir-glob" }, ni
   end
   ni = string.match(src, "^%*[^%*]()", i)
   if ni then
      return { type = "file-glob" }, ni
   end
   ni = string.match(src, "^%$%$()", i)
   if ni then
      return { type = "literal", text = "$" }, ni
   end
   simple, ni = string.match(src, "^`([^`]*)`()", i)
   if simple and ni then
      return { type = "shell", text = simple }, ni
   end
   local escaped
   escaped, ni = string.match(src, "^\\([\\#:=|])()", i)
   if escaped and ni then
      return { type = "literal", text = escaped }, ni
   end
   local var, errmsg
   var, ni, errmsg = read_variable_ref(src, i)
   if var and ni then
      return var, ni
   elseif ni and ni ~= i then
      return nil, ni, errmsg
   else
      return read_string(src, i)
   end
end

local function read_component(src, i)
   local parts = {}
   while true do
      local part, ni, errmsg = read_part(src, i)
      if part and ni then
         parts[#parts + 1] = part
         i = ni
      elseif #parts == 0 then
         return nil, ni or i, "Expected at least one component part: " .. errmsg
      else
         return { type = "component", parts = parts }, i
      end
   end
end

local function at_eof_or_nl(src, i)
   return i > string.len(src) or string.sub(src, i, i) == "\n"
end

local function read_task_header(src, i)
   local target, dependencies, order_only_dependencies = nil, {}, {}
   local ni, errmsg
   i = skip_ws(src, i)
   target, ni, errmsg = read_component(src, i)
   if not target or not ni then
      return nil, ni or i, "Could not read target: " .. errmsg
   end
   i = skip_ws(src, ni)
   if string.sub(src, i, i) ~= ":" then
      return nil, i, "Expected the ':' separating the target from it's dependencies"
   end
   i = i + 1
   local needs_order_only = false
   while true do
      i = skip_ws(src, i)
      if string.sub(src, i, i) == "|" then
         needs_order_only = true
         break
      elseif at_eof_or_nl(src, i) then
         break
      end
      local dep
      dep, ni, errmsg = read_component(src, i)
      if not dep or not ni then
         return nil, ni or i, "Could not read dependency: " .. errmsg
      end
      i = ni
      dependencies[#dependencies + 1] = dep
   end
   if needs_order_only then
      i = i + 1
      while true do
         i = skip_ws(src, i)
         if at_eof_or_nl(src, i) then
            break
         end
         local dep
         dep, ni, errmsg = read_component(src, i)
         if not dep or not ni then
            return nil, ni or i, "Could not read order-only dependency: " .. errmsg
         end
         i = ni
         order_only_dependencies[#order_only_dependencies + 1] = dep
      end
   end

   i = skip_ws(src, i)
   if i > string.len(src) then
      return nil, i, "Expected newline ending the task header but found EOF"
   elseif string.sub(src, i, i) ~= "\n" then
      return nil, i, string.format("Expected newline ending the task header but got: %q",
                                   string.sub(src, i, i))
   end
   i = i + 1

   return {
      type = "task-header",
      target = target,
      dependencies = dependencies,
      order_only_dependencies = order_only_dependencies,
   }, i
end

local function read_components(src, i, whatami)
   local values = {}
   while true do
      i = skip_ws(src, i)
      if at_eof_or_nl(src, i) then
         break
      end
      local value
      value, ni, errmsg = read_component(src, i)
      if not value or not ni then
         return nil, ni or i, "Could not read values of " .. whatami .. ": " .. errmsg
      end
      i = ni
      values[#values + 1] = value
   end

   i = skip_ws(src, i)
   if i > string.len(src) then
      return nil, i, "Expected newline ending the " .. whatami .. " but got EOF"
   elseif string.sub(src, i, i) ~= "\n" then
      return nil, i, string.format("Expected newline ending but got: %q",
                                   string.sub(src, i, i))
   end
   i = i + 1

   return values, i
end

local function read_variable_assigment(src, i)
   local name, ni, errmsg = read_variable_name(src, i)
   if not name or not ni then
      return nil, ni or i, "Could not read variable name in assigment: " .. errmsg
   end
   i = skip_ws(src, ni)
   local override, immediate = true, false
   if string.sub(src, i, i) == "=" then
      i = i + 1
   elseif string.sub(src, i, i + 1) == ":=" then
      i = i + 2
      immediate = true
   elseif string.sub(src, i, i + 2) == "::=" then
      i = i + 3
      immediate = true
   elseif string.sub(src, i, i + 1) == "?=" then
      i = i + 2
      override = false
   else
      return nil, i, "Expected assignment operator `=`, `:=`, `::=` or `?=`"
   end

   local values = {}
   values, ni, errmsg = read_components(src, i, "variable assigment")
   if not values then
      return nil, i, errmsg
   end
   i = ni

   return {
      type = "assigment",
      override = override,
      immediate = immediate,
      target = name,
      expression_list = values,
   }, i
end

local function read_include(src, i)
   local ni = string.match(src, "^include%s+()", i)
   if not ni then
      return nil, "expected 'include' keyword"
   end
   i = ni

   local values = {}
   values, ni, errmsg = read_components(src, i, "include directive")
   if not values then
      return nil, i, errmsg
   end
   i = ni

   return {
      type = "include",
      filenames = values,
   }, i
end

local function read_task_line(src, i, previous_indentation)
   local indentation, ni = string.match(src, "^([ \t]+)()", i)
   if not indentation or not ni then
      return nil, ni or i, "Indentation expected before task body"
   end
   local intrinsic_indentation, extrinsic_indentation = "", ""
   if previous_indentation then
      if not utils.is_prefix(indentation, previous_indentation) then
         return nil, i, "Expected same indentation as previous line"
      end
      intrinsic_indentation = string.sub(indentation, string.len(previous_indentation) + 1)
      extrinsic_indentation = string.sub(indentation, 1, string.len(previous_indentation))
      assert(extrinsic_indentation == previous_indentation)
   else
      extrinsic_indentation = indentation
   end
   i = ni

   local escaped, st
   st, escaped, ni = string.match(src, "^[^\n]-()(\\*)\n()", i)
   if not st or not escaped or not ni then
      -- This shell extends to the end of the file
      escaped = ""
      ni = string.len(src) + 1
      st = ni
   end
   local line = string.sub(src, i, st - 1) -- subtract 1 as to not get the
                                           -- newline / first backslash
   i = ni
   local num_backslashes
   if string.len(escaped) % 2 == 1 then
      num_backslashes = (string.len(escaped) - 1) / 2
   else
      num_backslashes = string.len(escaped) / 2
   end

   local final_line = intrinsic_indentation .. line .. string.rep("\\", num_backslashes)
   local line_els = {}
   do
      local function add_literal(l)
         line_els[#line_els + 1] = { literal = l }
      end
      local function add_var(v)
         line_els[#line_els + 1] = { variable = v }
      end
      local j, nj = 1, 1
      while true do
         nj = string.find(final_line, "$", j, true)
         if not nj then
            add_literal(string.sub(final_line, j))
            break
         else
            add_literal(string.sub(final_line, j, nj - 1))
            j = nj
            local var, errmsg
            var, nj, errmsg = read_variable_ref(final_line, j)
            if not var or not nj then
               return nil, nj or j, "Expected variable reference in body: " .. errmsg
            else
               j = nj
               add_var(var)
            end
         end
      end
   end

   return {
      type = "task-line",
      line = final_line,
      elements = line_els,
      indentation = extrinsic_indentation,
   }, i
end

local function read_task_body(src, i)
   local lines = {}
   local previous_indentation = nil
   while string.match(src, "^[ \t]", i) and i <= string.len(src) do
      local line, ni, errmsg = read_task_line(src, i, previous_indentation)
      if not line or not ni then
         return nil, ni or i, "Could not read task body: " .. errmsg
      end
      previous_indentation = line.indentation
      i = ni
      lines[#lines + 1] = line
   end
   return {
      type = "task-body",
      lines = lines,
      indentation = previous_indentation or "",
   }, i
end

local function read_task(src, i)
   local header, ni, errmsg = read_task_header(src, i)
   if not header or not ni then
      return nil, ni or i, "Could not read rule for task: " .. errmsg
   end
   i = ni
   local body
   body, ni, errmsg = read_task_body(src, i)
   if not body or not ni then
      return nil, ni or i, "Could not read recipe for task: " .. errmsg
   end
   i = ni
   return {
      type = "task",
      header = header,
      body = body,
   }, i
end

local function skip_nls(src, i)
   i = skip_ws(src, i)
   if string.sub(src, i, i) == "\n" then
      i = i + 1
      return skip_nls(src, i)
   else
      return i
   end
end

local function read_makefile(src, i)
   local children = {}
   while i <= string.len(src) do
      i = skip_nls(src, i)
      local assigment, ni_1, errmsg_1 = read_variable_assigment(src, i)
      if assigment and ni_1 then
         i = ni_1
         table.insert(children, assigment)
      else
         local task, ni_2, errmsg_2 = read_task(src, i)
         if task and ni_2 then
            i = ni_2
            table.insert(children, task)
         else
            local include, ni_3, errmsg_3 = read_include(src, i)
            if include and ni_3 then
               i = ni_3
               table.insert(children, include)
            else
               return nil, i,
                  string.format("Expected assigment: %s %s\n         or a task: %s %s\n         or an include: %s %s",
                                M.srcloc_to_string(pos_to_srcloc(src, ni_1)),
                                errmsg_1,
                                M.srcloc_to_string(pos_to_srcloc(src, ni_2)),
                                errmsg_2,
                                M.srcloc_to_string(pos_to_srcloc(src, ni_3)),
                                errmsg_3)
            end
         end
      end
   end
   i = skip_nls(src, i)
   return {
      type = "makefile",
      children = children,
   }, i
end

local function read_full_makefile(src, i)
   local ast, ni, errmsg = read_makefile(src, i)
   i = ni or i
   if i <= string.len(src) then
      return nil, i, errmsg or "Could not parse the whole file"
   else
      return ast, i
   end
end

function M.parse_string(src)
   local ast, i, errmsg = read_full_makefile(src, 1)
   if not ast or not i then
      i = i or 1
      return nil, M.srcloc_to_string(pos_to_srcloc(src, i)) .. ": " .. errmsg
   else
      return ast
   end
end

function M.parse_file(file_handle)
   return M.parse_string(file_handle:read "a")
end

function M.make_os_env(env)
   local env = { own = {} }

   function env:get(name)
      return { value = {os.getenv(name)} }
   end

   function env:has(name)
      return self.own[name]
   end

   function env:set(name, value_or_ast)
      if self.own[name] and value_or_ast.value then
         local stdlib = require "posix.stdlib"
         stdlib.setenv(name, table.concat(value_or_ast.value, " "))
      end
   end

   function env:new(name)
      local stdlib = require "posix.stdlib"
      stdlib.setenv(name, "")
      self.own[name] = true
   end

   return env
end

function M.make_empty_env()
   local env = {}

   function env:get(name)
      error("variable " .. name .. " does not exists")
   end

   function env:has(name)
      return false
   end

   function env:set(name, value_or_ast) end

   function env:new(name) end

   return env
end

function M.make_subenv(parent)
   local env = { vars = {}, parent = parent or M.make_empty_env() }

   function env:get(name)
      return self.vars[name] or self.parent:get(name)
   end

   function env:has(name)
      return self.vars[name] ~= nil or self.parent:has(name)
   end

   function env:set(name, value_or_ast)
      if self.vars[name] then
         self.vars[name] = value_or_ast
      else
         return self.parent:set(name, value_or_ast)
      end
   end

   function env:new(name)
      self.vars[name] = { value = {} }
   end

   return env
end

function M.eval_variable(var, env, eval_shell)
   local var = env:get(var.name)
   local value
   if var.components then
      value = M.eval_components(var.components, env, nil, eval_shell)
   else
      value = assert(var.value)
   end
   return value
end

function M.eval_part(part, env, pattern, eval_shell)
   local ty = part.type
   if ty == "literal" then
      return true, part.text
   elseif ty == "variable" then
      return false, M.eval_variable(part, env, eval_shell)
   elseif ty == "file-glob" then
      error("file globbing is not supported")
   elseif ty == "dir-glob" then
      error("directory globbing is not supported")
   elseif ty == "pattern" then
      return true, assert(pattern, "used a pattern, but no pattern was available")
   elseif ty == "shell" then
      return false, eval_shell(part.text)
   elseif ty == "string" then
      local res = {}
      for i = 1, #part.parts do
         local p = part.parts[i]
         if p.type == "variable" then
            local values = M.eval_variable(p, env, eval_shell)
            for j = 1, #values do
               res[#res + 1] = values[j]
            end
         else
            assert(p.type == "literal")
            res[#res + 1] = p.text
         end
      end
      return true, table.concat(res, " ")
   else
      error("unreachable: " .. ty)
   end
end

function M.eval_components(components, env, pattern, eval_shell)
   local res = {}
   for i = 1, #components do
      local comp = components[i]
      local acc = {""}
      for j = 1, #comp.parts do
         local part = comp.parts[j]
         local is_scalar, val = M.eval_part(part, env, pattern, eval_shell)
         if not is_scalar then
            local mult = {}
            for k = 1, #acc do
               for q = 1, #val do
                  mult[#mult + 1] = acc[k] .. val[q]
               end
            end
            acc = mult
         else
            for k = 1, #acc do
               acc[k] = acc[k] .. val
            end
         end
      end

      for j = 1, #acc do
         res[#res + 1] = acc[j]
      end
   end
   return res
end

local function pattern_match(self, text)
   if string.len(text) < string.len(self.prefix) + string.len(self.suffix) then
      return nil
   end
   if self.prefix ~= "" and string.sub(text, 1, string.len(self.prefix)) ~= self.prefix then
      return nil
   end
   if self.suffix ~= "" and string.sub(text, -string.len(self.suffix), -1) ~= self.suffix then
      return nil
   end
   return string.sub(text, string.len(self.prefix) + 1, -string.len(self.suffix) - 1)
end

function M.pattern_extract(component, env, eval_shell)
   local prefix_parts, suffix_parts, pos = {}, {}, nil
   for i = 1, #component.parts do
      local part = component.parts[i]
      if part.type == "pattern" then
         assert(not pos, "multiples patterns on a target")
         pos = i
      elseif not pos then
         prefix_parts[#prefix_parts + 1] = part
      else
         suffix_parts[#suffix_parts + 1] = part
      end
   end
   local prefix = M.eval_components({{parts = prefix_parts}}, env, nil, eval_shell)
   local suffix = M.eval_components({{parts = suffix_parts}}, env, nil, eval_shell)
   local matchers = {}
   for i = 1, #prefix do
      for j = 1, #suffix do
         matchers[#matchers + 1] = {
            prefix = prefix[i],
            suffix = suffix[j],
            pattern_match = pattern_match,
         }
      end
   end
   return not not pos, matchers
end

function M.eval_make(ast, env, run, eval_shell, include_ast)
   local graph = {}
   local tasks = {}
   local codes = {}
   local targets = {}
   local recipes = {}

   local function apply_ast(ast)
      for i = 1, #ast.children do
         local child = ast.children[i]
         local ty = child.type
         if ty == "task" then
            local header = child.header
            local target, deps, order_only = nil, {}, {}
            local has_pattern, matchers = M.pattern_extract(header.target, env, eval_shell)
            local function get_dependencies(key, pattern)
               return M.eval_components(header.dependencies, env, pattern, eval_shell)
            end

            local idx
            if has_pattern then
               idx = #targets + 1
            else
               idx = 1
            end

            local function task(key)
               for i = 1, #matchers do
                  local pattern = matchers[i]:pattern_match(key)
                  if pattern and (has_pattern or pattern == "") then
                     if not has_pattern then
                        pattern = nil
                     end
                     return {
                        pattern = pattern,
                        dependencies = get_dependencies(key, pattern),
                        ast = child,
                        codes = child.body,
                     }
                  end
               end
               return nil
            end

            table.insert(targets, idx, task)
         elseif ty == "assigment" then
            if child.override then
               env:new(child.target)
            end
            local value
            if child.immediate then
               value = { value = M.eval_components(child.expression_list, env, nil, eval_shell) }
            else
               value = { components = child.expression_list }
            end
            if child.override or not env:has(child.target) then
               env:set(child.target, value)
            end
         elseif ty == "include" then
            local values = M.eval_components(child.filenames, env, nil, eval_shell)
            for j = 1, #values do
               apply_ast(include_ast(values[j]))
            end
         else
            error("unreachable: " .. ty)
         end
      end
   end

   apply_ast(ast)

   local function make_subenv(env, key, deps)
      local subenv = M.make_subenv(env)
      subenv:new("@")
      subenv:set("@", {value = {key}})
      subenv:new("<")
      if #deps > 0 then
         subenv:set("<", {value = {deps[1]}})
      else
         subenv:set("<", {value = {}})
      end
      subenv:new("^")
      subenv:set("^", {value = utils.remove_duplicates(deps)})
      subenv:new("+")
      subenv:set("+", {value = deps})
      subenv:new("|")
      subenv:set("|", {value = {}})
      return subenv
   end

   local function generate_task_for_data(key, data)
      return function(fetch)
         local dependencies = {}
         for i = 1, #data.dependencies do
            dependencies[i] = fetch(data.dependencies[i])
         end

         local subenv = make_subenv(env, key, data.dependencies)

         local expanded_lines = {}
         for i = 1, #data.codes.lines do
            local line = data.codes.lines[i]
            local expanded = {}
            for j = 1, #line.elements do
               local el = line.elements[j]
               if el.literal then
                  expanded[#expanded + 1] = el.literal
               else
                  assert(el.variable)
                  expanded[#expanded + 1] = M.eval_variable(el.variable, subenv, eval_shell)
               end
            end
            expanded_lines[#expanded_lines + 1] = expanded
         end

         return run(key, expanded_lines, dependencies, fetch)
      end
   end

   local function get_data_for_key(key)
      local matching_datas = {}
      for i = 1, #targets do
         local data = targets[i](key)
         if data then
            matching_datas[#matching_datas + 1] = data
         end
      end

      if #matching_datas == 0 then
         return nil
      elseif #matching_datas == 1 then
         return matching_datas[1]
      else
         local pattern, dependencies, all_codes = nil, {}, {}
         for i = 1, #matching_datas do
            local data = matching_datas[i]
            if pattern and pattern[1] ~= data.pattern then
               if pattern[1] and not data.pattern then
                  -- I was recording the data for a rule with a pattern, but
                  -- there is a rule WITHOUT a pattern. We need to always give
                  -- priority to pattern-less rules.
                  pattern = {data.pattern}
                  dependencies = {}
                  table.move(data.dependencies, 1, #data.dependencies, 1, dependencies)
                  all_codes = {data.codes}
               elseif not pattern[1] and data.pattern then
                  -- I was recording the data for a rule without a pattern, but
                  -- a pattern-ed (?) rule was found. We need to ignore it.
               elseif not pattern[1] and not data.pattern then
                  -- What? the only falsy value should be nil, which always
                  -- compares equal to itself.
                  error("unreachable")
               else
                  error("Multiples pattern rules match the same key: " .. tostring(key))
               end
            else
               if not pattern then
                  pattern = {data.pattern}
               end
               table.move(data.dependencies, 1, #data.dependencies,
                          #dependencies + 1, dependencies)
               if #data.codes.lines > 0 then
                  all_codes[#all_codes + 1] = data.codes
               end
            end
         end

         if #all_codes == 0 then
            all_codes = {
               {
                  type = "task-body",
                  lines = {},
                  indentation = "",
               }
            }
         end
         assert(#all_codes == 1,
                "Multiples recipes for the same key: "  .. tostring(key))

         local new_data = {
            pattern = pattern,
            dependencies = dependencies,
            codes = all_codes[1],
         }
         return new_data
      end
   end

   local function tasks(key)
      local data = get_data_for_key(key)
      if not data then
         return nil
      else
         return generate_task_for_data(key, data)
      end
   end

   local function dependencies_of(key)
      local data = get_data_for_key(key)
      if not data then
         return nil
      else
         return data.dependencies
      end
   end

   return tasks, dependencies_of
end

function M.dependencies_function_to_graph(dependencies_of)
   local function index(self, key)
      if not rawget(self, key) then
         self[key] = dependencies_of(key)
      end
      return rawget(self, key)
   end
   return setmetatable({}, { __index = index })
end

function M.parse_and_prepare(code, run, eval_shell, read_file)
   local osenv = M.make_subenv(M.make_os_env())
   local ast, errmsg = M.parse_string(code)
   if not ast then
      error(errmsg)
   end

   local function include_ast(filename)
      local ast, errmsg = M.parse_string(read_file(filename))
      if not ast then
         error(errmsg)
      end
      return ast
   end

   local tasks, dependencies_of = M.eval_make(ast, osenv, run, eval_shell, include_ast)
   local graph = M.dependencies_function_to_graph(dependencies_of)
   return {
      ast = ast,
      dependencies_of = dependencies_of,
      dependency_graph = graph,
      tasks = tasks,
   }
end

return M
