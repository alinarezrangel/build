return function(Store)
   local M = {}

   function M.create(rebuilder)
      return function(tasks, key, store)
         local done = {}
         local function fetch(key)
            local task = tasks(key)
            local value = Store.get(store, key)
            if not task or done[key] then
               return value
            else
               local new_task = rebuilder(key, value, task)
               local new_value = new_task(fetch)
               done[key] = true
               Store.put(store, key, value)
               return new_value
            end
         end
         return fetch(key)
      end
   end

   return M
end
