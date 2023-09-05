---
title: build.systems.ninja
libbar: yes
---

# `build.systems.ninja` #

Ninja-like system. Requires all dependency data up-front and compares files via
their Apenwarr's hash.

## Usage ##

```lua
local System = require "build.systems.ninja" (Posix_File_System, Store, Metadata_Store)
local scheduler = System.create(posix_file_system, metadata_store)
local tasks = System.create_tasks(tasks, dependencies)
-- Exports: System.Rebuilder, System.Scheduler, System.Hasher, System.Verifying_Trace_Store
```

Uses the [topological scheduler
(`build.schedulers.topological`)](schedulers-topological.md) with the
[verifying traces rebuilder
(`build.rebuilders.verifying-traces`)](rebuilders-verifying-traces.md). These
two get instantiated to the `System.Scheduler` and `System.Rebuilder`
structures.

The `System.Verifying_Trace_Store` is an instantiation of
[`build.traces.verifying.hash`](traces-verifying-hash.md). It is instantiated
with the `System.Hasher` hasher, an instance of
[`build.hashers.apenwarr`](hashers-apenwarr.md).

The `System.create(fs, metadata)` function creates the scheduler from a POSIX
file system and an instance of the metadata store. Because this uses a
topological scheduler, you cannot directly pass a function to the scheduler,
instead you must create a *topotasks* object that contains dependency data
using the `System.create_tasks(tasks, deps)` function. See the
`topological_tasks` of [topological scheduler
(`build.schedulers.topological`)](schedulers-topological.md) for more help.

## See also ##

  * [`build.systems.make`](systems-make.md).
  * [`build.systems.redo`](systems-redo.md).
  * [`build.systems.sha1-redo`](systems-sha1-redo.md).
