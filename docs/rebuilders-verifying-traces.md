---
title: build.rebuilders.verifying-traces
libbar: yes
---

# `build.rebuilders.verifying-traces` #

**Special meaning of keys?**
: No.

**Requires an specific scheduler?**
: No.

A verifying-traces rebuilder. A verifying trace contains a *hash* gotten by a
*hash function* from a key, it's value and it's dependencies hashes. Depending
on the hash function this rebuilder will have different criteria for the
caching.

## Usage ##

```lua
local Rebuilder = require "build.rebuilders.verifying-traces" (Verifying_Trace_Store)
```

  * `Verifying_Trace_Store` is the structure of the verifying traces store to
    use.

The `Rebuilder.create(vt)` function (for a given instance of the
`Verifying_Trace_Store` `vt`) will create and return the new rebuilder.

## See Also ##

  * [`build.rebuilders.mtime`](rebuilders-mtime.md).
  * [`build.rebuilders.dirty_bit`](rebuilders-dirty-bit.md).
  * [`build.rebuilders.phony-adapter`](rebuilders-phony-adapter.md).
