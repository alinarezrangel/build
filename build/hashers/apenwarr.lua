return function(Posix_File_System)
   local M = {
      FILE_DOESNT_EXISTS = -1,
      COMPARE_STATS = {
         "st_mtime", "st_ino", "st_size", "st_mode", "st_uid", "st_gid",
      },
   }

   function M.create(fs)
      return fs
   end

   function M.hash(fs, key, value)
      return (Posix_File_System.get_stats(fs, key)) or M.FILE_DOESNT_EXISTS
   end

   function M:hash_dirty(key, old_hash, new_hash)
      if new_hash == M.FILE_DOESNT_EXISTS then
         return true
      end
      for i = 1, #M.COMPARE_STATS do
         local field = M.COMPARE_STATS[i]
         if old_hash[field] ~= new_hash[field] then
            return true
         end
      end
      return false
   end

   return M
end
