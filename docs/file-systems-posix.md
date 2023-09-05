---
title: build.file-systems.posix
libbar: yes
---

# `build.file-systems.posix` #

It is a structure (not a functor) with the following interface:

```lua
local Posix_File_System = require "build.file-systems.posix"
local fs = Posix_File_System.global()
Posix_File_System.change_current_directory(fs, path)
local cwd = Posix_File_System.get_current_directory(fs)
local is_a_term = Posix_File_System.is_a_terminal(fs, handle_or_fileno)
local right_now = Posix_File_System.current_time(fs)
local stat_st = Posix_File_System.get_stats(fs, path)
local mtime = Posix_File_System.get_mtime(fs, path)
local res = Posix_File_System.run_wait(fs, program, args, config)
local errnos = Posix_File_System.get_errno(fs)
Posix_File_System.setenv(fs, name, value)
local ok, error, errno = Posix_File_System.try_delete_file(fs, path)
```

The `global()` function returns an instance of the file system. As this module
uses [`luaposix`](https://luaposix.github.io/luaposix/index.html) there is no
such thing as multiple "file systems" and you can only use the global one.

-------------------------------------------------------------------------------

Why even bother with making the file system swappable like this? Well,
for one, not all POSIX file systems are "global" and always available. Imagine
for example that you want to run this over
[WebAssembly](https://webassembly.org) which uses a capability-based
model. Then you could write your own `Posix_File_System` that has a different
constructor than `global()` but has all the same functions.

Second, by explicitly documenting which parts of `build.lua` assume a POSIX
file system and which don't, I make it easier for you to know which parts need
porting if you want to take advantage of a different, incompatible file system.

-------------------------------------------------------------------------------

The next functions are all simple: `change_current_directory()` does what its
name says (it's basically a Lua version of `cd`), `get_current_directory()` is
similar, being a Lua version of `pwd`, `is_a_terminal()` returns `true` or
`false` depending on the handle or fileno is a tty (see `isatty`(3)),
`current_time()` returns the current time in seconds since the
epoch. `get_stats()` gets the stat structure of a path. It must return a table
[like the one used by
luaposix](https://luaposix.github.io/luaposix/modules/posix.sys.stat.html#PosixStat).

`get_mtime()` is a subset of `get_stats()`: it only returns the `st_mtime` field.

`get_errno()` returnsa table mapping all the errno names to their numeric
values for this system. For example, if `errnos` is the errno table returned by
`get_errno()` then `errnos.EINVAL` is the number that corresponds with
`EINVAL`.

`setenv()` will set an environment variable, as it's name says.

`try_delete_file()` will try to permanently delete a file. It either returns
`true` if the file could be deleted, or `false, errmsg, errno` where `errmsg`
is a string with the error message and `errno` is the errno for the error.

<a id="run_wait_func"></a>

`run_wait()` is the most complex of all: it runs and waits for a program to
execute, possibly capturing its stdout: It can be called like this: `local
exit_code = Posix_File_System.run_wait(fs, program, args)` where `program` is a
string with the program name (to be searched on the `PATH`) and `args` a
sequential table (array) with the arguments to pass. It must return the exit
code of the program.

But it can also be called like this: `local result =
Posix_File_System.run_wait(fs, program, args, { capture_stdout = BOOL,
capture_stderr = BOOL })`. When this is done the result is no longer a number
but instead a table with the field `exit_code` and optionally `stdout` and/or
`stderr`. `exit_code` is the same than before and `stdout`/`stderr` are strings
with all of the standard output/error of the subprocess. `stdout` and `stderr`
are only set if their respective `capture_stdout` / `capture_stderr` option is
true.
