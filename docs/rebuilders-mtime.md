---
title: build.rebuilders.mtime
libbar: yes
---

# `build.rebuilders.mtime` #

**Special meaning of keys?**
: Yes, as file names.

**Requires an specific scheduler?**
: Yes, any scheduler that provides dependency information along with the
  task. For example, the [topological scheduler](schedulers-topological.md).

This simple rebuilder will cache a key only for as long as its modification
time (also known as *mtime*) remains bigger than that of it's dependencies.

## Usage ##

```lua
local Rebuilder = require "build.rebuilders.mtime" (Posix_File_System)
```

  * `Posix_File_System` is the structure of the POSIX compatible file system to
    use.

The `Rebuilder.create(fs)` (where `fs` is the instance of `Posix_File_System`)
will create and return the new rebuilder.

## See Also ##

  * [`build.rebuilders.verifying-traces`](rebuilders-verifying-traces.md).
  * [`build.rebuilders.dirty_bit`](rebuilders-dirty-bit.md).
