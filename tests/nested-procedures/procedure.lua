
moonagents.global_functions()

local level
local s = ""

local function AtReturn(ss)
   s = s .. " " .. ss
   restore()
end

local function Waiting_Stop()
   log_print("level=%u: received STOP", level)
   save()
   procedure_return(s)
end

local function Start(lvl, maxlvl)
   level = lvl
   log_print("level=%u parent=%u caller=%u",level, parent_, caller_)
   
   s = "" .. level
   if level < maxlvl then
      procedure(AtReturn, nil, "procedure", level+1, maxlvl)
   end
   next_state("Waiting")
end

start_transition(Start)
transition("Waiting","STOP",Waiting_Stop)
