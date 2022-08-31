local M = {}

require "fennel"
local V = require "fennel.view"

local function skip_ws(src, i)
   return (string.match(src, "^%s*()", i)) or i
end

local function read_variable_name(src, i)
   local name, ni = string.match(src, "^([a-zA-Z_][a-zA-Z_0-9]*)()", i)
   if name and ni then
      return name, ni
   else
      return nil, i, "Could not read a variable name"
   end
end

local function read_variable_ref(src, i)
   local ni = string.match(src, "^%$%(()", i)
   if not ni then
      return nil, i, "Expected `$(` (variable reference start)"
   end
   i = ni
   local name, errmsg
   name, ni, errmsg = read_variable_name(src, i)
   if not name or not ni then
      return nil, i, errmsg
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
   local simple, ni = string.match(src, "^([a-zA-Z0-9%._%+%-%*@,~/=#]+)()", i)
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
   local var
   var, ni = read_variable_ref(src, i)
   if var and ni then
      return var, ni
   end
   return read_string(src, i)
end

local function read_component(src, i)
   local parts = {}
   while true do
      local part, ni = read_part(src, i)
      if part and ni then
         parts[#parts + 1] = part
         i = ni
      elseif #parts == 0 then
         return nil, i, "Expected at least one component part"
      else
         return { type = "component", parts = parts }, i
      end
   end
end

local function parse_task_header(src, i)
   local target, dependencies, order_only_dependencies = nil, {}, {}
   local ni, errmsg
   i = skip_ws(src, i)
   target, ni, errmsg = read_component(src, i)
   if not target or not ni then
      return nil, i, "Could not read target: " .. errmsg
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
      elseif i > string.len(src) then
         break
      end
      local dep
      dep, ni, errmsg = read_component(src, i)
      if not dep or not ni then
         return nil, i, "Could not read dependency: " .. errmsg
      end
      i = ni
      dependencies[#dependencies + 1] = dep
   end
   if needs_order_only then
      i = i + 1
      while true do
         i = skip_ws(src, i)
         if i > string.len(src) then
            break
         end
         local dep
         dep, ni, errmsg = read_component(src, i)
         if not dep or not ni then
            return nil, i, "Could not read order-only dependency: " .. errmsg
         end
         i = ni
         order_only_dependencies[#order_only_dependencies + 1] = dep
      end
   end
   if i <= string.len(src) then
      return nil, i, "Expected end of task-header line"
   end
   return {
      type = "task-header",
      target = target,
      dependencies = dependencies,
      order_only_dependencies = order_only_dependencies,
   }, i
end

local function parse_variable_assigment(src, i)
   -- VAR ws "=" ws EXPRLIST
   -- VAR ws "?=" ws EXPRLIST
   local name, ni, errmsg = read_variable_name(src, i)
   if not name or not ni then
      return nil, i, "Could not read variable name in assigment: " .. errmsg
   end
   i = skip_ws(src, ni)
   local override = false
   if string.sub(src, i, i) == "=" then
      i = i + 1
      override = true
   elseif string.sub(src, i, i + 1) == "?=" then
      i = i + 2
   else
      return nil, i, "Expected assignment operator `=` or `?=`"
   end
   local values = {}
   while true do
      i = skip_ws(src, i)
      if i > string.len(src) then
         break
      end
      local value
      value, ni, errmsg = read_component(src, i)
      if not value or not ni then
         return nil, i, "Could not read value of variable: " .. errmsg
      end
      i = ni
      values[#values + 1] = value
   end
   i = skip_ws(src, i)
   if i <= string.len(src) then
      return nil, i, "Expected end of assigment line"
   end
   return {
      type = "assigment",
      override = override,
      target = name,
      expression_list = values,
   }, i
end

function M.parse_file(file_handle)
   local after_header = false
   local indentation = nil
   local children, task = {}, nil
   local function flush_task()
      if task then
         children[#children + 1] = task
         task = nil
      end
   end

   for line in file_handle:lines() do
      if string.match(line, "^%s*#") then
         -- continue
      elseif string.match(line, "^%s*$") then
         -- continue
      elseif after_header and string.match(line, "^%s+") then
         local line_indentation = string.match(line, "^(%s+)")
         if not indentation then
            indentation = line_indentation
         end
         assert(string.sub(line, 1, string.len(indentation)) == indentation)
         assert(task)
         task.body[#task.body + 1] = string.sub(line, string.len(indentation) + 1)
      else
         local header, i, h_errmsg = parse_task_header(line, 1)
         if header then
            flush_task()
            after_header = true
            indentation = nil
            task = {
               type = "task",
               header = header,
               body = {},
            }
         else
            local assigment, a_errmsg
            assigment, i, a_errmsg = parse_variable_assigment(line, 1)
            if assigment then
               flush_task()
               after_header = false
               indentation = nil
               task = nil
               children[#children + 1] = assigment
            else
               error(string.format("Expected task or variable assigment.\nTask error: %s\nVariable error: %s", h_errmsg, a_errmsg))
            end
         end
      end
   end
   flush_task()

   return {
      type = "make",
      children = children,
   }
end

local function file_like_from_string(str)
   return {
      lines = function(self)
         return string.gmatch(str, "(.-)\n")
      end
   }
end

function M.parse_string(code)
   local ast, errmsg = M.parse_file(file_like_from_string(code))
   if not ast then
      error(errmsg)
   end
   return ast
end

function M.eval_components(components, env, pattern)
   local res = ""
   for i = 1, #components do
      local comp = components[i]
      if i > 1 then
         res = res .. " "
      end
      for j = 1, #comp.parts do
         local part = comp.parts[j]
         local ty = part.type
         if ty == "literal" then
            res = res .. part.text
         elseif ty == "variable" then
            res = res .. env:get(part.name)
         elseif ty == "file-glob" then
            error("file globbing is not supported")
         elseif ty == "dir-glob" then
            error("directory globbing is not supported")
         elseif ty == "pattern" then
            res = res .. pattern
         else
            error("unrechable: " .. ty)
         end
      end
   end
   return res
end

function M.eval_make(ast, env, run)
   local graph = {}
   local tasks = {}
   local codes = {}

   for i = 1, #ast.children do
      local child = ast.children[i]
      local ty = child.type
      if ty == "task" then
         local header = child.header
         local target, deps, order_only = nil, {}, {}
         target = M.eval_components({header.target}, env, nil)
         graph[target] = graph[target] or {}
         for j = 1, #header.dependencies do
            deps[j] = M.eval_components({header.dependencies[j]}, env, nil)
            table.insert(graph[target], deps[j])
         end
         assert(#header.order_only_dependencies == 0)
         assert(not codes[target] or #child.body == 0)
         if not codes[target] then
            codes[target] = child.body
         end
      elseif ty == "assigment" then
         local value = M.eval_components(child.expression_list, env, nil)
         if child.override or not env:has(child.target) then
            env:set(child.target, value)
         end
      else
         error("unreachable: " .. ty)
      end
   end

   for key, deps in pairs(graph) do
      tasks[key] = function(fetch)
         local vals = {}
         for j = 1, #deps do
            vals[j] = fetch(deps[j])
         end
         return run(key, assert(codes[key]), vals, fetch)
      end
   end

   return graph, tasks
end

function M.make_os_env()
   local env = {}

   function env:get(name)
      return os.getenv(name) or ""
   end

   function env:has(name)
      return os.getenv(name) == nil
   end

   function env:set(name, value)
      local stdlib = require "posix.stdlib"
      stdlib.setenv(name, value)
   end

   return env
end

local function substitute(line, env)
   local function repl(p, name)
      return p .. env:get(name)
   end
   return string.gsub(line, "([^%$])%$%(([a-zA-Z_][a-zA-Z_0-9]*)%)", repl)
end

local function make_run(env, run)
   return function(target, codes, deps, fetch)
      local expanded = {}
      for i = 1, #codes do
         expanded[i] = string.sub(substitute(" " .. codes[i], env), 2)
      end
      return run(target, deps, expanded, fetch)
   end
end

function M.make_tasks_from_tasks_table(tasks_table)
   return function(key)
      return assert(tasks_table[key])
   end
end

function M.parse_and_prepare(code, run)
   local osenv = M.make_os_env()
   local ast = M.parse_string(code)
   local graph, tasks_table = M.eval_make(ast, osenv, make_run(osenv, run))
   local tasks = M.make_tasks_from_tasks_table(tasks_table)
   return {
      dependency_graph = graph,
      tasks = tasks,
   }
end

return M
