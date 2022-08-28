local M = {}

local stat = require "posix.sys.stat"
local time = require "posix.sys.time"

function M.global()
end

function M:current_time()
   local tv = time.gettimeofday()
   return tv.tv_sec
end

function M:get_stats(path)
   return stat.stat(path)
end

function M:get_mtime(path)
   local st = M.get_stats(self, path)
   if st then
      return st.st_mtime
   else
      return nil
   end
end

return M
