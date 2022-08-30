return function(...)
   local M = {}

   local Modules = {...}

   function M.create_combined_hashers(...)
      local myself = {...}
      myself.n = select("#", ...)
      assert(myself.n == #Modules)
      return myself
   end

   function M:hash(key, value)
      local res = {}
      for i = 1, self.n do
         res[i] = Modules[i].hash(self[i], key, value)
      end
      return res
   end

   function M:hash_dirty(key, old_hash, new_hash)
      for i = 1, self.n do
         if not Modules[i].hash_dirty(self[i], key, old_hash[i], new_hash[i]) then
            return false
         end
      end
      return true
   end

   return M
end
