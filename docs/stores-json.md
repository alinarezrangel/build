---
title: build.stores.json
libbar: yes
---

# `build.stores.json` #

The keys must be strings. The values can be any value.

It has two additional functions: `open(filename)` returns a new JSON store,
reading it from the file `filename` if it exists or creating a new empty store
otherwise. On the other hand, `save(json_store)` will write back the JSON store
to it's original file.

This store **is not safe against concurrent modification**: if two processes
try to open the same file with a JSON store and modify it, when saving one of
the two will overwrite the other's changes.

## Usage ##

```lua
local JSON_Table = require "build.stores.json"
```

## Example ##

```lua
local Table = require "build.stores.json"

local store = Table.open "store.json"
print("previous random: ", Table.get("hola"))
Table.put(store, "hola", math.random())
print("current random: ", Table.get("hola"))
Table.save(store)
```

## See Also ##

  * [`build.stores.table`](stores-table.md).
