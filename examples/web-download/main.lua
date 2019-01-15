#!/usr/bin/env lua
--
-- This example is a MoonAgents rendition of the Lua coroutines example from
-- chapter 9 of "Programming in Lua" 3rd edition, by Roberto Ierusalimschy
-- (http://www.lua.org/pil/).
--
-- The 'download.lua' agent-script defines an agent that connects to the HTTP
-- port of an host and downloads a file. The system agent creates a few such
-- agents - one for each desired web page - that download the files concurrently.
-- Each agent downloads a chunk of data in its socket callback, which is executed
-- only when the socket is detected to be ready (within a trigger() callback).
--
-- As in the PIL3 example, the files are not saved anywhere, the application
-- just counts the number of downloaded bytes.
--

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

local ts = moonagents.now()
local system = moonagents.create_system(nil, "system", host, pages)

local n = 0
while n do n = moonagents.trigger(n==0) end

-- Note: if n==0 there are no scheduled signals, and since both our application and
--       the SDL system have nothing to do untless something arrives on the sockets
--       we can allow trigger() to block on select().

ts = moonagents.since(ts)
print(string.format("Elapsed %.1f seconds", ts))
