return function(Posix_File_System, File_Of_Key)
   local M = {
      FILE_DOESNT_EXISTS = -1,
      HAS_NO_FILE = -2,
   }

   function M.create(fs)
      return fs
   end

   function M.hash(fs, key, value)
      local file = File_Of_Key(key)
      if not file then
         return M.HAS_NO_FILE
      else
         local mtime = Posix_File_System.get_mtime(fs, file)
         return mtime or M.FILE_DOESNT_EXISTS
      end
   end

   function M:hash_dirty(key, old_hash, new_hash)
      return old_hash == M.HAS_NO_FILE
         or new_hash == M.FILE_DOESNT_EXISTS
         or old_hash ~= new_hash
   end

   return M
end
