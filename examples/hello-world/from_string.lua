#!/usr/bin/env lua
-- Alt. main for Hello World application, where the script agent is
-- passed as a string containing the script code.

local moonagents = require("moonagents")

moonagents.log_open("example.log")
moonagents.trace_enable(true)

local script = [[
moonagents.global_functions()

-- Just to make things a little interesting, the salute is given with a delay.
local delay = 1.2 -- seconds
local T = timer(delay,"T_EXPIRED")

local function Start()
   print("Please, wait "..delay.." seconds ...")
   timer_start(T)
   next_state("Waiting")
end

local function TExpired()
   print("... Hello World!")
   stop()
end

start_transition(Start)
transition("Waiting", "T_EXPIRED", TExpired)
]]

-- Create the system agent:
local system = moonagents.create_system_s("HelloSystem", script)

-- Event loop:
while moonagents.trigger() do end

