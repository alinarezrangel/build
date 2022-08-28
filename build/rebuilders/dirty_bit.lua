return function()
   local M = {}

   function M.create()
      local built_bits = {}
      return function(key, value, task)
         return function(fetch)
            if not built_bits[key] then
               value = task(fetch)
               built_bits[key] = true
               return value
            else
               return value
            end
         end
      end
   end

   return M
end
