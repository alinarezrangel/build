local M = {}

-- Helper to invoke a function when a scope ends.
--
-- Returns a "closer" value with a `__close` meta-method, suitable for use with
-- Lua 5.4's `<close>` pragma. For example: `local _ <close> = M.closer(...)`.
--
-- Returns the "closer" value along with all of the other parameters.
--
-- `close` can be any callable value, it will be called when the "closer" gets
-- closed with 2 arguments: `value` and the error that led to the scope being
-- exited (or nil if the scope is exiting normally). For more details on the
-- second argument, see the documentation for Lua's `__close` meta-method.
--
-- An example of this usage is:
--
--    local _ <close> = M.closer(print, 1)
--    return true -- Prints 1, nil
--
--    local _ <close> = M.closer(print, 1)
--    error(2) -- Prints 1, 2
--
-- As a special case, `close` can also be a string, in that case it must begin
-- with either `.` or `:`, or a `-` followed by any of the previous.
--
-- If `close` begins with `.`, the rest of `close` is the name of the field on
-- `value` that will be called with the closing error or nil:
--
--    local T = {
--       n = "hi",
--       print = print,
--       mprint = function(self, ...)
--          print("Self=", self.n, "and", ...)
--       end,
--    }
--
--    local _ <close> = M.closer(".print", T)
--    return true -- Prints table T, nil
--
--    local _ <close> = M.closer(".print", T)
--    error(2) -- Prints table T, 2
--
-- Note how `M.closer(".METHOD", T)` is the same than `M.closer(T.METHOD, T)`.
--
-- The string can also begin with `:`, in this case the `value` is also passed
-- to the method:
--
--    local _ <close> = M.closer(":mprint", T)
--    return true -- Prints Self=hi and nil
--
--    local _ <close> = M.closer(":mprint", T)
--    error(2) -- Prints Self=hi and 2
--
-- If the string begins with `-`, the extra error argument is NOT passed:
--
--    local _ <close> = M.closer("-.print", T)
--    error(2) -- Prints table T, nil
--
--    local _ <close> = M.closer("-:mprint", T)
--    error(2) -- Prints Self=hi and nil
--
-- Any additional arguments are returned unchanged:
--
--    local _ <close>, x, y, z = M.closer(".print", T, 1, 2)
--    assert(x == T)
--    assert(y == 1)
--    assert(z == 2)
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

-- Replaces variable references inside the format string `tmpl` by the values
-- of the table `values`.
--
-- Each substring of the form `«[a-zA-Z0-9]+»` looks up the referenced key
-- (always as a string) in the table `values`, replacing the placeholder by the
-- table's value (converted to a string via the `tostring` function).
--
-- Returns the final string.
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

-- Escapes `str` so that, if surrounded by double quotes, it is a valid
-- GraphViz string literal.
function M.graphviz_string_escape(str)
   local function escape(c)
      return string.format("\\x%02X", string.byte(c, 1, 1))
   end
   return (string.gsub(str, "([^a-zA-Z0-9 _])", escape))
end

-- Determines if `prefix` is a prefix of `str`.
function M.is_prefix(str, prefix)
   return string.len(str) >= string.len(prefix)
      and string.sub(str, 1, string.len(prefix)) == prefix
end

-- Removes duplicate values from the sequential table `values`.
--
-- Values are kept as keys in a table for easy access, so elements in `values`
-- will be compared by identity.
--
-- Doesn't modify `values`, instead returns the new deduplicated table.
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

-- Removes a single trailing `\n` of `str`, if any exists.
function M.chomp_end(str)
   return (string.match(str, "^(.-)\n$")) or str
end

