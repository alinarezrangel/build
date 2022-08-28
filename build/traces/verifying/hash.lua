return function(Store, Hasher)
   local M = {}

   function M.create(backing_store, hasher)
      return {
         backing_store = backing_store,
         hasher = hasher,
      }
   end

   function M:hash(key, value)
      return Hasher.hash(self.hasher, key, value)
   end

   function M:record(key, value_hash, dependencies_hashed)
      local data = {
         value_hash = value_hash,
         dependencies = {},
      }
      for dep_key, dep_hash in pairs(dependencies_hashed) do
         data.dependencies[dep_key] = dep_hash
      end
      Store.put(self.backing_store, key, data)
   end

   function M:verify(key, value_hash, get_dependency_hash)
      local data, found = Store.try_get(self.backing_store, key)
      local old_value_hash, old_dependencies_hashed = nil, {}
      if found then
         old_value_hash = data.value_hash
         old_dependencies_hashed = data.dependencies
      end
      if not found or Hasher.hash_dirty(self.hasher, key, old_value_hash, value_hash) then
         return false
      else
         for dep_key, old_dep_hash in pairs(old_dependencies_hashed) do
            local new_dep_hash = get_dependency_hash(dep_key)
            if Hasher.hash_dirty(self.hasher, dep_key, old_dep_hash, new_dep_hash) then
               return false
            end
         end
         return true
      end
   end

   return M
end
