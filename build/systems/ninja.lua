return function(Posix_File_System, Store, Metadata_Store)
   local M = {}

   M.Hasher = require "build.hashers.apenwarr" (Posix_File_System)
   M.Verifying_Trace_Store = require "build.traces.verifying.hash" (Metadata_Store, M.Hasher)
   M.Rebuilder = require "build.rebuilders.verifying-traces" (M.Verifying_Trace_Store)
   M.Scheduler = require "build.schedulers.topological" (Store)

   M.create_tasks = M.Scheduler.topological_tasks

   function M.create(fs, metadata_store)
      local hash = M.Hasher.create(fs)
      local vt = M.Verifying_Trace_Store.create(metadata_store, hash)
      local rebuilder = M.Rebuilder.create(vt)
      return M.Scheduler.create(rebuilder)
   end

   return M
end
