---
title: build.systems.sha1-redo
libbar: yes
---

# `build.systems.sha1-redo` #

Like [`build.systems.redo`](systems-redo.md), but not only compares the
Apenwarr's hash of the files, but also their SHA1 hash. The API and behaviour
is otherwise identical to `build.systems.redo`.

The main advantage of also comparing SHA1 hashes is the significant reduction
of false-negatives: even if somehow the mtime, size, inode, etc of the file
hasn't changed, as long as it's content has the SHA1 hash will change
triggering a rebuild (assuming no hash collisions, of course).

## Usage ##

```lua
local System = require "build.systems.sha1-redo" (Posix_File_System, Store, Metadata_Store)
local scheduler = System.create(posix_file_system, metadata_store)
-- Exports: System.Rebuilder, System.Scheduler, System.Hasher, System.Verifying_Trace_Store
```

It provides the same API than the [`build.systems.redo`](systems-redo.md)
functor.

## See also ##

  * [`build.systems.make`](systems-make.md).
  * [`build.systems.redo`](systems-redo.md).
  * [`build.systems.ninja`](systems-ninja.md).
