#!/usr/bin/env lua
local moonagents = require("moonagents")

local n = tonumber(({...})[1]) or 100
local rep = tonumber(({...})[2]) or 3

--moonagents.log_open("test.log")
--moonagents.trace_enable(true)
--moonagents.trace_enable(true)

local ts = moonagents.now()
print("hello world")
print(string.format("print('hello world') executed in %.0f us",moonagents.since(ts)*1e6))

moonagents.set_receive_callback(function(sig, srcpid)
   if sig[1] == "RESULTS" then -- { "RESULTS", n_agents, elapsed, mean,var,min,max }
      local signame, n_agents, elapsed, mean, var, min, max = table.unpack(sig)
      --io.write(string.format("test executed in %.1f s, average signal delay is %.0f us\n", elapsed, mean*1e6))
      io.write(string.format("done (%.1f s), signal delay: mean=%.0f, var=%.0f min=%.0f max=%.0f us\n",
                              elapsed, mean*1e6, var*1e6, min*1e6, max*1e6))
   end
end)

collectgarbage()
collectgarbage('stop')
local trigger = moonagents.trigger
for k=1,rep do
   io.write(string.format("%u - creating %u agents... ",k,n))
   local system = moonagents.create_system("System","system", n)
   while trigger() do collectgarbage('step') end
-- Alternatives:
-- while trigger() do collectgarbage() end  -- minimizes memory, but slower (4x to 5x)
-- while trigger() do end; collectgarbage() -- faster, but uses more memory
end

