#!/usr/bin/env lua
-- Alternative main with the agent scripts passed as strings.

local moonagents = require("moonagents")

local host = "www.w3.org" -- web site where to download the pages
local pages = {           -- list of pages do download
 "/TR/html401/html40.txt",
 "/TR/2002/REC-xhtml1-20020801/xhtml1.pdf",
 "/TR/REC-html32.html",
 "/TR/2000/REC-DOM-Level-2-Core-20001113/DOM2-Core.txt"
}

--[[ Uncomment to see the interleaved execution of agents in traces
moonagents.log_open("example.log")
moonagents.trace_enable(true)
--]]


local system_script = [=[

local download_script = [[
moonagents.global_functions()

local socket = require("socket")

local nread = 0 -- no of bytes read
local block_size = 1024

local function Callback(c) -- socket 'read' callback
   local s, status, partial = c:receive(block_size)
   -- print(partial) -- chunk of data
   if status == "closed" then
      if partial then nread = nread + #partial end
      socket_remove(c, 'r')
      c:close()
      log_print("%s: read %u bytes (finished)", name_, nread)
      return stop()
   end
   s = s or partial
   nread = nread + #s
   log("%s: read %u bytes", name_, nread)
end

local function Start(host, file)
   log_print("%s: connecting to %s:80", name_, host)
   local c = assert(socket.connect(host, 80))

   socket_add(c, 'r', Callback)

   log_print("%s: retrieving '%s'", name_, file)
   c:send("GET " .. file .." HTTP/1.0\r\n\r\n")

   next_state("Downloading")
end

start_transition(Start)
]]

moonagents.global_functions()

local function Start(host, pages)
   log_print("%s: Creating agents", name_)
   for _,file in ipairs(pages) do
      create_s(nil, download_script, host, file)
   end
   stop()
end

start_transition(Start)
]=]

local ts = moonagents.now()
local system = moonagents.create_system_s(nil, system_script, host, pages)

local n = 0
while n do n = moonagents.trigger(n==0) end

ts = moonagents.since(ts)
print(string.format("Elapsed %.1f seconds", ts))

