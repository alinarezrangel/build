---
title: build.schedulers.suspending
libbar: yes
---

# `build.schedulers.suspending` #

The simplest scheduler. It tries to build it's target, suspending it's
execution when a new dependency is discovered. Once that dependency is done,
execution of the original task resumes.

As a way to prevent infinite loops, this scheduler also keeps a dirty bit for
the duration of a single call to it's build function. This means that even if
the rebuilder marks an already built key as outdated, this scheduler will
**not** rebuild it.

## Usage ##

```lua
local Suspending = require "build.schedulers.suspending" (Store)
```

  * `Store` is the structure of the backing store of the scheduler.

## See Also ##

  * [`build.schedulers.topological`](schedulers-topological.md).
