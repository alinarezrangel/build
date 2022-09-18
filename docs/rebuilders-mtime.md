---
title: build.rebuilders.mtime
libbar: yes
---

# `build.rebuilders.mtime` #

**Special meaning of keys?**
: No, but they must have an associated file name.

**Requires an specific scheduler?**
: Yes, any scheduler that provides dependency information along with the
  task. For example, the [topological scheduler](schedulers-topological.md).

This simple rebuilder will cache a key only for as long as its modification
time (also known as *mtime*) remains bigger than that of it's dependencies.

## Usage ##

```lua
local Rebuilder = require "build.rebuilders.mtime" (Posix_File_System, File_Of_Key)
```

  * `Posix_File_System` is the structure of the POSIX compatible file system to
    use.
  * `File_Of_Key` must be a function that will be called like
    `File_Of_Key(key)`. It must return the filename of the file associated with
    the key, or `nil` if the key has no filename.

The `Rebuilder.create(fs)` (where `fs` is the instance of `Posix_File_System`)
will create and return the new rebuilder.

## Notes ##

When checking the timestamps, keys without an associated file will be handled
as permanently out of date. This sound wrong but is the only way to keep the
invariants of the build system: always rebuilding file-less keys will never
leave a key that should have been rebuilt *unbuilt*.

## See Also ##

  * [`build.rebuilders.verifying-traces`](rebuilders-verifying-traces.md).
  * [`build.rebuilders.dirty_bit`](rebuilders-dirty-bit.md).
  * [`build.rebuilders.phony-adapter`](rebuilders-phony-adapter.md).
