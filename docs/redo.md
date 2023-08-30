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
`build.redo` is executing is reached.

## Lua DSL ##

The DSL used by the `build.redo` uses the [Lua](https://lua.org) programming
language. Some important terms are:

  * *Output file*: A file produced by `build.redo` that is **not** part of your
    source code.
  * *Recipe file*: The `.do.lua` file that produces an output file.
  * *Source file*: A file which is not produced by a recipe.
  * *Redofile*: The `Redofile.lua` file that is executed at the beginning of
    each run.

## `Redofile.lua` ##

The redofile will be executed at the very beginning of the build process. It
will be run every time `build.redo` is executed, so you may want to avoid any
slow operation. It has access to a fresh global environment with all the normal
Lua bindings (`io`, `string`, `table`, `os`, etc). Additionally, the following
bindings are available:

  * `utils`: The `build.utils` module.
  * `REDO_DSL_VERSION`: A table with the version of the `build.redo` DSL. It
    contains the keys `major`, `minor` and `patch`.
  * `SHELL`: A string: the shell to use (defaults to `sh`).
  * `BASE_DIR`: Absolute path to the directory where `build.redo` is being run.
  * `build(key)`: Builds `key`, which must be a string containing the name of
    the file to build. This function can not be called after the `Redofile.lua`
    has finished executing.
  * `run_wait(program, args, config)`: The `run_wait` function from the [POSIX
    module](internals.md#run_wait_func). The first parameter (`fs`) is no
    longer necessary.
  * `run(cli)`: `cli` must be a non-empty sequential table. The first element
    will be the program to execute, while remaining ones will be the arguments
    to use. Returns the program's exit code.
  * `sh(cmd)`: Runs `cmd` (a string) under the shell (specified by the global
    `SHELL`).
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
  * `fsh(cmdf, ...)`: This function does the formatting of `shf`. Returns the
    formatted string.
  * `trim_slashes(dir)`: Removes the slashes at the end of a path.
  * `num_directories(path)`: Counts the number of directories in a path.
  * `setenv(name, value)`: Sets an environment variable.
  * `getenv_or_empty(name, def)`: Tries to get the environment variable
    `name`. If it does not exists, returns `def` (if passed) or the empty
    string.
  * `empty_or(value, def)`: If `value` is false, nil or the empty string,
    returns `def`. Otherwise returns `value`.
  * `read_file(path)`: Reads the file at `path` and returns it's contents as a
    string. This does not declare a dependency on `path` so be careful and
    declare it yourself.
  * `write_file(path, content)`: Writes `content` (a string) to the file at
    `path`, overwriting its previous contents.
  * `chomp_file(path)`: Like `read_file` but removes any trailing newlines.
  * `get_cwd()`: Returns the current working directory.
  * `fprint(handle, ...)`: Like `print`, but prints to a file handle.
  * `eprint(...)`: Like `print`, but prints to `io.stderr`.
  * `printf(fmt, ...)`: Equivalent to `print(string.format(fmt, ...))`.
  * `eprintf(fmt, ...)`: Equivalent to `eprint(string.format(fmt, ...))`.
  * `errorf(fmt, ...)`: Equivalent to `error(string.format(fmt, ...))`.
  * `warnf(fmt, ...)`: Equivalent to `warn(string.format(fmt, ...))`.
  * `replace_extension(path, new_ext)`: Replaces the last extension of `path`
    by `new_ext`. `new_ext` is expected to contain a leading dot `.`. If `path`
    has no extensions returns it as-is.
  * `join`: Alias for `utils.eager_join`.

You can create your own globals, which will be visible on all recipe files. For
example:

```lua
function join_commas(tbl)
   return table.concat(tbl, ", ")
end
```

Will make the `join_commas` function available to all recipe files.

Additionally, there are 2 hooks that you can use to customize the handling of
recipe files: the `prelude` and `postlude` hooks. They are explained on more
depth on the section [Hooks and dynamic extents](#hooks-and-dynamic-extents).

## Recipe files (`.do.lua`) ##

The recipe files have the same bindings than `Redofile.lua`, and additionally
can access:

  * `RECIPE`: A string with the filename of this recipe file (relative to the
    `build.redo` command).
  * `REL_BASE_DIR`: Like `BASE_DIR`, but relative to the recipe file.
  * `RECIPE_NAME`: `basename`(1) of `RECIPE`.
  * `RECIPE_DIR`: `dirname`(1) of `RECIPE`.
  * `TARGET`: A string with the file being built, relative to the recipe file.
  * `TARGET_NAME`: `basename`(1) of `TARGET`.
  * `TARGET_DIR`: `dirname`(1) of `TARGET`.
  * `ABS_TARGET`: Absolute path to the file being built.
  * `ABS_TARGET_NAME`: `basename`(1) of `ABS_TARGET`.
  * `ABS_TARGET_DIR`: `dirname`(1) of `ABS_TARGET`.
  * `ifchange(...)`: All of the arguments must be strings representing
    paths. This function registers them as dependencies of this target. As the
    name says, if any of them changes, this file will be rebuilt.
  * `ifanychanges(targets)`: `targets` must be a sequential table of
    strings. Same as calling `ifchange` with all the values of `targets`.
  * `always()`: Special function which marks this target as permanently out of
    date. The name means "always rebuild (this file)".

As with the original `redo`(1), each recipe is executed while inside its
directory. So for example, the recipe file `a/b/c.do.lua` would be executed
while inside `a/b/`.

Inside recipes, you can pass filenames that are relative to the recipe file to
`ifchange` and `ifanychanges` (normally relative filenames have to be relative
to the `build.redo` tool invocation).

The *environment* of the recipe file **is a copy** of the environment of the
redofile. This means that globals set on the redofile are visible inside the
recipe file, but setting them directly has no effect. For example:

```lua
-- In Redofile.lua

X = 1
Y = {2}

function Z()
   print("X", X)
   print("Y", Y[1])
end

function W()
   print "<W"
   Z()
   print "W>"
end

-- In all.do.lua

W()
X = 2
W()
Y[1] = 3
W()
Y = {7}
W()

function Z()
   print "no"
end

W()
```

Prints:

```
<W
X	1
Y	2
W>
<W
X	1
Y	2
W>
<W
X	1
Y	3
W>
<W
X	1
Y	3
W>
<W
X	1
Y	3
W>
```

Notice how assigments to `X` and `Z` don't have any effect, while modifying `Y`
does, but assigning it doesn't. This perfectly matches Lua semantics with
shared tables, but can be unexpected nonetheless.

## Hooks and dynamic extents ##

Because of the previously mentioned fact about environments, the global
environment of the redofile **is not the same** than the one of the recipe
files. This means that you **cannot access recipe variables from the
redofile**. For example, the following program will print `nil`:

```lua
-- In Redofile.lua

function whoami()
   print(RECIPE)
end

-- In all.do.lua

whoami()
```

The function `whoami` is successfully called, but it prints `nil`. This is
because the variable `RECIPE` is set on the recipe's environment and not on the
redofile's environment.

(I might change this behaviour in the future, as it is confusing.)

To allow you to use the environment variables from the redofile, two hooks are
provided: `prelude` and `postlude`.

If the redofile defines any of these functions, they will be called as
`prelude(env)` or `postlude(env)` before/after the recipe is executing. `env`
is the environment of the recipe. For example, fixing the previous example:

```lua
-- In Redofile.lua

function prelude(env)
   function env.whoami()
      print(env.RECIPE)
   end
end

-- In all.do.lua

whoami()
```

`prelude` is called right before executing the recipe and `postlude` right
after it has finished. In both cases you can access all of the recipes global
variables via the `env` table.

Thanks to the `prelude` and `postlude` hooks, your redofile can build arbitrary
DSLs to automatize your recipe files. This allows recipe files to stay small
and on a relatively straightforward, imperative, procedural style.

For example, on one project `build.redo` was used inside a subdirectory of the
project (kind of like having a `build/` directory with make). Rather than
constantly hard-coding the relative path to the project's root in each recipe
file (which is error-prone and will get invalidated if the recope files are
moved), the `prelude` hook of the redofile calculated the relative path to the
project's root before each recipe started executing, exporting it as the
`REL_ROOT` variable to each recipe. Now each recipe can just use the `REL_ROOT`
variable without problems nor any pre-build-time macro replacement routine.

## Command line usage ##

See `build.redo -h` for a listing of all command line options and what they do.

## Common patterns ##

### File variables ###

Because `build.redo` can only track files, build variables are a
problem. Changing a recipe, an input file or the redofile will trigger a
recompilation of the dependent files. But changing an environment variable will
not:

```lua
-- In output.txt.do.lua

local var = os.getenv "VAR" or "-unset-"
print("var is", var)
-- Cannot say `ifchange(var)` as that interprets `var` as a file name.
write_file(TARGET, var)
```

In the above example, `output.txt` depends on the env variable `VAR`. But we
cannot declare such dependency. This makes your builds unstable (as changing
their dependencies no longer triggers a rebuild) allowing your build outputs to
get out of date. Detecting when an output is out of date because of an
undeclared dependency might not be easy and could make you lose a lot of time
debugging it. To fix this you can use the pattern described in `redo`'s
original documentation: storing variables into files.

```lua
-- In Redofile.lua

function prelude(env)
   function get_var()
      local envvar = os.getenv "VAR"
      if envvar then
         return envvar
      else
         env.ifchange "VAR.txt"
         return chomp_file "VAR.txt"
      end
   end
end

-- In output.txt.do.lua

local var = get_var()
write_file(TARGET, var)
```

In the previous example the environment variable `VAR` is still used so that
you can still override its value for a single invocation, but the way is meant
to be used is by writing the value of the variable to the `VAR.txt`
file. Storing build-time variables in files may look weird, but it has many
advantages over the traditional usage of environment variables in programs such
as make:

  1. As mentioned before, changes to the variable automatically trigger a
     rebuild of the project.
  2. You can store the default value of the variable on the file itself.
  3. By having one file per variable it is easy to see all the knobs of the
     build without having to read all the source code.

I generally prefer to put all the variables on a `vars/` directory (so
`vars/CC`, `vars/LDFLAGS`, etc).

### `configure` script ###

Thanks to Lua's support for the special `%q` format on its `string.format`
function, it is really easy to write your own `configure`-like scripts for
`build.redo`. For example, this simple `serialize` function takes a normal,
non-recursive Lua table and serializes it:

```lua
local function serialize_table(tbl)
   local res = {"{"}
   for key, value in pairs(tbl) do
      res[#res + 1] = string.format("[%q] = ", key)
      res[#res + 1] = serialize(value)
   end
   res[#res + 1] = "}"
   return table.concat(res, "\n")
end

function serialize(val)
   if type(val) == "table" then
      return serialize_table(val)
   else
      return string.format("%q", val)
   end
end
```

You could use this to emit variable assigments:

```lua
-- Using the previous functions...

local out <close> = io.open("config.lua", "wb")
local config = {
   os = detect_os(),
   arch = detect_architecture(),
   cc = detect_cc(),
   prefix = get_prefix(),
   -- etc
}
out:write "CONFIGURATION = "
out:write(serialize(config))
out:write "\n"
```

This example will create a `config.lua` file with contents like:

```lua
CONFIGURATION = {
   os = "linux",
   arch = "x86-64",
   cc = "gcc",
   prefix = "/usr/local",
}
```

(Assuming, of course, suitable implementations of all the `detect_*`
functions.)

You could then `require` the `config.lua` and use the generated variable. Note
how no part of the code had to handle escaping strings, numbers, booleans, etc.

Note that `configure`-like scripts often are not necessary with `build.redo`:
the ability to declare dependencies after-the-fact and to discover them
dynamically means that most of the things you would have previously solved by
generating a makefile can now be solved just by normal recipe files. As an
example, if we have a target that should contain a zip of all source files,
rather than generating a Makefile like this:

```sh
OUT=dist.make
GEN=dist.zip
touch "$OUT"
printf '%s:' "$GEN" > "$OUT"
for file in **/*.c
do
    printf ' %s' "$file" >> "$OUT"
done
printf '\n\tzip $@ $^\n' >> "$OUT"
```

An then including it on your normal makefile, you can instead do:

```lua
-- In dist.zip.do.lua

local srcs = table_glob "**/*.c"
ifanychanges(srcs)
shf("zip %w %W", TARGET, srcs)
```

Which properly discovers and registers the dependencies.

(It also has the advantage of propertly escaping file names passed to `zip`,
but the makefile-generating script could probably do the same with more code
and/or a call to `shellquote`(1p), which `build.redo` uses anyways.)

### Multiple output files ###

A recipe that produces multiple outputs can be handled by creating several
"dummy" recipes that only depend on the first one. For example:

```lua
-- This recipe produces several files. Let's name it for the main one.

-- index.txt.do.lua

write_file(TARGET, [[1.txt
2.txt
]])
write_file("1.txt", "1\n")
write_file("2.txt", "2\n")

-- 1.txt.do.lua

ifchanges "index.txt"

-- 2.txt.do.lua

ifchanges "index.txt"
```

Notice how the recipes for `1.txt` and `2.txt` do nothing but depend on
`index.txt`, which creates all 3 files.

### Phony targets ###

A recipe that calls `always` will be considered out of date for the next
rebuilding. To implement make's `.PHONY` rules call the `always` function at
the beginning of the file:

```lua
-- all.do.lua

always()
ifchange "output.exe"
ifchange "output.out"
ifchange "lib.so"
ifchange "lib.a"
```

## Bugs and notes ##

### Recursive `build.redo` ###

As of 2023-01-03, there is no support for recursive `build.redo` invocations
for the same project and doing so will corrupt the database. Rather than that,
use the `ifchange`-like functions. These functions do the same thing
`build.redo` would when invoked with the given arguments as targets (so
`ifchange "hello"` is the same than `build.redo hello` at that directory).

### Relative and absolute paths ###

Mixing relative and absolute paths might cause issues with the database. This
is because to know when to rebuild a file the database stores "keys" which are
the file names. Because a single file might have several different names, you
can have several keys which actually match to the same file. In this case
`build.redo` cannot know when to rebuild the file. As far as I have thought
about this, this seems like a very hard to fix issue.

In theory this could be solved if I used inodes as keys rather than filenames,
after all, *the database is not portable* anyways. But that is not yet
implemented.

In the time being, avoid mixing absolute and relative filenames. Remember that
both hardlinks and symlinks are treated by `build.redo` as completely different
files from their target.

To try to make all of this easier to do, `build.redo` tries to translate
everything into relative filenames by default. They are relative to the
directory where `build.redo` is running. So, if `build.redo` is running at `/a`
and inside `/a/b/c` you run `ifchange "/a/b/c/d"` it will translate it to
`ifchange "./d"`. This is done via text manipulation and as such hardlinks and
symlinks are treated as different (so if you have a symlink `/g` which points
to `/a/b/c/d`, running `ifchange "/g"` will **not** get translated).

### Paralellism ###

Not yet implemented.
