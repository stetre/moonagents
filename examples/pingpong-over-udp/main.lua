-- Ping Pong over UDP
--
-- This example reuses the player.lua script from the pingpong example.
--
-- This time the two player agents exchanging pings and pongs are
-- created in two different systems (i.e. two different OS processes)
-- and communicate over UDP. The system agent of each side translates
-- messages received on the socket into signals to be forwarded to
-- the local player agent, and viceversa.
--
-- To run the example there are two shell scripts, `responder` and
-- `initiator`, to be executed in this order in two different shells.
--
-- Notice how the shell scripts define the MOONAGENTS environment
-- variable so that MoonAgents can find the player.lua script in the
-- directory containing the pingpong example (this is needed in this
-- example because the script is not in the current directory).

local moonagents = require("moonagents")

local port = tonumber(({...})[1]) or 8080
local duration = tonumber(({...})[2]) or 10 -- seconds
local interval = tonumber(({...})[3]) -- (or nil) seconds 

local role = interval and "initiator" or "responder"

local ip = "127.0.0.1"
local remip = ip
local remport = port+1

if role == "initiator" then --swap UDP address
   port, remport = remport, port
   ip, remip = remip, ip
end

moonagents.log_open(string.format("%s.log",role))
moonagents.trace_enable(true)

local system = moonagents.create_system("system","system",ip,port,remip,remport,duration,interval)

while moonagents.trigger() do end

