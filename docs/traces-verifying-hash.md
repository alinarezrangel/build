---
title: build.traces.verifying.hash
libbar: yes
---

# `build.traces.verifying.hash` #

An implementation of a verifying traces store with a swappable hash
implementation.

It uses a backing store to remember the hashes of the previous build as to
compare them.

## Usage ##

```lua
local Verifying_Trace_Store = require "build.traces.verifying.hash" (Store, Hasher)
```

  * `Store` is the structure of the backing store to use.
  * `Hasher` is the structure of the hasher to use.

```lua
local new_vt = Verifying_Trace_Store.create(backing_store, hasher)
```

The `Verifying_Trace_Store.create(backing_store, hasher)` creates and returns a
new verifying traces store given `backing_store` (an instance of the backing
`Store`) and a `hasher` (the instance of the `Hasher`).
