
local socket = require("socket")
local moonagents = require("moonagents")

local port = tonumber(({...})[1]) or 8080 -- server port
local n = tonumber(({...})[2]) -- no. of tests (nil->max)
local npings = tonumber(({...})[3]) or 3
local ping_int = tonumber(({...})[4]) or 1
local timeout = tonumber(({...})[5]) or 10 -- timeout
local rep = tonumber(({...})[6]) or 3 -- no. of repetitions
local ip = "127.0.0.1"

--moonagents.log_open("test.log")
--moonagents.trace_enable(true)

local ts = moonagents.now()
print("hello world")
moonagents.log_print("print('hello world') executed in %.0f us",moonagents.since(ts)*1e6)
moonagents.log_print("maximum number of file descriptors is %u",socket._SETSIZE)

max = math.floor(socket._SETSIZE/2) - 2
if not n or n > max then 
   n = max 
   moonagents.log_print("limiting n to %u",n)
end

local function ReceiveCb(sig, srcpid)
   -- { "RESULTS", ncli, n_success, n_failure }
   local signame, m, nok, nko = table.unpack(sig)
   if signame == "RESULTS" then
      io.write(string.format("%.0f succeeded, %.0f failed (%.3f s)\n",nok, nko, moonagents.since(ts)))
      io.flush()
   end
end

moonagents.set_receive_callback(ReceiveCb)

for k=1,rep do
   io.write(string.format("%u - running %u tests.....",k,n)) io.flush()
   ts = moonagents.now()
   local system = moonagents.create_system(nil,"system",n,ip,port,npings,ping_int,timeout)
   while moonagents.trigger() do end
end
