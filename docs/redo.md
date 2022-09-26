---
title: The build.redo tool
toolbar: yes
---

# `build.redo` -- The redo-like clone of `build.lua` #

The program `build.redo` is a tool inspired by the redo program. Specifically,
from both DBJ's redo and Apenwarr's redo.

Unlike the original redos, this one does not use shell scripts for the recipe
files, instead using Lua files that end in `.do.lua`.

## Basic usage ##

The basic usage is simple: use `build.redo` to build the `all` target, or
`build.redo TARGETS...` to build the specified targets.

`build.redo` will first eval the Lua file `Redofile.lua` on the current
directory, if it exists. Then it will run the required recipes as to bring the
targets up to date.

Each recipe is on a file that ends with `.do.lua`. They are named for the file
they will produce when executed. For example, `libexample.so.do.lua` is the
recipe for `libexample.so`.

There is one special recipe name: `default`. If, when building a file `foo.txt`
no `foo.txt.do.lua` file is found, then `default.txt.do.lua` will be
tried. Note how the file name was replaced by `default` yet the extension was
left as-is. For files with multiples extensions, incremental removals will be
tried: `foo.a.b.c` will cause the search of `foo.a.b.c.do.lua`,
`default.a.b.c.do.lua`, `default.b.c.do.lua` and `default.c.do.lua`.

If no recipe is found on the same directory than the desired file, the parent
directory will be tried. This continues until the directory in which
`build.redo` is executing.

## Lua DSL ##

## `Redofile.lua` ##

The redofile will be executed at the very beginning of the build process. It
will be run every time `build.redo` is executed, so you want it to be fast. It
has access to a fresh global environment with all the normal Lua
bindings. Additionally, the following bindings are available:

  * `utils`: The `build.utils` module.
  * `REDO_DSL_VERSION`: A table with the version of the `build.redo` DSL. It
    contains the keys `major`, `minor` and `patch`.
  * `SHELL`: A string: the shell to use (defaults to `sh`).
  * `build(key)`: Builds `key`, which must be a string containing the name of
    the file to build. This function can not be called after the `Redofile.lua`
    has finished executing.
  * `run_wait(...)`: The `run_wait` function from the [POSIX
    module](internals.md#run_wait_func).
  * `run(cli)`: `cli` must be a non-empty sequential table. The first element
    will be the program to execute, while remaining ones will be the arguments
    to use. Returns the program's exit code.
  * `sh(cmd)`: Runs `cmd` under the shell (specified by the global `SHELL`).
  * `shellquote(words)`: Quotes (with `shellquote`(1p)) the `words`, a
    sequential table of strings. Returns a string which would be interpreted by
    a POSIX shell as several words with the values of `words`.
  * `shf(cmdf, ...)`: *Formatted shell*. Like `sh(cmd)`, but first formats the
    command `cmdf` using the variadic arguments. The following formatting
    specifiers are recognized: `%%` is a literal `%`, `%s` inserts an argument
    as-is, `%w` takes a string argument and inserts the result of `shellquote
    {ARG}` and `%W` which takes a sequential-table-of-strings (array of
    strings) and inserts the results of `shellquote(ARG)`.
    
    The value of this function comes from the ability of creating shell-safe
    commands even on the presence of shell keywords, spaces, single or double
    quotes and more. For example, `shf("echo %w", "hello > world")`
    appropiatedly prints `hello > world` rather than creating a file `world`
    with the contents `hello`. As with the `shellquote` function, this assumes
    that `SHELL` points to a POSIX-compatible shell.

You can create your own globals, which will be visible on all recipe files.

**Note**: Modifying any global from a recipe file will have no effect. This is
as to prevent globals from being used to communicate between recipes and making
the build process a mess. This constraint is enforced loosely via a shallow
copy of the environment and you can easily side-step it by using global tables
(as no value is copied deeply).

## Recipe files (`.do.lua`) ##

The recipe files have the same bindings than `Redofile.lua`, and additionally
can access:

  * `TARGET`: A string with the file being built.
  * `TARGET_NAME`: `basename`(1) of the target.
  * `TARGET_DIR`: `dirname`(1) of the target.
  * `RECIPE`: A string with the filename of this recipe file (relative to the
    `build.redo` command).
  * `RECIPE_NAME`: `basename`(1) of the recipe file.
  * `RECIPE_DIR`: `dirname`(1) of the recipe file.
  * `ifchange(...)`: All of the arguments must be strings. This function
    registers them as dependencies of this target. As the name says, if any of
    them changes, this file will be rebuilt.
  * `ifanychanges(targets)`: `targets` must be a sequential table of
    strings. Same as calling `ifchange` with all the values of `targets`.
  * `always()`: Special function which marks this target as permanently out of
    date. The name means "always rebuild (this file)".

As with the original `redo`(1), each recipe is executed while inside its
directory. So for example, the recipe file `a/b/c.do.lua` would be executed
while inside `a/b/`.

## Command line usage ##

See `build.redo -h` for a listing of all command line options and what they do.
