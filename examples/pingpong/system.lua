-- System agent script: system.lua

moonagents.global_functions()

local T1 = timer(10,"T1_EXPIRED")
local player1, player2

local function Start(duration, interval)
   local duration = duration or 10
   local interval = interval or 1
   log_print("%s: duration=%g s, interval=%g s",name_,duration, interval)

   player1=create("player1","player",interval)
   player2=create("player2","player")

   send({"START", player2}, player1)
   timer_start(T1,now()+duration)

   next_state("ACTIVE")
end

local function Active_T1Expired()
   send({"STOP"}, player1)
   send({"STOP"}, player2)
   stop()
end

start_transition(Start)
transition("ACTIVE","T1_EXPIRED",Active_T1Expired)

