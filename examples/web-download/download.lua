-- Agent script: download.lua

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

