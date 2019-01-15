#!/usr/bin/env lua
local moonagents = require("moonagents")

local maxlevels = tonumber(({...})[1]) or 3

moonagents.log_open("test.log")
moonagents.trace_enable(true)
local system = moonagents.create_system(nil, "system", maxlevels)
while moonagents.trigger() do end
