#!/usr/bin/env lua
-- Procedure example.
--
-- This example shows a procedure call. It also uses the save() and
-- restore() functions, and time-triggered signals.
--
-- The system agent creates a caller agent with the caller.lua script, and
-- then sends some signals to it. The caller agent calls the procedure defined
-- in the procedure.lua script. While the procedure is executing, all signals
-- sent to the caller are redirected to the procedure, which save()s them.
-- When the procedure returns, all the signals saved by it are automatically
-- moved in the caller's 'saved queue'. The caller restore()s and receives
-- them, and then it receives other signals newly sent to it by the system
-- agent.

local moonagents = require("moonagents")

moonagents.log_open("example.log")
moonagents.trace_enable(true)

local system = moonagents.create_system("System","system")

while moonagents.trigger() do end
