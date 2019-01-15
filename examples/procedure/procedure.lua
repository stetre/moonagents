-- Procedure script: procedure.lua

moonagents.global_functions()

local cnt = 0

local function Waiting_Any()
   -- notice that sender_ is not self_ but caller_
   log_print("%s: received from %u: '%s'",name_, sender_, signal_[2])
   cnt = cnt +1
   -- save the signal for the caller:
   save()
end

local function Waiting_Return()
   log_print("%s: received %s from %u",name_,signame_,sender_)
   -- return from procedure, with return values:
   return procedure_return("received verses",cnt)
   -- no code after procedure_return()
end


local function Init(...) 
   log_print("%s: Init(%s)",name_,table.concat({...},","))
   -- time-triggered signals are handy in procedures because
   -- procedures can not create timers...
   send_at({ "RETURN" }, self_, now() + 5)
   next_state("Waiting")
end


start_transition(Init)
transition("Waiting","RETURN",Waiting_Return)
transition("Waiting","*",Waiting_Any)

