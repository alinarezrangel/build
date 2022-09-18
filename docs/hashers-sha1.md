---
title: build.hashers.sha1
libbar: yes
---

# `build.hashers.sha1` #

**Special meaning of keys?**
: No, but they must have an associated file name.

This hasher uses the SHA1 hash of a file as it's VT hash. This way changes to a
file that affect it's modification date but not it's content will not trigger a
rebuild.

Note that SHA1 hashes, like all hash functions, have a risk of collisions. When
this happens the file will not be rebuilt. This is problematic as it is assumed
that VT hashers will have false positives but never false negatives and as such
not only will a rebuild not be triggered (causing all sorts of issues for your
build) but also there is no way to force a rebuild of a key in a store. Because
of this, build systems provided by this library always mix this hasher with
another one, using the SHA1 hash as a mere "quick exit" ("if the SHA1 hashes
are different then we *know* the file has changed"). Still, if you feel
specially lucky, you can use this VT hasher as-is and ignore the possible
collisions.

## Usage ##

```lua
local Hasher = require "build.hashers.sha1" (Posix_File_System, File_Of_Key)
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
  * [`build.hashers.apenwarr`](hashers-apenwarr.md).
  * [`build.hashers.combined-clean`](hashers-combined-clean.md).
  * [`build.hashers.combined-dirty`](hashers-combined-dirty.md).
