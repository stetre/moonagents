#!/usr/bin/env lua
-- Remote functions example.
--
-- This example uses the remote functions construct to implement
-- a centralized database-agent that serves other agents.
--
-- The database.lua script defines the database agent, while the
-- user.lua script defines a user agent that locates the database by
-- its name, and uses the 'get' and 'set' functions exported by it.

local moonagents= require("moonagents")

-- get the no. of entries in the database
local n_entries = tonumber(({...})[1]) or 1000 

moonagents.log_open("example.log")
moonagents.trace_enable(true)

local system = moonagents.create_system(nil, "system", n_entries)

while moonagents.trigger() do end
