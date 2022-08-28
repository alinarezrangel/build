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

return M
