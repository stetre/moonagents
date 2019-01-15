
moonagents.global_functions()

function AtReturn(s)
   log_print("procedure returned '%s'",s)
   next_state("Waiting")
end

function Waiting_Stop()
   log_print("caller: received STOP")
   stop()
end

function Start(maxlevel)
   procedure(AtReturn, nil, "procedure", 1, maxlevel)
   send({ "STOP" }, self_)
   next_state("NotImportant")
end

start_transition(Start)
transition("Waiting","STOP",Waiting_Stop)

