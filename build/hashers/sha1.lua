return function(Posix_File_System)
   local M = {
      FILE_DOESNT_EXISTS = -1,

      MAX_SIZE_READED_IN_MEMORY = 50 * 1024 * 1024, -- 50 MiB
   }

   local sha1 = require "sha1"

   function M.create(fs)
      return fs
   end

   local function read_hash(fs, path)
      local handle <close>, errmsg = io.open(path, "rb")
      if not handle then
         return nil, errmsg
      end
      local size = assert(handle:seek "end")
      assert(handle:seek "set")
      if size <= M.MAX_SIZE_READED_IN_MEMORY then
         local contents = handle:read "a"
         return sha1.sha1(contents)
      else
         local function read_chunk(len)
            return assert(handle:read(len))
         end
         return sha1.sha1_chunked(size, read_chunk)
      end
   end

   function M.hash(fs, key, value)
      local res = read_hash(fs, key)
      print("SHA1", key, res)
      return res or M.FILE_DOESNT_EXISTS
   end

   function M:hash_dirty(key, old_hash, new_hash)
      return new_hash == M.FILE_DOESNT_EXISTS or old_hash ~= new_hash
   end

   return M
end
