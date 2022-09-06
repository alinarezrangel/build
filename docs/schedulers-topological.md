---
title: build.schedulers.topological
libbar: yes
---

# `build.schedulers.topological` #

A *topological* scheduler. Orders all required keys in the store
*topologically* and builds them in order. Because of the guarantee that
dependency information is accurate, this linear scan will always build
dependencies of a key before the key itself.

While conceptually the simplest, this happens to be quite complex to implement
in Lua due to the architecture of the program. In the original Haskell program,
the static restrictions of the `Applicative` typeclass make it so that for any
given set of tasks the build system can always infer all the dependencies of a
given key. Sadly (or happily, depending on your point of view), Lua has no type
system. Because of this the user of this scheduler must provide dependency
information manually and unlike in the Haskell program there is no check that
it is accurate.

(Like in make or ninja, inaccurate dependency information will manifest itself
in unpredictable build and misterious errors.)

## Usage ##

```lua
local Topological = require "build.schedulers.topological" (Store)
```

  * `Store` is the structure of the backing store of the scheduler.

While the API is the same than
[`build.schedulers.suspending`](schedulers-suspending.md), trying to use it
like another scheduler will quickly result in a "The topological scheduler only
supports topological tasks (created with the `topological_tasks()` function)"
error. This is because this scheduler does not accept any function as its tasks
function, but instead only accepts value produced by the
`Topological.topological_tasks(tasks, dependencies)`. This function takes your
normal `tasks` function but also a `dependencies` table. Said table keys must
be the keys of the store and its values must be a sequential table (an array)
of the keys in which this one depends.

For example, to say that the key `"A"` depends on `"B"` and `"C"`, while key
`"B"` depends on `"C"`, the following table would be used:

```lua
local dependencies = {
    ["A"] = {"B", "C"},
    ["B"] = {"C"},
}
```

Keys which are not found are assumed to have no dependencies.

As an additional thing of this scheduler, its `task` function also has methods:
`task(fetch)` will build the given task like in all other schedulers but
`task:get_dependecies()` will return the sequential table (array) with all the
dependencies of that task. This is extremely useful when writting rebuilders
that require dependency information.

## See Also ##

  * [`build.schedulers.suspending`](schedulers-suspending.md).
