#!/usr/bin/env lua
-- Priority signals example.
-- 
-- This example uses priority signals. The application first configures
-- the number of priority levels to 3 (MoonAgents by default has only 1
-- level of priority, plus the 'normal' level), then creates the system
-- agent, which sends a few signals with different priorities to itself
-- just to see their order of arrival.

local moonagents = require("moonagents")

moonagents.log_open("example.log")
moonagents.trace_enable(true)

-- Set the number of priority levels:
moonagents.set_priority_levels(3)

local system = moonagents.create_system(nil,"system")

while moonagents.trigger() do end
