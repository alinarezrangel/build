local M = {}

local json = require "build.third-party.rxi-json"

local function read_json(filename, def)
   local handle <close> = io.open(filename, "rb")
   if not handle then
      return def
   else
      return json.decode(handle:read "a")
   end
end

local function write_json(filename, obj)
   local handle <close> = io.open(filename, "wb")
   handle:write(json.encode(obj))
end

function M.open(filename)
   return { filename = filename, base = read_json(filename, { keys = {}, values = {} }) }
end

function M:try_get(key)
   return self.base.values[key], self.base.keys[key]
end

function M:get(key)
   assert(self.base.keys[key])
   return self.base.values[key]
end

function M:put(key, value)
   self.base.values[key] = value
   self.base.keys[key] = true
end

function M:save()
   write_json(self.filename, self.base)
end

return M
