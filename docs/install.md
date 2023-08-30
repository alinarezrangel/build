---
title: Installation guide
---

# How to install `build.lua` #

## Dependencies ##

- [Lua 5.4](https://lua.org).
- [The `luaposix` library](https://github.com/luaposix/luaposix/).
- [`shell-quote`(1p)](https://manpages.debian.org/buster/libstring-shellquote-perl/shell-quote.1p.en.html).

## Installation with LuaRocks ##

Clone [this repository](https://github.com/alinarezrangel/build) and run
`luarocks --lua-version 5.4 install rockspecs/build-dev-1.rockspec`.

## Manual installation ##

Move the `build/` directory to somewhere in your `LUA_PATH` and copy the files
in the `programs/` directory without their `.lua` extension (so for example,
`build.make.lua` becomes `build.make`) to any directory in your
`PATH`. Remember to make these files executable (with `chmod +x`).
