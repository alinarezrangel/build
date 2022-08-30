return function(Posix_File_System, Store, Metadata_Store)
   local M = {}

   local ApenwarrHasher = require "build.hashers.apenwarr" (Posix_File_System)
   local Sha1Hasher = require "build.hashers.sha1" (Posix_File_System)
   M.Hasher = require "build.hashers.combined-clean" (ApenwarrHasher, Sha1Hasher)

   M.Verifying_Trace_Store = require "build.traces.verifying.hash" (Metadata_Store, M.Hasher)
   M.Rebuilder = require "build.rebuilders.verifying-traces" (M.Verifying_Trace_Store)
   M.Scheduler = require "build.schedulers.suspending" (Store)

   function M.create(fs, metadata_store)
      local apenwarr_hash = ApenwarrHasher.create(fs)
      local sha1_hash = Sha1Hasher.create(fs)
      local hash = M.Hasher.create_combined_hashers(apenwarr_hash, sha1_hash)
      local vt = M.Verifying_Trace_Store.create(metadata_store, hash)
      local rebuilder = M.Rebuilder.create(vt)
      return M.Scheduler.create(rebuilder)
   end

   return M
end
