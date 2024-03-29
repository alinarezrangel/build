---
title: Internals of build.lua
libbar: yes
---

# Internals of `build.lua` #

As described in [Build Systems a la
Carte](https://www.microsoft.com/en-us/research/publication/build-systems-la-carte/),
a build system is basically a program that takes a *key-value store* with
possibly out-of-date values and sets a desired *key* to it's up-to-date value,
given a set of recipes that can update any key. The architecture of `build.lua`
is extremely similar to that of the Haskell program described on the paper,
consisting of the *store*, the *scheduler* (who decides *how* to update the
keys given their dependencies) and the *rebuilder* (who decides whenever to
rebuild or not a given key). Each recipe is instead called a *task* and the set
of recipes is instead a *tasks* function that returns the *task* for a given
*key*.

Specifically, the *tasks* function has the form:

```lua
function tasks(key)
    return task
end
```

And each *task* function the form:

```lua
function task(fetch)
    return new_value
end
```

Where `fetch` is a function that can be called like `local value =
fetch(another_key)` and returns the up-to-date value of said key, possibly
rebuilding it.

## Functors and structures ##

For maximum flexibility, most modules in this library use a *functor* pattern
that I copied from the [Standard
ML](https://en.wikipedia.org/wiki/Standard_ML). In this pattern, a Lua module
does **not** return a table with it's functions and variables as normal, but
instead returns a function. This function takes several *structures* or
*functors*[^1] as parameters and *then* it returns your average Lua table with
functions and data.

A functor that has been applied is called a *structure*. While by definition
all normal Lua modules count as structures, I will only call structures those
who additionally follow the same API restrictions as functor-created
structures.

All the APIs used by functors and structures have the same form for most of
their operations:

    Structure.operation(structure_instance, ...)

Let's go through an example:

```lua
-- printer.lua -- A functor
return function(Terminal)
    local M = {}

    function M.create(terminal)
        return { my_terminal = terminal }
    end
    
    function M:print(message)
        Terminal.write(self.my_terminal, message)
        Terminal.write(self.my_terminal, "\n")
    end

    return M
end

-- terminal.lua -- A structure
local M = {}

function M.global()
    return { handle = io.stdout }
end

function M:write(text)
    self.handle:write(text)
end

return M
```

To use these modules together, we would do:

```lua
local Terminal = require "terminal"
local PRINTER = require "printer"
local Printer = PRINTER(Terminal)

local term = Terminal.global()
local printer = Printer.create(term)
Printer.print(printer, "hello world")
```

As a convention, structures are named in Camel Case when imported, while
functors in UPPER CASE. Naming functors is almost never necessary as you can
always do `require "printer" (Terminal)`.

When properly executed, a good functor has almost no `require`s: all of them
have been lifted to parameters of the functor. This basically is dependency
injection. See also [Dependency Injection
(Wikipedia)](https://en.wikipedia.org/wiki/Dependency_injection) and the
[NewSpeak programming language](https://newspeaklanguage.org/).


## File systems ##

Module: `build.file-systems`. You cannot import `build.file-systems` directly,
instead, import one of its submodules.

The only available file system is
[`build.file-sistems.posix`](file-systems-posix.md).

## Stores ##

Module: `build.stores`.

Interface:

```lua
-- For a given `Store` and `store` instance
Store.put(store, key, value)
local value = Store.get(store, key)
local value, found = Store.try_get(store, key)
```

The store must be able to store and retrieve `nil`s, and distinguish a `nil`
valued key from a non-existing one.

Available stores:

  * [`build.stores.table`](stores-table.md): An in-memory, volatile store.
  * [`build.stores.json`](stores-json.md): A store that can be saved and loaded
    from a JSON file.

## Schedulers ##

Module `build.schedulers`. Importing `build.schedulers` is the same as
importing all of it's submodules.

Interface:

```lua
-- For a given `Scheduler`
local build_function = Scheduler.create(rebuilder)
-- Where `build_function` has the form:
-- function build_function(tasks, key, store) -> up_to_date_value_of_key
```

Available schedulers:

  * [`build.schedulers.topological`](schedulers-topological.md): Requires a
    fixed, ahead-of-time full dependency graph.
  * [`build.schedulers.suspending`](schedulers-suspending.md): Discovers the
    dependencies of a task dynamically.

## Rebuilders ##

Module `build.rebuilders`. Importing `build.rebuilders` is the same as
importing all of it's submodules.

Interface:

```lua
-- For a given `rebuilder` instance
local caching_fetch = rebuilder(key, value, task)(fetch)
-- Where `caching_fetch` has the form:
-- function caching_fetch(key) -> up_to_date_value_of_key
```

Available rebuilders:

  * [`build.rebuilders.mtime`](rebuilders-mtime.md): Rebuild a file only if
    it's dependencies are newer than it. Requires the [topological
    scheduler](schedulers-topological.md).
  * [`build.rebuilders.verifying-traces`](rebuilders-verifying-traces.md):
    Rebuild a file only a *verifying-traces store* determines it's trace has
    changed.
  * [`build.rebuilders.dirty_bit`](rebuilders-dirty-bit.md): Mostly useless in
    real life, this simple rebuilder servers as an example. It only rebuilds
    each target one; without a way to save the "dirty bit" to non-volatile
    storage this rebuilder is just not very practical.
  * [`build.rebuilders.phony-adapter`](rebuilders-phony-adapter.md): This
    *adapter* wraps another rebuilder so that certain keys are always
    considered out-of-date.

## Traces ##

Module `build.traces`. Importing `build.traces` is the same as importing all of
it's submodules.

### Verifying ###

Module `build.traces.verifying`. Importing `build.traces.verifying` is the same
as importing all of it's submodules.

Implements a *verifying-trace store*. These stores associate each key with a
*verifying-trace* which consists of a hash of it's value and it's
dependecies. This way, when the hash changes you know the key is out-of-date.

You can implement your own verifying-traces store that uses it's own hashing
method that doesn't conform to the *hashers* interface used by this
module. This way if the hasher interface is too strict for your requirements
you are not left without option. Nonetheless I don't expect this to be a very
common case and I think most people will want to use
[`build.traces.verifying.hash`](traces-verifying-hash.md) most of the time.

Interface:

```lua
-- For a given `VT` (Verifying-Traces store) and `vt` instance
local hash = VT.hash(vt, key, value)
VT.record(vt, key, value_hash, dependencies_hashed)
local is_up_to_date = VT.verify(vt, key, value_hash, get_dependency_hash)
-- Where `get_dependency_hash` is a function of the form:
-- function get_dependency_hash(key) -> hash
```

Verifying-traces stores only need to handle their own hash type.

  * [`build.traces.verifying.hash`](traces-verifying-hash.md).

## Hashers ##

Module `build.hashers`. Importing `build.hashers` is the same as importing all
of it's submodules.

The hashers are used by the [hashing verifying-traces
store](traces-verifying-hash.md) to determine whenever or not to rebuild a
*key*. Hashes are composable and they conform to the very simple interface of:

```lua
-- For a given `Hasher` and `hasher` instance.
local hash = Hasher.hash(hasher, key, value)
local is_dirty = Hasher.hash_dirty(hasher, old_hash, new_hash)
```

Available hashers are:

  * [`build.hashers.mtime`](hashers-mtime.md): The hash is it's modification
    time of the key's file. Keys get rebuilt when modified.
  * [`build.hashers.sha1`](hashers-sha1.md): The hash is the SHA1 hash of the
    key's file. Keys get rebuilt when changed.
  * [`build.hashers.apenwarr`](hashers-apenwarr.md): The out-of-dateness
    criteria described by Apenwarr in [mtime comparison considered
    harmful](https://apenwarr.ca/log/20181113).
  * [`build.hashers.combined-clean`](hashers-combined-clean.md): Combines 2 or
    more hashers, if any of them says the key is clean then the key is
    considered clean.
  * [`build.hashers.combined-dirty`](hashers-combined-dirty.md): Combined 2 or
    more hashers, if any of them says the key is dirty then the key is
    considered dirty.

## Systems ##

Module: `build.systems`. Importing `build.systems` is the same as importing
`build.systems.make`, `build.systems.ninja`, `build.systems.redo` and
`build.systems.shake`.

For ease of use as an embedded library, some build systems are prebuild. These
configurations are not as flexible, but if you do not plan on making use of the
most advanced features of this library and instead only want a Lua library to
keep things up to date, these are useful:

  * [`build.systems.make`](systems-make.md): *Make*-like system. Builds files
    by comparing their *mtimes*. Requires all dependencies up-front.
  * [`build.systems.redo`](systems-redo.md): *Redo*-like system. Builds files
    by using their [Apenwarr's hash](hashers-apenwarr.md). Discovers
    dependencies dinamically.
  * [`build.systems.ninja`](systems-ninja.md): *Ninja*-like system. Builds
    files by using their [Apenwarr's hash](hashers-apenwarr.md). Requires all
    dependencies up-front.
  * `build.systems.shake`: Alias for [`build.systems.redo`](systems-redo.md).
  * [`build.systems.sha1-redo`](systems-sha1-redo.md): Variant of
    `build.systems.redo` that uses the SHA1 hash of the files instead of their
    Apenwarr's hash.

[^1]: Thankfully we don't need to worry about the typechecking issues of higher-order functors, as Lua is dynamically typed.
