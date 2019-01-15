-- agent.lua

moonagents.global_functions()

local T = timer(1, "T_EXPIRED")
local exptime

local function Active_TExpired() 
   local err = now() - exptime
   send({"RESULT", err }, parent_)
   stop()
end

local function Start(maxduration) 
   local duration = math.random()*maxduration -- random between 0 and maxduration
   timer_modify(T, duration)
   exptime = timer_start(T, now()+duration)
   next_state("Active")
end

start_transition(Start)
transition("Active","T_EXPIRED",Active_TExpired)

