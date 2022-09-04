local M = {}

local unistd = require "posix.unistd"
local poll = require "posix.poll"
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

local DEFAULT_RUN_CONFIG = {
   capture_stdout = false,
}

function M:run_wait(program, args, config)
   config = config or DEFAULT_RUN_CONFIG
   local outr, outw
   if config.capture_stdout then
      outr, outw = unistd.pipe()
   end
   local pid, errmsg, errno = unistd.fork()
   if not pid then
      error("could not fork: " .. errmsg)
   elseif pid == 0 then
      if config.capture_stdout then
         unistd.dup2(outw, 1)
         unistd.close(outr)
      end
      local n
      n, errmsg, errno = unistd.execp(program, args)
      error("could not exec: " .. errmsg)
   else
      local res = {}
      if config.capture_stdout then
         unistd.close(outw)
         local parts = { [outr] = {} }
         local fds = { [outr] = { events = { IN = true } } }
         while next(fds) do
            poll.poll(fds, -1)
            for fd in pairs(fds) do
               if fds[fd].revents.IN then
                  parts[fd][#parts[fd] + 1] = unistd.read(fd, 1024)
               end
               if fds[fd].revents.HUP then
                  unistd.close(fd)
                  fds[fd] = nil
               end
            end
         end
         res.stdout = table.concat(parts[outr])
      end
      local cpid
      cpid, errmsg, errno = wait.wait(pid)
      if not cpid then
         error("could not wait: " .. errmsg)
      else
         -- errno is the exit code
         res.exit_code = errno

         if config.capture_stdout then
            return res
         else
            return res.exit_code
         end
      end
   end
end

return M
