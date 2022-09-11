local M = {}

function M.create(backing_rebuilder, is_phony_key)
   return function(key, value, task)
      if is_phony_key(key) then
         return task
      else
         return backing_rebuilder(key, value, task)
      end
   end
end

return M
