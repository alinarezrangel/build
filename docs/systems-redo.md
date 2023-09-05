---
title: build.systems.redo
libbar: yes
---

# `build.systems.redo` #

Redo-like system. Discovers depedencies dynamically and uses the Apenwarr's
hash to compare files.

## Usage ##

```lua
local System = require "build.systems.redo" (Posix_File_System, Store, Metadata_Store)
local scheduler = System.create(posix_file_system, metadata_store)
-- Exports: System.Rebuilder, System.Scheduler, System.Hasher, System.Verifying_Trace_Store
```

Uses the [suspending scheduler
(`build.schedulers.suspending`)](schedulers-suspending.md) with the [verifying
traces rebuilder
(`build.rebuilders.verifying-traces`)](rebuilders-verifying-traces.md). These
two get instantiated to the `System.Scheduler` and `System.Rebuilder`
structures.

The `System.Verifying_Trace_Store` is an instantiation of
[`build.traces.verifying.hash`](traces-verifying-hash.md). It is instantiated
with the `System.Hasher` hasher, an instance of
[`build.hashers.apenwarr`](hashers-apenwarr.md).

The `System.create(fs, metadata)` function creates the scheduler from a POSIX
file system and an instance of the metadata store.

## See also ##

  * [`build.systems.make`](systems-make.md).
  * [`build.systems.ninja`](systems-ninja.md).
  * [`build.systems.sha1-redo`](systems-sha1-redo.md).
