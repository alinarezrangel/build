return function(Posix_File_System, Store)
   local M = {}

   M.Rebuilder = require "build.rebuilders.mtime" (Posix_File_System)
   M.Scheduler = require "build.schedulers.topological" (Store)

   M.create_tasks = M.Scheduler.topological_tasks

   function M.create(fs)
      local rebuilder = M.Rebuilder.create(fs)
      return M.Scheduler.create(rebuilder)
   end

   return M
end
