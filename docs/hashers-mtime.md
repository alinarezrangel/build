---
title: build.hashers.mtime
libbar: yes
---

# `build.hashers.mtime` #

**Special meaning of keys?**
: Yes, as file names.

This simple hasher will record the modification times of a key and mark it as
dirty if it changes.

## Usage ##

```lua
local Hasher = require "build.hashers.mtime" (Posix_File_System)
local hasher = Hasher.create(posix_file_system)
```

  * `Posix_File_System` must be the POSIX file system structure to use.
  * `posix_file_system` must be the `Posix_File_System` instance to use.

## See Also ##

  * [`build.hashers.sha1`](hashers-sha1.md).
  * [`build.hashers.apenwarr`](hashers-apenwarr.md).
  * [`build.hashers.combined-clean`](hashers-combined-clean.md).
  * [`build.hashers.combined-dirty`](hashers-combined-dirty.md).
