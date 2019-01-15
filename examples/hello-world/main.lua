#!/usr/bin/env lua
-- Hello World application

local moonagents = require("moonagents")

moonagents.log_open("example.log")
moonagents.trace_enable(true)

-- Create the system agent:
local system = moonagents.create_system("HelloSystem","agent")

-- Event loop:
while moonagents.trigger() do end

