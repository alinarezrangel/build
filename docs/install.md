# How to install `build.lua` #

## Dependencies ##

- Lua 5.4.
- [The `luaposix` library](https://github.com/luaposix/luaposix/).
- [`shell-quote`(1p)](https://manpages.debian.org/buster/libstring-shellquote-perl/shell-quote.1p.en.html).

## Installation with LuaRocks ##

Clone [this repository](https://github.com/alinarezrangel/build) and run
`luarocks --lua-version 5.4 install rockspecs/build-dev-1.rockspec`.

## Manual installation ##

Move the `build/` directory to somewhere in your `LUA_PATH` and copy
`programs/build.make.lua` as `build.make` to somewhere in your `PATH`. Remember
to make `build.make` an executable (with `chmod +x`).
