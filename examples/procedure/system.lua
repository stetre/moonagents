-- System agent script: system.lua

moonagents.global_functions()

local caller -- caller agent's pid
local T1 = timer(1,"T1")
local cnt = 0

local lyrics = {
   "Giant steps are what you take",
   "Walking on the moon",
   "I hope my legs don't break",
   "Walking on the moon",
   "We could walk forever",
   "Walking on the moon",
   "We could live together",
   "Walking on, walking on the moon",
   "Walking back from your house",
   "Walking on the moon",
   "Walking back from your house",
   "Walking on the moon",
   "Feet they hardly touch the ground",
   "Walking on the moon",
   "My feet don't hardly make no sound",
   "Walking on, walking on the moon",
   "Some may say",
   "I'm wishing my days away",
   "No way",
   "And if it's the price I pay",
   "Some say",
   "Tomorrow's another day",
   "You stay",
   "I may as well play",
   "Giant steps are what you take",
   "Walking on the moon",
   "I hope...",
}

local function Active_T1()
   cnt = cnt+1
   local v = lyrics[cnt]
   if v then
      send({ "VERSE", v }, caller)
      timer_start(T1)
   else
      send_at({ "STOP" }, caller, now() + 2)
      log_print("%s: stopping", name_)
      stop()
   end
end 

local function Start()
   caller = create("Caller","caller")
   send({ "START" }, caller)
   timer_start(T1)
   next_state("Active")
end


start_transition(Start)
transition("Active","T1",Active_T1)
