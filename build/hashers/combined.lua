return function(...)
   local M = {}

   local Modules = {...}

   function M.create_combined_hashers(first, ...)
      assert(first ~= nil)
      local myself = table.pack {first, ...}
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
         print("AT", i)
         if Modules[i].hash_dirty(self[i], key, old_hash, new_hash) then
            print("S")
            return true
         end
      end
      print("E")
      return false
   end

   return M
end
