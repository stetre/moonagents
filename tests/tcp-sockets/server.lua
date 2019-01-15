-- Agent script: server.lua

moonagents.global_functions()

local socket = require("socket")

local s 
local cli = {} 

local function Close(c)
   log("%s: %s:%s disconnected", name_, c:getpeername())
   socket_remove(c, 'r')
   c:close()
   cli[c]=nil
end

local function Stop()
   if s then
      socket_remove(s, 'r')
      s:close()
   end
   stop()
end

local function Failure(reason)
   log_print("failure '%s'",reason)
-- send({ "FAILURE", reason }, parent_)
   Stop()
   os.exit()
end


local function Receive(c)
   local data, err = c:receive()
   log("%s: received '%s' from %s:%s",name_, data, c:getpeername())
   if data ~= "ping" then return end -- ignore
   c:send("pong\n")
end


local function Accept(s)
   local c, err = s:accept()
   if not c then
      log(err)
      return
   end
   log("%s: %s:%s connected", name_, c:getpeername())
   socket_add(c, 'r', Receive)
   cli[c] = true
end


local function Start(ip, port, backlog)
   local ok, err
   
   log("%s: opening server %s:%u",name_, ip,port)
   s , err = socket.bind(ip,port)
   if not s then Failure(err) return end
   ok, err = s:setoption("reuseaddr",true)
   if not ok then Failure(err) return end
   socket_add(s, 'r', Accept)

   next_state("Active")
end


local function Active_Stop()
   log("%s: closing server %s:%u",name_,s:getsockname())
   socket_remove(s, 'r')
   s:close()
   for c in pairs(cli) do Close(c) end
   Stop()
end

start_transition(Start)
transition("Active","STOP", Active_Stop)

