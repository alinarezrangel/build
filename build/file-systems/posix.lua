local M = {}

local unistd = require "posix.unistd"
local stat = require "posix.sys.stat"
local time = require "posix.sys.time"
local wait = require "posix.sys.wait"

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

function M:run_wait(program, args)
   local pid, errmsg, errno = unistd.fork()
   if not pid then
      error("could not fork: " .. errmsg)
   elseif pid == 0 then
      local n
      n, errmsg, errno = unistd.execp(program, args)
      error("could not exec: " .. errmsg)
   else
      local cpid
      cpid, errmsg, errno = wait.wait(pid)
      if not cpid then
         error("could not wait: " .. errmsg)
      end
   end
end

return M