-- Collects and returns all the matches of `patt` in `str`.
--
-- `patt` must not have any captures.
--
-- For example: `M.split_match("a,b,c", "[^,]*")` will result in `{"a", "b",
-- "c"}`.
function M.split_match(str, patt)
   local res = {}
   for cap in string.gmatch(str, patt) do
      res[#res + 1] = cap
   end
   return res
end

-- Slice table.
--
-- Slices the sequential table `t` from `i` to `j`. `i` and `j` must be indexes
-- into `t`, `i` defaults to `1` and `j` defaults to the table length.
--
-- The table length is obtained from it's `n` field or `#t`. This makes this
-- function useful for tables returned by `table.pack` and tables created by
-- hand like `{1, 2, 3}`.
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

-- Reverse search `needle` in the string `haystack`.
--
-- Starts from `start`, which defaults to `string.len(haystack)`. This returns
-- the right-most occurrence of `needle` (which is NOT a pattern, but a normal
-- string, this is why `_plain` is in the name).
--
-- Returns the index of the starting character of the found match, or `nil` if
-- no match was found.
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

-- Returns the basename of a filename.
--
-- For example, the basename of `"/a/b/c/d"` is `"d"`, while the basename of
-- `"/a/b/c/d/"` is `""`.
--
-- For filenames with no path separators, such as `"sample-dir"`, returns the
-- filename unchanged.
--
-- See also `M.dirname`.
function M.basename(filename)
   local p = M.string_rfind_plain(filename, "/")
   if p then
      return string.sub(filename, p + 1, -1)
   else
      return filename
   end
end

-- Complement of `M.basename`, returns the dirname of a filename.
--
-- For example, the dirname of `"/a/b/c/d"` is `"/a/b/c/"`, while the dirname
-- of `"/a/b/c/d/"` is `"/a/b/c/d/"`.
--
-- For filenames with no path separators, such as `"sample-dir"`, returns `"."`.
--
-- WARNING: Note for this function keeps the trailing slash when returning the
-- dirname. This is unlike the dirname(3) function from the `<libgen.h>`
-- header, which removes them.
--
-- See also `M.basename`.
function M.dirname(filename)
   local p = M.string_rfind_plain(filename, "/")
   if not p then
      return "."
   else
      return string.sub(filename, 1, p)
   end
end

-- Returns a shallow copy of the table `tbl`.
--
-- The metatable is not copied.
function M.shallow_copy(tbl)
   local r = {}
   for k, v in pairs(tbl) do
      r[k] = v
   end
   return r
end

-- Parses a simple 3-component version number.
--
-- Despite it's name, it doesn't handle the full semver spec. yet.
--
-- Returns a table with 3 keys: `major`, `minor` and `patch`, each containing a
-- number.
function M.semver(semver)
   local m, n, p = string.match(semver, "^v?([0-9]+)%.([0-9]+)%.([0-9]+)$")
   return {
      major = tonumber(m),
      minor = tonumber(n),
      patch = tonumber(p),
   }
end

-- Determines if `path` is an absolute path.
function M.is_absolute(path)
   return path ~= "" and string.sub(path, 1, 1) == "/"
end

-- Removes unnecessary `..` components of a path.
--
-- Basically, takes any non-`..` component followed by a `..` and removes them
-- both.
--
-- WARNING: This function operates lexically, never interacting with the
-- filesystem. As such, it's results may differ from the real answer and it
-- should not be used for security-critical purposes. This function completely
-- ignores the existence of links and the fact that the filesystem is not a
-- tree but a graph.
--
-- Returns the simplified path.
--
-- BUG: This function doesn't remove unneeded `.` components.
function M.eager_resolve(path)
   local parts = M.split_match(path, "([^/]+)")
   local res = {}
   for i = 1, #parts do
      if #res > 0 and res[#res] ~= ".." and parts[i] == ".." then
         while res[#res] == "." do
            res[#res] = nil
         end
         res[#res] = nil
      else
         res[#res + 1] = parts[i]
      end
   end
   local rel = table.concat(res, "/")
   if M.is_absolute(path) then
      return "/" .. rel
   elseif rel == "" then
      return "."
   else
      return rel
   end
end

-- Joins several components to be inside of `base`.
--
-- For example: `M.eager_join("a/b", "c", "d")` will result in `"a/b/c/d"`.
--
-- WARNING: This function uses `M.eager_resolve`, see it's comment for a
-- security warning.
function M.eager_join(base, ...)
   return M.eager_resolve(base .. "/" .. table.concat({...}, "/"))
end

-- Flattens 1 level of `tbl`, a sequential table of sequential tables.
--
-- Doesn't modify `tbl`, instead returns the new flattened table.
function M.flatten(tbl)
   local res = {}
   for i = 1, #tbl do
      local t = tbl[i]
      for j = 1, #t do
         res[#res + 1] = t[j]
      end
   end
   return res
end

return M
