-- System agent: system.lua

moonagents.global_functions()

local function Send(n)
-- Sends a signal named "LEVEL<n>" to itself, with priority n.
-- If n=nil, the signal is named 'NORMAL' and sent without priority.
   if not n then
      send({ string.format("NORMAL") }, self_)
   else
      send({ string.format("LEVEL%u",n) }, self_, n)
   end
end

local function Start()
   -- Send to self a few signal with different priorities.

   -- This has normal priority (no priority at all):
   Send()
   
   -- These also have no priority because their level is higher
   -- than the configured number (=3) of priority levels:
   Send(5) 
   Send(4) 

   -- These have increasing priorities:
   Send(3) -- lowest (> no priority)
   Send(2) -- medium priority
   Send(1) -- highest (level 1 is always the highest)

   -- This has priority 1, imposed by the receiver with
   -- the input_priority() function (see below):
   Send(6)

   -- Finally, this also has no priority, and since signals with
   -- the same priority are dispatched first-in-first-out, it 
   -- should arrive last:
   send({ "STOP" }, self_ ) 

   -- Summarizing, the order of arrival should be the following:
   print("expected order of arrival: LEVEL1, LEVEL6, LEVEL2, LEVEL3, NORMAL, LEVEL5, LEVEL4, STOP")

   next_state("Active")
end

function Received()
   print(string.format("received %s",signame_))
end

start_transition(Start)
transition("Active","*", Received)
transition("Active","STOP", function () Received() stop() end)
-- set the priority of 'LEVEL6' input signals to 1 (i.e. highest priority):
input_priority("LEVEL6",1)

