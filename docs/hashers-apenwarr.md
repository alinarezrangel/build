---
title: build.hashers.apenwarr
libbar: yes
---

# `build.hashers.apenwarr` #

**Special meaning of keys?**
: Yes, as file names.

This hasher is like the [`build.hashers.mtime`](hashers-mtime.md) hasher but it
not only keeps track of the modification time, but also the inode, file size,
owner and group, etc. More details can be found at the article [mtime
comparison considered harmful](https://apenwarr.ca/log/20181113).

## Usage ##

```lua
local Hasher = require "build.hashers.apenwarr" (Posix_File_System)
local hasher = Hasher.create(posix_file_system)
```

  * `Posix_File_System` must be the POSIX file system structure to use.
  * `posix_file_system` must be the `Posix_File_System` instance to use.

## See Also ##

  * [`build.hashers.mtime`](hashers-mtime.md).
  * [`build.hashers.sha1`](hashers-sha1.md).
  * [`build.hashers.combined-clean`](hashers-combined-clean.md).
  * [`build.hashers.combined-dirty`](hashers-combined-dirty.md).
