-- agent.lua

moonagents.global_functions()

local exptime

local function Active_Received() 
   local err = now() - exptime
   send({"RESULT", err }, parent_)
   stop()
end

local function Start(maxduration) 
   local duration = math.random()*maxduration -- random between 0 and maxduration
   exptime = now()+duration
   send_at({"RECEIVED"}, self_, exptime)
   next_state("Active")
end

start_transition(Start)
transition("Active","RECEIVED", Active_Received)

