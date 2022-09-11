---
title: build.rebuilders.dirty_bit
libbar: yes
---

# `build.rebuilders.dirty_bit` #

**Special meaning of keys?**
: No.

**Requires an specific scheduler?**
: No.

The simplest rebuilder, keeps a dirty bit for each key, building it only
once. With no way to store this key for future use nor a way to unmark a key,
is of little practical use.

## Usage ##

```lua
local Rebuilder = require "build.rebuilders.dirty_bit" ()
```

The `Rebuilder.create()` will return the rebuilder.

## See Also ##

  * [`build.rebuilders.mtime`](rebuilders-mtime.md).
  * [`build.rebuilders.verifying-traces`](rebuilders-verifying-traces.md).
  * [`build.rebuilders.phony-adapter`](rebuilders-phony-adapter.md).
