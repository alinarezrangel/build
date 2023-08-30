local M = {}

local stdio = require "posix.stdio"
local stdlib = require "posix.stdlib"
local unistd = require "posix.unistd"
local poll = require "posix.poll"
local stat = require "posix.sys.stat"
local time = require "posix.sys.time"
local wait = require "posix.sys.wait"
local errno = require "posix.errno"

function M.global()
end

function M:get_errno()
   return errno
end

function M:setenv(name, value)
   stdlib.setenv(name, tostring(value))
end

function M:change_current_directory(path)
   unistd.chdir(path)
end

function M:get_current_directory()
   local cwd, errmsg = unistd.getcwd()
   assert(cwd, errmsg)
   return cwd
end

function M:is_a_terminal(handle_or_fileno)
   local fileno
   if type(handle_or_fileno) == "number" then
      fileno = handle_or_fileno
   else
      fileno = stdio.fileno(handle_or_fileno)
   end
   return unistd.isatty(fileno) == 1
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

function M:try_delete_file(path)
   return unistd.unlink(path)
end

local DEFAULT_RUN_CONFIG = {
   capture_stdout = false,
   capture_stderr = false,
}

function M:run_wait(program, args, config)
   local had_config = config ~= nil
   config = config or DEFAULT_RUN_CONFIG
   local outr, outw, errr, errw
   if config.capture_stdout then
      outr, outw = unistd.pipe()
   end
   if config.capture_stderr then
      errr, errw = unistd.pipe()
   end
   local pid, errmsg, errno = unistd.fork()
   if not pid then
      error("could not fork: " .. errmsg)
   elseif pid == 0 then
      if config.capture_stdout then
         unistd.dup2(outw, 1)
         unistd.close(outr)
      end
      if config.capture_stderr then
         unistd.dup2(outw, 2)
         unistd.close(outr)
      end
      local n
      n, errmsg, errno = unistd.execp(program, args)
      error("could not exec: " .. errmsg)
   else
      local res = {}
      if config.capture_stdout or config.capture_stderr then
         local parts = {}
         local fds = {}
         if config.capture_stdout then
            unistd.close(outw)
            parts[outr] = {}
            fds[outr] = { events = { IN = true } }
         end
         if config.capture_stderr then
            unistd.close(errw)
            parts[errr] = {}
            fds[errr] = { events = { IN = true } }
         end
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
         if config.capture_stdout then
            res.stdout = table.concat(parts[outr])
         end
         if config.capture_stderr then
            res.stderr = table.concat(parts[errr])
         end
      end
      local cpid
      cpid, errmsg, errno = wait.wait(pid)
      if not cpid then
         error("could not wait: " .. errmsg)
      else
         -- errno is the exit code
         res.exit_code = errno

         if had_config then
            return res
         else
            return res.exit_code
         end
      end
   end
end

return M
