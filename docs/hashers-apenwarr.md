---
title: build.hashers.apenwarr
libbar: yes
---

# `build.hashers.apenwarr` #

**Special meaning of keys?**
: No, but they must have an associated file name.

This hasher is like the [`build.hashers.mtime`](hashers-mtime.md) hasher but it
not only keeps track of the modification time, but also the inode, file size,
owner and group, etc. More details can be found at the article [mtime
comparison considered harmful](https://apenwarr.ca/log/20181113).

## Usage ##

```lua
local Hasher = require "build.hashers.apenwarr" (Posix_File_System, File_Of_Key)
local hasher = Hasher.create(posix_file_system)
```

  * `Posix_File_System` must be the POSIX file system structure to use.
  * `File_Of_Key` must be a function that will be called like
    `File_Of_Key(key)`. It must return the filename of the file associated with
    the key, or `nil` if the key has no filename.
  * `posix_file_system` must be the `Posix_File_System` instance to use.

## Notes ##

Same note from the [`mtime` rebuilder](rebuilders-mtime.md) about file-less
keys applies here.

## See Also ##

  * [`build.hashers.mtime`](hashers-mtime.md).
  * [`build.hashers.sha1`](hashers-sha1.md).
  * [`build.hashers.combined-clean`](hashers-combined-clean.md).
  * [`build.hashers.combined-dirty`](hashers-combined-dirty.md).
