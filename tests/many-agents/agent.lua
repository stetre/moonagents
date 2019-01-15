-- agent.lua

moonagents.global_functions()

local delay

local function Stop() 
   if state_ == "Stopping" then
      send({ "STOPPING", delay }, sender_)
      stop()
   else
      next_state("Stopping")
   end
end

local function AtReturn(dly)
   delay = dly
   Stop()
end

start_transition(function() 
   procedure(AtReturn, nil, "procedure")
   next_state("Active")
end)

transition("Active","STOP", function() Stop() end)
transition("Stopping","STOP", function() Stop() end)

