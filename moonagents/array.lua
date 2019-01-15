-- Note: this module is derived from LuaSocket's sample code, namely from the
-- newset() function in luasocket/samples/tinyirc.lua  (in LuaSocket 3.0-rc1).
-- See LuaSocket's license included in the thirdparty/ directory.
------------------------------------------------------------------------------
-- The set is mantained as a sequence, ie an array with indices 1 .. n_elements.
-- It can be efficiently traversed with index,element = ipairs().
-- User-defined info may be associated with each element, and retrieved with
-- the function array:info()

local function array()
   local self = {} -- the array itself
   local reverse = {}     -- value-to-index map
   local reverseinfo = {} -- value-to-info map
   -- setmetatable(reverse, { __gc = function(x) print("reverse collected",x) end })
   return setmetatable(self, 
      {
      __index = {
      ---------------------------------------------
        insert = function(self, value, info)
            if not reverse[value] then
                table.insert(self, value)
                reverse[value] = #self
            end
            if info then
               reverseinfo[value] = info
            end
        end,
      ---------------------------------------------
        remove = function(self, value)
            local index = reverse[value]
            if index then
                reverse[value] = nil
                reverseinfo[value] = nil
                local top = table.remove(self)
                if top ~= value then
                    reverse[top] = index
                    self[index] = top -- overwrites value
                end
            end
        end,
      ---------------------------------------------
        ispresent = function(self, value)
            return reverse[value]
        end,
      ---------------------------------------------
        info = function(self, value)
            return reverseinfo[value]
        end,
      ---------------------------------------------
        setinfo = function(self, value, info)
            local index = reverse[value]
            if index then reverseinfo[value] = info end
            return reverseinfo[value]
        end,
      },
      ---------------------------------------------
      __tostring = function(self)
            local s ={}
            for i,v in ipairs(self) do
               s[i] = string.format("%u %s %s",i,v,tostring(reverseinfo[v]))
            end   
            return (table.concat(s,"\n"))
         end,
      })
end

return array
