-- This procedure sends a signal to itself, computes the
-- time it takes for the signal to traverse the scheduler,
-- and returns that value to the caller agent.

moonagents.global_functions()

local sendtime

local function Start()
   sendtime = send({ "RETURN" }, self_)
   next_state("Active")
end

local function Active_Return()
   local delay = recvtime_ - sendtime
   procedure_return(delay)
end

start_transition(Start)
transition("Active", "RETURN", Active_Return)
transition("Any", "*", function() save() end)
default_state("Any")

