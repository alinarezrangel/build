return function(Posix_File_System)
   local M = {}

   function M.create(fs)
      return function(key, value, task)
         return function(fetch)
            local deps = task:get_dependencies()
            local my_mtime = Posix_File_System.get_mtime(fs, key)
            local out_of_date = false
            if not my_mtime then
               out_of_date = true
            else
               for i = 1, #deps do
                  local dep_key = deps[i]
                  local dep_mtime = Posix_File_System.get_mtime(fs, dep_key)
                  if not dep_mtime or dep_mtime > my_mtime then
                     out_of_date = true
                     break
                  end
               end
            end
            if out_of_date or #deps == 0 then
               value = task(fetch)
               return value
            else
               return value
            end
         end
      end
   end

   return M
end
