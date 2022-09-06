---
title: build.stores.table
libbar: yes
---

# `build.stores.table` #

A structure. The `empty()` function creates a new, empty table store and
returns it.

Both the keys and the values can be any value.

## Usage ##

```lua
local Table = require "build.stores.table"
```

## Example ##

```lua
local Table = require "build.stores.table"

local store = Table.empty()
Table.put(store, "hola", 1)
assert(Table.get("hola") == 1)
```

## See Also ##

  * [`build.stores.json`](stores-json.md).
