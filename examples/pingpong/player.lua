-- Agent script: player.lua

moonagents.global_functions()

local interval = 5
local T = timer(interval,"T_EXPIRED")
local peer

local function PrintSignal()
   log_print("%s: Received %s from %u",name_,signame_,sender_)
end

local function Init(ping_interval)
   interval = ping_interval or interval
   next_state("Waiting")
end

local function Waiting_Start()
   PrintSignal()
   peer = signal_[2]
   timer_start(T, now()+interval)
   next_state("Initiator")
end   

local function Initiator_TExpired()
   send({ "PING", self_ }, peer)
   timer_start(T, now()+interval)
end

local function Initiator_Pong()
   PrintSignal()
end   

local function Waiting_Ping()
   PrintSignal()
   send({ "PONG", self_ }, signal_[2])
   next_state("Responder")
end   

local Responder_Ping = Waiting_Ping

local function Any_Stop()
   PrintSignal()
   stop()
end


start_transition(Init)
transition("Waiting", "START", Waiting_Start)
transition("Waiting", "PING", Waiting_Ping)
transition("Initiator", "T_EXPIRED", Initiator_TExpired)
transition("Initiator", "PONG", Initiator_Pong)
transition("Responder", "PING", Responder_Ping)
transition("Any", "STOP", Any_Stop)
default_state("Any")

