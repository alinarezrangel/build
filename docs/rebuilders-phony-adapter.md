---
title: build.rebuilders.phony-adapter
libbar: yes
---

# `build.rebuilders.phony-adapter` #

**Special meaning of keys?**
: No.

**Requires an specific scheduler?**
: No.

This rebuilder will always rebuild keys that satisfy an `is_phony_key`
predicate. All other keys will be rebuilt using a `backing_rebuilder`.

## Usage ##

```lua
local Rebuilder = require "build.rebuilders.phony-adapter"
local rebuilder = Rebuilder.create(backing_rebuilder, is_phony_key)
```

This module is not a functor.

The `Rebuilder.create()` will create and return the new rebuilder. The
`backing_rebuilder` must be another rebuilder to use then the key is not a
phony key. The `is_phony_key` will be called like this:

```lua
local is_phony = is_phony_key(key)
```

## See Also ##

  * [`build.rebuilders.mtime`](rebuilders-mtime.md).
  * [`build.rebuilders.verifying-traces`](rebuilders-verifying-traces.md).
  * [`build.rebuilders.dirty_bit`](rebuilders-dirty-bit.md).
