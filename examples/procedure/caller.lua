-- Agent script: caller.lua

moonagents.global_functions()

local function AtReturn(...)
   log_print("AtReturn(%s)",table.concat({...},","))
   restore()
end

local function Active_Start()
   log_print("%s: received %s", name_, signame_)
   -- call the procedure, passing it some parameters
   procedure(AtReturn, "Procedure", "procedure", "hello",1,2,3)
end

local function Active_Stop()
   log_print("%s: received %s", name_, signame_)
   stop()
end

local function Received()
   log_print("%s: received from %u: '%s'",name_, sender_, signal_[2])
end

local function Init() 
   next_state("Active")
end

start_transition(Init)
transition("Active","START",Active_Start)
transition("Active","STOP",Active_Stop)
transition("Active","*", Received)
