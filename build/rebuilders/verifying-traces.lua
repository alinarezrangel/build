return function(Verifying_Trace_Store)
   local M = {}

   function M.create(vt)
      return function(key, value, task)
         local value_hash = Verifying_Trace_Store.hash(vt, key, value)
         return function(fetch)
            local function get_dependency_hash(dep_key)
               return Verifying_Trace_Store.hash(vt, dep_key, fetch(dep_key))
            end
            local up_to_date = Verifying_Trace_Store.verify(vt, key, value_hash, get_dependency_hash)
            if up_to_date then
               return value
            else
               local new_dependencies = {}
               local function tracking_fetch(dep_key)
                  local dep_value = fetch(dep_key)
                  local dep_hash = Verifying_Trace_Store.hash(vt, dep_key, dep_value)
                  new_dependencies[dep_key] = dep_hash
                  return dep_value
               end
               value = task(tracking_fetch)
               value_hash = Verifying_Trace_Store.hash(vt, key, value)
               Verifying_Trace_Store.record(vt, key, value_hash, new_dependencies)
               return value
            end
         end
      end
   end

   return M
end
