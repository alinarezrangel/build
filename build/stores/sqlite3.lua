local M = {}

local utils = require "build.utils"
local lsqlite3 = require "lsqlite3"

function M.unsafe_create(conn, table_name, table_name_sql)
   return {
      connection = conn,
      table_name = table_name,
      table_name_sql = table_name_sql,
   }
end

M.CREATE_TABLE_SQL = [[
create table if not exists «TABLE» (store_key primary key, store_value);
]]

function M.create_with_connection(conn, table_name)
   assert(string.match(table_name, "^[a-zA-Z_][a-zA-Z_0-9]*$"), "invalid table name")
   local table_name_sql = '"' .. table_name .. '"'
   local sql = utils.template(M.CREATE_TABLE_SQL, { TABLE = table_name_sql })
   conn:execute(sql)
   return M.unsafe_create(conn, table_name, table_name_sql)
end

function M.create_in_memory(table_name)
   table_name = table_name or "main_store"
   return M.create_with_connection(lsqlite3.open_memory(), table_name)
end

function M:try_get(key)
   local query = string.format("select store_value from %s where store_key = ?", self.table_name_sql)
   local _prepared <close>, prepared = utils.closer("-:finalize", assert(self.connection:prepare(query)))
   assert(prepared:bind_values(key))
   local res, found = nil, false
   for row in prepared:nrows() do
      assert(not found, "consistency error: multiple values for the same key")
      res = row.store_value
      found = true
   end
   return res, found
end

function M:get(key)
   local val, found = M.try_get(self, key)
   assert(found, string.format("could not find key '%s'", key))
   return val
end

function M:put(key, value)
   local query = string.format("insert into %s (store_key, store_value) values (?, ?)", self.table_name_sql)
   local _prepared <close>, prepared = utils.closer("-:finalize", assert(self.connection:prepare(query)))
   assert(prepared:bind_values(key, value))
   for row in prepared:nrows() do end -- Just execute the query
end

return M
