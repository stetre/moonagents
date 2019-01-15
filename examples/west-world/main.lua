#!/usr/bin/env lua
-- An implementation with MoonAgents of the West World example from
-- chapter 2 of Mat Buckland's book "Programming Game AI by Example".

local moonagents = require("moonagents")

local duration = tonumber(({...})[1]) or 20 -- seconds
local interval = tonumber(({...})[2]) or .8 -- seconds

moonagents.log_open("example.log")
moonagents.trace_enable(true)
-- Comment out this if your terminal does not support ANSI color escape sequences, 
-- or if you don't want colored text:
moonagents.text_style_enable(true)

local system = moonagents.create_system("WestWorld","system", duration, interval)

while moonagents.trigger() do end

