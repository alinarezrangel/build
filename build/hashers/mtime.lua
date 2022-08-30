return function(Posix_File_System)
   local M = {
      FILE_DOESNT_EXISTS = -1,
   }

   function M.create(fs)
      return fs
   end

   function M.hash(fs, key, value)
      local mtime = Posix_File_System.get_mtime(fs, key)
      return mtime or M.FILE_DOESNT_EXISTS
   end

   function M:hash_dirty(key, old_hash, new_hash)
      return new_hash == M.FILE_DOESNT_EXISTS or old_hash ~= new_hash
   end

   return M
end
