local utils = require "build.utils"

return function(Store)
   local M = {}

   -- So, in the original paper, they take advantage of Haskell's `Applicative`
   -- vs `Monad` to get the dependencies of the tasks without running
   -- them. This is not practical in Lua.
   --
   -- So instead I did the uglier option of requiring the `tasks` object of
   -- this scheduler to not be an actual function, but an special `topotasks`
   -- object.
   --
   -- Clients can construct their own topotasks, which associate each task with
   -- their dependencies.

   -- Methods of the topotasks object.
   M.METHODS = {}

   -- Return the direct dependencies of `key`.
   function M.METHODS:dependencies_of(key)
      return self.dependencies[key] or {}
   end

   -- Return a list with all the dependencies, even transitive ones, of
   -- `key`. The returned deps are in topological order.
   function M.METHODS:all_dependencies_in_topological_order(key)
      local deps = {}
      local deps_to_depths = {}
      local seen = {}

      local function visit(key, depth)
         deps_to_depths[key] = math.max(deps_to_depths[key] or -1, depth)
         if not seen[key] then
            seen[key] = true
            local deps_keys = self:dependencies_of(key)
            for i = 1, #deps_keys do
               visit(deps_keys[i], depth + 1)
            end
         end
      end

      visit(key, 1)

      local function linearize()
         for key, depth in pairs(deps_to_depths) do
            deps[depth] = deps[depth] or {n = 0}
            local t = deps[depth]
            t.n = t.n + 1
            t[t.n] = key
         end
      end
      linearize()

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
         return a.depth > b.depth
      end
      table.sort(flattened_deps, lt)
      for i = 1, flattened_deps.n do
         flattened_deps[i] = flattened_deps[i].key
      end
      return flattened_deps
   end

   M.META = { __index = M.METHODS }

   -- For compatibility, topotasks objects are callable.
   function M.META:__call(...)
      return self.tasks(...)
   end

   -- It is nice to be able to distinguish them...
   function M.META:__tostring()
      return string.format("topotask: (%s)", self.tasks)
   end

   -- Creates a topotasks object.
   --
   -- `tasks` is the normal tasks function, that, when called with a key,
   -- returns the task for that key (or `nil`).
   --
   -- `dependencies` is a table mapping each key to a list of their immediate
   -- dependencies.
   function M.topological_tasks(tasks, dependencies)
      return setmetatable({ tasks = tasks,
                            dependencies = dependencies,
                          }, M.META)
   end

   -- Determines if `tasks` is a topotasks object or a normal tasks function.
   function M.is_topological_tasks(tasks)
      return getmetatable(tasks) == M.META
   end

   -- Utility function that exports the dependency graph of a topotasks object
   -- to a GraphViz file. `out_file` must be the open output file handle.
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

   -- Each task returned by the topotasks object is wrapped into a topotask by
   -- the scheduler.
   --
   -- Importantly, the `task:get_dependencies()` method allows each topotask to
   -- obtain it's own dependencies.
   --
   -- The wrapping of each task into a topotask is done by the scheduler and
   -- not by the topotasks object. This is certainly a design mistake and
   -- should be fixed.

   -- The methods for a topotask.
   M.TASK_METHODS = {}

   function M.TASK_METHODS:get_dependencies()
      local metaself = getmetatable(self)
      return metaself.tasks:dependencies_of(metaself.key)
   end

   -- Wraps a task into a topotask. `tasks` is the topotasks object to use.
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
