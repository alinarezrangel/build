local M = {}

function M.empty()
   return {}
end

function M:put(key, value)
   self[key] = value
end

function M:get(key)
   -- XXX: Should raise an error for non-existing keys
   return self[key]
end

function M:try_get(key)
   return self[key]
end

return M
