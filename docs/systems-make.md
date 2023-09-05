---
title: build.systems.make
libbar: yes
---

# `build.systems.make` #

Make-like system. Requires dependency data up-front and builds files by their
*mtime*.

## Usage ##

```lua
local System = require "build.systems.make" (Posix_File_System, Store)
local scheduler = System.create(posix_file_system)
local tasks = System.create_tasks(tasks, dependencies)
-- Exports: System.Rebuilder, System.Scheduler
```

Uses the [topological scheduler
(`build.schedulers.topological`)](schedulers-topological.md) with the [mtime
rebuilder (`build.rebuilders.mtime`)](rebuilders-mtime.md). These two get
instantiated to the `System.Scheduler` and `System.Rebuilder` structures.

The `System.create(fs)` function creates the scheduler from a POSIX file
system. Because this uses a topological scheduler, you cannot directly pass a
function to the scheduler, instead you must create a *topotasks* object that
contains dependency data using the `System.create_tasks(tasks, deps)`
function. See the `topological_tasks` of [topological scheduler
(`build.schedulers.topological`)](schedulers-topological.md) for more help.

## See also ##

  * [`build.systems.redo`](systems-redo.md).
  * [`build.systems.ninja`](systems-ninja.md).
  * [`build.systems.sha1-redo`](systems-sha1-redo.md).
