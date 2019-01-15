#!/usr/bin/env lua
-- Coroutine version

local socket = require("socket")
local moonagents = require("moonagents") -- for now() and since() only

local host = "www.w3.org" -- web site where to download the pages
local pages = {           -- list of pages do download
 "/TR/html401/html40.txt",
 "/TR/2002/REC-xhtml1-20020801/xhtml1.pdf",
 "/TR/REC-html32.html",
 "/TR/2000/REC-DOM-Level-2-Core-20001113/DOM2-Core.txt"
}

local function receive(connection)
   connection:settimeout(0)
   local s, status, partial = connection:receive(2^10)
   if status == "timeout" then
      coroutine.yield(connection)
   end
   return s or partial, status
end

local function download(host, file)
   print(string.format("connecting to %s:80", host))
   local c = assert(socket.connect(host, 80))
   local count = 0  -- counts number of bytes read
   local request = string.format("GET %s HTTP/1.0\r\nhost: %s\r\n\r\n", file, host)
   print(string.format("retrieving '%s'", file))
   c:send(request)
   while true do
      local s, status = receive(c)
      count = count + #s
      if status  == "closed" then break end
   end
   c:close()
   print(file, count)
end

local tasks = {} -- list of all live tasks
   
local function get(host, file)
   -- create coroutine for a task
   local co = coroutine.wrap(function() download(host, file) end)
   -- insert it in the list
   table.insert(tasks, co)
end


local function dispatch ()
   local i  =  1
   local timedout =  {}
   while true do
      if tasks[i] == nil then   -- no other tasks?
         if tasks[1] == nil then break end -- list is empty? break the loop
         i = 1 -- else restart the loop
         timedout =  {}
      end
      local res = tasks[i]() -- run a task
      if not res then -- task  finished?
         table.remove(tasks,  i)
      else -- time  out
         i = i + 1
         timedout[#timedout+1] =  res
         if #timedout == #tasks then -- all tasks blocked?
            socket.select(timedout)       -- wait
         end
      end
   end
end

   
local ts = moonagents.now()
for _, page in ipairs(pages) do
   get(host, page)
end
dispatch()
ts = moonagents.since(ts)
print(string.format("Elapsed %.1f seconds", ts))

