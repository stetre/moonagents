#!/usr/bin/env lua
-- Ping Pong example, main script.
--
-- In this example, the system agent creates two processes with
-- the same agent script (player.lua), and sends a START signal
-- to one of them instructing it to start pinging the other, which
-- in turns pongs in response.
-- The system agent also sets a timer to control the duration of
-- the ping-pong exchange, and at the timer expiry it sends a STOP
-- signal to both processes, and stops itself.

local moonagents = require("moonagents")

local duration = tonumber(({...})[1]) or 10 -- seconds
local interval = tonumber(({...})[2]) or 1 -- seconds

moonagents.log_open("example.log")
moonagents.trace_enable(true)

local system = moonagents.create_system("System","system",duration,interval)

while moonagents.trigger() do end

