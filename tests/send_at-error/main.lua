#!/usr/bin/env lua
local moonagents = require("moonagents")


local maxdur = tonumber(({...})[1]) or 2
local n = tonumber(({...})[2]) or 100
local rep = tonumber(({...})[3]) or 3

--moonagents.log_open("test.log")
--moonagents.trace_enable(true)

local ts = moonagents.now()
print("hello world")
ts = moonagents.since(ts)*1e6
print(string.format("print('hello world') executed in %.0f us",ts))

local f = function(...) return ... end
local ts = moonagents.now()
ts = moonagents.since(ts)*1e6
for i=1, n do f(n) end
print(string.format("nothing executed in %.3f us",ts))

local ts = moonagents.now()
ts = moonagents.since(ts)*1e6
print(string.format("nothing executed in %.3f us",ts))

moonagents.set_receive_callback(function(sig, srcpid)
   if sig[1] == "RESULTS" then -- { "RESULTS", n_agents, elapsed, mean,var,min,max }
      local signame, n_agents, elapsed, mean,var,min,max = table.unpack(sig)
      io.write(string.format("test executed in %.1f s, average arrival error is %.0f us\n", elapsed, mean*1e6))
      print(string.format("mean=%.0f var=%.0f, min=%.0f, max=%.0f", mean*1e6,var*1e6,min*1e6,max*1e6))
   end
end)

collectgarbage()
collectgarbage('stop')
local trigger = moonagents.trigger
for k=1,rep do
   io.write(string.format("%u - creating %u agents.....",k,n))
   local system = moonagents.create_system("System","system", maxdur, n)
   while trigger() do collectgarbage('step') end
end

