-- System agent script: system.lua

moonagents.global_functions()

local socket = require("socket")

local T1 = timer(10,"T1")
local player
local s, peerip, peerport, role


local function udprecv() -- socket 'read' callback
   -- get the UDP datagram and the sender's address
   local msg, fromip, fromport = s:receivefrom()
   log_print("received '%s' from %s:%s",msg,fromip,fromport)

   -- check that it is an expected message
   assert(msg == "PING" or msg == "PONG" or msg == "STOP")

   -- send the corresponding signal to the local player agent
   send({ msg, self_ }, player)
   if msg == "STOP" then
      stop()
   end
end


local function Start(ip, port, remip, remport, duration, ping_interval)
   peerip = remip
   peerport = remport
   role = ping_interval and "initiator" or "responder"
   
   log_print("starting %s at %s:%s (peer system is at %s:%s)", 
         role,ip,port,peerip,peerport)

   -- create a UDP socket and bind it to ip:port
   s = assert(socket.udp())
   assert(s:setsockname(ip,port))
   assert(s:setoption("reuseaddr",true))

   -- register the socket in the event loop
   socket_add(s, 'r', udprecv)

   -- create the player agent 
   player=create("player","pingpong.player", ping_interval) -- 

   -- send it the start signal (initiator side only)
   if role == "initiator" then
      send({ "START", self_ }, player )
   end

   -- start the overall timer
   timer_start(T1,now()+duration)

   next_state("Active")
end

local function Active_T1Expired()
   send({ "STOP" }, player )
   s:sendto("STOP",peerip,peerport)
   stop(function () socket_remove(s, 'r') s:close() end) 
end


local function Active_Any() 
   -- signal from local player, redirect signal name to peer system
   s:sendto(signame_,peerip,peerport)
end

start_transition(Start)
transition("Active","T1",Active_T1Expired)
transition("Active","*",Active_Any)

