local utils = require "build.utils"

return function(Store)
   local M = {}

   M.METHODS = {}

   function M.METHODS:dependencies_of(key)
      return self.dependencies[key] or {}
   end

   function M.METHODS:all_dependencies_in_topological_order(key)
      local deps = {}
      local seen = {}

      local function visit(key, depth)
         if seen[key] then
            return
         end
         seen[key] = true
         local deps_keys = self:dependencies_of(key)
         local same_depth_deps = deps[depth]
         if not same_depth_deps then
            same_depth_deps = {n = 0}
            deps[depth] = same_depth_deps
         end
         same_depth_deps.n = same_depth_deps.n + 1
         same_depth_deps[same_depth_deps.n] = key
         for i = 1, #deps_keys do
            visit(deps_keys[i], depth + 1)
         end
      end

      visit(key, 1)

      local function flatten_deps()
         local res = {n = 0}
         for i = 1, #deps do
            local same_depth_deps = deps[i]
            for j = 1, same_depth_deps.n do
               res.n = res.n + 1
               res[res.n] = { key = same_depth_deps[j], depth = i }
            end
         end
         return res
      end

      local flattened_deps = flatten_deps()
      local function lt(a, b)
         return a.depth < b.depth
      end
      table.sort(flattened_deps, lt)
      for i = 1, flattened_deps.n do
         flattened_deps[i] = flattened_deps[i].key
      end
      return flattened_deps
   end

   M.META = { __index = M.METHODS }

   function M.META:__call(...)
      return self.tasks(...)
   end

   function M.topological_tasks(tasks, dependencies)
      return setmetatable({ tasks = tasks,
                            dependencies = dependencies,
                          }, M.META)
   end

   function M.is_topological_tasks(tasks)
      return getmetatable(tasks) == M.META
   end

   function M.graph_to_graphviz(tasks, out_file)
      assert(M.is_topological_tasks(tasks), "graph_to_graphviz needs a topological graph")
      local cnt = 0
      local function gen_label()
         cnt = cnt + 1
         return string.format("_%d", cnt)
      end
      local labels = {}
      local function get_label(key)
         if not labels[key] then
            labels[key] = gen_label()
         end
         return labels[key]
      end
      out_file:write "digraph {\n"
      for key, deps in pairs(tasks.dependencies) do
         out_file:write(string.format("%s [label = \"%s\"];\n",
                                      get_label(key),
                                      utils.graphviz_string_escape(key)))
         for i = 1, #deps do
            out_file:write(string.format("%s -> %s;\n", get_label(key), get_label(deps[i])))
         end
      end
      out_file:write "}\n"
   end

   M.TASK_METHODS = {}

   function M.TASK_METHODS:get_dependencies()
      local metaself = getmetatable(self)
      return metaself.tasks:dependencies_of(metaself.key)
   end

   local function create_topological_task(tasks, task, key)
      local meta = {
         __index = M.TASK_METHODS,
         tasks = tasks,
         key = key,
      }

      function meta:__call(...)
         return task(...)
      end

      return setmetatable({}, meta)
   end

   function M.create(rebuilder)
      return function(tasks, key, store)
         assert(M.is_topological_tasks(tasks),
                "The topological scheduler only supports topological tasks (created with the `topological_tasks()` function)")
         local in_order = tasks:all_dependencies_in_topological_order(key)

         local function build(key)
            local deps = tasks:dependencies_of(key)
            local function fetch(dep_key)
               for i = 1, #deps do
                  if deps[i] == dep_key then
                     return Store.get(store, dep_key)
                  end
               end
               error(string.format("Dependency %s of %s was unlisted", dep_key, key))
            end

            local task = tasks(key)
            local topotask = create_topological_task(tasks, task, key)
            local new_task = rebuilder(key, value, topotask)
            local new_value = new_task(fetch)
            Store.put(store, key, new_value)
         end

         for i = 1, in_order.n do
            build(in_order[i])
         end
         return Store.get(store, key)
      end
   end

   return M
end
