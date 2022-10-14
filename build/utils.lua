local M = {}

function M.closer(close, value, ...)
   local closef
   if type(close) == "string" then
      assert(close ~= "", "cannot pass the empty string to closer()")
      local ignore_error = false
      if string.sub(close, 1, 1) == "-" then
         ignore_error = true
         close = string.sub(close, 2, -1)
      end
      assert(close ~= "", "cannot pass the string '-' to closer()")
      local method_closef
      if string.sub(close, 1, 1) == ":" then
         local method = string.sub(close, 2, -1)
         method_closef = function(_, error_or_nil)
            return value[method](value, error_or_nil)
         end
      else
         assert(string.sub(close, 1, 1) == ".",
                "only two syntaxes are allowed as a string to closer(): '.' and ':', instead got " + close)
         local method = string.sub(close, 2, -1)
         method_closef = function(_, error_or_nil)
            return value[method](error_or_nil)
         end
      end
      if ignore_error then
         closef = function()
            return method_closef()
         end
      else
         closef = method_closef
      end
   else
      closef = function(_, error_or_nil)
         return close(value, error_or_nil)
      end
   end

   return setmetatable({}, { __close = closef }), value, ...
end

function M.template(tmpl, values)
   local function replace(name)
      if name == "" then
         return "«»"
      else
         return tostring(values[name])
      end
   end
   return string.gsub(tmpl, "«([a-zA-Z0-9_]*)»", replace)
end

function M.graphviz_string_escape(str)
   local function escape(c)
      return string.format("\\x%02X", string.byte(c, 1, 1))
   end
   return (string.gsub(str, "([^a-zA-Z0-9 _])", escape))
end

function M.is_prefix(str, prefix)
   return string.len(str) >= string.len(prefix)
      and string.sub(str, 1, string.len(prefix)) == prefix
end

function M.remove_duplicates(values)
   local seen = {}
   local new = {}
   for i = 1, #values do
      if not seen[values[i]] then
         new[#new + 1] = values[i]
      end
      seen[values[i]] = true
   end
   return new
end

function M.chomp_end(str)
   return (string.match(str, "^(.-)\n$")) or str
end

function M.split_match(str, patt)
   local res = {}
   for cap in string.gmatch(str, patt) do
      res[#res + 1] = cap
   end
   return res
end

function M.table_sub(t, i, j)
   local len = t.n or #t
   i = i or 1
   j = j or len
   local res, w = {}, 1
   for k = i, j do
      res[w] = t[k]
      w = w + 1
   end
   return res
end

function M.string_rfind_plain(haystack, needle, start)
   start = start or string.len(haystack)
   -- Extremely inefficient.
   for i = start - string.len(needle) + 1, 1, -1 do
      if string.sub(haystack, i, i + string.len(needle) - 1) == needle then
         return i
      end
   end
   return nil
end

function M.basename(filename)
   local p = M.string_rfind_plain(filename, "/")
   if p then
      return string.sub(filename, p + 1, -1)
   else
      return filename
   end
end

function M.dirname(filename)
   local p = M.string_rfind_plain(filename, "/")
   if not p then
      return "."
   else
      return string.sub(filename, 1, p)
   end
end

function M.shallow_copy(tbl)
   local r = {}
   for k, v in pairs(tbl) do
      r[k] = v
   end
   return r
end

function M.semver(semver)
   local m, n, p = string.match(semver, "^v?([0-9]+)%.([0-9]+)%.([0-9]+)$")
   return {
      major = tonumber(m),
      minor = tonumber(n),
      patch = tonumber(p),
   }
end


function M.eager_resolve(path)
   local parts = M.split_match(path, "([^/]+)")
   local res = {}
   for i = 1, #parts do
      if #res > 0 and res[#res] ~= ".." and parts[i] == ".." then
         res[#res] = nil
      else
         res[#res + 1] = parts[i]
      end
   end
   return table.concat(res, "/")
end

function M.eager_join(base, path)
   return M.eager_resolve(base .. "/" .. path)
end

return M
