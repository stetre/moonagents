-- Agent script: client.lua

moonagents.global_functions()

local socket = require("socket")

local timeout = 10
local interval = 1 -- ping interval
local npings = 3 -- no. of pings
local counter = 0 -- sent pings
local T1 = timer(interval,"T1") -- ping timer
local T2 = timer(timeout,"T2") -- error timer
local s, srvip, srvport

local function Stop()
   if s then
      log("%s: closing %s:%s",name_,s:getsockname())
      --s:shutdown()
      socket_remove(s, 'r')
      s:close()
   end
   stop()
end

local function Failure(reason)
   log_print("failure '%s'",reason)
   send({ "FAILURE", reason }, parent_)
   Stop()
end

local function Send() -- socket 'send' callback
   log("@@")
end

local function Ping()
   counter = counter + 1
   s:send("ping\n")
   if counter < npings then timer_start(T1) end
   timer_start(T2)
end

local function Receive(s) -- socket 'read' callback
   local data, err = s:receive()
   log("%s: received '%s' from %s:%s", name_, data, s:getpeername())
   if data ~= "pong" then return end -- ignore
   if counter == npings then
      send({ "SUCCESS" }, parent_)
      Stop()
   end
end

local function Start(ip, port, n, int, t)
   local ok, errmsg
   srvip = ip
   srvport = port 
   npings = n or npings
   interval = int or interval
   timeout = t or timeout
   
   timer_modify(T1,interval)
   timer_modify(T2,timeout)
   
   
   log("%s: connecting to %s:%u", name_, ip, port)
   s , errmsg = socket.connect(ip, port)
   if not s then Failure(errmsg) return end
   log("%s: connected (%s:%u)", name_, s:getsockname())
   ok, errmsg = s:setoption("reuseaddr",true)
   if not ok then Failure(errmsg) return end
   socket_add(s, 'r', Receive)
   --socket_add(s, 'w', Send)
   Ping()
   next_state("Active")
end

local function Active_T1()
   Ping()
end

function Active_T2()
   Failure("T2 expired")
end

start_transition(Start)
transition("Active","T1", Active_T1)
transition("Active","T2", Active_T2)

