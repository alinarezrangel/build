---
title: build.hashers.mtime
libbar: yes
---

# `build.hashers.mtime` #

**Special meaning of keys?**
: No, but they must have an associated file name.

This simple hasher will record the modification times of a key and mark it as
dirty if it changes.

## Usage ##

```lua
local Hasher = require "build.hashers.mtime" (Posix_File_System, File_Of_Key)
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

  * [`build.hashers.sha1`](hashers-sha1.md).
  * [`build.hashers.apenwarr`](hashers-apenwarr.md).
  * [`build.hashers.combined-clean`](hashers-combined-clean.md).
  * [`build.hashers.combined-dirty`](hashers-combined-dirty.md).
