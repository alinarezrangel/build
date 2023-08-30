# `build.lua` -- A build system in Lua #

Implements the build system from the amazing [Build Systems A La
Carte](https://www.microsoft.com/en-us/research/publication/build-systems-la-carte/).

## More information ##

See the [README file on the `docs/` directory](docs/README.md).

## Building ##

To build the HTML version of the documentation, do `make` or `make
all_docs`. `make TAGS` will generate an etags file for the Lua sources.

## Installation ##

To install with luarocks:

```sh
luarocks --lua-version 5.4 install rockspecs/build-dev-1.rockspec
```
