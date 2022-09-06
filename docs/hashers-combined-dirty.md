---
title: build.hashers.combined-dirty
libbar: yes
---

# `build.hashers.combined-dirty` #

**Special meaning of keys?**
: No, they are passed as-is to the combined hashers.

A *combined* hasher. Accepts several hashers as its inputs and marks a key as
dirty if **any** of the hashers says that it is dirty. Basically it is an
`or` for hashers.

## Usage ##

```lua
local COMBINED_DIRTY = require "build.hashers.combined-dirty"
local Hasher = COMBINED_DIRTY (...)
local hasher = Hasher.create_combined_hashers(...)
```

In the first call, the arguments to the `COMBINED_DIRTY` functor must be the
structures of all the hashers to combine. In the second call, the arguments to
the `create_combined_hashers()` function must be all the instances of the
hashers in the same order than the structures.

## Example ##

For example, let's combine the [mtime](hashers-mtime.html) and the
[sha1](hashers-sha1.html) hashers to create a new hasher that considers a file
dirty if either its SHA1 hash or its modification time have changed.

```lua
local Posix_File_System = require "build.file-systems.posix"
local COMBINED_DIRTY = require "build.hashers.combined-dirty"
local Sha1_Hasher = require "build.hashers.sha1" (Posix_File_System)
local Mtime_Hasher = require "build.hashers.mtime" (Posix_File_System)
local Combined_Hasher = COMBINED_DIRTY(Sha1_Hasher, Mtime_Hasher)

local fs = Posix_File_System.global()
local sha1_hasher = Sha1_Hasher.create(fs)
local mtime_hasher = Mtime_Hasher.create(fs)
local combined_hasher = Combined_Hasher.create_combined_hashers(sha1_hasher, mtime_hasher)
-- Use `combined_hasher` freely
```

## See Also ##

  * [`build.hashers.mtime`](hashers-mtime.md).
  * [`build.hashers.sha1`](hashers-sha1.md).
  * [`build.hashers.apenwarr`](hashers-apenwarr.md).
  * [`build.hashers.combined-clean`](hashers-combined-clean.md).
