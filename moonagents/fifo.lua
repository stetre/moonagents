
local function fifo()
   local self, first, last = {}, 0, -1
   return setmetatable(self, {
      __index = {

      push = function(self,val)
         last = last+1
         self[last] = val
      end,
--[[
      pushprio = function(self,val)
         first = first-1
         self[first] = val
      end,
--]]

      pop = function(self)
         if first > last then return nil end
         local val = self[first]
         self[first] = nil
         first = first + 1
         if first > last then first = 0 last = -1 end -- reset 
         return val
      end,  

--[[
      peek = function(self)
         if first > last then return nil end
         return self[first]
      end,

      moveto = function(self, dstfifo)
      -- pops all values and pushes them in dstfifo
         local val = self:pop()
         while val do
            dstfifo:push(val) 
            val = self:pop()
         end
      end,
--]]

      count = function(self)
         return last - first + 1
      end,

      isempty = function(self)
         return first > last
      end,
      
      }, -- __index

      __pairs = function(self)
         local function iterator(self, i)
            local v = self[i]
            if v then return i+1, v end
         end
         return iterator, self, first
      end,

      __tostring = function(self)
         local s = {}
         local i = first
         while i <= last do
            s[#s+1] = self[i]
            i = i+1
         end
         return table.concat(s," ")
      end,

--    __gc = function(self) print("collected")  end,

   })
end

return fifo
